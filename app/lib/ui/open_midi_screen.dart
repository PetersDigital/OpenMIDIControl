// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
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

// ---------------------------------------------------------------------------
// State: Performance Page (Fader, XY, Pads, Utility)
// ---------------------------------------------------------------------------
class PerformancePageIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setPage(int index) => state = index;
}

final performancePageIndexProvider =
    NotifierProvider<PerformancePageIndexNotifier, int>(
      PerformancePageIndexNotifier.new,
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

class _OpenMIDIMainScreenState extends ConsumerState<OpenMIDIMainScreen> {
  Orientation? _lastOrientation;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
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

    // Auto-toggle transport based on orientation
    if (_lastOrientation != orientation) {
      _lastOrientation = orientation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (orientation == Orientation.landscape) {
            ref.read(transportVisibleProvider.notifier).setVisible(true);
          } else {
            ref.read(transportVisibleProvider.notifier).setVisible(false);
          }
        }
      });
    }

    final size = MediaQuery.sizeOf(context);

    final isLandscape = orientation == Orientation.landscape;
    final isTablet = size.shortestSide >= 600;

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
            const DeviceOfflineOverlay(),
            if (isLandscape) const _SidePanelOverlay(),
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
    final isLocked = ref.watch(
      layoutStateProvider.select((s) => s.isPerformanceLocked),
    );

    return Column(
      children: [
        // Top bar
        Container(
          height: 64,
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(
                Icons.settings_input_component,
                color: Color(0xFFA6C9F8),
                size: 26,
              ),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ConnectionStatusButton(
                      onTap: () => _showMidiSettings(context, ref),
                    ),
                    const SizedBox(width: 4),
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
                    IconButton(
                      icon: Icon(
                        isLocked ? Icons.lock : Icons.lock_open,
                        color: isLocked ? Colors.redAccent : Colors.white,
                      ),
                      tooltip: 'Lock Performance Interface',
                      onPressed: () => ref
                          .read(layoutStateProvider.notifier)
                          .togglePerformanceLock(),
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
                          child: _StatusDisplay(
                            label: "TEMPO",
                            value: "120 BPM",
                          ),
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
          flex: ref.watch(transportVisibleProvider) ? 70 : 100,
          child: PerformanceZone(key: _performanceZoneKey, isMobile: true),
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
    final isVisible = ref.watch(transportVisibleProvider);
    final size = MediaQuery.sizeOf(context);
    final panelWidth = size.width * 0.38;

    return Stack(
      children: [
        // Always 100% fader zone
        _buildPerformanceZone(ref),

        // Sliding Command Center
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          top: 0,
          bottom: 0,
          left: faderOnRight ? (isVisible ? 0 : -panelWidth) : null,
          right: !faderOnRight ? (isVisible ? 0 : -panelWidth) : null,
          width: panelWidth,
          child: Visibility(
            visible: isVisible,
            maintainState: false,
            child: _buildCommandCenter(context, ref, faderOnRight),
          ),
        ),

        // Floating Toggle (only visible when panel is hidden)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          top: 12,
          left: faderOnRight ? (isVisible ? -300 : 12) : null,
          right: !faderOnRight ? (isVisible ? -300 : 12) : null,
          child: AnimatedOpacity(
            opacity: isVisible ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: isVisible,
              child: _buildFloatingControls(context, ref, faderOnRight),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingControls(
    BuildContext context,
    WidgetRef ref,
    bool faderOnRight,
  ) {
    final isLocked = ref.watch(
      layoutStateProvider.select((s) => s.isPerformanceLocked),
    );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2024).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ConnectionStatusButton(onTap: () => _showMidiSettings(context, ref)),
          Tooltip(
            message: 'Toggle Transport',
            child: IconButton(
              key: const ValueKey('transport_toggle_button_floating'),
              icon: Icon(
                faderOnRight
                    ? Icons.keyboard_double_arrow_right
                    : Icons.keyboard_double_arrow_left,
                color: const Color(0xFFA6C9F8),
                size: 20,
              ),
              onPressed: () {
                ref.read(transportVisibleProvider.notifier).toggle();
              },
            ),
          ),
          IconButton(
            icon: Icon(
              isLocked ? Icons.lock : Icons.lock_open,
              color: isLocked ? Colors.redAccent : Colors.white,
              size: 20,
            ),
            tooltip: 'Lock Performance Interface',
            onPressed: () =>
                ref.read(layoutStateProvider.notifier).togglePerformanceLock(),
          ),
          Tooltip(
            message: 'App Settings',
            child: IconButton(
              key: const ValueKey('floating_app_settings'),
              icon: const Icon(
                Icons.more_vert,
                color: Color(0xFFC3C7CA),
                size: 20,
              ),
              onPressed: () => _showAppSettings(context, ref),
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
    final isLocked = ref.watch(
      layoutStateProvider.select((s) => s.isPerformanceLocked),
    );

    return Container(
      color: const Color(0xFF1E2024),
      child: Column(
        children: [
          // Compact Header Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(
                  Icons.settings_input_component,
                  color: Color(0xFFA6C9F8),
                  size: 20,
                ),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: _ConnectionStatusButton(
                          onTap: () => _showMidiSettings(context, ref),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: 'Toggle Transport',
                        child: IconButton(
                          key: const ValueKey('transport_toggle_button_panel'),
                          icon: Icon(
                            faderOnRight
                                ? Icons.keyboard_double_arrow_left
                                : Icons.keyboard_double_arrow_right,
                            color: const Color(0xFFC3C7CA),
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => ref
                              .read(transportVisibleProvider.notifier)
                              .toggle(),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(
                          isLocked ? Icons.lock : Icons.lock_open,
                          color: isLocked ? Colors.redAccent : Colors.white,
                          size: 20,
                        ),
                        tooltip: 'Lock Performance Interface',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => ref
                            .read(layoutStateProvider.notifier)
                            .togglePerformanceLock(),
                      ),
                      const SizedBox(width: 4),
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
                          onPressed: () => _showAppSettings(context, ref),
                        ),
                      ),
                    ],
                  ),
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
    return PerformanceZone(key: _performanceZoneKey, isMobile: true);
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
    final isVisible = ref.watch(transportVisibleProvider);
    final size = MediaQuery.sizeOf(context);
    final panelWidth = size.width * 0.40;

    return Column(
      children: [
        _buildLandscapeHeader(context, ref),
        Expanded(
          child: Row(
            children: [
              if (faderOnRight)
                AnimatedContainer(
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
                ),
              Expanded(
                child: PerformanceZone(
                  key: _performanceZoneKey,
                  isMobile: false,
                ),
              ),
              if (!faderOnRight)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  width: isVisible ? panelWidth : 0,
                  decoration: const BoxDecoration(),
                  clipBehavior: Clip.hardEdge,
                  child: Visibility(
                    visible: isVisible,
                    maintainState: true,
                    child: _buildCommandCenter(context, ref, faderOnRight),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeHeader(BuildContext context, WidgetRef ref) {
    final faderOnRight =
        ref.watch(layoutHandProvider) == LayoutHand.faderOnRight;
    final isVisible = ref.watch(transportVisibleProvider);
    final isLocked = ref.watch(
      layoutStateProvider.select((s) => s.isPerformanceLocked),
    );

    return Container(
      color: const Color(0xFF111318),
      padding: const EdgeInsets.fromLTRB(24, 8, 16, 8),
      child: Row(
        children: [
          Text(
            "OPENMIDI",
            style: AppText.performance(
              color: const Color(0xFFA6C9F8),
              fontWeight: FontWeight.w900,
              fontSize: 24,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          _ConnectionStatusButton(onTap: () => _showMidiSettings(context, ref)),
          const SizedBox(width: 8),
          // Transport Toggle Button
          Tooltip(
            message: isVisible ? 'Hide Transport' : 'Show Transport',
            child: IconButton(
              key: const ValueKey('transport_toggle_button_desktop'),
              icon: Icon(
                isVisible
                    ? (faderOnRight
                          ? Icons.keyboard_double_arrow_left
                          : Icons.keyboard_double_arrow_right)
                    : (faderOnRight
                          ? Icons.keyboard_double_arrow_right
                          : Icons.keyboard_double_arrow_left),
                color: const Color(0xFFA6C9F8),
              ),
              onPressed: () {
                ref.read(transportVisibleProvider.notifier).toggle();
              },
            ),
          ),
          const SizedBox(width: 8),
          // Lock/Unlock Button
          IconButton(
            icon: Icon(
              isLocked ? Icons.lock : Icons.lock_open,
              color: isLocked ? Colors.redAccent : const Color(0xFFA6C9F8),
            ),
            tooltip: 'Lock Performance Interface',
            onPressed: () {
              ref.read(layoutStateProvider.notifier).togglePerformanceLock();
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Color(0xFFC3C7CA)),
            onPressed: () => _showAppSettings(context, ref),
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
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status displays

              // Status displays
              Row(
                children: const [
                  Expanded(
                    child: _StatusDisplay(label: "TEMPO", value: "120 BPM"),
                  ),
                  Expanded(
                    child: _StatusDisplay(
                      label: "TIMECODE",
                      value: "001:01:000",
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Track name
              SizedBox(
                width: double.infinity,
                child: Text(
                  "01 - Cinematic Violins",
                  style: AppText.performance(
                    color: const Color(0xFFA6C9F8),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),

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
    );
  }
}

// ===========================================================================
// SHARED WIDGETS
// ===========================================================================

class _ConnectionStatusButton extends ConsumerWidget {
  final VoidCallback onTap;

  const _ConnectionStatusButton({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final midiStatus = ref.watch(midiStatusProvider);

    final (statusText, statusColor) = switch (midiStatus) {
      MidiStatus.usbActive => (
        "USB PERIPHERAL READY",
        const Color(0xFF4DD0E1), // Cyan
      ),
      MidiStatus.usbHostAwaitingPort => (
        "USB HOST DETECTED",
        const Color(0xFF9575CD), // Purple
      ),
      MidiStatus.usbHostConnected => (
        "USB HOST ACTIVE",
        const Color(0xFF66BB6A), // Green
      ),
      MidiStatus.connected => (
        "DEVICE CONNECTED",
        const Color(0xFF42A5F5), // Blue
      ),
      MidiStatus.available => (
        "MIDI READY",
        const Color(0xFFFFCA28), // Amber
      ),
      MidiStatus.connectionLost => (
        "CONNECTION LOST",
        const Color(0xFFE57373), // Red
      ),
      MidiStatus.disconnected => (
        "DISCONNECTED",
        const Color(0xFFBDBDBD), // Grey
      ),
    };

    final buttonContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: statusColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              statusText,
              style: AppText.system(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );

    return Tooltip(
      key: const ValueKey('connection_status_button'),
      message: 'MIDI Connection Settings',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: buttonContent,
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
          style: AppText.system(
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
            style: AppText.performance(
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

    return Column(
      children: [
        // Page Tab Bar with integrated progress
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Row(
              children: [
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
