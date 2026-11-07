/*
 * audio_mf_mac.h - the audio_mf.h calls on macOS, on ExtAudioFile.
 *
 * Decodes whatever Core Audio can open to 16-bit interleaved PCM at the file's
 * own rate and channels. Paths arrive as UTF-8 from NATIVE_STRING, through the
 * wchar_t* parameter that AUDIO_DECODER declares for Windows. Times are in
 * 100-nanosecond units, as Media Foundation's are.
 *
 * Copyright (c) 2026 Larry Rix - MIT License
 */

#ifndef AUDIO_MF_MAC_H
#define AUDIO_MF_MAC_H

#include <AudioToolbox/AudioToolbox.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

typedef long long LONGLONG;

typedef struct {
    ExtAudioFileRef file;
    int rate;
    int channels;
} audio_mf_decoder;

static void* audio_mf_open(const wchar_t* l_path, int* l_rate, int* l_channels, LONGLONG* l_duration) {
    const char* path = (const char*) l_path;
    CFURLRef url = CFURLCreateFromFileSystemRepresentation(NULL, (const UInt8*) path, (CFIndex) strlen(path), false);
    audio_mf_decoder* d;
    ExtAudioFileRef file = NULL;
    AudioStreamBasicDescription source, client;
    SInt64 frames = 0;
    UInt32 size;
    OSStatus status;

    if (!url) return NULL;
    status = ExtAudioFileOpenURL(url, &file);
    CFRelease(url);
    if (status != noErr) return NULL;

    size = sizeof(source);
    memset(&source, 0, sizeof(source));
    if (ExtAudioFileGetProperty(file, kExtAudioFileProperty_FileDataFormat, &size, &source) != noErr
        || source.mChannelsPerFrame == 0 || source.mSampleRate <= 0) {
        ExtAudioFileDispose(file);
        return NULL;
    }
    memset(&client, 0, sizeof(client));
    client.mSampleRate = source.mSampleRate;
    client.mFormatID = kAudioFormatLinearPCM;
    client.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    client.mBitsPerChannel = 16;
    client.mChannelsPerFrame = source.mChannelsPerFrame;
    client.mBytesPerFrame = client.mChannelsPerFrame * 2;
    client.mFramesPerPacket = 1;
    client.mBytesPerPacket = client.mBytesPerFrame;
    if (ExtAudioFileSetProperty(file, kExtAudioFileProperty_ClientDataFormat, sizeof(client), &client) != noErr) {
        ExtAudioFileDispose(file);
        return NULL;
    }
    size = sizeof(frames);
    ExtAudioFileGetProperty(file, kExtAudioFileProperty_FileLengthFrames, &size, &frames);

    d = (audio_mf_decoder*) malloc(sizeof(audio_mf_decoder));
    if (!d) {
        ExtAudioFileDispose(file);
        return NULL;
    }
    d->file = file;
    d->rate = (int) source.mSampleRate;
    d->channels = (int) source.mChannelsPerFrame;
    *l_rate = d->rate;
    *l_channels = d->channels;
    *l_duration = (LONGLONG) ((double) frames / source.mSampleRate * 1.0e7);
    return d;
}

/* 1 with `*l_got' bytes, 0 at the end of the file, -1 on an error. */
static int audio_mf_read(void* l_handle, unsigned char* l_out, int l_cap, int* l_got) {
    audio_mf_decoder* d = (audio_mf_decoder*) l_handle;
    UInt32 frames = (UInt32) (l_cap / (d->channels * 2));
    AudioBufferList list;

    *l_got = 0;
    list.mNumberBuffers = 1;
    list.mBuffers[0].mNumberChannels = (UInt32) d->channels;
    list.mBuffers[0].mDataByteSize = frames * (UInt32) d->channels * 2;
    list.mBuffers[0].mData = l_out;
    if (ExtAudioFileRead(d->file, &frames, &list) != noErr) return -1;
    if (frames == 0) return 0;
    *l_got = (int) frames * d->channels * 2;
    return 1;
}

static int audio_mf_seek(void* l_handle, LONGLONG l_at) {
    audio_mf_decoder* d = (audio_mf_decoder*) l_handle;
    return ExtAudioFileSeek(d->file, (SInt64) ((double) l_at / 1.0e7 * d->rate)) == noErr ? 1 : 0;
}

static LONGLONG audio_mf_position(void* l_handle) {
    audio_mf_decoder* d = (audio_mf_decoder*) l_handle;
    SInt64 frame = 0;
    if (ExtAudioFileTell(d->file, &frame) != noErr) return 0;
    return (LONGLONG) ((double) frame / d->rate * 1.0e7);
}

static void audio_mf_close(void* l_handle) {
    audio_mf_decoder* d = (audio_mf_decoder*) l_handle;
    ExtAudioFileDispose(d->file);
    free(d);
}

#endif /* AUDIO_MF_MAC_H */
