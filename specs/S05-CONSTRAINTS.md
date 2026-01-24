# S05 - Constraints: simple_audio

**Status:** BACKWASH (reverse-engineered from implementation)
**Date:** 2026-01-23

---

## 1. Audio Format Constraints

### Sample Rate

| Constraint | Value | Rationale |
|------------|-------|-----------|
| Minimum | > 0 | Must be positive |
| Common Values | 8000, 16000, 22050, 44100, 48000, 96000 | Standard audio rates |
| Maximum | Device dependent | WASAPI negotiates with hardware |

### Channels

| Constraint | Value | Rationale |
|------------|-------|-----------|
| Minimum | 1 | Mono |
| Maximum | 8 | 7.1 surround |
| Common Values | 1 (mono), 2 (stereo), 6 (5.1), 8 (7.1) | Standard configurations |

### Bits Per Sample

| Constraint | Allowed Values | Rationale |
|------------|----------------|-----------|
| 8-bit | 8 | Legacy, unsigned |
| 16-bit | 16 | CD quality, signed |
| 24-bit | 24 | Professional audio |
| 32-bit | 32 | Maximum precision |

### Sample Value Range

| Bit Depth | Range (Raw) | Range (Normalized) |
|-----------|-------------|-------------------|
| 8-bit | 0 to 255 | -1.0 to 1.0 (via (x-128)/128) |
| 16-bit | -32768 to 32767 | -1.0 to 1.0 (via x/32768) |
| 24-bit | -8388608 to 8388607 | -1.0 to 1.0 (via x/8388608) |
| 32-bit | -2147483648 to 2147483647 | -1.0 to 1.0 (via x/2147483648) |

---

## 2. Device Constraints

### Device Direction

| Constraint | Description |
|------------|-------------|
| Output devices | Can only create output streams |
| Input devices | Can only create input streams |
| Mutual exclusion | A device is either output OR input, never both |

### Device Validity

| Constraint | Check | Action on Failure |
|------------|-------|-------------------|
| Handle non-null | handle /= default_pointer | Return Void or raise error |
| Device present | Device still connected | refresh to update list |

---

## 3. Stream Constraints

### Stream State Machine

```
[Created] --start--> [Running] --stop--> [Stopped] --start--> [Running]
    |                    |                   |
    +--close-->          +--close-->         +--close--> [Closed]
```

| State | is_started | is_valid | Allowed Operations |
|-------|------------|----------|-------------------|
| Created | False | True | start, close |
| Running | True | True | stop, read/write, close |
| Stopped | False | True | start, close |
| Closed | False | False | None |

### Format Matching

| Constraint | Description |
|------------|-------------|
| Buffer-Stream Match | Buffer channels and bits_per_sample must match stream |
| Direction Match | write requires is_output; read requires is_input |

---

## 4. Buffer Constraints

### Buffer Size

| Constraint | Value |
|------------|-------|
| Minimum frames | > 0 |
| Maximum frames | Memory dependent |
| Typical size | 256-8192 frames per write |

### WAV File Constraints

| Constraint | Value | Rationale |
|------------|-------|-----------|
| Format | RIFF/WAVE | Standard WAV container |
| Audio Format | PCM (1) | No compressed audio |
| Minimum file size | 44 bytes | Header size |
| Byte order | Little-endian | WAV specification |

### Index Bounds

| Access | Valid Range |
|--------|-------------|
| Frame index | 0 to frame_count - 1 |
| Channel index | 0 to channels - 1 |

---

## 5. Platform Constraints

### Windows Requirements

| Constraint | Value |
|------------|-------|
| Minimum OS | Windows 7 |
| API | WASAPI (Windows Audio Session API) |
| COM | Must be initialized |
| Mode | Shared mode only |

### Memory Constraints

| Resource | Constraint |
|----------|------------|
| Device list | Cached, must call refresh to update |
| Stream handles | Must call close to release |
| Buffer data | MANAGED_POINTER, Eiffel-managed memory |

---

## 6. Thread Safety

| Component | Thread Safety |
|-----------|---------------|
| SIMPLE_AUDIO | Not thread-safe |
| AUDIO_DEVICE | Read-only after creation |
| AUDIO_STREAM | Single-threaded use only |
| AUDIO_BUFFER | Not thread-safe |

**SCOOP Consideration:** For SCOOP compatibility, each component should be a separate processor.

---

## 7. Error Handling

| Scenario | Behavior |
|----------|----------|
| Device not found | Returns Void |
| Stream creation failure | Returns Void |
| WAV load failure | is_valid = False, last_error set |
| Write to input stream | Precondition violation |
| Read from output stream | Precondition violation |
