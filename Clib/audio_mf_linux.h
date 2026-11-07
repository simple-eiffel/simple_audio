/*
 * audio_mf_linux.h - the audio_mf.h calls on Linux, on dr_wav and dr_mp3.
 *
 * Decodes WAV and MP3 to 16-bit interleaved PCM at the file's own rate and
 * channels. Paths arrive as UTF-8 from NATIVE_STRING, through the wchar_t*
 * parameter that AUDIO_DECODER declares for Windows. Times are in 100-nanosecond
 * units, as Media Foundation's are.
 *
 * dr_wav.h and dr_mp3.h are mackron/dr_libs at commit 35b5c392cc15, under public
 * domain or MIT-0. They need no install. Windows and macOS open more formats,
 * through the system's own decoders; Linux opens these two.
 *
 * Copyright (c) 2026 Larry Rix - MIT License
 */

#ifndef AUDIO_MF_LINUX_H
#define AUDIO_MF_LINUX_H

#include <stdlib.h>
#include <string.h>
#include <wchar.h>

#define DRMP3_API static
#define DRMP3_PRIVATE static
#define DRWAV_API static
#define DRWAV_PRIVATE static
#define DR_MP3_IMPLEMENTATION
#define DR_WAV_IMPLEMENTATION
#include "dr_mp3.h"
#include "dr_wav.h"

typedef long long LONGLONG;

typedef struct {
    int is_wav;
    drwav wav;
    drmp3 mp3;
    int rate;
    int channels;
    unsigned long long cursor;   /* next frame */
} audio_mf_decoder;

static void* audio_mf_open(const wchar_t* l_path, int* l_rate, int* l_channels, LONGLONG* l_duration) {
    const char* path = (const char*) l_path;
    audio_mf_decoder* d = (audio_mf_decoder*) calloc(1, sizeof(audio_mf_decoder));
    unsigned long long frames;

    if (!d) return NULL;
    if (drwav_init_file(&d->wav, path, NULL)) {
        d->is_wav = 1;
        d->rate = (int) d->wav.sampleRate;
        d->channels = (int) d->wav.channels;
        frames = d->wav.totalPCMFrameCount;
    } else if (drmp3_init_file(&d->mp3, path, NULL)) {
        d->rate = (int) d->mp3.sampleRate;
        d->channels = (int) d->mp3.channels;
        frames = drmp3_get_pcm_frame_count(&d->mp3);
    } else {
        free(d);
        return NULL;
    }
    *l_rate = d->rate;
    *l_channels = d->channels;
    *l_duration = (LONGLONG) ((double) frames / (double) d->rate * 1.0e7);
    return d;
}

/* 1 with `*l_got' bytes, 0 at the end of the file, -1 on an error. */
static int audio_mf_read(void* l_handle, unsigned char* l_out, int l_cap, int* l_got) {
    audio_mf_decoder* d = (audio_mf_decoder*) l_handle;
    unsigned long long want = (unsigned long long) l_cap / (unsigned long long) (d->channels * 2);
    unsigned long long frames;

    *l_got = 0;
    if (d->is_wav) {
        frames = drwav_read_pcm_frames_s16(&d->wav, want, (drwav_int16*) l_out);
    } else {
        frames = drmp3_read_pcm_frames_s16(&d->mp3, want, (drmp3_int16*) l_out);
    }
    if (frames == 0) return 0;
    d->cursor += frames;
    *l_got = (int) frames * d->channels * 2;
    return 1;
}

static int audio_mf_seek(void* l_handle, LONGLONG l_at) {
    audio_mf_decoder* d = (audio_mf_decoder*) l_handle;
    unsigned long long frame = (unsigned long long) ((double) l_at / 1.0e7 * (double) d->rate);
    int done;

    if (d->is_wav) {
        done = drwav_seek_to_pcm_frame(&d->wav, frame) ? 1 : 0;
    } else {
        done = drmp3_seek_to_pcm_frame(&d->mp3, frame) ? 1 : 0;
    }
    if (done) d->cursor = frame;
    return done;
}

static LONGLONG audio_mf_position(void* l_handle) {
    audio_mf_decoder* d = (audio_mf_decoder*) l_handle;
    return (LONGLONG) ((double) d->cursor / (double) d->rate * 1.0e7);
}

static void audio_mf_close(void* l_handle) {
    audio_mf_decoder* d = (audio_mf_decoder*) l_handle;
    if (d->is_wav) {
        drwav_uninit(&d->wav);
    } else {
        drmp3_uninit(&d->mp3);
    }
    free(d);
}

#endif /* AUDIO_MF_LINUX_H */
