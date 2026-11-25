// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../core/models/action_payload.dart';
import '../../core/models/layout_models.dart';
import '../design_system.dart';
import 'config_gesture_wrapper.dart';

import '../midi_service.dart';
import '../midi_action_dispatcher.dart';
import '../layout_state.dart';
import '../performance_ticker_mixin.dart';
import 'control_config_modal.dart';

enum MidiButtonMode { note, cc }

ActionPayload? _buttonPayload(LayoutControl control, MidiButtonMode mode) {
  final payload = control.payload;
  if (mode == MidiButtonMode.note &&
      payload is CcPayload &&
      !payload.highResolution &&
      payload.cc == control.defaultCc &&
      payload.channel == control.channel) {
    return NotePayload(channel: payload.channel, note: payload.cc);
  }
  return payload;
}

class Trigger extends ConsumerStatefulWidget {
  final String controlId;
  final MidiButtonMode mode;
  final Color activeColor;
  final Color inactiveColor;

  const Trigger({
    super.key,
    required this.controlId,
    required this.pageId,
    this.mode = MidiButtonMode.cc,
    this.activeColor = const Color(0xFFA6C9F8),
    this.inactiveColor = const Color(0xFF282A2E),
  });

  final String pageId;

  @override
  ConsumerState<Trigger> createState() => _TriggerState();
}

class _TriggerState extends ConsumerState<Trigger>
    with
        TickerProviderStateMixin,
        WidgetsBindingObserver,
        PerformanceTickerMixin {
  bool _isPressed = false;
  int? _activePointer;
  final _midiGate = MidiGate();

  @override
  void initState() {
    super.initState();
    initPerformanceMixin();
  }

  @override
  void onAppLifecycleChanged(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _isPressed) {
      setState(() {
        _activePointer = null;
        _isPressed = false;
      });
      _midiGate.release();
    }
  }

  @override
  void dispose() {
    _midiGate.release();
    disposePerformanceMixin();
    super.dispose();
  }

  void _handlePointerDown(PointerEvent event, ActionPayload? payload) {
    if (_isPressed) return;
    _activePointer = event.pointer;

    setState(() {
      _isPressed = true;
    });

    if (payload != null) {
      _midiGate.press(ref.read(midiServiceProvider), payload, isFinal: false);
    }
  }

  void _handlePointerUp(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    setState(() {
      _isPressed = false;
    });

    _midiGate.release();
  }

  @override
  Widget build(BuildContext context) {
    final control = ref.watch(
      layoutStateProvider.select((s) {
        final page = s.pages.firstWhereOrNull((p) => p.id == widget.pageId);
        if (page == null) return null;
        return page.controls.firstWhereOrNull((c) => c.id == widget.controlId);
      }),
    );

    if (control == null) return const SizedBox.shrink();

    final isLocked = ref.watch(
      layoutStateProvider.select((s) => s.isPerformanceLocked),
    );
    final channel = control.payload?.midiChannel ?? control.channel;
    final identifier = control.defaultCc;
    final payload = _buttonPayload(control, widget.mode);
    final isUnassigned = identifier == -1 && payload == null;
    final label = control.displayName;

    return RepaintBoundary(
      child: Listener(
        onPointerDown: isUnassigned
            ? null
            : (e) => _handlePointerDown(e, payload),
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerUp,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: isUnassigned ? 0.3 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 50),
            decoration: BoxDecoration(
              color: _isPressed ? widget.activeColor : widget.inactiveColor,
              borderRadius: BorderRadius.zero,
              border: Border.all(
                color: _isPressed
                    ? widget.activeColor
                    : const Color(0xFF111318),
                width: 1.0,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  child: ConfigGestureWrapper(
                    key: ValueKey('config_wrapper_trigger_${control.id}'),
                    id: 'trigger_${control.id}',
                    onConfigRequested: isLocked
                        ? null
                        : () =>
                              showUtilityConfigModal(context, ref, control.id),
                    child: Container(
                      padding: const EdgeInsets.only(
                        top: 4,
                        left: 6,
                        bottom: 20,
                        right: 20,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 64,
                        minHeight: 60,
                      ),
                      alignment: Alignment.topLeft,
                      child: Text(
                        isUnassigned
                            ? 'UNASSIGNED'
                            : control.payload?.displayLabel ?? 'CC $identifier',
                        style: AppText.performance(
                          color: _isPressed
                              ? const Color(0xFF033258).withValues(alpha: 0.6)
                              : const Color(0xFFC3C7CA).withValues(alpha: 0.3),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppText.performance(
                        color: _isPressed
                            ? const Color(0xFF033258)
                            : const Color(0xFFC3C7CA),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                // Status (Bottom Left)
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Text(
                    _isPressed ? 'ON' : 'OFF',
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      color: _isPressed
                          ? const Color(0xFF033258)
                          : const Color(0xFFC3C7CA).withValues(alpha: 0.3),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: isUnassigned
                      ? const SizedBox.shrink()
                      : Text(
                          'CH${channel + 1}',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            color: _isPressed
                                ? const Color(0xFF033258).withValues(alpha: 0.6)
                                : const Color(
                                    0xFFC3C7CA,
                                  ).withValues(alpha: 0.3),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
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

Future<void> showUtilityConfigModal(
  BuildContext context,
  WidgetRef ref,
  String id,
) async {
  await showDialog(
    context: context,
    builder: (context) => ControlConfigModal(
      controlId: id,
      identifierLabel: 'CC Number',
      displayNameLabel: 'Control Name',
    ),
  );
}

class Toggle extends ConsumerStatefulWidget {
  final String controlId;
  final MidiButtonMode mode;
  final Color activeColor;
  final Color inactiveColor;

  const Toggle({
    super.key,
    required this.controlId,
    required this.pageId,
    this.mode = MidiButtonMode.cc,
    this.activeColor = const Color(0xFFFFB59E), // Distinct color for toggles
    this.inactiveColor = const Color(0xFF282A2E),
  });

  final String pageId;

  @override
  ConsumerState<Toggle> createState() => _ToggleState();
}

class _ToggleState extends ConsumerState<Toggle>
    with
        TickerProviderStateMixin,
        WidgetsBindingObserver,
        PerformanceTickerMixin {
  bool _isActive = false;
  bool _isPressed = false;
  int? _activePointer;
  final _midiGate = MidiGate();

  @override
  void initState() {
    super.initState();
    initPerformanceMixin();
  }

  @override
  void dispose() {
    if (_midiGate.heldPayload is NotePayload) {
      _midiGate.release();
    }
    disposePerformanceMixin();
    super.dispose();
  }

  void _handlePointerDown(PointerEvent event) {
    if (_isPressed) return;
    _activePointer = event.pointer;

    setState(() {
      _isPressed = true;
    });
  }

  void _handlePointerUp(PointerEvent event, ActionPayload? payload) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;

    _toggleState(payload);

    setState(() {
      _isPressed = false;
    });
  }

  void _toggleState(ActionPayload? payload) {
    setState(() => _isActive = !_isActive);

    if (_isActive && payload != null) {
      _midiGate.press(ref.read(midiServiceProvider), payload);
    } else if (!_isActive) {
      _midiGate.release(relativeOnRelease: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final control = ref.watch(
      layoutStateProvider.select((s) {
        final page = s.pages.firstWhereOrNull((p) => p.id == widget.pageId);
        if (page == null) return null;
        return page.controls.firstWhereOrNull((c) => c.id == widget.controlId);
      }),
    );

    if (control == null) return const SizedBox.shrink();

    final isLocked = ref.watch(
      layoutStateProvider.select((s) => s.isPerformanceLocked),
    );
    final channel = control.payload?.midiChannel ?? control.channel;
    final identifier = control.defaultCc;
    final payload = _buttonPayload(control, widget.mode);
    final isUnassigned = identifier == -1 && payload == null && !_isActive;
    final label = control.displayName;

    return RepaintBoundary(
      child: Listener(
        onPointerDown: isUnassigned ? null : _handlePointerDown,
        onPointerUp: (e) => _handlePointerUp(e, payload),
        onPointerCancel: (e) => _handlePointerUp(e, payload),
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: isUnassigned ? 0.3 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: _isActive ? widget.activeColor : widget.inactiveColor,
              borderRadius: BorderRadius.zero,
              border: Border.all(
                color: _isActive ? widget.activeColor : const Color(0xFF111318),
                width: 1.0,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  child: ConfigGestureWrapper(
                    key: ValueKey('config_wrapper_toggle_${control.id}'),
                    id: 'toggle_${control.id}',
                    onConfigRequested: isLocked
                        ? null
                        : () =>
                              showUtilityConfigModal(context, ref, control.id),
                    child: Container(
                      padding: const EdgeInsets.only(
                        top: 4,
                        left: 6,
                        bottom: 20,
                        right: 20,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 64,
                        minHeight: 60,
                      ),
                      alignment: Alignment.topLeft,
                      child: Text(
                        isUnassigned
                            ? 'UNASSIGNED'
                            : control.payload?.displayLabel ?? 'CC $identifier',
                        style: AppText.performance(
                          color: _isActive
                              ? const Color(0xFF690005).withValues(alpha: 0.6)
                              : const Color(0xFFC3C7CA).withValues(alpha: 0.3),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppText.performance(
                        color: _isActive
                            ? const Color(0xFF690005)
                            : const Color(0xFFC3C7CA),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                // Status (Bottom Left)
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Text(
                    _isActive ? 'ON' : 'OFF',
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      color: _isActive
                          ? const Color(0xFF690005)
                          : const Color(0xFFC3C7CA).withValues(alpha: 0.3),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: isUnassigned
                      ? const SizedBox.shrink()
                      : Text(
                          'CH${channel + 1}',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            color: _isActive
                                ? const Color(0xFF690005).withValues(alpha: 0.6)
                                : const Color(
                                    0xFFC3C7CA,
                                  ).withValues(alpha: 0.3),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
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
