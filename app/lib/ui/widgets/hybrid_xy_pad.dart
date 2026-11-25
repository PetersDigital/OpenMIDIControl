// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design_system.dart';
import '../midi_service.dart';
import '../midi_action_dispatcher.dart';
import '../performance_ticker_mixin.dart';
import 'control_config_modal.dart';
import 'config_gesture_wrapper.dart';
import '../layout_state.dart';
import '../../core/models/layout_models.dart';
import '../../core/models/action_payload.dart';

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
    this.isActive = true,
  });

  final bool isActive;

  @override
  ConsumerState<HybridXYPad> createState() => _HybridXYPadState();
}

class _HybridXYPadState extends ConsumerState<HybridXYPad>
    with TickerProviderStateMixin, PerformanceTickerMixin {
  bool _isDragging = false;
  final ValueNotifier<Offset> _posNotifier = ValueNotifier<Offset>(
    const Offset(0.5, 0.5),
  );
  double get _normalizedX => _posNotifier.value.dx;
  double get _normalizedY => _posNotifier.value.dy;

  Timer? _throttleTimer;
  bool _canSend = true;
  bool _hasPendingSend = false;

  // No ticker needed for idle interaction
  int? _lastPolledX;
  int? _lastPolledY;

  LayoutControl? _cachedControl;
  final _xAction = MidiActionDispatcher();
  final _yAction = MidiActionDispatcher();

  int get _channel => _cachedControl?.channel ?? widget.channel;
  int get _ccX => _cachedControl?.defaultCc ?? widget.ccX;
  int get _ccY => _cachedControl?.secondaryCc ?? widget.ccY;
  bool get _invertX => _cachedControl?.invertX ?? widget.invertX;
  bool get _invertY => _cachedControl?.invertY ?? widget.invertY;
  double get _midiX => _invertX ? 1.0 - _normalizedX : _normalizedX;
  double get _midiY => _invertY ? 1.0 - _normalizedY : _normalizedY;
  String? get _feedbackX =>
      ccFeedbackAddress(_cachedControl?.payload, _channel, _ccX);
  String? get _feedbackY =>
      ccFeedbackAddress(_cachedControl?.secondaryPayload, _channel, _ccY);

  String _axisLabel(ActionPayload? payload, int legacyCc) => switch (payload) {
    CcPayload(:final cc) => 'CC$cc',
    null => 'CC$legacyCc',
    _ => payload.displayLabel,
  };

  @override
  void initState() {
    super.initState();
    initPerformanceMixin();
    _cachedControl = ref.read(layoutStateProvider).getControlById(widget.id);

    final controlState = ref.read(controlStateProvider);
    final hotX = controlState.ccValues[_feedbackX];
    final hotY = controlState.ccValues[_feedbackY];

    final double initX = hotX != null ? hotX / 127.0 : 0.5;
    final double initY = hotY != null ? hotY / 127.0 : 0.5;
    _posNotifier.value = Offset(initX, initY);

    if (widget.isActive) {
      _setupMidiListeners();
    }
  }

  void _setupMidiListeners() {
    clearManagedSubscriptions();
    final feedbackX = _feedbackX;
    final feedbackY = _feedbackY;
    if (feedbackX != null) {
      addManagedSubscription(
        ref.listenManual(hotCcValueProvider(feedbackX), (previous, next) {
          if (!widget.isActive) return;
          if (next is AsyncData) {
            final valX = next.value;
            if (valX != null && valX != _lastPolledX) {
              _lastPolledX = valX;
              _handleXUpdate(valX);
            }
          }
        }),
      );
    }
    if (feedbackY != null) {
      addManagedSubscription(
        ref.listenManual(hotCcValueProvider(feedbackY), (previous, next) {
          if (!widget.isActive) return;
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
  }

  @override
  void didUpdateWidget(HybridXYPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        // Re-setup listeners
        _setupMidiListeners();
        // Re-sync values when coming back to foreground
        final controlState = ref.read(controlStateProvider);
        final hotX = controlState.ccValues[_feedbackX];
        final hotY = controlState.ccValues[_feedbackY];

        double nextX = _normalizedX;
        double nextY = _normalizedY;
        if (hotX != null) {
          final normX = hotX / 127.0;
          nextX = _invertX ? 1.0 - normX : normX;
        }
        if (hotY != null) {
          final normY = hotY / 127.0;
          nextY = _invertY ? 1.0 - normY : normY;
        }
        _posNotifier.value = Offset(nextX, nextY);
      } else {
        // Suspend resources
        clearManagedSubscriptions();
        _throttleTimer?.cancel();
        _canSend = true;
        _hasPendingSend = false;
        _xAction.end();
        _yAction.end();
      }
    }
  }

  @override
  void onAppLifecycleChanged(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _throttleTimer?.cancel();
      _canSend = true;
      _hasPendingSend = false;
      _xAction.end();
      _yAction.end();
    }
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    _xAction.end();
    _yAction.end();
    _posNotifier.dispose();
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
    final nextX = invertX ? 1.0 - norm : norm;
    _posNotifier.value = Offset(nextX, _normalizedY);
  }

  void _handleYUpdate(int val) {
    if (_isDragging) return;
    if (!mounted) return;

    final control = ref.read(layoutStateProvider).getControlById(widget.id);
    final invertY = control?.invertY ?? widget.invertY;
    final norm = val / 127.0;
    final nextY = invertY ? 1.0 - norm : norm;
    _posNotifier.value = Offset(_normalizedX, nextY);
  }

  void _handleDragStart(DragStartDetails details, Size size) {
    setState(() {
      _isDragging = true;
    });
    _updatePosition(details.localPosition, size, begin: true);
  }

  void _updatePosition(Offset localPosition, Size size, {bool begin = false}) {
    final double nx = (localPosition.dx / size.width).clamp(0.0, 1.0);
    final double ny = (localPosition.dy / size.height).clamp(0.0, 1.0);

    _posNotifier.value = Offset(nx, ny);

    if (begin) {
      final service = ref.read(midiServiceProvider);
      _xAction.begin(service, _cachedControl?.payload, _midiX);
      _yAction.begin(service, _cachedControl?.secondaryPayload, _midiY);
    }
    _sendMidi(isFinal: false);
  }

  static const int _kTransmissionThrottleMs = 8;

  void _sendMidi({required bool isFinal}) {
    if (!_canSend && !isFinal) {
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

    final service = ref.read(midiServiceProvider);
    _xAction.sendPosition(
      service,
      _cachedControl?.payload,
      _midiX,
      legacyChannel: _channel,
      legacyCc: _ccX,
      isFinal: isFinal,
    );
    _yAction.sendPosition(
      service,
      _cachedControl?.secondaryPayload,
      _midiY,
      legacyChannel: _channel,
      legacyCc: _ccY,
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
      if (prev?.payload != next?.payload) _xAction.end();
      if (prev?.secondaryPayload != next?.secondaryPayload) _yAction.end();
      _cachedControl = next;
      if (prev != next) {
        _lastPolledX = null;
        _lastPolledY = null;
        if (!widget.isActive) return;
        _setupMidiListeners();
      }
    });

    final control = ref.watch(
      layoutStateProvider.select((s) => s.getControlById(widget.id)),
    );
    final labelX = _axisLabel(
      control?.payload,
      control?.defaultCc ?? widget.ccX,
    );
    final labelY = _axisLabel(
      control?.secondaryPayload,
      control?.secondaryCc ?? widget.ccY,
    );
    final invertX = control?.invertX ?? widget.invertX;
    final invertY = control?.invertY ?? widget.invertY;

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);

          return GestureDetector(
            onPanStart: (details) => _handleDragStart(details, size),
            onPanUpdate: (details) {
              _updatePosition(details.localPosition, size);
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
                    // Static center guide lines (never repainted on drag)
                    const CustomPaint(
                      size: Size.infinite,
                      painter: _XYGridPainter(),
                    ),
                    // Dynamic crosshairs & touch marker isolated in inner RepaintBoundary
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: ValueListenableBuilder<Offset>(
                          valueListenable: _posNotifier,
                          builder: (context, pos, _) {
                            final nx = pos.dx;
                            final ny = pos.dy;
                            return Stack(
                              children: [
                                Positioned(
                                  left: nx * size.width - 0.5,
                                  top: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 1,
                                    color: _isDragging
                                        ? const Color(0xFFA6C9F8)
                                        : const Color(
                                            0xFFA6C9F8,
                                          ).withValues(alpha: 0.3),
                                  ),
                                ),
                                Positioned(
                                  top: ny * size.height - 0.5,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: 1,
                                    color: _isDragging
                                        ? const Color(0xFFA6C9F8)
                                        : const Color(
                                            0xFFA6C9F8,
                                          ).withValues(alpha: 0.3),
                                  ),
                                ),
                                Positioned(
                                  left: (nx * size.width) - 15,
                                  top: (ny * size.height) - 15,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _isDragging
                                          ? const Color(
                                              0xFFA6C9F8,
                                            ).withValues(alpha: 0.8)
                                          : const Color(
                                              0xFFA6C9F8,
                                            ).withValues(alpha: 0.4),
                                      border: Border.all(
                                        color: const Color(0xFFA6C9F8),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    // Live Readouts
                    Positioned(
                      top: 8,
                      right: 8,
                      child: ConfigGestureWrapper(
                        id: '${widget.id}_x_readout',
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
                              RepaintBoundary(
                                child: ValueListenableBuilder<Offset>(
                                  valueListenable: _posNotifier,
                                  builder: (_, pos, _) {
                                    final val =
                                        ((invertX ? (1.0 - pos.dx) : pos.dx) *
                                                127)
                                            .round()
                                            .toString()
                                            .padLeft(3, '0');
                                    return Text(
                                      val,
                                      style: const TextStyle(
                                        fontFamily: 'DSEG7Modern',
                                        color: Color(0xFFA6C9F8),
                                        fontSize: 16,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Text(
                                'X: $labelX',
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
                                'Y: $labelY',
                                style: AppText.performance(
                                  color: Colors.white24,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              RepaintBoundary(
                                child: ValueListenableBuilder<Offset>(
                                  valueListenable: _posNotifier,
                                  builder: (_, pos, _) {
                                    final val =
                                        ((invertY ? (1.0 - pos.dy) : pos.dy) *
                                                127)
                                            .round()
                                            .toString()
                                            .padLeft(3, '0');
                                    return Text(
                                      val,
                                      style: const TextStyle(
                                        fontFamily: 'DSEG7Modern',
                                        color: Color(0xFFA6C9F8),
                                        fontSize: 16,
                                      ),
                                    );
                                  },
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
  const _XYGridPainter();

  static final Paint _gridPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.05)
    ..strokeWidth = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      _gridPaint,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      _gridPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
