# RISKS: simple_audio


**Date**: 2026-01-23

## Risk Register

| ID | Risk | Likelihood | Impact | Mitigation |
|----|------|------------|--------|------------|
| RISK-001 | WASAPI COM complexity | MEDIUM | HIGH | Study miniaudio implementation |
| RISK-002 | Callback latency with contracts | MEDIUM | MEDIUM | Profile, disable in release |
| RISK-003 | SCOOP overhead in audio thread | LOW | HIGH | Careful callback isolation |
| RISK-004 | Device hot-plug handling | LOW | MEDIUM | Defer to Phase 2 |
| RISK-005 | Format conversion bugs | MEDIUM | LOW | Extensive test coverage |

## Technical Risks

### RISK-001: WASAPI COM Complexity
**Description:** WASAPI requires complex COM interface handling including reference counting, GUIDs, and async events
**Likelihood:** MEDIUM
**Impact:** HIGH
**Indicators:** Build failures, memory leaks, access violations
**Mitigation:** Reference miniaudio's WASAPI implementation, thorough testing
**Contingency:** Fall back to simpler WinMM if COM proves too complex

### RISK-002: Contract Overhead in Real-Time
**Description:** Precondition/postcondition checking may introduce latency in audio callbacks
**Likelihood:** MEDIUM
**Impact:** MEDIUM (audio glitches)
**Indicators:** Audible dropouts, buffer underruns
**Mitigation:** Profile callback performance, use check statements sparingly in hot paths
**Contingency:** Conditional compilation to disable contracts in release builds

### RISK-003: SCOOP and Audio Threads
**Description:** WASAPI callbacks come from system threads, may conflict with SCOOP model
**Likelihood:** LOW
**Impact:** HIGH (crashes, deadlocks)
**Indicators:** Hangs during playback, assertion failures
**Mitigation:** Isolate callback data structures, use lock-free ring buffers
**Contingency:** Single-threaded mode without SCOOP integration

## Ecosystem Risks

### RISK-004: simple_file Dependency
**Description:** Relying on simple_file for binary buffer handling
**Likelihood:** LOW
**Impact:** LOW
**Indicators:** API incompatibility
**Mitigation:** simple_file is stable, well-tested
**Contingency:** Implement minimal buffer class internally

## Resource Risks

### RISK-005: Testing Hardware Requirements
**Description:** Audio testing requires actual audio hardware, CI may lack it
**Likelihood:** MEDIUM
**Impact:** LOW
**Indicators:** Skipped tests in CI
**Mitigation:** Mock device tests, manual testing for real hardware
**Contingency:** Virtual audio device for CI
