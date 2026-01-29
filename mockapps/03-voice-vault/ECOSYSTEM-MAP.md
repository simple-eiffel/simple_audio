# Voice Vault - Ecosystem Integration

## simple_* Dependencies

### Required Libraries

| Library | Purpose | Integration Point |
|---------|---------|-------------------|
| simple_audio | Audio recording, playback, WAV I/O | Core recording engine |
| simple_hash | SHA-256 integrity hashing | Recording verification |
| simple_encryption | AES-256 encryption | At-rest security |
| simple_json | Metadata, configuration | Recording metadata |
| simple_sql | SQLite recording index | Search and organization |
| simple_datetime | Precise timestamps | Chain of custody |
| simple_file | Secure file operations | Storage management |
| simple_logger | Audit logging | Compliance trail |

### Optional Libraries

| Library | Purpose | When Needed |
|---------|---------|-------------|
| simple_pdf | Evidence reports | Court-ready documentation |
| simple_uuid | Recording IDs | Unique identifiers |
| simple_validation | Input validation | Strict mode |
| simple_scheduler | Scheduled recordings | Automated capture |
| simple_csv | Audit export | Spreadsheet analysis |

## Integration Patterns

### simple_audio Integration

**Purpose:** Core recording functionality - capture audio from devices, save to WAV.

**Usage:**
```eiffel
feature -- Recording

    start_recording (a_device: AUDIO_DEVICE; a_config: VAULT_CONFIG): VAULT_SESSION
            -- Start new recording session.
        require
            device_valid: a_device /= Void and then a_device.is_valid
            device_is_input: a_device.is_input
            config_valid: a_config /= Void
        local
            l_audio: SIMPLE_AUDIO
            l_stream: AUDIO_STREAM
            l_buffer: AUDIO_BUFFER
        do
            create l_audio.make
            l_stream := l_audio.create_input_stream (
                a_device,
                a_config.sample_rate,
                a_config.channels,
                a_config.bit_depth
            )

            if attached l_stream as s then
                -- Create buffer for 60 minutes max
                create l_buffer.make (
                    a_config.sample_rate * 3600,
                    a_config.channels,
                    a_config.bit_depth
                )

                create Result.make (s, l_buffer, a_config)
                s.start
            else
                last_error := "Failed to create recording stream"
            end
        ensure
            recording_or_error: Result /= Void or not last_error.is_empty
        end

    save_recording (a_session: VAULT_SESSION): VAULT_RECORDING
            -- Save completed recording session.
        require
            session_valid: a_session /= Void
            session_stopped: not a_session.is_recording
        local
            l_hash: STRING
            l_encrypted_path: STRING
        do
            -- Calculate integrity hash before encryption
            l_hash := calculate_audio_hash (a_session.buffer)

            -- Save raw WAV (temporary)
            a_session.buffer.save_to_wav (temp_path)

            -- Encrypt and save to vault
            l_encrypted_path := encrypt_and_store (temp_path, a_session.id)

            -- Create recording record
            create Result.make (a_session, l_hash, l_encrypted_path)

            -- Add to index
            index.add (Result)

            -- Log creation
            audit.log_creation (Result)

            -- Clean up temp file
            delete_file (temp_path)
        ensure
            recording_created: Result /= Void
            integrity_set: not Result.integrity_hash.is_empty
            indexed: index.has (Result.id)
            audited: audit.has_event (Result.id, "created")
        end
```

**Data flow:** Audio device -> AUDIO_STREAM -> AUDIO_BUFFER -> hash -> encrypt -> store

### simple_hash Integration

**Purpose:** SHA-256 integrity hashing for tamper detection and verification.

**Usage:**
```eiffel
feature -- Integrity

    calculate_audio_hash (a_buffer: AUDIO_BUFFER): STRING
            -- Calculate SHA-256 hash of audio data.
        require
            buffer_valid: a_buffer /= Void and then a_buffer.is_valid
        local
            l_hash: SIMPLE_HASH
        do
            create l_hash.make_sha256

            -- Hash the raw PCM data
            l_hash.update_managed_pointer (a_buffer.data, 0, a_buffer.byte_count)

            Result := l_hash.hex_digest
        ensure
            result_not_empty: not Result.is_empty
            correct_length: Result.count = 64
        end

    verify_recording (a_recording: VAULT_RECORDING): VERIFICATION_RESULT
            -- Verify recording integrity.
        require
            recording_valid: a_recording /= Void
        local
            l_buffer: AUDIO_BUFFER
            l_calculated_hash, l_stored_hash: STRING
        do
            create Result.make

            -- Decrypt and load recording
            l_buffer := decrypt_and_load (a_recording.encrypted_path)

            if l_buffer.is_valid then
                -- Calculate current hash
                l_calculated_hash := calculate_audio_hash (l_buffer)

                -- Compare with stored hash
                l_stored_hash := a_recording.integrity_hash

                Result.set_calculated_hash (l_calculated_hash)
                Result.set_stored_hash (l_stored_hash)

                if l_calculated_hash.same_string (l_stored_hash) then
                    Result.set_verified (True)
                    Result.set_message ("Integrity verified: Hash matches stored value")
                else
                    Result.set_verified (False)
                    Result.set_message ("INTEGRITY FAILURE: Hash mismatch detected")
                end
            else
                Result.set_verified (False)
                Result.set_message ("INTEGRITY FAILURE: Could not load recording")
            end

            -- Always log verification attempt
            audit.log_verification (a_recording.id, Result)
        ensure
            result_set: Result /= Void
            audited: audit.has_event (a_recording.id, "verified")
        end
```

**Data flow:** Recording -> decrypt -> hash -> compare -> verification result

### simple_encryption Integration

**Purpose:** AES-256 encryption for at-rest security.

**Usage:**
```eiffel
feature -- Encryption

    encrypt_and_store (a_source: STRING; a_id: STRING): STRING
            -- Encrypt audio file and store in vault.
        require
            source_exists: file_exists (a_source)
            id_not_empty: not a_id.is_empty
        local
            l_crypto: SIMPLE_ENCRYPTION
            l_key: ENCRYPTION_KEY
            l_dest: STRING
        do
            l_key := load_vault_key
            create l_crypto.make_aes_256_gcm (l_key)

            -- Generate destination path
            l_dest := vault_path_for (a_id)

            -- Encrypt file
            l_crypto.encrypt_file (a_source, l_dest)

            if l_crypto.is_success then
                Result := l_dest
            else
                last_error := "Encryption failed: " + l_crypto.last_error
            end
        ensure
            encrypted_or_error: not Result.is_empty or not last_error.is_empty
        end

    decrypt_and_load (a_path: STRING): AUDIO_BUFFER
            -- Decrypt recording and load into buffer.
        require
            path_not_empty: not a_path.is_empty
        local
            l_crypto: SIMPLE_ENCRYPTION
            l_key: ENCRYPTION_KEY
            l_temp: STRING
        do
            l_key := load_vault_key
            create l_crypto.make_aes_256_gcm (l_key)

            l_temp := generate_temp_path

            -- Decrypt to temp file
            l_crypto.decrypt_file (a_path, l_temp)

            if l_crypto.is_success then
                -- Load decrypted WAV
                create Result.make_from_wav (l_temp)

                -- Secure delete temp file
                secure_delete (l_temp)
            else
                create Result.make_empty
                last_error := "Decryption failed: " + l_crypto.last_error
            end
        end
```

**Data flow:** WAV file -> AES-256 encrypt -> vault storage / vault storage -> AES-256 decrypt -> WAV file

### simple_sql Integration

**Purpose:** SQLite database for recording index, search, and organization.

**Usage:**
```eiffel
feature -- Index Management

    index_database: SIMPLE_SQL
            -- Recording index database.
        once
            create Result.make_sqlite (vault_path + "/vault.db")
            ensure_schema (Result)
        end

    ensure_schema (a_db: SIMPLE_SQL)
            -- Create schema if not exists.
        do
            a_db.execute ("
                CREATE TABLE IF NOT EXISTS recordings (
                    id TEXT PRIMARY KEY,
                    case_id TEXT,
                    type TEXT,
                    subjects TEXT,
                    recorder TEXT,
                    created_at TEXT,
                    completed_at TEXT,
                    duration_seconds INTEGER,
                    integrity_hash TEXT,
                    encrypted_path TEXT,
                    notes TEXT,
                    status TEXT DEFAULT 'active'
                )
            ")

            a_db.execute ("
                CREATE INDEX IF NOT EXISTS idx_case ON recordings(case_id)
            ")

            a_db.execute ("
                CREATE INDEX IF NOT EXISTS idx_date ON recordings(created_at)
            ")
        end

    search_recordings (a_criteria: SEARCH_CRITERIA): LIST [VAULT_RECORDING]
            -- Search recordings matching criteria.
        local
            l_query: STRING
            l_stmt: SQL_STATEMENT
        do
            create {ARRAYED_LIST [VAULT_RECORDING]} Result.make (50)

            l_query := "SELECT * FROM recordings WHERE status = 'active'"

            if attached a_criteria.case_id as cid then
                l_query.append (" AND case_id = ?")
            end

            if attached a_criteria.date_from as df then
                l_query.append (" AND created_at >= ?")
            end

            if attached a_criteria.type as t then
                l_query.append (" AND type = ?")
            end

            l_query.append (" ORDER BY created_at DESC LIMIT ?")

            l_stmt := index_database.prepare (l_query)
            -- Bind parameters...

            across l_stmt.execute as row loop
                Result.extend (recording_from_row (row))
            end

            -- Log search
            audit.log_search (a_criteria)
        end
```

**Data flow:** Recording metadata -> SQLite insert / search criteria -> SQL query -> results

### simple_logger Integration

**Purpose:** Comprehensive audit logging for compliance.

**Usage:**
```eiffel
feature -- Audit Logging

    audit_logger: SIMPLE_LOGGER
            -- Audit trail logger.
        once
            create Result.make ("voice-vault-audit")
            Result.set_level (Log_info)
            Result.add_file_handler (audit_log_path)
            Result.set_format ("[%timestamp%] [%level%] %message%")
        end

    log_access (a_recording_id: STRING; a_action: STRING; a_user: STRING)
            -- Log recording access event.
        require
            id_not_empty: not a_recording_id.is_empty
            action_not_empty: not a_action.is_empty
        local
            l_entry: AUDIT_ENTRY
        do
            create l_entry.make (a_recording_id, a_action, a_user, current_timestamp)

            -- Log to file
            audit_logger.info (l_entry.to_string)

            -- Store in database for chain queries
            store_audit_entry (l_entry)
        ensure
            logged: audit_has_entry (a_recording_id, a_action)
        end

    get_chain_of_custody (a_recording_id: STRING): LIST [AUDIT_ENTRY]
            -- Get complete chain of custody for recording.
        require
            id_not_empty: not a_recording_id.is_empty
        local
            l_stmt: SQL_STATEMENT
        do
            create {ARRAYED_LIST [AUDIT_ENTRY]} Result.make (20)

            l_stmt := audit_database.prepare ("
                SELECT * FROM audit_log
                WHERE recording_id = ?
                ORDER BY timestamp ASC
            ")
            l_stmt.bind_string (1, a_recording_id)

            across l_stmt.execute as row loop
                Result.extend (entry_from_row (row))
            end
        ensure
            result_attached: Result /= Void
        end
```

**Data flow:** Action event -> audit log file + SQLite -> chain of custody query

## Dependency Graph

```
voice_vault
    |
    +-- simple_audio (required)
    |       +-- simple_file
    |       +-- ISE base
    |
    +-- simple_hash (required)
    |       +-- ISE base
    |
    +-- simple_encryption (required)
    |       +-- ISE base
    |
    +-- simple_json (required)
    |       +-- ISE base
    |
    +-- simple_sql (required)
    |       +-- simple_file
    |       +-- ISE base
    |
    +-- simple_datetime (required)
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
    +-- simple_uuid (optional - IDs)
    |       +-- ISE base
    |
    +-- simple_pdf (optional - reports)
    |       +-- simple_file
    |       +-- ISE base
    |
    +-- simple_scheduler (optional - automation)
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
        name="voice_vault"
        uuid="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx">

    <target name="voice_vault">
        <root class="VAULT_CLI" feature="make"/>

        <file_rule>
            <exclude>/EIFGENs$</exclude>
            <exclude>/\.git$</exclude>
        </file_rule>

        <option warning="warning" syntax="standard" manifest_array_type="mismatch_warning">
            <assertions precondition="true" postcondition="true" check="true" invariant="true"/>
        </option>

        <setting name="console_application" value="true"/>
        <setting name="executable_name" value="voice-vault"/>
        <setting name="dead_code_removal" value="feature"/>

        <capability>
            <concurrency support="scoop"/>
            <void_safety support="all"/>
        </capability>

        <!-- simple_* dependencies (required) -->
        <library name="simple_audio" location="$SIMPLE_EIFFEL/simple_audio/simple_audio.ecf"/>
        <library name="simple_hash" location="$SIMPLE_EIFFEL/simple_hash/simple_hash.ecf"/>
        <library name="simple_encryption" location="$SIMPLE_EIFFEL/simple_encryption/simple_encryption.ecf"/>
        <library name="simple_json" location="$SIMPLE_EIFFEL/simple_json/simple_json.ecf"/>
        <library name="simple_sql" location="$SIMPLE_EIFFEL/simple_sql/simple_sql.ecf"/>
        <library name="simple_datetime" location="$SIMPLE_EIFFEL/simple_datetime/simple_datetime.ecf"/>
        <library name="simple_file" location="$SIMPLE_EIFFEL/simple_file/simple_file.ecf"/>
        <library name="simple_logger" location="$SIMPLE_EIFFEL/simple_logger/simple_logger.ecf"/>

        <!-- Optional dependencies -->
        <!-- <library name="simple_uuid" location="$SIMPLE_EIFFEL/simple_uuid/simple_uuid.ecf"/> -->
        <!-- <library name="simple_pdf" location="$SIMPLE_EIFFEL/simple_pdf/simple_pdf.ecf"/> -->
        <!-- <library name="simple_scheduler" location="$SIMPLE_EIFFEL/simple_scheduler/simple_scheduler.ecf"/> -->

        <!-- ISE dependencies -->
        <library name="base" location="$ISE_LIBRARY/library/base/base.ecf"/>

        <!-- Application source -->
        <cluster name="src" location="./src/" recursive="true"/>
    </target>

    <target name="voice_vault_tests" extends="voice_vault">
        <root class="TEST_APP" feature="make"/>
        <setting name="executable_name" value="voice_vault_tests"/>
        <library name="simple_testing" location="$SIMPLE_EIFFEL/simple_testing/simple_testing.ecf"/>
        <cluster name="testing" location="./testing/" recursive="true"/>
    </target>

</system>
```

## Cross-Library Data Types

| Source Library | Type | Usage in Voice Vault |
|----------------|------|----------------------|
| simple_audio | AUDIO_BUFFER | Recording data container |
| simple_audio | AUDIO_STREAM | Recording input stream |
| simple_audio | AUDIO_DEVICE | Recording device |
| simple_hash | HASH_DIGEST | Integrity verification |
| simple_encryption | ENCRYPTION_KEY | Vault encryption key |
| simple_json | JSON_OBJECT | Metadata storage |
| simple_sql | SQL_DATABASE | Recording index |
| simple_sql | SQL_STATEMENT | Queries |
| simple_datetime | DATETIME | Timestamps |
| simple_logger | LOG_MESSAGE | Audit entries |
| simple_file | FILE_PATH | Storage paths |
