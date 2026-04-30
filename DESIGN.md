# Design System Strategy: The Console

## 1. Overview & Creative North Star

The Creative North Star for this design system is **"The Console."**

We are moving away from the "flat web" and toward a high-fidelity digital instrument. This system should feel like a piece of precision laboratory equipment viewed through a lens of soft, atmospheric light. We achieve this by rejecting the standard "boxed" layout in favor of **Tonal Architecture**.

Instead of drawing lines to separate ideas, we use depth, light, and "dead-touch" zones to create a UI that feels carved from a single block of obsidian, then illuminated by internal LED hardware. Every interaction should feel intentional, technical, and premium.

---

## 2. Colors & Atmospheric Depth

Our palette is rooted in deep obsidian tones with luminous accents. The goal is a high-contrast environment where color represents state and energy, not just decoration.

### The "No-Line" Rule

**Strict Mandate:** Designers are prohibited from using 1px solid borders to define sections.
Boundaries must be created through background color shifts. For example, a `surface_container_low` control panel should sit directly on a `surface` background. The eye should perceive the edge through the change in value, not a stroke.

### Surface Hierarchy & Nesting

Treat the UI as a series of physical layers. Use the surface-container tiers to create "nested" depth:

* **Base:** `surface_dim` (#111318) for the overall application backdrop.
* **Primary Work Area:** `surface_container` (#1e2024).
* **Interactive Modules:** `surface_container_high` (#282a2e) for raised components.
* **Active Overlays:** `surface_container_highest` (#333539) to draw the eye to focused tasks.

### Signature Textures

* **Token:** Use `surface_variant` at 60% opacity with a `20px` backdrop blur.
* **Signature Glow:** For primary CTAs, do not use flat fills. Use a subtle inner-glow effect using `on_primary_container` to give the button a "powered-on" hardware feel.

---

## 3. Typography: Technical Authority

We pair the geometric precision of **Space Grotesk** with the clean readability of **Inter**.

* **Display & Headlines (Space Grotesk):** Used for data readouts and section headers. The wide apertures and monospaced-adjacent feel of Space Grotesk reinforce the "Technical Console" aesthetic.
* **Body & Titles (Inter):** Used for all functional labels and instructional text. Inter provides the "Human" balance to the technical display face.
* **Hierarchy Note:** Use `label-sm` (Space Grotesk) in all-caps with `0.05em` letter spacing for hardware-style labels above faders and inputs.

---

## 4. Elevation & Light

In this system, light replaces physical structure.

### The Layering Principle

Depth is achieved by "stacking" tiers. Place a `surface_container_lowest` card inside a `surface_container_low` section to create a "recessed" tray effect. This mimics the milled aluminum of high-end audio consoles.

### Ambient Shadows

Shadows must be invisible but felt.

* **Values:** Blur: `24px` to `40px`. Opacity: `4%-8%`.
* **Color:** Use a tinted version of `primary` or `tertiary` (matching the active component) rather than black. This creates a "light leak" effect rather than a shadow.

### The "Ghost Border" Fallback

If contrast ratios require a boundary, use a **Ghost Border**: `outline_variant` at 15% opacity. Never use 100% opaque outlines.

---

## 5. Components: The 1% Polish

### Fader Ribbons (Signature Component)

Faders are the heart of the Console. They must mimic physical LED strips.

* **The Block:** Must be solid color blocks. Use `primary_container` (#a6c9f8) or `tertiary_container` (#a1cfce). **No gradients.**
* **The Glow:** Apply a `4px` to `8px` outer glow (drop shadow) using the same color as the ribbon at 30% opacity. This simulates light reflecting off the "obsidian" hardware casing.
* **Corners:** All fader tracks and thumbs must use `rounded-md` (0.375rem).

### Vertical Fader Gutters (The Dead-Touch Zone)

To prevent accidental simultaneous activation in high-stakes environments:

* **Mandatory Spacing:** A gutter of **16px to 24px** (Spacing Scale 16 or 20) must exist between the interactive hit-boxes of vertical faders. This "dead zone" ensures precision and reinforces the technical layout.

### Buttons & Inputs

* **Buttons:** Use `rounded-md` (0.375rem). Primary buttons use a solid `primary_container` fill. Tertiary buttons should be "Ghost" style (no fill, subtle `outline_variant` hover state).
* **Input Fields:** Recess inputs using `surface_container_lowest`. Use `on_surface_variant` for placeholder text to maintain the moody, low-light aesthetic.
* **No Dividers:** Forbid the use of divider lines in lists. Use vertical white space (`spacing-4` or `1.4rem`) or a subtle shift to `surface_container_low` on hover to separate items.

---

## 6. Do's and Don'ts

### Do

* **DO** use intentional asymmetry. Offset a sidebar or header to break the "web template" feel.
* **DO** lean into tonal shifts. If a UI feels flat, adjust the `surface_container` tier rather than adding a border.
* **DO** ensure high-interaction faders have a clear "off" state using `surface_variant`.

### Don't

* **DON'T** use pure black (#000000). Always use the `surface` tokens to maintain the deep charcoal "Obsidian" depth.
* **DON'T** use standard 1px borders. If you feel you need one, try increasing the spacing or changing the background color first.
* **DON'T** use rounded-full (pills) for functional buttons; stick to the technical `rounded-md` (0.375rem) to maintain the "Console" precision.

## 7. Command Center & Layout Momentum

Treat the command center as the "instrument cluster" for the console: 30% of the portrait canvas and 40% of the landscape canvas are reserved for it so the status row, timecode, and nav grid never compete with the faders.

* **Snapshot / Preset Panel:** Accessible from the settings drawer. Provides the UI state for managing deeply configurable presets that drive the underlying `MidiRouter`. Presets recall layout and routing configurations dynamically.

* **Status Banners:**
  * `usbReady`: Amber border/title. "USB PERIPHERAL READY". (Peripheral mode active, waiting for traffic).
  * `usbConnected`: Deep green border (`Colors.green.shade900`), `Colors.green.shade400` icon/title. "USB HOST CONNECTED". (DAW traffic detected).
  * `available`: Amber border/title. "MIDI DEVICES AVAILABLE". (Non-peripheral hardware detected).
  * `connectionLost`: Red border/title. "CONNECTION LOST" (transient state).
* **Control grid:** The 3×3 grid of transport controls serves primarily as a visual anchor and layout testbed for future macros, so keep the glyphs aligned and consistent with the `surface_container` tiers.
* **Connections Branding:**
  * Manual overrides and USB mode toggles use the `primary_container` color for active switches.
  * Device tiles use `surface_container_low` with `primary_container` translucent highlighting (10% alpha) when active.
* **Responsive placements:** The same grid + faders reorder depending on the screen width, so avoid resizing or cropping the command panel text; the layout toggle on the settings screen flips the whole stack left/right without reflowing the grid elements.
* **Diagnostics Interface:** The 'Bug' icon in the status bar serves as the entry point for the high-precision event log. It features a transient 'Amber' state when the console is active, maintaining the laboratory console aesthetic while providing real-time technical feedback.

Preserve the Console photon glow rules when building any future overlays that share the command center space (glassy surfaces, diffused shadows, no hard outlines).
