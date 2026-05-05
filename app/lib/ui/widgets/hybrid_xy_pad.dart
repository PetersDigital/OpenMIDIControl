// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design_system.dart';
import '../midi_service.dart';
import '../performance_ticker_mixin.dart';
import 'control_config_modal.dart';
import 'config_gesture_wrapper.dart';
import '../layout_state.dart';
import '../../core/models/layout_models.dart';

class HybridXYPad extends ConsumerStatefulWidget {
  final String id;
  final int ccX;
  final int ccY;
  final int channel;
  final bool invertX;
  final bool invertY;
  final Color padColor;

  const HybridXYPad({
    super.key,
    required this.id,
    required this.ccX,
    required this.ccY,
    this.channel = 0,
    this.invertX = false,
    this.invertY = true, // By default, Y=0 is usually bottom in audio software
    this.padColor = const Color(0xFF282A2E),
  });

  @override
  ConsumerState<HybridXYPad> createState() => _HybridXYPadState();
}

class _HybridXYPadState extends ConsumerState<HybridXYPad>
    with
        TickerProviderStateMixin,
        WidgetsBindingObserver,
        PerformanceTickerMixin {
  bool _isDragging = false;
  double _normalizedX = 0.5;
  double _normalizedY = 0.5;

  Timer? _throttleTimer;
  bool _canSend = true;
  bool _hasPendingSend = false;

  // No ticker needed for idle interaction
  int? _lastPolledX;
  int? _lastPolledY;

  LayoutControl? _cachedControl;

  @override
  void initState() {
    super.initState();
    initPerformanceMixin();
    final control = ref.read(layoutStateProvider).getControlById(widget.id);
    final channel = control?.channel ?? widget.channel;
    final ccX = control?.defaultCc ?? widget.ccX;
    final ccY = control?.secondaryCc ?? widget.ccY;

    final controlState = ref.read(controlStateProvider);
    final hotX = controlState.ccValues["$channel:$ccX"];
    final hotY = controlState.ccValues["$channel:$ccY"];

    if (hotX != null) {
      _normalizedX = hotX / 127.0;
    }
    if (hotY != null) {
      _normalizedY = hotY / 127.0;
    }

    final controlSub = ref.read(layoutStateProvider).getControlById(widget.id);
    final channelSub = controlSub?.channel ?? widget.channel;
    final ccXSub = controlSub?.defaultCc ?? widget.ccX;
    final ccYSub = controlSub?.secondaryCc ?? widget.ccY;

    addManagedSubscription(
      ref.listenManual(hotCcValueProvider("$channelSub:$ccXSub"), (
        previous,
        next,
      ) {
        if (next is AsyncData) {
          final valX = next.value;
          if (valX != null && valX != _lastPolledX) {
            _lastPolledX = valX;
            _handleXUpdate(valX);
          }
        }
      }),
    );
    addManagedSubscription(
      ref.listenManual(hotCcValueProvider("$channelSub:$ccYSub"), (
        previous,
        next,
      ) {
        if (next is AsyncData) {
          final valY = next.value;
          if (valY != null && valY != _lastPolledY) {
            _lastPolledY = valY;
            _handleYUpdate(valY);
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

  void _showConfigMenu() {
    showDialog(
      context: context,
      builder: (context) => ControlConfigModal(
        controlId: widget.id,
        identifierLabel: 'X Axis MIDI ID (e.g., 20 or C3)',
        secondaryIdentifierLabel: 'Y Axis MIDI ID (e.g., 21 or C#3)',
        displayNameLabel: 'XY Pad Name',
      ),
    );
  }

  void _handleXUpdate(int val) {
    if (_isDragging) return;
    if (!mounted) return;

    final control = ref.read(layoutStateProvider).getControlById(widget.id);
    final invertX = control?.invertX ?? widget.invertX;
    final norm = val / 127.0;

    setState(() {
      _normalizedX = invertX ? 1.0 - norm : norm;
    });
  }

  void _handleYUpdate(int val) {
    if (_isDragging) return;
    if (!mounted) return;

    final control = ref.read(layoutStateProvider).getControlById(widget.id);
    final invertY = control?.invertY ?? widget.invertY;
    final norm = val / 127.0;

    setState(() {
      _normalizedY = invertY ? 1.0 - norm : norm;
    });
  }

  void _handleDragStart(DragStartDetails details, Size size) {
    setState(() {
      _isDragging = true;
    });
    _cachedControl = ref.read(layoutStateProvider).getControlById(widget.id);
    _updatePosition(details.localPosition, size, isFinal: false);
  }

  void _updatePosition(
    Offset localPosition,
    Size size, {
    required bool isFinal,
  }) {
    final double nx = (localPosition.dx / size.width).clamp(0.0, 1.0);
    final double ny = (localPosition.dy / size.height).clamp(0.0, 1.0);

    setState(() {
      _normalizedX = nx;
      _normalizedY = ny;
    });

    _sendMidi(isFinal: isFinal);
  }

  static const int _kTransmissionThrottleMs = 8;

  void _sendMidi({required bool isFinal}) {
    if (!_canSend && !isFinal) {
      setState(() => _isDragging = true);
      _hasPendingSend = true;
      return;
    }

    _canSend = false;
    _hasPendingSend = false;
    _throttleTimer?.cancel();

    _throttleTimer = Timer(
      const Duration(milliseconds: _kTransmissionThrottleMs),
      () {
        _canSend = true;
        if (_hasPendingSend && mounted && _isDragging) {
          _sendMidi(isFinal: false);
        }
      },
    );

    final effectiveCcX = _cachedControl?.defaultCc ?? widget.ccX;
    final effectiveCcY = _cachedControl?.secondaryCc ?? widget.ccY;
    final effectiveChannel = _cachedControl?.channel ?? widget.channel;
    final effectiveInvertX = _cachedControl?.invertX ?? widget.invertX;
    final effectiveInvertY = _cachedControl?.invertY ?? widget.invertY;

    final effectiveX = effectiveInvertX ? 1.0 - _normalizedX : _normalizedX;
    final effectiveY = effectiveInvertY ? 1.0 - _normalizedY : _normalizedY;

    final valX = (effectiveX * 127).round().clamp(0, 127);
    final valY = (effectiveY * 127).round().clamp(0, 127);

    final service = ref.read(midiServiceProvider);

    // Batch these closely together
    service.sendCC(
      effectiveCcX,
      valX,
      channel: effectiveChannel,
      isFinal: isFinal,
    );
    service.sendCC(
      effectiveCcY,
      valY,
      channel: effectiveChannel,
      isFinal: isFinal,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Reactively update local state and subscriptions when global layout state changes
    ref.listen(layoutStateProvider.select((s) => s.getControlById(widget.id)), (
      prev,
      next,
    ) {
      _cachedControl = next;
      if (prev != next) {
        _lastPolledX = null;
        _lastPolledY = null;
        clearManagedResources();
        final channelSub = next?.channel ?? widget.channel;
        final ccXSub = next?.defaultCc ?? widget.ccX;
        final ccYSub = next?.secondaryCc ?? widget.ccY;

        addManagedSubscription(
          ref.listenManual(hotCcValueProvider("$channelSub:$ccXSub"), (
            previous,
            current,
          ) {
            if (current is AsyncData) {
              final valX = current.value;
              if (valX != null && valX != _lastPolledX) {
                _lastPolledX = valX;
                _handleXUpdate(valX);
              }
            }
          }),
        );
        addManagedSubscription(
          ref.listenManual(hotCcValueProvider("$channelSub:$ccYSub"), (
            previous,
            current,
          ) {
            if (current is AsyncData) {
              final valY = current.value;
              if (valY != null && valY != _lastPolledY) {
                _lastPolledY = valY;
                _handleYUpdate(valY);
              }
            }
          }),
        );
      }
    });

    final control = ref.watch(
      layoutStateProvider.select((s) => s.getControlById(widget.id)),
    );
    final ccX = control?.defaultCc ?? widget.ccX;
    final ccY = control?.secondaryCc ?? widget.ccY;
    final invertX = control?.invertX ?? widget.invertX;
    final invertY = control?.invertY ?? widget.invertY;

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);

          return GestureDetector(
            onPanStart: (details) => _handleDragStart(details, size),
            onPanUpdate: (details) {
              _updatePosition(details.localPosition, size, isFinal: false);
            },
            onPanEnd: (details) {
              setState(() {
                _isDragging = false;
              });
              // Send final definitive update
              _sendMidi(isFinal: true);
            },
            onPanCancel: () {
              setState(() {
                _isDragging = false;
              });
              _sendMidi(isFinal: true);
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              decoration: BoxDecoration(
                color: widget.padColor,
                borderRadius: BorderRadius.zero,
                border: Border.all(
                  color: _isDragging
                      ? const Color(0xFFA6C9F8)
                      : const Color(0xFF111318).withValues(alpha: 0.5),
                  width: _isDragging ? 2.0 : 1.0,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.zero,
                child: Stack(
                  children: [
                    // Center guide lines
                    CustomPaint(size: Size.infinite, painter: _XYGridPainter()),
                    // Active crosshairs
                    Positioned(
                      left: _normalizedX * size.width - 0.5,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 1,
                        color: _isDragging
                            ? const Color(0xFFA6C9F8)
                            : const Color(0xFFA6C9F8).withValues(alpha: 0.3),
                      ),
                    ),
                    Positioned(
                      top: _normalizedY * size.height - 0.5,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 1,
                        color: _isDragging
                            ? const Color(0xFFA6C9F8)
                            : const Color(0xFFA6C9F8).withValues(alpha: 0.3),
                      ),
                    ),
                    // Touch Point Marker
                    Positioned(
                      left: (_normalizedX * size.width) - 15,
                      top: (_normalizedY * size.height) - 15,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isDragging
                              ? const Color(0xFFA6C9F8).withValues(alpha: 0.8)
                              : const Color(0xFFA6C9F8).withValues(alpha: 0.4),
                          border: Border.all(
                            color: const Color(0xFFA6C9F8),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    // Live Readouts
                    Positioned(
                      top: 8,
                      right: 8,
                      child: ConfigGestureWrapper(
                        id: '${widget.id}_x_readout',
                        isDragging: _isDragging,
                        onConfigRequested: _showConfigMenu,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 60,
                            minHeight: 60,
                          ),
                          alignment: Alignment.topRight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                ((invertX
                                            ? (1.0 - _normalizedX)
                                            : _normalizedX) *
                                        127)
                                    .round()
                                    .toString()
                                    .padLeft(3, '0'),
                                style: const TextStyle(
                                  fontFamily: 'DSEG7Modern',
                                  color: Color(0xFFA6C9F8),
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'X: CC$ccX',
                                style: AppText.performance(
                                  color: Colors.white24,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: ConfigGestureWrapper(
                        id: '${widget.id}_y_readout',
                        isDragging: _isDragging,
                        onConfigRequested: _showConfigMenu,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 60,
                            minHeight: 60,
                          ),
                          alignment: Alignment.bottomLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Y: CC$ccY',
                                style: AppText.performance(
                                  color: Colors.white24,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                ((invertY
                                            ? (1.0 - _normalizedY)
                                            : _normalizedY) *
                                        127)
                                    .round()
                                    .toString()
                                    .padLeft(3, '0'),
                                style: const TextStyle(
                                  fontFamily: 'DSEG7Modern',
                                  color: Color(0xFFA6C9F8),
                                  fontSize: 16,
                                ),
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
          );
        },
      ),
    );
  }
}

class _XYGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
