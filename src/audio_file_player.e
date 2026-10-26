note
	description: "[
		A decoded file streamed into a sink (0.2.0, simple_bible GW-25):
		`pump' - called from the host's clock, a fast GUI tick or a worker's
		loop - keeps the sink topped up from the decoder a chunk at a time,
		so a LibriVox hour plays from a few kilobytes of memory. `seek'
		jumps; `position_seconds' is what is being heard (written less what
		the sink still holds). It is the playback a SW_MEDIA_TRANSPORT
		drives: its on_play/on_pause/on_seek call `play'/`pause'/`seek' and
		the host reports `position_seconds' back.
	]"

class
	AUDIO_FILE_PLAYER

create
	make

feature {NONE} -- Initialization

	make (a_decoder: AUDIO_DECODER; a_sink: AUDIO_SINK)
			-- Play `a_decoder''s file into `a_sink', which takes its format.
		require
			open: a_decoder.is_open
			ready: a_sink.is_ready
			same_format: a_sink.sample_rate = a_decoder.sample_rate and a_sink.channels = a_decoder.channels
				and a_sink.bits_per_sample = a_decoder.bits_per_sample
		do
			decoder := a_decoder
			sink := a_sink
			volume := 1.0
		ensure
			kept: decoder = a_decoder and sink = a_sink
			stopped: not is_playing and not is_finished
		end

feature -- Access

	decoder: AUDIO_DECODER
	sink: AUDIO_SINK

	volume: REAL_64
			-- 0 silent .. 1 as recorded.

	duration_seconds: REAL_64
		do
			Result := decoder.duration_seconds
		end

	position_seconds: REAL_64
			-- What is being heard.
		do
			Result := base_seconds + ((frames_sent - sink.buffered_frames).max (0) / decoder.sample_rate)
		ensure
			non_negative: Result >= 0.0
		end

	on_finished: detachable PROCEDURE
			-- Run once, when the last sound has been heard.

feature -- Status

	is_playing: BOOLEAN
			-- Started, not paused, not finished.
		do
			Result := sink.is_started and not is_finished
		end

	is_paused: BOOLEAN

	is_finished: BOOLEAN
			-- Was everything decoded and heard?

feature -- Element change

	set_volume (a_volume: REAL_64)
		require
			in_range: a_volume >= 0.0 and a_volume <= 1.0
		do
			volume := a_volume
		ensure
			set: volume = a_volume
		end

	set_on_finished (a_action: PROCEDURE)
		do
			on_finished := a_action
		ensure
			set: on_finished = a_action
		end

feature -- Operations

	play
			-- Start or resume.
		do
			if is_finished then
				seek (0.0)
			end
			if not sink.is_started then
				pump
				sink.start
			end
			is_paused := False
		ensure
			playing: sink.is_started and not is_paused
		end

	pause
		do
			if sink.is_started then
				sink.stop
			end
			is_paused := True
		ensure
			paused: is_paused and not sink.is_started
		end

	seek (a_seconds: REAL_64)
			-- Continue from `a_seconds' (what the sink already holds still
			-- plays: a fraction of a second).
		require
			non_negative: a_seconds >= 0.0
		do
			if decoder.seek (a_seconds) then
				base_seconds := a_seconds - (sink.buffered_frames / decoder.sample_rate)
				frames_sent := 0
				pending := Void
				pending_at := 0
				is_finished := False
				finished_told := False
			end
		end

	pump
			-- Top the sink up from the decoder; tell `on_finished' once all
			-- has been heard.
		local
			l_room, l_taken: INTEGER
			l_done: BOOLEAN
		do
			from
				l_room := sink.available_frames
			until
				l_room <= 0 or l_done
			loop
				if not attached pending as al_p or else pending_at >= al_p.frame_count then
					pending := decoder.read_chunk (l_room.max (1024))
					pending_at := 0
					if attached pending as al_new then
						apply_volume (al_new)
					end
				end
				if attached pending as al_p then
					l_taken := sink.write_frames (al_p, pending_at, (al_p.frame_count - pending_at).min (l_room))
					pending_at := pending_at + l_taken
					frames_sent := frames_sent + l_taken
					l_room := l_room - l_taken
					l_done := l_taken = 0
				else
					l_done := True
				end
			end
			if decoder.is_at_end and pending = Void and sink.buffered_frames = 0 and not finished_told then
				is_finished := True
				finished_told := True
				if attached on_finished as al_f then
					al_f.call
				end
			end
		end

feature {NONE} -- Implementation

	pending: detachable AUDIO_BUFFER
			-- The decoded chunk being written.

	pending_at: INTEGER
			-- Its next frame.

	frames_sent: INTEGER_64
			-- Frames written since the last seek.

	base_seconds: REAL_64
			-- Where the last seek put the start of `frames_sent'.

	finished_told: BOOLEAN

	apply_volume (a_chunk: AUDIO_BUFFER)
		local
			i, ch: INTEGER
		do
			if volume < 1.0 then
				from i := 0 until i >= a_chunk.frame_count loop
					from ch := 0 until ch >= a_chunk.channels loop
						a_chunk.set_sample (i, ch, a_chunk.sample_at (i, ch) * volume)
						ch := ch + 1
					end
					i := i + 1
				end
			end
		end

invariant
	volume_in_range: volume >= 0.0 and volume <= 1.0

end
