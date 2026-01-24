# S04 - Feature Specifications: simple_audio

**Status:** BACKWASH (reverse-engineered from implementation)
**Date:** 2026-01-23

---

## 1. SIMPLE_AUDIO Feature Specifications

### make

| Attribute | Value |
|-----------|-------|
| Category | Creation |
| Signature | `make` |
| Purpose | Initialize audio system |
| Algorithm | 1. Initialize WASAPI via COM; 2. Create device lists; 3. Call refresh |
| Side Effects | COM initialization, device enumeration |

### output_devices

| Attribute | Value |
|-----------|-------|
| Category | Access |
| Signature | `output_devices: ARRAYED_LIST [AUDIO_DEVICE]` |
| Purpose | Get all available output (playback) devices |
| Algorithm | Return twin of internal list |
| Performance | O(n) copy |

### input_devices

| Attribute | Value |
|-----------|-------|
| Category | Access |
| Signature | `input_devices: ARRAYED_LIST [AUDIO_DEVICE]` |
| Purpose | Get all available input (recording) devices |
| Algorithm | Return twin of internal list |
| Performance | O(n) copy |

### default_output

| Attribute | Value |
|-----------|-------|
| Category | Access |
| Signature | `default_output: detachable AUDIO_DEVICE` |
| Purpose | Get system default output device |
| Algorithm | Query WASAPI for default render endpoint |
| Return | AUDIO_DEVICE or Void if none |

### default_input

| Attribute | Value |
|-----------|-------|
| Category | Access |
| Signature | `default_input: detachable AUDIO_DEVICE` |
| Purpose | Get system default input device |
| Algorithm | Query WASAPI for default capture endpoint |
| Return | AUDIO_DEVICE or Void if none |

### refresh

| Attribute | Value |
|-----------|-------|
| Category | Operations |
| Signature | `refresh` |
| Purpose | Re-enumerate all audio devices |
| Algorithm | Clear lists, enumerate output devices, enumerate input devices |
| Side Effects | Updates internal device lists |

### create_output_stream

| Attribute | Value |
|-----------|-------|
| Category | Operations |
| Signature | `create_output_stream (a_device: AUDIO_DEVICE; a_sample_rate, a_channels, a_bits: INTEGER): detachable AUDIO_STREAM` |
| Purpose | Create playback stream for a device |
| Parameters | a_device: target device; a_sample_rate: Hz (e.g., 44100); a_channels: 1-8; a_bits: 8/16/24/32 |
| Algorithm | Call WASAPI to create audio client, initialize with format |
| Return | AUDIO_STREAM or Void on failure |

### create_input_stream

| Attribute | Value |
|-----------|-------|
| Category | Operations |
| Signature | `create_input_stream (a_device: AUDIO_DEVICE; a_sample_rate, a_channels, a_bits: INTEGER): detachable AUDIO_STREAM` |
| Purpose | Create recording stream for a device |
| Parameters | a_device: target device; a_sample_rate: Hz; a_channels: 1-8; a_bits: 8/16/24/32 |
| Algorithm | Call WASAPI to create audio client, initialize capture |
| Return | AUDIO_STREAM or Void on failure |

### dispose

| Attribute | Value |
|-----------|-------|
| Category | Cleanup |
| Signature | `dispose` |
| Purpose | Release audio system resources |
| Algorithm | Call WASAPI cleanup, uninitialize COM |
| Side Effects | Releases native resources |

---

## 2. AUDIO_STREAM Feature Specifications

### start

| Attribute | Value |
|-----------|-------|
| Category | Operations |
| Signature | `start` |
| Purpose | Start audio streaming |
| Algorithm | Call IAudioClient::Start() |
| Side Effects | Begins audio data flow |

### stop

| Attribute | Value |
|-----------|-------|
| Category | Operations |
| Signature | `stop` |
| Purpose | Stop audio streaming |
| Algorithm | Call IAudioClient::Stop() |
| Side Effects | Halts audio data flow |

### write

| Attribute | Value |
|-----------|-------|
| Category | Operations |
| Signature | `write (a_buffer: AUDIO_BUFFER): INTEGER` |
| Purpose | Write audio data to output stream |
| Parameters | a_buffer: audio data to write |
| Algorithm | Get available frames, copy data to render client |
| Return | Number of frames written |

### read

| Attribute | Value |
|-----------|-------|
| Category | Operations |
| Signature | `read (a_buffer: AUDIO_BUFFER): INTEGER` |
| Purpose | Read audio data from input stream |
| Parameters | a_buffer: buffer to receive data |
| Algorithm | Get capture buffer, copy data |
| Return | Number of frames read |

### close

| Attribute | Value |
|-----------|-------|
| Category | Cleanup |
| Signature | `close` |
| Purpose | Close stream and release resources |
| Algorithm | Stop if running, release audio client |
| Side Effects | Handle becomes invalid |

---

## 3. AUDIO_BUFFER Feature Specifications

### make_from_wav

| Attribute | Value |
|-----------|-------|
| Category | Creation |
| Signature | `make_from_wav (a_path: READABLE_STRING_GENERAL)` |
| Purpose | Load PCM audio from WAV file |
| Parameters | a_path: path to WAV file |
| Algorithm | Parse RIFF header, extract fmt chunk, read data chunk |
| Constraints | PCM format only (audio_format=1), 8/16/24/32-bit, 1-8 channels |

### sample_at

| Attribute | Value |
|-----------|-------|
| Category | Access |
| Signature | `sample_at (a_frame, a_channel: INTEGER): REAL_64` |
| Purpose | Get normalized sample value (-1.0 to 1.0) |
| Parameters | a_frame: 0-based frame index; a_channel: 0-based channel index |
| Algorithm | Calculate offset, read bytes, normalize based on bit depth |
| Return | Normalized sample value |

### set_sample

| Attribute | Value |
|-----------|-------|
| Category | Element change |
| Signature | `set_sample (a_frame, a_channel: INTEGER; a_value: REAL_64)` |
| Purpose | Set normalized sample value |
| Parameters | a_frame: frame index; a_channel: channel index; a_value: -1.0 to 1.0 |
| Algorithm | Calculate offset, denormalize value, write bytes |

### save_to_wav

| Attribute | Value |
|-----------|-------|
| Category | Export |
| Signature | `save_to_wav (a_path: READABLE_STRING_GENERAL): BOOLEAN` |
| Purpose | Save buffer to WAV file |
| Parameters | a_path: output file path |
| Algorithm | Write RIFF header, fmt chunk, data chunk |
| Return | True on success |

### fill_sine_wave

| Attribute | Value |
|-----------|-------|
| Category | Generation |
| Signature | `fill_sine_wave (a_frequency: REAL_64; a_sample_rate: INTEGER)` |
| Purpose | Fill buffer with sine wave |
| Parameters | a_frequency: Hz (e.g., 440.0 for A4); a_sample_rate: samples per second |
| Algorithm | Calculate phase delta, iterate frames, compute sin(phase) |

---

## 4. Common Audio Formats

| Format | Sample Rate | Channels | Bits | Use Case |
|--------|-------------|----------|------|----------|
| CD Quality | 44100 Hz | 2 | 16 | Music playback |
| Voice | 16000 Hz | 1 | 16 | VoIP, speech |
| High-Res | 96000 Hz | 2 | 24 | Studio quality |
| DVD | 48000 Hz | 6 | 16 | Surround sound |
