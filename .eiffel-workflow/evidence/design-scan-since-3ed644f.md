# Design scan (diff mode) - simple_audio since 3ed644f (..56c837c, 1.1.0, GW-25)

Read-only. Nothing compiled or run; every finding is from reading the files
named. Subjects: audio_mf.h, AUDIO_DECODER, AUDIO_FILE_PLAYER, AUDIO_SINK,
AUDIO_STREAM_SINK, AUDIO_STREAM.write_frames, AUDIO_BUFFER.set_sample_rate, tests.

Answer to the unit question: AUDIO_STREAM.buffer_size IS frames
(audio_bridge.h:574 returns WASAPI buffer_frames; :501 available = buffer_frames - padding).
So buffered_frames = padding, correct in units.

Totals: HIGH 2, MEDIUM 7, LOW 9 (plus duplication proposals D1-D3 and test notes T1-T5).

## HIGH

### H1 - position_seconds can go negative after a mid-play seek (contract violation)
File: src/audio_file_player.e:119-133 and :50-56.
Evidence: seek sets `base_seconds := a_seconds - buffered/rate` and `frames_sent := 0`.
Then position = base + (0 - buffered).max(0)/rate = base. With 0.1 s buffered,
`seek (0.0)` or `seek (0.05)` gives base = -0.1 / -0.05 and the postcondition
`non_negative` (line 55) fails. The sink's old audio also stays queued, so the clock
sits at base until the old audio drains, then jumps. The tests never seek with
buffered > 0 (the seek (1.5) in lib_tests comes after finish, buffered = 0).
Fix: give AUDIO_SINK a `discard_buffered` (WASAPI: Stop, Reset, restart if it was
started; test sink: queued := 0) and call it in seek; then base = a_seconds exactly.
Minimum: clamp `Result := (...).max (0.0)`.

### H2 - play starts the device empty; the real sink drops the prefill; start failure breaks the postcondition
File: src/audio_file_player.e:94-107; src/audio_stream_sink.e:381-386; src/audio_stream.e:108-117, :149-165.
Evidence: play calls `pump` BEFORE `sink.start`. AUDIO_STREAM_SINK.write_frames returns 0
when `not stream.is_started` (and AUDIO_STREAM.write_frames requires is_started), so on a
device the first pump reads a chunk, writes nothing, and the device starts with an empty
buffer (gap/click until the next tick). AUDIO_TEST_SINK.write_frames accepts writes while
stopped, so the tests cannot see it: the two sinks diverge and the AUDIO_SINK contract is
silent about writing while stopped. Second: AUDIO_STREAM.start leaves is_started False when
c_start fails (no error), so `play` ensure `sink.is_started` (line 106) fails and is_playing
is False with no error path.
Fix: start the sink first, then pump; or state the stopped-write behaviour in AUDIO_SINK
(require/ensure) and make both implementations agree, with one conformance test run on both.
Make play report failure (last_error or BOOLEAN) and weaken the postcondition to match.

## MEDIUM

### M1 - decode error is invisible to the player and stalls it
File: src/audio_file_player.e:147-163, :164; src/audio_decoder.e:100-104.
Evidence: read_chunk returns Void on error with is_at_end False. pump sets pending Void,
l_done True; finish needs decoder.is_at_end, so it never finishes, never reports, and
retries the failed read every tick. last_error is set but never read by the player and is
not cleared on a later success.
Fix: player exposes has_error/last_error from the decoder; on error stop and tell the host.
Decoder clears last_error at the start of read_chunk.

### M2 - realloc failure silently drops decoded audio
File: Clib/audio_mf.h:181-189.
Evidence: when realloc fails the tail (l_length - l_n bytes) is discarded, *l_got still 1,
position advances only by l_n, so the next sample's l_time hides a hole. (Pending is empty
on entry, so nothing stale remains; the loss is the tail.)
Fix: return -1 on realloc failure, or keep one persistent pending buffer grown once.

### M3 - Lock handling leaks a lock and drops samples silently
File: Clib/audio_mf.h:177-198.
Evidence: condition is `SUCCEEDED(Lock) && l_length > 0`. Lock succeeded with length 0 falls
to Release (line 197) without Unlock. Lock failure skips the sample and reads on.
Fix: Unlock whenever Lock succeeded; on Lock failure release and return -1.

### M4 - ENDOFSTREAM and format-change flags
File: Clib/audio_mf.h:164-172.
Evidence: (a) a sample delivered together with ENDOFSTREAM is released unread (line 169), so a
final chunk can be lost. (b) MF_SOURCE_READERF_CURRENTMEDIATYPECHANGED is ignored: a mid-stream
rate/channel change leaves Eiffel's channels/sample_rate stale and the bytes misaligned.
(c) MF_SOURCE_READERF_ERROR is not tested. STREAMTICK (NULL sample) is handled by line 172.
Fix: process the sample first, then honour ENDOFSTREAM; on type change return -1 (or re-query
and report); test the ERROR flag.

### M5 - COM / MF lifecycle: unbalanced CoInitializeEx, startup race, no MFShutdown
File: Clib/audio_mf.h:60-73.
Evidence: CoInitializeEx on every open, never CoUninitialize (count grows; harmless but
unbalanced); it locks MTA on a fresh thread. The CAS sets audio_mf_started = 1 BEFORE MFStartup
returns, so a second thread (another SCOOP processor opening a decoder) can pass and call
MFCreateSourceReaderFromURL before startup finished. MFShutdown is never called (fine for LITE
at process end, but undocumented). read/seek/close do not initialise COM, so a decoder used
from another processor relies on the implicit MTA.
Fix: InitOnceExecuteOnce for MFStartup; balance CoInitializeEx in close or do it once per
process; make "open, read, close on one processor" a documented precondition.

### M6 - AUDIO_DECODER leaks the reader if close is forgotten
File: src/audio_decoder.e (no dispose).
Evidence: handle owns an IMFSourceReader and a malloc block; nothing frees them on GC.
Fix: inherit DISPOSABLE (redefine dispose to call c_close); close stays idempotent (it is).

### M7 - AUDIO_SINK contract is too thin
File: src/audio_sink.e:264-290; src/audio_stream_sink.e:364-367.
Evidence: no ensure on start/stop, none on write while stopped, no capacity relation.
AUDIO_STREAM_SINK.buffered_frames reads padding indirectly via buffer_size - available_frames;
when GetCurrentPadding fails available_frames returns 0 (audio_bridge.h), so buffered jumps to
buffer_size and position_seconds steps backwards for a tick.
Fix: add capacity_frames with invariant buffered + available <= capacity; AUDIO_STREAM gets a
direct buffered_frames from one padding call; ensure clauses on start/stop.

## LOW

L1 - Position arithmetic (audio_mf.h:161, :194): per-call truncation of (n/frame)*1e7/rate; drift at most 100 ns per call;
no overflow (LONGLONG); (int)l_length from DWORD fine under 2 GB. After a partial read, position = l_time + frames taken, and pending
reads add on from there: correct.
L2 - audio_mf_open (85-86, 91-93): SetStreamSelection/SetGUID/SetUINT32 HRESULTs ignored; failures surface later as a less clear NULL.
L3 - duration PROPVARIANT (120-123): a non-VT_UI8 duration reads as 0 silently; acceptable per the "0 when the file does not say" contract.
L4 - decoder.seek (audio_decoder.e:110-120): no upper bound; seek beyond duration is whatever MF does. `(a * 1.0e7).truncated_to_integer_64`
overflows near 9e11 s. Precondition label `in_file` promises more than it checks; add `a_seconds <= duration_seconds or duration_seconds = 0.0`
or specify "then at end". Player.seek has no result, so a failed decoder seek is silent.
L5 - read_chunk (audio_decoder.e:92-98): a_max_frames * channels * 2 can overflow; every call allocates a MANAGED_POINTER plus an AUDIO_BUFFER
and copies once; the pump asks for up to a whole device buffer per tick. Reuse a scratch buffer, read into the AUDIO_BUFFER data directly.
L6 - apply_volume (audio_file_player.e:189-202): per-sample sample_at/set_sample (require checks, REAL_64 round trip, /32768 then *32767);
88k calls/s stereo, with contracts baked into the `test` build. Volume changes reach only audio decoded afterwards, so the sink queue plays
at the old level. Fix: one integer scaler (AUDIO_BUFFER.scale_by or inline C), or ISimpleAudioVolume for immediate effect.
L7 - pump while paused (135-171): relies on the sink refusing writes; with AUDIO_TEST_SINK a paused pump fills the sink and advances frames_sent.
Skip writes explicitly when is_paused (AUDIO_PLAYER.pump does).
L8 - on_finished (164-170): once, re-armed by seek; re-entrant play/seek from the handler is safe (flags set first). position_seconds at the end
is the decoded length, not clamped to duration_seconds. play after finish calls seek (0.0); if that fails nothing plays and nothing says why.
L9 - invariants: AUDIO_FILE_PLAYER has only volume range; add pending_at >= 0, frames_sent >= 0, sink matches decoder format, decoder.is_open.
AUDIO_DECODER has none (is_open implies sample_rate > 0 and channels > 0; duration_seconds >= 0). decoder.position_seconds (next chunk starts) vs
player.position_seconds (what is heard) are different quantities: rename the decoder one (next_chunk_seconds).

## Duplication with AUDIO_PLAYER (proposals; nothing extracted without Larry)

D1 - volume + set_volume (same contract and invariant), on_finished + set_on_finished, is_paused, is_playing/is_finished, and
pump-copy-with-gain exist in both AUDIO_PLAYER (audio_player.e:77-152, :266-306) and AUDIO_FILE_PLAYER. Side-by-side deferred mixins:
- AUDIO_VOLUME_CONTROL: volume, set_volume, invariant, and the single gain routine from L6.
- AUDIO_FINISH_NOTIFIER: on_finished, set_on_finished, notify_finished (once, re-armable).
- AUDIO_TRANSPORT (deferred): play, pause, is_playing, is_paused, is_finished, position_seconds, pump, so a SW_MEDIA_TRANSPORT drives either.
D2 - AUDIO_STREAM.write (~line 141) and write_frames (149-165) duplicate the available_frames.min logic; write can call
write_frames (a_buffer, 0, a_buffer.frame_count). AUDIO_PLAYER.pump could then use write_frames and drop its temp buffer copy.
D3 - a deferred AUDIO_SOURCE (open, sample_rate, channels, bits_per_sample, read_chunk, seek, is_at_end, last_error) would let a WAV source and the MF
decoder share AUDIO_FILE_PLAYER; WAV currently goes through AUDIO_PLAYER whole-in-memory.

## Tests (testing/lib_tests.e, audio_test_sink.e)

T1 - Tolerances: frames +-3000 (3.4 %) and half-left +-3000 (6.8 %) hide the loss of two or three whole MP3 frames (1152 frames), exactly what M2/M3/M4
would cause; seek replay count 22050 +-3000 (13 %) is the loosest. Tighten to the encoder delay window with a comment on its source. Crossings +-90 (5 %),
clock +-0.1 s, seek position +-0.05 s are meaningful (MP3 frames are 26 ms).
T2 - Untested: the C pending path (tests ask 4096/4410-frame chunks while an MF sample is about 1152 frames, so a chunk is never cut; call
read_chunk (100) and check totals and position), stereo, seek while the sink holds audio (H1), volume < 1, start failure (H2), decode error, seek past the end,
close twice, decoder dropped unclosed (M6).
T3 - The "paused" assertion checks only queued > 0 and is_paused; not that position_seconds holds or pump writes nothing (L7).
T4 - fixture_path uses current_working_path: works only when run from the library directory; failure shows as a bare "opens" assertion.
T5 - AUDIO_TEST_SINK accepts writes while stopped (the real sink drops them) and records only channel 0; no shared sink-conformance test (H2).
