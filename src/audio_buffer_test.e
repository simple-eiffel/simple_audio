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
			create buffer.make_from_wav (""sound.wav"")
			if buffer.is_valid then
				print (""Loaded "" + buffer.duration.out + "" seconds%N"")
			end

			-- Fill with sine wave
			buffer.fill_sine_wave (440.0, 44100)

			-- Access samples
			print (buffer.sample_at (0, 0).out)  -- Left channel, frame 0
	]"
	author: "Larry Rix"
	date: "``$"
	revision: "``$"