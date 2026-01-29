# Podcast Forge - Technical Design

## Architecture

### Component Overview

```
+------------------------------------------------------------------+
|                        PODCAST FORGE                              |
+------------------------------------------------------------------+
|  CLI Interface Layer                                              |
|    - Argument parsing (simple_cli style)                          |
|    - Command routing (new, build, normalize, assemble, publish)   |
|    - Output formatting (progress, summaries, JSON)                |
+------------------------------------------------------------------+
|  Project Management Layer                                         |
|    - Project templates (show definitions)                         |
|    - Episode manifests (per-episode config)                       |
|    - Asset management (intros, outros, music)                     |
+------------------------------------------------------------------+
|  Processing Engine Layer                                          |
|    - Loudness normalization                                       |
|    - Silence trimming                                             |
|    - Audio assembly (concatenation)                               |
|    - Fade in/out                                                  |
+------------------------------------------------------------------+
|  Metadata Layer                                                   |
|    - ID3 tagging                                                  |
|    - Episode info (title, description, artwork)                   |
|    - RSS feed generation                                          |
+------------------------------------------------------------------+
|  Integration Layer                                                |
|    - simple_audio (WAV I/O, sample manipulation)                  |
|    - simple_json (project files, manifests)                       |
|    - simple_csv (episode lists, analytics)                        |
|    - simple_template (show notes generation)                      |
|    - simple_hash (content fingerprinting)                         |
|    - simple_file (asset management)                               |
+------------------------------------------------------------------+
```

### Class Design

| Class | Responsibility | Key Features |
|-------|----------------|--------------|
| FORGE_CLI | Command-line interface | parse_args, execute, show_progress |
| FORGE_PROJECT | Show/project definition | load, save, validate, templates |
| FORGE_EPISODE | Single episode container | manifest, assets, metadata |
| FORGE_NORMALIZER | Loudness normalization | target_lufs, measure, apply_gain |
| FORGE_ASSEMBLER | Audio concatenation | add_segment, crossfade, build |
| FORGE_TRIMMER | Silence trimming | trim_start, trim_end, threshold |
| FORGE_FADER | Fade in/out effects | fade_in, fade_out, duration |
| FORGE_METADATA | ID3 and metadata | title, artist, album, artwork |
| FORGE_MANIFEST | Episode manifest | segments, order, timing |
| FORGE_PUBLISHER | Output generation | export_wav, export_mp3, generate_rss |

### Command Structure

```bash
podcast-forge <command> [options] [arguments]

Commands:
  new <name>            Create new project/show
  init                  Initialize project in current directory
  episode <name>        Create new episode from template
  build [episode]       Build episode(s) from manifest
  normalize <file>      Normalize audio loudness
  assemble <manifest>   Assemble segments into episode
  trim <file>           Trim silence from audio
  metadata <file>       Edit/view metadata
  publish <episode>     Generate final outputs
  status                Show project status

Global Options:
  --project, -p DIR     Project directory
  --config, -c FILE     Configuration file
  --output, -o DIR      Output directory
  --verbose, -v         Verbose output
  --quiet, -q           Suppress progress output
  --help, -h            Show help

new Options:
  --template NAME       Start from template (interview, solo, panel)
  --intro FILE          Set intro audio file
  --outro FILE          Set outro audio file

build Options:
  --all                 Build all pending episodes
  --dry-run             Show what would be done
  --force               Rebuild even if up-to-date
  --target-lufs FLOAT   Loudness target (default: -16)

normalize Options:
  --target, -t LUFS     Target loudness (default: -16)
  --peak-limit DB       True peak limit (default: -1)
  --in-place            Overwrite input file

assemble Options:
  --crossfade MS        Crossfade duration (default: 0)
  --intro FILE          Prepend intro
  --outro FILE          Append outro

trim Options:
  --threshold DB        Silence threshold (default: -40)
  --min-duration MS     Minimum silence to trim (default: 500)
  --keep-start MS       Keep silence at start (default: 100)
  --keep-end MS         Keep silence at end (default: 500)

publish Options:
  --format FORMAT       Output format: wav, mp3, both (default: both)
  --bitrate KBPS        MP3 bitrate (default: 192)
  --rss                 Generate RSS feed entry

Examples:
  podcast-forge new "My Podcast" --template interview
  podcast-forge episode "Episode 42 - Special Guest"
  podcast-forge build --all --target-lufs -16
  podcast-forge normalize raw_recording.wav -t -16
  podcast-forge assemble episode.json --intro intro.wav --outro outro.wav
  podcast-forge publish episode-42 --format mp3 --rss
```

### Data Flow

```
Project Template --> Episode Manifest --> Build Pipeline --> Final Output
       |                    |                   |                |
   Show config         Segment list        Normalize        WAV/MP3
   Intro/outro         Asset paths          Assemble         RSS entry
   Defaults            Metadata             Trim/fade        Show notes

Build Pipeline Detail:
  1. Load episode manifest (JSON)
  2. Validate all asset files exist
  3. Load main content audio
  4. Measure loudness, calculate gain
  5. Apply loudness normalization
  6. Trim silence from start/end
  7. Apply fade in/out
  8. Prepend intro segment
  9. Append outro segment
  10. Embed metadata (ID3)
  11. Export final file(s)
  12. Generate RSS entry
```

### Project Structure

```
my-podcast/
+-- forge.json              # Project configuration
+-- assets/
|   +-- intro.wav           # Show intro
|   +-- outro.wav           # Show outro
|   +-- music/              # Background music
|   +-- artwork/            # Episode artwork
+-- episodes/
|   +-- ep001/
|   |   +-- manifest.json   # Episode manifest
|   |   +-- raw/            # Raw recordings
|   |   +-- output/         # Final outputs
|   +-- ep002/
|       +-- ...
+-- templates/
|   +-- episode.json        # Episode template
|   +-- metadata.json       # Metadata template
+-- output/                 # Published episodes
+-- feed.xml                # RSS feed
```

### Configuration Schema (forge.json)

```json
{
  "project": {
    "name": "My Podcast",
    "slug": "my-podcast",
    "version": "1.0",
    "description": "A podcast about interesting topics",
    "author": "Host Name",
    "website": "https://mypodcast.com",
    "language": "en",
    "category": "Technology"
  },
  "audio": {
    "sample_rate": 44100,
    "channels": 2,
    "bit_depth": 16,
    "target_lufs": -16,
    "peak_limit_db": -1,
    "silence_threshold_db": -40
  },
  "assets": {
    "intro": "assets/intro.wav",
    "outro": "assets/outro.wav",
    "artwork": "assets/artwork/cover.jpg"
  },
  "output": {
    "directory": "output",
    "formats": ["wav", "mp3"],
    "mp3_bitrate": 192,
    "filename_pattern": "{slug}-{number}-{title}"
  },
  "metadata": {
    "artist": "Host Name",
    "album": "My Podcast",
    "genre": "Podcast",
    "copyright": "2026 Host Name"
  }
}
```

### Episode Manifest Schema (manifest.json)

```json
{
  "episode": {
    "number": 42,
    "title": "Special Guest Interview",
    "description": "In this episode, we talk with...",
    "date": "2026-01-24",
    "duration_estimate": "45:00",
    "slug": "special-guest-interview"
  },
  "segments": [
    {
      "type": "intro",
      "source": "project:intro",
      "fade_in_ms": 0,
      "fade_out_ms": 500
    },
    {
      "type": "content",
      "source": "raw/recording.wav",
      "trim_silence": true,
      "normalize": true,
      "fade_in_ms": 500,
      "fade_out_ms": 500
    },
    {
      "type": "outro",
      "source": "project:outro",
      "fade_in_ms": 500,
      "fade_out_ms": 1000
    }
  ],
  "metadata": {
    "guests": ["Guest Name"],
    "topics": ["topic1", "topic2"],
    "links": [
      {"title": "Guest Website", "url": "https://example.com"}
    ]
  },
  "status": "draft"
}
```

### Error Handling

| Error Type | Handling | User Message |
|------------|----------|--------------|
| Project not found | Exit code 1, suggest init | "Error: No project found. Run 'podcast-forge init'" |
| Asset missing | Exit code 2, list missing | "Error: Asset not found: {path}" |
| Invalid manifest | Exit code 3, show validation errors | "Error: Invalid manifest: {details}" |
| Audio format error | Exit code 4, suggest conversion | "Error: Unsupported format. Convert to WAV first." |
| Build failed | Exit code 5, keep partial work | "Error: Build failed at step: {step}" |
| Metadata error | Warning, continue | "Warning: Could not embed metadata: {reason}" |

### Exit Codes

| Code | Meaning | Use |
|------|---------|-----|
| 0 | Success | All operations completed |
| 1 | Project error | No project, invalid config |
| 2 | Asset error | Missing files |
| 3 | Manifest error | Invalid episode manifest |
| 4 | Audio error | Format or processing issue |
| 5 | Build error | Build pipeline failure |

## GUI/TUI Future Path

**CLI foundation enables:**
- All processing logic in reusable library classes
- Project files are human-readable JSON
- Manifest-based workflow supports visual editors
- Progress callbacks enable real-time UI updates

**TUI potential (simple_tui):**
- Episode list with status indicators
- Build progress with waveform preview
- Metadata editor with field navigation
- Project browser

**GUI potential (future):**
- Drag-and-drop segment arrangement
- Waveform editor with visual trim points
- Loudness meter visualization
- Publish wizard with preview
- RSS feed management
