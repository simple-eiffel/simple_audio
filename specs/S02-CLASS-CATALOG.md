# S02 - Class Catalog: simple_audio

**Status:** BACKWASH (reverse-engineered from implementation)
**Date:** 2026-01-23

---

## 1. Class Hierarchy

```
SIMPLE_AUDIO (facade)
    |
    +-- AUDIO_DEVICE (device representation)
    |
    +-- AUDIO_STREAM (active stream)
    |
    +-- AUDIO_BUFFER (PCM data container)
```

## 2. Class Descriptions

### SIMPLE_AUDIO (Facade)

| Attribute | Value |
|-----------|-------|
| Role | Main entry point and facade |
| Responsibility | Device enumeration, stream factory |
| Creatable | Yes (via `make`) |
| Inherits | None |

**Key Collaborators:**
- Creates and returns AUDIO_DEVICE instances
- Creates and returns AUDIO_STREAM instances
- Uses inline C for WASAPI interop

### AUDIO_DEVICE

| Attribute | Value |
|-----------|-------|
| Role | Audio endpoint representation |
| Responsibility | Store device properties (name, ID, direction) |
| Creatable | Yes (via `make_from_handle`, `make_empty`) |
| Inherits | None |

**Key Collaborators:**
- Created by SIMPLE_AUDIO
- Passed to stream creation methods

### AUDIO_STREAM

| Attribute | Value |
|-----------|-------|
| Role | Active audio I/O channel |
| Responsibility | Start/stop stream, read/write audio data |
| Creatable | Yes (via `make_from_handle`) |
| Inherits | None |

**Key Collaborators:**
- Created by SIMPLE_AUDIO.create_output_stream / create_input_stream
- Uses AUDIO_BUFFER for data transfer

### AUDIO_BUFFER

| Attribute | Value |
|-----------|-------|
| Role | PCM audio data container |
| Responsibility | Store raw audio, WAV file I/O, sample manipulation |
| Creatable | Yes (via `make`, `make_empty`, `make_from_wav`) |
| Inherits | None |

**Key Collaborators:**
- Passed to AUDIO_STREAM for read/write operations
- Self-contained WAV file loading/saving

## 3. Feature Groupings

### SIMPLE_AUDIO Features

| Category | Features |
|----------|----------|
| Access | output_devices, input_devices, default_output, default_input, output_device_count, input_device_count |
| Status | is_initialized |
| Operations | refresh, create_output_stream, create_input_stream |
| Cleanup | dispose |

### AUDIO_DEVICE Features

| Category | Features |
|----------|----------|
| Access | name, id, handle |
| Status | is_output, is_input, is_valid |
| Comparison | same_device |
| Display | display_name |

### AUDIO_STREAM Features

| Category | Features |
|----------|----------|
| Access | handle, sample_rate, channels, bits_per_sample, bytes_per_frame, buffer_size |
| Status | is_output, is_input, is_started, is_valid, available_frames |
| Operations | start, stop, write, read |
| Cleanup | close |

### AUDIO_BUFFER Features

| Category | Features |
|----------|----------|
| Access | frame_count, channels, bits_per_sample, bytes_per_sample, bytes_per_frame, sample_rate, data, is_valid, last_error, byte_count, duration, sample_at |
| Element change | set_sample, clear |
| Export | save_to_wav |
| Generation | fill_sine_wave, fill_silence |

## 4. Visibility Matrix

| Class | SIMPLE_AUDIO | AUDIO_DEVICE | AUDIO_STREAM | AUDIO_BUFFER |
|-------|--------------|--------------|--------------|--------------|
| SIMPLE_AUDIO | - | Creates | Creates | - |
| AUDIO_DEVICE | - | - | - | - |
| AUDIO_STREAM | - | - | - | Uses |
| AUDIO_BUFFER | - | - | - | - |
