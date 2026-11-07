/*
 * audio_bridge_mac.h - the audio_bridge.h calls on macOS, on Core Audio.
 *
 * Devices through the AudioObject API, streams through AudioQueue, which does
 * sample format conversion and takes a device by its UID.
 *
 * A stream holds one second in a ring, as WASAPI's shared buffer does: the
 * caller writes when there is room and reads what has arrived, and the queue's
 * callback moves bytes in or out. An empty ring plays silence.
 *
 * Differences from Windows, all in what a device can report:
 * - Peak level: Core Audio has no per-device meter, so it reads 0.
 * - Volume and mute: answer 0 on a device with no such control, such as HDMI.
 * - Reset drops the ring; up to about 60 ms already queued is still heard.
 *
 * The queue's thread is created with every signal blocked, so the Eiffel
 * runtime's handler never runs on a thread it does not know.
 *
 * Copyright (c) 2026 Larry Rix - MIT License
 */

#ifndef AUDIO_BRIDGE_MAC_H
#define AUDIO_BRIDGE_MAC_H

#include <AudioToolbox/AudioToolbox.h>
#include <CoreAudio/CoreAudio.h>
#include <CoreFoundation/CoreFoundation.h>
#include <pthread.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <wchar.h>

#define AUDIO_FLOW_RENDER  0
#define AUDIO_FLOW_CAPTURE 1
#define AUDIO_QUEUE_BUFFERS 3

typedef struct {
    AudioDeviceID id;
    int flow;
} AudioMacDevice;

/* Non-NULL once started: SIMPLE_AUDIO's `is_initialized' reads it. */
static void* g_enumerator = NULL;

static int audio_init(void) {
    g_enumerator = (void*) &g_enumerator;
    return 1;
}

static void audio_cleanup(void) {
    g_enumerator = NULL;
}

static AudioObjectPropertyScope audio_scope(int flow) {
    return flow == AUDIO_FLOW_RENDER ? kAudioObjectPropertyScopeOutput : kAudioObjectPropertyScopeInput;
}

static int audio_has_streams(AudioDeviceID id, int flow) {
    AudioObjectPropertyAddress a = {kAudioDevicePropertyStreams, audio_scope(flow), kAudioObjectPropertyElementMain};
    UInt32 size = 0;
    return AudioObjectGetPropertyDataSize(id, &a, 0, NULL, &size) == noErr && size > 0;
}

/* The ids of every device with streams in `flow'. Caller frees. */
static AudioDeviceID* audio_device_ids(int flow, int* count) {
    AudioObjectPropertyAddress a = {kAudioHardwarePropertyDevices, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain};
    UInt32 size = 0;
    AudioDeviceID* ids;
    int all, i, kept = 0;

    *count = 0;
    if (AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &a, 0, NULL, &size) != noErr || size == 0) return NULL;
    ids = (AudioDeviceID*) malloc(size);
    if (!ids) return NULL;
    if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &a, 0, NULL, &size, ids) != noErr) {
        free(ids);
        return NULL;
    }
    all = (int) (size / sizeof(AudioDeviceID));
    for (i = 0; i < all; i++) {
        if (audio_has_streams(ids[i], flow)) ids[kept++] = ids[i];
    }
    *count = kept;
    return ids;
}

static int audio_device_count(int flow) {
    int count = 0;
    AudioDeviceID* ids = audio_device_ids(flow, &count);
    free(ids);
    return count;
}

static void* audio_new_device(AudioDeviceID id, int flow) {
    AudioMacDevice* d = (AudioMacDevice*) malloc(sizeof(AudioMacDevice));
    if (d) {
        d->id = id;
        d->flow = flow;
    }
    return d;
}

static void* audio_get_device(int flow, int index) {
    int count = 0;
    AudioDeviceID* ids = audio_device_ids(flow, &count);
    void* result = NULL;
    if (ids && index >= 0 && index < count) result = audio_new_device(ids[index], flow);
    free(ids);
    return result;
}

static void* audio_get_default_device(int flow) {
    AudioObjectPropertyAddress a = {
        flow == AUDIO_FLOW_RENDER ? kAudioHardwarePropertyDefaultOutputDevice : kAudioHardwarePropertyDefaultInputDevice,
        kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain};
    AudioDeviceID id = kAudioObjectUnknown;
    UInt32 size = sizeof(id);
    if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &a, 0, NULL, &size, &id) != noErr) return NULL;
    return id == kAudioObjectUnknown ? NULL : audio_new_device(id, flow);
}

/* The string property `selector' into `buffer' as UTF-16, which AUDIO_DEVICE
   reads 16 bits at a time; wchar_t is wider here, so the cast is deliberate. */
static int audio_get_string(void* device_ptr, AudioObjectPropertySelector selector, wchar_t* buffer, int buffer_size) {
    AudioMacDevice* d = (AudioMacDevice*) device_ptr;
    AudioObjectPropertyAddress a = {selector, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain};
    CFStringRef text = NULL;
    UInt32 size = sizeof(text);
    UniChar* out = (UniChar*) buffer;
    CFIndex length;

    if (!d || AudioObjectGetPropertyData(d->id, &a, 0, NULL, &size, &text) != noErr || !text) return 0;
    length = CFStringGetLength(text);
    if (length > buffer_size - 1) length = buffer_size - 1;
    CFStringGetCharacters(text, CFRangeMake(0, length), out);
    out[length] = 0;
    CFRelease(text);
    return 1;
}

static int audio_get_device_name(void* device_ptr, wchar_t* buffer, int buffer_size) {
    return audio_get_string(device_ptr, kAudioObjectPropertyName, buffer, buffer_size);
}

static int audio_get_device_id(void* device_ptr, wchar_t* buffer, int buffer_size) {
    return audio_get_string(device_ptr, kAudioDevicePropertyDeviceUID, buffer, buffer_size);
}

static void audio_release_device(void* device_ptr) {
    free(device_ptr);
}

static float audio_get_device_volume(void* device_ptr) {
    AudioMacDevice* d = (AudioMacDevice*) device_ptr;
    AudioObjectPropertyAddress a;
    Float32 level = 0;
    UInt32 size = sizeof(level);
    if (!d) return 0.0f;
    a = (AudioObjectPropertyAddress) {kAudioHardwareServiceDeviceProperty_VirtualMainVolume, audio_scope(d->flow), kAudioObjectPropertyElementMain};
    if (!AudioObjectHasProperty(d->id, &a)) return 0.0f;
    if (AudioObjectGetPropertyData(d->id, &a, 0, NULL, &size, &level) != noErr) return 0.0f;
    return level;
}

static int audio_set_device_volume(void* device_ptr, float level) {
    AudioMacDevice* d = (AudioMacDevice*) device_ptr;
    AudioObjectPropertyAddress a;
    Float32 value = level < 0.0f ? 0.0f : (level > 1.0f ? 1.0f : level);
    if (!d) return 0;
    a = (AudioObjectPropertyAddress) {kAudioHardwareServiceDeviceProperty_VirtualMainVolume, audio_scope(d->flow), kAudioObjectPropertyElementMain};
    if (!AudioObjectHasProperty(d->id, &a)) return 0;
    return AudioObjectSetPropertyData(d->id, &a, 0, NULL, sizeof(value), &value) == noErr ? 1 : 0;
}

static int audio_get_device_mute(void* device_ptr) {
    AudioMacDevice* d = (AudioMacDevice*) device_ptr;
    AudioObjectPropertyAddress a;
    UInt32 muted = 0, size = sizeof(muted);
    if (!d) return 0;
    a = (AudioObjectPropertyAddress) {kAudioDevicePropertyMute, audio_scope(d->flow), kAudioObjectPropertyElementMain};
    if (!AudioObjectHasProperty(d->id, &a)) return 0;
    if (AudioObjectGetPropertyData(d->id, &a, 0, NULL, &size, &muted) != noErr) return 0;
    return muted ? 1 : 0;
}

static int audio_set_device_mute(void* device_ptr, int muted) {
    AudioMacDevice* d = (AudioMacDevice*) device_ptr;
    AudioObjectPropertyAddress a;
    UInt32 value = muted ? 1 : 0;
    if (!d) return 0;
    a = (AudioObjectPropertyAddress) {kAudioDevicePropertyMute, audio_scope(d->flow), kAudioObjectPropertyElementMain};
    if (!AudioObjectHasProperty(d->id, &a)) return 0;
    return AudioObjectSetPropertyData(d->id, &a, 0, NULL, sizeof(value), &value) == noErr ? 1 : 0;
}

static float audio_get_device_peak_level(void* device_ptr) {
    (void) device_ptr;
    return 0.0f;
}

typedef struct {
    AudioQueueRef queue;
    AudioQueueBufferRef buffers[AUDIO_QUEUE_BUFFERS];
    AudioStreamBasicDescription format;
    pthread_mutex_t lock;        /* guards the ring */
    unsigned char* ring;
    UInt32 capacity;             /* frames */
    UInt32 head;                 /* first queued frame */
    UInt32 count;                /* frames queued */
    UInt32 chunk_bytes;
    int is_render;
    int is_started;
} AudioStream;

static void audio_ring_take(AudioStream* s, unsigned char* out, UInt32 frames) {
    UInt32 bpf = s->format.mBytesPerFrame;
    UInt32 first = s->capacity - s->head;
    if (first > frames) first = frames;
    memcpy(out, s->ring + (size_t) s->head * bpf, (size_t) first * bpf);
    if (frames > first) memcpy(out + (size_t) first * bpf, s->ring, (size_t) (frames - first) * bpf);
    s->head = (s->head + frames) % s->capacity;
    s->count -= frames;
}

static void audio_ring_put(AudioStream* s, const unsigned char* in, UInt32 frames) {
    UInt32 bpf = s->format.mBytesPerFrame;
    UInt32 tail = (s->head + s->count) % s->capacity;
    UInt32 first = s->capacity - tail;
    if (first > frames) first = frames;
    memcpy(s->ring + (size_t) tail * bpf, in, (size_t) first * bpf);
    if (frames > first) memcpy(s->ring, in + (size_t) first * bpf, (size_t) (frames - first) * bpf);
    s->count += frames;
}

/* Fill `b' from the ring, then silence. An 8-bit sample's silence is 128. */
static void audio_fill(AudioStream* s, AudioQueueBufferRef b) {
    UInt32 bpf = s->format.mBytesPerFrame;
    UInt32 want = s->chunk_bytes / bpf;
    UInt32 frames;
    pthread_mutex_lock(&s->lock);
    frames = s->count < want ? s->count : want;
    if (frames > 0) audio_ring_take(s, (unsigned char*) b->mAudioData, frames);
    pthread_mutex_unlock(&s->lock);
    memset((unsigned char*) b->mAudioData + (size_t) frames * bpf, s->format.mBitsPerChannel == 8 ? 128 : 0, (size_t) (want - frames) * bpf);
    b->mAudioDataByteSize = want * bpf;
}

static void audio_output_callback(void* user, AudioQueueRef q, AudioQueueBufferRef b) {
    AudioStream* s = (AudioStream*) user;
    if (s->is_started) {
        audio_fill(s, b);
        AudioQueueEnqueueBuffer(q, b, 0, NULL);
    }
}

static void audio_input_callback(void* user, AudioQueueRef q, AudioQueueBufferRef b, const AudioTimeStamp* t,
                                 UInt32 packets, const AudioStreamPacketDescription* d) {
    AudioStream* s = (AudioStream*) user;
    UInt32 frames = b->mAudioDataByteSize / s->format.mBytesPerFrame;
    (void) t; (void) packets; (void) d;
    pthread_mutex_lock(&s->lock);
    if (frames > s->capacity - s->count) frames = s->capacity - s->count;
    if (frames > 0) audio_ring_put(s, (const unsigned char*) b->mAudioData, frames);
    pthread_mutex_unlock(&s->lock);
    if (s->is_started) AudioQueueEnqueueBuffer(q, b, 0, NULL);
}

static void audio_stream_destroy(void* stream_ptr);

static void* audio_stream_create(void* device_ptr, int is_render, int sample_rate, int channels, int bits_per_sample) {
    AudioMacDevice* d = (AudioMacDevice*) device_ptr;
    AudioObjectPropertyAddress a = {kAudioDevicePropertyDeviceUID, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain};
    AudioStream* s;
    CFStringRef uid = NULL;
    UInt32 size = sizeof(uid);
    sigset_t all, old;
    OSStatus status;
    int i;

    if (!d || channels <= 0 || sample_rate <= 0) return NULL;
    s = (AudioStream*) calloc(1, sizeof(AudioStream));
    if (!s) return NULL;
    pthread_mutex_init(&s->lock, NULL);
    s->is_render = is_render;
    s->format.mSampleRate = sample_rate;
    s->format.mFormatID = kAudioFormatLinearPCM;
    s->format.mFormatFlags = kAudioFormatFlagIsPacked | (bits_per_sample == 8 ? 0 : kAudioFormatFlagIsSignedInteger);
    s->format.mBitsPerChannel = (UInt32) bits_per_sample;
    s->format.mChannelsPerFrame = (UInt32) channels;
    s->format.mBytesPerFrame = (UInt32) (channels * bits_per_sample / 8);
    s->format.mFramesPerPacket = 1;
    s->format.mBytesPerPacket = s->format.mBytesPerFrame;
    s->capacity = (UInt32) sample_rate;   /* one second, as on Windows */
    s->ring = (unsigned char*) malloc((size_t) s->capacity * s->format.mBytesPerFrame);
    s->chunk_bytes = (UInt32) (sample_rate / 50) * s->format.mBytesPerFrame;
    if (!s->ring) { audio_stream_destroy(s); return NULL; }

    sigfillset(&all);
    pthread_sigmask(SIG_SETMASK, &all, &old);
    if (is_render) {
        status = AudioQueueNewOutput(&s->format, audio_output_callback, s, NULL, NULL, 0, &s->queue);
    } else {
        status = AudioQueueNewInput(&s->format, audio_input_callback, s, NULL, NULL, 0, &s->queue);
    }
    pthread_sigmask(SIG_SETMASK, &old, NULL);
    if (status != noErr) { s->queue = NULL; audio_stream_destroy(s); return NULL; }

    if (AudioObjectGetPropertyData(d->id, &a, 0, NULL, &size, &uid) == noErr && uid) {
        status = AudioQueueSetProperty(s->queue, kAudioQueueProperty_CurrentDevice, &uid, sizeof(uid));
        CFRelease(uid);
        if (status != noErr) { audio_stream_destroy(s); return NULL; }
    }
    for (i = 0; i < AUDIO_QUEUE_BUFFERS; i++) {
        if (AudioQueueAllocateBuffer(s->queue, s->chunk_bytes, &s->buffers[i]) != noErr) {
            audio_stream_destroy(s);
            return NULL;
        }
    }
    return s;
}

static int audio_stream_start(void* stream_ptr) {
    AudioStream* s = (AudioStream*) stream_ptr;
    sigset_t all, old;
    OSStatus status;
    int i;

    if (!s || !s->queue || s->is_started) return 0;
    s->is_started = 1;
    for (i = 0; i < AUDIO_QUEUE_BUFFERS; i++) {
        if (s->is_render) {
            audio_fill(s, s->buffers[i]);
        } else {
            s->buffers[i]->mAudioDataByteSize = 0;
        }
        AudioQueueEnqueueBuffer(s->queue, s->buffers[i], 0, NULL);
    }
    sigfillset(&all);
    pthread_sigmask(SIG_SETMASK, &all, &old);
    status = AudioQueueStart(s->queue, NULL);
    pthread_sigmask(SIG_SETMASK, &old, NULL);
    if (status != noErr) {
        s->is_started = 0;
        AudioQueueReset(s->queue);
        return 0;
    }
    return 1;
}

static int audio_stream_stop(void* stream_ptr) {
    AudioStream* s = (AudioStream*) stream_ptr;
    if (!s || !s->queue || !s->is_started) return 0;
    s->is_started = 0;
    return AudioQueueStop(s->queue, true) == noErr ? 1 : 0;
}

static int audio_stream_reset(void* stream_ptr) {
    AudioStream* s = (AudioStream*) stream_ptr;
    if (!s || !s->queue) return 0;
    pthread_mutex_lock(&s->lock);
    s->head = 0;
    s->count = 0;
    pthread_mutex_unlock(&s->lock);
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
    if ((UInt32) frame_count <= s->capacity - s->count) {
        audio_ring_put(s, (const unsigned char*) data, (UInt32) frame_count);
        result = frame_count;
    }
    pthread_mutex_unlock(&s->lock);
    return result;
}

static int audio_stream_read(void* stream_ptr, void* data, int max_frames) {
    AudioStream* s = (AudioStream*) stream_ptr;
    UInt32 frames;
    if (!s || s->is_render || !data || max_frames <= 0) return 0;
    pthread_mutex_lock(&s->lock);
    frames = s->count < (UInt32) max_frames ? s->count : (UInt32) max_frames;
    if (frames > 0) audio_ring_take(s, (unsigned char*) data, frames);
    pthread_mutex_unlock(&s->lock);
    return (int) frames;
}

static int audio_stream_get_sample_rate(void* stream_ptr) {
    AudioStream* s = (AudioStream*) stream_ptr;
    return s ? (int) s->format.mSampleRate : 0;
}

static int audio_stream_get_channels(void* stream_ptr) {
    AudioStream* s = (AudioStream*) stream_ptr;
    return s ? (int) s->format.mChannelsPerFrame : 0;
}

static int audio_stream_get_bits_per_sample(void* stream_ptr) {
    AudioStream* s = (AudioStream*) stream_ptr;
    return s ? (int) s->format.mBitsPerChannel : 0;
}

static int audio_stream_get_buffer_size(void* stream_ptr) {
    AudioStream* s = (AudioStream*) stream_ptr;
    return s ? (int) s->capacity : 0;
}

static void audio_stream_destroy(void* stream_ptr) {
    AudioStream* s = (AudioStream*) stream_ptr;
    if (!s) return;
    s->is_started = 0;
    if (s->queue) AudioQueueDispose(s->queue, true);
    pthread_mutex_destroy(&s->lock);
    free(s->ring);
    free(s);
}

#endif /* AUDIO_BRIDGE_MAC_H */
