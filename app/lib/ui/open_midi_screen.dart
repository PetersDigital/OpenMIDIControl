import 'panels/utility_grid_panel.dart';
// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/hybrid_xy_pad.dart';
import 'panels/drum_grid_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hybrid_touch_fader.dart';
import 'midi_service.dart';
import 'settings_screen.dart';
import 'midi_settings_screen.dart';
import 'providers/config_ui_provider.dart';
import 'design_system.dart';
import 'layout_state.dart';

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
class OpenMIDIMainScreen extends ConsumerStatefulWidget {
  const OpenMIDIMainScreen({super.key});

  @override
  ConsumerState<OpenMIDIMainScreen> createState() => _OpenMIDIMainScreenState();
}

class _OpenMIDIMainScreenState extends ConsumerState<OpenMIDIMainScreen> {
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
    final size = MediaQuery.sizeOf(context);

    final isLandscape = orientation == Orientation.landscape;
    final isTablet = size.shortestSide >= 600;

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
                    message: 'Toggle Transport',
                    child: GestureDetector(
                      key: const ValueKey('transport_toggle_button'),
                      onTap: () =>
                          ref.read(transportVisibleProvider.notifier).toggle(),
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
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      ref.watch(layoutStateProvider).isPerformanceLocked
                          ? Icons.lock
                          : Icons.lock_open,
                      color: ref.watch(layoutStateProvider).isPerformanceLocked
                          ? Colors.redAccent
                          : Colors.white,
                    ),
                    tooltip: 'Lock Performance Interface',
                    onPressed: () => ref
                        .read(layoutStateProvider.notifier)
                        .togglePerformanceLock(),
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
            maintainState: true,
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
          _ConnectionStatusButton(onTap: () => _showMidiSettings(context)),
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
              ref.watch(layoutStateProvider).isPerformanceLocked
                  ? Icons.lock
                  : Icons.lock_open,
              color: ref.watch(layoutStateProvider).isPerformanceLocked
                  ? Colors.redAccent
                  : Colors.white,
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
              onPressed: () => _showAppSettings(context),
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
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Toggle Transport',
                      child: IconButton(
                        key: const ValueKey('transport_toggle_button'),
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
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        ref.watch(layoutStateProvider).isPerformanceLocked
                            ? Icons.lock
                            : Icons.lock_open,
                        color:
                            ref.watch(layoutStateProvider).isPerformanceLocked
                            ? Colors.redAccent
                            : Colors.white,
                        size: 20,
                      ),
                      tooltip: 'Lock Performance Interface',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => ref
                          .read(layoutStateProvider.notifier)
                          .togglePerformanceLock(),
                    ),
                    const SizedBox(width: 8),
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

    return Stack(
      children: [
        // Always 100% performance zone
        PerformanceZone(key: _performanceZoneKey, isMobile: false),

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
            maintainState: true,
            child: _buildCommandCenter(context, ref, faderOnRight),
          ),
        ),

        // Floating Toggle (only visible when panel is hidden)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          top: 24,
          left: faderOnRight ? (isVisible ? -300 : 24) : null,
          right: !faderOnRight ? (isVisible ? -300 : 24) : null,
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2024).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ConnectionStatusButton(onTap: () => _showMidiSettings(context)),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Toggle Transport',
            child: IconButton(
              key: const ValueKey('transport_toggle_button_floating'),
              icon: Icon(
                faderOnRight
                    ? Icons.keyboard_double_arrow_right
                    : Icons.keyboard_double_arrow_left,
                color: const Color(0xFFA6C9F8),
                size: 28,
              ),
              onPressed: () =>
                  ref.read(transportVisibleProvider.notifier).toggle(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              ref.watch(layoutStateProvider).isPerformanceLocked
                  ? Icons.lock
                  : Icons.lock_open,
              color: ref.watch(layoutStateProvider).isPerformanceLocked
                  ? Colors.redAccent
                  : Colors.white,
              size: 28,
            ),
            tooltip: 'Lock Performance Interface',
            onPressed: () =>
                ref.read(layoutStateProvider.notifier).togglePerformanceLock(),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'App Settings',
            child: IconButton(
              key: const ValueKey('desktop_floating_app_settings'),
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
    );
  }

  Widget _buildCommandCenter(
    BuildContext context,
    WidgetRef ref,
    bool faderOnRight,
  ) {
    return Container(
      color: const Color(0xFF1A1C20),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: 400,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTransportButton(Icons.skip_previous, () {}),
                  _buildTransportButton(Icons.stop, () {}),
                  _buildTransportButton(
                    Icons.play_arrow,
                    () {},
                    isPrimary: true,
                  ),
                  _buildTransportButton(Icons.pause, () {}),
                  _buildTransportButton(Icons.skip_next, () {}),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                const SizedBox(width: 24),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ConnectionStatusButton(
                      onTap: () => _showMidiSettings(context),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Toggle Transport',
                      child: IconButton(
                        key: const ValueKey('transport_toggle_button_panel'),
                        icon: Icon(
                          faderOnRight
                              ? Icons.keyboard_double_arrow_left
                              : Icons.keyboard_double_arrow_right,
                          color: const Color(0xFFA6C9F8),
                        ),
                        onPressed: () {
                          ref.read(transportVisibleProvider.notifier).toggle();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        ref.watch(layoutStateProvider).isPerformanceLocked
                            ? Icons.lock
                            : Icons.lock_open,
                        color:
                            ref.watch(layoutStateProvider).isPerformanceLocked
                            ? Colors.redAccent
                            : Colors.white,
                      ),
                      tooltip: 'Lock Performance Interface',
                      onPressed: () => ref
                          .read(layoutStateProvider.notifier)
                          .togglePerformanceLock(),
                    ),
                    const SizedBox(width: 8),
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
            child: Text(
              "01 - Cinematic Violins",
              style: AppText.performance(
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

  Widget _buildTransportButton(
    IconData icon,
    VoidCallback onPressed, {
    bool isPrimary = false,
  }) {
    return IconButton(
      icon: Icon(
        icon,
        color: isPrimary ? const Color(0xFFA6C9F8) : const Color(0xFFC3C7CA),
        size: isPrimary ? 48 : 32,
      ),
      onPressed: onPressed,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: statusColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            statusText,
            style: AppText.system(
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
    final layoutState = ref.watch(layoutStateProvider);
    final currentPage = layoutState.activePageIndex;

    return Column(
      children: [
        // Page Tab Bar with integrated progress
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Row(
              children: [
                // Dynamically render tabs from layout schema
                for (int i = 0; i < layoutState.pages.length; i++)
                  _buildTabButton(i, layoutState.pages[i].name, currentPage),
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
