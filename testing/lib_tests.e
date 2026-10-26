note
	description: "Tests for simple_audio library"
	author: "Larry Rix"

class
	LIB_TESTS

inherit
	TEST_SET_BASE

feature -- Tests

	test_initialization
			-- Test audio system initialization.
		local
			audio: SIMPLE_AUDIO
		do
			create audio.make
			assert ("initialized", audio.is_initialized)
			audio.dispose
		end

	test_output_device_enumeration
			-- Test listing output devices.
		local
			audio: SIMPLE_AUDIO
			devices: ARRAYED_LIST [AUDIO_DEVICE]
		do
			create audio.make
			devices := audio.output_devices
			assert ("devices_not_void", devices /= Void)
			-- Most systems have at least one output device
			print ("  Output devices found: " + devices.count.out + "%N")
			across devices as d loop
				print ({STRING_32} "    - " + d.display_name + "%N")
				assert ("device_valid", d.is_valid)
				assert ("device_is_output", d.is_output)
			end
			audio.dispose
		end

	test_input_device_enumeration
			-- Test listing input devices.
		local
			audio: SIMPLE_AUDIO
			devices: ARRAYED_LIST [AUDIO_DEVICE]
		do
			create audio.make
			devices := audio.input_devices
			assert ("devices_not_void", devices /= Void)
			print ("  Input devices found: " + devices.count.out + "%N")
			across devices as d loop
				print ({STRING_32} "    - " + d.display_name + "%N")
				assert ("device_valid", d.is_valid)
				assert ("device_is_input", d.is_input)
			end
			audio.dispose
		end

	test_default_output_device
			-- Test getting default output device.
		local
			audio: SIMPLE_AUDIO
		do
			create audio.make
			if attached audio.default_output as dev then
				print ({STRING_32} "  Default output: " + dev.name + "%N")
				assert ("is_output", dev.is_output)
				assert ("has_name", not dev.name.is_empty)
			else
				print ("  No default output device%N")
			end
			audio.dispose
		end

	test_default_input_device
			-- Test getting default input device.
		local
			audio: SIMPLE_AUDIO
		do
			create audio.make
			if attached audio.default_input as dev then
				print ({STRING_32} "  Default input: " + dev.name + "%N")
				assert ("is_input", dev.is_input)
				assert ("has_name", not dev.name.is_empty)
			else
				print ("  No default input device%N")
			end
			audio.dispose
		end

	test_device_properties
			-- Test device name and ID retrieval.
		local
			audio: SIMPLE_AUDIO
		do
			create audio.make
			if attached audio.default_output as dev then
				assert ("name_not_empty", not dev.name.is_empty)
				assert ("id_not_empty", not dev.id.is_empty)
				assert ("display_name_not_empty", not dev.display_name.is_empty)
				print ({STRING_32} "  Name: " + dev.name + "%N")
				print ({STRING_32} "  ID: " + dev.id + "%N")
			end
			audio.dispose
		end

	test_device_count
			-- Test device counting.
		local
			audio: SIMPLE_AUDIO
		do
			create audio.make
			assert ("counts_match", audio.output_device_count = audio.output_devices.count)
			assert ("input_counts_match", audio.input_device_count = audio.input_devices.count)
			print ("  Output: " + audio.output_device_count.out + ", Input: " + audio.input_device_count.out + "%N")
			audio.dispose
		end

	test_refresh
			-- Test device re-enumeration.
		local
			audio: SIMPLE_AUDIO
			count1, count2: INTEGER
		do
			create audio.make
			count1 := audio.output_device_count
			audio.refresh
			count2 := audio.output_device_count
			assert ("count_consistent", count1 = count2)
			audio.dispose
		end

	test_buffer_creation
			-- Test audio buffer creation.
		local
			buffer: AUDIO_BUFFER
		do
			create buffer.make (1024, 2, 16)
			assert ("frame_count", buffer.frame_count = 1024)
			assert ("channels", buffer.channels = 2)
			assert ("bits", buffer.bits_per_sample = 16)
			assert ("bytes_per_frame", buffer.bytes_per_frame = 4)
			assert ("byte_count", buffer.byte_count = 4096)
		end

	test_buffer_8bit
			-- Test 8-bit buffer.
		local
			buffer: AUDIO_BUFFER
		do
			create buffer.make (100, 1, 8)
			assert ("bytes_per_sample", buffer.bytes_per_sample = 1)
			assert ("byte_count", buffer.byte_count = 100)
		end

	test_buffer_24bit
			-- Test 24-bit buffer.
		local
			buffer: AUDIO_BUFFER
		do
			create buffer.make (100, 2, 24)
			assert ("bytes_per_sample", buffer.bytes_per_sample = 3)
			assert ("bytes_per_frame", buffer.bytes_per_frame = 6)
		end

	test_buffer_32bit
			-- Test 32-bit buffer.
		local
			buffer: AUDIO_BUFFER
		do
			create buffer.make (100, 2, 32)
			assert ("bytes_per_sample", buffer.bytes_per_sample = 4)
			assert ("bytes_per_frame", buffer.bytes_per_frame = 8)
		end

	test_buffer_sample_access
			-- Test reading/writing samples.
		local
			buffer: AUDIO_BUFFER
			value: REAL_64
		do
			create buffer.make (10, 2, 16)

			-- Set and get
			buffer.set_sample (0, 0, 0.5)
			value := buffer.sample_at (0, 0)
			assert ("value_close", (value - 0.5).abs < 0.01)

			buffer.set_sample (5, 1, -0.75)
			value := buffer.sample_at (5, 1)
			assert ("negative_close", (value - (-0.75)).abs < 0.01)
		end

	test_buffer_clear
			-- Test buffer clearing.
		local
			buffer: AUDIO_BUFFER
		do
			create buffer.make (100, 2, 16)
			buffer.set_sample (50, 0, 0.9)
			buffer.clear
			assert ("cleared", buffer.sample_at (50, 0).abs < 0.01)
		end

	test_buffer_sine_wave
			-- Test sine wave generation.
		local
			buffer: AUDIO_BUFFER
			i: INTEGER
			has_positive, has_negative: BOOLEAN
		do
			create buffer.make (1000, 1, 16)
			buffer.fill_sine_wave (440.0, 44100)

			-- Check that we have both positive and negative values (it's a wave)
			from i := 0 until i >= 1000 loop
				if buffer.sample_at (i, 0) > 0.1 then
					has_positive := True
				elseif buffer.sample_at (i, 0) < -0.1 then
					has_negative := True
				end
				i := i + 1
			end

			assert ("has_positive_samples", has_positive)
			assert ("has_negative_samples", has_negative)
		end

	test_empty_device
			-- Test empty device creation.
		local
			dev: AUDIO_DEVICE
		do
			create dev.make_empty
			assert ("not_valid", not dev.is_valid)
			assert ("is_output", dev.is_output)
		end

	test_empty_buffer
			-- Test empty buffer creation.
		local
			buffer: AUDIO_BUFFER
		do
			create buffer.make_empty
			assert ("zero_frames", buffer.frame_count = 0)
			assert ("has_data", buffer.data /= Void)
		end


feature -- MP3 decoding and streaming (0.2.0, GW-25)

	test_mp3_decodes_to_the_tone_it_holds
			-- The fixture is two seconds of 440 Hz, mono, 44.1 kHz: Media
			-- Foundation decodes it to that - about 88,200 frames crossing zero
			-- about 1,760 times - and a seek to 1 second leaves about half.
		local
			d: AUDIO_DECODER
			l_frames, l_crossings, i: INTEGER
			l_last: REAL_64
			l_done: BOOLEAN
		do
			create d.make
			assert ("opens " + d.last_error.to_string_8, d.open (fixture_path))
			assert ("44.1 kHz", d.sample_rate = 44100)
			assert ("mono", d.channels = 1)
			assert ("two seconds: " + d.duration_seconds.out, (d.duration_seconds - 2.0).abs < 0.1)
			from until l_done loop
				if attached d.read_chunk (4096) as al_chunk then
					from i := 0 until i >= al_chunk.frame_count loop
							-- only clearly signed samples count: the encoder's quiet
							-- padding flickers about zero without being the tone
						if al_chunk.sample_at (i, 0).abs > 0.1 then
							if l_last /= 0.0 and then (al_chunk.sample_at (i, 0) > 0.0) /= (l_last > 0.0) then
								l_crossings := l_crossings + 1
							end
							l_last := al_chunk.sample_at (i, 0)
						end
						i := i + 1
					end
					l_frames := l_frames + al_chunk.frame_count
				else
					l_done := True
				end
			end
			assert ("at the end", d.is_at_end)
			assert ("about 88,200 frames: " + l_frames.out, (l_frames - 88200).abs < 3000)
			assert ("440 Hz: " + l_crossings.out + " zero crossings", (l_crossings - 1760).abs < 90)
			assert ("seeks", d.seek (1.0))
			assert ("from one second: " + d.position_seconds.out, (d.position_seconds - 1.0).abs < 0.05)
			l_frames := 0
			from l_done := False until l_done loop
				if attached d.read_chunk (4096) as al_chunk then
					l_frames := l_frames + al_chunk.frame_count
				else
					l_done := True
				end
			end
			assert ("about half left: " + l_frames.out, (l_frames - 44100).abs < 3000)
			d.close
			assert ("closed", not d.is_open)
		end

	test_a_file_streams_into_a_sink
			-- The player keeps a 0.1-second sink topped up while it drains in
			-- 50-millisecond steps: everything is heard, the clock follows,
			-- the end is told once, and a seek replays from there.
		local
			d: AUDIO_DECODER
			l_sink: AUDIO_TEST_SINK
			l_player: AUDIO_FILE_PLAYER
			i: INTEGER
		do
			create d.make
			assert ("opens", d.open (fixture_path))
			create l_sink.make (44100, 1, 4410)
			create l_player.make (d, l_sink)
			l_player.set_on_finished (agent do finished_count := finished_count + 1 end)
			finished_count := 0
			l_player.play
			assert ("playing", l_player.is_playing)
			from i := 1 until i > 20 loop
				l_sink.drain (2205)
				l_player.pump
				i := i + 1
			end
			assert ("the clock follows what is heard: " + l_player.position_seconds.out, (l_player.position_seconds - 1.0).abs < 0.1)
			l_player.pause
			l_sink.drain (2205)
			assert ("paused: nothing more is heard", l_sink.queued > 0 and l_player.is_paused)
			l_player.play
			from i := 1 until l_player.is_finished or i > 200 loop
				l_sink.drain (2205)
				l_player.pump
				i := i + 1
			end
			assert ("finished", l_player.is_finished)
			assert ("told once", finished_count = 1)
			assert ("everything was given: " + l_sink.heard.count.out, (l_sink.heard.count - 88200).abs < 3000)
			assert ("the clock at the end: " + l_player.position_seconds.out, (l_player.position_seconds - 2.0).abs < 0.1)
			l_sink.heard.wipe_out
			l_player.seek (1.5)
			l_player.play
			from i := 1 until l_player.is_finished or i > 200 loop
				l_sink.drain (2205)
				l_player.pump
				i := i + 1
			end
			assert ("a seek replays the last half second: " + l_sink.heard.count.out, (l_sink.heard.count - 22050).abs < 3000)
			assert ("told again after the seek", finished_count = 2)
			d.close
		end

feature -- Scan 21

	test_scan21_play_starts_the_device_with_sound_queued
			-- A device takes nothing while stopped: `play' must start it, then
			-- fill it - not fill a stopped device that drops the audio.
		local
			d: AUDIO_DECODER
			l_sink: AUDIO_TEST_SINK
			l_player: AUDIO_FILE_PLAYER
		do
			create d.make
			assert ("opens", d.open (fixture_path))
			create l_sink.make (44100, 1, 4410)
			create l_player.make (d, l_sink)
			l_player.play
			assert ("started with sound queued: " + l_sink.queued.out, l_sink.is_started and l_sink.queued > 0)
			d.close
		end

	test_scan21_seek_forgets_what_the_device_held
			-- A seek drops the old audio the device still holds, so the clock
			-- reads the new place at once (and never goes below zero).
		local
			d: AUDIO_DECODER
			l_sink: AUDIO_TEST_SINK
			l_player: AUDIO_FILE_PLAYER
		do
			create d.make
			assert ("opens", d.open (fixture_path))
			create l_sink.make (44100, 1, 4410)
			create l_player.make (d, l_sink)
			l_player.play
			l_sink.drain (2205)
			l_player.pump
			l_player.seek (0.0)
			assert ("the old audio is forgotten", l_sink.queued = 0)
			assert ("the clock reads the new place: " + l_player.position_seconds.out, l_player.position_seconds.abs < 0.001)
			l_player.pump
			assert ("and fills again from there", l_sink.queued > 0)
			d.close
		end

	test_scan21_a_device_that_will_not_start_says_so
		local
			d: AUDIO_DECODER
			l_sink: AUDIO_TEST_SINK
			l_player: AUDIO_FILE_PLAYER
		do
			create d.make
			assert ("opens", d.open (fixture_path))
			create l_sink.make (44100, 1, 4410)
			l_sink.set_refuses_start (True)
			create l_player.make (d, l_sink)
			l_player.play
			assert ("not playing", not l_player.is_playing)
			assert ("and it says why", not l_player.last_error.is_empty)
			d.close
		end

feature {NONE} -- Fixtures

	finished_count: INTEGER

	fixture_path: STRING_32
			-- The 440 Hz MP3, by an absolute path.
		do
			Result := (create {EXECUTION_ENVIRONMENT}).current_working_path.extended ("testing").extended ("fixtures").extended ("tone_440_2s.mp3").name
		end

end
