// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'hybrid_touch_fader.dart';
import 'midi_service.dart';
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

final layoutHandProvider = NotifierProvider<LayoutHandNotifier, LayoutHand>(
  LayoutHandNotifier.new,
);

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
    final mq = MediaQuery.of(context);
    final isLandscape = mq.orientation == Orientation.landscape;
    final isTablet = mq.size.shortestSide >= 600;

    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Adaptive layout selection
            if (isLandscape) {
              if (isTablet && constraints.maxWidth > 900) {
                return const _DesktopLandscapeLayout();
              }
              // Landscape on phones (including ultra-wide 19.5:9+)
              return const _MobileLandscapeLayout();
            }
            // Default portrait for mobile
            return const _MobilePortraitLayout();
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
  const _MobilePortraitLayout();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Top bar
        Container(
          height: 64,
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(
                Icons.settings_input_component,
                color: Color(0xFFA6C9F8),
                size: 26,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ConnectionStatusButton(
                    onTap: () => _showMidiSettings(context),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'App Settings',
                    child: GestureDetector(
                      onTap: () => _showAppSettings(context),
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.more_vert,
                          color: Color(0xFFC3C7CA),
                          size: 24,
                        ),
                      ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatusDisplay(label: "TEMPO", value: "120 BPM"),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            const Text(
                              "TRACK",
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: Colors.white60,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2.0,
                              ),
                            ),
                            const Text(
                              "01 - Cinematic Violins",
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: Color(0xFFA6C9F8),
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
                          alignRight: true,
                        ),
                      ),
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
                          child: Row(
                            children: const [
                              Expanded(
                                child: _GridButton(icon: Icons.fast_rewind),
                              ),
                              Expanded(
                                child: _GridButton(
                                  icon: Icons.keyboard_arrow_up,
                                  bgColor: Color(0xFF282A2E),
                                ),
                              ),
                              Expanded(
                                child: _GridButton(
                                  icon: Icons.fiber_manual_record,
                                  bgColor: Color(0xFFFFB59E),
                                  iconColor: Color(0xFF690005),
                                  isSolid: true,
                                  shadowColor: Color(0xFFFFB59E),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: const [
                              Expanded(
                                child: _GridButton(
                                  icon: Icons.keyboard_arrow_left,
                                  bgColor: Color(0xFF282A2E),
                                ),
                              ),
                              Expanded(
                                child: _GridButton(
                                  icon: Icons.stop,
                                  bgColor: Color(0xFF33353A),
                                  iconColor: Colors.white,
                                ),
                              ),
                              Expanded(
                                child: _GridButton(
                                  icon: Icons.keyboard_arrow_right,
                                  bgColor: Color(0xFF282A2E),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: const [
                              Expanded(
                                child: _GridButton(icon: Icons.fast_forward),
                              ),
                              Expanded(
                                child: _GridButton(
                                  icon: Icons.keyboard_arrow_down,
                                  bgColor: Color(0xFF282A2E),
                                ),
                              ),
                              Expanded(
                                child: _GridButton(
                                  icon: Icons.play_arrow,
                                  bgColor: Color(0xFFA6C9F8),
                                  iconColor: Color(0xFF033258),
                                  isSolid: true,
                                  shadowColor: Color(0xFFA6C9F8),
                                ),
                              ),
                            ],
                          ),
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
                    behavior: ref.watch(faderBehaviorProvider),
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
                    behavior: ref.watch(faderBehaviorProvider),
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
// MOBILE LANDSCAPE LAYOUT
// ===========================================================================
class _MobileLandscapeLayout extends ConsumerWidget {
  const _MobileLandscapeLayout();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faderOnRight =
        ref.watch(layoutHandProvider) == LayoutHand.faderOnRight;

    final commandPanel = Expanded(
      flex: 38,
      child: _buildCommandCenter(context, ref),
    );
    final faderPanel = Expanded(flex: 62, child: _buildPerformanceZone(ref));

    return Row(
      children: faderOnRight
          ? [commandPanel, faderPanel]
          : [faderPanel, commandPanel],
    );
  }

  Widget _buildCommandCenter(BuildContext context, WidgetRef ref) {
    return Container(
      color: const Color(0xFF1E2024),
      child: Column(
        children: [
          // Compact Header Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(
                  Icons.settings_input_component,
                  color: Color(0xFFA6C9F8),
                  size: 20,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ConnectionStatusButton(
                      onTap: () => _showMidiSettings(context),
                    ),
                    Tooltip(
                      message: 'App Settings',
                      child: IconButton(
                        icon: const Icon(
                          Icons.more_vert,
                          color: Color(0xFFC3C7CA),
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _showAppSettings(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Status Row (Tempo/TC)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _StatusDisplay(label: "TEMPO", value: "120 BPM"),
                ),
                Expanded(
                  child: _StatusDisplay(
                    label: "TIMECODE",
                    value: "001:01:000",
                    alignRight: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Transport Grid (Full bleed)
          Expanded(
            child: Container(
              color: const Color(0xFF111318),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: const [
                        Expanded(child: _GridButton(icon: Icons.fast_rewind)),
                        Expanded(
                          child: _GridButton(
                            icon: Icons.keyboard_arrow_up,
                            bgColor: Color(0xFF282A2E),
                          ),
                        ),
                        Expanded(
                          child: _GridButton(
                            icon: Icons.fiber_manual_record,
                            bgColor: Color(0xFFFFB59E),
                            iconColor: Color(0xFF690005),
                            isSolid: true,
                            shadowColor: Color(0xFFFFB59E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: const [
                        Expanded(
                          child: _GridButton(
                            icon: Icons.keyboard_arrow_left,
                            bgColor: Color(0xFF282A2E),
                          ),
                        ),
                        Expanded(
                          child: _GridButton(
                            icon: Icons.stop,
                            bgColor: Color(0xFF33353A),
                            iconColor: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: _GridButton(
                            icon: Icons.keyboard_arrow_right,
                            bgColor: Color(0xFF282A2E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: const [
                        Expanded(child: _GridButton(icon: Icons.fast_forward)),
                        Expanded(
                          child: _GridButton(
                            icon: Icons.keyboard_arrow_down,
                            bgColor: Color(0xFF282A2E),
                          ),
                        ),
                        Expanded(
                          child: _GridButton(
                            icon: Icons.play_arrow,
                            bgColor: Color(0xFFA6C9F8),
                            iconColor: Color(0xFF033258),
                            isSolid: true,
                            shadowColor: Color(0xFFA6C9F8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceZone(WidgetRef ref) {
    return Container(
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
              behavior: ref.watch(faderBehaviorProvider),
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
              behavior: ref.watch(faderBehaviorProvider),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// DESKTOP / TABLET LANDSCAPE LAYOUT
// ===========================================================================
class _DesktopLandscapeLayout extends ConsumerWidget {
  const _DesktopLandscapeLayout();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faderOnRight =
        ref.watch(layoutHandProvider) == LayoutHand.faderOnRight;

    final commandPanel = Expanded(
      flex: 40,
      child: _buildCommandCenter(context, ref),
    );
    final faderPanel = Expanded(flex: 60, child: _buildPerformanceZone(ref));

    return Row(
      children: faderOnRight
          ? [commandPanel, faderPanel]
          : [faderPanel, commandPanel],
    );
  }

  Widget _buildCommandCenter(BuildContext context, WidgetRef ref) {
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
              const Text(
                "OPENMIDI",
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFFA6C9F8),
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  letterSpacing: -0.5,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ConnectionStatusButton(
                    onTap: () => _showMidiSettings(context),
                  ),
                  Tooltip(
                    message: 'App Settings',
                    child: IconButton(
                      icon: const Icon(
                        Icons.more_vert,
                        color: Color(0xFFC3C7CA),
                        size: 28,
                      ),
                      onPressed: () => _showAppSettings(context),
                    ),
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
                child: _StatusDisplay(label: "TEMPO", value: "120 BPM"),
              ),
              Expanded(
                child: _StatusDisplay(label: "TIMECODE", value: "001:01:000"),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Track name
          SizedBox(
            width: double.infinity,
            child: const Text(
              "01 - Cinematic Violins",
              style: TextStyle(
                fontFamily: 'Inter',
                color: Color(0xFFA6C9F8),
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
                    child: Row(
                      children: const [
                        Expanded(child: _GridButton(icon: Icons.fast_rewind)),
                        Expanded(
                          child: _GridButton(
                            icon: Icons.keyboard_arrow_up,
                            bgColor: Color(0xFF282A2E),
                          ),
                        ),
                        Expanded(
                          child: _GridButton(
                            icon: Icons.fiber_manual_record,
                            bgColor: Color(0xFFFFB59E),
                            iconColor: Color(0xFF690005),
                            isSolid: true,
                            shadowColor: Color(0xFFFFB59E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: const [
                        Expanded(
                          child: _GridButton(
                            icon: Icons.keyboard_arrow_left,
                            bgColor: Color(0xFF282A2E),
                          ),
                        ),
                        Expanded(
                          child: _GridButton(
                            icon: Icons.stop,
                            bgColor: Color(0xFF33353A),
                            iconColor: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: _GridButton(
                            icon: Icons.keyboard_arrow_right,
                            bgColor: Color(0xFF282A2E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: const [
                        Expanded(child: _GridButton(icon: Icons.fast_forward)),
                        Expanded(
                          child: _GridButton(
                            icon: Icons.keyboard_arrow_down,
                            bgColor: Color(0xFF282A2E),
                          ),
                        ),
                        Expanded(
                          child: _GridButton(
                            icon: Icons.play_arrow,
                            bgColor: Color(0xFFA6C9F8),
                            iconColor: Color(0xFF033258),
                            isSolid: true,
                            shadowColor: Color(0xFFA6C9F8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceZone(WidgetRef ref) {
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
              behavior: ref.watch(faderBehaviorProvider),
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
              behavior: ref.watch(faderBehaviorProvider),
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

class _ConnectionStatusButton extends ConsumerStatefulWidget {
  final VoidCallback onTap;

  const _ConnectionStatusButton({required this.onTap});

  @override
  ConsumerState<_ConnectionStatusButton> createState() =>
      _ConnectionStatusButtonState();
}

class _ConnectionStatusButtonState
    extends ConsumerState<_ConnectionStatusButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _glowOpacity;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _glowOpacity = Tween<double>(begin: 0.25, end: 0.55).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final midiStatus = ref.watch(midiStatusProvider);

    String statusText;
    Color statusColor;
    bool showGlow = false;

    switch (midiStatus) {
      case MidiStatus.usbActive:
        statusText = "USB PERIPHERAL MODE READY";
        statusColor = Colors.green.shade400;
        _animationController.stop();
        break;
      case MidiStatus.usbHostConnected:
        statusText = "USB HOST CONNECTED";
        statusColor = Colors.green.shade400;
        _animationController.stop();
        break;
      case MidiStatus.connected:
        statusText = "CONNECTED";
        statusColor = Colors.green.shade400;
        _animationController.stop();
        break;
      case MidiStatus.available:
        statusText = "AVAILABLE";
        statusColor = const Color(0xFFFFCA28); // Amber
        showGlow = true;
        if (!_animationController.isAnimating) {
          _animationController.repeat(reverse: true);
        }
        break;
      case MidiStatus.connectionLost:
        statusText = "CONNECTION LOST";
        statusColor = const Color(0xFFE57373); // Red
        _animationController.stop();
        break;
      case MidiStatus.disconnected:
        statusText = "DISCONNECTED";
        statusColor = const Color(0xFFE57373); // Red
        _animationController.stop();
        break;
    }

    final buttonContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: statusColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showGlow) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            statusText,
            style: TextStyle(
              fontFamily: 'Inter',
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );

    return Tooltip(
      message: 'MIDI Settings',
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (showGlow)
              FadeTransition(
                opacity: _glowOpacity,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor,
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.35),
                        blurRadius: 18,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const SizedBox(height: 34, width: 100),
                ),
              ),
            buttonContent,
          ],
        ),
      ),
    );
  }
}

class _StatusDisplay extends StatelessWidget {
  final String label;
  final String value;
  final bool alignRight;

  const _StatusDisplay({
    required this.label,
    required this.value,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
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
            style: const TextStyle(
              fontFamily: 'Inter',
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
