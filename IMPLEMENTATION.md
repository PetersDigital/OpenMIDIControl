## Implementation Roadmap

Following the [Version Roadmap](README.md#version-roadmap-v0.1.0-to-v1.0.0), the implementation is structured as follows:

### ✅ v0.1.0: Baseline
- **Responsive UI Shell:** Building the "Ethereal Console" using `LayoutBuilder` (Portrait Phone / Landscape Tablet).
- **Core Fader Logic:** Multi-touch pointer capture and normalized `0.0..1.0` value domain.
- **State Management:** Riverpod `Notifier` providers for transport-agnostic logic.

### ✅ v0.1.5: MIDI Reliability & Logic Polish
- **Metadata Reconnection:** Switched from transient IDs to Name/Manufacturer fingerprints for robust USB hot-plugging.
- **Virtual MIDI Bridge:** Native `VirtualMidiService.kt` to expose "OpenMIDIControl" as a device for other mobile apps.
- **Bi-directional Logic Engine:** Behavior logic (Catch-up/Hybrid) applied to both UI drag events and incoming MIDI `CC` streams.
- **Orientation Fix:** Dedicated `_MobileLandscapeLayout` to handle ultra-wide aspect ratios (19.5:9+).
- **Active Port UI:** Translucent row highlighting in MIDI settings to visualize active "data pipes."

### ⏳ v0.2.0: Advanced USB MIDI & Logic (Current Focus)

#### Phase 3: The Peripheral "Pivot"
The primary goal is to establish the Android phone as a **Class Compliant USB MIDI Peripheral** for Windows 11. This moves the app from controlling external hardware (Host mode) to controlling a DAW (Cubase, etc.) directly via USB.

- **Manifest & Service Integration:** Register a native `MidiDeviceService` in `AndroidManifest.xml` with `BIND_MIDI_DEVICE_SERVICE` permissions. This allows the app to broadcast standard USB MIDI descriptors requiring zero custom drivers on the host PC.
- **Service Configuration:** Update `midi_device_info.xml` to define the input and output port architecture exposed to the host DAW.
- **Peripheral Handshake:** Enhance `MainActivity.kt` to detect USB host connections and initialize the "Device Server" role.
- **Unified Routing:** Direct Flutter UI fader events to the Peripheral output port, ensuring low-latency delivery to the Windows environment.

#### Phase 4: Compliance & v0.2.0 Wrap-up
Focusing on professional stability and timing precision for the official v0.2.0 release.

- **Class Compliance Validation:** Rigorous testing across various hardware/cable configurations to ensure "plug-and-play" reliability.
- **Timing & Jitter Audit:** Implement high-precision monitoring using `System.nanoTime()` in Kotlin to measure the delta between UI touch events and MIDI byte egress. Target: sub-millisecond precision with minimal jitter.
- **14-bit Readiness:** Ensure the transport logic is optimized for high-resolution data (NRPN or Pitch Bend) in preparation for MCU/HUI support.
- **Deduplication Refinement:** Audit value-based suppression logic to prevent USB bus flooding while maintaining responsive feedback.
- **Release Polish:** Clean up debug indicators and finalize `CHANGELOG.md` for the v0.2.0 milestone.

### ⏳ v0.3.0: Control Expansion
- **Grid Components:** Implementing a 3×3 pad grid with low-latency velocity simulation.
- **Tactile Feedback:** Expanding haptic patterns for button toggles and multi-state switches.

### ⏳ v0.4.0+: MCU, HUI & Desktop Bridge
- **High Res (14-bit):** Pitch Bend and MSB/LSB pair handling for high-resolution DAW control.
- **Wireless Transport:** Optional rtpMIDI and WebSocket bridges for advanced macro integration.
- **MCU/HUI Handshake:** Native support for industry-standard DAW feedback protocols.