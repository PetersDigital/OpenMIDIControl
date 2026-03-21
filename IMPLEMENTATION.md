## Implementation Roadmap

### v0.1.0: Touch/UI & State Management
This stage focuses entirely on the user-facing interface and internal logic, independent of any actual MIDI hardware.

- Key Tasks: Building the responsive Flutter UI (the mobile portrait and tablet landscape "Ethereal Console" layouts) plus the command center grid, status row, and top-bar actions that open the Settings and MIDI Settings views.
- Core Mechanisms: Implementing multi-touch pointer capture for the two expressive faders (CC1 and CC11), the `HybridTouchFader` readout (DSEG7 font, long-press CC picker, color-coded tracks), and Riverpod state management so the UI can toggle fader behavior, layout hand, and future transport intents.
	* Additional focus: The Settings screen now surfaces Jump/Hybrid/Catch-Up modes, layout placement, and version metadata, while the MIDI Settings placeholder displays the "device disconnected" banner and upcoming device list.

### v0.2.0: The Native MIDI Service Bridge
This is where the app physically connects to the outside world.
- Key Tasks: Establishing the Flutter Platform Channels to communicate with Android's native android.media.midi stack.
- Core Mechanisms: Translating the normalized UI values into standard 7-bit or 14-bit MIDI CC output. Crucially, this stage also implements the "deterministic behavior and defensive feedback-loop prevention," utilizing short time-window suppression to prevent fader oscillation when receiving bidirectional feedback.

### v0.3.0: Transport/Host Integration
This final development stage tailors the baseline MIDI app to communicate effectively with a specific DAW.
- Key Tasks: Implementing the Cubase MIDI Remote API mapping using the reference scripts.
- Core Mechanisms: Establishing the boundary where the app remains DAW-agnostic, while the host adapter translates the app's control events and provides feedback normalization back to the core app.

### v0.4.0: Testing, Optimization & Guardrails
This final stage turns the baseline prototype into a professional, stage-ready instrument by strictly enforcing performance constraints and testing reliability.

- Key Tasks: Stress-testing thermal guardrails, ensuring multi-touch concurrency without pointer conflicts, and implementing the connection recovery lifecycle to safely handle accidental port loss.
- Core Mechanisms: Implementing value-based deduplication with a 50–100 ms suppression window to prevent visual feedback loops, and rate-limiting/coalescing outbound events (capped at 120 Hz) to protect CPU and battery stability.