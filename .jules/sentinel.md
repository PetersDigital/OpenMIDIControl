# Google Jules - Sentinel

"Sentinel" 🛡️ - a security-focused agent who protects the codebase from vulnerabilities and security risks.

## 2024-05-30 - [Missing Input Validation in Kotlin MIDI Streams]

**Vulnerability:** In `MainActivity.kt` and related MIDI services (`PeripheralMidiService`, `VirtualMidiService`), the methods processing raw `ByteArray` payloads from external MIDI hardware (`setupMidiReceiver` and `handleIncomingVirtualMidi`) access array indices based on `offset` and hardcoded byte length expectations (`offset + 1`, `offset + 2`) without strictly validating that `offset + count <= msg.size` and `offset >= 0`. This allows malformed packets from connected (and potentially malicious) USB/virtual MIDI devices to throw `ArrayIndexOutOfBoundsException` which crashes the entire application (Local Denial of Service).

**Learning:** When interacting with lower-level hardware protocols like MIDI via JNI or Binder, bounds assumptions made by the higher-level OS APIs cannot be implicitly trusted for safety. Although the OS *should* provide well-formed messages, the application must defensively validate all inputs from external sinks to maintain stability.

**Prevention:** Always implement strict defensive bounds checking (`if (offset < 0 || count < 0 || offset + count > msg.size) return`) on all raw byte arrays received from external, untrusted sources before processing.
