note
	description: "[
		AUDIO_BUFFER - PCM Audio Data Buffer

		Holds raw PCM audio data for reading/writing to audio streams.
		Supports 8, 16, 24, and 32-bit samples.

		Usage:
			buffer: AUDIO_BUFFER

			-- Create stereo 16-bit buffer
			create buffer.make (1024, 2, 16)

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
	make_empty

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
		ensure
			frame_count_set: frame_count = a_frames
			channels_set: channels = a_channels
			bits_set: bits_per_sample = a_bits
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

	data: MANAGED_POINTER
			-- Raw PCM data.

	byte_count: INTEGER
			-- Total size in bytes.
		do
			Result := frame_count * bytes_per_frame
		ensure
			correct: Result = frame_count * bytes_per_frame
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

end
