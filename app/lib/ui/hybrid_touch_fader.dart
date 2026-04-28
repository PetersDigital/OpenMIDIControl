// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'open_midi_screen.dart'; // For FaderBehavior type
import 'design_system.dart';
import 'midi_service.dart';
import 'widgets/control_config_modal.dart';
import 'widgets/config_gesture_wrapper.dart';
import 'widgets/rename_control_dialog.dart';
import 'layout_state.dart';

const _kFaderSmoothingDuration = Duration(milliseconds: 45);

class HybridTouchFader extends ConsumerStatefulWidget {
  final String controlId;
  final int ccNumber;
  final String displayName;
  final Color activeColor;
  final Color labelColor;
  final double initialValue;
  final bool isMobile;
  final FaderBehavior behavior;

  const HybridTouchFader({
    super.key,
    required this.controlId,
    required this.ccNumber,
    required this.displayName,
    required this.activeColor,
    required this.labelColor,
    this.initialValue = 0.0,
    this.isMobile = true,
    this.behavior = FaderBehavior.jump,
  });

  @override
  ConsumerState<HybridTouchFader> createState() => _HybridTouchFaderState();
}

class _HybridTouchFaderState extends ConsumerState<HybridTouchFader>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late int _ccNumber;
  late String _ccLabel;

  // Monotonic clock for reliable MIDI throttling (immune to system clock changes)
  late final Stopwatch _throttleStopwatch;

  // Track if user is actively dragging to prevent external MIDI echo feedback
  bool _isDragging = false;

  // State for touch Catch-up behavior (App -> Hardware)
  bool _isCatchingUp = false;
  bool _mustCrossMovingUp = false;

  // State for hardware Catch-up behavior (Hardware -> App)
  bool _hardwareIsCatchingUp = true;
  bool _hardwareMustCrossMovingUp = false;
  double? _lastHardwareValue;

  double? _pendingIncomingNormalized;
  bool _isIncomingUpdateScheduled = false;

  SpringSimulation? _springSimulation;
  ProviderSubscription<AsyncValue<int>>? _ccSubscription;

  @override
  void initState() {
    super.initState();
    _throttleStopwatch = Stopwatch()..start();
    _ccNumber = widget.ccNumber;
    _ccLabel = widget.displayName;

    // Restore value from session state if available, otherwise use initialValue
    final hotValue = ref.read(hotCcValueProvider("0:$_ccNumber")).asData?.value;
    final startValue = hotValue != null
        ? hotValue / 127.0
        : widget.initialValue;

    _animationController = AnimationController(
      vsync: this,
      value: startValue.clamp(0.0, 1.0),
    );

    _setupListener();
  }

  void _setupListener() {
    _ccSubscription?.close();
    _ccSubscription = ref.listenManual<AsyncValue<int>>(
      hotCcValueProvider("0:$_ccNumber"),
      (previous, next) =>
          next.whenData((val) => _handleCcUpdate(previous?.asData?.value, val)),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _ccSubscription?.close();
    super.dispose();
  }

  void _sendMidiUpdate({bool isFinal = false}) {
    final int ccValue = (_animationController.value * 127).round();
    ref
        .read(midiServiceProvider)
        .sendCC(_ccNumber, ccValue, channel: 0, isFinal: isFinal);
  }

  void _handlePanDown(DragDownDetails details, BoxConstraints constraints) {
    setState(() {
      _isDragging = false; // Will become true once we actually start dragging
    });

    if (widget.behavior == FaderBehavior.catchUp) {
      final handleY =
          (1.0 - _animationController.value) * constraints.maxHeight;
      final touchY = details.localPosition.dy;

      if ((touchY - handleY).abs() < 20.0) {
        _isCatchingUp = false;
      } else {
        _isCatchingUp = true;
        _mustCrossMovingUp = touchY > handleY;
      }
    }
  }

  void _handleDragStart(DragStartDetails details, BoxConstraints constraints) {
    if (widget.behavior == FaderBehavior.jump) {
      _applyAbsolutePosition(details.localPosition.dy, constraints.maxHeight);
      return;
    }

    if (widget.behavior == FaderBehavior.catchUp && !_isCatchingUp) {
      _applyAbsolutePosition(details.localPosition.dy, constraints.maxHeight);
    }
  }

  // Throttle MIDI updates to prevent flooding during rapid touch movement
  int _lastMidiUpdateTimeMs = 0;
  static const _midiUpdateThrottleMs = 8; // ~120Hz max

  void _handleDragUpdate(
    DragUpdateDetails details,
    BoxConstraints constraints,
  ) {
    if (widget.behavior == FaderBehavior.hybrid) {
      _animationController.value =
          (_animationController.value -
                  (details.delta.dy / constraints.maxHeight))
              .clamp(0.0, 1.0);
    } else if (widget.behavior == FaderBehavior.jump) {
      _applyAbsolutePosition(details.localPosition.dy, constraints.maxHeight);
    } else if (widget.behavior == FaderBehavior.catchUp) {
      if (_isCatchingUp) {
        final handleY =
            (1.0 - _animationController.value) * constraints.maxHeight;
        final touchY = details.localPosition.dy;

        bool crossed = false;
        if (_mustCrossMovingUp && touchY <= handleY) {
          crossed = true;
        } else if (!_mustCrossMovingUp && touchY >= handleY) {
          crossed = true;
        }

        if (crossed) {
          _isCatchingUp = false;
          _applyAbsolutePosition(
            details.localPosition.dy,
            constraints.maxHeight,
          );
        }
      } else {
        _applyAbsolutePosition(details.localPosition.dy, constraints.maxHeight);
      }
    }

    if (!mounted) return;

    if (!_isDragging) {
      setState(() => _isDragging = true);
    }

    final nowMs = _throttleStopwatch.elapsedMilliseconds;
    if (nowMs - _lastMidiUpdateTimeMs >= _midiUpdateThrottleMs) {
      _sendMidiUpdate();
      _lastMidiUpdateTimeMs = nowMs;
    }
  }

  void _applyAbsolutePosition(double localY, double maxHeight) {
    _animationController.value = (1.0 - (localY / maxHeight)).clamp(0.0, 1.0);
  }

  void _handleCcUpdate(int? prev, int next) {
    if (_isDragging) {
      // De-sync: The hardware is overriding the app state, but the user is dragging.
      // Set the catchup flag so when they release the app will catchup to the HW state
      _hardwareIsCatchingUp = true;
      _lastHardwareValue = null;
      return;
    }

    // Always schedule standard non-physics update if the user isn't touching it.
    // Physics handles smoothing for 'FaderBehavior.jump'.
    final incomingNormalized = (next / 127.0).clamp(0.0, 1.0);

    if (widget.behavior == FaderBehavior.jump) {
      _animateToIncomingValue(incomingNormalized);
    } else {
      _pendingIncomingNormalized = incomingNormalized;
      if (!_isIncomingUpdateScheduled) {
        _isIncomingUpdateScheduled = true;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _isIncomingUpdateScheduled = false;
          if (_pendingIncomingNormalized != null) {
            final incomingNormalized = _pendingIncomingNormalized!;

            if (_hardwareIsCatchingUp) {
              if (_lastHardwareValue == null) {
                // First update after drag release, figure out direction
                _hardwareMustCrossMovingUp =
                    incomingNormalized < _animationController.value;
                _lastHardwareValue = incomingNormalized;
                return;
              }

              // Check if it has crossed the threshold
              bool crossed = false;
              if (_hardwareMustCrossMovingUp &&
                  incomingNormalized >= _animationController.value) {
                crossed = true;
              }
              if (!_hardwareMustCrossMovingUp &&
                  incomingNormalized <= _animationController.value) {
                crossed = true;
              }

              if (crossed) {
                _hardwareIsCatchingUp = false;
                _animationController.animateTo(
                  incomingNormalized,
                  duration: _kFaderSmoothingDuration,
                  curve: Curves.linear,
                );
              }
              _lastHardwareValue = incomingNormalized;
            } else {
              // Already caught up, track normally
              _animationController.animateTo(
                incomingNormalized,
                duration: _kFaderSmoothingDuration,
                curve: Curves.linear,
              );
            }
          }
        });
      }
    }
  }

  static final _springDesc = SpringDescription.withDampingRatio(
    mass: 1.0,
    stiffness: 100.0,
    ratio: 0.9,
  );

  void _animateToIncomingValue(double incomingNormalized) {
    if (_springSimulation == null) {
      _springSimulation = SpringSimulation(
        _springDesc,
        _animationController.value,
        incomingNormalized,
        0.0,
      );
      _animationController.animateWith(_springSimulation!);
    } else {
      // Retarget the existing simulation
      _springSimulation = SpringSimulation(
        _springDesc,
        _animationController.value,
        incomingNormalized,
        _animationController.velocity,
      );
      _animationController.animateWith(_springSimulation!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPerformanceLocked = ref
        .watch(layoutStateProvider)
        .isPerformanceLocked;
    final double labelFontSize = widget.isMobile ? 14.0 : 18.0;
    final double displayFontSize = widget.isMobile ? 40.0 : 60.0;
    final TextStyle displayTextStyle = TextStyle(
      fontFamily: 'DSEG7Modern',
      fontSize: displayFontSize,
      color: Colors.red,
      height: 1.0,
    );
    final TextStyle ghostDisplayTextStyle = TextStyle(
      fontFamily: 'DSEG7Modern',
      fontSize: displayFontSize,
      color: Colors.red.withValues(alpha: 0.06),
      height: 1.0,
    );
    final Widget activeTrack = Container(color: widget.activeColor);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Listener(
          onPointerDown: (e) {
            _handlePanDown(
              DragDownDetails(localPosition: e.localPosition),
              constraints,
            );
          },
          behavior: HitTestBehavior.opaque,
          child: GestureDetector(
            onVerticalDragStart: (d) => _handleDragStart(d, constraints),
            onVerticalDragUpdate: (d) => _handleDragUpdate(d, constraints),
            onVerticalDragCancel: () {
              setState(() {
                _isDragging = false;
              });
              _sendMidiUpdate(isFinal: true);
            },
            onVerticalDragEnd: (_) {
              setState(() {
                _isDragging = false;
              });
              _sendMidiUpdate(isFinal: true);
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: const Color(0xFF111318),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // Filled active track
                  AnimatedBuilder(
                    animation: _animationController,
                    child: activeTrack,
                    builder: (context, child) {
                      return FractionallySizedBox(
                        heightFactor: _animationController.value,
                        widthFactor: 1.0,
                        alignment: Alignment.bottomCenter,
                        child: child,
                      );
                    },
                  ),

                  // Full-width TM1637 Display pinned at top with visible gap
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Black readout box — full width, top-padded
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          color: const Color(0xFF0C0E12),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Ghost segments — very faint
                              Text(
                                "888",
                                textAlign: TextAlign.center,
                                style: ghostDisplayTextStyle,
                              ),
                              // Active value
                              AnimatedBuilder(
                                animation: _animationController,
                                builder: (context, child) {
                                  final int ccValue =
                                      (_animationController.value * 127)
                                          .round();
                                  return Text(
                                    ccValue.toString().padLeft(3, ' '),
                                    textAlign: TextAlign.center,
                                    style: displayTextStyle,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        // CC Name Label (long-press to open CC picker, double-tap to rename)
                        const SizedBox(height: 8),
                        ConfigGestureWrapper(
                          id: widget.controlId,
                          isDragging: _isDragging,
                          onConfigRequested: _showConfigMenu,
                          onRenameRequested: isPerformanceLocked
                              ? null
                              : _showRenameDialog,
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 64,
                              minHeight: 44,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _ccLabel,
                              textAlign: TextAlign.center,
                              style: AppText.performance(
                                color: Colors.white,
                                fontSize: labelFontSize,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showConfigMenu() async {
    final result = await showDialog<ControlConfigResult>(
      context: context,
      builder: (context) => ControlConfigModal(
        initialChannel: 0,
        initialIdentifier: _ccNumber,
        identifierLabel: 'CC Number',
      ),
    );

    if (result != null) {
      debugPrint("Selected CC: $result");
      setState(() {
        _ccNumber = result.identifier;
        if (_ccLabel.startsWith('CC')) {
          _ccLabel = 'CC $_ccNumber';
        }
      });
      _setupListener();
    }
  }

  Future<void> _showRenameDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => RenameControlDialog(
        currentName: _ccLabel,
        controlId: widget.controlId,
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _ccLabel = result;
      });
      ref
          .read(layoutStateProvider.notifier)
          .updateControlLabel(widget.controlId, result);
    }
  }
}
