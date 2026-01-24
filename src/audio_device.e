note
	description: "[
		AUDIO_DEVICE - Audio Device Information

		Represents a single audio endpoint (speaker, microphone, etc.)
		from the Windows Audio Session API.

		Query device properties like name and ID.
		Control volume and monitor peak levels.

		Usage:
			device: AUDIO_DEVICE

			-- Get volume (0.0 to 1.0)
			print (device.volume.out + "%%N")

			-- Set volume
			device.set_volume (0.75)

			-- Monitor peak level (for VU meters)
			print (device.peak_level.out + "%%N")

			-- Mute/unmute
			device.mute
			device.unmute
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	AUDIO_DEVICE

create
	make_from_handle,
	make_empty

feature {NONE} -- Initialization

	make_from_handle (a_handle: POINTER; a_is_output: BOOLEAN)
			-- Create device from WASAPI handle.
		require
			handle_valid: a_handle /= default_pointer
		do
			handle := a_handle
			is_output := a_is_output
			fetch_properties
		ensure
			handle_set: handle = a_handle
			direction_set: is_output = a_is_output
		end

	make_empty
			-- Create empty device for testing.
		do
			handle := default_pointer
			is_output := True
			create internal_name.make_empty
			create internal_id.make_empty
		end

feature -- Access

	name: STRING_32
			-- Friendly name of this device.
		do
			Result := internal_name.twin
		ensure
			result_attached: Result /= Void
		end

	id: STRING_32
			-- Unique device identifier.
		do
			Result := internal_id.twin
		ensure
			result_attached: Result /= Void
		end

	handle: POINTER
			-- Native device handle (IMMDevice*).

feature -- Status

	is_output: BOOLEAN
			-- Is this an output (playback) device?

	is_input: BOOLEAN
			-- Is this an input (recording) device?
		do
			Result := not is_output
		ensure
			opposite: Result = not is_output
		end

	is_valid: BOOLEAN
			-- Is this device handle valid?
		do
			Result := handle /= default_pointer
		end

feature -- Volume Control

	volume: REAL_64
			-- Current volume level (0.0 to 1.0).
		require
			device_valid: is_valid
		do
			Result := c_get_volume (handle).to_double
		ensure
			in_range: Result >= 0.0 and Result <= 1.0
		end

	set_volume (a_level: REAL_64)
			-- Set volume level (0.0 to 1.0).
		require
			device_valid: is_valid
			level_valid: a_level >= 0.0 and a_level <= 1.0
		local
			l_ignored: INTEGER
		do
			l_ignored := c_set_volume (handle, a_level.truncated_to_real)
		ensure
			volume_set: (volume - a_level).abs < 0.01
		end

	is_muted: BOOLEAN
			-- Is device muted?
		require
			device_valid: is_valid
		do
			Result := c_get_mute (handle) /= 0
		end

	mute
			-- Mute the device.
		require
			device_valid: is_valid
		local
			l_ignored: INTEGER
		do
			l_ignored := c_set_mute (handle, 1)
		ensure
			muted: is_muted
		end

	unmute
			-- Unmute the device.
		require
			device_valid: is_valid
		local
			l_ignored: INTEGER
		do
			l_ignored := c_set_mute (handle, 0)
		ensure
			not_muted: not is_muted
		end

	toggle_mute
			-- Toggle mute state.
		require
			device_valid: is_valid
		do
			if is_muted then
				unmute
			else
				mute
			end
		end

feature -- Peak Level Monitoring

	peak_level: REAL_64
			-- Current peak audio level (0.0 to 1.0).
			-- Use for VU meters and audio visualization.
		require
			device_valid: is_valid
		do
			Result := c_get_peak_level (handle).to_double
		ensure
			in_range: Result >= 0.0 and Result <= 1.0
		end

feature -- Comparison

	same_device (other: AUDIO_DEVICE): BOOLEAN
			-- Is `other` the same physical device?
		require
			other_attached: other /= Void
		do
			Result := internal_id.same_string (other.id)
		end

feature -- Display

	display_name: STRING_32
			-- Formatted display name with direction.
		do
			create Result.make (internal_name.count + 10)
			if is_output then
				Result.append_string_general ("[OUT] ")
			else
				Result.append_string_general ("[IN] ")
			end
			Result.append (internal_name)
		ensure
			result_attached: Result /= Void
		end

feature {NONE} -- Implementation

	internal_name: STRING_32
	internal_id: STRING_32

	fetch_properties
			-- Fetch device name and ID from WASAPI.
		local
			l_buffer: MANAGED_POINTER
		do
			create l_buffer.make (512)  -- 256 wide chars
			create internal_name.make_empty
			create internal_id.make_empty

			-- Get friendly name
			if c_get_name (handle, l_buffer.item, 256) /= 0 then
				internal_name := wide_string_to_string_32 (l_buffer)
			else
				internal_name := {STRING_32} "Unknown Device"
			end

			-- Get device ID
			if c_get_id (handle, l_buffer.item, 256) /= 0 then
				internal_id := wide_string_to_string_32 (l_buffer)
			else
				internal_id := {STRING_32} "unknown-id"
			end
		end

	wide_string_to_string_32 (a_buffer: MANAGED_POINTER): STRING_32
			-- Convert wide string buffer to STRING_32.
		local
			i: INTEGER
			c: NATURAL_16
		do
			create Result.make (256)
			from i := 0 until i >= 255 loop
				c := a_buffer.read_natural_16 (i * 2)
				if c = 0 then
					i := 255  -- Exit loop
				else
					Result.append_character (c.to_character_32)
					i := i + 1
				end
			end
		end

feature {NONE} -- C externals

	c_get_name (a_device: POINTER; a_buffer: POINTER; a_size: INTEGER): INTEGER
		external
			"C inline use %"audio_bridge.h%""
		alias
			"return (EIF_INTEGER)audio_get_device_name($a_device, (wchar_t*)$a_buffer, (int)$a_size);"
		end

	c_get_id (a_device: POINTER; a_buffer: POINTER; a_size: INTEGER): INTEGER
		external
			"C inline use %"audio_bridge.h%""
		alias
			"return (EIF_INTEGER)audio_get_device_id($a_device, (wchar_t*)$a_buffer, (int)$a_size);"
		end

	c_release (a_device: POINTER)
		external
			"C inline use %"audio_bridge.h%""
		alias
			"audio_release_device($a_device);"
		end

	c_get_volume (a_device: POINTER): REAL_32
		external
			"C inline use %"audio_bridge.h%""
		alias
			"return (EIF_REAL_32)audio_get_device_volume($a_device);"
		end

	c_set_volume (a_device: POINTER; a_level: REAL_32): INTEGER
		external
			"C inline use %"audio_bridge.h%""
		alias
			"return (EIF_INTEGER)audio_set_device_volume($a_device, (float)$a_level);"
		end

	c_get_mute (a_device: POINTER): INTEGER
		external
			"C inline use %"audio_bridge.h%""
		alias
			"return (EIF_INTEGER)audio_get_device_mute($a_device);"
		end

	c_set_mute (a_device: POINTER; a_muted: INTEGER): INTEGER
		external
			"C inline use %"audio_bridge.h%""
		alias
			"return (EIF_INTEGER)audio_set_device_mute($a_device, (int)$a_muted);"
		end

	c_get_peak_level (a_device: POINTER): REAL_32
		external
			"C inline use %"audio_bridge.h%""
		alias
			"return (EIF_REAL_32)audio_get_device_peak_level($a_device);"
		end

invariant
	name_attached: internal_name /= Void
	id_attached: internal_id /= Void

end
