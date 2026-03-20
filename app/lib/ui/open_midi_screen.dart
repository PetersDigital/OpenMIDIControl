import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'hybrid_touch_fader.dart';
import 'settings_screen.dart';
import 'midi_settings_screen.dart';

// ---------------------------------------------------------------------------
// State: Fader Behavior
// ---------------------------------------------------------------------------
enum FaderBehavior { jump, hybrid, catchUp }

class FaderBehaviorNotifier extends Notifier<FaderBehavior> {
  @override
  FaderBehavior build() => FaderBehavior.jump;

  void updateBehavior(FaderBehavior v) => state = v;
}

final faderBehaviorProvider =
    NotifierProvider<FaderBehaviorNotifier, FaderBehavior>(
  FaderBehaviorNotifier.new,
);

// ---------------------------------------------------------------------------
// State: Layout hand (faders left vs. right)
// ---------------------------------------------------------------------------
enum LayoutHand { faderOnLeft, faderOnRight }

class LayoutHandNotifier extends Notifier<LayoutHand> {
  @override
  LayoutHand build() => LayoutHand.faderOnLeft;

  void toggle() {
    state = state == LayoutHand.faderOnLeft
        ? LayoutHand.faderOnRight
        : LayoutHand.faderOnLeft;
  }
}

final layoutHandProvider =
    NotifierProvider<LayoutHandNotifier, LayoutHand>(LayoutHandNotifier.new);

// ---------------------------------------------------------------------------
// Navigation helpers
// ---------------------------------------------------------------------------
void _showMidiSettings(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const MidiSettingsScreen()),
  );
}

void _showAppSettings(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const SettingsScreen()),
  );
}

// ---------------------------------------------------------------------------
// Root screen
// ---------------------------------------------------------------------------
class OpenMIDIMainScreen extends ConsumerWidget {
  const OpenMIDIMainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF111318),
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

// ===========================================================================
// MOBILE PORTRAIT LAYOUT
// ===========================================================================
class _MobilePortraitLayout extends ConsumerWidget {
  const _MobilePortraitLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Top bar
        Container(
          height: 64,
          color: const Color(0xFF0D131E),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.settings_input_component,
                  color: Color(0xFFA6C9F8), size: 26),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _showMidiSettings(context),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      child: Text(
                        "DISCONNECTED",
                        style: GoogleFonts.inter(
                          color: Colors.red.shade400,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showAppSettings(context),
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.more_vert,
                          color: Color(0xFFC3C7CA), size: 24),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // COMMAND CENTER (30%)
        Expanded(
          flex: 30,
          child: Container(
            color: const Color(0xFF1E2024),
            child: Column(
              children: [
                // Status row
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                          child: _StatusDisplay(
                              label: "TEMPO", value: "120 BPM")),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              "TRACK",
                              style: GoogleFonts.inter(
                                color: Colors.white60,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2.0,
                              ),
                            ),
                            Text(
                              "01 - Cinematic Violins",
                              style: GoogleFonts.manrope(
                                color: const Color(0xFFA6C9F8),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                          child: _StatusDisplay(
                              label: "TIMECODE",
                              value: "001:01:000",
                              alignRight: true)),
                    ],
                  ),
                ),

                // 3×3 control grid
                Expanded(
                  child: Container(
                    color: const Color(0xFF111318),
                    child: Column(
                      children: [
                        Expanded(
                          child: Row(children: const [
                            Expanded(child: _GridButton(icon: Icons.fast_rewind)),
                            Expanded(child: _GridButton(icon: Icons.keyboard_arrow_up, bgColor: Color(0xFF282A2E))),
                            Expanded(child: _GridButton(icon: Icons.fiber_manual_record, bgColor: Color(0xFFFFB59E), iconColor: Color(0xFF690005), isSolid: true, shadowColor: Color(0xFFFFB59E))),
                          ]),
                        ),
                        Expanded(
                          child: Row(children: const [
                            Expanded(child: _GridButton(icon: Icons.keyboard_arrow_left, bgColor: Color(0xFF282A2E))),
                            Expanded(child: _GridButton(icon: Icons.stop, bgColor: Color(0xFF33353A), iconColor: Colors.white)),
                            Expanded(child: _GridButton(icon: Icons.keyboard_arrow_right, bgColor: Color(0xFF282A2E))),
                          ]),
                        ),
                        Expanded(
                          child: Row(children: const [
                            Expanded(child: _GridButton(icon: Icons.fast_forward)),
                            Expanded(child: _GridButton(icon: Icons.keyboard_arrow_down, bgColor: Color(0xFF282A2E))),
                            Expanded(child: _GridButton(icon: Icons.play_arrow, bgColor: Color(0xFFA6C9F8), iconColor: Color(0xFF033258), isSolid: true, shadowColor: Color(0xFFA6C9F8))),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // PERFORMANCE ZONE (70%)
        Expanded(
          flex: 70,
          child: Container(
            color: const Color(0xFF111318),
            child: Row(
              children: [
                Expanded(
                  child: HybridTouchFader(
                    ccNumber: 1,
                    label: "CC1\nDYNAMICS",
                    activeColor: const Color(0xFFA6C9F8),
                    labelColor: const Color(0xFF033258),
                    initialValue: 1.0,
                    isMobile: true,
                  ),
                ),
                Expanded(
                  child: HybridTouchFader(
                    ccNumber: 11,
                    label: "CC11\nEXPRESSION",
                    activeColor: const Color(0xFFA1CFCE),
                    labelColor: const Color(0xFF013737),
                    initialValue: 0.5,
                    isMobile: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// DESKTOP / TABLET LANDSCAPE LAYOUT
// ===========================================================================
class _DesktopLandscapeLayout extends ConsumerWidget {
  const _DesktopLandscapeLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faderOnRight =
        ref.watch(layoutHandProvider) == LayoutHand.faderOnRight;

    final commandPanel = Expanded(
      flex: 40,
      child: _buildCommandCenter(context),
    );
    final faderPanel = Expanded(
      flex: 60,
      child: _buildPerformanceZone(),
    );

    return Row(
      children: faderOnRight
          ? [commandPanel, faderPanel]
          : [faderPanel, commandPanel],
    );
  }

  Widget _buildCommandCenter(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1C20),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "OPENMIDI",
                style: GoogleFonts.inter(
                  color: const Color(0xFFA6C9F8),
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  letterSpacing: -0.5,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _showMidiSettings(context),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      child: Text(
                        "DISCONNECTED",
                        style: GoogleFonts.inter(
                          color: Colors.red.shade400,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.5,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert,
                        color: Color(0xFFC3C7CA), size: 28),
                    onPressed: () => _showAppSettings(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Status displays
          Row(
            children: const [
              Expanded(
                  child: _StatusDisplay(label: "TEMPO", value: "120 BPM")),
              Expanded(
                  child: _StatusDisplay(
                      label: "TIMECODE", value: "001:01:000")),
            ],
          ),
          const SizedBox(height: 32),

          // Track name
          SizedBox(
            width: double.infinity,
            child: Text(
              "01 - Cinematic Violins",
              style: GoogleFonts.manrope(
                color: const Color(0xFFA6C9F8),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // 3×3 grid
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              color: const Color(0xFF111318),
              child: Column(
                children: [
                  Expanded(
                    child: Row(children: const [
                      Expanded(child: _GridButton(icon: Icons.fast_rewind)),
                      Expanded(child: _GridButton(icon: Icons.keyboard_arrow_up, bgColor: Color(0xFF282A2E))),
                      Expanded(child: _GridButton(icon: Icons.fiber_manual_record, bgColor: Color(0xFFFFB59E), iconColor: Color(0xFF690005), isSolid: true, shadowColor: Color(0xFFFFB59E))),
                    ]),
                  ),
                  Expanded(
                    child: Row(children: const [
                      Expanded(child: _GridButton(icon: Icons.keyboard_arrow_left, bgColor: Color(0xFF282A2E))),
                      Expanded(child: _GridButton(icon: Icons.stop, bgColor: Color(0xFF33353A), iconColor: Colors.white)),
                      Expanded(child: _GridButton(icon: Icons.keyboard_arrow_right, bgColor: Color(0xFF282A2E))),
                    ]),
                  ),
                  Expanded(
                    child: Row(children: const [
                      Expanded(child: _GridButton(icon: Icons.fast_forward)),
                      Expanded(child: _GridButton(icon: Icons.keyboard_arrow_down, bgColor: Color(0xFF282A2E))),
                      Expanded(child: _GridButton(icon: Icons.play_arrow, bgColor: Color(0xFFA6C9F8), iconColor: Color(0xFF033258), isSolid: true, shadowColor: Color(0xFFA6C9F8))),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceZone() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: HybridTouchFader(
              ccNumber: 1,
              label: "CC1 Dynamics",
              activeColor: const Color(0xFFA6C9F8),
              labelColor: const Color(0xFF033258),
              initialValue: 1.0,
              isMobile: false,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: HybridTouchFader(
              ccNumber: 11,
              label: "CC11 Expression",
              activeColor: const Color(0xFFA1CFCE),
              labelColor: const Color(0xFF013737),
              initialValue: 0.98,
              isMobile: false,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// SHARED WIDGETS
// ===========================================================================
class _StatusDisplay extends StatelessWidget {
  final String label;
  final String value;
  final bool alignRight;

  const _StatusDisplay({
    super.key,
    required this.label,
    required this.value,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white60,
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _GridButton extends StatelessWidget {
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final bool isSolid;
  final Color shadowColor;

  const _GridButton({
    super.key,
    required this.icon,
    this.bgColor = const Color(0xFF1E2024),
    this.iconColor = const Color(0xFFC3C7CA),
    this.isSolid = false,
    this.shadowColor = Colors.transparent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(
          color: const Color(0xFF111318).withValues(alpha: 0.2),
          width: 0.5,
        ),
        boxShadow: isSolid
            ? [
                BoxShadow(
                  color: shadowColor.withValues(alpha: 0.4),
                  blurRadius: 20,
                  blurStyle: BlurStyle.inner,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Icon(icon, color: iconColor, size: isSolid ? 36 : 24),
      ),
    );
  }
}
