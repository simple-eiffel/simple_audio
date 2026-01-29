# SCOPE: simple_audio

## Problem Statement
In one sentence: Eiffel applications need native, cross-platform audio I/O without heavy dependencies.

What's wrong today: No simple, void-safe Eiffel audio library exists. Eiffel-Loop's Laabhair is complex and Windows-focused. Eiffel Game2 requires SDL.
Who experiences this: Eiffel developers building audio applications, games, multimedia tools.
Impact of not solving: Developers must use FFI to C libraries with no contracts or void safety.

## Target Users
| User Type | Needs | Pain Level |
|-----------|-------|------------|
| Game developers | Real-time audio playback, low latency | HIGH |
| Multimedia apps | Record/playback, format conversion | HIGH |
| Scientific tools | Audio analysis, waveform capture | MEDIUM |

## Success Criteria
| Level | Criterion | Measure |
|-------|-----------|---------|
| MVP | Play audio buffer to default device | Working playback test |
| MVP | Capture audio from microphone | Working capture test |
| Full | Multi-device support, format conversion | Device enumeration works |

## Scope Boundaries
### In Scope (MUST)
- Real-time audio playback
- Real-time audio capture
- WASAPI backend (Windows)
- Buffer-based streaming

### In Scope (SHOULD)
- Device enumeration
- Sample rate conversion
- Format conversion (8/16/24/32-bit)
- Volume control

### Out of Scope
- Audio file decoding (MP3, OGG, FLAC) - use simple_codec
- 3D positional audio - use OpenAL directly
- MIDI support - separate library
- Audio effects/DSP - separate library

### Deferred to Future
- Linux ALSA/PulseAudio backend
- macOS CoreAudio backend
- ASIO support for pro audio

## Constraints
| Type | Constraint |
|------|------------|
| Technical | Must be SCOOP-compatible |
| Technical | Void-safe throughout |
| Platform | Windows-first (WASAPI) |
| Ecosystem | Must prefer simple_* dependencies |

## Assumptions to Validate
| ID | Assumption | Risk if False |
|----|------------|---------------|
| A-1 | WASAPI provides low-latency audio | May need ASIO fallback |
| A-2 | Inline C sufficient for COM interfaces | May need external DLL |
| A-3 | simple_file handles binary buffers | May need buffer classes |

## Research Questions
- Which audio API provides best latency on Windows?
- How do other libraries handle real-time streaming?
- What buffer sizes are optimal for low latency?
