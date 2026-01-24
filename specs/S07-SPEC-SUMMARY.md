# S07 - Specification Summary: simple_audio

**Status:** BACKWASH (reverse-engineered from implementation)
**Date:** 2026-01-23

---

## 1. Library Overview

**simple_audio** is a real-time audio I/O library for Eiffel on Windows, providing access to audio devices via the Windows Audio Session API (WASAPI).

### Key Capabilities

| Capability | Description |
|------------|-------------|
| Device Enumeration | List all input/output audio devices |
| Default Device Access | Get system default playback/recording device |
| Audio Streaming | Create playback and recording streams |
| PCM Data Handling | Buffer management with sample-level access |
| WAV File I/O | Load from and save to WAV files |
| Tone Generation | Generate test signals (sine waves) |

---

## 2. Architecture Summary

### Component Count

| Component | Count |
|-----------|-------|
| Classes | 4 |
| Public Features | 45+ |
| Preconditions | 39 |
| Postconditions | 31 |
| Class Invariants | 12 |

### Design Patterns

| Pattern | Application |
|---------|-------------|
| Facade | SIMPLE_AUDIO hides WASAPI complexity |
| Factory | Stream creation via facade |
| Bridge | C inline externals to WASAPI |

---

## 3. API Quick Reference

### Device Operations

```eiffel
audio: SIMPLE_AUDIO
create audio.make

-- List devices
across audio.output_devices as dev loop
    print (dev.name + "%N")
end

-- Get default
if attached audio.default_output as dev then
    -- use dev
end
```

### Stream Operations

```eiffel
-- Create stream
if attached audio.create_output_stream (device, 44100, 2, 16) as stream then
    stream.start
    stream.write (buffer)
    stream.stop
    stream.close
end
```

### Buffer Operations

```eiffel
-- Create buffer
buffer: AUDIO_BUFFER
create buffer.make (1024, 2, 16)  -- 1024 frames, stereo, 16-bit

-- Load from WAV
create buffer.make_from_wav ("sound.wav")

-- Generate tone
buffer.fill_sine_wave (440.0, 44100)  -- 440 Hz A note

-- Access samples
sample := buffer.sample_at (0, 0)  -- frame 0, channel 0
buffer.set_sample (0, 0, 0.5)

-- Save
buffer.save_to_wav ("output.wav")
```

---

## 4. Constraint Summary

### Format Constraints

| Parameter | Allowed Values |
|-----------|----------------|
| Sample Rate | > 0 (typically 8000-192000 Hz) |
| Channels | 1-8 |
| Bits | 8, 16, 24, or 32 |

### State Constraints

| Object | Key Constraint |
|--------|----------------|
| SIMPLE_AUDIO | Must be initialized before use |
| AUDIO_STREAM | Must be started before read/write |
| AUDIO_BUFFER | Format must match stream for I/O |

---

## 5. Dependencies

### Required

| Dependency | Purpose |
|------------|---------|
| ISE base library | Core Eiffel classes |
| Windows WASAPI | Audio hardware access |
| COM runtime | WASAPI initialization |

### Optional

| Dependency | Purpose |
|------------|---------|
| simple_ffmpeg | Encoded format support (future) |

---

## 6. Platform Support

| Platform | Status |
|----------|--------|
| Windows 7+ | Supported |
| Windows 10/11 | Primary target |
| Linux | Not supported |
| macOS | Not supported |

---

## 7. Performance Characteristics

| Operation | Complexity | Notes |
|-----------|------------|-------|
| Device enumeration | O(n) | n = device count |
| Stream start/stop | O(1) | WASAPI call |
| Buffer read/write | O(n) | n = frame count |
| WAV load | O(n) | n = file size |
| Sample access | O(1) | Direct memory access |

### Latency

| Configuration | Expected Latency |
|---------------|-----------------|
| WASAPI Shared Mode | 10-30 ms |
| Default buffer | ~20 ms |

---

## 8. Completeness Assessment

### Implemented Features

- [x] Device enumeration (input/output)
- [x] Default device access
- [x] Stream creation (playback/recording)
- [x] Stream control (start/stop)
- [x] Audio read/write
- [x] PCM buffer management
- [x] WAV file loading
- [x] WAV file saving
- [x] Sample-level access
- [x] Tone generation

### Not Implemented

- [ ] Volume control
- [ ] Peak level monitoring
- [ ] Device change notification
- [ ] Exclusive mode
- [ ] Encoded format support
- [ ] Audio effects
- [ ] Mixing

---

## 9. Usage Recommendations

### Best Practices

1. **Always check for Void** when creating streams
2. **Close streams** when done to release resources
3. **Match buffer format** to stream format
4. **Call refresh** if devices may have changed
5. **Check is_valid** after loading WAV files

### Common Pitfalls

| Pitfall | Solution |
|---------|----------|
| Writing to stopped stream | Check is_started first |
| Format mismatch | Ensure buffer matches stream |
| Memory leak | Always call close on streams |
| Stale device list | Call refresh periodically |
