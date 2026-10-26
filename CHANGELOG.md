# Changelog

All notable changes to simple_audio.

## 1.1.2 - 2026-10-26

### Changed
- Dropped the ISE `wel` library from `simple_audio.ecf`. It was listed from the
  first commit, but no class ever used it; the clean build links without it.
  simple_audio depends only on EiffelBase and simple_file.
- Zero compiler warnings: six test `print` lines use `{STRING_32}` literals
  (obsolete `as_string_8`).
- 22 pass.

## 1.1.1 - 2026-10-25

### Fixed (design scan 21, since 3ed644f)

Report: `.eiffel-workflow/evidence/design-scan-since-3ed644f.md` (2 HIGH,
7 MEDIUM, 9 LOW). Each fix has a test that failed on the old code:
- **HIGH**: `play` filled the sink before starting it, and a device takes
  nothing while stopped, so playback started empty (the test sink hid it by
  taking audio while stopped; it now behaves as a device does). `play`
  starts the sink, then fills it; a device that will not start leaves
  `last_error` instead of breaking the postcondition.
  `test_scan21_play_starts_the_device_with_sound_queued` (old code:
  "started with sound queued: 0"),
  `test_scan21_a_device_that_will_not_start_says_so`.
- **HIGH**: a seek left the device's buffered audio playing and set the
  clock's base below zero (breaking `position_seconds`' postcondition).
  New `AUDIO_SINK.discard_buffered` (`AUDIO_STREAM.reset`: stop, reset the
  WASAPI buffer, start again) is called by `seek`; the clock reads the new
  place at once; invariant `clock_from_zero`.
  `test_scan21_seek_forgets_what_the_device_held`.
- MEDIUM: a decoding error ended nothing - the player waited for an end
  that never came. It now ends the file there and keeps the reason in
  `last_error`.
- 22 pass. Open (in the report): Media Foundation's error and format-change
  flags, COM and MFShutdown balance, a decoder without dispose, tighter
  test tolerances and stereo, and the duplication with AUDIO_PLAYER
  (volume, finish notice, pause) that side-by-side mixins should absorb.

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
