# Audio Sentinel - Technical Design

## Architecture

### Component Overview

```
+------------------------------------------------------------------+
|                        AUDIO SENTINEL                             |
+------------------------------------------------------------------+
|  CLI Interface Layer                                              |
|    - Argument parsing (simple_cli style)                          |
|    - Command routing (analyze, batch, monitor, report)            |
|    - Output formatting (text, json, csv)                          |
+------------------------------------------------------------------+
|  Analysis Engine Layer                                            |
|    - Loudness measurement (integrated, short-term, momentary)     |
|    - True peak detection                                          |
|    - Silence detection                                            |
|    - Clipping detection                                           |
|    - Format validation                                            |
+------------------------------------------------------------------+
|  Profile Management Layer                                         |
|    - Built-in profiles (EBU R128, ATSC A/85, custom)              |
|    - Profile loading/saving                                       |
|    - Threshold configuration                                      |
+------------------------------------------------------------------+
|  Reporting Layer                                                  |
|    - Result aggregation                                           |
|    - Multi-format export (JSON, CSV, text, HTML)                  |
|    - Severity classification (pass, warning, fail)                |
+------------------------------------------------------------------+
|  Integration Layer                                                |
|    - simple_audio (WAV loading, sample access)                    |
|    - simple_json (config, reports)                                |
|    - simple_csv (batch results)                                   |
|    - simple_logger (audit trail)                                  |
|    - simple_file (file operations)                                |
+------------------------------------------------------------------+
```

### Class Design

| Class | Responsibility | Key Features |
|-------|----------------|--------------|
| SENTINEL_CLI | Command-line interface | parse_args, execute, format_output |
| SENTINEL_ANALYZER | Core analysis engine | analyze_file, measure_loudness, detect_clipping |
| SENTINEL_PROFILE | Quality standard definition | load, save, validate, thresholds |
| SENTINEL_RESULT | Analysis results container | issues, metrics, severity, pass/fail |
| SENTINEL_REPORTER | Output generation | to_json, to_csv, to_text, to_html |
| SENTINEL_BATCH | Batch processing | process_directory, aggregate_results |
| SENTINEL_MONITOR | Continuous monitoring | watch_directory, on_new_file |
| LOUDNESS_CALCULATOR | ITU-R BS.1770 loudness | integrated_lufs, short_term, momentary |
| PEAK_DETECTOR | True peak measurement | sample_peak, true_peak_dbfs |
| SILENCE_DETECTOR | Silence gap detection | find_silences, total_silence |
| CLIPPING_DETECTOR | Clipping/overload detection | detect_clips, severity |

### Command Structure

```bash
audio-sentinel <command> [options] [arguments]

Commands:
  analyze <file>        Analyze single audio file
  batch <directory>     Batch analyze directory
  monitor <directory>   Continuous monitoring mode
  report <results>      Generate formatted report
  profiles              List available profiles
  version               Show version information

Global Options:
  --profile, -p NAME    Quality profile (default: ebu-r128)
  --output, -o FORMAT   Output format: text|json|csv|html (default: text)
  --config, -c FILE     Configuration file path
  --verbose, -v         Verbose output
  --quiet, -q           Suppress non-error output
  --help, -h            Show help

analyze Options:
  --loudness            Measure loudness (LUFS)
  --peaks               Detect true peaks
  --silence             Detect silence gaps
  --clipping            Detect clipping
  --all                 Run all checks (default)
  --report FILE         Save detailed report

batch Options:
  --recursive, -r       Process subdirectories
  --pattern GLOB        File pattern (default: *.wav)
  --summary FILE        Save summary report
  --fail-fast           Stop on first failure
  --parallel N          Parallel processing (default: 4)

monitor Options:
  --interval SECONDS    Check interval (default: 60)
  --webhook URL         Send alerts to webhook
  --email ADDRESS       Send alerts to email
  --archive DIR         Move processed files

Examples:
  audio-sentinel analyze episode.wav --profile podcast
  audio-sentinel batch ./episodes -r --output json > results.json
  audio-sentinel monitor ./incoming --webhook https://hooks.slack.com/...
```

### Data Flow

```
Input File(s) --> Validation --> Analysis --> Aggregation --> Report
       |               |             |              |            |
   WAV/PCM        Format       Loudness,      Combine       JSON/CSV/
   loading        checks       peaks,         results,      text/HTML
                               silence,       classify
                               clipping       severity

Analysis Pipeline:
  1. Load audio file (AUDIO_BUFFER)
  2. Validate format (sample rate, channels, bits)
  3. Run analyzers in parallel:
     - Loudness (gated, ungated)
     - True peak detection
     - Silence detection
     - Clipping detection
  4. Compare against profile thresholds
  5. Classify severity (pass/warning/fail)
  6. Generate result object
  7. Format output
```

### Configuration Schema

```json
{
  "audio_sentinel": {
    "version": "1.0",
    "default_profile": "ebu-r128",
    "output_format": "text",
    "parallel_workers": 4,
    "profiles_directory": "./profiles",
    "reports_directory": "./reports",
    "logging": {
      "level": "info",
      "file": "sentinel.log"
    },
    "alerts": {
      "webhook_url": null,
      "email": null,
      "on_failure": true,
      "on_warning": false
    }
  }
}
```

### Profile Schema

```json
{
  "profile": {
    "name": "ebu-r128",
    "description": "EBU R128 Broadcast Loudness Standard",
    "version": "1.0",
    "loudness": {
      "target_lufs": -23.0,
      "tolerance_lufs": 1.0,
      "loudness_range_max_lu": 20.0,
      "true_peak_max_dbtp": -1.0
    },
    "silence": {
      "threshold_dbfs": -60.0,
      "max_duration_seconds": 3.0,
      "min_gap_seconds": 0.5
    },
    "clipping": {
      "consecutive_samples": 3,
      "max_occurrences": 0
    },
    "format": {
      "sample_rates": [44100, 48000],
      "channels": [1, 2],
      "bit_depths": [16, 24]
    }
  }
}
```

### Result Schema

```json
{
  "result": {
    "file": "episode.wav",
    "timestamp": "2026-01-24T10:30:00Z",
    "profile": "ebu-r128",
    "duration_seconds": 3600.5,
    "overall_status": "fail",
    "metrics": {
      "integrated_loudness_lufs": -21.5,
      "loudness_range_lu": 12.3,
      "true_peak_dbtp": 0.2,
      "max_silence_seconds": 5.2,
      "clipping_count": 3
    },
    "issues": [
      {
        "type": "loudness",
        "severity": "warning",
        "message": "Integrated loudness -21.5 LUFS exceeds target -23.0 +/- 1.0 LUFS",
        "position_seconds": null
      },
      {
        "type": "true_peak",
        "severity": "fail",
        "message": "True peak +0.2 dBTP exceeds limit -1.0 dBTP",
        "position_seconds": 1234.5
      },
      {
        "type": "silence",
        "severity": "fail",
        "message": "Silence gap 5.2 seconds exceeds limit 3.0 seconds",
        "position_seconds": 890.0
      }
    ]
  }
}
```

### Error Handling

| Error Type | Handling | User Message |
|------------|----------|--------------|
| File not found | Exit code 1, log error | "Error: File not found: {path}" |
| Invalid format | Exit code 2, skip file in batch | "Error: Unsupported format: {details}" |
| Profile not found | Exit code 3, list available | "Error: Profile '{name}' not found. Available: ..." |
| Analysis error | Exit code 4, include partial results | "Warning: Analysis incomplete: {reason}" |
| Permission denied | Exit code 5, log and skip | "Error: Permission denied: {path}" |
| Out of memory | Exit code 6, suggest smaller batches | "Error: Insufficient memory. Try --parallel 1" |

### Exit Codes

| Code | Meaning | CI/CD Use |
|------|---------|-----------|
| 0 | All files passed | Build passes |
| 1 | Some files have warnings | Build passes with warnings |
| 2 | Some files failed | Build fails |
| 10+ | System/usage errors | Build fails |

## GUI/TUI Future Path

**CLI foundation enables:**
- All analysis logic is in reusable library classes
- Report generation produces data suitable for visualization
- Profiles and configs are JSON-based, easily editable by GUI
- Batch processing creates data sets for dashboard display

**TUI potential (simple_tui):**
- Real-time loudness meter display
- File list with pass/fail status
- Profile editor
- Monitoring dashboard with alerts

**GUI potential (future):**
- Waveform visualization with issue markers
- Drag-and-drop file processing
- Real-time level meters
- Trend analysis charts
- Alert configuration wizard
