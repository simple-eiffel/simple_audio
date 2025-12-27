note
	description: "[
		AUDIO_STREAM - Audio Input/Output Stream

		Represents an active audio stream for playback or recording.
		Uses WASAPI shared mode for low-latency audio.

		Usage:
			stream: AUDIO_STREAM
			buffer: AUDIO_BUFFER

			-- Write audio data
			create buffer.make (1024, 2, 16)
			buffer.fill_sine_wave (440.0, 44100)
			stream.start
			stream.write (buffer)
			stream.stop
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	AUDIO_STREAM

create
	make_from_handle

feature {NONE} -- Initialization

	make_from_handle (a_handle: POINTER; a_is_output: BOOLEAN; a_sample_rate, a_channels, a_bits: INTEGER)
			-- Create stream from WASAPI handle.
		require
			handle_valid: a_handle /= default_pointer
			sample_rate_valid: a_sample_rate > 0
			channels_valid: a_channels > 0
			bits_valid: a_bits > 0
		do
			handle := a_handle
			is_output := a_is_output
			sample_rate := a_sample_rate
			channels := a_channels
			bits_per_sample := a_bits
			bytes_per_frame := channels * (bits_per_sample // 8)
			buffer_size := c_get_buffer_size (handle)
		ensure
			handle_set: handle = a_handle
			direction_set: is_output = a_is_output
			sample_rate_set: sample_rate = a_sample_rate
			channels_set: channels = a_channels
			bits_set: bits_per_sample = a_bits
		end

feature -- Access

	handle: POINTER
			-- Native stream handle.

	sample_rate: INTEGER
			-- Sample rate in Hz.

	channels: INTEGER
			-- Number of channels.

	bits_per_sample: INTEGER
			-- Bits per sample (8, 16, 24, 32).

	bytes_per_frame: INTEGER
			-- Bytes per frame (channels * bytes_per_sample).

	buffer_size: INTEGER
			-- Size of hardware buffer in frames.

feature -- Status

	is_output: BOOLEAN
			-- Is this an output (playback) stream?

	is_input: BOOLEAN
			-- Is this an input (recording) stream?
		do
			Result := not is_output
		ensure
			opposite: Result = not is_output
		end

	is_started: BOOLEAN
			-- Is stream currently running?

	is_valid: BOOLEAN
			-- Is this stream valid?
		do
			Result := handle /= default_pointer
		end

	available_frames: INTEGER
			-- Number of frames available for writing (output) or reading (input).
		require
			stream_valid: is_valid
		do
			Result := c_get_available_frames (handle)
		ensure
			non_negative: Result >= 0
		end

feature -- Operations

	start
			-- Start the audio stream.
		require
			stream_valid: is_valid
			not_started: not is_started
		do
			if c_start (handle) /= 0 then
				is_started := True
			end
		end

	stop
			-- Stop the audio stream.
		require
			stream_valid: is_valid
			is_running: is_started
		do
			if c_stop (handle) /= 0 then
				is_started := False
			end
		end

	write (a_buffer: AUDIO_BUFFER): INTEGER
			-- Write audio data from buffer. Returns frames written.
		require
			stream_valid: is_valid
			is_running: is_started
			is_output_stream: is_output
			buffer_valid: a_buffer /= Void
			format_matches: a_buffer.channels = channels and a_buffer.bits_per_sample = bits_per_sample
		local
			l_frames: INTEGER
		do
			l_frames := available_frames.min (a_buffer.frame_count)
			if l_frames > 0 then
				Result := c_write (handle, a_buffer.data.item, l_frames)
			end
		ensure
			non_negative: Result >= 0
		end

	read (a_buffer: AUDIO_BUFFER): INTEGER
			-- Read audio data into buffer. Returns frames read.
		require
			stream_valid: is_valid
			is_running: is_started
			is_input_stream: is_input
			buffer_valid: a_buffer /= Void
			format_matches: a_buffer.channels = channels and a_buffer.bits_per_sample = bits_per_sample
		do
			Result := c_read (handle, a_buffer.data.item, a_buffer.frame_count)
		ensure
			non_negative: Result >= 0
		end

feature -- Cleanup

	close
			-- Close and release stream resources.
		do
			if is_started then
				stop
			end
			if handle /= default_pointer then
				c_destroy (handle)
				handle := default_pointer
			end
		ensure
			handle_cleared: handle = default_pointer
			stopped: not is_started
		end

feature {NONE} -- C externals

	c_start (a_stream: POINTER): INTEGER
		external
			"C inline use %"audio_bridge.h%""
		alias
			"return (EIF_INTEGER)audio_stream_start($a_stream);"
		end

	c_stop (a_stream: POINTER): INTEGER
		external
			"C inline use %"audio_bridge.h%""
		alias
			"return (EIF_INTEGER)audio_stream_stop($a_stream);"
		end

	c_write (a_stream, a_data: POINTER; a_frames: INTEGER): INTEGER
		external
			"C inline use %"audio_bridge.h%""
		alias
			"return (EIF_INTEGER)audio_stream_write($a_stream, $a_data, (int)$a_frames);"
		end

	c_read (a_stream, a_data: POINTER; a_max_frames: INTEGER): INTEGER
		external
			"C inline use %"audio_bridge.h%""
		alias
			"return (EIF_INTEGER)audio_stream_read($a_stream, $a_data, (int)$a_max_frames);"
		end

	c_get_available_frames (a_stream: POINTER): INTEGER
		external
			"C inline use %"audio_bridge.h%""
		alias
			"return (EIF_INTEGER)audio_stream_get_available_frames($a_stream);"
		end

	c_get_buffer_size (a_stream: POINTER): INTEGER
		external
			"C inline use %"audio_bridge.h%""
		alias
			"return (EIF_INTEGER)audio_stream_get_buffer_size($a_stream);"
		end

	c_destroy (a_stream: POINTER)
		external
			"C inline use %"audio_bridge.h%""
		alias
			"audio_stream_destroy($a_stream);"
		end

invariant
	sample_rate_positive: sample_rate > 0
	channels_positive: channels > 0
	bits_positive: bits_per_sample > 0

end
