# S03 - Contracts: simple_audio

**Status:** BACKWASH (reverse-engineered from implementation)
**Date:** 2026-01-23

---

## 1. SIMPLE_AUDIO Contracts

### Creation

```eiffel
make
    ensure
        initialized: is_initialized
```

### Feature Contracts

```eiffel
output_devices: ARRAYED_LIST [AUDIO_DEVICE]
    ensure
        result_attached: Result /= Void

input_devices: ARRAYED_LIST [AUDIO_DEVICE]
    ensure
        result_attached: Result /= Void

create_output_stream (a_device: AUDIO_DEVICE; a_sample_rate, a_channels, a_bits: INTEGER): detachable AUDIO_STREAM
    require
        device_valid: a_device /= Void
        device_is_output: a_device.is_output
        sample_rate_valid: a_sample_rate > 0
        channels_valid: a_channels > 0 and a_channels <= 8
        bits_valid: a_bits = 8 or a_bits = 16 or a_bits = 24 or a_bits = 32

create_input_stream (a_device: AUDIO_DEVICE; a_sample_rate, a_channels, a_bits: INTEGER): detachable AUDIO_STREAM
    require
        device_valid: a_device /= Void
        device_is_input: a_device.is_input
        sample_rate_valid: a_sample_rate > 0
        channels_valid: a_channels > 0 and a_channels <= 8
        bits_valid: a_bits = 8 or a_bits = 16 or a_bits = 24 or a_bits = 32
```

### Class Invariant

```eiffel
invariant
    output_devices_attached: internal_output_devices /= Void
    input_devices_attached: internal_input_devices /= Void
```

---

## 2. AUDIO_DEVICE Contracts

### Creation

```eiffel
make_from_handle (a_handle: POINTER; a_is_output: BOOLEAN)
    require
        handle_valid: a_handle /= default_pointer
    ensure
        handle_set: handle = a_handle
        direction_set: is_output = a_is_output
```

### Feature Contracts

```eiffel
name: STRING_32
    ensure
        result_attached: Result /= Void

id: STRING_32
    ensure
        result_attached: Result /= Void

is_input: BOOLEAN
    ensure
        opposite: Result = not is_output

same_device (other: AUDIO_DEVICE): BOOLEAN
    require
        other_attached: other /= Void

display_name: STRING_32
    ensure
        result_attached: Result /= Void
```

### Class Invariant

```eiffel
invariant
    name_attached: internal_name /= Void
    id_attached: internal_id /= Void
```

---

## 3. AUDIO_STREAM Contracts

### Creation

```eiffel
make_from_handle (a_handle: POINTER; a_is_output: BOOLEAN; a_sample_rate, a_channels, a_bits: INTEGER)
    require
        handle_valid: a_handle /= default_pointer
        sample_rate_valid: a_sample_rate > 0
        channels_valid: a_channels > 0
        bits_valid: a_bits > 0
    ensure
        handle_set: handle = a_handle
        direction_set: is_output = a_is_output
        sample_rate_set: sample_rate = a_sample_rate
        channels_set: channels = a_channels
        bits_set: bits_per_sample = a_bits
```

### Feature Contracts

```eiffel
is_input: BOOLEAN
    ensure
        opposite: Result = not is_output

available_frames: INTEGER
    require
        stream_valid: is_valid
    ensure
        non_negative: Result >= 0

start
    require
        stream_valid: is_valid
        not_started: not is_started

stop
    require
        stream_valid: is_valid
        is_running: is_started

write (a_buffer: AUDIO_BUFFER): INTEGER
    require
        stream_valid: is_valid
        is_running: is_started
        is_output_stream: is_output
        buffer_valid: a_buffer /= Void
        format_matches: a_buffer.channels = channels and a_buffer.bits_per_sample = bits_per_sample
    ensure
        non_negative: Result >= 0

read (a_buffer: AUDIO_BUFFER): INTEGER
    require
        stream_valid: is_valid
        is_running: is_started
        is_input_stream: is_input
        buffer_valid: a_buffer /= Void
        format_matches: a_buffer.channels = channels and a_buffer.bits_per_sample = bits_per_sample
    ensure
        non_negative: Result >= 0

close
    ensure
        handle_cleared: handle = default_pointer
        stopped: not is_started
```

### Class Invariant

```eiffel
invariant
    sample_rate_positive: sample_rate > 0
    channels_positive: channels > 0
    bits_positive: bits_per_sample > 0
```

---

## 4. AUDIO_BUFFER Contracts

### Creation

```eiffel
make (a_frames, a_channels, a_bits: INTEGER)
    require
        frames_positive: a_frames > 0
        channels_positive: a_channels > 0 and a_channels <= 8
        bits_valid: a_bits = 8 or a_bits = 16 or a_bits = 24 or a_bits = 32
    ensure
        frame_count_set: frame_count = a_frames
        channels_set: channels = a_channels
        bits_set: bits_per_sample = a_bits
        valid: is_valid

make_from_wav (a_path: READABLE_STRING_GENERAL)
    require
        path_not_empty: not a_path.is_empty
    ensure
        error_set_on_failure: not is_valid implies not last_error.is_empty
```

### Feature Contracts

```eiffel
byte_count: INTEGER
    ensure
        correct: Result = frame_count * bytes_per_frame

duration: REAL_64
    require
        valid_sample_rate: sample_rate > 0
    ensure
        non_negative: Result >= 0.0

sample_at (a_frame, a_channel: INTEGER): REAL_64
    require
        frame_valid: a_frame >= 0 and a_frame < frame_count
        channel_valid: a_channel >= 0 and a_channel < channels
    ensure
        in_range: Result >= -1.0 and Result <= 1.0

set_sample (a_frame, a_channel: INTEGER; a_value: REAL_64)
    require
        frame_valid: a_frame >= 0 and a_frame < frame_count
        channel_valid: a_channel >= 0 and a_channel < channels
        value_valid: a_value >= -1.0 and a_value <= 1.0

save_to_wav (a_path: READABLE_STRING_GENERAL): BOOLEAN
    require
        path_not_empty: not a_path.is_empty
        is_valid: is_valid

fill_sine_wave (a_frequency: REAL_64; a_sample_rate: INTEGER)
    require
        frequency_positive: a_frequency > 0.0
        sample_rate_positive: a_sample_rate > 0
```

### Class Invariant

```eiffel
invariant
    data_attached: data /= Void
    channels_positive: channels > 0
    bits_valid: bits_per_sample = 8 or bits_per_sample = 16 or bits_per_sample = 24 or bits_per_sample = 32
    sample_rate_positive: sample_rate > 0
    error_valid: last_error /= Void
```

---

## 5. Contract Summary

| Class | Preconditions | Postconditions | Invariants |
|-------|---------------|----------------|------------|
| SIMPLE_AUDIO | 10 | 5 | 2 |
| AUDIO_DEVICE | 2 | 6 | 2 |
| AUDIO_STREAM | 13 | 9 | 3 |
| AUDIO_BUFFER | 14 | 11 | 5 |
| **Total** | **39** | **31** | **12** |
