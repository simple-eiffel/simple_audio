# DECISIONS: simple_audio


**Date**: 2026-01-23

## Decision Log

### D-001: Audio Backend
**Question:** Which Windows audio API to use?
**Options:**
1. WASAPI: Modern, low-latency, Windows Vista+
2. WinMM: Legacy, high latency, maximum compatibility
3. DirectSound: Deprecated, game-focused

**Decision:** WASAPI
**Rationale:** Lowest latency, modern Windows standard, exclusive mode support
**Implications:** Windows Vista+ required, COM interface complexity
**Reversible:** YES (can add backends later)

### D-002: Streaming Model
**Question:** How to handle continuous audio streaming?
**Options:**
1. Callback-based: Library calls user code with buffer
2. Push-based: User code writes to buffer queue
3. Pull-based: User code reads from library buffer

**Decision:** Callback-based
**Rationale:** Industry standard (PortAudio, miniaudio), lowest latency, natural for real-time
**Implications:** User must handle threading, callbacks must be fast
**Reversible:** NO (fundamental architecture)

### D-003: Buffer Management
**Question:** How to handle audio buffers?
**Options:**
1. Ring buffer: Circular buffer for streaming
2. Double buffer: Swap buffers on fill
3. Queue: FIFO of discrete buffers

**Decision:** Ring buffer with double-buffering
**Rationale:** Combines continuous streaming with predictable latency
**Implications:** Need robust ring buffer implementation
**Reversible:** YES

### D-004: Sample Format
**Question:** What internal sample format to use?
**Options:**
1. 32-bit float: Maximum quality, easy math
2. 16-bit integer: CD quality, compact
3. Native format: Match device, no conversion

**Decision:** 32-bit float internally, convert at device boundary
**Rationale:** Simplifies processing, avoids clipping during mixing
**Implications:** Conversion overhead at I/O, but minimal
**Reversible:** YES

### D-005: COM Interface Handling
**Question:** How to handle WASAPI COM interfaces in Eiffel?
**Options:**
1. Inline C: Direct COM calls in external blocks
2. C bridge library: Separate .c file with wrappers
3. WEL COM wrappers: Use existing EiffelStudio COM support

**Decision:** Inline C
**Rationale:** simple_* pattern, no external compilation, self-contained
**Implications:** Complex inline C code, but maintainable
**Reversible:** YES (can extract to bridge if needed)
