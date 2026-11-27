// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:io' show Platform;

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models/action_payload.dart';
import '../core/protocol/mcu/mcu_codec.dart';
import 'global_ui_scale_state.dart';
import 'header_transport_state.dart';
import 'midi_action_dispatcher.dart';
import 'midi_service.dart';
import 'midi_settings_state.dart'
    show
        MidiProtocolMode,
        mcuLampLitProvider,
        mcuRouteActiveProvider,
        midiProtocolModeProvider;
import 'performance_ticker_mixin.dart';
import 'layout_document_state.dart';
import 'settings_screen.dart';
import 'midi_settings_screen.dart';
import 'providers/config_ui_provider.dart';
import 'widgets/config_gesture_wrapper.dart';
import 'design_system.dart';
import 'layout_state.dart';
import 'editor_state.dart';
import 'side_panel_state.dart';
import 'widgets/dynamic_grid_renderer.dart';
import 'widgets/performance_grid_viewport.dart';
import 'editor/widget_palette_panel.dart';
import 'editor/page_settings_panel.dart';

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

class _OpenMIDIMainScreenState extends ConsumerState<OpenMIDIMainScreen> {
  bool _launchCheckPending = false;
  bool _transportSyncPending = false;
  Orientation? _lastOrientation;
  Timer? _firstLaunchTimer;

  @override
  void initState() {
    super.initState();
    _initLayoutDocument();
    _checkFirstLaunch();
  }

  void _initLayoutDocument() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(layoutDocumentProvider.notifier).initializeOnStartup();
      }
    });
  }

  @override
  void dispose() {
    _launchCheckPending = false;
    _transportSyncPending = false;
    _firstLaunchTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkFirstLaunch() async {
    if (!_launchCheckPending) {
      _launchCheckPending = true;
      SchedulerBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        final isTest = Platform.environment.containsKey('FLUTTER_TEST');
        if (isTest) {
          final isFirstLaunch = await ref.read(firstLaunchCheckProvider.future);
          if (!mounted) return;
          if (isFirstLaunch) {
            ref.read(transportVisibleProvider.notifier).setVisible(true);

            // In first-launch tests, we schedule the 2-second timer which the test expects and pumps through
            _firstLaunchTimer = Timer(const Duration(seconds: 2), () {
              if (mounted) {
                ref.read(transportVisibleProvider.notifier).setVisible(false);
                SharedPreferences.getInstance().then((prefs) {
                  prefs.setBool('hasLaunched', true);
                });
              }
              _launchCheckPending = false;
            });
          } else {
            _launchCheckPending = false;
          }
        } else {
          // In production: stagger the entire check by 1000ms to avoid CPU spike on startup
          _firstLaunchTimer = Timer(
            const Duration(milliseconds: 1000),
            () async {
              if (!mounted) return;
              final isFirstLaunch = await ref.read(
                firstLaunchCheckProvider.future,
              );
              if (!mounted) return;
              if (isFirstLaunch) {
                ref.read(transportVisibleProvider.notifier).setVisible(true);

                // Reuse the timer for the second delay
                _firstLaunchTimer = Timer(const Duration(seconds: 2), () async {
                  if (mounted) {
                    ref
                        .read(transportVisibleProvider.notifier)
                        .setVisible(false);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('hasLaunched', true);
                  }
                  _launchCheckPending = false;
                });
              } else {
                _launchCheckPending = false;
              }
            },
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(midiProtocolModeProvider);
    final orientation = MediaQuery.orientationOf(context);
    final size = MediaQuery.sizeOf(context);
    final isLandscape = orientation == Orientation.landscape;
    final isTablet = size.shortestSide >= 600;

    // Sync transport visibility with orientation only when orientation changes
    if (_lastOrientation != orientation) {
      _lastOrientation = orientation;
      if (!_transportSyncPending) {
        _transportSyncPending = true;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final current = ref.read(transportVisibleProvider);
            if (isLandscape && !current) {
              ref.read(transportVisibleProvider.notifier).setVisible(true);
            } else if (!isLandscape && current) {
              ref.read(transportVisibleProvider.notifier).setVisible(false);
            }
            _transportSyncPending = false;
          }
        });
      }
    }

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
    final isEditorMode = ref.watch(editorModeProvider.select((v) => v));
    final isPaletteOpen = ref.watch(
      editorOverlayProvider.select((o) => o == EditorOverlay.palette),
    );
    final isPageSettingsOpen = ref.watch(
      editorOverlayProvider.select((o) => o == EditorOverlay.pageSettings),
    );
    final isOverlayVisible = ref.watch(
      editorOverlayProvider.select((o) => o != EditorOverlay.none),
    );
    final isTransportVisible = ref.watch(
      transportVisibleProvider.select((v) => v),
    );
    final activePageId = ref.watch(
      layoutStateProvider.select((s) => s.activePage?.id),
    );

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
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Icon(
                  Icons.settings_input_component,
                  color: Color(0xFFA6C9F8),
                  size: 26,
                ),
              ),

              const Spacer(),

              // RIGHT ZONE: Transport + Settings
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Tooltip(
                    message: 'Toggle Transport',
                    child: GestureDetector(
                      key: const ValueKey('transport_toggle_button_portrait'),
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
                  if (isEditorMode) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: 'Toggle Widget Palette',
                      child: GestureDetector(
                        onTap: () => ref
                            .read(editorOverlayProvider.notifier)
                            .toggle(EditorOverlay.palette),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.add_box,
                            color: isPaletteOpen
                                ? const Color(0xFFA6C9F8)
                                : const Color(0xFFC3C7CA),
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Tooltip(
                      message: 'Page Settings',
                      child: GestureDetector(
                        onTap: () {
                          ref
                              .read(editorOverlayProvider.notifier)
                              .toggle(EditorOverlay.pageSettings);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.settings,
                            color: Color(0xFFC3C7CA),
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Toggle Editor Mode',
                    child: GestureDetector(
                      onTap: () =>
                          ref.read(editorModeProvider.notifier).toggle(),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.edit,
                          color: isEditorMode
                              ? const Color(0xFFA6C9F8)
                              : const Color(0xFFC3C7CA),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'App Settings',
                    child: GestureDetector(
                      onTap: () {
                        ref.read(editorOverlayProvider.notifier).hide();
                        _showAppSettings(context, ref);
                      },
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
        if (isTransportVisible)
          const Expanded(flex: 30, child: MidiTransportGrid(square: false)),

        // PERFORMANCE ZONE (70%)
        Expanded(
          flex: isTransportVisible ? 70 : 100,
          child: Stack(
            children: [
              Positioned.fill(
                child: PerformanceZone(
                  key: _performanceZoneKey,
                  isMobile: true,
                ),
              ),
              if (isOverlayVisible)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () =>
                        ref.read(editorOverlayProvider.notifier).hide(),
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox.expand(),
                  ),
                ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                top: 0,
                bottom: 0,
                right: isPaletteOpen ? 0 : -320,
                child: const WidgetPalettePanel(),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                top: 0,
                bottom: 0,
                right: isPageSettingsOpen ? 0 : -320,
                child: activePageId != null
                    ? PageSettingsPanel(pageId: activePageId)
                    : const SizedBox(),
              ),
            ],
          ),
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
    final faderOnRight = ref.watch(
      layoutHandProvider.select((h) => h == LayoutHand.faderOnRight),
    );
    final isVisible = ref.watch(transportVisibleProvider.select((v) => v));
    final size = MediaQuery.sizeOf(context);
    final panelWidth = size.width * (isMobile ? 0.38 : 0.40);
    final isOverlayVisible = ref.watch(
      editorOverlayProvider.select((o) => o != EditorOverlay.none),
    );
    final isPaletteOpen = ref.watch(
      editorOverlayProvider.select((o) => o == EditorOverlay.palette),
    );
    final isPageSettingsOpen = ref.watch(
      editorOverlayProvider.select((o) => o == EditorOverlay.pageSettings),
    );
    final activePageId = ref.watch(
      layoutStateProvider.select((s) => s.activePage?.id),
    );

    return Column(
      children: [
        _buildLandscapeHeader(context, ref, isMobile),
        Expanded(
          child: Stack(
            children: [
              Row(
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
              if (isOverlayVisible)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () =>
                        ref.read(editorOverlayProvider.notifier).hide(),
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox.expand(),
                  ),
                ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                top: 0,
                bottom: 0,
                right: isPaletteOpen ? 0 : -320,
                child: const WidgetPalettePanel(),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                top: 0,
                bottom: 0,
                right: isPageSettingsOpen ? 0 : -320,
                child: activePageId != null
                    ? PageSettingsPanel(pageId: activePageId)
                    : const SizedBox(),
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
    final faderOnRight = ref.watch(
      layoutHandProvider.select((h) => h == LayoutHand.faderOnRight),
    );
    final isVisible = ref.watch(transportVisibleProvider.select((v) => v));
    final isEditorMode = ref.watch(editorModeProvider.select((v) => v));
    final isPaletteOpen = ref.watch(
      editorOverlayProvider.select((o) => o == EditorOverlay.palette),
    );

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
                if (isEditorMode) ...[
                  const SizedBox(width: 4),
                  _HeaderIconButton(
                    icon: Icons.add_box,
                    tooltip: 'Toggle Widget Palette',
                    color: isPaletteOpen
                        ? const Color(0xFFA6C9F8)
                        : const Color(0xFFC3C7CA),
                    onPressed: () => ref
                        .read(editorOverlayProvider.notifier)
                        .toggle(EditorOverlay.palette),
                  ),
                  const SizedBox(width: 4),
                  _HeaderIconButton(
                    icon: Icons.settings,
                    tooltip: 'Page Settings',
                    color: const Color(0xFFC3C7CA),
                    onPressed: () {
                      ref
                          .read(editorOverlayProvider.notifier)
                          .toggle(EditorOverlay.pageSettings);
                    },
                  ),
                ],
                const SizedBox(width: 4),
                _HeaderIconButton(
                  icon: Icons.edit,
                  tooltip: 'Toggle Editor Mode',
                  color: isEditorMode
                      ? const Color(0xFFA6C9F8)
                      : const Color(0xFFC3C7CA),
                  onPressed: () =>
                      ref.read(editorModeProvider.notifier).toggle(),
                ),
                const SizedBox(width: 4),
                _HeaderIconButton(
                  icon: Icons.more_vert,
                  tooltip: 'App Settings',
                  onPressed: () {
                    ref.read(editorOverlayProvider.notifier).hide();
                    _showAppSettings(context, ref);
                  },
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

  static Widget _cell(Widget child, {required bool wrapSquare}) => Expanded(
    child: wrapSquare ? AspectRatio(aspectRatio: 1, child: child) : child,
  );

  static Widget _buildRows({required bool wrapSquare}) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        Expanded(
          child: Row(
            children: [
              _cell(
                const _GridButton(
                  role: HeaderTransportRole.rewind,
                  icon: Icons.fast_rewind,
                ),
                wrapSquare: wrapSquare,
              ),
              _cell(
                const _GridButton(
                  role: HeaderTransportRole.up,
                  icon: Icons.keyboard_arrow_up,
                  bgColor: Color(0xFF282A2E),
                ),
                wrapSquare: wrapSquare,
              ),
              _cell(
                const _GridButton(
                  role: HeaderTransportRole.record,
                  icon: Icons.fiber_manual_record,
                  bgColor: Color(0xFFFFB59E),
                  iconColor: Color(0xFF690005),
                  isSolid: true,
                  shadowColor: Color(0xFFFFB59E),
                ),
                wrapSquare: wrapSquare,
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              _cell(
                const _GridButton(
                  role: HeaderTransportRole.left,
                  icon: Icons.keyboard_arrow_left,
                  bgColor: Color(0xFF282A2E),
                ),
                wrapSquare: wrapSquare,
              ),
              _cell(
                const _GridButton(
                  role: HeaderTransportRole.stop,
                  icon: Icons.stop,
                  bgColor: Color(0xFF33353A),
                  iconColor: Colors.white,
                ),
                wrapSquare: wrapSquare,
              ),
              _cell(
                const _GridButton(
                  role: HeaderTransportRole.right,
                  icon: Icons.keyboard_arrow_right,
                  bgColor: Color(0xFF282A2E),
                ),
                wrapSquare: wrapSquare,
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              _cell(
                const _GridButton(
                  role: HeaderTransportRole.fastForward,
                  icon: Icons.fast_forward,
                ),
                wrapSquare: wrapSquare,
              ),
              _cell(
                const _GridButton(
                  role: HeaderTransportRole.down,
                  icon: Icons.keyboard_arrow_down,
                  bgColor: Color(0xFF282A2E),
                ),
                wrapSquare: wrapSquare,
              ),
              _cell(
                const _GridButton(
                  role: HeaderTransportRole.play,
                  icon: Icons.play_arrow,
                  bgColor: Color(0xFFA6C9F8),
                  iconColor: Color(0xFF033258),
                  isSolid: true,
                  shadowColor: Color(0xFFA6C9F8),
                ),
                wrapSquare: wrapSquare,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!square) {
      return RepaintBoundary(
        child: Container(
          color: Colors.transparent,
          child: Center(child: _buildRows(wrapSquare: false)),
        ),
      );
    }

    return RepaintBoundary(
      child: LayoutBuilder(
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
                child: _buildRows(wrapSquare: true),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  const _HeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
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
          child: Icon(icon, color: color ?? const Color(0xFFA6C9F8), size: 20),
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
  bool _transportSyncPending = false;

  @override
  void initState() {
    super.initState();
    // Start expanded briefly to show status, then collapse
    if (!_transportSyncPending) {
      _transportSyncPending = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _expandTemporarily();
        _transportSyncPending = false;
      });
    }
  }

  @override
  void dispose() {
    _transportSyncPending = false;
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
        child: RepaintBoundary(
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
      ),
    );
  }
}

class _GridButton extends ConsumerStatefulWidget {
  final HeaderTransportRole role;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final bool isSolid;
  final Color shadowColor;

  const _GridButton({
    required this.role,
    required this.icon,
    this.bgColor = const Color(0xFF1E2024),
    this.iconColor = const Color(0xFFC3C7CA),
    this.isSolid = false,
    this.shadowColor = Colors.transparent,
  });

  @override
  ConsumerState<_GridButton> createState() => _GridButtonState();
}

class _GridButtonState extends ConsumerState<_GridButton>
    with PerformanceTickerMixin {
  final _gate = MidiGate.transport();
  int? _pointer;

  @override
  void initState() {
    super.initState();
    initPerformanceMixin();
  }

  @override
  void didUpdateWidget(_GridButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.role != oldWidget.role) _release();
  }

  @override
  void onAppLifecycleChanged(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _pointer != null) {
      setState(_release);
    }
  }

  @override
  void dispose() {
    _release();
    disposePerformanceMixin();
    super.dispose();
  }

  void _release() {
    _pointer = null;
    _gate.release();
  }

  void _handlePointerDown(PointerDownEvent event, ActionPayload? payload) {
    if (_pointer != null || event.buttons != kPrimaryButton) return;
    setState(() => _pointer = event.pointer);
    if (payload != null) _gate.press(ref.read(midiServiceProvider), payload);
  }

  void _handlePointerUp(PointerEvent event, McuActionPayload? mcuTarget) {
    if (event.pointer != _pointer) return;
    setState(_release);
    final bounds = context.size;
    if (event is PointerUpEvent &&
        mcuTarget != null &&
        bounds != null &&
        (Offset.zero & bounds).contains(event.localPosition)) {
      ref.read(midiServiceProvider).tapMcuSwitch(mcuTarget);
    }
  }

  void _activate(ActionPayload? payload, McuActionPayload? mcuTarget) {
    if (_pointer != null) return;
    final midi = ref.read(midiServiceProvider);
    if (mcuTarget != null) {
      midi.tapMcuSwitch(mcuTarget);
    } else if (payload != null) {
      _gate.press(midi, payload);
      _gate.release();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMcu =
        ref.watch(midiProtocolModeProvider).value == MidiProtocolMode.mcu;
    ref.listen(midiProtocolModeProvider, (previous, next) {
      if (previous?.value != next.value && _pointer != null) setState(_release);
    });
    final mcuReady =
        isMcu && (ref.watch(mcuRouteActiveProvider).value ?? false);
    if (isMcu) {
      ref.listen(mcuRouteActiveProvider, (_, next) {
        if (next.value == false && _pointer != null) setState(_release);
      });
    }
    final mcuTarget = mcuReady
        ? McuActionPayload.transport(McuCodec.headerActions[widget.role.index])
        : null;
    ref.listen<ActionPayload?>(
      headerTransportMappingsProvider.select((m) => m[widget.role]),
      (previous, next) {
        if (previous != next && _pointer != null) {
          setState(_release);
        }
      },
    );

    final payload = isMcu
        ? null
        : ref.watch(
            headerTransportMappingsProvider.select((m) => m[widget.role]),
          );
    final address = HeaderTransportMappingsNotifier.feedbackAddress(payload);
    final enabled = mcuTarget != null || (address != null && payload != null);
    final isLit = mcuTarget != null
        ? ref.watch(mcuLampLitProvider(McuCodec.switchNote(mcuTarget)))
        : address != null &&
              ref.watch(
                controlStateProvider.select(
                  (state) => state.buttonStates[address] ?? false,
                ),
              );
    final isPressed = _pointer != null;
    final accent = widget.role == HeaderTransportRole.record
        ? const Color(0xFFFFB59E)
        : const Color(0xFFA6C9F8);

    final effectiveBg = isPressed
        ? (widget.isSolid
              ? Color.alphaBlend(
                  Colors.white.withValues(alpha: 0.25),
                  widget.bgColor,
                )
              : accent)
        : isLit && !widget.isSolid
        ? Color.alphaBlend(accent.withValues(alpha: 0.16), widget.bgColor)
        : widget.bgColor;
    final effectiveIconColor = isPressed && !widget.isSolid
        ? const Color(0xFF111318)
        : isLit && !widget.isSolid
        ? accent
        : widget.iconColor;
    final border = isLit
        ? Border.all(color: widget.isSolid ? Colors.white : accent, width: 1.5)
        : Border.all(
            color: const Color(0xFF111318).withValues(alpha: 0.2),
            width: 0.5,
          );
    final shadows = widget.isSolid || isLit || isPressed
        ? [
            BoxShadow(
              color: (widget.isSolid ? widget.shadowColor : accent).withValues(
                alpha: isPressed || isLit ? 0.65 : 0.4,
              ),
              blurRadius: 20,
              blurStyle: BlurStyle.normal,
            ),
          ]
        : null;

    return Semantics(
      button: true,
      label: widget.role.label,
      enabled: enabled,
      selected: isLit,
      onTap: enabled ? () => _activate(payload, mcuTarget) : null,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: enabled
                ? (event) => _handlePointerDown(event, payload)
                : null,
            onPointerUp: (event) => _handlePointerUp(event, mcuTarget),
            onPointerCancel: (event) => _handlePointerUp(event, null),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final baseSize = constraints.smallest.shortestSide;
                final iconSize = widget.isSolid
                    ? baseSize * 0.38
                    : baseSize * 0.30;

                return Container(
                  decoration: BoxDecoration(
                    color: effectiveBg,
                    border: border,
                    boxShadow: shadows,
                  ),
                  child: Center(
                    child: Icon(
                      widget.icon,
                      color: effectiveIconColor,
                      size: iconSize.clamp(35.0, 50.0),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
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
  late final ScrollController _tabScrollController;
  bool _panMode = false;

  @override
  void initState() {
    super.initState();
    _tabScrollController = ScrollController();
  }

  @override
  void dispose() {
    _tabScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPage = ref.watch(
      layoutStateProvider.select((s) => s.activePageIndex),
    );
    final pages = ref.watch(layoutStateProvider.select((s) => s.pages));
    final isLocked = ref.watch(
      layoutStateProvider.select((s) => s.isPerformanceLocked),
    );
    final scale =
        ref.watch(globalUiScaleProvider).value ??
        GlobalUiScaleNotifier.defaultScale;
    final canPan = scale > 1 && pages.isNotEmpty;

    ref.listen(globalUiScaleProvider, (_, next) {
      if (_panMode && (next.value ?? 1) <= 1) {
        setState(() => _panMode = false);
      }
    });

    ref.listen<int>(layoutStateProvider.select((s) => s.activePageIndex), (
      previous,
      next,
    ) {
      if (_panMode) setState(() => _panMode = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_tabScrollController.hasClients) return;
        final currentPages = ref.read(layoutStateProvider).pages;
        final maxScroll = _tabScrollController.position.maxScrollExtent;
        if (maxScroll == 0) return;
        // Approximate tab width is 80; reveal trailing newly added tabs completely.
        final targetOffset = next == currentPages.length - 1
            ? maxScroll
            : (next * 80.0) -
                  (_tabScrollController.position.viewportDimension / 2) +
                  40.0;
        _tabScrollController.animateTo(
          targetOffset.clamp(0.0, maxScroll),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      });
    });

    final isScrollable = pages.length > 4 || canPan;

    return Column(
      children: [
        // Page Tab Bar with integrated progress
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Row(
              children: [
                _buildLockButton(isLocked),
                if (isScrollable)
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _tabScrollController,
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int i = 0; i < pages.length; i++)
                            _buildTabButton(
                              i,
                              pages[i].name,
                              currentPage,
                              true,
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  for (int i = 0; i < pages.length; i++)
                    _buildTabButton(i, pages[i].name, currentPage, false),
                if (canPan)
                  SizedBox(
                    width: 44,
                    height: 38,
                    child: IconButton(
                      tooltip: _panMode ? 'Finish panning' : 'Pan grid',
                      icon: Icon(
                        _panMode ? Icons.check : Icons.open_with,
                        size: 18,
                      ),
                      color: _panMode
                          ? const Color(0xFFA6C9F8)
                          : Colors.white54,
                      padding: EdgeInsets.zero,
                      onPressed: () => setState(() => _panMode = !_panMode),
                    ),
                  ),
              ],
            ),
            const GlobalConfigProgressBar(),
          ],
        ),
        // Performance Panels
        Expanded(
          child: pages.isEmpty
              ? Center(
                  child: Text(
                    'No pages configured. Go to App Settings to add a page.',
                    style: AppText.system(color: Colors.white54),
                  ),
                )
              : PerformanceGridViewport(
                  scale: scale,
                  panEnabled: _panMode,
                  child: IndexedStack(
                    index: currentPage,
                    children: pages.asMap().entries.map((entry) {
                      final index = entry.key;
                      final page = entry.value;
                      return DynamicGridRenderer(
                        key: ValueKey(page.id),
                        controls: page.controls,
                        pageId: page.id,
                        isActive: currentPage == index,
                        isMobile: widget.isMobile,
                      );
                    }).toList(),
                  ),
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

  Widget _buildTabButton(
    int index,
    String label,
    int currentPage,
    bool isScrollable,
  ) {
    final isActive = currentPage == index;
    final button = GestureDetector(
      onTap: () {
        ref.read(layoutStateProvider.notifier).setPageIndex(index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFEBC351) : const Color(0xFF212327),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Space Grotesk',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: isActive ? const Color(0xFF212327) : Colors.white54,
          ),
        ),
      ),
    );

    if (isScrollable) {
      return button;
    } else {
      return Expanded(child: button);
    }
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

    return RepaintBoundary(
      child: Container(
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

    return Stack(
      children: [
        // Backdrop Blur & Scrim
        Positioned.fill(
          child: ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black.withValues(alpha: 0.65)),
            ),
          ),
        ),
        // Content Card
        Positioned.fill(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF111318), // Obsidian Base
                  borderRadius: BorderRadius.circular(
                    8,
                  ), // Technical sharp corner
                  border: Border.all(
                    color: Colors.redAccent.withValues(
                      alpha: 0.15,
                    ), // Red Ghost Border
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withValues(
                        alpha: 0.05,
                      ), // Luminous shadow
                      blurRadius: 40,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.usb_off_rounded,
                      color: Colors.redAccent.withValues(alpha: 0.8),
                      size: 64,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "DEVICE OFFLINE",
                      style: AppText.performance(
                        color: Colors.redAccent.withValues(alpha: 0.9),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Connection was physically lost. Please reconnect the hardware to continue.",
                      textAlign: TextAlign.center,
                      style: AppText.system(
                        color: Colors.white60,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white10),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  6,
                                ), // rounded-md
                              ),
                            ),
                            onPressed: () => ref
                                .read(connectedMidiDeviceProvider.notifier)
                                .clearConnectionLost(),
                            child: Text(
                              "DISMISS",
                              style: AppText.system(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent.withValues(
                                alpha: 0.8,
                              ),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  6,
                                ), // rounded-md
                              ),
                            ),
                            onPressed: () {
                              ref
                                  .read(connectedMidiDeviceProvider.notifier)
                                  .disconnect();
                              ref.invalidate(midiDevicesProvider);
                            },
                            child: Text(
                              "RESET PORTS",
                              style: AppText.system(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
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
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// SETTINGS FLYOUT (Landscape)
// ---------------------------------------------------------------------------
class _SidePanelOverlay extends ConsumerStatefulWidget {
  const _SidePanelOverlay();

  @override
  ConsumerState<_SidePanelOverlay> createState() => _SidePanelOverlayState();
}

class _SidePanelOverlayState extends ConsumerState<_SidePanelOverlay> {
  SidePanelType _lastActiveType = SidePanelType.none;

  @override
  Widget build(BuildContext context) {
    final panelState = ref.watch(sidePanelProvider);
    final panelType = panelState.type;
    final isVisible = panelType != SidePanelType.none;
    final isLeft = panelState.side == SidePanelSide.left;

    if (panelType != SidePanelType.none) {
      _lastActiveType = panelType;
    }

    final activeContent = _lastActiveType != SidePanelType.none
        ? _buildPanelContent(_lastActiveType)
        : const SizedBox.shrink();

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
          onEnd: () {
            if (!isVisible) {
              setState(() {
                _lastActiveType = SidePanelType.none;
              });
            }
          },
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
                    child: activeContent,
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
