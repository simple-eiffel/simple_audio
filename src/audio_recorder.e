note
	description: "[
		AUDIO_RECORDER - High-Level Audio Recording

		Simple, high-level audio recording for Eiffel applications.
		Provides event-driven callbacks for real-time audio processing.

		Usage:
			recorder: AUDIO_RECORDER

			-- Simple recording to file
			create recorder.make
			recorder.record_to_file ("output.wav", 5.0)  -- 5 seconds

			-- Event-driven recording with callback
			recorder.set_on_data_available (agent process_audio)
			recorder.start
			-- ... do other work ...
			recorder.stop
			recorder.buffer.save_to_wav ("output.wav")

			-- Real-time audio processing
			recorder.set_on_data_available (agent (buf: AUDIO_BUFFER)
				do
					print ("Peak: " + buf.sample_at (0, 0).abs.out + "%%N")
				end)
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	AUDIO_RECORDER

create
	make,
	make_with_device

feature {NONE} -- Initialization

	make
			-- Create recorder using default input device.
		local
			l_audio: SIMPLE_AUDIO
		do
			create l_audio.make
			if attached l_audio.default_input as dev then
				device := dev
			else
				create device.make_empty
			end
			sample_rate := 44100
			channels := 2
			bits_per_sample := 16
			create last_error.make_empty
			l_audio.dispose
		ensure
			defaults_set: sample_rate = 44100 and channels = 2 and bits_per_sample = 16
		end

	make_with_device (a_device: AUDIO_DEVICE)
			-- Create recorder for specific device.
		require
			device_valid: a_device /= Void and then a_device.is_valid
			device_is_input: a_device.is_input
		do
			device := a_device
			sample_rate := 44100
			channels := 2
			bits_per_sample := 16
			create last_error.make_empty
		ensure
			device_set: device = a_device
		end

feature -- Access

	device: AUDIO_DEVICE
			-- Input device for recording.

	sample_rate: INTEGER
			-- Recording sample rate in Hz.

	channels: INTEGER
			-- Number of recording channels.

	bits_per_sample: INTEGER
			-- Bits per sample.

	buffer: detachable AUDIO_BUFFER
			-- Recorded audio data (accumulated).

	duration: REAL_64
			-- Total recorded duration in seconds.
		do
			if attached buffer as buf then
				Result := buf.duration
			end
		ensure
			non_negative: Result >= 0.0
		end

	last_error: STRING
			-- Error message from last operation.

feature -- Status

	is_recording: BOOLEAN
			-- Is recording in progress?
		do
			Result := attached current_stream as s and then s.is_started
		end

	has_error: BOOLEAN
			-- Did last operation fail?
		do
			Result := not last_error.is_empty
		end

feature -- Configuration

	set_format (a_sample_rate, a_channels, a_bits: INTEGER)
			-- Set recording format.
		require
			not_recording: not is_recording
			sample_rate_valid: a_sample_rate > 0
			channels_valid: a_channels > 0 and a_channels <= 8
			bits_valid: a_bits = 8 or a_bits = 16 or a_bits = 24 or a_bits = 32
		do
			sample_rate := a_sample_rate
			channels := a_channels
			bits_per_sample := a_bits
		ensure
			sample_rate_set: sample_rate = a_sample_rate
			channels_set: channels = a_channels
			bits_set: bits_per_sample = a_bits
		end

feature -- Callbacks

	on_data_available_action: detachable PROCEDURE [TUPLE [AUDIO_BUFFER]]
			-- Called when new audio data is available.
			-- The buffer contains the latest chunk of recorded audio.

	set_on_data_available (a_action: PROCEDURE [TUPLE [AUDIO_BUFFER]])
			-- Set callback for real-time audio data.
		require
			action_valid: a_action /= Void
		do
			on_data_available_action := a_action
		ensure
			action_set: on_data_available_action = a_action
		end

feature -- Recording Operations

	record_to_file (a_path: READABLE_STRING_GENERAL; a_duration: REAL_64)
			-- Record for specified duration and save to WAV file.
		require
			path_not_empty: not a_path.is_empty
			duration_positive: a_duration > 0.0
			not_recording: not is_recording
		local
			l_start_time: REAL_64
		do
			start

			if is_recording then
				-- Record for specified duration
				l_start_time := current_time_ms / 1000.0
				from
				until current_time_ms / 1000.0 - l_start_time >= a_duration
				loop
					pump
					sleep_ms (10)
				end

				stop

				-- Save to file
				if attached buffer as buf then
					if not buf.save_to_wav (a_path) then
						last_error := "Failed to save WAV file"
					end
				end
			end
		end

	start
			-- Start recording.
		require
			not_recording: not is_recording
		local
			l_audio: SIMPLE_AUDIO
			l_stream: detachable AUDIO_STREAM
		do
			last_error.wipe_out

			-- Create stream
			create l_audio.make
			l_stream := l_audio.create_input_stream (device, sample_rate, channels, bits_per_sample)

			if attached l_stream as s then
				current_stream := s
				-- Create initial buffer for accumulating data
				create buffer.make (sample_rate * 60, channels, bits_per_sample)  -- 60 seconds max
				buffer_position := 0
				s.start
			else
				last_error := "Failed to create audio stream"
			end
		ensure
			recording_or_error: is_recording or has_error
		end

	stop
			-- Stop recording.
		do
			if attached current_stream as s then
				if s.is_started then
					s.stop
				end
				s.close
			end
			current_stream := Void

			-- Trim buffer to actual recorded size
			if attached buffer as buf and then buffer_position > 0 and then buffer_position < buf.frame_count then
				trim_buffer (buffer_position)
			end
		ensure
			stopped: not is_recording
		end

feature -- Processing

	pump
			-- Process recording - call regularly during recording.
			-- Reads audio data from device and accumulates in buffer.
		local
			l_temp_buffer: AUDIO_BUFFER
			l_frames_read: INTEGER
			i, ch: INTEGER
		do
			if attached current_stream as s and then attached buffer as buf then
				if s.is_started then
					-- Create temporary buffer for reading
					create l_temp_buffer.make (s.available_frames.max (1024), channels, bits_per_sample)

					l_frames_read := s.read (l_temp_buffer)

					if l_frames_read > 0 then
						-- Copy to accumulator buffer
						from i := 0 until i >= l_frames_read or buffer_position + i >= buf.frame_count loop
							from ch := 0 until ch >= channels loop
								buf.set_sample (buffer_position + i, ch, l_temp_buffer.sample_at (i, ch))
								ch := ch + 1
							end
							i := i + 1
						end
						buffer_position := buffer_position + i

						-- Call data callback with the chunk
						if attached on_data_available_action as action then
							-- Create a properly sized buffer for the callback
							create l_temp_buffer.make (l_frames_read, channels, bits_per_sample)
							from i := 0 until i >= l_frames_read loop
								from ch := 0 until ch >= channels loop
									l_temp_buffer.set_sample (i, ch, buf.sample_at (buffer_position - l_frames_read + i, ch))
									ch := ch + 1
								end
								i := i + 1
							end
							action.call ([l_temp_buffer])
						end
					end
				end
			end
		end

feature {NONE} -- Implementation

	current_stream: detachable AUDIO_STREAM
			-- Active audio stream.

	buffer_position: INTEGER
			-- Current write position in accumulator buffer.

	trim_buffer (a_frames: INTEGER)
			-- Trim buffer to specified number of frames.
		require
			buffer_exists: attached buffer
			frames_valid: a_frames > 0
		local
			l_new_buffer: AUDIO_BUFFER
			i, ch: INTEGER
		do
			if attached buffer as buf then
				create l_new_buffer.make (a_frames, buf.channels, buf.bits_per_sample)
				from i := 0 until i >= a_frames loop
					from ch := 0 until ch >= buf.channels loop
						l_new_buffer.set_sample (i, ch, buf.sample_at (i, ch))
						ch := ch + 1
					end
					i := i + 1
				end
				buffer := l_new_buffer
			end
		end

	sleep_ms (a_ms: INTEGER)
			-- Sleep for milliseconds.
		external
			"C inline use <windows.h>"
		alias
			"Sleep((DWORD)$a_ms);"
		end

	current_time_ms: REAL_64
			-- Current time in milliseconds.
		external
			"C inline use <windows.h>"
		alias
			"return (EIF_REAL_64)GetTickCount64();"
		end

invariant
	device_attached: device /= Void
	last_error_attached: last_error /= Void
	sample_rate_positive: sample_rate > 0
	channels_positive: channels > 0
	bits_valid: bits_per_sample = 8 or bits_per_sample = 16 or bits_per_sample = 24 or bits_per_sample = 32

end
