/*
 * audio_bridge.h - WASAPI bridge for simple_audio
 *
 * Provides Windows Audio Session API access for Eiffel.
 * Uses Eric Bezault inline C pattern.
 */

#ifndef AUDIO_BRIDGE_H
#define AUDIO_BRIDGE_H

#include <windows.h>
#include <mmdeviceapi.h>
#include <audioclient.h>
#include <functiondiscoverykeys_devpkey.h>
#include <initguid.h>

/* GUIDs for WASAPI */
DEFINE_GUID(CLSID_MMDeviceEnumerator_Local, 0xBCDE0395, 0xE52F, 0x467C, 0x8E, 0x3D, 0xC4, 0x57, 0x92, 0x91, 0x69, 0x2E);
DEFINE_GUID(IID_IMMDeviceEnumerator_Local, 0xA95664D2, 0x9614, 0x4F35, 0xA7, 0x46, 0xDE, 0x8D, 0xB6, 0x36, 0x17, 0xE6);
DEFINE_GUID(IID_IAudioClient_Local, 0x1CB9AD4C, 0xDBFA, 0x4c32, 0xB1, 0x78, 0xC2, 0xF5, 0x68, 0xA7, 0x03, 0xB2);
DEFINE_GUID(IID_IAudioRenderClient_Local, 0xF294ACFC, 0x3146, 0x4483, 0xA7, 0xBF, 0xAD, 0xDC, 0xA7, 0xC2, 0x60, 0xE2);
DEFINE_GUID(IID_IAudioCaptureClient_Local, 0xC8ADBD64, 0xE71E, 0x48a0, 0xA4, 0xDE, 0x18, 0x5C, 0x39, 0x5C, 0xD3, 0x17);

/* Device flow direction */
#define AUDIO_FLOW_RENDER  0
#define AUDIO_FLOW_CAPTURE 1

/* Static enumerator (one per process) */
static IMMDeviceEnumerator* g_enumerator = NULL;

/* Initialize COM and get enumerator */
static int audio_init(void) {
    HRESULT hr;

    if (g_enumerator != NULL) return 1;

    hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
    if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) return 0;

    hr = CoCreateInstance(
        &CLSID_MMDeviceEnumerator_Local,
        NULL,
        CLSCTX_ALL,
        &IID_IMMDeviceEnumerator_Local,
        (void**)&g_enumerator
    );

    return SUCCEEDED(hr) ? 1 : 0;
}

/* Cleanup */
static void audio_cleanup(void) {
    if (g_enumerator) {
        g_enumerator->lpVtbl->Release(g_enumerator);
        g_enumerator = NULL;
    }
    CoUninitialize();
}

/* Count audio devices */
static int audio_device_count(int flow) {
    IMMDeviceCollection* collection = NULL;
    UINT count = 0;
    HRESULT hr;
    EDataFlow data_flow = (flow == AUDIO_FLOW_RENDER) ? eRender : eCapture;

    if (!g_enumerator) {
        if (!audio_init()) return 0;
    }

    hr = g_enumerator->lpVtbl->EnumAudioEndpoints(
        g_enumerator, data_flow, DEVICE_STATE_ACTIVE, &collection
    );

    if (SUCCEEDED(hr) && collection) {
        collection->lpVtbl->GetCount(collection, &count);
        collection->lpVtbl->Release(collection);
    }

    return (int)count;
}

/* Get device handle by index */
static void* audio_get_device(int flow, int index) {
    IMMDeviceCollection* collection = NULL;
    IMMDevice* device = NULL;
    HRESULT hr;
    EDataFlow data_flow = (flow == AUDIO_FLOW_RENDER) ? eRender : eCapture;

    if (!g_enumerator) {
        if (!audio_init()) return NULL;
    }

    hr = g_enumerator->lpVtbl->EnumAudioEndpoints(
        g_enumerator, data_flow, DEVICE_STATE_ACTIVE, &collection
    );

    if (SUCCEEDED(hr) && collection) {
        hr = collection->lpVtbl->Item(collection, (UINT)index, &device);
        collection->lpVtbl->Release(collection);
        if (FAILED(hr)) device = NULL;
    }

    return device;
}

/* Get default device */
static void* audio_get_default_device(int flow) {
    IMMDevice* device = NULL;
    HRESULT hr;
    EDataFlow data_flow = (flow == AUDIO_FLOW_RENDER) ? eRender : eCapture;

    if (!g_enumerator) {
        if (!audio_init()) return NULL;
    }

    hr = g_enumerator->lpVtbl->GetDefaultAudioEndpoint(
        g_enumerator, data_flow, eConsole, &device
    );

    return SUCCEEDED(hr) ? device : NULL;
}

/* Get device friendly name */
static int audio_get_device_name(void* device_ptr, wchar_t* buffer, int buffer_size) {
    IMMDevice* device = (IMMDevice*)device_ptr;
    IPropertyStore* props = NULL;
    PROPVARIANT var;
    HRESULT hr;

    if (!device) return 0;

    hr = device->lpVtbl->OpenPropertyStore(device, STGM_READ, &props);
    if (FAILED(hr) || !props) return 0;

    PropVariantInit(&var);
    hr = props->lpVtbl->GetValue(props, &PKEY_Device_FriendlyName, &var);

    if (SUCCEEDED(hr) && var.vt == VT_LPWSTR && var.pwszVal) {
        wcsncpy(buffer, var.pwszVal, buffer_size - 1);
        buffer[buffer_size - 1] = 0;
        PropVariantClear(&var);
        props->lpVtbl->Release(props);
        return 1;
    }

    PropVariantClear(&var);
    props->lpVtbl->Release(props);
    return 0;
}

/* Get device ID */
static int audio_get_device_id(void* device_ptr, wchar_t* buffer, int buffer_size) {
    IMMDevice* device = (IMMDevice*)device_ptr;
    LPWSTR id = NULL;
    HRESULT hr;

    if (!device) return 0;

    hr = device->lpVtbl->GetId(device, &id);
    if (SUCCEEDED(hr) && id) {
        wcsncpy(buffer, id, buffer_size - 1);
        buffer[buffer_size - 1] = 0;
        CoTaskMemFree(id);
        return 1;
    }

    return 0;
}

/* Release device */
static void audio_release_device(void* device_ptr) {
    IMMDevice* device = (IMMDevice*)device_ptr;
    if (device) {
        device->lpVtbl->Release(device);
    }
}

/* Audio stream structure */
typedef struct {
    IMMDevice* device;
    IAudioClient* client;
    IAudioRenderClient* render;
    IAudioCaptureClient* capture;
    WAVEFORMATEX* format;
    UINT32 buffer_frames;
    int is_render;
    int is_started;
} AudioStream;

/* Create audio stream */
static void* audio_stream_create(void* device_ptr, int is_render, int sample_rate, int channels, int bits_per_sample) {
    IMMDevice* device = (IMMDevice*)device_ptr;
    AudioStream* stream;
    WAVEFORMATEX* format;
    HRESULT hr;
    REFERENCE_TIME duration = 10000000; /* 1 second buffer */

    if (!device) return NULL;

    stream = (AudioStream*)calloc(1, sizeof(AudioStream));
    if (!stream) return NULL;

    format = (WAVEFORMATEX*)calloc(1, sizeof(WAVEFORMATEX));
    if (!format) {
        free(stream);
        return NULL;
    }

    format->wFormatTag = WAVE_FORMAT_PCM;
    format->nChannels = (WORD)channels;
    format->nSamplesPerSec = (DWORD)sample_rate;
    format->wBitsPerSample = (WORD)bits_per_sample;
    format->nBlockAlign = format->nChannels * format->wBitsPerSample / 8;
    format->nAvgBytesPerSec = format->nSamplesPerSec * format->nBlockAlign;
    format->cbSize = 0;

    stream->format = format;
    stream->is_render = is_render;
    stream->device = device;
    device->lpVtbl->AddRef(device);

    hr = device->lpVtbl->Activate(
        device,
        &IID_IAudioClient_Local,
        CLSCTX_ALL,
        NULL,
        (void**)&stream->client
    );

    if (FAILED(hr)) goto error;

    hr = stream->client->lpVtbl->Initialize(
        stream->client,
        AUDCLNT_SHAREMODE_SHARED,
        0,
        duration,
        0,
        format,
        NULL
    );

    if (FAILED(hr)) goto error;

    hr = stream->client->lpVtbl->GetBufferSize(stream->client, &stream->buffer_frames);
    if (FAILED(hr)) goto error;

    if (is_render) {
        hr = stream->client->lpVtbl->GetService(
            stream->client,
            &IID_IAudioRenderClient_Local,
            (void**)&stream->render
        );
    } else {
        hr = stream->client->lpVtbl->GetService(
            stream->client,
            &IID_IAudioCaptureClient_Local,
            (void**)&stream->capture
        );
    }

    if (FAILED(hr)) goto error;

    return stream;

error:
    if (stream->client) stream->client->lpVtbl->Release(stream->client);
    if (stream->device) stream->device->lpVtbl->Release(stream->device);
    free(format);
    free(stream);
    return NULL;
}

/* Start stream */
static int audio_stream_start(void* stream_ptr) {
    AudioStream* stream = (AudioStream*)stream_ptr;
    HRESULT hr;

    if (!stream || !stream->client || stream->is_started) return 0;

    hr = stream->client->lpVtbl->Start(stream->client);
    if (SUCCEEDED(hr)) {
        stream->is_started = 1;
        return 1;
    }
    return 0;
}

/* Stop stream */
static int audio_stream_stop(void* stream_ptr) {
    AudioStream* stream = (AudioStream*)stream_ptr;
    HRESULT hr;

    if (!stream || !stream->client || !stream->is_started) return 0;

    hr = stream->client->lpVtbl->Stop(stream->client);
    if (SUCCEEDED(hr)) {
        stream->is_started = 0;
        return 1;
    }
    return 0;
}

/* Get available frames for writing (render) */
static int audio_stream_get_available_frames(void* stream_ptr) {
    AudioStream* stream = (AudioStream*)stream_ptr;
    UINT32 padding = 0;
    HRESULT hr;

    if (!stream || !stream->client) return 0;

    hr = stream->client->lpVtbl->GetCurrentPadding(stream->client, &padding);
    if (FAILED(hr)) return 0;

    return (int)(stream->buffer_frames - padding);
}

/* Write audio data (render) */
static int audio_stream_write(void* stream_ptr, const void* data, int frame_count) {
    AudioStream* stream = (AudioStream*)stream_ptr;
    BYTE* buffer;
    HRESULT hr;
    int bytes_to_copy;

    if (!stream || !stream->render || !data || frame_count <= 0) return 0;

    hr = stream->render->lpVtbl->GetBuffer(stream->render, (UINT32)frame_count, &buffer);
    if (FAILED(hr)) return 0;

    bytes_to_copy = frame_count * stream->format->nBlockAlign;
    memcpy(buffer, data, bytes_to_copy);

    hr = stream->render->lpVtbl->ReleaseBuffer(stream->render, (UINT32)frame_count, 0);
    return SUCCEEDED(hr) ? frame_count : 0;
}

/* Read audio data (capture) */
static int audio_stream_read(void* stream_ptr, void* data, int max_frames) {
    AudioStream* stream = (AudioStream*)stream_ptr;
    BYTE* buffer;
    UINT32 frames_available;
    DWORD flags;
    HRESULT hr;
    int bytes_to_copy;

    if (!stream || !stream->capture || !data || max_frames <= 0) return 0;

    hr = stream->capture->lpVtbl->GetBuffer(
        stream->capture, &buffer, &frames_available, &flags, NULL, NULL
    );

    if (FAILED(hr) || frames_available == 0) return 0;

    if ((int)frames_available > max_frames) {
        frames_available = (UINT32)max_frames;
    }

    if (flags & AUDCLNT_BUFFERFLAGS_SILENT) {
        bytes_to_copy = frames_available * stream->format->nBlockAlign;
        memset(data, 0, bytes_to_copy);
    } else {
        bytes_to_copy = frames_available * stream->format->nBlockAlign;
        memcpy(data, buffer, bytes_to_copy);
    }

    stream->capture->lpVtbl->ReleaseBuffer(stream->capture, frames_available);
    return (int)frames_available;
}

/* Get stream format info */
static int audio_stream_get_sample_rate(void* stream_ptr) {
    AudioStream* stream = (AudioStream*)stream_ptr;
    return stream && stream->format ? (int)stream->format->nSamplesPerSec : 0;
}

static int audio_stream_get_channels(void* stream_ptr) {
    AudioStream* stream = (AudioStream*)stream_ptr;
    return stream && stream->format ? (int)stream->format->nChannels : 0;
}

static int audio_stream_get_bits_per_sample(void* stream_ptr) {
    AudioStream* stream = (AudioStream*)stream_ptr;
    return stream && stream->format ? (int)stream->format->wBitsPerSample : 0;
}

static int audio_stream_get_buffer_size(void* stream_ptr) {
    AudioStream* stream = (AudioStream*)stream_ptr;
    return stream ? (int)stream->buffer_frames : 0;
}

/* Destroy stream */
static void audio_stream_destroy(void* stream_ptr) {
    AudioStream* stream = (AudioStream*)stream_ptr;

    if (!stream) return;

    if (stream->is_started) {
        stream->client->lpVtbl->Stop(stream->client);
    }

    if (stream->render) stream->render->lpVtbl->Release(stream->render);
    if (stream->capture) stream->capture->lpVtbl->Release(stream->capture);
    if (stream->client) stream->client->lpVtbl->Release(stream->client);
    if (stream->device) stream->device->lpVtbl->Release(stream->device);

    free(stream->format);
    free(stream);
}

#endif /* AUDIO_BRIDGE_H */
