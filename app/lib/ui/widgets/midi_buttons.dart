// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../design_system.dart';
import 'config_gesture_wrapper.dart';

import '../midi_service.dart';
import '../layout_state.dart';
import '../performance_ticker_mixin.dart';
import 'control_config_modal.dart';

enum MidiButtonMode { note, cc }

class Trigger extends ConsumerStatefulWidget {
  final int index;
  final MidiButtonMode mode;
  final Color activeColor;
  final Color inactiveColor;

  const Trigger({
    super.key,
    required this.index,
    this.mode = MidiButtonMode.cc,
    this.activeColor = const Color(0xFFA6C9F8),
    this.inactiveColor = const Color(0xFF282A2E),
  });

  @override
  ConsumerState<Trigger> createState() => _TriggerState();
}

class _TriggerState extends ConsumerState<Trigger>
    with
        TickerProviderStateMixin,
        WidgetsBindingObserver,
        PerformanceTickerMixin {
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    initPerformanceMixin();
  }

  @override
  void dispose() {
    disposePerformanceMixin();
    super.dispose();
  }

  void _handlePointerDown(PointerEvent event, int identifier, int channel) {
    if (_isPressed) return;

    setState(() {
      _isPressed = true;
    });

    final service = ref.read(midiServiceProvider);
    if (widget.mode == MidiButtonMode.note) {
      service.sendNoteOn(identifier, 127, channel: channel, isFinal: false);
    } else {
      service.sendCC(identifier, 127, channel: channel, isFinal: false);
    }
  }

  void _handlePointerUp(PointerEvent event, int identifier, int channel) {
    setState(() {
      _isPressed = false;
    });

    final service = ref.read(midiServiceProvider);
    if (widget.mode == MidiButtonMode.note) {
      service.sendNoteOff(identifier, channel: channel, isFinal: true);
    } else {
      service.sendCC(identifier, 0, channel: channel, isFinal: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final control = ref.watch(
      layoutStateProvider.select(
        (s) => s.pages.length > 3 && widget.index < s.pages[3].controls.length
            ? s.pages[3].controls[widget.index]
            : null,
      ),
    );

    if (control == null) return const SizedBox.shrink();

    final isLocked = ref.watch(
      layoutStateProvider.select((s) => s.isPerformanceLocked),
    );
    final channel = control.channel;
    final identifier = control.defaultCc;
    final isUnassigned = identifier == -1;
    final label = control.displayName;

    return Listener(
      onPointerDown: isUnassigned
          ? null
          : (e) => _handlePointerDown(e, identifier, channel),
      onPointerUp: isUnassigned
          ? null
          : (e) => _handlePointerUp(e, identifier, channel),
      onPointerCancel: isUnassigned
          ? null
          : (e) => _handlePointerUp(e, identifier, channel),
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: isUnassigned ? 0.3 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 50),
          decoration: BoxDecoration(
            color: _isPressed ? widget.activeColor : widget.inactiveColor,
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: _isPressed ? widget.activeColor : const Color(0xFF111318),
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
                      : () => showUtilityConfigModal(context, ref, control.id),
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
                      isUnassigned ? 'UNASSIGNED' : 'CC $identifier',
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
                              : const Color(0xFFC3C7CA).withValues(alpha: 0.3),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
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
  final int index;
  final MidiButtonMode mode;
  final Color activeColor;
  final Color inactiveColor;

  const Toggle({
    super.key,
    required this.index,
    this.mode = MidiButtonMode.cc,
    this.activeColor = const Color(0xFFFFB59E), // Distinct color for toggles
    this.inactiveColor = const Color(0xFF282A2E),
  });

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

  @override
  void initState() {
    super.initState();
    initPerformanceMixin();
  }

  @override
  void dispose() {
    disposePerformanceMixin();
    super.dispose();
  }

  void _handlePointerDown(PointerEvent event) {
    if (_isPressed) return;

    setState(() {
      _isPressed = true;
    });
  }

  void _handlePointerUp(PointerEvent event, int identifier, int channel) {
    if (!_isPressed) return;

    _toggleState(identifier, channel);

    setState(() {
      _isPressed = false;
    });
  }

  void _toggleState(int identifier, int channel) {
    setState(() => _isActive = !_isActive);

    final service = ref.read(midiServiceProvider);

    if (widget.mode == MidiButtonMode.note) {
      if (_isActive) {
        service.sendNoteOn(identifier, 127, channel: channel, isFinal: true);
      } else {
        service.sendNoteOff(identifier, channel: channel, isFinal: true);
      }
    } else {
      if (_isActive) {
        service.sendCC(identifier, 127, channel: channel, isFinal: true);
      } else {
        service.sendCC(identifier, 0, channel: channel, isFinal: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final control = ref.watch(
      layoutStateProvider.select(
        (s) => s.pages.length > 3 && widget.index < s.pages[3].controls.length
            ? s.pages[3].controls[widget.index]
            : null,
      ),
    );

    if (control == null) return const SizedBox.shrink();

    final isLocked = ref.watch(
      layoutStateProvider.select((s) => s.isPerformanceLocked),
    );
    final channel = control.channel;
    final identifier = control.defaultCc;
    final isUnassigned = identifier == -1;
    final label = control.displayName;

    return Listener(
      onPointerDown: isUnassigned ? null : _handlePointerDown,
      onPointerUp: isUnassigned
          ? null
          : (e) => _handlePointerUp(e, identifier, channel),
      onPointerCancel: isUnassigned
          ? null
          : (e) => _handlePointerUp(e, identifier, channel),
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
                      : () => showUtilityConfigModal(context, ref, control.id),
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
                      isUnassigned ? 'UNASSIGNED' : 'CC $identifier',
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
                              : const Color(0xFFC3C7CA).withValues(alpha: 0.3),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
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
