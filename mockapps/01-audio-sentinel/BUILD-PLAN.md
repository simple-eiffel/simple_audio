# Audio Sentinel - Build Plan

## Phase Overview

| Phase | Deliverable | Effort | Dependencies |
|-------|-------------|--------|--------------|
| Phase 1 | MVP CLI - Single file analysis | 3 days | simple_audio, simple_json |
| Phase 2 | Full CLI - Batch, profiles, reporting | 5 days | Phase 1, simple_csv, simple_logger |
| Phase 3 | Polish - Monitoring, alerts, documentation | 3 days | Phase 2 |

---

## Phase 1: MVP

### Objective

Demonstrate core value: analyze a single WAV file and report loudness, peaks, and basic quality metrics.

### Deliverables

1. **SENTINEL_CLI** - Basic command-line interface with `analyze` command
2. **SENTINEL_ANALYZER** - Core analysis engine with loudness and peak detection
3. **SENTINEL_RESULT** - Result container with pass/fail status
4. **LOUDNESS_CALCULATOR** - ITU-R BS.1770 loudness measurement
5. **PEAK_DETECTOR** - Sample and true peak detection

### Tasks

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| T1.1 | Create project structure and ECF | Compiles with all dependencies |
| T1.2 | Implement LOUDNESS_CALCULATOR | RMS and gated loudness measurement |
| T1.3 | Implement PEAK_DETECTOR | Sample peak and true peak detection |
| T1.4 | Implement SENTINEL_ANALYZER | Orchestrates analysis, uses calculators |
| T1.5 | Implement SENTINEL_RESULT | Stores metrics and issues |
| T1.6 | Implement SENTINEL_CLI | Parse args, run analysis, print results |
| T1.7 | Create basic EBU R128 profile | Hardcoded thresholds for MVP |
| T1.8 | Write MVP tests | Test each component in isolation |

### Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| test_loudness_sine | 440Hz sine at -20dBFS | Loudness ~ -20 LUFS |
| test_loudness_silence | Silent buffer | Loudness < -70 LUFS |
| test_peak_clipping | Buffer with clipped samples | Peak = 0 dBFS, clipping detected |
| test_peak_normal | Normal audio | Peak < 0 dBFS, no clipping |
| test_analyze_file | Valid WAV file | Result with all metrics populated |
| test_analyze_missing | Non-existent file | Error with appropriate message |
| test_cli_analyze | "analyze test.wav" | Formatted output with metrics |

### Exit Criteria

- `audio-sentinel analyze test.wav` produces loudness and peak measurements
- Results match FFmpeg reference within 0.1 LUFS / 0.1 dB
- Exit code reflects pass/fail status

---

## Phase 2: Full Implementation

### Objective

Production-ready CLI with batch processing, configurable profiles, and multi-format reporting.

### Deliverables

1. **SENTINEL_PROFILE** - Profile loading and management
2. **SENTINEL_BATCH** - Directory/batch processing
3. **SENTINEL_REPORTER** - JSON, CSV, text, HTML output
4. **SILENCE_DETECTOR** - Silence gap detection
5. **CLIPPING_DETECTOR** - Clipping/overload detection
6. **Built-in profiles** - EBU R128, ATSC A/85, Podcast, Custom

### Tasks

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| T2.1 | Implement SENTINEL_PROFILE | Load/save JSON profiles |
| T2.2 | Create built-in profiles | EBU R128, ATSC A/85, Podcast |
| T2.3 | Implement SILENCE_DETECTOR | Detect gaps, report positions |
| T2.4 | Implement CLIPPING_DETECTOR | Detect clipping, count occurrences |
| T2.5 | Implement SENTINEL_BATCH | Process directories, aggregate results |
| T2.6 | Implement SENTINEL_REPORTER | JSON, CSV, text, HTML output |
| T2.7 | Add --profile flag | Switch between profiles |
| T2.8 | Add --output flag | Select output format |
| T2.9 | Add batch command | Process directory with pattern matching |
| T2.10 | Add logging integration | Audit trail for all operations |
| T2.11 | Write integration tests | End-to-end workflow tests |

### Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| test_profile_load | JSON profile file | Profile object with correct thresholds |
| test_profile_builtin | "ebu-r128" | EBU R128 thresholds |
| test_silence_detect | Audio with 5s gap | Silence detected at correct position |
| test_clipping_detect | Audio with clips | Clipping count matches actual |
| test_batch_directory | Directory with 10 WAVs | 10 results, correct aggregation |
| test_batch_pattern | "*.wav" pattern | Only WAV files processed |
| test_reporter_json | Result object | Valid JSON with all fields |
| test_reporter_csv | Batch results | Valid CSV with header row |
| test_cli_batch | "batch ./dir -r" | Recursive processing, summary |

### Exit Criteria

- All commands work: analyze, batch, profiles
- All output formats work: text, json, csv
- All profiles load correctly
- Batch processing handles 100+ files
- Logging captures all operations

---

## Phase 3: Production Polish

### Objective

Production-hardened tool with monitoring, alerts, documentation, and error handling.

### Deliverables

1. **SENTINEL_MONITOR** - Directory watching for continuous operation
2. **Alert integrations** - Webhook and email notifications
3. **Error handling hardening** - Graceful failure for all edge cases
4. **Performance optimization** - Parallel processing, memory efficiency
5. **Documentation** - README, man page, examples

### Tasks

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| T3.1 | Implement SENTINEL_MONITOR | Watch directory, process new files |
| T3.2 | Add webhook alerts | POST to URL on failure |
| T3.3 | Add email alerts (optional) | Send email on failure |
| T3.4 | Implement parallel processing | --parallel N flag |
| T3.5 | Memory optimization | Process large files in chunks |
| T3.6 | Error handling review | No unhandled exceptions |
| T3.7 | Write README.md | Installation, usage, examples |
| T3.8 | Create example profiles | Industry-specific templates |
| T3.9 | Performance benchmarking | Document processing speed |
| T3.10 | Final test suite | Full coverage, edge cases |

### Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| test_monitor_new_file | Drop file in watched dir | File analyzed automatically |
| test_webhook_fail | Failing file + webhook URL | HTTP POST sent |
| test_parallel_batch | 100 files, --parallel 4 | 4x faster than sequential |
| test_large_file | 2-hour WAV file | Completes without OOM |
| test_invalid_wav | Corrupted WAV | Graceful error, continues batch |
| test_permission_denied | Read-only file | Error logged, continues |

### Exit Criteria

- Monitor mode runs 24/7 without issues
- Large files (2+ hours) process without memory issues
- All error conditions handled gracefully
- Documentation complete for all features

---

## ECF Target Structure

```xml
<!-- Library target (reusable analysis engine) -->
<target name="sentinel_lib">
    <root all_classes="true" />
    <library name="simple_audio" location="..."/>
    <library name="simple_json" location="..."/>
    <!-- ... other dependencies ... -->
    <cluster name="lib" location="./src/lib/" recursive="true"/>
</target>

<!-- CLI executable target -->
<target name="audio_sentinel" extends="sentinel_lib">
    <root class="SENTINEL_CLI" feature="make"/>
    <setting name="executable_name" value="audio-sentinel"/>
    <cluster name="cli" location="./src/cli/" recursive="true"/>
</target>

<!-- Test target -->
<target name="audio_sentinel_tests" extends="sentinel_lib">
    <root class="TEST_APP" feature="make"/>
    <setting name="executable_name" value="audio_sentinel_tests"/>
    <library name="simple_testing" location="$SIMPLE_EIFFEL/simple_testing/simple_testing.ecf"/>
    <cluster name="testing" location="./testing/" recursive="true"/>
</target>
```

---

## Build Commands

```bash
# Compile CLI (workbench for development)
/d/prod/ec.sh -batch -config audio_sentinel.ecf -target audio_sentinel -c_compile

# Compile CLI (finalized for release)
/d/prod/ec.sh -batch -config audio_sentinel.ecf -target audio_sentinel -finalize -c_compile

# Run tests
/d/prod/ec.sh -batch -config audio_sentinel.ecf -target audio_sentinel_tests -c_compile
./EIFGENs/audio_sentinel_tests/W_code/audio_sentinel_tests.exe

# Run CLI
./EIFGENs/audio_sentinel/W_code/audio-sentinel.exe analyze test.wav
```

---

## Success Criteria

| Criterion | Measure | Target |
|-----------|---------|--------|
| Compiles | Zero errors, zero warnings | 100% |
| Tests pass | All test cases | 100% |
| Contracts satisfied | No precondition/postcondition violations | 100% |
| CLI works | All commands documented and functional | 100% |
| Performance | Process 1-hour file in <6 minutes | 10x real-time |
| Documentation | README, examples, profiles | Complete |
| Error handling | No unhandled exceptions | 100% |

---

## File Structure

```
audio_sentinel/
+-- audio_sentinel.ecf
+-- README.md
+-- LICENSE
+-- src/
|   +-- cli/
|   |   +-- sentinel_cli.e
|   +-- lib/
|       +-- sentinel_analyzer.e
|       +-- sentinel_result.e
|       +-- sentinel_profile.e
|       +-- sentinel_batch.e
|       +-- sentinel_reporter.e
|       +-- sentinel_monitor.e
|       +-- loudness_calculator.e
|       +-- peak_detector.e
|       +-- silence_detector.e
|       +-- clipping_detector.e
+-- testing/
|   +-- test_app.e
|   +-- lib_tests.e
|   +-- test_loudness.e
|   +-- test_peaks.e
|   +-- test_analyzer.e
|   +-- test_batch.e
+-- profiles/
|   +-- ebu-r128.json
|   +-- atsc-a85.json
|   +-- podcast.json
+-- examples/
|   +-- ci-pipeline.yml
|   +-- monitor-script.sh
+-- docs/
    +-- index.html
```
