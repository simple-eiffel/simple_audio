# RECOMMENDATION: simple_audio

## Executive Summary
Build a native WASAPI-based audio I/O library for Eiffel with full void safety and contracts. The library fills a critical gap in the Eiffel ecosystem with no viable alternative.

## Recommendation
**Action:** BUILD
**Confidence:** HIGH

## Rationale
1. No existing Eiffel audio library provides simple, void-safe audio I/O
2. WASAPI is the modern Windows standard with best latency
3. miniaudio proves the pattern works with minimal dependencies
4. simple_* ecosystem needs audio capability for multimedia applications

## Proposed Approach

### Phase 1 (MVP)
- SIMPLE_AUDIO facade class
- SIMPLE_AUDIO_DEVICE for device management
- SIMPLE_AUDIO_BUFFER for sample data
- Basic playback to default device
- Basic capture from default device

### Phase 2 (Full)
- Device enumeration and selection
- Sample rate conversion
- Format conversion (bit depth)
- Volume control
- Multiple simultaneous streams

### Phase 3 (Future)
- Linux ALSA backend
- macOS CoreAudio backend
- Low-latency ASIO support

## Key Features
1. **Real-time playback**: Stream audio to output device with < 20ms latency
2. **Real-time capture**: Record from microphone with < 20ms latency
3. **Callback streaming**: Continuous audio via agent callbacks
4. **Device management**: Enumerate and select audio devices
5. **Format flexibility**: Support common sample rates and bit depths

## Success Criteria
- Play a sine wave without audible glitches
- Record 10 seconds of audio without dropouts
- Pass all unit tests in CI (with mock devices)

## Dependencies
| Library | Purpose | simple_* Preferred |
|---------|---------|-------------------|
| simple_file | Binary buffer I/O | YES |
| simple_testing | Unit tests | YES |
| WEL | Windows externals | ISE (no simple_* equivalent) |

## Next Steps
1. Run `/eiffel.spec` to transform this research into specification
2. Then `/eiffel.intent` to capture refined intent
3. Continue with Eiffel Spec Kit workflow

## Open Questions
- Exact buffer sizes for optimal latency vs. reliability tradeoff
- Whether to expose WASAPI exclusive mode (lowest latency, locks device)
- Integration strategy with future simple_codec for format decoding
