note
	description: "[
		AUDIO_DEVICE - Audio Device Information

		Represents a single audio endpoint (speaker, microphone, etc.)
		from the Windows Audio Session API.

		Query device properties like name and ID.
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

invariant
	name_attached: internal_name /= Void
	id_attached: internal_id /= Void

end
