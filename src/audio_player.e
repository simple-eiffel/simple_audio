note
	description: "[
		AUDIO_PLAYER - High-Level Audio Playback

		Simple, high-level audio playback for Eiffel applications.
		Provides one-liner playback and event-driven callbacks.

		Usage:
			player: AUDIO_PLAYER

			-- One-liner playback (blocking)
			create player.make
			player.play_file ("music.wav")

			-- Non-blocking playback with callback
			player.set_on_finished (agent on_playback_done)
			player.play_file_async ("music.wav")

			-- Control during playback
			player.pause
			player.resume
			player.stop

			-- Volume control
			player.set_volume (0.75)
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	AUDIO_PLAYER

create
	make,
	make_with_device

feature {NONE} -- Initialization

	make
			-- Create player using default output device.
		local
			l_audio: SIMPLE_AUDIO
		do
			create l_audio.make
			if attached l_audio.default_output as dev then
				device := dev
			else
				create device.make_empty
			end
			volume := 1.0
			create last_error.make_empty
			l_audio.dispose
		ensure
			volume_default: volume = 1.0
		end

	make_with_device (a_device: AUDIO_DEVICE)
			-- Create player for specific device.
		require
			device_valid: a_device /= Void and then a_device.is_valid
			device_is_output: a_device.is_output
		do
			device := a_device
			volume := 1.0
			create last_error.make_empty
		ensure
			device_set: device = a_device
			volume_default: volume = 1.0
		end

feature -- Access

	device: AUDIO_DEVICE
			-- Output device for playback.

	volume: REAL_64
			-- Playback volume (0.0 to 1.0).

	position: REAL_64
			-- Current playback position in seconds.
		do
			if attached current_buffer as buf and then buf.sample_rate > 0 then
				Result := current_frame.to_double / buf.sample_rate.to_double
			end
		ensure
			non_negative: Result >= 0.0
		end

	duration: REAL_64
			-- Total duration in seconds.
		do
			if attached current_buffer as buf then
				Result := buf.duration
			end
		ensure
			non_negative: Result >= 0.0
		end

	last_error: STRING
			-- Error message from last operation (empty if success).

feature -- Status

	is_playing: BOOLEAN
			-- Is audio currently playing?
		do
			Result := attached current_stream as s and then s.is_started and then not is_paused
		end

	is_paused: BOOLEAN
			-- Is playback paused?

	is_finished: BOOLEAN
			-- Has playback finished?
		do
			Result := attached current_buffer as buf and then current_frame >= buf.frame_count
		end

	has_error: BOOLEAN
			-- Did last operation fail?
		do
			Result := not last_error.is_empty
		end

feature -- Volume Control

	set_volume (a_volume: REAL_64)
			-- Set playback volume (0.0 to 1.0).
		require
			valid_range: a_volume >= 0.0 and a_volume <= 1.0
		do
			volume := a_volume
		ensure
			volume_set: volume = a_volume
		end

feature -- Callbacks

	on_finished_action: detachable PROCEDURE [TUPLE]
			-- Called when playback finishes.

	set_on_finished (a_action: PROCEDURE [TUPLE])
			-- Set callback for playback completion.
		require
			action_valid: a_action /= Void
		do
			on_finished_action := a_action
		ensure
			action_set: on_finished_action = a_action
		end

feature -- Playback Operations

	play_file (a_path: READABLE_STRING_GENERAL)
			-- Play WAV file synchronously (blocking).
		require
			path_not_empty: not a_path.is_empty
			not_playing: not is_playing
		local
			l_buffer: AUDIO_BUFFER
		do
			last_error.wipe_out
			create l_buffer.make_from_wav (a_path)

			if l_buffer.is_valid then
				play_buffer (l_buffer)
				wait_for_finish
			else
				last_error := l_buffer.last_error.twin
			end
		end

	play_file_async (a_path: READABLE_STRING_GENERAL)
			-- Play WAV file asynchronously (non-blocking).
			-- Use `on_finished_action` for completion notification.
		require
			path_not_empty: not a_path.is_empty
			not_playing: not is_playing
		local
			l_buffer: AUDIO_BUFFER
		do
			last_error.wipe_out
			create l_buffer.make_from_wav (a_path)

			if l_buffer.is_valid then
				play_buffer (l_buffer)
			else
				last_error := l_buffer.last_error.twin
			end
		end

	play_buffer (a_buffer: AUDIO_BUFFER)
			-- Play audio buffer.
		require
			buffer_valid: a_buffer /= Void and then a_buffer.is_valid
			not_playing: not is_playing
		local
			l_audio: SIMPLE_AUDIO
			l_stream: detachable AUDIO_STREAM
		do
			last_error.wipe_out
			current_buffer := a_buffer
			current_frame := 0
			is_paused := False

			create l_audio.make
			l_stream := l_audio.create_output_stream (device, a_buffer.sample_rate, a_buffer.channels, a_buffer.bits_per_sample)

			if attached l_stream as s then
				current_stream := s
				s.start
			else
				last_error := "Failed to create audio stream"
			end
		ensure
			playing_or_error: is_playing or has_error
		end

	pause
			-- Pause playback.
		require
			is_playing: is_playing
		do
			if attached current_stream as s then
				s.stop
				is_paused := True
			end
		ensure
			paused: is_paused
		end

	resume
			-- Resume paused playback.
		require
			is_paused: is_paused
		do
			if attached current_stream as s then
				s.start
				is_paused := False
			end
		ensure
			not_paused: not is_paused
		end

	stop
			-- Stop playback completely.
		do
			if attached current_stream as s then
				if s.is_started then
					s.stop
				end
				s.close
			end
			current_stream := Void
			current_buffer := Void
			current_frame := 0
			is_paused := False
		ensure
			stopped: not is_playing
			not_paused: not is_paused
		end

feature -- Processing

	pump
			-- Process audio - call regularly during async playback.
			-- Writes more audio data to the stream buffer.
		local
			l_frames_to_write, l_frames_written: INTEGER
			l_temp_buffer: AUDIO_BUFFER
			i, ch: INTEGER
			l_value: REAL_64
		do
			if attached current_stream as s and then attached current_buffer as buf then
				if s.is_started and then not is_paused then
					l_frames_to_write := s.available_frames.min (buf.frame_count - current_frame)

					if l_frames_to_write > 0 then
						-- Create temporary buffer with volume-adjusted samples
						create l_temp_buffer.make (l_frames_to_write, buf.channels, buf.bits_per_sample)

						from i := 0 until i >= l_frames_to_write loop
							from ch := 0 until ch >= buf.channels loop
								l_value := buf.sample_at (current_frame + i, ch) * volume
								l_temp_buffer.set_sample (i, ch, l_value.max (-1.0).min (1.0))
								ch := ch + 1
							end
							i := i + 1
						end

						l_frames_written := s.write (l_temp_buffer)
						current_frame := current_frame + l_frames_written
					end

					-- Check if finished
					if current_frame >= buf.frame_count then
						if attached on_finished_action as action then
							action.call ([])
						end
					end
				end
			end
		end

	wait_for_finish
			-- Block until playback finishes.
		do
			from
			until not is_playing or is_finished
			loop
				pump
				sleep_ms (10)
			end

			-- Let remaining buffer drain
			if attached current_buffer as buf then
				sleep_ms ((buf.duration * 1000).truncated_to_integer.min (2000))
			end

			stop
		end

feature {NONE} -- Implementation

	current_stream: detachable AUDIO_STREAM
			-- Active audio stream.

	current_buffer: detachable AUDIO_BUFFER
			-- Buffer being played.

	current_frame: INTEGER
			-- Current playback position in frames.

	sleep_ms (a_ms: INTEGER)
			-- Sleep for milliseconds.
		external
			"C inline use <windows.h>"
		alias
			"Sleep((DWORD)$a_ms);"
		end

invariant
	volume_valid: volume >= 0.0 and volume <= 1.0
	device_attached: device /= Void
	last_error_attached: last_error /= Void

end
