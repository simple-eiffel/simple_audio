<p align="center">
  <img src="docs/images/logo.svg" alt="simple_audio logo" width="400">
</p>

# simple_audio

**[Documentation](https://simple-eiffel.github.io/simple_audio/)** | **[GitHub](https://github.com/simple-eiffel/simple_audio)**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Eiffel](https://img.shields.io/badge/Eiffel-25.02-blue.svg)](https://www.eiffel.org/)
[![Design by Contract](https://img.shields.io/badge/DbC-enforced-orange.svg)]()
[![Windows](https://img.shields.io/badge/Platform-Windows-blue.svg)]()

Real-time audio I/O library for Eiffel using Windows Audio Session API (WASAPI).

Part of the [Simple Eiffel](https://github.com/simple-eiffel) ecosystem.

## Status

**Development** - Windows-only, WASAPI shared mode

## Overview

SIMPLE_AUDIO provides low-latency audio playback and recording using WASAPI. Features include:

- **Device enumeration** - List input/output devices with names and IDs
- **Stream creation** - Create playback or recording streams
- **Audio buffers** - PCM data with 8/16/24/32-bit sample support
- **WAV file loading** - Load audio from WAV files (PCM format)
- **Sine wave generation** - Built-in test signal generation

Uses inline C externals - no external DLLs required.

## Quick Start

```eiffel
local
    audio: SIMPLE_AUDIO
do
    create audio.make

    -- List output devices
    across audio.output_devices as d loop
        print (d.display_name + "%N")
    end

    -- Get default device info
    if attached audio.default_output as dev then
        print ("Default: " + dev.name + "%N")
    end

    audio.dispose
end
```

## Loading WAV Files

```eiffel
local
    buffer: AUDIO_BUFFER
do
    -- Load audio from WAV file
    create buffer.make_from_wav ("sound.wav")

    if buffer.is_valid then
        print ("Loaded: " + buffer.duration.out + " seconds%N")
        print ("Sample rate: " + buffer.sample_rate.out + " Hz%N")
        print ("Channels: " + buffer.channels.out + "%N")
    else
        print ("Error: " + buffer.last_error + "%N")
    end
end
```

## Audio Playback

```eiffel
local
    audio: SIMPLE_AUDIO
    buffer: AUDIO_BUFFER
do
    create audio.make

    if attached audio.default_output as dev then
        if attached audio.create_output_stream (dev, 44100, 2, 16) as stream then
            -- Create a 1-second sine wave buffer
            create buffer.make (44100, 2, 16)
            buffer.fill_sine_wave (440.0, 44100)

            stream.start
            stream.write (buffer)
            -- ... wait for playback ...
            stream.stop
            stream.close
        end
    end

    audio.dispose
end
```

## Playing MP3 and Other Compressed Files (1.1.0)

```eiffel
local
    decoder: AUDIO_DECODER
    player: AUDIO_FILE_PLAYER
do
    create decoder.make
    if decoder.open ("Genesis_01.mp3") then
        -- a sink in the decoder's format: an output AUDIO_STREAM as AUDIO_STREAM_SINK
        create player.make (decoder, sink)
        player.play
        -- from the host's clock (a fast GUI tick, a worker loop):
        player.pump
    end
end
```

`AUDIO_DECODER` reads whatever Windows decodes (MP3, AAC/M4A, WMA, WAV)
through Media Foundation, a chunk at a time; `AUDIO_FILE_PLAYER` streams it,
with `pause`, `seek`, `volume`, `position_seconds` and `on_finished`.

## Audio Recording

```eiffel
local
    audio: SIMPLE_AUDIO
    buffer: AUDIO_BUFFER
    frames_read: INTEGER
do
    create audio.make

    if attached audio.default_input as dev then
        if attached audio.create_input_stream (dev, 44100, 2, 16) as stream then
            create buffer.make (44100, 2, 16)  -- 1 second buffer

            stream.start
            frames_read := stream.read (buffer)
            stream.stop

            print ("Recorded " + frames_read.out + " frames%N")
            stream.close
        end
    end

    audio.dispose
end
```

## Working with Samples

```eiffel
local
    buffer: AUDIO_BUFFER
    value: REAL_64
do
    -- Create stereo 16-bit buffer
    create buffer.make (1024, 2, 16)

    -- Set sample value (-1.0 to 1.0)
    buffer.set_sample (0, 0, 0.5)   -- Frame 0, Left channel
    buffer.set_sample (0, 1, -0.5)  -- Frame 0, Right channel

    -- Read sample value
    value := buffer.sample_at (0, 0)

    -- Fill with silence
    buffer.fill_silence

    -- Generate test tone
    buffer.fill_sine_wave (440.0, 44100)
end
```

## Installation

1. Set the environment variable:
```batch
set SIMPLE_EIFFEL=D:\prod
```

2. Add to your ECF file:
```xml
<library name="simple_audio" location="$SIMPLE_EIFFEL/simple_audio/simple_audio.ecf"/>
```

## Dependencies

- simple_file (file operations)
- EiffelBase (for MANAGED_POINTER)
- ole32.lib, uuid.lib (Windows system libraries, linked automatically)
- mfplat.lib, mfreadwrite.lib, mfuuid.lib (Media Foundation, linked by `audio_mf.h`; Windows 7 or later)
- ISE `wel` (still; against the simple_* rule - noted in the CHANGELOG)

## API Reference

### SIMPLE_AUDIO (Facade)

| Method | Description |
|--------|-------------|
| `output_devices` | All output (playback) devices |
| `input_devices` | All input (recording) devices |
| `default_output` | Default output device |
| `default_input` | Default input device |
| `create_output_stream` | Create playback stream |
| `create_input_stream` | Create recording stream |
| `refresh` | Re-enumerate devices |
| `dispose` | Release resources |

### AUDIO_DEVICE

| Property | Description |
|----------|-------------|
| `name` | Device friendly name |
| `id` | Unique device identifier |
| `is_output` | True if output device |
| `is_input` | True if input device |
| `display_name` | Name with [IN]/[OUT] prefix |

### AUDIO_STREAM

| Method | Description |
|--------|-------------|
| `start` | Begin streaming |
| `stop` | Stop streaming |
| `write (buffer)` | Write audio data (output) |
| `read (buffer)` | Read audio data (input) |
| `close` | Release stream |
| `available_frames` | Frames ready for I/O |
| `sample_rate` | Stream sample rate |
| `channels` | Number of channels |
| `bits_per_sample` | Bit depth |

### AUDIO_DECODER (1.1.0)

| Method | Description |
|--------|-------------|
| `open (path)` | Open a file Windows can decode; True on success |
| `read_chunk (max_frames)` | The next 16-bit PCM chunk; Void at the end |
| `seek (seconds)` | Continue from there |
| `position_seconds`, `duration_seconds` | Where, and how long |
| `close` | Let the file go |

### AUDIO_FILE_PLAYER (1.1.0)

| Method | Description |
|--------|-------------|
| `make (decoder, sink)` | Stream the decoder into a sink of its format |
| `play`, `pause`, `seek (seconds)` | Transport |
| `pump` | Top the sink up (call from the host's clock) |
| `position_seconds` | What is being heard |
| `set_volume`, `set_on_finished` | Volume; told once at the end |

### AUDIO_BUFFER

| Method | Description |
|--------|-------------|
| `make (frames, channels, bits)` | Create buffer |
| `make_from_wav (path)` | Load from WAV file |
| `sample_at (frame, channel)` | Get sample (-1.0 to 1.0) |
| `set_sample (frame, channel, value)` | Set sample |
| `fill_sine_wave (freq, rate)` | Generate sine wave |
| `fill_silence` | Zero all samples |
| `clear` | Same as fill_silence |
| `is_valid` | True if load succeeded |
| `last_error` | Error message if failed |
| `sample_rate` | Sample rate in Hz |
| `duration` | Duration in seconds |

## Supported Formats

- **Sample rates**: Any (common: 44100, 48000, 96000)
- **Channels**: 1-8 (mono, stereo, surround)
- **Bit depths**: 8, 16, 24, 32 (PCM)
- **WAV files**: PCM format only (no compression)
- **Compressed files** (1.1.0): MP3, AAC/M4A, WMA and anything else Windows decodes, through `AUDIO_DECODER`

## Platform Support

Currently Windows-only. Uses:
- WASAPI (Windows Audio Session API)
- Shared mode (lower latency, device sharing)

## License

MIT License - see LICENSE file

---

Part of the **Simple Eiffel** ecosystem - modern, contract-driven Eiffel libraries.
