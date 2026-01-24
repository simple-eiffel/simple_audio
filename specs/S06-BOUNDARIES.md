# S06 - Boundaries: simple_audio

**Status:** BACKWASH (reverse-engineered from implementation)
**Date:** 2026-01-23

---

## 1. External Boundaries

### Operating System Interface

```
+-------------------+
|   simple_audio    |
+-------------------+
         |
         | Inline C
         v
+-------------------+
|   audio_bridge.h  |
+-------------------+
         |
         | COM/WASAPI
         v
+-------------------+
|  Windows Audio    |
|  Session API      |
+-------------------+
         |
         v
+-------------------+
|  Audio Hardware   |
+-------------------+
```

### WASAPI Interface Points

| Function | Direction | Purpose |
|----------|-----------|---------|
| audio_init() | Eiffel -> C | Initialize COM and WASAPI |
| audio_cleanup() | Eiffel -> C | Release WASAPI resources |
| audio_device_count() | Eiffel -> C | Get number of devices |
| audio_get_device() | Eiffel -> C | Get device by index |
| audio_get_default_device() | Eiffel -> C | Get default endpoint |
| audio_stream_create() | Eiffel -> C | Create audio stream |
| audio_stream_start/stop() | Eiffel -> C | Control playback |
| audio_stream_read/write() | Eiffel -> C | Transfer audio data |

---

## 2. Internal Module Boundaries

### Facade Pattern

```
Client Code
     |
     v
+-------------------+
|   SIMPLE_AUDIO    |  <-- Facade (main entry point)
+-------------------+
     |
     +--------+--------+
     |        |        |
     v        v        v
+--------+ +--------+ +--------+
|DEVICE  | |STREAM  | |BUFFER  |
+--------+ +--------+ +--------+
```

### Module Responsibilities

| Module | Responsibility | Does NOT Handle |
|--------|----------------|-----------------|
| SIMPLE_AUDIO | Device enumeration, stream factory | Audio data processing |
| AUDIO_DEVICE | Device properties | Stream operations |
| AUDIO_STREAM | Real-time I/O | Data format conversion |
| AUDIO_BUFFER | Data storage, WAV I/O | Device operations |

---

## 3. Data Flow Boundaries

### Playback Flow

```
Application
     | (normalized samples)
     v
AUDIO_BUFFER
     | (raw PCM bytes)
     v
AUDIO_STREAM.write()
     | (via C bridge)
     v
WASAPI Render Client
     |
     v
Audio Hardware (DAC)
     |
     v
Speaker
```

### Recording Flow

```
Microphone
     |
     v
Audio Hardware (ADC)
     |
     v
WASAPI Capture Client
     | (via C bridge)
     v
AUDIO_STREAM.read()
     | (raw PCM bytes)
     v
AUDIO_BUFFER
     | (normalized samples)
     v
Application
```

---

## 4. Memory Boundaries

### Eiffel Managed Memory

| Component | Memory Type |
|-----------|-------------|
| SIMPLE_AUDIO | Eiffel heap |
| AUDIO_DEVICE lists | Eiffel ARRAYED_LIST |
| AUDIO_BUFFER.data | MANAGED_POINTER (Eiffel-managed) |

### Native Memory

| Component | Memory Type | Ownership |
|-----------|-------------|-----------|
| Device handles | WASAPI pointers | WASAPI (released by Eiffel) |
| Stream handles | WASAPI pointers | WASAPI (released by Eiffel) |
| Audio client | COM object | WASAPI |

### Memory Transfer

```
AUDIO_BUFFER.data (MANAGED_POINTER)
     |
     | .item -> raw pointer
     v
C inline external
     |
     | memcpy
     v
WASAPI Buffer
```

---

## 5. Format Boundaries

### WAV File Format Boundary

```
File System
     | (binary file)
     v
+------------------+
|  WAV Parser      |
|  (AUDIO_BUFFER)  |
+------------------+
     |
     | Validated PCM
     v
AUDIO_BUFFER.data
```

### Format Validation Points

| Boundary | Validation |
|----------|------------|
| WAV load | RIFF signature, WAVE format, PCM only |
| Stream create | Valid sample rate, channels, bits |
| Stream write | Buffer format matches stream format |
| Sample access | Frame and channel in bounds |

---

## 6. Error Boundaries

### Error Propagation

```
Hardware Error
     |
     v
WASAPI Error Code
     |
     v
C Bridge Return Value (0/non-zero)
     |
     v
Eiffel Void or Boolean
     |
     v
Client Application
```

### Error Handling Strategy

| Layer | Error Indication | Recovery |
|-------|-----------------|----------|
| C Bridge | Returns 0 on failure | Return Void |
| AUDIO_DEVICE | is_valid query | Check before use |
| AUDIO_STREAM | is_valid, is_started | Check state |
| AUDIO_BUFFER | is_valid, last_error | Check after creation |

---

## 7. Scope Boundaries

### In Scope

- Device enumeration (input/output)
- Real-time PCM audio I/O
- WAV file loading/saving
- Sample-level access
- Tone generation (sine wave)

### Out of Scope

- Compressed audio formats (MP3, AAC, FLAC)
- Audio effects (reverb, EQ, compression)
- Audio mixing
- MIDI support
- Cross-platform support
- Exclusive mode (ultra-low latency)
- Sample rate conversion
- Network audio streaming

### Future Extensions (Phase 2+)

| Feature | Potential Integration |
|---------|----------------------|
| Encoded formats | simple_ffmpeg |
| Mixing | Internal mixer class |
| Effects | Plugin architecture |
| Linux support | ALSA/PulseAudio backend |
