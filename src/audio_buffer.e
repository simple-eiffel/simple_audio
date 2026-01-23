note
	description: "[
		AUDIO_BUFFER - PCM Audio Data Buffer

		Holds raw PCM audio data for reading/writing to audio streams.
		Supports 8, 16, 24, and 32-bit samples.
		Can load from WAV files (PCM format only).

		Usage:
			buffer: AUDIO_BUFFER

			-- Create stereo 16-bit buffer
			create buffer.make (1024, 2, 16)

			-- Load from WAV file
			create buffer.make_from_wav ("sound.wav")
			if buffer.is_valid then
				print ("Loaded " + buffer.duration.out + " seconds%N")
			end

			-- Fill with sine wave
			buffer.fill_sine_wave (440.0, 44100)

			-- Access samples
			print (buffer.sample_at (0, 0).out)  -- Left channel, frame 0
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	AUDIO_BUFFER

create
	make,
	make_empty,
	make_from_wav

feature {NONE} -- Initialization

	make (a_frames, a_channels, a_bits: INTEGER)
			-- Create buffer with given format.
		require
			frames_positive: a_frames > 0
			channels_positive: a_channels > 0 and a_channels <= 8
			bits_valid: a_bits = 8 or a_bits = 16 or a_bits = 24 or a_bits = 32
		local
			l_size: INTEGER
		do
			frame_count := a_frames
			channels := a_channels
			bits_per_sample := a_bits
			bytes_per_sample := bits_per_sample // 8
			bytes_per_frame := channels * bytes_per_sample
			l_size := frame_count * bytes_per_frame
			create data.make (l_size)
			sample_rate := 44100
			is_valid := True
			last_error := ""
		ensure
			frame_count_set: frame_count = a_frames
			channels_set: channels = a_channels
			bits_set: bits_per_sample = a_bits
			valid: is_valid
		end

	make_empty
			-- Create empty buffer for testing.
		do
			frame_count := 0
			channels := 2
			bits_per_sample := 16
			bytes_per_sample := 2
			bytes_per_frame := 4
			create data.make (0)
			sample_rate := 44100
			is_valid := True
			last_error := ""
		end

	make_from_wav (a_path: READABLE_STRING_GENERAL)
			-- Load PCM audio data from WAV file.
		require
			path_not_empty: not a_path.is_empty
		local
			l_file: RAW_FILE
			l_header: MANAGED_POINTER
			l_chunk_id: STRING
			l_chunk_size, l_audio_format, l_num_channels, l_bits: INTEGER
			l_rate, l_data_size, l_pos: INTEGER
			l_found_fmt, l_found_data: BOOLEAN
		do
			-- Initialize defaults
			sample_rate := 44100
			channels := 2
			bits_per_sample := 16
			bytes_per_sample := 2
			bytes_per_frame := 4
			frame_count := 0
			create data.make (0)
			is_valid := False
			last_error := ""

			create l_file.make_with_name (a_path)
			if not l_file.exists then
				last_error := "File not found"
			else
				l_file.open_read
				create l_header.make (44)

				-- Read RIFF header (12 bytes)
				if l_file.count < 44 then
					last_error := "File too small"
				else
					l_file.read_to_managed_pointer (l_header, 0, 12)
					l_chunk_id := read_four_chars (l_header, 0)

					if not l_chunk_id.same_string ("RIFF") then
						last_error := "Not a RIFF file"
					else
						l_chunk_id := read_four_chars (l_header, 8)
						if not l_chunk_id.same_string ("WAVE") then
							last_error := "Not a WAVE file"
						else
							-- Parse chunks
							l_pos := 12
							from
							until l_found_fmt and l_found_data or l_pos >= l_file.count - 8
							loop
								l_file.go (l_pos)
								l_file.read_to_managed_pointer (l_header, 0, 8)
								l_chunk_id := read_four_chars (l_header, 0)
								l_chunk_size := l_header.read_integer_32_le (4)

								if l_chunk_id.same_string ("fmt ") then
									-- Format chunk
									if l_chunk_size >= 16 then
										l_file.read_to_managed_pointer (l_header, 0, 16)
										l_audio_format := l_header.read_integer_16_le (0)
										l_num_channels := l_header.read_integer_16_le (2)
										l_rate := l_header.read_integer_32_le (4)
										l_bits := l_header.read_integer_16_le (14)

										if l_audio_format /= 1 then
											last_error := "Not PCM format (compressed audio not supported)"
										elseif l_num_channels < 1 or l_num_channels > 8 then
											last_error := "Invalid channel count"
										elseif not (l_bits = 8 or l_bits = 16 or l_bits = 24 or l_bits = 32) then
											last_error := "Unsupported bit depth: " + l_bits.out
										else
											sample_rate := l_rate
											channels := l_num_channels
											bits_per_sample := l_bits
											bytes_per_sample := bits_per_sample // 8
											bytes_per_frame := channels * bytes_per_sample
											l_found_fmt := True
										end
									end
									l_pos := l_pos + 8 + l_chunk_size
								elseif l_chunk_id.same_string ("data") then
									-- Data chunk
									l_data_size := l_chunk_size
									if l_found_fmt and l_data_size > 0 and bytes_per_frame > 0 then
										frame_count := l_data_size // bytes_per_frame
										create data.make (l_data_size)
										l_file.read_to_managed_pointer (data, 0, l_data_size)
										l_found_data := True
										is_valid := True
									end
									l_pos := l_pos + 8 + l_chunk_size
								else
									-- Skip unknown chunk
									l_pos := l_pos + 8 + l_chunk_size
								end
								-- Ensure even alignment
								if l_chunk_size \\ 2 = 1 then
									l_pos := l_pos + 1
								end
							end

							if not l_found_fmt then
								last_error := "No fmt chunk found"
							elseif not l_found_data then
								last_error := "No data chunk found"
							end
						end
					end
				end
				l_file.close
			end
		ensure
			error_set_on_failure: not is_valid implies not last_error.is_empty
		end

feature -- Access

	frame_count: INTEGER
			-- Number of audio frames.

	channels: INTEGER
			-- Number of channels.

	bits_per_sample: INTEGER
			-- Bits per sample.

	bytes_per_sample: INTEGER
			-- Bytes per sample.

	bytes_per_frame: INTEGER
			-- Bytes per frame.

	sample_rate: INTEGER
			-- Sample rate in Hz.

	data: MANAGED_POINTER
			-- Raw PCM data.

	is_valid: BOOLEAN
			-- Was last operation successful?

	last_error: STRING
			-- Error message if not valid.

	byte_count: INTEGER
			-- Total size in bytes.
		do
			Result := frame_count * bytes_per_frame
		ensure
			correct: Result = frame_count * bytes_per_frame
		end

	duration: REAL_64
			-- Duration in seconds.
		require
			valid_sample_rate: sample_rate > 0
		do
			Result := frame_count.to_double / sample_rate.to_double
		ensure
			non_negative: Result >= 0.0
		end

	sample_at (a_frame, a_channel: INTEGER): REAL_64
			-- Get sample value at frame and channel (normalized -1.0 to 1.0).
		require
			frame_valid: a_frame >= 0 and a_frame < frame_count
			channel_valid: a_channel >= 0 and a_channel < channels
		local
			l_offset: INTEGER
			l_value: INTEGER
		do
			l_offset := (a_frame * bytes_per_frame) + (a_channel * bytes_per_sample)

			inspect bits_per_sample
			when 8 then
				l_value := data.read_natural_8 (l_offset).as_integer_32 - 128
				Result := l_value / 128.0
			when 16 then
				l_value := data.read_integer_16 (l_offset)
				Result := l_value / 32768.0
			when 24 then
				l_value := data.read_natural_8 (l_offset).as_integer_32
				l_value := l_value | (data.read_natural_8 (l_offset + 1).as_integer_32 |<< 8)
				l_value := l_value | (data.read_integer_8 (l_offset + 2).as_integer_32 |<< 16)
				Result := l_value / 8388608.0
			when 32 then
				l_value := data.read_integer_32 (l_offset)
				Result := l_value / 2147483648.0
			end
		ensure
			in_range: Result >= -1.0 and Result <= 1.0
		end

feature -- Element change

	set_sample (a_frame, a_channel: INTEGER; a_value: REAL_64)
			-- Set sample value at frame and channel (normalized -1.0 to 1.0).
		require
			frame_valid: a_frame >= 0 and a_frame < frame_count
			channel_valid: a_channel >= 0 and a_channel < channels
			value_valid: a_value >= -1.0 and a_value <= 1.0
		local
			l_offset: INTEGER
			l_int: INTEGER
		do
			l_offset := (a_frame * bytes_per_frame) + (a_channel * bytes_per_sample)

			inspect bits_per_sample
			when 8 then
				l_int := ((a_value * 127.0) + 128.0).truncated_to_integer.max (0).min (255)
				data.put_natural_8 (l_int.as_natural_8, l_offset)
			when 16 then
				l_int := (a_value * 32767.0).truncated_to_integer.max (-32768).min (32767)
				data.put_integer_16 (l_int.as_integer_16, l_offset)
			when 24 then
				l_int := (a_value * 8388607.0).truncated_to_integer.max (-8388608).min (8388607)
				data.put_natural_8 ((l_int & 0xFF).as_natural_8, l_offset)
				data.put_natural_8 (((l_int |>> 8) & 0xFF).as_natural_8, l_offset + 1)
				data.put_integer_8 ((l_int |>> 16).as_integer_8, l_offset + 2)
			when 32 then
				l_int := (a_value * 2147483647.0).truncated_to_integer
				data.put_integer_32 (l_int, l_offset)
			end
		end

	clear
			-- Zero all samples.
		local
			i: INTEGER
		do
			from i := 0 until i >= byte_count loop
				data.put_natural_8 (0, i)
				i := i + 1
			end
		end

feature -- Export

	save_to_wav (a_path: READABLE_STRING_GENERAL): BOOLEAN
			-- Save buffer to WAV file. Returns True on success.
		require
			path_not_empty: not a_path.is_empty
			is_valid: is_valid
		local
			l_file: RAW_FILE
			l_header: MANAGED_POINTER
			l_data_size: INTEGER
		do
			l_data_size := byte_count

			create l_file.make_create_read_write (a_path.to_string_8)
			if l_file.is_open_write then
				create l_header.make (44)

				-- RIFF header
				l_header.put_natural_8 (('R').code.as_natural_8, 0)
				l_header.put_natural_8 (('I').code.as_natural_8, 1)
				l_header.put_natural_8 (('F').code.as_natural_8, 2)
				l_header.put_natural_8 (('F').code.as_natural_8, 3)
				l_header.put_integer_32_le (36 + l_data_size, 4)
				l_header.put_natural_8 (('W').code.as_natural_8, 8)
				l_header.put_natural_8 (('A').code.as_natural_8, 9)
				l_header.put_natural_8 (('V').code.as_natural_8, 10)
				l_header.put_natural_8 (('E').code.as_natural_8, 11)

				-- fmt chunk
				l_header.put_natural_8 (('f').code.as_natural_8, 12)
				l_header.put_natural_8 (('m').code.as_natural_8, 13)
				l_header.put_natural_8 (('t').code.as_natural_8, 14)
				l_header.put_natural_8 ((' ').code.as_natural_8, 15)
				l_header.put_integer_32_le (16, 16)  -- chunk size
				l_header.put_integer_16_le (1, 20)   -- PCM format
				l_header.put_integer_16_le (channels.as_integer_16, 22)
				l_header.put_integer_32_le (sample_rate, 24)
				l_header.put_integer_32_le (sample_rate * bytes_per_frame, 28)  -- byte rate
				l_header.put_integer_16_le (bytes_per_frame.as_integer_16, 32)  -- block align
				l_header.put_integer_16_le (bits_per_sample.as_integer_16, 34)

				-- data chunk
				l_header.put_natural_8 (('d').code.as_natural_8, 36)
				l_header.put_natural_8 (('a').code.as_natural_8, 37)
				l_header.put_natural_8 (('t').code.as_natural_8, 38)
				l_header.put_natural_8 (('a').code.as_natural_8, 39)
				l_header.put_integer_32_le (l_data_size, 40)

				-- Write header
				l_file.put_managed_pointer (l_header, 0, 44)

				-- Write audio data
				l_file.put_managed_pointer (data, 0, l_data_size)

				l_file.close
				Result := True
			end
		end

feature -- Generation

	fill_sine_wave (a_frequency: REAL_64; a_sample_rate: INTEGER)
			-- Fill buffer with sine wave at given frequency.
		require
			frequency_positive: a_frequency > 0.0
			sample_rate_positive: a_sample_rate > 0
		local
			i, ch: INTEGER
			phase, delta, value: REAL_64
		do
			delta := (2.0 * Pi * a_frequency) / a_sample_rate.to_double
			phase := 0.0

			from i := 0 until i >= frame_count loop
				value := sine (phase) * 0.8  -- 80% amplitude to avoid clipping
				from ch := 0 until ch >= channels loop
					set_sample (i, ch, value)
					ch := ch + 1
				end
				phase := phase + delta
				if phase > 2.0 * Pi then
					phase := phase - 2.0 * Pi
				end
				i := i + 1
			end
		end

	fill_silence
			-- Fill buffer with silence.
		do
			clear
		end

feature {NONE} -- Implementation

	read_four_chars (a_ptr: MANAGED_POINTER; a_offset: INTEGER): STRING
			-- Read 4 ASCII characters from pointer.
		require
			ptr_valid: a_ptr /= Void
			offset_valid: a_offset >= 0 and a_offset + 4 <= a_ptr.count
		do
			create Result.make (4)
			Result.append_character (a_ptr.read_natural_8 (a_offset).to_character_8)
			Result.append_character (a_ptr.read_natural_8 (a_offset + 1).to_character_8)
			Result.append_character (a_ptr.read_natural_8 (a_offset + 2).to_character_8)
			Result.append_character (a_ptr.read_natural_8 (a_offset + 3).to_character_8)
		ensure
			result_count: Result.count = 4
		end

feature {NONE} -- Constants

	Pi: REAL_64 = 3.14159265358979323846
			-- Mathematical constant Pi.

feature {NONE} -- Math

	sine (x: REAL_64): REAL_64
			-- Sine function.
		external
			"C inline"
		alias
			"return (EIF_REAL_64)sin((double)$x);"
		end

invariant
	data_attached: data /= Void
	channels_positive: channels > 0
	bits_valid: bits_per_sample = 8 or bits_per_sample = 16 or bits_per_sample = 24 or bits_per_sample = 32
	sample_rate_positive: sample_rate > 0
	error_valid: last_error /= Void

end
