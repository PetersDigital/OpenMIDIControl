// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:async';
import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/action_payload.dart';
import '../../core/utils/control_value_formatter.dart';
import '../midi_action_dispatcher.dart';
import '../midi_service.dart';
import '../midi_settings_state.dart'
    show mcuRouteActiveProvider, mcuVPotRingProvider;
import '../performance_ticker_mixin.dart';

class EndlessEncoderWidget extends ConsumerStatefulWidget {
  final int channel;
  final int cc;
  final ActionPayload? payload;
  final double sensitivity;
  final bool showChannelLabel;
  final bool isActive;
  final Color? accentColor;
  final String? fontFamily;
  final bool showNumericReadout;

  const EndlessEncoderWidget({
    super.key,
    this.channel = 0,
    required this.cc,
    this.payload,
    this.sensitivity = 1.5,
    this.showChannelLabel = true,
    this.isActive = true,
    this.accentColor,
    this.fontFamily,
    this.showNumericReadout = true,
  });

  @override
  ConsumerState<EndlessEncoderWidget> createState() =>
      _EndlessEncoderWidgetState();
}

class _EndlessEncoderWidgetState extends ConsumerState<EndlessEncoderWidget>
    with TickerProviderStateMixin, PerformanceTickerMixin {
  int _currentValue = 0;
  double _accumulatedDelta = 0.0;
  bool _isDragging = false;
  bool _vPotPushActive = false;
  Timer? _throttleTimer;
  int? _lastPolledValue;
  double _visualRotation = 0.0;
  final _midiAction = MidiActionDispatcher();
  int _pendingRelativeDelta = 0;
  McuActionPayload? get _vPot => switch (widget.payload) {
    final McuActionPayload payload when payload.target == McuTarget.vPot =>
      payload,
    _ => null,
  };
  String? get _feedbackAddress =>
      ccFeedbackAddress(widget.payload, widget.channel, widget.cc);

  @override
  void initState() {
    super.initState();
    initPerformanceMixin();
    _syncFromControlState();

    if (widget.isActive) {
      _setupMidiListener();
    }
  }

  void _syncFromControlState() {
    final hotValue = ref.read(controlStateProvider).ccValues[_feedbackAddress];
    if (hotValue != null) {
      _currentValue = hotValue;
      _lastPolledValue = hotValue;
    }
  }

  void _setupMidiListener() {
    clearManagedSubscriptions();
    final address = _feedbackAddress;
    if (address == null) return;
    addManagedSubscription(
      ref.listenManual(hotCcValueProvider(address), (previous, next) {
        if (!widget.isActive) return;
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
  void didUpdateWidget(EndlessEncoderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.payload != widget.payload || !widget.isActive) {
      _throttleTimer?.cancel();
      _pendingRelativeDelta = 0;
      _midiAction.end();
      if (oldWidget.payload != widget.payload) {
        _vPotPushActive = false;
      }
    }
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        _setupMidiListener();
        _syncFromControlState();
      } else {
        clearManagedSubscriptions();
        _throttleTimer?.cancel();
      }
    } else if (oldWidget.channel != widget.channel ||
        oldWidget.cc != widget.cc ||
        oldWidget.payload != widget.payload) {
      _lastPolledValue = null;
      _syncFromControlState();
      if (widget.isActive) {
        _setupMidiListener();
      }
    }
  }

  @override
  void onAppLifecycleChanged(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _throttleTimer?.cancel();
      _pendingRelativeDelta = 0;
      _midiAction.end();
    }
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    _midiAction.end();
    disposePerformanceMixin();
    super.dispose();
  }

  void _sendMidiUpdate() {
    if (!widget.isActive) return;
    if (widget.payload == null && widget.cc == -1) return;
    final delta = _pendingRelativeDelta;
    _pendingRelativeDelta = 0;
    _midiAction.sendPosition(
      ref.read(midiServiceProvider),
      widget.payload,
      _currentValue / 127,
      legacyChannel: widget.channel,
      legacyCc: widget.cc,
      relativeDelta: delta,
    );
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
    if (widget.payload is NotePayload) {
      _midiAction.begin(
        ref.read(midiServiceProvider),
        widget.payload,
        _currentValue / 127,
      );
    }
  }

  void _finishDrag() {
    _isDragging = false;
    _accumulatedDelta = 0.0;
    if (widget.payload is RelativeCcPayload || _vPot != null) {
      _throttleTimer?.cancel();
    }
    _sendMidiUpdate();
    _midiAction.end();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _accumulatedDelta -= details.delta.dy;

    if (_accumulatedDelta.abs() >= widget.sensitivity) {
      int steps = (_accumulatedDelta / widget.sensitivity).truncate();
      _accumulatedDelta -= steps * widget.sensitivity;
      if (widget.payload is RelativeCcPayload || _vPot != null) {
        _pendingRelativeDelta += steps;
      }

      setState(() {
        _currentValue = (_currentValue + steps).clamp(0, 127);
        // Visual rotation follows the delta dy for a physical feel
        _visualRotation += details.delta.dy * 0.05;
      });
      _throttledSendMidiUpdate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vPot = _vPot;
    final vPotRing = vPot != null
        ? ref.watch(mcuVPotRingProvider(vPot.strip!)).value
        : null;
    final monitorLit = vPot != null && _vPotPushActive;
    final canPerform =
        widget.isActive &&
        (vPot == null || (ref.watch(mcuRouteActiveProvider).value ?? false));
    if (vPot != null) {
      ref.listen(mcuRouteActiveProvider, (_, next) {
        if (next.value == false) {
          _throttleTimer?.cancel();
          _pendingRelativeDelta = 0;
          if (_vPotPushActive) {
            setState(() => _vPotPushActive = false);
          }
        }
      });
    }
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = math.min(constraints.maxWidth, constraints.maxHeight);
          final double effectiveSize = size.isInfinite ? 100.0 : size;

          return GestureDetector(
            onTap: canPerform && vPot != null
                ? () {
                    ref.read(midiServiceProvider).tapMcuSwitch(vPot);
                    setState(() => _vPotPushActive = !_vPotPushActive);
                  }
                : null,
            onLongPress: canPerform && vPot != null ? () {} : null,
            onPanStart: canPerform ? _handleDragStart : null,
            onPanUpdate: canPerform ? _handleDragUpdate : null,
            onPanEnd: canPerform ? (_) => _finishDrag() : null,
            onPanCancel: canPerform ? _finishDrag : null,
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
                        baseColor: monitorLit
                            ? const Color(0xFFFFB300)
                            : const Color(0xFF23262B),
                      ),
                    ),
                  ),

                  // LED Ring
                  Semantics(
                    container: vPot != null,
                    label: vPot == null
                        ? null
                        : (monitorLit ? 'Monitor ON' : 'Monitor OFF'),
                    child: SizedBox(
                      width: effectiveSize,
                      height: effectiveSize,
                      child: CustomPaint(
                        painter: _LedRingPainter(
                          value: vPot == null ? _currentValue : 0,
                          inactiveColor: const Color(0xFF0C0E12),
                          accentColor: widget.accentColor,
                          isVPot: vPot != null,
                          vPotPosition: vPot != null
                              ? vPotRing?.position
                              : null,
                        ),
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
                        if (widget.showNumericReadout)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                ControlValueFormatter.formatEncoder(
                                  widget.payload,
                                  _currentValue,
                                  vPotRing: vPotRing,
                                ),
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  fontFamily:
                                      widget.fontFamily ?? 'Space Grotesk',
                                  color: monitorLit
                                      ? const Color(0xFF1A1400)
                                      : Colors.white,
                                  fontSize: effectiveSize * 0.2,
                                  fontWeight: FontWeight.bold,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (widget.showChannelLabel)
                          Text(
                            'CH${widget.channel + 1}',
                            style: TextStyle(
                              fontFamily: widget.fontFamily ?? 'Space Grotesk',
                              color: monitorLit
                                  ? const Color(
                                      0xFF1A1400,
                                    ).withValues(alpha: 0.7)
                                  : Colors.white.withValues(alpha: 0.5),
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
  final Color? accentColor;
  final bool isVPot;
  final int? vPotPosition;

  _LedRingPainter({
    required this.value,
    required this.inactiveColor,
    this.accentColor,
    this.isVPot = false,
    this.vPotPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = size.width * 0.02;
    final radius = size.width / 2 - (strokeWidth / 2 + 2.0);
    const startAngle = 135 * math.pi / 180;
    const maxSweepAngle = 270 * math.pi / 180;

    if (isVPot || vPotPosition != null) {
      final panStroke = math.max(size.width * 0.06, 2.4);
      final panRadius = size.width / 2 - (panStroke / 2 + 1.0);
      _inactivePaint
        ..color = inactiveColor
        ..strokeWidth = panStroke;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: panRadius),
        startAngle,
        maxSweepAngle,
        false,
        _inactivePaint,
      );

      final pos = vPotPosition;
      if (pos != null && pos >= 1 && pos <= 11) {
        final panColor = accentColor ?? const Color(0xFF64B5F6);
        if (pos == 6) {
          _dotPaint.color = panColor;
          canvas.drawCircle(
            Offset(center.dx, center.dy - panRadius),
            panStroke * 0.7,
            _dotPaint,
          );
        } else {
          final sweep = ((pos - 6) / 5.0) * (135 * math.pi / 180);
          _activePaint
            ..color = panColor
            ..strokeWidth = panStroke;
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: panRadius),
            -math.pi / 2,
            sweep,
            false,
            _activePaint,
          );
        }
      }
      return;
    }

    // Custom accent overrides the dynamic dB meter color scheme.
    final Color meterColor;
    if (accentColor != null) {
      meterColor = accentColor!;
    } else if (value <= 88) {
      meterColor = const Color(0xFF4CAF50); // Green (0-70%)
    } else if (value <= 114) {
      meterColor = const Color(0xFFFFB300); // Amber (70-90%)
    } else {
      meterColor = const Color(0xFFF44336); // Red (90-100%)
    }

    _inactivePaint
      ..color = inactiveColor
      ..strokeWidth = strokeWidth;

    _activePaint
      ..color = meterColor
      ..strokeWidth = strokeWidth;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      maxSweepAngle,
      false,
      _inactivePaint,
    );

    final sweepAngle = (value / 127.0) * maxSweepAngle;
    if (sweepAngle > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        _activePaint,
      );
    }
  }

  static final _inactivePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  static final _activePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  static final _dotPaint = Paint()..style = PaintingStyle.fill;

  @override
  bool shouldRepaint(covariant _LedRingPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isVPot != isVPot ||
        oldDelegate.vPotPosition != vPotPosition;
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
    _bodyPaint.color = baseColor;
    canvas.drawCircle(center, radius, _bodyPaint);

    // 2. Draw radial grips (uniform flat lines)
    _gripPaint.color = Colors.black.withValues(alpha: 0.4);

    _gripPath ??= _buildGripPath();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.scale(radius);
    // Draw cached path with thickness correction
    canvas.drawPath(_gripPath!, _gripPaint..strokeWidth = 1.0 / radius);
    canvas.restore();
  }

  static final _bodyPaint = Paint();
  static final _gripPaint = Paint()..style = PaintingStyle.stroke;
  static Path? _gripPath;

  static Path _buildGripPath() {
    final path = Path();
    const gripCount = 24;
    for (int i = 0; i < gripCount; i++) {
      final angle = (i * 360 / gripCount) * math.pi / 180;
      // Use unit coordinates (0.85 to 1.0 radial)
      path.moveTo(math.cos(angle) * 0.85, math.sin(angle) * 0.85);
      path.lineTo(math.cos(angle), math.sin(angle));
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _KnobSurfacePainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.baseColor != baseColor;
  }
}
