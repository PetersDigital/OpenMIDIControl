import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'hybrid_touch_fader.dart';

class OpenMIDIMainScreen extends ConsumerWidget {
  const OpenMIDIMainScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF111318), // Deep Studio Base
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 900) {
              return const _DesktopLandscapeLayout();
            } else {
              return const _MobilePortraitLayout();
            }
          },
        ),
      ),
    );
  }
}

// ==========================================
// MOBILE PORTRAIT LAYOUT
// ==========================================
class _MobilePortraitLayout extends ConsumerWidget {
  const _MobilePortraitLayout({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Top App Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("OPENMIDI", style: TextStyle(color: Color(0xFFa6c9f8), fontWeight: FontWeight.bold, fontSize: 18)),
              Text("CONNECTED", style: TextStyle(color: const Color(0xFFa6c9f8).withOpacity(0.8), fontSize: 10, letterSpacing: 2.0)),
            ],
          ),
        ),

        // COMMAND CENTER (35%)
        Expanded(
          flex: 35,
          child: Container(
            color: const Color(0xFF1A1C20),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Row 1: Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    Flexible(child: _StatusDisplay(label: "PROJECT TEMPO", value: "120 BPM")),
                    Flexible(child: _StatusDisplay(label: "TIMECODE", value: "001:01:000", alignRight: true)),
                  ],
                ),
                // Row 2: Nav & Track
                Row(
                  children: [
                    // Flattened D-Pad (Up/Down)
                    SizedBox(
                      width: 80,
                      child: Row(
                        children: const [
                          Expanded(child: _ControlButton(icon: Icons.keyboard_arrow_up)),
                          SizedBox(width: 4),
                          Expanded(child: _ControlButton(icon: Icons.keyboard_arrow_down)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Track Display
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(color: const Color(0xFF0C0E12), borderRadius: BorderRadius.circular(6)),
                        alignment: Alignment.center,
                        child: const Text("01 - Cinematic Violins", style: TextStyle(color: Color(0xFFa6c9f8), fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                // Row 3: Massive Transport
                Row(
                  children: const [
                    Expanded(flex: 2, child: _ControlButton(icon: Icons.fast_rewind)),
                    SizedBox(width: 8),
                    Expanded(flex: 2, child: _ControlButton(icon: Icons.stop)),
                    SizedBox(width: 8),
                    Expanded(flex: 3, child: _ControlButton(icon: Icons.play_arrow, bgColor: Color(0xFFa6c9f8), iconColor: Color(0xFF033258))),
                    SizedBox(width: 8),
                    Expanded(flex: 3, child: _ControlButton(icon: Icons.fiber_manual_record, bgColor: Color(0xFFffb59e), iconColor: Color(0xFF690005))),
                  ],
                ),
              ],
            ),
          ),
        ),

        // PERFORMANCE ZONE (65%)
        Expanded(
          flex: 65,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: const [
                Expanded(child: HybridTouchFader(ccNumber: 1, label: "CC1 DYNAMICS", activeColor: Color(0xFFa6c9f8))),
                SizedBox(width: 16),
                Expanded(child: HybridTouchFader(ccNumber: 11, label: "CC11 EXPRESSION", activeColor: Color(0xFFa1cfce))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// DESKTOP/TABLET LANDSCAPE LAYOUT
// ==========================================
class _DesktopLandscapeLayout extends ConsumerWidget {
  const _DesktopLandscapeLayout({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        // PERFORMANCE ZONE (60%)
        Expanded(
          flex: 60,
          child: Center(
            child: SizedBox(
              width: 400, // Constrained hardware width
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48.0),
                child: Row(
                  children: const [
                    Expanded(child: HybridTouchFader(ccNumber: 1, label: "CC1 DYNAMICS", activeColor: Color(0xFFa6c9f8))),
                    SizedBox(width: 32), // Wide gutter
                    Expanded(child: HybridTouchFader(ccNumber: 11, label: "CC11 EXPRESSION", activeColor: Color(0xFFa1cfce))),
                  ],
                ),
              ),
            ),
          ),
        ),

        // COMMAND CENTER (40%)
        Expanded(
          flex: 40,
          child: Container(
            color: const Color(0xFF1A1C20),
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: const [
                    Expanded(child: _StatusDisplay(label: "PROJECT BPM", value: "120")),
                    Expanded(child: _StatusDisplay(label: "TIMECODE", value: "001:01:000")),
                  ],
                ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: const Color(0xFF0C0E12), borderRadius: BorderRadius.circular(6)),
                  child: const Text("01 - Cinematic Violins", style: TextStyle(color: Colors.white, fontSize: 24)),
                ),
                const SizedBox(height: 32),

                // 3x3 Grid Placeholder (Jules can expand this)
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(color: const Color(0xFF1E2024), borderRadius: BorderRadius.circular(6)),
                    child: const Center(child: Text("3x3 Transport Grid Here", style: TextStyle(color: Colors.grey))),
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// REUSABLE WIDGETS
// ==========================================
class _StatusDisplay extends StatelessWidget {
  final String label;
  final String value;
  final bool alignRight;

  const _StatusDisplay({required this.label, required this.value, this.alignRight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, letterSpacing: 2.0)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final Color bgColor;
  final Color iconColor;

  const _ControlButton({
    required this.icon,
    this.bgColor = const Color(0xFF1E2024),
    this.iconColor = Colors.white70,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Icon(icon, color: iconColor),
    );
  }
}
