// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
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

class LatchPad extends ConsumerStatefulWidget {
  const LatchPad({super.key, required this.control, required this.isActive});

  final LayoutControl control;
  final bool isActive;

  @override
  ConsumerState<LatchPad> createState() => _LatchPadState();
}

class _LatchPadState extends ConsumerState<LatchPad>
    with SingleTickerProviderStateMixin, PerformanceTickerMixin {
  final _gate = MidiGate();
  final _remaining = ValueNotifier<double>(0);
  late final Ticker _ticker;
  Timer? _expiry;
  late bool _foreground;

  bool get _running => _expiry != null;

  @override
  void initState() {
    super.initState();
    initPerformanceMixin();
    _foreground =
        ref.read(appLifecycleStateProvider) == AppLifecycleState.resumed;
    _ticker = createManagedTicker((elapsed) {
      final durationUs =
          widget.control.latchDurationMs * Duration.microsecondsPerMillisecond;
      _remaining.value = (1 - elapsed.inMicroseconds / durationUs).clamp(
        0.0,
        1.0,
      );
    });
  }

  @override
  void didUpdateWidget(LatchPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive ||
        oldWidget.control.id != widget.control.id ||
        oldWidget.control.payload != widget.control.payload ||
        oldWidget.control.latchDurationMs != widget.control.latchDurationMs) {
      _release();
    }
  }

  @override
  void onAppLifecycleChanged(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground && _running) setState(_release);
  }

  void _toggle() {
    if (_running) {
      setState(_release);
      return;
    }
    final payload = widget.control.payload;
    if (!widget.isActive ||
        !_foreground ||
        (payload is! NotePayload && payload is! CcPayload)) {
      return;
    }
    final duration = Duration(milliseconds: widget.control.latchDurationMs);
    _gate.press(ref.read(midiServiceProvider), payload!);
    setState(() {
      _remaining.value = 1;
      _expiry = Timer(duration, () => setState(_release));
    });
    safeStartTicker(_ticker);
  }

  void _release() {
    _expiry?.cancel();
    _expiry = null;
    _ticker.stop();
    _remaining.value = 0;
    _gate.release();
  }

  @override
  void dispose() {
    _release();
    disposePerformanceMixin();
    _remaining.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final control = widget.control;
    final style = control.effectiveStyle;
    final isUnassigned =
        control.payload is! CcPayload && control.payload is! NotePayload;
    final canTrigger = widget.isActive && !isUnassigned;
    final isLocked = ref.watch(
      layoutStateProvider.select((state) => state.isPerformanceLocked),
    );
    final accent = Color(style.accentColorValue ?? 0xFFA6C9F8);
    final durationSeconds = control.latchDurationMs / 1000;

    return RepaintBoundary(
      child: Opacity(
        opacity: isUnassigned ? 0.3 : 1.0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF282A2E),
            border: Border.all(color: const Color(0xFF111318)),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Semantics(
                button: true,
                enabled: canTrigger,
                label: _running ? 'Cancel latch' : 'Start latch',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: canTrigger ? _toggle : null,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: CustomPaint(
                      painter: _CountdownPainter(_remaining, accent),
                      child: Center(
                        child: style.showNumericReadout
                            ? Text(
                                '$durationSeconds s',
                                style: AppText.performance(
                                  color: canTrigger
                                      ? Colors.white
                                      : Colors.white54,
                                  fontSize: 11,
                                ).copyWith(fontFamily: style.fontFamily),
                              )
                            : null,
                      ),
                    ),
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
    );
  }
}

class _CountdownPainter extends CustomPainter {
  _CountdownPainter(this.remaining, this.accent)
    : _track = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..color = accent.withValues(alpha: 0.2),
      _progress = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..color = accent,
      super(repaint: remaining);

  static const _strokeWidth = 3.0;
  final ValueNotifier<double> remaining;
  final Color accent;
  final Paint _track;
  final Paint _progress;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (size.shortestSide - _strokeWidth) / 2;
    if (radius <= 0) return;
    final center = size.center(Offset.zero);
    canvas.drawCircle(center, radius, _track);
    if (remaining.value <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      remaining.value * 2 * math.pi,
      false,
      _progress,
    );
  }

  @override
  bool shouldRepaint(_CountdownPainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.remaining != remaining;
}
