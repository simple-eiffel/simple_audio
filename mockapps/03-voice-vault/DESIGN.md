# Voice Vault - Technical Design

## Architecture

### Component Overview

```
+------------------------------------------------------------------+
|                         VOICE VAULT                               |
+------------------------------------------------------------------+
|  CLI Interface Layer                                              |
|    - Argument parsing (simple_cli style)                          |
|    - Command routing (record, list, verify, export, audit)        |
|    - Output formatting (text, json, csv)                          |
+------------------------------------------------------------------+
|  Recording Engine Layer                                           |
|    - Device selection and configuration                           |
|    - Recording session management                                 |
|    - Real-time integrity hashing                                  |
|    - Automatic segmentation                                       |
+------------------------------------------------------------------+
|  Integrity Layer                                                  |
|    - SHA-256 hash calculation                                     |
|    - Timestamp embedding                                          |
|    - Digital signature (optional)                                 |
|    - Chain verification                                           |
+------------------------------------------------------------------+
|  Storage Layer                                                    |
|    - Secure file storage                                          |
|    - Encrypted at-rest (AES-256)                                  |
|    - Index database (SQLite)                                      |
|    - Backup management                                            |
+------------------------------------------------------------------+
|  Audit Layer                                                      |
|    - Access logging                                               |
|    - Chain of custody records                                     |
|    - Export tracking                                              |
|    - Tamper detection                                             |
+------------------------------------------------------------------+
|  Integration Layer                                                |
|    - simple_audio (recording, playback)                           |
|    - simple_hash (SHA-256 integrity)                              |
|    - simple_encryption (AES-256)                                  |
|    - simple_sql (SQLite index)                                    |
|    - simple_json (metadata, config)                               |
|    - simple_datetime (timestamps)                                 |
|    - simple_logger (audit trail)                                  |
+------------------------------------------------------------------+
```

### Class Design

| Class | Responsibility | Key Features |
|-------|----------------|--------------|
| VAULT_CLI | Command-line interface | parse_args, execute, format_output |
| VAULT_RECORDER | Recording session management | start, stop, pause, resume |
| VAULT_RECORDING | Single recording container | metadata, hash, timestamps |
| VAULT_STORAGE | Secure file storage | save, load, encrypt, decrypt |
| VAULT_INDEX | Recording database | search, list, filter |
| VAULT_INTEGRITY | Hash and verification | calculate_hash, verify, sign |
| VAULT_AUDIT | Audit logging | log_access, log_export, get_chain |
| VAULT_EXPORTER | Evidence package generation | export_package, generate_manifest |
| VAULT_CUSTODY | Chain of custody records | add_custodian, transfer, document |
| VAULT_CONFIG | Configuration management | load, save, validate |

### Command Structure

```bash
voice-vault <command> [options] [arguments]

Commands:
  record                Start new recording session
  list                  List recordings
  info <id>             Show recording details
  verify <id>           Verify recording integrity
  play <id>             Play recording
  export <id>           Export evidence package
  audit <id>            Show audit trail
  search <query>        Search recordings
  config                Manage configuration
  devices               List audio devices

Global Options:
  --vault, -V DIR       Vault storage directory
  --config, -c FILE     Configuration file
  --output, -o FORMAT   Output format: text|json|csv (default: text)
  --verbose, -v         Verbose output
  --quiet, -q           Suppress non-error output
  --help, -h            Show help

record Options:
  --device, -d ID       Input device (default: system default)
  --case, -C ID         Case/matter identifier
  --subject NAMES       Recording subject(s)
  --type TYPE           Recording type: interview, call, meeting, other
  --duration MINUTES    Maximum duration (auto-stop)
  --notes TEXT          Session notes
  --scheduled TIME      Scheduled start time

list Options:
  --case ID             Filter by case
  --date RANGE          Filter by date (today, week, month, YYYY-MM-DD)
  --type TYPE           Filter by type
  --verified            Only verified recordings
  --limit N             Limit results (default: 50)

verify Options:
  --deep                Full byte-by-byte verification
  --report FILE         Save verification report

export Options:
  --format FORMAT       Package format: evidence, archive, playback
  --include-chain       Include chain of custody
  --include-audit       Include audit log
  --password PASS       Encrypt export package
  --output DIR          Output directory

audit Options:
  --from DATE           Start date
  --to DATE             End date
  --action TYPE         Filter by action type
  --user NAME           Filter by user

search Options:
  --case ID             Search within case
  --text QUERY          Full-text search in notes
  --subject NAME        Search by subject name

Examples:
  voice-vault record --case "2026-001" --subject "John Doe" --type interview
  voice-vault list --case "2026-001" --date month
  voice-vault verify abc123 --deep --report verify-report.pdf
  voice-vault export abc123 --format evidence --include-chain --include-audit
  voice-vault audit abc123 --from 2026-01-01
```

### Data Flow

```
Recording Session --> Integrity Calculation --> Secure Storage --> Index
       |                      |                      |             |
   Audio capture         SHA-256 hash           Encryption      SQLite
   Timestamps           Signature (opt)         WAV + meta      Search

Verification Flow:
  1. Load recording metadata from index
  2. Load encrypted audio from storage
  3. Recalculate SHA-256 hash
  4. Compare with stored hash
  5. Check timestamp chain
  6. Verify digital signature (if present)
  7. Generate verification report

Export Flow:
  1. Verify recording integrity
  2. Decrypt audio file
  3. Generate chain of custody document
  4. Generate audit log extract
  5. Generate verification certificate
  6. Package all files (optionally re-encrypt)
  7. Log export in audit trail
```

### Storage Structure

```
vault/
+-- config.json              # Vault configuration
+-- vault.db                 # SQLite index database
+-- recordings/
|   +-- 2026/
|   |   +-- 01/
|   |   |   +-- rec_abc123.vault     # Encrypted recording
|   |   |   +-- rec_abc123.meta      # Metadata JSON
|   |   |   +-- rec_def456.vault
|   |   |   +-- rec_def456.meta
|   |   +-- 02/
|   |       +-- ...
+-- audit/
|   +-- audit_2026-01.log    # Monthly audit logs
|   +-- audit_2026-02.log
+-- exports/
|   +-- export_20260124_abc123/
|       +-- recording.wav
|       +-- manifest.json
|       +-- chain_of_custody.pdf
|       +-- audit_log.txt
|       +-- verification.pdf
+-- keys/
    +-- vault.key            # Encryption key (protected)
```

### Configuration Schema

```json
{
  "vault": {
    "version": "1.0",
    "name": "Corporate Compliance Vault",
    "organization": "Example Corp",
    "storage_path": "./vault",
    "encryption": {
      "algorithm": "AES-256-GCM",
      "key_derivation": "PBKDF2",
      "iterations": 100000
    },
    "recording": {
      "sample_rate": 44100,
      "channels": 1,
      "bit_depth": 16,
      "max_duration_minutes": 480,
      "auto_segment_minutes": 60
    },
    "integrity": {
      "hash_algorithm": "SHA-256",
      "sign_recordings": false,
      "timestamp_server": null
    },
    "retention": {
      "default_days": 2555,
      "legal_hold_enabled": true
    },
    "audit": {
      "log_all_access": true,
      "log_playback": true,
      "log_exports": true
    }
  }
}
```

### Recording Metadata Schema

```json
{
  "recording": {
    "id": "abc123def456",
    "version": "1.0",
    "created": "2026-01-24T10:30:00Z",
    "completed": "2026-01-24T11:15:00Z",
    "duration_seconds": 2700,
    "case_id": "2026-001",
    "type": "interview",
    "subjects": ["John Doe"],
    "recorder": "Jane Smith",
    "device": "Microphone (Realtek Audio)",
    "notes": "Initial interview regarding...",
    "format": {
      "sample_rate": 44100,
      "channels": 1,
      "bit_depth": 16,
      "file_size_bytes": 237600000
    },
    "integrity": {
      "hash_algorithm": "SHA-256",
      "hash": "a1b2c3d4e5f6...",
      "calculated_at": "2026-01-24T11:15:01Z",
      "signature": null
    },
    "chain": [
      {
        "action": "created",
        "timestamp": "2026-01-24T10:30:00Z",
        "user": "Jane Smith",
        "notes": "Recording started"
      },
      {
        "action": "completed",
        "timestamp": "2026-01-24T11:15:00Z",
        "user": "Jane Smith",
        "notes": "Recording completed normally"
      }
    ]
  }
}
```

### Error Handling

| Error Type | Handling | User Message |
|------------|----------|--------------|
| Device not found | Exit code 1, list available | "Error: Device not found. Available: ..." |
| Recording failed | Exit code 2, save partial | "Error: Recording interrupted. Partial saved." |
| Vault locked | Exit code 3, prompt unlock | "Error: Vault locked. Unlock required." |
| Verification failed | Exit code 4, show details | "VERIFICATION FAILED: Hash mismatch at..." |
| Permission denied | Exit code 5, log attempt | "Error: Access denied. Logged to audit." |
| Storage full | Exit code 6, show usage | "Error: Storage limit reached. Free: X GB" |

### Exit Codes

| Code | Meaning | Use |
|------|---------|-----|
| 0 | Success | Operation completed |
| 1 | Device error | Recording device issues |
| 2 | Recording error | Recording session failure |
| 3 | Authentication error | Vault locked or wrong credentials |
| 4 | Integrity error | Verification failed |
| 5 | Permission error | Access denied |
| 6 | Storage error | Storage full or unavailable |

## GUI/TUI Future Path

**CLI foundation enables:**
- All recording logic in reusable library classes
- Metadata and audit logs are queryable JSON/SQLite
- Verification generates reports suitable for display
- Export packages are self-contained

**TUI potential (simple_tui):**
- Recording session dashboard with levels
- Recording list with search/filter
- Verification status display
- Chain of custody viewer

**GUI potential (future):**
- Recording interface with waveform
- Case management dashboard
- Visual chain of custody timeline
- Export wizard
- Calendar view of recordings
