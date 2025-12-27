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
				print ("    - " + d.display_name + "%N")
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
				print ("    - " + d.display_name + "%N")
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
				print ("  Default output: " + dev.name + "%N")
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
				print ("  Default input: " + dev.name + "%N")
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
				print ("  Name: " + dev.name + "%N")
				print ("  ID: " + dev.id + "%N")
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

end
