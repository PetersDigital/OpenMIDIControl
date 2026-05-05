// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../midi_service.dart';
import '../performance_ticker_mixin.dart';

class EndlessEncoderWidget extends ConsumerStatefulWidget {
  final int channel;
  final int cc;
  final double sensitivity;
  final bool showChannelLabel;

  const EndlessEncoderWidget({
    super.key,
    this.channel = 0,
    required this.cc,
    this.sensitivity = 1.5,
    this.showChannelLabel = true,
  });

  @override
  ConsumerState<EndlessEncoderWidget> createState() =>
      _EndlessEncoderWidgetState();
}

class _EndlessEncoderWidgetState extends ConsumerState<EndlessEncoderWidget>
    with
        TickerProviderStateMixin,
        WidgetsBindingObserver,
        PerformanceTickerMixin {
  int _currentValue = 0;
  double _accumulatedDelta = 0.0;
  bool _isDragging = false;
  Timer? _throttleTimer;
  int? _lastPolledValue;
  double _visualRotation = 0.0;

  @override
  void initState() {
    super.initState();
    initPerformanceMixin();
    // Initialize from current state
    final hotValue = ref
        .read(controlStateProvider)
        .ccValues["${widget.channel}:${widget.cc}"];
    if (hotValue != null) {
      _currentValue = hotValue;
      _lastPolledValue = hotValue;
    }

    addManagedSubscription(
      ref.listenManual(hotCcValueProvider("${widget.channel}:${widget.cc}"), (
        previous,
        next,
      ) {
        if (next is AsyncData) {
          final val = next.value;
          if (_isDragging) return;
          if (val != null && val != _lastPolledValue) {
            _lastPolledValue = val;
            if (val != _currentValue) {
              setState(() {
                _currentValue = val;
              });
            }
          }
        }
      }),
    );
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    disposePerformanceMixin();
    super.dispose();
  }

  void _sendMidiUpdate() {
    ref
        .read(midiServiceProvider)
        .sendCC(widget.cc, _currentValue, channel: widget.channel);
  }

  static const int _kTransmissionThrottleMs = 8;

  void _throttledSendMidiUpdate() {
    if (_throttleTimer?.isActive ?? false) return;
    _throttleTimer = Timer(
      const Duration(milliseconds: _kTransmissionThrottleMs),
      () {
        _sendMidiUpdate();
      },
    );
  }

  void _handleDragStart(DragStartDetails details) {
    _isDragging = true;
    _accumulatedDelta = 0.0;
  }

  void _handleDragCancel() {
    _isDragging = false;
    _accumulatedDelta = 0.0;
    _sendMidiUpdate(); // Final update
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _accumulatedDelta -= details.delta.dy;

    if (_accumulatedDelta.abs() >= widget.sensitivity) {
      int steps = (_accumulatedDelta / widget.sensitivity).truncate();
      _accumulatedDelta -= steps * widget.sensitivity;

      setState(() {
        _currentValue = (_currentValue + steps).clamp(0, 127);
        // Visual rotation follows the delta dy for a physical feel
        _visualRotation += details.delta.dy * 0.05;
      });
      _throttledSendMidiUpdate();
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    _isDragging = false;
    _accumulatedDelta = 0.0;
    _sendMidiUpdate(); // Final update
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = math.min(constraints.maxWidth, constraints.maxHeight);
          final double effectiveSize = size.isInfinite ? 100.0 : size;

          return GestureDetector(
            onPanStart: _handleDragStart,
            onPanUpdate: _handleDragUpdate,
            onPanEnd: _handleDragEnd,
            onPanCancel: _handleDragCancel,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: effectiveSize,
              height: effectiveSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Knob Surface
                  SizedBox(
                    width: effectiveSize * 0.75,
                    height: effectiveSize * 0.75,
                    child: CustomPaint(
                      painter: _KnobSurfacePainter(
                        rotation: _visualRotation,
                        baseColor: const Color(0xFF23262B),
                      ),
                    ),
                  ),

                  // LED Ring
                  SizedBox(
                    width: effectiveSize,
                    height: effectiveSize,
                    child: CustomPaint(
                      painter: _LedRingPainter(
                        value: _currentValue,
                        inactiveColor: const Color(0xFF0C0E12),
                      ),
                    ),
                  ),

                  // Center Readout
                  Container(
                    width: effectiveSize * 0.6,
                    height: effectiveSize * 0.6,
                    alignment: Alignment.center,
                    color: Colors.transparent, // Ensure it's tappable
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_currentValue',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            color: Colors.white,
                            fontSize: effectiveSize * 0.2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.showChannelLabel)
                          Text(
                            'CH${widget.channel + 1}',
                            style: TextStyle(
                              fontFamily: 'Space Grotesk',
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: effectiveSize * 0.1,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LedRingPainter extends CustomPainter {
  final int value;
  final Color inactiveColor;

  _LedRingPainter({required this.value, required this.inactiveColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = size.width * 0.02;
    final radius = size.width / 2 - (strokeWidth / 2 + 2.0);

    // Audio dB Meter color scheme
    Color meterColor;
    if (value <= 88) {
      meterColor = const Color(0xFF4CAF50); // Green (0-70%)
    } else if (value <= 114) {
      meterColor = const Color(0xFFFFB300); // Amber (70-90%)
    } else {
      meterColor = const Color(0xFFF44336); // Red (90-100%)
    }

    final paintInactive = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final paintActive = Paint()
      ..color = meterColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = 135 * math.pi / 180;
    const maxSweepAngle = 270 * math.pi / 180;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      maxSweepAngle,
      false,
      paintInactive,
    );

    final sweepAngle = (value / 127.0) * maxSweepAngle;
    if (sweepAngle > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paintActive,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LedRingPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}

class _KnobSurfacePainter extends CustomPainter {
  final double rotation;
  final Color baseColor;

  _KnobSurfacePainter({required this.rotation, required this.baseColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Draw flat knob body
    final bodyPaint = Paint()..color = baseColor;
    canvas.drawCircle(center, radius, bodyPaint);

    // 2. Draw radial grips (uniform flat lines)
    final gripPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const gripCount = 24;
    for (int i = 0; i < gripCount; i++) {
      final gripLength = radius * 0.15;

      final angle = (i * 360 / gripCount) * math.pi / 180 + rotation;
      final start = Offset(
        center.dx + math.cos(angle) * (radius - gripLength),
        center.dy + math.sin(angle) * (radius - gripLength),
      );
      final end = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      canvas.drawLine(start, end, gripPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _KnobSurfacePainter oldDelegate) {
    return oldDelegate.rotation != rotation;
  }
}
