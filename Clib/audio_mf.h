/* audio_mf.h - compressed audio decoded through Media Foundation
   (simple_audio 0.2.0, simple_bible GW-25: MP3 for the audio Bible).

   A Media Foundation source reader turns a file (MP3, AAC/M4A, WMA, WAV -
   whatever Windows decodes) into 16-bit PCM at the file's own rate and
   channel count, a chunk at a time, so an hour of audio never sits in
   memory decoded. Seeking moves the reader; reading resumes from there.

   The decoder keeps what a caller's buffer could not take (`pending') and
   hands it over first on the next read. One decoder per handle; a handle
   belongs to one thread (the reader is not shared).

   ISE builds C with _WIN32_WINNT/WINVER 0x0500, which hides the source
   reader (Windows 7). Raising it for the whole library breaks
   audio_bridge.h's kernel-streaming workaround, so only the Media
   Foundation includes below see Windows 10 - those headers test WINVER
   when they are included, even when windows.h came in earlier in the
   same generated C file. Identifiers carry the l_ / audio_mf_ prefixes. */

#ifndef AUDIO_MF_H
#define AUDIO_MF_H

#ifndef COBJMACROS
#define COBJMACROS
#endif

#include <stdlib.h>
#include <string.h>
#include <windows.h>
#pragma push_macro("WINVER")
#pragma push_macro("_WIN32_WINNT")
#undef WINVER
#undef _WIN32_WINNT
#define WINVER 0x0A00
#define _WIN32_WINNT 0x0A00
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <mferror.h>
#pragma pop_macro("_WIN32_WINNT")
#pragma pop_macro("WINVER")

#pragma comment(lib, "mfplat.lib")
#pragma comment(lib, "mfreadwrite.lib")
#pragma comment(lib, "mfuuid.lib")
#pragma comment(lib, "ole32.lib")

typedef struct {
    IMFSourceReader* reader;
    int rate;
    int channels;
    LONGLONG duration;        /* 100-nanosecond units */
    LONGLONG position;        /* of the next frame handed out */
    int at_end;
    unsigned char* pending;   /* decoded bytes a caller could not take yet */
    int pending_count;
    int pending_at;
} audio_mf_decoder;

__declspec(selectany) volatile LONG audio_mf_started = 0;

/* Media Foundation, once per process; COM on this thread. */
static int audio_mf_start(void) {
    HRESULT l_hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
    (void)l_hr;   /* S_FALSE or RPC_E_CHANGED_MODE: COM is already up here */
    if (InterlockedCompareExchange(&audio_mf_started, 1, 0) == 0) {
        if (FAILED(MFStartup(MF_VERSION, MFSTARTUP_LITE))) {
            InterlockedExchange(&audio_mf_started, 0);
            return 0;
        }
    }
    return 1;
}

/* Open `l_path' for 16-bit PCM; NULL when Windows cannot decode it. */
static void* audio_mf_open(const wchar_t* l_path, int* l_rate, int* l_channels, LONGLONG* l_duration) {
    audio_mf_decoder* l_d;
    IMFSourceReader* l_reader = NULL;
    IMFMediaType* l_want = NULL;
    IMFMediaType* l_got = NULL;
    PROPVARIANT l_var;
    UINT32 l_rate_value = 0, l_channels_value = 0;
    if (!l_path || !audio_mf_start()) return NULL;
    if (FAILED(MFCreateSourceReaderFromURL(l_path, NULL, &l_reader))) return NULL;
    IMFSourceReader_SetStreamSelection(l_reader, (DWORD)MF_SOURCE_READER_ALL_STREAMS, FALSE);
    IMFSourceReader_SetStreamSelection(l_reader, (DWORD)MF_SOURCE_READER_FIRST_AUDIO_STREAM, TRUE);
    if (FAILED(MFCreateMediaType(&l_want))) {
        IMFSourceReader_Release(l_reader);
        return NULL;
    }
    IMFMediaType_SetGUID(l_want, &MF_MT_MAJOR_TYPE, &MFMediaType_Audio);
    IMFMediaType_SetGUID(l_want, &MF_MT_SUBTYPE, &MFAudioFormat_PCM);
    IMFMediaType_SetUINT32(l_want, &MF_MT_AUDIO_BITS_PER_SAMPLE, 16);
    if (FAILED(IMFSourceReader_SetCurrentMediaType(l_reader, (DWORD)MF_SOURCE_READER_FIRST_AUDIO_STREAM, NULL, l_want))) {
        IMFMediaType_Release(l_want);
        IMFSourceReader_Release(l_reader);
        return NULL;
    }
    IMFMediaType_Release(l_want);
    if (FAILED(IMFSourceReader_GetCurrentMediaType(l_reader, (DWORD)MF_SOURCE_READER_FIRST_AUDIO_STREAM, &l_got))) {
        IMFSourceReader_Release(l_reader);
        return NULL;
    }
    IMFMediaType_GetUINT32(l_got, &MF_MT_AUDIO_SAMPLES_PER_SECOND, &l_rate_value);
    IMFMediaType_GetUINT32(l_got, &MF_MT_AUDIO_NUM_CHANNELS, &l_channels_value);
    IMFMediaType_Release(l_got);
    if (l_rate_value == 0 || l_channels_value == 0) {
        IMFSourceReader_Release(l_reader);
        return NULL;
    }
    l_d = (audio_mf_decoder*)calloc(1, sizeof(audio_mf_decoder));
    if (!l_d) {
        IMFSourceReader_Release(l_reader);
        return NULL;
    }
    l_d->reader = l_reader;
    l_d->rate = (int)l_rate_value;
    l_d->channels = (int)l_channels_value;
    PropVariantInit(&l_var);
    if (SUCCEEDED(IMFSourceReader_GetPresentationAttribute(l_reader, (DWORD)MF_SOURCE_READER_MEDIASOURCE, &MF_PD_DURATION, &l_var))) {
        if (l_var.vt == VT_UI8) l_d->duration = (LONGLONG)l_var.uhVal.QuadPart;
        PropVariantClear(&l_var);
    }
    *l_rate = l_d->rate;
    *l_channels = l_d->channels;
    *l_duration = l_d->duration;
    return l_d;
}

/* Hand over pending bytes into `l_out' (room for `l_cap' bytes); the count. */
static int audio_mf_take_pending(audio_mf_decoder* l_d, unsigned char* l_out, int l_cap) {
    int l_n = l_d->pending_count - l_d->pending_at;
    if (l_n <= 0) return 0;
    if (l_n > l_cap) l_n = l_cap;
    memcpy(l_out, l_d->pending + l_d->pending_at, (size_t)l_n);
    l_d->pending_at += l_n;
    if (l_d->pending_at >= l_d->pending_count) {
        l_d->pending_count = 0;
        l_d->pending_at = 0;
    }
    return l_n;
}

/* Decoded bytes into `l_out' (room for `l_cap' bytes, a whole number of
   frames). 1 with `*l_got' bytes, 0 at the end, -1 on an error. */
static int audio_mf_read(void* l_handle, unsigned char* l_out, int l_cap, int* l_got) {
    audio_mf_decoder* l_d = (audio_mf_decoder*)l_handle;
    IMFSample* l_sample = NULL;
    IMFMediaBuffer* l_buffer = NULL;
    BYTE* l_bytes = NULL;
    DWORD l_flags = 0, l_length = 0, l_index = 0;
    LONGLONG l_time = 0;
    int l_frame = 2 * (l_d ? l_d->channels : 1);
    int l_n;
    *l_got = 0;
    if (!l_d || !l_out || l_cap < l_frame) return -1;
    l_cap -= l_cap % l_frame;
    l_n = audio_mf_take_pending(l_d, l_out, l_cap);
    if (l_n > 0) {
        *l_got = l_n;
        l_d->position += (LONGLONG)(l_n / l_frame) * 10000000 / l_d->rate;
        return 1;
    }
    while (!l_d->at_end) {
        if (FAILED(IMFSourceReader_ReadSample(l_d->reader, (DWORD)MF_SOURCE_READER_FIRST_AUDIO_STREAM, 0,
                                              &l_index, &l_flags, &l_time, &l_sample))) return -1;
        if (l_flags & MF_SOURCE_READERF_ENDOFSTREAM) {
            l_d->at_end = 1;
            if (l_sample) IMFSample_Release(l_sample);
            break;
        }
        if (!l_sample) continue;   /* a stream tick or a format note: read on */
        if (FAILED(IMFSample_ConvertToContiguousBuffer(l_sample, &l_buffer))) {
            IMFSample_Release(l_sample);
            return -1;
        }
        if (SUCCEEDED(IMFMediaBuffer_Lock(l_buffer, &l_bytes, NULL, &l_length)) && l_length > 0) {
            l_d->position = l_time;
            l_n = (int)l_length < l_cap ? (int)l_length : l_cap;
            memcpy(l_out, l_bytes, (size_t)l_n);
            if ((int)l_length > l_n) {
                unsigned char* l_keep = (unsigned char*)realloc(l_d->pending, (size_t)((int)l_length - l_n));
                if (l_keep) {
                    l_d->pending = l_keep;
                    memcpy(l_d->pending, l_bytes + l_n, (size_t)((int)l_length - l_n));
                    l_d->pending_count = (int)l_length - l_n;
                    l_d->pending_at = 0;
                }
            }
            IMFMediaBuffer_Unlock(l_buffer);
            IMFMediaBuffer_Release(l_buffer);
            IMFSample_Release(l_sample);
            *l_got = l_n;
            l_d->position += (LONGLONG)(l_n / l_frame) * 10000000 / l_d->rate;
            return 1;
        }
        IMFMediaBuffer_Release(l_buffer);
        IMFSample_Release(l_sample);
    }
    return 0;
}

/* Move to `l_at' (100-nanosecond units). 1 when the reader moved. */
static int audio_mf_seek(void* l_handle, LONGLONG l_at) {
    audio_mf_decoder* l_d = (audio_mf_decoder*)l_handle;
    PROPVARIANT l_var;
    HRESULT l_hr;
    if (!l_d) return 0;
    PropVariantInit(&l_var);
    l_var.vt = VT_I8;
    l_var.hVal.QuadPart = l_at;
    l_hr = IMFSourceReader_SetCurrentPosition(l_d->reader, &GUID_NULL, &l_var);
    PropVariantClear(&l_var);
    if (FAILED(l_hr)) return 0;
    l_d->pending_count = 0;
    l_d->pending_at = 0;
    l_d->at_end = 0;
    l_d->position = l_at;
    return 1;
}

static LONGLONG audio_mf_position(void* l_handle) {
    return l_handle ? ((audio_mf_decoder*)l_handle)->position : 0;
}

static void audio_mf_close(void* l_handle) {
    audio_mf_decoder* l_d = (audio_mf_decoder*)l_handle;
    if (!l_d) return;
    if (l_d->reader) IMFSourceReader_Release(l_d->reader);
    free(l_d->pending);
    free(l_d);
}

#endif
