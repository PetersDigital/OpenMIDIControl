// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../midi_service.dart';

class EndlessEncoderWidget extends ConsumerStatefulWidget {
  final int channel;
  final int cc;
  final double sensitivity;
  final VoidCallback? onLongPress;

  const EndlessEncoderWidget({
    super.key,
    this.channel = 0,
    required this.cc,
    this.sensitivity = 5.0,
    this.onLongPress,
  });

  @override
  ConsumerState<EndlessEncoderWidget> createState() =>
      _EndlessEncoderWidgetState();
}

class _EndlessEncoderWidgetState extends ConsumerState<EndlessEncoderWidget> {
  int _currentValue = 0;
  double _accumulatedDelta = 0.0;
  bool _isDragging = false;
  Timer? _throttleTimer;

  @override
  void dispose() {
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
  }

  @override
  Widget build(BuildContext context) {
    // Watch the hot CC value, but don't overwrite if dragging.
    final asyncValue = ref.watch(
      hotCcValueProvider("${widget.channel}:${widget.cc}"),
    );

    // AsyncValue.whenData doesn't trigger a rebuild gracefully without side effects during build,
    // so we handle the update in a post-frame callback if needed,
    // or just use the value directly if not dragging.
    asyncValue.whenData((val) {
      if (!_isDragging && val != _currentValue) {
        // Schedule state update to avoid 'setState during build' errors
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isDragging && val != _currentValue) {
            setState(() {
              _currentValue = val;
            });
          }
        });
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);

        // If size is not restricted, give it a default reasonable size
        final double effectiveSize = size.isInfinite ? 100.0 : size;

        return GestureDetector(
          onPanStart: _handleDragStart,
          onPanUpdate: _handleDragUpdate,
          onPanEnd: _handleDragEnd,
          onPanCancel: () =>
              _handleDragEnd(DragEndDetails(velocity: Velocity.zero)),
          onLongPress: widget.onLongPress,
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
                      activeColor: const Color(
                        0xFFA6C9F8,
                      ), // Matches hybrid_touch_fader active text color
                      inactiveColor: const Color(0xFF0C0E12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
    final radius = size.width / 2 - 4.0; // slight padding

    final paintInactive = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    final paintActive = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    // Start angle: bottom left (approx 135 degrees)
    // End angle: bottom right (approx 45 degrees)
    // Sweep: 270 degrees
    const startAngle = 135 * math.pi / 180;
    const maxSweepAngle = 270 * math.pi / 180;

    // Draw background ring
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      maxSweepAngle,
      false,
      paintInactive,
    );

    // Draw active ring
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
