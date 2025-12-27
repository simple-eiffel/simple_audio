note
	description: "[
		SIMPLE_AUDIO - Real-time Audio I/O Library for Eiffel

		Main facade for Windows Audio Session API (WASAPI) access.
		Provides device enumeration and audio streaming capabilities.

		Usage:
			audio: SIMPLE_AUDIO
			create audio.make

			-- List output devices
			across audio.output_devices as d loop
				print (d.name + "%N")
			end

			-- Create playback stream
			if attached audio.default_output as dev then
				if attached audio.create_output_stream (dev, 44100, 2, 16) as stream then
					stream.start
					-- write audio data...
					stream.stop
				end
			end
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	SIMPLE_AUDIO

create
	make

feature {NONE} -- Initialization

	make
			-- Initialize audio system.
		do
			initialize_wasapi
			create internal_output_devices.make (10)
			create internal_input_devices.make (10)
			refresh
		ensure
			initialized: is_initialized
		end

feature -- Access

	output_devices: ARRAYED_LIST [AUDIO_DEVICE]
			-- All available output (playback) devices.
		do
			Result := internal_output_devices.twin
		ensure
			result_attached: Result /= Void
		end

	input_devices: ARRAYED_LIST [AUDIO_DEVICE]
			-- All available input (recording) devices.
		do
			Result := internal_input_devices.twin
		ensure
			result_attached: Result /= Void
		end

	default_output: detachable AUDIO_DEVICE
			-- Default output device (Void if none).
		local
			l_handle: POINTER
			l_device: AUDIO_DEVICE
		do
			l_handle := c_get_default_device (Flow_render)
			if l_handle /= default_pointer then
				create l_device.make_from_handle (l_handle, True)
				Result := l_device
			end
		end

	default_input: detachable AUDIO_DEVICE
			-- Default input device (Void if none).
		local
			l_handle: POINTER
			l_device: AUDIO_DEVICE
		do
			l_handle := c_get_default_device (Flow_capture)
			if l_handle /= default_pointer then
				create l_device.make_from_handle (l_handle, False)
				Result := l_device
			end
		end

	output_device_count: INTEGER
			-- Number of output devices.
		do
			Result := internal_output_devices.count
		end

	input_device_count: INTEGER
			-- Number of input devices.
		do
			Result := internal_input_devices.count
		end

feature -- Status

	is_initialized: BOOLEAN
			-- Is audio system initialized?
		do
			Result := c_is_initialized
		end

feature -- Operations

	refresh
			-- Re-enumerate all audio devices.
		local
			i, n: INTEGER
			l_handle: POINTER
			l_device: AUDIO_DEVICE
		do
			internal_output_devices.wipe_out
			internal_input_devices.wipe_out

			-- Enumerate output devices
			n := c_device_count (Flow_render)
			from i := 0 until i >= n loop
				l_handle := c_get_device (Flow_render, i)
				if l_handle /= default_pointer then
					create l_device.make_from_handle (l_handle, True)
					internal_output_devices.extend (l_device)
				end
				i := i + 1
			end

			-- Enumerate input devices
			n := c_device_count (Flow_capture)
			from i := 0 until i >= n loop
				l_handle := c_get_device (Flow_capture, i)
				if l_handle /= default_pointer then
					create l_device.make_from_handle (l_handle, False)
					internal_input_devices.extend (l_device)
				end
				i := i + 1
			end
		end

	create_output_stream (a_device: AUDIO_DEVICE; a_sample_rate, a_channels, a_bits: INTEGER): detachable AUDIO_STREAM
			-- Create output stream for device.
		require
			device_valid: a_device /= Void
			device_is_output: a_device.is_output
			sample_rate_valid: a_sample_rate > 0
			channels_valid: a_channels > 0 and a_channels <= 8
			bits_valid: a_bits = 8 or a_bits = 16 or a_bits = 24 or a_bits = 32
		local
			l_handle: POINTER
		do
			l_handle := c_stream_create (a_device.handle, 1, a_sample_rate, a_channels, a_bits)
			if l_handle /= default_pointer then
				create Result.make_from_handle (l_handle, True, a_sample_rate, a_channels, a_bits)
			end
		end

	create_input_stream (a_device: AUDIO_DEVICE; a_sample_rate, a_channels, a_bits: INTEGER): detachable AUDIO_STREAM
			-- Create input stream for device.
		require
			device_valid: a_device /= Void
			device_is_input: a_device.is_input
			sample_rate_valid: a_sample_rate > 0
			channels_valid: a_channels > 0 and a_channels <= 8
			bits_valid: a_bits = 8 or a_bits = 16 or a_bits = 24 or a_bits = 32
		local
			l_handle: POINTER
		do
			l_handle := c_stream_create (a_device.handle, 0, a_sample_rate, a_channels, a_bits)
			if l_handle /= default_pointer then
				create Result.make_from_handle (l_handle, False, a_sample_rate, a_channels, a_bits)
			end
		end

feature -- Cleanup

	dispose
			-- Release audio system resources.
		do
			c_cleanup
		end

feature {NONE} -- Implementation

	internal_output_devices: ARRAYED_LIST [AUDIO_DEVICE]
	internal_input_devices: ARRAYED_LIST [AUDIO_DEVICE]

	Flow_render: INTEGER = 0
	Flow_capture: INTEGER = 1

	initialize_wasapi
			-- Initialize WASAPI.
		local
			l_ignored: BOOLEAN
		do
			l_ignored := c_init
		end

feature {NONE} -- C externals

	c_init: BOOLEAN
		external
			"C inline use %"audio_bridge.h%""
		alias
			"return (EIF_BOOLEAN)audio_init();"
		end

	c_cleanup
		external
			"C inline use %"audio_bridge.h%""
		alias
			"audio_cleanup();"
		end

	c_is_initialized: BOOLEAN
		external
			"C inline use %"audio_bridge.h%""
		alias
			"return (EIF_BOOLEAN)(g_enumerator != NULL);"
		end

	c_device_count (a_flow: INTEGER): INTEGER
		external
			"C inline use %"audio_bridge.h%""
		alias
			"return (EIF_INTEGER)audio_device_count((int)$a_flow);"
		end

	c_get_device (a_flow, a_index: INTEGER): POINTER
		external
			"C inline use %"audio_bridge.h%""
		alias
			"return (EIF_POINTER)audio_get_device((int)$a_flow, (int)$a_index);"
		end

	c_get_default_device (a_flow: INTEGER): POINTER
		external
			"C inline use %"audio_bridge.h%""
		alias
			"return (EIF_POINTER)audio_get_default_device((int)$a_flow);"
		end

	c_stream_create (a_device: POINTER; a_is_render, a_sample_rate, a_channels, a_bits: INTEGER): POINTER
		external
			"C inline use %"audio_bridge.h%""
		alias
			"return (EIF_POINTER)audio_stream_create($a_device, (int)$a_is_render, (int)$a_sample_rate, (int)$a_channels, (int)$a_bits);"
		end

invariant
	output_devices_attached: internal_output_devices /= Void
	input_devices_attached: internal_input_devices /= Void

end
