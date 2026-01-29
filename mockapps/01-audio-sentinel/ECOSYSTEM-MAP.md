# Audio Sentinel - Ecosystem Integration

## simple_* Dependencies

### Required Libraries

| Library | Purpose | Integration Point |
|---------|---------|-------------------|
| simple_audio | WAV file loading, sample access, buffer manipulation | Core audio I/O - AUDIO_BUFFER for sample data |
| simple_json | Configuration files, profiles, JSON report output | Config loading, result serialization |
| simple_csv | Batch results export, analytics | Summary reports, data export |
| simple_file | File operations, path handling | File enumeration, existence checks |
| simple_logger | Audit logging, debug output | Operation logging, compliance trail |
| simple_datetime | Timestamps for reports and logging | ISO 8601 timestamps |

### Optional Libraries

| Library | Purpose | When Needed |
|---------|---------|-------------|
| simple_scheduler | Automated monitoring jobs | Monitor command with scheduling |
| simple_http | Webhook notifications | Alert integration |
| simple_email | Email alerts | Alert integration |
| simple_hash | File integrity checksums | Chain of custody reports |
| simple_template | HTML report generation | Fancy report output |
| simple_validation | Input validation | Complex config validation |

## Integration Patterns

### simple_audio Integration

**Purpose:** Core audio file loading and sample-level access for analysis.

**Usage:**
```eiffel
feature -- Audio Loading

    load_audio_file (a_path: READABLE_STRING_GENERAL): AUDIO_BUFFER
            -- Load audio file for analysis.
        require
            path_not_empty: not a_path.is_empty
        local
            l_buffer: AUDIO_BUFFER
        do
            create l_buffer.make_from_wav (a_path)
            if l_buffer.is_valid then
                Result := l_buffer
            else
                last_error := l_buffer.last_error
            end
        ensure
            valid_result_or_error: Result /= Void or not last_error.is_empty
        end

feature -- Sample Analysis

    calculate_rms (a_buffer: AUDIO_BUFFER; a_start, a_count: INTEGER): REAL_64
            -- Calculate RMS level for sample range.
        require
            buffer_valid: a_buffer /= Void and then a_buffer.is_valid
            range_valid: a_start >= 0 and a_start + a_count <= a_buffer.frame_count
        local
            i, ch: INTEGER
            sum, sample: REAL_64
        do
            from i := a_start until i >= a_start + a_count loop
                from ch := 0 until ch >= a_buffer.channels loop
                    sample := a_buffer.sample_at (i, ch)
                    sum := sum + (sample * sample)
                    ch := ch + 1
                end
                i := i + 1
            end
            Result := (sum / (a_count * a_buffer.channels)).sqrt
        ensure
            result_in_range: Result >= 0.0 and Result <= 1.0
        end
```

**Data flow:** WAV file -> AUDIO_BUFFER -> sample iteration -> analysis metrics

### simple_json Integration

**Purpose:** Configuration and profile management, JSON report output.

**Usage:**
```eiffel
feature -- Profile Loading

    load_profile (a_path: READABLE_STRING_GENERAL): SENTINEL_PROFILE
            -- Load quality profile from JSON file.
        require
            path_not_empty: not a_path.is_empty
        local
            l_json: SIMPLE_JSON
            l_obj: JSON_OBJECT
        do
            create l_json.make
            l_json.parse_file (a_path)
            if l_json.is_valid and then attached l_json.root_object as obj then
                create Result.make_from_json (obj)
            else
                create Result.make_default
            end
        end

feature -- Report Generation

    result_to_json (a_result: SENTINEL_RESULT): JSON_OBJECT
            -- Convert analysis result to JSON.
        require
            result_valid: a_result /= Void
        local
            l_issues: JSON_ARRAY
        do
            create Result.make
            Result.put_string (a_result.file_path, "file")
            Result.put_string (a_result.timestamp_iso8601, "timestamp")
            Result.put_string (a_result.profile_name, "profile")
            Result.put_number (a_result.duration_seconds, "duration_seconds")
            Result.put_string (a_result.overall_status, "overall_status")

            -- Add metrics object
            Result.put_object (metrics_to_json (a_result.metrics), "metrics")

            -- Add issues array
            create l_issues.make
            across a_result.issues as ic loop
                l_issues.add (issue_to_json (ic))
            end
            Result.put_array (l_issues, "issues")
        end
```

**Data flow:** JSON file -> parse -> profile object / result object -> serialize -> JSON output

### simple_csv Integration

**Purpose:** Batch results export for spreadsheet analysis and reporting.

**Usage:**
```eiffel
feature -- Batch Export

    export_batch_results (a_results: LIST [SENTINEL_RESULT]; a_path: READABLE_STRING_GENERAL)
            -- Export batch results to CSV file.
        require
            results_not_empty: not a_results.is_empty
            path_not_empty: not a_path.is_empty
        local
            l_csv: SIMPLE_CSV
            l_row: CSV_ROW
        do
            create l_csv.make

            -- Header row
            l_csv.add_header (<<"file", "status", "loudness_lufs", "true_peak_dbtp",
                               "silence_max_sec", "clipping_count", "issues">>)

            -- Data rows
            across a_results as ic loop
                create l_row.make
                l_row.add (ic.file_path)
                l_row.add (ic.overall_status)
                l_row.add (ic.metrics.integrated_loudness_lufs.out)
                l_row.add (ic.metrics.true_peak_dbtp.out)
                l_row.add (ic.metrics.max_silence_seconds.out)
                l_row.add (ic.metrics.clipping_count.out)
                l_row.add (ic.issue_count.out)
                l_csv.add_row (l_row)
            end

            l_csv.save_to_file (a_path)
        end
```

**Data flow:** Result list -> iterate -> CSV rows -> file output

### simple_logger Integration

**Purpose:** Audit trail for compliance, debug logging.

**Usage:**
```eiffel
feature -- Logging

    logger: SIMPLE_LOGGER
            -- Application logger.
        once
            create Result.make ("audio-sentinel")
            Result.set_level (Log_info)
            Result.add_file_handler ("sentinel.log")
        end

    log_analysis_start (a_file: STRING)
            -- Log start of analysis.
        do
            logger.info ("Analysis started: " + a_file)
        end

    log_analysis_complete (a_result: SENTINEL_RESULT)
            -- Log analysis completion with result.
        do
            if a_result.is_pass then
                logger.info ("Analysis PASSED: " + a_result.file_path)
            else
                logger.warn ("Analysis FAILED: " + a_result.file_path +
                             " (" + a_result.issue_count.out + " issues)")
            end
        end
```

**Data flow:** Events -> log messages -> file/console output

## Dependency Graph

```
audio_sentinel
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
    +-- simple_logger (required)
    |       +-- simple_file
    |       +-- simple_datetime
    |       +-- ISE base
    |
    +-- simple_datetime (required)
    |       +-- ISE base
    |
    +-- simple_scheduler (optional - monitoring)
    |       +-- simple_datetime
    |       +-- ISE base
    |
    +-- simple_http (optional - webhooks)
    |       +-- simple_json
    |       +-- ISE base
    |
    +-- simple_hash (optional - integrity)
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
        name="audio_sentinel"
        uuid="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx">

    <target name="audio_sentinel">
        <root class="SENTINEL_CLI" feature="make"/>

        <file_rule>
            <exclude>/EIFGENs$</exclude>
            <exclude>/\.git$</exclude>
        </file_rule>

        <option warning="warning" syntax="standard" manifest_array_type="mismatch_warning">
            <assertions precondition="true" postcondition="true" check="true" invariant="true"/>
        </option>

        <setting name="console_application" value="true"/>
        <setting name="executable_name" value="audio-sentinel"/>
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
        <library name="simple_logger" location="$SIMPLE_EIFFEL/simple_logger/simple_logger.ecf"/>
        <library name="simple_datetime" location="$SIMPLE_EIFFEL/simple_datetime/simple_datetime.ecf"/>

        <!-- ISE dependencies (only when no simple_* alternative) -->
        <library name="base" location="$ISE_LIBRARY/library/base/base.ecf"/>
        <library name="time" location="$ISE_LIBRARY/library/time/time.ecf"/>

        <!-- Application source -->
        <cluster name="src" location="./src/" recursive="true"/>
    </target>

    <target name="audio_sentinel_tests" extends="audio_sentinel">
        <root class="TEST_APP" feature="make"/>
        <setting name="executable_name" value="audio_sentinel_tests"/>
        <library name="simple_testing" location="$SIMPLE_EIFFEL/simple_testing/simple_testing.ecf"/>
        <cluster name="testing" location="./testing/" recursive="true"/>
    </target>

</system>
```

## Cross-Library Data Types

| Source Library | Type | Usage in Audio Sentinel |
|----------------|------|-------------------------|
| simple_audio | AUDIO_BUFFER | Audio data container for analysis |
| simple_audio | AUDIO_DEVICE | Device enumeration (if monitoring live) |
| simple_json | JSON_OBJECT | Config, profiles, results |
| simple_json | JSON_ARRAY | Issue lists, metrics collections |
| simple_csv | CSV_ROW | Batch result rows |
| simple_logger | LOG_MESSAGE | Audit trail entries |
| simple_datetime | DATETIME | Timestamps for reports |
| simple_file | FILE_PATH | Path handling |
