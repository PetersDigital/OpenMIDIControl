// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/hybrid_xy_pad.dart';
import 'panels/drum_grid_panel.dart';
import 'panels/utility_grid_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hybrid_touch_fader.dart';
import 'midi_service.dart';
import 'settings_screen.dart';
import 'midi_settings_screen.dart';
import 'providers/config_ui_provider.dart';
import 'widgets/config_gesture_wrapper.dart';
import 'design_system.dart';
import 'layout_state.dart';
import 'side_panel_state.dart';

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
// State: Transport Visibility
// ---------------------------------------------------------------------------
class TransportVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => false; // Default is hidden, initialized later

  void toggle() => state = !state;
  void setVisible(bool visible) => state = visible;
}

final transportVisibleProvider =
    NotifierProvider<TransportVisibleNotifier, bool>(
      TransportVisibleNotifier.new,
    );

final firstLaunchCheckProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final hasLaunched = prefs.getBool('hasLaunched') ?? false;
  return !hasLaunched;
});

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

// (SidePanelNotifier was moved to side_panel_state.dart)

// ---------------------------------------------------------------------------

// Navigation helpers
// ---------------------------------------------------------------------------
void _showMidiSettings(BuildContext context, WidgetRef ref) {
  final isLandscape =
      MediaQuery.orientationOf(context) == Orientation.landscape;
  if (isLandscape) {
    ref.read(sidePanelProvider.notifier).show(SidePanelType.midiSettings);
  } else {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MidiSettingsScreen()),
    );
  }
}

void _showAppSettings(BuildContext context, WidgetRef ref) {
  final isLandscape =
      MediaQuery.orientationOf(context) == Orientation.landscape;
  if (isLandscape) {
    ref.read(sidePanelProvider.notifier).show(SidePanelType.appSettings);
  } else {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }
}

// ---------------------------------------------------------------------------
// Root screen
// ---------------------------------------------------------------------------
class OpenMIDIMainScreen extends ConsumerStatefulWidget {
  const OpenMIDIMainScreen({super.key});

  @override
  ConsumerState<OpenMIDIMainScreen> createState() => _OpenMIDIMainScreenState();
}

class _OpenMIDIMainScreenState extends ConsumerState<OpenMIDIMainScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkFirstLaunch();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final orientation =
        WidgetsBinding
                .instance
                .platformDispatcher
                .views
                .first
                .physicalSize
                .aspectRatio >
            1
        ? Orientation.landscape
        : Orientation.portrait;

    if (orientation == Orientation.landscape) {
      ref.read(transportVisibleProvider.notifier).setVisible(true);
    } else {
      ref.read(transportVisibleProvider.notifier).setVisible(false);
    }
  }

  Future<void> _checkFirstLaunch() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final isFirstLaunch = await ref.read(firstLaunchCheckProvider.future);
      if (isFirstLaunch) {
        ref.read(transportVisibleProvider.notifier).setVisible(true);

        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          ref.read(transportVisibleProvider.notifier).setVisible(false);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('hasLaunched', true);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.orientationOf(context);
    final size = MediaQuery.sizeOf(context);
    final isLandscape = orientation == Orientation.landscape;
    final isTablet = size.shortestSide >= 600;

    // Sync transport visibility with orientation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final current = ref.read(transportVisibleProvider);
        if (isLandscape && !current) {
          ref.read(transportVisibleProvider.notifier).setVisible(true);
        } else if (!isLandscape && current) {
          ref.read(transportVisibleProvider.notifier).setVisible(false);
        }
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                // Adaptive layout selection
                if (isLandscape) {
                  return _LandscapeLayout(
                    isMobile: !isTablet || constraints.maxWidth <= 900,
                  );
                }
                // Default portrait for mobile
                return const _MobilePortraitLayout();
              },
            ),
            const DeviceOfflineOverlay(),
            if (isLandscape) const _SidePanelOverlay(),
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 24.0),
                child: DynamicConnectionIsland(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// MOBILE PORTRAIT LAYOUT
// ===========================================================================
// Global key to preserve PerformanceZone state across layout/orientation changes
final GlobalKey<_PerformanceZoneState> _performanceZoneKey =
    GlobalKey<_PerformanceZoneState>();

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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // LEFT ZONE: App Icon
              const Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.settings_input_component,
                      color: Color(0xFFA6C9F8),
                      size: 26,
                    ),
                  ],
                ),
              ),

              // RIGHT ZONE: Transport + Settings
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Tooltip(
                      message: 'Toggle Transport',
                      child: GestureDetector(
                        key: const ValueKey('transport_toggle_button_portrait'),
                        onTap: () => ref
                            .read(transportVisibleProvider.notifier)
                            .toggle(),
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.play_circle_outline,
                            color: Color(0xFFC3C7CA),
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Tooltip(
                      message: 'App Settings',
                      child: GestureDetector(
                        onTap: () => _showAppSettings(context, ref),
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
              ),
            ],
          ),
        ),

        // COMMAND CENTER (30%)
        if (ref.watch(transportVisibleProvider))
          const Expanded(flex: 30, child: MidiTransportGrid(square: false)),

        // PERFORMANCE ZONE (70%)
        Expanded(
          flex: ref.watch(transportVisibleProvider) ? 70 : 100,
          child: PerformanceZone(key: _performanceZoneKey, isMobile: true),
        ),
      ],
    );
  }
}

// ===========================================================================
// UNIFIED LANDSCAPE LAYOUT
// ===========================================================================
class _LandscapeLayout extends ConsumerWidget {
  final bool isMobile;
  const _LandscapeLayout({required this.isMobile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faderOnRight =
        ref.watch(layoutHandProvider) == LayoutHand.faderOnRight;
    final isVisible = ref.watch(transportVisibleProvider);
    final size = MediaQuery.sizeOf(context);
    final panelWidth = size.width * (isMobile ? 0.38 : 0.40);

    return Column(
      children: [
        _buildLandscapeHeader(context, ref, isMobile),
        Expanded(
          child: Row(
            children: [
              if (faderOnRight)
                _buildAnimatedSidePanel(
                  context,
                  ref,
                  isVisible,
                  panelWidth,
                  faderOnRight,
                ),
              Expanded(
                child: PerformanceZone(
                  key: _performanceZoneKey,
                  isMobile: isMobile,
                ),
              ),
              if (!faderOnRight)
                _buildAnimatedSidePanel(
                  context,
                  ref,
                  isVisible,
                  panelWidth,
                  faderOnRight,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedSidePanel(
    BuildContext context,
    WidgetRef ref,
    bool isVisible,
    double panelWidth,
    bool faderOnRight,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: isVisible ? panelWidth : 0,
      decoration: const BoxDecoration(),
      clipBehavior: Clip.hardEdge,
      child: Visibility(
        visible: isVisible,
        maintainState: false,
        child: _buildCommandCenter(context, ref, faderOnRight),
      ),
    );
  }

  Widget _buildLandscapeHeader(
    BuildContext context,
    WidgetRef ref,
    bool isMobile,
  ) {
    final faderOnRight =
        ref.watch(layoutHandProvider) == LayoutHand.faderOnRight;
    final isVisible = ref.watch(transportVisibleProvider);

    return Container(
      color: const Color(0xFF111318),
      padding: EdgeInsets.fromLTRB(isMobile ? 12 : 24, 8, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // LEFT ZONE: Title
          Expanded(
            child: Row(
              children: [
                Text(
                  "OpenMIDIControl",
                  style: AppText.system(
                    color: const Color(0xFFA6C9F8),
                    fontWeight: FontWeight.w900,
                    fontSize: isMobile ? 18 : 24,
                  ),
                ),
              ],
            ),
          ),

          // RIGHT ZONE: Actions
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Transport Toggle Button
                _HeaderIconButton(
                  key: const ValueKey('transport_toggle_button_landscape'),
                  icon: isVisible
                      ? (faderOnRight
                            ? Icons.keyboard_double_arrow_left
                            : Icons.keyboard_double_arrow_right)
                      : (faderOnRight
                            ? Icons.keyboard_double_arrow_right
                            : Icons.keyboard_double_arrow_left),
                  tooltip: isVisible ? 'Hide Transport' : 'Show Transport',
                  onPressed: () =>
                      ref.read(transportVisibleProvider.notifier).toggle(),
                ),
                const SizedBox(width: 4),
                _HeaderIconButton(
                  icon: Icons.more_vert,
                  tooltip: 'App Settings',
                  onPressed: () => _showAppSettings(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandCenter(
    BuildContext context,
    WidgetRef ref,
    bool faderOnRight,
  ) {
    return Container(
      color: const Color(0xFF1A1C20),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: isMobile ? 8 : 16,
      ),
      child: const MidiTransportGrid(square: true),
    );
  }
}

// ===========================================================================
// MIDI TRANSPORT GRID
// ===========================================================================
class MidiTransportGrid extends StatelessWidget {
  const MidiTransportGrid({super.key, this.square = false});

  final bool square;

  @override
  Widget build(BuildContext context) {
    if (!square) {
      return Container(
        color: Colors.transparent,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: Row(
                  children: [
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
                  children: [
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
                  children: [
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
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final gridSize =
            constraints.hasBoundedWidth && constraints.hasBoundedHeight
            ? math.min(constraints.maxWidth, constraints.maxHeight)
            : constraints.maxWidth;

        return Container(
          color: Colors.transparent,
          child: Center(
            child: SizedBox(
              width: gridSize,
              height: gridSize,
              child: const Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: _GridButton(icon: Icons.fast_rewind),
                          ),
                        ),
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: _GridButton(
                              icon: Icons.keyboard_arrow_up,
                              bgColor: Color(0xFF282A2E),
                            ),
                          ),
                        ),
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: _GridButton(
                              icon: Icons.fiber_manual_record,
                              bgColor: Color(0xFFFFB59E),
                              iconColor: Color(0xFF690005),
                              isSolid: true,
                              shadowColor: Color(0xFFFFB59E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: _GridButton(
                              icon: Icons.keyboard_arrow_left,
                              bgColor: Color(0xFF282A2E),
                            ),
                          ),
                        ),
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: _GridButton(
                              icon: Icons.stop,
                              bgColor: Color(0xFF33353A),
                              iconColor: Colors.white,
                            ),
                          ),
                        ),
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: _GridButton(
                              icon: Icons.keyboard_arrow_right,
                              bgColor: Color(0xFF282A2E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: _GridButton(icon: Icons.fast_forward),
                          ),
                        ),
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: _GridButton(
                              icon: Icons.keyboard_arrow_down,
                              bgColor: Color(0xFF282A2E),
                            ),
                          ),
                        ),
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: _GridButton(
                              icon: Icons.play_arrow,
                              bgColor: Color(0xFFA6C9F8),
                              iconColor: Color(0xFF033258),
                              isSolid: true,
                              shadowColor: Color(0xFFA6C9F8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _HeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, color: const Color(0xFFA6C9F8), size: 20),
        ),
      ),
    );
  }
}

// ===========================================================================
// SHARED WIDGETS
// ===========================================================================

class DynamicConnectionIsland extends ConsumerStatefulWidget {
  const DynamicConnectionIsland({super.key});

  @override
  ConsumerState<DynamicConnectionIsland> createState() =>
      _DynamicConnectionIslandState();
}

class _DynamicConnectionIslandState
    extends ConsumerState<DynamicConnectionIsland> {
  bool _isExpanded = false;
  Timer? _collapseTimer;

  @override
  void initState() {
    super.initState();
    // Start expanded briefly to show status, then collapse
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _expandTemporarily();
    });
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
  }

  void _expandTemporarily() {
    if (!mounted) return;
    setState(() => _isExpanded = true);
    _collapseTimer?.cancel();
    _collapseTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isExpanded = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final midiStatus = ref.watch(midiStatusProvider);

    // Auto-expand on status change
    ref.listen(midiStatusProvider, (previous, next) {
      if (previous != next) {
        _expandTemporarily();
      }
    });

    final (statusText, statusColor) = switch (midiStatus) {
      MidiStatus.usbActive => ("USB PERIPHERAL READY", const Color(0xFF4DD0E1)),
      MidiStatus.usbHostAwaitingPort => (
        "USB HOST DETECTED",
        const Color(0xFF9575CD),
      ),
      MidiStatus.usbHostConnected => (
        "USB HOST ACTIVE",
        const Color(0xFF66BB6A),
      ),
      MidiStatus.connected => ("DEVICE CONNECTED", const Color(0xFF42A5F5)),
      MidiStatus.available => ("MIDI READY", const Color(0xFFFFCA28)),
      MidiStatus.connectionLost => ("CONNECTION LOST", const Color(0xFFE57373)),
      MidiStatus.disconnected => ("DISCONNECTED", const Color(0xFFBDBDBD)),
    };

    return ConfigGestureWrapper(
      key: const ValueKey('connection_status_island'),
      id: 'connection_status_island',
      // Step 1: Double-tap and hold to expand when collapsed
      onConfigRequested: !_isExpanded ? () => _expandTemporarily() : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // Step 2: Regular tap to navigate only when already expanded
          if (_isExpanded) {
            _showMidiSettings(context, ref);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          height: 36,
          // Finite constraints for smooth lerp
          constraints: BoxConstraints(
            minWidth: 36,
            maxWidth: _isExpanded ? 500 : 36,
          ),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFF1E2024),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer scroll view suppresses overflow errors for the whole row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                clipBehavior: Clip.none,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: _isExpanded ? 16 : 10.5,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // The Dot
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      // Expansion Spacer
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOutCubic,
                        width: _isExpanded ? 12 : 0,
                      ),
                      // Expanded content
                      AnimatedOpacity(
                        opacity: _isExpanded ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOutCubic,
                          constraints: BoxConstraints(
                            maxWidth: _isExpanded ? 400 : 0,
                          ),
                          // Inner scroll view suppresses overflow errors for the text row
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const NeverScrollableScrollPhysics(),
                            clipBehavior: Clip.none,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  statusText,
                                  style: AppText.system(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                  maxLines: 1,
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.settings_ethernet,
                                  color: statusColor.withValues(alpha: 0.7),
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final baseSize = constraints.smallest.shortestSide;
        final iconSize = isSolid ? baseSize * 0.38 : baseSize * 0.30;

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
            child: Icon(
              icon,
              color: iconColor,
              size: iconSize.clamp(35.0, 50.0),
            ),
          ),
        );
      },
    );
  }
}

class PerformanceZone extends ConsumerStatefulWidget {
  final bool isMobile;
  const PerformanceZone({super.key, this.isMobile = false});

  @override
  ConsumerState<PerformanceZone> createState() => _PerformanceZoneState();
}

class _PerformanceZoneState extends ConsumerState<PerformanceZone> {
  @override
  Widget build(BuildContext context) {
    final currentPage = ref.watch(
      layoutStateProvider.select((s) => s.activePageIndex),
    );
    final pages = ref.watch(layoutStateProvider.select((s) => s.pages));
    final isLocked = ref.watch(
      layoutStateProvider.select((s) => s.isPerformanceLocked),
    );

    return Column(
      children: [
        // Page Tab Bar with integrated progress
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Row(
              children: [
                _buildLockButton(isLocked),
                // Dynamically render tabs from layout schema
                for (int i = 0; i < pages.length; i++)
                  _buildTabButton(i, pages[i].name, currentPage),
              ],
            ),
            const GlobalConfigProgressBar(),
          ],
        ),
        // Performance Panels
        Expanded(
          child: IndexedStack(
            index: currentPage,
            children: [
              // Page 0: Dual Faders
              Row(
                key: const ValueKey('page_faders'),
                children: [
                  Expanded(
                    child: HybridTouchFader(
                      key: const ValueKey('fader_cc1'),
                      controlId: 'fader_0',
                      ccNumber: 1,
                      displayName: "CC1\nDYNAMICS",
                      activeColor: const Color(0xFFA6C9F8),
                      labelColor: const Color(0xFF033258),
                      initialValue: 1.0,
                      isMobile: widget.isMobile,
                      behavior: ref.watch(faderBehaviorProvider),
                    ),
                  ),
                  Expanded(
                    child: HybridTouchFader(
                      key: const ValueKey('fader_cc11'),
                      controlId: 'fader_1',
                      ccNumber: 11,
                      displayName: "CC11\nEXPRESSION",
                      activeColor: const Color(0xFFA1CFCE),
                      labelColor: const Color(0xFF013737),
                      initialValue: 64 / 127.0,
                      isMobile: widget.isMobile,
                      behavior: ref.watch(faderBehaviorProvider),
                    ),
                  ),
                ],
              ),

              // Page 1: Single High-Precision XY Pad
              const Padding(
                key: ValueKey('page_xy'),
                padding: EdgeInsets.all(16),
                child: HybridXYPad(id: "xy_main", ccX: 1, ccY: 11),
              ),

              // Page 2: Drum Grid Panel
              const DrumGridPanel(key: ValueKey('page_drums')),

              // Page 3: Utility Grid Panel
              const UtilityGridPanel(key: ValueKey('page_utility')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLockButton(bool isLocked) {
    return GestureDetector(
      onTap: () {
        ref.read(layoutStateProvider.notifier).togglePerformanceLock();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: const BoxDecoration(color: Color(0xFF1A1C20)),
        child: Icon(
          isLocked ? Icons.lock : Icons.lock_open,
          color: isLocked ? Colors.redAccent : Colors.white54,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label, int currentPage) {
    final isActive = currentPage == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          ref.read(layoutStateProvider.notifier).setPageIndex(index);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFEBC351) : const Color(0xFF212327),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: isActive ? const Color(0xFF212327) : Colors.white54,
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// GLOBAL CONFIG PROGRESS BAR
// ===========================================================================

class GlobalConfigProgressBar extends ConsumerWidget {
  const GlobalConfigProgressBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(configProgressProvider);

    if (progress <= 0) return const SizedBox.shrink();

    return Container(
      height: 3,
      width: double.infinity,
      color: Colors.transparent,
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: progress,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF9575CD), // Purple
                Color(0xFFEBC351), // Gold
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// DEVICE OFFLINE OVERLAY
// ===========================================================================

class DeviceOfflineOverlay extends ConsumerWidget {
  const DeviceOfflineOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnectionLost = ref.watch(
      connectedMidiDeviceProvider.select((s) => s.isConnectionLost),
    );

    if (!isConnectionLost) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () =>
          ref.read(connectedMidiDeviceProvider.notifier).clearConnectionLost(),
      child: Container(
        color: Colors.black.withValues(alpha: 0.8),
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: GestureDetector(
              onTap:
                  () {}, // Consume tap to prevent background dismissal when touching the content
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2024),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha: 0.2),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.usb_off_rounded,
                      color: Colors.redAccent,
                      size: 80,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "DEVICE OFFLINE",
                      style: AppText.performance(
                        color: Colors.redAccent,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Connection was physically lost. Please reconnect the hardware to continue.",
                      textAlign: TextAlign.center,
                      style: AppText.system(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white60,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => ref
                                .read(connectedMidiDeviceProvider.notifier)
                                .clearConnectionLost(),
                            child: const Text(
                              "DISMISS",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              ref
                                  .read(connectedMidiDeviceProvider.notifier)
                                  .disconnect();
                              ref.invalidate(midiDevicesProvider);
                            },
                            child: const Text(
                              "RESET PORTS",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SETTINGS FLYOUT (Landscape)
// ---------------------------------------------------------------------------
class _SidePanelOverlay extends ConsumerWidget {
  const _SidePanelOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final panelState = ref.watch(sidePanelProvider);
    final panelType = panelState.type;
    final isVisible = panelType != SidePanelType.none;
    final isLeft = panelState.side == SidePanelSide.left;

    return Stack(
      children: [
        // Scrim
        AnimatedOpacity(
          opacity: isVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: IgnorePointer(
            ignoring: !isVisible,
            child: GestureDetector(
              key: const ValueKey('side_panel_scrim'),
              onTap: () => ref.read(sidePanelProvider.notifier).hide(),
              child: Container(color: Colors.black54),
            ),
          ),
        ),

        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          left: isLeft ? (isVisible ? 0 : -450) : null,
          right: !isLeft ? (isVisible ? 0 : -450) : null,
          top: 0,
          bottom: 0,
          child: Container(
            width: 450,
            decoration: BoxDecoration(
              color: const Color(0xFF111318),
              boxShadow: [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 40,
                  offset: Offset(isLeft ? 10 : -10, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Content - Screens handle their own headers/AppBars
                Expanded(
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      // Ensure AppBars look consistent in the panel
                      appBarTheme: AppBarTheme(
                        backgroundColor: const Color(0xFF1E2024),
                        elevation: 0,
                        titleTextStyle: AppText.system(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    child: _buildPanelContent(panelType),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPanelContent(SidePanelType type) {
    switch (type) {
      case SidePanelType.appSettings:
        return const SettingsScreen();
      case SidePanelType.midiSettings:
        return const MidiSettingsScreen();
      case SidePanelType.none:
        return const SizedBox.shrink();
    }
  }
}
