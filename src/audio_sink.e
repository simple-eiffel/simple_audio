note
	description: "[
		Where streamed audio goes (0.2.0, simple_bible GW-25): a device
		(AUDIO_STREAM_SINK around an AUDIO_STREAM) or, in tests, a fake that
		records what it was given and drains at a pace the test sets. A sink
		holds a little audio ahead of what is heard; `available_frames' is
		the room left, `buffered_frames' what is queued and not yet heard.
	]"

deferred class
	AUDIO_SINK

feature -- Format

	sample_rate: INTEGER
		deferred
		end

	channels: INTEGER
		deferred
		end

	bits_per_sample: INTEGER
		deferred
		end

feature -- Status

	is_ready: BOOLEAN
			-- Can it take audio (opened, not closed)?
		deferred
		end

	is_started: BOOLEAN
			-- Is it playing what it holds?
		deferred
		end

	available_frames: INTEGER
			-- Room for more, in frames.
		require
			ready: is_ready
		deferred
		ensure
			non_negative: Result >= 0
		end

	buffered_frames: INTEGER
			-- Queued and not yet heard, in frames.
		require
			ready: is_ready
		deferred
		ensure
			non_negative: Result >= 0
		end

feature -- Operations

	start
		require
			ready: is_ready
			not_started: not is_started
		deferred
		end

	stop
		require
			ready: is_ready
			started: is_started
		deferred
		end

	write_frames (a_buffer: AUDIO_BUFFER; a_first, a_count: INTEGER): INTEGER
			-- Queue up to `a_count' frames of `a_buffer' from frame `a_first'
			-- (0-based); the frames taken.
		require
			ready: is_ready
			format_matches: a_buffer.channels = channels and a_buffer.bits_per_sample = bits_per_sample
			in_range: a_first >= 0 and a_count >= 0 and a_first + a_count <= a_buffer.frame_count
		deferred
		ensure
			bounded: Result >= 0 and Result <= a_count
		end

	close
			-- Let the device go.
		deferred
		ensure
			closed: not is_ready
		end

end
