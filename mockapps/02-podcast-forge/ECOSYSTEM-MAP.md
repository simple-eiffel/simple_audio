# Podcast Forge - Ecosystem Integration

## simple_* Dependencies

### Required Libraries

| Library | Purpose | Integration Point |
|---------|---------|-------------------|
| simple_audio | WAV file I/O, sample manipulation, playback | Core audio processing |
| simple_json | Project configs, manifests, metadata | Project file management |
| simple_csv | Episode lists, analytics export | Reporting and data |
| simple_file | Asset management, path handling | File operations |
| simple_datetime | Timestamps, scheduling | Episode dates, build times |
| simple_hash | Content fingerprinting | Duplicate detection, caching |

### Optional Libraries

| Library | Purpose | When Needed |
|---------|---------|-------------|
| simple_template | Show notes generation | Automated documentation |
| simple_xml | RSS feed generation | Podcast publishing |
| simple_http | Remote asset fetching | Distributed workflows |
| simple_logger | Build logging | Debug and audit |
| simple_validation | Manifest validation | Strict mode |

## Integration Patterns

### simple_audio Integration

**Purpose:** Core audio file handling - loading, sample manipulation, saving.

**Usage:**
```eiffel
feature -- Audio Loading

    load_segment (a_path: READABLE_STRING_GENERAL): AUDIO_BUFFER
            -- Load audio segment for processing.
        require
            path_not_empty: not a_path.is_empty
        local
            l_buffer: AUDIO_BUFFER
        do
            create l_buffer.make_from_wav (a_path)
            if l_buffer.is_valid then
                Result := l_buffer
            else
                last_error := "Failed to load: " + l_buffer.last_error
            end
        ensure
            valid_or_error: Result /= Void or not last_error.is_empty
        end

feature -- Audio Processing

    normalize_loudness (a_buffer: AUDIO_BUFFER; a_target_lufs: REAL_64): AUDIO_BUFFER
            -- Normalize buffer to target loudness.
        require
            buffer_valid: a_buffer /= Void and then a_buffer.is_valid
            target_reasonable: a_target_lufs >= -30.0 and a_target_lufs <= 0.0
        local
            current_lufs, gain_db, gain_linear: REAL_64
            i, ch: INTEGER
            sample: REAL_64
        do
            -- Measure current loudness
            current_lufs := measure_integrated_loudness (a_buffer)

            -- Calculate required gain
            gain_db := a_target_lufs - current_lufs
            gain_linear := (10.0 ^ (gain_db / 20.0))

            -- Apply gain to all samples
            create Result.make (a_buffer.frame_count, a_buffer.channels, a_buffer.bits_per_sample)
            from i := 0 until i >= a_buffer.frame_count loop
                from ch := 0 until ch >= a_buffer.channels loop
                    sample := a_buffer.sample_at (i, ch) * gain_linear
                    Result.set_sample (i, ch, sample.max (-1.0).min (1.0))
                    ch := ch + 1
                end
                i := i + 1
            end
        ensure
            result_valid: Result /= Void and then Result.is_valid
            same_length: Result.frame_count = a_buffer.frame_count
        end

feature -- Audio Assembly

    concatenate_buffers (a_buffers: LIST [AUDIO_BUFFER]): AUDIO_BUFFER
            -- Concatenate multiple buffers into one.
        require
            not_empty: not a_buffers.is_empty
            same_format: buffers_same_format (a_buffers)
        local
            total_frames, offset, i, ch: INTEGER
            first: AUDIO_BUFFER
        do
            first := a_buffers.first

            -- Calculate total length
            across a_buffers as ic loop
                total_frames := total_frames + ic.frame_count
            end

            -- Create output buffer
            create Result.make (total_frames, first.channels, first.bits_per_sample)

            -- Copy each buffer
            offset := 0
            across a_buffers as buf loop
                from i := 0 until i >= buf.frame_count loop
                    from ch := 0 until ch >= buf.channels loop
                        Result.set_sample (offset + i, ch, buf.sample_at (i, ch))
                        ch := ch + 1
                    end
                    i := i + 1
                end
                offset := offset + buf.frame_count
            end
        ensure
            result_valid: Result /= Void and then Result.is_valid
        end
```

**Data flow:** WAV file -> AUDIO_BUFFER -> normalize/trim/fade -> concatenate -> save WAV

### simple_json Integration

**Purpose:** Project configuration, episode manifests, metadata storage.

**Usage:**
```eiffel
feature -- Project Loading

    load_project (a_path: READABLE_STRING_GENERAL): FORGE_PROJECT
            -- Load project configuration.
        require
            path_not_empty: not a_path.is_empty
        local
            l_json: SIMPLE_JSON
            l_obj: JSON_OBJECT
        do
            create l_json.make
            l_json.parse_file (a_path)

            if l_json.is_valid and then attached l_json.root_object as root then
                create Result.make
                if attached root.object_at ("project") as proj then
                    Result.set_name (proj.string_at ("name"))
                    Result.set_slug (proj.string_at ("slug"))
                    Result.set_description (proj.string_at ("description"))
                end
                if attached root.object_at ("audio") as audio then
                    Result.set_target_lufs (audio.number_at ("target_lufs"))
                    Result.set_sample_rate (audio.integer_at ("sample_rate"))
                end
                if attached root.object_at ("assets") as assets then
                    Result.set_intro_path (assets.string_at ("intro"))
                    Result.set_outro_path (assets.string_at ("outro"))
                end
            else
                create Result.make_default
                last_error := "Invalid project file"
            end
        end

feature -- Episode Manifest

    load_manifest (a_path: READABLE_STRING_GENERAL): FORGE_MANIFEST
            -- Load episode manifest.
        require
            path_not_empty: not a_path.is_empty
        local
            l_json: SIMPLE_JSON
            l_segment: FORGE_SEGMENT
        do
            create l_json.make
            l_json.parse_file (a_path)
            create Result.make

            if l_json.is_valid and then attached l_json.root_object as root then
                if attached root.object_at ("episode") as ep then
                    Result.set_number (ep.integer_at ("number"))
                    Result.set_title (ep.string_at ("title"))
                    Result.set_date (ep.string_at ("date"))
                end
                if attached root.array_at ("segments") as segs then
                    across segs as ic loop
                        if attached {JSON_OBJECT} ic as seg_obj then
                            create l_segment.make_from_json (seg_obj)
                            Result.add_segment (l_segment)
                        end
                    end
                end
            end
        end
```

**Data flow:** JSON file -> parse -> project/manifest objects -> process -> save JSON

### simple_hash Integration

**Purpose:** Content fingerprinting for caching and duplicate detection.

**Usage:**
```eiffel
feature -- Content Fingerprinting

    audio_fingerprint (a_buffer: AUDIO_BUFFER): STRING
            -- Generate SHA-256 fingerprint of audio content.
        require
            buffer_valid: a_buffer /= Void and then a_buffer.is_valid
        local
            l_hash: SIMPLE_HASH
        do
            create l_hash.make_sha256
            l_hash.update_managed_pointer (a_buffer.data, 0, a_buffer.byte_count)
            Result := l_hash.hex_digest
        ensure
            result_not_empty: not Result.is_empty
            correct_length: Result.count = 64
        end

feature -- Build Caching

    needs_rebuild (a_episode: FORGE_EPISODE): BOOLEAN
            -- Does episode need rebuilding?
        local
            l_current_hash, l_cached_hash: STRING
        do
            l_current_hash := manifest_hash (a_episode.manifest)
            l_cached_hash := load_cached_hash (a_episode.slug)
            Result := l_current_hash /~ l_cached_hash
        end
```

**Data flow:** Audio/manifest -> hash calculation -> cache lookup -> rebuild decision

### simple_template Integration

**Purpose:** Show notes and metadata generation.

**Usage:**
```eiffel
feature -- Show Notes Generation

    generate_show_notes (a_episode: FORGE_EPISODE): STRING
            -- Generate show notes from template.
        local
            l_template: SIMPLE_TEMPLATE
            l_context: TEMPLATE_CONTEXT
        do
            create l_template.make_from_file (project.show_notes_template)
            create l_context.make

            -- Populate context
            l_context.put (a_episode.title, "title")
            l_context.put (a_episode.number.out, "number")
            l_context.put (a_episode.description, "description")
            l_context.put (a_episode.date, "date")
            l_context.put (a_episode.duration_formatted, "duration")

            -- Add links
            l_context.put_list (a_episode.links, "links")

            -- Add guests
            l_context.put_list (a_episode.guests, "guests")

            Result := l_template.render (l_context)
        ensure
            result_not_empty: not Result.is_empty
        end
```

**Data flow:** Episode metadata + template -> render -> show notes HTML/Markdown

## Dependency Graph

```
podcast_forge
    |
    +-- simple_audio (required)
    |       +-- simple_file
    |       +-- ISE base
    |
    +-- simple_json (required)
    |       +-- ISE base
    |
    +-- simple_csv (required)
    |       +-- simple_file
    |       +-- ISE base
    |
    +-- simple_file (required)
    |       +-- ISE base
    |
    +-- simple_datetime (required)
    |       +-- ISE base
    |
    +-- simple_hash (required)
    |       +-- ISE base
    |
    +-- simple_template (optional - show notes)
    |       +-- simple_file
    |       +-- ISE base
    |
    +-- simple_xml (optional - RSS)
    |       +-- ISE base
    |
    +-- simple_logger (optional - debugging)
    |       +-- simple_file
    |       +-- simple_datetime
    |       +-- ISE base
    |
    +-- ISE base (required)
```

## ECF Configuration

```xml
<?xml version="1.0" encoding="ISO-8859-1"?>
<system xmlns="http://www.eiffel.com/developers/xml/configuration-1-23-0"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:schemaLocation="http://www.eiffel.com/developers/xml/configuration-1-23-0 http://www.eiffel.com/developers/xml/configuration-1-23-0.xsd"
        name="podcast_forge"
        uuid="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx">

    <target name="podcast_forge">
        <root class="FORGE_CLI" feature="make"/>

        <file_rule>
            <exclude>/EIFGENs$</exclude>
            <exclude>/\.git$</exclude>
        </file_rule>

        <option warning="warning" syntax="standard" manifest_array_type="mismatch_warning">
            <assertions precondition="true" postcondition="true" check="true" invariant="true"/>
        </option>

        <setting name="console_application" value="true"/>
        <setting name="executable_name" value="podcast-forge"/>
        <setting name="dead_code_removal" value="feature"/>

        <capability>
            <concurrency support="scoop"/>
            <void_safety support="all"/>
        </capability>

        <!-- simple_* dependencies -->
        <library name="simple_audio" location="$SIMPLE_EIFFEL/simple_audio/simple_audio.ecf"/>
        <library name="simple_json" location="$SIMPLE_EIFFEL/simple_json/simple_json.ecf"/>
        <library name="simple_csv" location="$SIMPLE_EIFFEL/simple_csv/simple_csv.ecf"/>
        <library name="simple_file" location="$SIMPLE_EIFFEL/simple_file/simple_file.ecf"/>
        <library name="simple_datetime" location="$SIMPLE_EIFFEL/simple_datetime/simple_datetime.ecf"/>
        <library name="simple_hash" location="$SIMPLE_EIFFEL/simple_hash/simple_hash.ecf"/>

        <!-- Optional dependencies (uncomment to enable features) -->
        <!-- <library name="simple_template" location="$SIMPLE_EIFFEL/simple_template/simple_template.ecf"/> -->
        <!-- <library name="simple_xml" location="$SIMPLE_EIFFEL/simple_xml/simple_xml.ecf"/> -->

        <!-- ISE dependencies -->
        <library name="base" location="$ISE_LIBRARY/library/base/base.ecf"/>

        <!-- Application source -->
        <cluster name="src" location="./src/" recursive="true"/>
    </target>

    <target name="podcast_forge_tests" extends="podcast_forge">
        <root class="TEST_APP" feature="make"/>
        <setting name="executable_name" value="podcast_forge_tests"/>
        <library name="simple_testing" location="$SIMPLE_EIFFEL/simple_testing/simple_testing.ecf"/>
        <cluster name="testing" location="./testing/" recursive="true"/>
    </target>

</system>
```

## Cross-Library Data Types

| Source Library | Type | Usage in Podcast Forge |
|----------------|------|------------------------|
| simple_audio | AUDIO_BUFFER | Audio data for processing |
| simple_json | JSON_OBJECT | Project and manifest data |
| simple_json | JSON_ARRAY | Segment lists, link lists |
| simple_csv | CSV_ROW | Episode analytics rows |
| simple_hash | HASH_DIGEST | Content fingerprints |
| simple_datetime | DATETIME | Episode dates, build times |
| simple_file | FILE_PATH | Asset paths |
| simple_template | TEMPLATE | Show notes generation |
