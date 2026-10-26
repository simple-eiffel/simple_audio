# Changelog

All notable changes to simple_audio.

## 1.1.0 - 2026-10-25

### Added (MP3 and other compressed files, for simple_bible GW-25)

- **`AUDIO_DECODER`**: whatever Windows decodes - MP3, AAC/M4A, WMA, WAV -
  through Media Foundation's source reader (`Clib/audio_mf.h`), as 16-bit
  PCM at the file's own rate and channels, a chunk at a time (`read_chunk`),
  with `seek`, `position_seconds` and `duration_seconds`. An hour of audio
  never sits decoded in memory.
- **`AUDIO_FILE_PLAYER`**: a decoded file streamed into a sink; `pump` (from
  the host's clock) keeps the sink topped up; `play`, `pause`, `seek`,
  `volume`, `position_seconds` (what is heard: written less what the sink
  still holds), `on_finished` once at the end. It is the playback a
  simple_widgets SW_MEDIA_TRANSPORT drives.
- **`AUDIO_SINK`** (deferred) and **`AUDIO_STREAM_SINK`** (an output
  AUDIO_STREAM as a sink); `AUDIO_STREAM.write_frames` writes from an
  offset; `AUDIO_BUFFER.set_sample_rate`.
- Media Foundation needs Windows 7: ISE builds C for Windows 2000, and
  raising that for the whole library breaks `audio_bridge.h`'s
  kernel-streaming workaround, so only the Media Foundation includes see
  Windows 10.
- Tests: a two-second 440 Hz MP3 fixture (`testing/fixtures`, made with
  ffmpeg) decodes to about 88,200 frames and 440 Hz by its zero crossings,
  and a seek to one second leaves about half; the player streams it into a
  test sink (`AUDIO_TEST_SINK`: no device, no sound) - the clock follows,
  the end is told once, a seek replays from there. The test runner now
  prints why a test failed. 19 pass.
- Noted, not changed: the library still depends on ISE's `wel` library,
  against the simple_* rule.
