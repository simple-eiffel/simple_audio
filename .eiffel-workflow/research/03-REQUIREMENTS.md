# REQUIREMENTS: simple_audio

## Functional Requirements
| ID | Requirement | Priority | Acceptance Criteria |
|----|-------------|----------|---------------------|
| FR-001 | Play audio buffer to output device | MUST | Audio heard through speakers |
| FR-002 | Capture audio from input device | MUST | Buffer contains microphone data |
| FR-003 | Enumerate available audio devices | MUST | List of device names returned |
| FR-004 | Select specific output device | SHOULD | Audio plays to selected device |
| FR-005 | Select specific input device | SHOULD | Capture from selected device |
| FR-006 | Control playback volume | SHOULD | Volume changes audibly |
| FR-007 | Query device capabilities | SHOULD | Sample rates, formats returned |
| FR-008 | Support multiple sample rates | SHOULD | 44100, 48000, 96000 Hz work |
| FR-009 | Support multiple bit depths | SHOULD | 16-bit, 24-bit, 32-bit float work |
| FR-010 | Callback-based streaming | MUST | Continuous audio without gaps |

## Non-Functional Requirements
| ID | Requirement | Category | Measure | Target |
|----|-------------|----------|---------|--------|
| NFR-001 | Low latency playback | PERFORMANCE | Latency | < 20ms |
| NFR-002 | Low latency capture | PERFORMANCE | Latency | < 20ms |
| NFR-003 | No audio glitches | RELIABILITY | Dropouts per hour | 0 |
| NFR-004 | Thread-safe callbacks | CONCURRENCY | SCOOP compatible | Yes |
| NFR-005 | Memory efficient | RESOURCE | Buffer overhead | < 1MB |
| NFR-006 | Clean shutdown | RELIABILITY | Resource leaks | 0 |

## Constraints
| ID | Constraint | Type | Immutable? |
|----|------------|------|------------|
| C-001 | Must be SCOOP-compatible | TECHNICAL | YES |
| C-002 | Must prefer simple_* over ISE | ECOSYSTEM | YES |
| C-003 | Void-safe throughout | TECHNICAL | YES |
| C-004 | Windows WASAPI first | PLATFORM | NO |
| C-005 | Inline C for COM calls | TECHNICAL | YES |
| C-006 | No external DLLs beyond system | DEPLOYMENT | YES |
