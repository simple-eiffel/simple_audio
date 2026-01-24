# S01 - Project Inventory: simple_audio

**Status:** BACKWASH (reverse-engineered from implementation)
**Date:** 2026-01-23
**Library Version:** 1.0.0

---

## 1. Project Identity

| Attribute | Value |
|-----------|-------|
| Name | simple_audio |
| Purpose | Real-time Audio I/O Library for Windows |
| Domain | Audio / Multimedia |
| Facade Class | SIMPLE_AUDIO |
| ECF File | simple_audio.ecf |

## 2. File Inventory

### Source Files (src/)

| File | Class | Purpose |
|------|-------|---------|
| simple_audio.e | SIMPLE_AUDIO | Main facade - device enumeration, stream creation |
| audio_device.e | AUDIO_DEVICE | Represents audio endpoint (speaker/microphone) |
| audio_stream.e | AUDIO_STREAM | Active audio stream for playback/recording |
| audio_buffer.e | AUDIO_BUFFER | PCM audio data buffer with WAV I/O |

### C Library Files (Clib/)

| File | Purpose |
|------|---------|
| audio_bridge.h | C header for WASAPI bridge functions |
| Makefile.win | Build configuration for Windows |

### Test Files (testing/)

| File | Purpose |
|------|---------|
| test_app.e | Test application entry point |
| lib_tests.e | Library test suite |
| test_set_base.e | Base test set class |

## 3. Dependencies

### ISE Libraries

| Library | Purpose |
|---------|---------|
| base | Core Eiffel classes |
| time | Timing operations |

### External Dependencies

| Dependency | Type | Purpose |
|------------|------|---------|
| Windows Audio Session API (WASAPI) | System | Native audio access |
| ole32.lib | Windows Library | COM initialization |
| uuid.lib | Windows Library | GUIDs for WASAPI interfaces |

### simple_* Libraries

None required.

## 4. Platform Requirements

| Requirement | Value |
|-------------|-------|
| OS | Windows (7, 8, 10, 11) |
| Architecture | x64 |
| Compiler | EiffelStudio 25.02+ |

## 5. Documentation Assets

| File | Status |
|------|--------|
| README.md | Present |
| research/SIMPLE_AUDIO_RESEARCH.md | Present |
| docs/index.html | Present |

## 6. Known Limitations

1. Windows-only (no Linux/macOS support)
2. PCM audio only (no compressed format decoding)
3. Shared mode only (no exclusive mode for ultra-low latency)
4. No built-in audio effects or mixing
