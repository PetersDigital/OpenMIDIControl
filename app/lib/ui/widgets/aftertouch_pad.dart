// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lifecycle/app_lifecycle_manager.dart';
import '../../core/models/action_payload.dart';
import '../../core/models/layout_models.dart';
import '../design_system.dart';
import '../layout_state.dart';
import '../midi_action_dispatcher.dart';
import '../midi_service.dart';
import '../performance_ticker_mixin.dart';
import 'config_gesture_wrapper.dart';
import 'control_config_modal.dart';

class AftertouchPad extends ConsumerStatefulWidget {
  const AftertouchPad({
    super.key,
    required this.control,
    required this.isActive,
  });

  final LayoutControl control;
  final bool isActive;

  @override
  ConsumerState<AftertouchPad> createState() => _AftertouchPadState();
}

class _AftertouchPadState extends ConsumerState<AftertouchPad>
    with PerformanceTickerMixin {
  static const _intervalUs = 10000;

  final _note = MidiGate();
  final _sendClock = Stopwatch();
  final _expression = ValueNotifier<int>(0);
  Timer? _pendingSend;
  MidiService? _service;
  int? _pointer;
  int? _cc;
  int _lastSent = 0;
  double _startY = 0;
  late bool _foreground;

  @override
  void initState() {
    super.initState();
    initPerformanceMixin();
    _foreground =
        ref.read(appLifecycleStateProvider) == AppLifecycleState.resumed;
  }

  @override
  void didUpdateWidget(AftertouchPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive ||
        oldWidget.control.payload != widget.control.payload ||
        oldWidget.control.effectiveSecondaryPayload !=
            widget.control.effectiveSecondaryPayload) {
      _release();
    }
  }

  @override
  void onAppLifecycleChanged(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground && _pointer != null) setState(_release);
  }

  void _press(PointerDownEvent event, Size size, NotePayload note) {
    if (_pointer != null || !_foreground || event.buttons != kPrimaryButton) {
      return;
    }
    final intensity = (1 - event.localPosition.dy / size.height).clamp(
      0.0,
      1.0,
    );
    final velocity = switch (note.velocityMode) {
      NoteVelocityMode.fixed => 127,
      NoteVelocityMode.touchPosition =>
        (127 *
                (note.velocityCurve == NoteVelocityCurve.drumPad
                    ? intensity * math.sqrt(intensity)
                    : intensity))
            .round()
            .clamp(1, 127),
    };
    final service = ref.read(midiServiceProvider);
    final expression = widget.control.effectiveSecondaryPayload;
    _cc = expression is CcPayload ? expression.cc : null;
    _service = service;
    _startY = event.localPosition.dy;
    setState(() => _pointer = event.pointer);
    _note.press(service, note, velocity: velocity);
  }

  void _move(PointerMoveEvent event) {
    if (_pointer != event.pointer || _cc == null) return;
    final travel = (_startY - event.localPosition.dy) / math.max(1.0, _startY);
    final value = (travel.clamp(0.0, 1.0) * 127).round();
    _expression.value = value;
    if (value == _lastSent || _pendingSend != null) return;

    final remaining = _intervalUs - _sendClock.elapsedMicroseconds;
    if (!_sendClock.isRunning || remaining <= 0) {
      _sendExpression();
    } else {
      _pendingSend = Timer(Duration(microseconds: remaining), _sendExpression);
    }
  }

  void _sendExpression() {
    _pendingSend = null;
    final value = _expression.value;
    if (value == _lastSent) return;
    final note = _note.heldPayload as NotePayload;
    _lastSent = value;
    _sendClock
      ..reset()
      ..start();
    _service!.sendCC(_cc!, value, channel: note.channel);
  }

  void _release() {
    if (_pointer == null) return;
    _pendingSend?.cancel();
    _pendingSend = null;
    _sendClock
      ..stop()
      ..reset();
    _note.release();
    _pointer = null;
    _service = null;
    _cc = null;
    _lastSent = 0;
    _expression.value = 0;
  }

  void _finishPointer(PointerEvent event) {
    if (_pointer == event.pointer) setState(_release);
  }

  @override
  void dispose() {
    _release();
    _expression.dispose();
    disposePerformanceMixin();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final control = widget.control;
    final style = control.effectiveStyle;
    final note = control.payload;
    final isUnassigned = note is! NotePayload;
    final accent = Color(style.accentColorValue ?? 0xFFA6C9F8);
    final isLocked = ref.watch(
      layoutStateProvider.select((state) => state.isPerformanceLocked),
    );

    return RepaintBoundary(
      child: Opacity(
        opacity: isUnassigned ? 0.3 : 1.0,
        child: LayoutBuilder(
          builder: (context, constraints) => DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF282A2E),
              border: Border.all(
                color: _pointer == null ? const Color(0xFF111318) : accent,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: widget.isActive && note is NotePayload
                      ? (event) => _press(event, constraints.biggest, note)
                      : null,
                  onPointerMove: _move,
                  onPointerUp: _finishPointer,
                  onPointerCancel: _finishPointer,
                  child: ValueListenableBuilder<int>(
                    valueListenable: _expression,
                    builder: (context, value, _) => Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        FractionallySizedBox(
                          widthFactor: 1,
                          heightFactor: value / 127,
                          child: ColoredBox(
                            color: accent.withValues(alpha: 0.35),
                          ),
                        ),
                        if (style.showNumericReadout &&
                            _pointer != null &&
                            _cc != null)
                          Center(
                            child: Text(
                              '$value',
                              style: AppText.performance(
                                color: Colors.white,
                              ).copyWith(fontFamily: style.fontFamily),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (style.showLabel)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ConfigGestureWrapper(
                      id: control.id,
                      onConfigRequested: isLocked || !widget.isActive
                          ? null
                          : () => showDialog<void>(
                              context: context,
                              builder: (_) => ControlConfigModal(
                                controlId: control.id,
                                displayNameLabel: 'Pad Label',
                              ),
                            ),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          control.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.performance(
                            color: Colors.white70,
                            fontSize: 11,
                          ).copyWith(fontFamily: style.fontFamily),
                        ),
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
