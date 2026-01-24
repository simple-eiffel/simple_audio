# LANDSCAPE: simple_audio


**Date**: 2026-01-23

## Existing Solutions

### PortAudio
| Aspect | Assessment |
|--------|------------|
| Type | LIBRARY |
| Platform | Windows, macOS, Linux, BSD |
| URL | https://portaudio.com/ |
| Maturity | MATURE |
| License | MIT |

**Strengths:**
- Cross-platform standard for audio I/O
- Simple callback-based API
- Wide platform support

**Weaknesses:**
- High latency on Windows with Winmm backend
- WASAPI support requires specific configuration
- No Eiffel bindings exist

**Relevance:** 70%

### miniaudio
| Aspect | Assessment |
|--------|------------|
| Type | LIBRARY |
| Platform | Windows, macOS, Linux, iOS, Android, Web |
| URL | https://miniaud.io/ |
| Maturity | MATURE |
| License | Public Domain / MIT-0 |

**Strengths:**
- Single header file, no dependencies
- Built-in format decoding (MP3, FLAC, WAV, Vorbis)
- Excellent documentation
- Zero external linking on Windows/macOS

**Weaknesses:**
- C library, requires FFI
- Large single file may complicate inline C approach

**Relevance:** 85%

### libsoundio
| Aspect | Assessment |
|--------|------------|
| Type | LIBRARY |
| Platform | Windows, macOS, Linux |
| URL | https://github.com/andrewrk/libsoundio |
| Maturity | GROWING |
| License | MIT |

**Strengths:**
- Clean, well-documented API
- Channel mapping support for surround
- Multiple backend support simultaneously

**Weaknesses:**
- Less widespread than PortAudio
- Requires linking

**Relevance:** 65%

### OpenAL Soft
| Aspect | Assessment |
|--------|------------|
| Type | LIBRARY |
| Platform | Windows, macOS, Linux |
| URL | https://www.openal-soft.org/ |
| Maturity | MATURE |
| License | LGPL |

**Strengths:**
- 3D positional audio
- Environmental effects (reverb, occlusion)
- Game-focused features

**Weaknesses:**
- No audio input support
- Overkill for simple playback
- LGPL license considerations

**Relevance:** 40%

## Eiffel Ecosystem Check

### ISE Libraries
- WEL: Windows API wrappers, no audio support

### simple_* Libraries
- simple_file: Binary file I/O (dependency)
- simple_codec: Audio format decoding (future integration)

### Eiffel-Loop Libraries
- Laabhair: Audio analysis framework (Windows only, complex)
- TagLib: Audio metadata only, not playback

### Eiffel Game2
- SDL2 audio wrapper (requires full SDL dependency)

### Gap Analysis
Not available in Eiffel: Simple, void-safe audio I/O library with contracts

## Comparison Matrix
| Feature | PortAudio | miniaudio | libsoundio | Our Need |
|---------|-----------|-----------|------------|----------|
| Playback | ✓ | ✓ | ✓ | MUST |
| Capture | ✓ | ✓ | ✓ | MUST |
| WASAPI | ✓ | ✓ | ✓ | MUST |
| No dependencies | ✗ | ✓ | ✗ | SHOULD |
| Format decode | ✗ | ✓ | ✗ | OUT |
| 3D audio | ✗ | ✗ | ✗ | OUT |

## Patterns Identified
| Pattern | Seen In | Adopt? |
|---------|---------|--------|
| Callback streaming | All | YES |
| Ring buffer | PortAudio, miniaudio | YES |
| Device enumeration | All | YES |
| Async event loop | libsoundio | MAYBE |

## Build vs Buy vs Adapt
| Option | Effort | Risk | Fit |
|--------|--------|------|-----|
| Build (direct WASAPI) | MEDIUM | LOW | 90% |
| Adapt (miniaudio wrapper) | LOW | MEDIUM | 80% |
| Adapt (PortAudio wrapper) | MEDIUM | MEDIUM | 70% |

**Initial Recommendation:** BUILD with direct WASAPI, referencing miniaudio patterns
