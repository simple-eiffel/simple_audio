note
	description: "[
		An output AUDIO_STREAM (WASAPI) as an AUDIO_SINK (0.2.0). The stream
		keeps its own contracts; this adapter speaks the sink's.
	]"

class
	AUDIO_STREAM_SINK

inherit
	AUDIO_SINK

create
	make

feature {NONE} -- Initialization

	make (a_stream: AUDIO_STREAM)
		require
			output: a_stream.is_valid and a_stream.is_output
		do
			stream := a_stream
		ensure
			kept: stream = a_stream
		end

feature -- Access

	stream: AUDIO_STREAM

feature -- Format

	sample_rate: INTEGER
		do
			Result := stream.sample_rate
		end

	channels: INTEGER
		do
			Result := stream.channels
		end

	bits_per_sample: INTEGER
		do
			Result := stream.bits_per_sample
		end

feature -- Status

	is_ready: BOOLEAN
		do
			Result := stream.is_valid
		end

	is_started: BOOLEAN
		do
			Result := stream.is_started
		end

	available_frames: INTEGER
		do
			Result := stream.available_frames
		end

	buffered_frames: INTEGER
		do
			Result := (stream.buffer_size - stream.available_frames).max (0)
		end

feature -- Operations

	start
		do
			stream.start
		end

	stop
		do
			stream.stop
		end

	write_frames (a_buffer: AUDIO_BUFFER; a_first, a_count: INTEGER): INTEGER
		do
			if stream.is_started then
				Result := stream.write_frames (a_buffer, a_first, a_count)
			end
		end

	close
		do
			stream.close
		end

end
