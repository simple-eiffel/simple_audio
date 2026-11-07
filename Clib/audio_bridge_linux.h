/*
 * audio_bridge_linux.h - the audio_bridge.h calls on Linux, on PulseAudio.
 *
 * One threaded main loop and one context serve the whole program. PipeWire
 * desktops answer the same protocol. With no server running, the library still
 * starts and simply reports no devices.
 *
 * Shared state is `weak', not static: this header is compiled into several
 * generated C files, and a static would give each its own empty connection.
 *
 * Each stream holds a one-second ring, like WASAPI's shared buffer. Writes only
 * touch the ring, so they never block. The server drains it through the write
 * callback, padding with silence when it runs dry.
 *
 * Differences from Windows:
 * - Peak level: PulseAudio has no per-device meter here, so it reads 0.
 * - Reset drops the ring and flushes the server, so little is still heard.
 *
 * The main loop's thread starts with every signal blocked, so the Eiffel
 * runtime's handler never runs on a thread it does not know.
 *
 * Copyright (c) 2026 Larry Rix - MIT License
 */

#ifndef AUDIO_BRIDGE_LINUX_H
#define AUDIO_BRIDGE_LINUX_H

#include <pulse/pulseaudio.h>
#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

#define AUDIO_FLOW_RENDER  0
#define AUDIO_FLOW_CAPTURE 1
#define AUDIO_NAME_SIZE    512
#define AUDIO_SHARED       __attribute__((weak))

/* Non-NULL once started: SIMPLE_AUDIO's `is_initialized' reads it. */
AUDIO_SHARED void* g_enumerator = NULL;
AUDIO_SHARED pa_threaded_mainloop* g_audio_loop = NULL;
AUDIO_SHARED pa_context* g_audio_context = NULL;
AUDIO_SHARED pthread_mutex_t g_audio_connect_lock = PTHREAD_MUTEX_INITIALIZER;

typedef struct {
    int flow;
    char name[AUDIO_NAME_SIZE];
    char description[AUDIO_NAME_SIZE];
} AudioLinuxDevice;

typedef struct {
    AudioLinuxDevice* items;
    int count;
    int capacity;
    int flow;
} AudioLinuxList;

static void audio_context_state(pa_context* c, void* user) {
    (void) c; (void) user;
    pa_threaded_mainloop_signal(g_audio_loop, 0);
}

static void audio_disconnect(void) {
    if (g_audio_loop) pa_threaded_mainloop_stop(g_audio_loop);
    if (g_audio_context) {
        pa_context_disconnect(g_audio_context);
        pa_context_unref(g_audio_context);
        g_audio_context = NULL;
    }
    if (g_audio_loop) {
        pa_threaded_mainloop_free(g_audio_loop);
        g_audio_loop = NULL;
    }
}

/* Connect once. 1 when the server is reachable. */
static int audio_connect(void) {
    sigset_t all, old;
    pa_context_state_t state;
    int result = 0;

    pthread_mutex_lock(&g_audio_connect_lock);
    if (g_audio_context) {
        pthread_mutex_unlock(&g_audio_connect_lock);
        return 1;
    }
    g_audio_loop = pa_threaded_mainloop_new();
    if (g_audio_loop) {
        g_audio_context = pa_context_new(pa_threaded_mainloop_get_api(g_audio_loop), "simple_audio");
    }
    if (g_audio_context) {
        pa_context_set_state_callback(g_audio_context, audio_context_state, NULL);
        if (pa_context_connect(g_audio_context, NULL, PA_CONTEXT_NOAUTOSPAWN, NULL) >= 0) {
            sigfillset(&all);
            pthread_sigmask(SIG_SETMASK, &all, &old);
            result = pa_threaded_mainloop_start(g_audio_loop) >= 0;
            pthread_sigmask(SIG_SETMASK, &old, NULL);
        }
    }
    if (result) {
        pa_threaded_mainloop_lock(g_audio_loop);
        for (;;) {
            state = pa_context_get_state(g_audio_context);
            if (state == PA_CONTEXT_READY || !PA_CONTEXT_IS_GOOD(state)) break;
            pa_threaded_mainloop_wait(g_audio_loop);
        }
        pa_threaded_mainloop_unlock(g_audio_loop);
        result = state == PA_CONTEXT_READY;
    }
    if (!result) audio_disconnect();
    pthread_mutex_unlock(&g_audio_connect_lock);
    return result;
}

static int audio_init(void) {
    g_enumerator = (void*) &g_enumerator;
    audio_connect();
    return 1;
}

static void audio_cleanup(void) {
    pthread_mutex_lock(&g_audio_connect_lock);
    audio_disconnect();
    g_enumerator = NULL;
    pthread_mutex_unlock(&g_audio_connect_lock);
}

/* Wait for `op', with the loop locked. */
static void audio_finish(pa_operation* op) {
    if (!op) return;
    while (pa_operation_get_state(op) == PA_OPERATION_RUNNING) {
        pa_threaded_mainloop_wait(g_audio_loop);
    }
    pa_operation_unref(op);
}

static void audio_copy_text(char* target, const char* source) {
    strncpy(target, source ? source : "", AUDIO_NAME_SIZE - 1);
    target[AUDIO_NAME_SIZE - 1] = 0;
}

static void audio_list_add(AudioLinuxList* list, const char* name, const char* description) {
    AudioLinuxDevice* grown;
    if (list->count == list->capacity) {
        int capacity = list->capacity ? list->capacity * 2 : 8;
        grown = (AudioLinuxDevice*) realloc(list->items, (size_t) capacity * sizeof(AudioLinuxDevice));
        if (!grown) return;
        list->items = grown;
        list->capacity = capacity;
    }
    list->items[list->count].flow = list->flow;
    audio_copy_text(list->items[list->count].name, name);
    audio_copy_text(list->items[list->count].description, description);
    list->count++;
}

static void audio_sink_listed(pa_context* c, const pa_sink_info* i, int eol, void* user) {
    (void) c;
    if (eol != 0 || !i) {
        pa_threaded_mainloop_signal(g_audio_loop, 0);
        return;
    }
    audio_list_add((AudioLinuxList*) user, i->name, i->description);
}

/* A monitor is another device's output, not a microphone: leave it out. */
static void audio_source_listed(pa_context* c, const pa_source_info* i, int eol, void* user) {
    (void) c;
    if (eol != 0 || !i) {
        pa_threaded_mainloop_signal(g_audio_loop, 0);
        return;
    }
    if (i->monitor_of_sink == PA_INVALID_INDEX) {
        audio_list_add((AudioLinuxList*) user, i->name, i->description);
    }
}

/* Every device in `flow'. Caller frees `list->items'. */
static void audio_list_devices(int flow, AudioLinuxList* list) {
    memset(list, 0, sizeof(*list));
    list->flow = flow;
    if (!audio_connect()) return;
    pa_threaded_mainloop_lock(g_audio_loop);
    if (flow == AUDIO_FLOW_RENDER) {
        audio_finish(pa_context_get_sink_info_list(g_audio_context, audio_sink_listed, list));
    } else {
        audio_finish(pa_context_get_source_info_list(g_audio_context, audio_source_listed, list));
    }
    pa_threaded_mainloop_unlock(g_audio_loop);
}

static int audio_device_count(int flow) {
    AudioLinuxList list;
    audio_list_devices(flow, &list);
    free(list.items);
    return list.count;
}

static void* audio_new_device(const AudioLinuxDevice* source) {
    AudioLinuxDevice* d = (AudioLinuxDevice*) malloc(sizeof(AudioLinuxDevice));
    if (d) *d = *source;
    return d;
}

static void* audio_get_device(int flow, int index) {
    AudioLinuxList list;
    void* result = NULL;
    audio_list_devices(flow, &list);
    if (index >= 0 && index < list.count) result = audio_new_device(&list.items[index]);
    free(list.items);
    return result;
}

typedef struct {
    char sink[AUDIO_NAME_SIZE];
    char source[AUDIO_NAME_SIZE];
} AudioLinuxDefaults;

static void audio_server_read(pa_context* c, const pa_server_info* i, void* user) {
    AudioLinuxDefaults* d = (AudioLinuxDefaults*) user;
    (void) c;
    if (i) {
        audio_copy_text(d->sink, i->default_sink_name);
        audio_copy_text(d->source, i->default_source_name);
    }
    pa_threaded_mainloop_signal(g_audio_loop, 0);
}

static void* audio_get_default_device(int flow) {
    AudioLinuxDefaults defaults;
    AudioLinuxList list;
    const char* wanted;
    void* result = NULL;
    int i;

    memset(&defaults, 0, sizeof(defaults));
    audio_list_devices(flow, &list);
    if (list.count > 0) {
        pa_threaded_mainloop_lock(g_audio_loop);
        audio_finish(pa_context_get_server_info(g_audio_context, audio_server_read, &defaults));
        pa_threaded_mainloop_unlock(g_audio_loop);
        wanted = flow == AUDIO_FLOW_RENDER ? defaults.sink : defaults.source;
        for (i = 0; i < list.count && !result; i++) {
            if (strcmp(list.items[i].name, wanted) == 0) result = audio_new_device(&list.items[i]);
        }
        /* A default that is a monitor is not in the list. */
        if (!result) result = audio_new_device(&list.items[0]);
    }
    free(list.items);
    return result;
}

/* `text' into `buffer' as UTF-16, which AUDIO_DEVICE reads 16 bits at a time;
   wchar_t is wider here, so the cast is deliberate. */
static int audio_write_utf16(const char* text, wchar_t* buffer, int buffer_size) {
    const unsigned char* p = (const unsigned char*) text;
    uint16_t* out = (uint16_t*) buffer;
    int n = 0;
    uint32_t code;
    int extra;

    if (buffer_size <= 0) return 0;
    while (*p) {
        if (*p < 0x80) { code = *p; extra = 0; }
        else if ((*p & 0xE0) == 0xC0) { code = *p & 0x1F; extra = 1; }
        else if ((*p & 0xF0) == 0xE0) { code = *p & 0x0F; extra = 2; }
        else if ((*p & 0xF8) == 0xF0) { code = *p & 0x07; extra = 3; }
        else { code = 0xFFFD; extra = 0; }
        p++;
        while (extra > 0 && (*p & 0xC0) == 0x80) {
            code = (code << 6) | (*p & 0x3F);
            p++;
            extra--;
        }
        if (extra > 0) code = 0xFFFD;
        if (code >= 0x10000) {
            if (n + 2 > buffer_size - 1) break;
            code -= 0x10000;
            out[n++] = (uint16_t) (0xD800 | (code >> 10));
            out[n++] = (uint16_t) (0xDC00 | (code & 0x3FF));
        } else {
            if (n + 1 > buffer_size - 1) break;
            out[n++] = (uint16_t) code;
        }
    }
    out[n] = 0;
    return 1;
}

static int audio_get_device_name(void* device_ptr, wchar_t* buffer, int buffer_size) {
    AudioLinuxDevice* d = (AudioLinuxDevice*) device_ptr;
    return d ? audio_write_utf16(d->description, buffer, buffer_size) : 0;
}

static int audio_get_device_id(void* device_ptr, wchar_t* buffer, int buffer_size) {
    AudioLinuxDevice* d = (AudioLinuxDevice*) device_ptr;
    return d ? audio_write_utf16(d->name, buffer, buffer_size) : 0;
}

static void audio_release_device(void* device_ptr) {
    free(device_ptr);
}

typedef struct {
    pa_cvolume volume;
    int mute;
    int found;
} AudioLinuxLevel;

static void audio_sink_level(pa_context* c, const pa_sink_info* i, int eol, void* user) {
    AudioLinuxLevel* l = (AudioLinuxLevel*) user;
    (void) c;
    if (eol != 0 || !i) {
        pa_threaded_mainloop_signal(g_audio_loop, 0);
        return;
    }
    l->volume = i->volume;
    l->mute = i->mute;
    l->found = 1;
}

static void audio_source_level(pa_context* c, const pa_source_info* i, int eol, void* user) {
    AudioLinuxLevel* l = (AudioLinuxLevel*) user;
    (void) c;
    if (eol != 0 || !i) {
        pa_threaded_mainloop_signal(g_audio_loop, 0);
        return;
    }
    l->volume = i->volume;
    l->mute = i->mute;
    l->found = 1;
}

static int audio_read_level(AudioLinuxDevice* d, AudioLinuxLevel* level) {
    memset(level, 0, sizeof(*level));
    if (!d || !audio_connect()) return 0;
    pa_threaded_mainloop_lock(g_audio_loop);
    if (d->flow == AUDIO_FLOW_RENDER) {
        audio_finish(pa_context_get_sink_info_by_name(g_audio_context, d->name, audio_sink_level, level));
    } else {
        audio_finish(pa_context_get_source_info_by_name(g_audio_context, d->name, audio_source_level, level));
    }
    pa_threaded_mainloop_unlock(g_audio_loop);
    return level->found;
}

static void audio_context_done(pa_context* c, int success, void* user) {
    (void) c;
    *(int*) user = success;
    pa_threaded_mainloop_signal(g_audio_loop, 0);
}

static float audio_get_device_volume(void* device_ptr) {
    AudioLinuxLevel level;
    float value;
    if (!audio_read_level((AudioLinuxDevice*) device_ptr, &level)) return 0.0f;
    value = (float) pa_cvolume_avg(&level.volume) / (float) PA_VOLUME_NORM;
    return value > 1.0f ? 1.0f : value;
}

static int audio_set_device_volume(void* device_ptr, float level) {
    AudioLinuxDevice* d = (AudioLinuxDevice*) device_ptr;
    AudioLinuxLevel current;
    float value = level < 0.0f ? 0.0f : (level > 1.0f ? 1.0f : level);
    pa_cvolume volume;
    int done = 0;

    if (!audio_read_level(d, &current)) return 0;
    pa_cvolume_set(&volume, current.volume.channels, (pa_volume_t) (value * (float) PA_VOLUME_NORM));
    pa_threaded_mainloop_lock(g_audio_loop);
    if (d->flow == AUDIO_FLOW_RENDER) {
        audio_finish(pa_context_set_sink_volume_by_name(g_audio_context, d->name, &volume, audio_context_done, &done));
    } else {
        audio_finish(pa_context_set_source_volume_by_name(g_audio_context, d->name, &volume, audio_context_done, &done));
    }
    pa_threaded_mainloop_unlock(g_audio_loop);
    return done ? 1 : 0;
}

static int audio_get_device_mute(void* device_ptr) {
    AudioLinuxLevel level;
    if (!audio_read_level((AudioLinuxDevice*) device_ptr, &level)) return 0;
    return level.mute ? 1 : 0;
}

static int audio_set_device_mute(void* device_ptr, int muted) {
    AudioLinuxDevice* d = (AudioLinuxDevice*) device_ptr;
    int done = 0;

    if (!d || !audio_connect()) return 0;
    pa_threaded_mainloop_lock(g_audio_loop);
    if (d->flow == AUDIO_FLOW_RENDER) {
        audio_finish(pa_context_set_sink_mute_by_name(g_audio_context, d->name, muted ? 1 : 0, audio_context_done, &done));
    } else {
        audio_finish(pa_context_set_source_mute_by_name(g_audio_context, d->name, muted ? 1 : 0, audio_context_done, &done));
    }
    pa_threaded_mainloop_unlock(g_audio_loop);
    return done ? 1 : 0;
}

static float audio_get_device_peak_level(void* device_ptr) {
    (void) device_ptr;
    return 0.0f;
}

typedef struct {
    pa_stream* stream;
    pthread_mutex_t lock;        /* guards the ring */
    unsigned char* ring;
    uint32_t capacity;           /* frames */
    uint32_t head;               /* first queued frame */
    uint32_t count;              /* frames queued */
    uint32_t bytes_per_frame;
    int sample_rate;
    int channels;
    int bits;
    int is_render;
    int is_started;
} AudioStream;

static void audio_ring_take(AudioStream* s, unsigned char* out, uint32_t frames) {
    uint32_t bpf = s->bytes_per_frame;
    uint32_t first = s->capacity - s->head;
    if (first > frames) first = frames;
    memcpy(out, s->ring + (size_t) s->head * bpf, (size_t) first * bpf);
    if (frames > first) memcpy(out + (size_t) first * bpf, s->ring, (size_t) (frames - first) * bpf);
    s->head = (s->head + frames) % s->capacity;
    s->count -= frames;
}

static void audio_ring_put(AudioStream* s, const unsigned char* in, uint32_t frames) {
    uint32_t bpf = s->bytes_per_frame;
    uint32_t tail = (s->head + s->count) % s->capacity;
    uint32_t first = s->capacity - tail;
    if (first > frames) first = frames;
    memcpy(s->ring + (size_t) tail * bpf, in, (size_t) first * bpf);
    if (frames > first) memcpy(s->ring, in + (size_t) first * bpf, (size_t) (frames - first) * bpf);
    s->count += frames;
}

/* Fill what the server asks for from the ring, then silence. An 8-bit sample's
   silence is 128. Nothing is taken before `start', so queued sound waits. */
static void audio_stream_writable(pa_stream* p, size_t bytes, void* user) {
    AudioStream* s = (AudioStream*) user;
    void* data = NULL;
    size_t size = bytes;
    uint32_t want, frames;

    if (!s->is_started || bytes == 0) return;
    if (pa_stream_begin_write(p, &data, &size) < 0 || !data) return;
    want = (uint32_t) (size / s->bytes_per_frame);
    if (want == 0) {
        pa_stream_cancel_write(p);
        return;
    }
    pthread_mutex_lock(&s->lock);
    frames = s->count < want ? s->count : want;
    if (frames > 0) audio_ring_take(s, (unsigned char*) data, frames);
    pthread_mutex_unlock(&s->lock);
    memset((unsigned char*) data + (size_t) frames * s->bytes_per_frame, s->bits == 8 ? 128 : 0,
           (size_t) (want - frames) * s->bytes_per_frame);
    pa_stream_write(p, data, (size_t) want * s->bytes_per_frame, NULL, 0, PA_SEEK_RELATIVE);
}

static void audio_stream_readable(pa_stream* p, size_t bytes, void* user) {
    AudioStream* s = (AudioStream*) user;
    const void* data = NULL;
    size_t size = 0;
    uint32_t frames;
    (void) bytes;

    while (pa_stream_readable_size(p) > 0) {
        if (pa_stream_peek(p, &data, &size) < 0) return;
        if (size == 0) return;
        if (data) {
            frames = (uint32_t) (size / s->bytes_per_frame);
            pthread_mutex_lock(&s->lock);
            if (frames > s->capacity - s->count) frames = s->capacity - s->count;
            if (frames > 0) audio_ring_put(s, (const unsigned char*) data, frames);
            pthread_mutex_unlock(&s->lock);
        }
        pa_stream_drop(p);
    }
}

static void audio_stream_state(pa_stream* p, void* user) {
    (void) p; (void) user;
    pa_threaded_mainloop_signal(g_audio_loop, 0);
}

static void audio_stream_done(pa_stream* p, int success, void* user) {
    (void) p;
    *(int*) user = success;
    pa_threaded_mainloop_signal(g_audio_loop, 0);
}

static void audio_stream_destroy(void* stream_ptr);

static void* audio_stream_create(void* device_ptr, int is_render, int sample_rate, int channels, int bits_per_sample) {
    AudioLinuxDevice* d = (AudioLinuxDevice*) device_ptr;
    AudioStream* s;
    pa_sample_spec spec;
    pa_buffer_attr attr;
    pa_stream_state_t state;
    pa_stream_flags_t flags = (pa_stream_flags_t) (PA_STREAM_START_CORKED | PA_STREAM_ADJUST_LATENCY);
    int connected;

    if (!d || channels <= 0 || sample_rate <= 0 || !audio_connect()) return NULL;
    switch (bits_per_sample) {
        case 8:  spec.format = PA_SAMPLE_U8;    break;
        case 16: spec.format = PA_SAMPLE_S16LE; break;
        case 24: spec.format = PA_SAMPLE_S24LE; break;
        case 32: spec.format = PA_SAMPLE_S32LE; break;
        default: return NULL;
    }
    spec.rate = (uint32_t) sample_rate;
    spec.channels = (uint8_t) channels;
    if (!pa_sample_spec_valid(&spec)) return NULL;

    s = (AudioStream*) calloc(1, sizeof(AudioStream));
    if (!s) return NULL;
    pthread_mutex_init(&s->lock, NULL);
    s->is_render = is_render;
    s->sample_rate = sample_rate;
    s->channels = channels;
    s->bits = bits_per_sample;
    s->bytes_per_frame = (uint32_t) (channels * bits_per_sample / 8);
    s->capacity = (uint32_t) sample_rate;   /* one second, as on Windows */
    s->ring = (unsigned char*) malloc((size_t) s->capacity * s->bytes_per_frame);
    if (!s->ring) { audio_stream_destroy(s); return NULL; }

    attr.maxlength = (uint32_t) -1;
    attr.tlength = (uint32_t) pa_usec_to_bytes(60 * PA_USEC_PER_MSEC, &spec);
    attr.prebuf = 0;   /* never wait for a fill: the ring pads with silence */
    attr.minreq = (uint32_t) pa_usec_to_bytes(20 * PA_USEC_PER_MSEC, &spec);
    attr.fragsize = (uint32_t) pa_usec_to_bytes(20 * PA_USEC_PER_MSEC, &spec);

    pa_threaded_mainloop_lock(g_audio_loop);
    s->stream = pa_stream_new(g_audio_context, "simple_audio stream", &spec, NULL);
    if (!s->stream) {
        pa_threaded_mainloop_unlock(g_audio_loop);
        audio_stream_destroy(s);
        return NULL;
    }
    pa_stream_set_state_callback(s->stream, audio_stream_state, s);
    if (is_render) {
        pa_stream_set_write_callback(s->stream, audio_stream_writable, s);
        connected = pa_stream_connect_playback(s->stream, d->name, &attr, flags, NULL, NULL);
    } else {
        pa_stream_set_read_callback(s->stream, audio_stream_readable, s);
        connected = pa_stream_connect_record(s->stream, d->name, &attr, flags);
    }
    state = PA_STREAM_FAILED;
    if (connected >= 0) {
        for (;;) {
            state = pa_stream_get_state(s->stream);
            if (state == PA_STREAM_READY || !PA_STREAM_IS_GOOD(state)) break;
            pa_threaded_mainloop_wait(g_audio_loop);
        }
    }
    pa_threaded_mainloop_unlock(g_audio_loop);
    if (state != PA_STREAM_READY) {
        audio_stream_destroy(s);
        return NULL;
    }
    return s;
}

static int audio_stream_cork(AudioStream* s, int corked) {
    int done = 0;
    audio_finish(pa_stream_cork(s->stream, corked, audio_stream_done, &done));
    return done;
}

static int audio_stream_start(void* stream_ptr) {
    AudioStream* s = (AudioStream*) stream_ptr;
    size_t room;
    int done;

    if (!s || !s->stream || s->is_started) return 0;
    pa_threaded_mainloop_lock(g_audio_loop);
    s->is_started = 1;
    if (s->is_render) {
        room = pa_stream_writable_size(s->stream);
        if (room != (size_t) -1 && room > 0) audio_stream_writable(s->stream, room, s);
    }
    done = audio_stream_cork(s, 0);
    if (!done) s->is_started = 0;
    pa_threaded_mainloop_unlock(g_audio_loop);
    return done ? 1 : 0;
}

static int audio_stream_stop(void* stream_ptr) {
    AudioStream* s = (AudioStream*) stream_ptr;
    int done;

    if (!s || !s->stream || !s->is_started) return 0;
    pa_threaded_mainloop_lock(g_audio_loop);
    s->is_started = 0;
    done = audio_stream_cork(s, 1);
    pa_threaded_mainloop_unlock(g_audio_loop);
    return done ? 1 : 0;
}

static int audio_stream_reset(void* stream_ptr) {
    AudioStream* s = (AudioStream*) stream_ptr;
    int done = 0;

    if (!s || !s->stream) return 0;
    pthread_mutex_lock(&s->lock);
    s->head = 0;
    s->count = 0;
    pthread_mutex_unlock(&s->lock);
    pa_threaded_mainloop_lock(g_audio_loop);
    audio_finish(pa_stream_flush(s->stream, audio_stream_done, &done));
    pa_threaded_mainloop_unlock(g_audio_loop);
    return 1;
}

/* Room to write. */
static int audio_stream_get_available_frames(void* stream_ptr) {
    AudioStream* s = (AudioStream*) stream_ptr;
    int result;
    if (!s) return 0;
    pthread_mutex_lock(&s->lock);
    result = (int) (s->capacity - s->count);
    pthread_mutex_unlock(&s->lock);
    return result;
}

/* All of `frame_count', or 0 when there is no room for it, as on Windows. */
static int audio_stream_write(void* stream_ptr, const void* data, int frame_count) {
    AudioStream* s = (AudioStream*) stream_ptr;
    int result = 0;
    if (!s || !s->is_render || !data || frame_count <= 0) return 0;
    pthread_mutex_lock(&s->lock);
    if ((uint32_t) frame_count <= s->capacity - s->count) {
        audio_ring_put(s, (const unsigned char*) data, (uint32_t) frame_count);
        result = frame_count;
    }
    pthread_mutex_unlock(&s->lock);
    return result;
}

static int audio_stream_read(void* stream_ptr, void* data, int max_frames) {
    AudioStream* s = (AudioStream*) stream_ptr;
    uint32_t frames;
    if (!s || s->is_render || !data || max_frames <= 0) return 0;
    pthread_mutex_lock(&s->lock);
    frames = s->count < (uint32_t) max_frames ? s->count : (uint32_t) max_frames;
    if (frames > 0) audio_ring_take(s, (unsigned char*) data, frames);
    pthread_mutex_unlock(&s->lock);
    return (int) frames;
}

static int audio_stream_get_sample_rate(void* stream_ptr) {
    AudioStream* s = (AudioStream*) stream_ptr;
    return s ? s->sample_rate : 0;
}

static int audio_stream_get_channels(void* stream_ptr) {
    AudioStream* s = (AudioStream*) stream_ptr;
    return s ? s->channels : 0;
}

static int audio_stream_get_bits_per_sample(void* stream_ptr) {
    AudioStream* s = (AudioStream*) stream_ptr;
    return s ? s->bits : 0;
}

static int audio_stream_get_buffer_size(void* stream_ptr) {
    AudioStream* s = (AudioStream*) stream_ptr;
    return s ? (int) s->capacity : 0;
}

static void audio_stream_destroy(void* stream_ptr) {
    AudioStream* s = (AudioStream*) stream_ptr;
    if (!s) return;
    s->is_started = 0;
    if (s->stream) {
        pa_threaded_mainloop_lock(g_audio_loop);
        pa_stream_set_write_callback(s->stream, NULL, NULL);
        pa_stream_set_read_callback(s->stream, NULL, NULL);
        pa_stream_set_state_callback(s->stream, NULL, NULL);
        pa_stream_disconnect(s->stream);
        pa_stream_unref(s->stream);
        pa_threaded_mainloop_unlock(g_audio_loop);
    }
    pthread_mutex_destroy(&s->lock);
    free(s->ring);
    free(s);
}

#endif /* AUDIO_BRIDGE_LINUX_H */
