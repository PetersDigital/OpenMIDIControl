// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:async';
import 'dart:io' as io;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../midi_service.dart';

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
    with TickerProviderStateMixin {
  int _currentValue = 0;
  double _accumulatedDelta = 0.0;
  bool _isDragging = false;
  Timer? _throttleTimer;
  late Ticker _pullTicker;
  int? _lastPolledValue;

  @override
  void initState() {
    super.initState();
    // Initialize from current state
    final hotValue = ref
        .read(controlStateProvider)
        .ccValues["${widget.channel}:${widget.cc}"];
    if (hotValue != null) {
      _currentValue = hotValue;
      _lastPolledValue = hotValue;
    }

    _setupTicker();
  }

  void _setupTicker() {
    final bool isTestEnv = io.Platform.environment.containsKey('FLUTTER_TEST');

    _pullTicker = createTicker((elapsed) {
      if (!mounted || _isDragging) return;
      final currentState = ref.read(controlStateProvider);
      final val = currentState.ccValues["${widget.channel}:${widget.cc}"];
      if (val != null && val != _lastPolledValue) {
        _lastPolledValue = val;
        if (val != _currentValue) {
          setState(() {
            _currentValue = val;
          });
        }
      }
    });

    if (!isTestEnv) {
      _pullTicker.start();
    } else {
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
      });
    }
  }

  @override
  void dispose() {
    _pullTicker.dispose();
    _throttleTimer?.cancel();
    super.dispose();
  }

  void _sendMidiUpdate() {
    ref
        .read(midiServiceProvider)
        .sendCC(widget.cc, _currentValue, channel: widget.channel);
  }

  void _throttledSendMidiUpdate() {
    if (_throttleTimer?.isActive ?? false) return;
    _throttleTimer = Timer(const Duration(milliseconds: 16), () {
      _sendMidiUpdate();
    });
  }

  void _handleDragStart(DragStartDetails details) {
    _isDragging = true;
    _accumulatedDelta = 0.0;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _accumulatedDelta -= details.delta.dy;

    if (_accumulatedDelta.abs() >= widget.sensitivity) {
      int steps = (_accumulatedDelta / widget.sensitivity).truncate();
      _accumulatedDelta -= steps * widget.sensitivity;

      setState(() {
        _currentValue = (_currentValue + steps).clamp(0, 127);
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
            onPanCancel: () =>
                _handleDragEnd(DragEndDetails(velocity: Velocity.zero)),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: effectiveSize,
              height: effectiveSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Knob base
                  Container(
                    width: effectiveSize * 0.8,
                    height: effectiveSize * 0.8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1E2024),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                  ),

                  // LED Ring
                  SizedBox(
                    width: effectiveSize,
                    height: effectiveSize,
                    child: CustomPaint(
                      painter: _LedRingPainter(
                        value: _currentValue,
                        activeColor: const Color(0xFFA6C9F8),
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
  final Color activeColor;
  final Color inactiveColor;

  _LedRingPainter({
    required this.value,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = size.width * 0.02;
    final radius = size.width / 2 - (strokeWidth / 2 + 2.0);

    final paintInactive = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final paintActive = Paint()
      ..color = activeColor
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
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
