# Voice Vault - Build Plan

## Phase Overview

| Phase | Deliverable | Effort | Dependencies |
|-------|-------------|--------|--------------|
| Phase 1 | MVP CLI - Record with integrity | 4 days | simple_audio, simple_hash, simple_json |
| Phase 2 | Full CLI - Storage, index, audit | 5 days | Phase 1, simple_sql, simple_encryption |
| Phase 3 | Polish - Export, verification, documentation | 3 days | Phase 2, simple_logger |

---

## Phase 1: MVP

### Objective

Demonstrate core value: record audio with automatic integrity hashing and metadata capture.

### Deliverables

1. **VAULT_CLI** - Basic command-line interface with record command
2. **VAULT_RECORDER** - Recording session management
3. **VAULT_RECORDING** - Recording container with metadata
4. **VAULT_INTEGRITY** - SHA-256 hash calculation
5. **VAULT_CONFIG** - Basic configuration

### Tasks

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| T1.1 | Create project structure and ECF | Compiles with all dependencies |
| T1.2 | Implement VAULT_CONFIG | Load/save JSON config |
| T1.3 | Implement VAULT_RECORDER | Start/stop recording sessions |
| T1.4 | Implement VAULT_INTEGRITY | SHA-256 hash of audio data |
| T1.5 | Implement VAULT_RECORDING | Recording container with metadata |
| T1.6 | Implement VAULT_CLI (record) | CLI command to start recording |
| T1.7 | Implement VAULT_CLI (list) | Basic listing of recordings |
| T1.8 | Write MVP tests | Test each component |

### Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| test_record_session | 10s recording | WAV file with correct duration |
| test_hash_audio | Sample buffer | SHA-256 hash (64 hex chars) |
| test_hash_consistent | Same buffer twice | Identical hashes |
| test_hash_different | Different buffers | Different hashes |
| test_metadata_create | Recording session | Metadata JSON with all fields |
| test_cli_record | "record --duration 10" | Recording created, hash shown |
| test_cli_list | "list" | Shows recording with ID |

### Exit Criteria

- `voice-vault record` captures audio with integrity hash
- Hash is reproducible (same audio = same hash)
- Metadata captures timestamp, duration, device
- Basic list shows recordings

---

## Phase 2: Full Implementation

### Objective

Production-ready vault with encryption, indexing, search, and audit logging.

### Deliverables

1. **VAULT_STORAGE** - Encrypted file storage
2. **VAULT_INDEX** - SQLite recording database
3. **VAULT_AUDIT** - Audit logging
4. **VAULT_CUSTODY** - Chain of custody
5. **Full CLI commands** - info, verify, search, audit

### Tasks

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| T2.1 | Implement VAULT_STORAGE | Encrypt/decrypt recordings |
| T2.2 | Implement VAULT_INDEX | SQLite database for recordings |
| T2.3 | Implement VAULT_AUDIT | Log all operations |
| T2.4 | Implement VAULT_CUSTODY | Track chain of custody |
| T2.5 | Add 'info' command | Show recording details |
| T2.6 | Add 'verify' command | Verify recording integrity |
| T2.7 | Add 'search' command | Search recordings |
| T2.8 | Add 'audit' command | Show audit trail |
| T2.9 | Implement playback | Play recordings securely |
| T2.10 | Add device selection | List and select input devices |
| T2.11 | Write integration tests | End-to-end workflows |

### Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| test_encrypt_audio | WAV file | Encrypted .vault file |
| test_decrypt_audio | .vault file | Original WAV recovered |
| test_index_add | Recording | Entry in SQLite |
| test_index_search | Case ID | Matching recordings |
| test_audit_create | Recording creation | Audit entry logged |
| test_audit_access | Recording access | Audit entry logged |
| test_verify_valid | Valid recording | Verification PASSED |
| test_verify_tampered | Tampered file | Verification FAILED |
| test_custody_chain | Recording with activity | Complete chain of custody |

### Exit Criteria

- Recordings are encrypted at rest
- All operations are audited
- Search works by case, date, type
- Verification detects tampering
- Chain of custody is complete

---

## Phase 3: Production Polish

### Objective

Export features, reports, and documentation for production use.

### Deliverables

1. **VAULT_EXPORTER** - Evidence package generation
2. **Verification reports** - PDF/text reports
3. **Scheduled recordings** - Automated capture
4. **Documentation** - README, legal guidelines

### Tasks

| Task | Description | Acceptance Criteria |
|------|-------------|---------------------|
| T3.1 | Implement VAULT_EXPORTER | Create evidence packages |
| T3.2 | Generate verification reports | PDF/text certificates |
| T3.3 | Generate chain of custody docs | Formatted custody report |
| T3.4 | Add 'export' command | Export evidence package |
| T3.5 | Add scheduled recording | --scheduled flag |
| T3.6 | Add legal hold feature | Prevent deletion |
| T3.7 | Write README.md | Installation, usage, compliance |
| T3.8 | Create compliance guide | Legal documentation |
| T3.9 | Error handling review | All edge cases covered |
| T3.10 | Final test suite | Full coverage |

### Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| test_export_evidence | Recording ID | Package with all files |
| test_export_encrypted | Recording + password | Encrypted package |
| test_verification_report | Verified recording | PDF/text report |
| test_custody_report | Recording with chain | Formatted custody doc |
| test_scheduled_record | Future time | Recording starts on schedule |
| test_legal_hold | Hold recording | Deletion blocked |
| test_export_audit | Export action | Logged in audit trail |

### Exit Criteria

- Evidence packages are complete and professional
- Reports meet legal documentation standards
- Scheduled recording works reliably
- Documentation covers compliance requirements

---

## ECF Target Structure

```xml
<!-- Library target (reusable vault engine) -->
<target name="vault_lib">
    <root all_classes="true" />
    <library name="simple_audio" location="..."/>
    <library name="simple_hash" location="..."/>
    <library name="simple_encryption" location="..."/>
    <!-- ... other dependencies ... -->
    <cluster name="lib" location="./src/lib/" recursive="true"/>
</target>

<!-- CLI executable target -->
<target name="voice_vault" extends="vault_lib">
    <root class="VAULT_CLI" feature="make"/>
    <setting name="executable_name" value="voice-vault"/>
    <cluster name="cli" location="./src/cli/" recursive="true"/>
</target>

<!-- Test target -->
<target name="voice_vault_tests" extends="vault_lib">
    <root class="TEST_APP" feature="make"/>
    <setting name="executable_name" value="voice_vault_tests"/>
    <library name="simple_testing" location="$SIMPLE_EIFFEL/simple_testing/simple_testing.ecf"/>
    <cluster name="testing" location="./testing/" recursive="true"/>
</target>
```

---

## Build Commands

```bash
# Compile CLI (workbench for development)
/d/prod/ec.sh -batch -config voice_vault.ecf -target voice_vault -c_compile

# Compile CLI (finalized for release)
/d/prod/ec.sh -batch -config voice_vault.ecf -target voice_vault -finalize -c_compile

# Run tests
/d/prod/ec.sh -batch -config voice_vault.ecf -target voice_vault_tests -c_compile
./EIFGENs/voice_vault_tests/W_code/voice_vault_tests.exe

# Run CLI
./EIFGENs/voice_vault/W_code/voice-vault.exe record --case "2026-001"
```

---

## Success Criteria

| Criterion | Measure | Target |
|-----------|---------|--------|
| Compiles | Zero errors, zero warnings | 100% |
| Tests pass | All test cases | 100% |
| Contracts satisfied | No precondition/postcondition violations | 100% |
| CLI works | All commands documented and functional | 100% |
| Recording reliability | Successful recordings vs attempts | 99.9% |
| Hash verification | Correct tamper detection | 100% |
| Audit completeness | All operations logged | 100% |
| Documentation | README, compliance guide | Complete |

---

## File Structure

```
voice_vault/
+-- voice_vault.ecf
+-- README.md
+-- LICENSE
+-- COMPLIANCE.md
+-- src/
|   +-- cli/
|   |   +-- vault_cli.e
|   +-- lib/
|       +-- vault_recorder.e
|       +-- vault_recording.e
|       +-- vault_storage.e
|       +-- vault_index.e
|       +-- vault_integrity.e
|       +-- vault_audit.e
|       +-- vault_custody.e
|       +-- vault_exporter.e
|       +-- vault_config.e
+-- testing/
|   +-- test_app.e
|   +-- lib_tests.e
|   +-- test_recorder.e
|   +-- test_integrity.e
|   +-- test_storage.e
|   +-- test_audit.e
+-- docs/
|   +-- index.html
|   +-- compliance/
|       +-- chain_of_custody.md
|       +-- legal_guidelines.md
+-- templates/
    +-- verification_report.template
    +-- custody_report.template
```

---

## Security Considerations

### Encryption Key Management

- Vault key derived from user passphrase using PBKDF2 (100K iterations)
- Key never stored in plaintext
- Memory wiped after use
- Consider hardware security module (HSM) integration for enterprise

### Audit Log Protection

- Audit logs append-only
- Hash chain linking entries
- Separate storage from recordings
- Regular backup to immutable storage

### Tamper Detection

- SHA-256 hash calculated before encryption
- Hash stored separately from recording
- Verification compares recalculated hash
- Any mismatch = tampering detected

### Access Control

- Vault requires passphrase to unlock
- Individual recording access logged
- Export requires additional authentication
- Legal hold prevents deletion
