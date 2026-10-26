note
	description: "[
		Compressed audio as PCM (0.2.0, simple_bible GW-25: MP3 for the audio
		Bible): whatever Windows decodes - MP3, AAC/M4A, WMA, WAV - through
		Media Foundation's source reader, as 16-bit samples at the file's own
		rate and channels, a chunk at a time, so an hour never sits decoded
		in memory. `seek' moves within the file. One decoder belongs to one
		processor (the reader is not shared).
	]"

class
	AUDIO_DECODER

create
	make

feature {NONE} -- Initialization

	make
		do
			create last_error.make_empty
		end

feature -- Access

	is_open: BOOLEAN
		do
			Result := handle /= default_pointer
		end

	sample_rate: INTEGER
	channels: INTEGER

	bits_per_sample: INTEGER = 16

	duration_seconds: REAL_64
			-- How long the file plays (0 when the file does not say).

	position_seconds: REAL_64
			-- Where the next chunk starts.
		require
			open: is_open
		do
			Result := c_position (handle) / 1.0e7
		end

	is_at_end: BOOLEAN
			-- Did the last `read_chunk' find nothing more?

	last_error: STRING_32

feature -- Operations

	open (a_path: READABLE_STRING_GENERAL): BOOLEAN
			-- Open `a_path' for decoding. True when Windows can decode it.
		require
			closed: not is_open
			path_given: not a_path.is_empty
		local
			l_path: NATIVE_STRING
			l_rate, l_channels: INTEGER
			l_duration: INTEGER_64
		do
			last_error.wipe_out
			is_at_end := False
			create l_path.make (a_path)
			handle := c_open (l_path.item, $l_rate, $l_channels, $l_duration)
			if handle /= default_pointer then
				sample_rate := l_rate
				channels := l_channels
				duration_seconds := l_duration / 1.0e7
				Result := True
			else
				last_error := {STRING_32} "Windows cannot decode " + a_path.to_string_32
			end
		ensure
			open_when_true: Result = is_open
			format_when_open: Result implies (sample_rate > 0 and channels > 0)
		end

	read_chunk (a_max_frames: INTEGER): detachable AUDIO_BUFFER
			-- Up to `a_max_frames' more frames; Void at the end (`is_at_end')
			-- or on an error (`last_error').
		require
			open: is_open
			positive: a_max_frames > 0
		local
			l_bytes: MANAGED_POINTER
			l_got, l_status, l_frames: INTEGER
			l_buffer: AUDIO_BUFFER
		do
			create l_bytes.make (a_max_frames * channels * 2)
			l_status := c_read (handle, l_bytes.item, l_bytes.count, $l_got)
			if l_status = 1 and l_got > 0 then
				l_frames := l_got // (channels * 2)
				create l_buffer.make (l_frames, channels, 16)
				l_buffer.set_sample_rate (sample_rate)
				l_buffer.data.item.memory_copy (l_bytes.item, l_frames * channels * 2)
				Result := l_buffer
			elseif l_status = 0 then
				is_at_end := True
			else
				last_error := {STRING_32} "decoding failed"
			end
		ensure
			bounded: attached Result as al_r implies (al_r.frame_count >= 1 and al_r.frame_count <= a_max_frames)
			format: attached Result as al_r implies (al_r.channels = channels and al_r.sample_rate = sample_rate)
		end

	seek (a_seconds: REAL_64): BOOLEAN
			-- Continue from `a_seconds' into the file. True when it moved.
		require
			open: is_open
			in_file: a_seconds >= 0.0
		do
			Result := c_seek (handle, (a_seconds * 1.0e7).truncated_to_integer_64) = 1
			if Result then
				is_at_end := False
			end
		end

	close
		do
			if handle /= default_pointer then
				c_close (handle)
				handle := default_pointer
			end
		ensure
			closed: not is_open
		end

feature {NONE} -- Implementation

	handle: POINTER

	c_open (a_path, a_rate, a_channels, a_duration: POINTER): POINTER
		external "C inline use %"audio_mf.h%""
		alias "return audio_mf_open((const wchar_t*)$a_path, (int*)$a_rate, (int*)$a_channels, (LONGLONG*)$a_duration);"
		end

	c_read (a_handle, a_out: POINTER; a_cap: INTEGER; a_got: POINTER): INTEGER
		external "C inline use %"audio_mf.h%""
		alias "return audio_mf_read($a_handle, (unsigned char*)$a_out, $a_cap, (int*)$a_got);"
		end

	c_seek (a_handle: POINTER; a_at: INTEGER_64): INTEGER
		external "C inline use %"audio_mf.h%""
		alias "return audio_mf_seek($a_handle, (LONGLONG)$a_at);"
		end

	c_position (a_handle: POINTER): INTEGER_64
		external "C inline use %"audio_mf.h%""
		alias "return (EIF_INTEGER_64)audio_mf_position($a_handle);"
		end

	c_close (a_handle: POINTER)
		external "C inline use %"audio_mf.h%""
		alias "audio_mf_close($a_handle);"
		end

end
