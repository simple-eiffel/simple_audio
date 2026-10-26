note
	description: "[
		A sink for tests: it holds `capacity' frames, remembers the first
		channel of every frame it was given, and is heard only when the test
		says (`drain'), so playback runs with no sound and no device.
	]"

class
	AUDIO_TEST_SINK

inherit
	AUDIO_SINK

create
	make

feature {NONE} -- Initialization

	make (a_rate, a_channels, a_capacity: INTEGER)
		require
			positive: a_rate > 0 and a_channels > 0 and a_capacity > 0
		do
			sample_rate := a_rate
			channels := a_channels
			capacity := a_capacity
			is_ready := True
			create heard.make (a_rate * 2)
		end

feature -- Format

	sample_rate: INTEGER
	channels: INTEGER
	bits_per_sample: INTEGER = 16

feature -- Status

	is_ready: BOOLEAN
	is_started: BOOLEAN
	capacity: INTEGER

	queued: INTEGER
			-- Frames given and not yet drained.

	available_frames: INTEGER
		do
			Result := capacity - queued
		end

	buffered_frames: INTEGER
		do
			Result := queued
		end

	heard: ARRAYED_LIST [REAL_64]
			-- The first channel of every frame given, in order.

feature -- Operations

	start
		do
			is_started := True
		end

	stop
		do
			is_started := False
		end

	write_frames (a_buffer: AUDIO_BUFFER; a_first, a_count: INTEGER): INTEGER
		local
			i: INTEGER
		do
			Result := a_count.min (available_frames)
			from i := 0 until i >= Result loop
				heard.extend (a_buffer.sample_at (a_first + i, 0))
				i := i + 1
			end
			queued := queued + Result
		end

	drain (a_frames: INTEGER)
			-- The device plays `a_frames' (fewer when it holds fewer).
		do
			if is_started then
				queued := (queued - a_frames).max (0)
			end
		end

	close
		do
			is_ready := False
		end

end
