## 2024-05-24 - [Flutter 120Hz Animation Churn]
**Learning:** `AnimationController`s triggering full `setState` up to 120Hz per second cause thermal and performance issues on mobile when driving UI elements dynamically via continuous external data (like MIDI CC updates). In high-frequency data applications, the entire widget tree gets unnecessarily rebuilt.
**Action:** Always wrap specifically the visually changing components in `AnimatedBuilder` instead of using an `.addListener(() { setState(() {}); });` on the controller for components mapping external high-speed inputs like MIDI.
