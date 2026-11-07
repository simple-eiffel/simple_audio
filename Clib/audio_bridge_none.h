/*
 * audio_bridge_none.h - the audio_bridge.h calls where no backend exists yet.
 *
 * Linux lands here until its backend is written: no devices, and every stream
 * refused, so the library compiles and says plainly that there is no audio.
 *
 * Copyright (c) 2026 Larry Rix - MIT License
 */

#ifndef AUDIO_BRIDGE_NONE_H
#define AUDIO_BRIDGE_NONE_H

#include <stdlib.h>
#include <wchar.h>

#define AUDIO_FLOW_RENDER  0
#define AUDIO_FLOW_CAPTURE 1

typedef struct { int is_started; } AudioStream;

static void* g_enumerator = NULL;

static int audio_init(void) { g_enumerator = (void*) &g_enumerator; return 1; }
static void audio_cleanup(void) { g_enumerator = NULL; }
static int audio_device_count(int flow) { (void) flow; return 0; }
static void* audio_get_device(int flow, int index) { (void) flow; (void) index; return NULL; }
static void* audio_get_default_device(int flow) { (void) flow; return NULL; }
static int audio_get_device_name(void* d, wchar_t* b, int s) { (void) d; (void) b; (void) s; return 0; }
static int audio_get_device_id(void* d, wchar_t* b, int s) { (void) d; (void) b; (void) s; return 0; }
static void audio_release_device(void* d) { (void) d; }
static float audio_get_device_volume(void* d) { (void) d; return 0.0f; }
static int audio_set_device_volume(void* d, float l) { (void) d; (void) l; return 0; }
static int audio_get_device_mute(void* d) { (void) d; return 0; }
static int audio_set_device_mute(void* d, int m) { (void) d; (void) m; return 0; }
static float audio_get_device_peak_level(void* d) { (void) d; return 0.0f; }
static void* audio_stream_create(void* d, int r, int s, int c, int b) { (void) d; (void) r; (void) s; (void) c; (void) b; return NULL; }
static int audio_stream_start(void* s) { (void) s; return 0; }
static int audio_stream_stop(void* s) { (void) s; return 0; }
static int audio_stream_reset(void* s) { (void) s; return 0; }
static int audio_stream_get_available_frames(void* s) { (void) s; return 0; }
static int audio_stream_write(void* s, const void* d, int f) { (void) s; (void) d; (void) f; return 0; }
static int audio_stream_read(void* s, void* d, int m) { (void) s; (void) d; (void) m; return 0; }
static int audio_stream_get_sample_rate(void* s) { (void) s; return 0; }
static int audio_stream_get_channels(void* s) { (void) s; return 0; }
static int audio_stream_get_bits_per_sample(void* s) { (void) s; return 0; }
static int audio_stream_get_buffer_size(void* s) { (void) s; return 0; }
static void audio_stream_destroy(void* s) { (void) s; }

/* No decoder either. */
typedef long long LONGLONG;
static void* audio_mf_open(const wchar_t* p, int* r, int* c, LONGLONG* d) { (void) p; (void) r; (void) c; (void) d; return NULL; }
static int audio_mf_read(void* h, unsigned char* o, int c, int* g) { (void) h; (void) o; (void) c; *g = 0; return -1; }
static int audio_mf_seek(void* h, LONGLONG a) { (void) h; (void) a; return 0; }
static LONGLONG audio_mf_position(void* h) { (void) h; return 0; }
static void audio_mf_close(void* h) { (void) h; }

#endif /* AUDIO_BRIDGE_NONE_H */
