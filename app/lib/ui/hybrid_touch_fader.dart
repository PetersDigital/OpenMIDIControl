// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'open_midi_screen.dart'; // For FaderBehavior type
import 'midi_service.dart';
import 'midi_settings_state.dart';
import 'widgets/control_config_modal.dart';

const _kFaderSmoothingDuration = Duration(milliseconds: 45);

class HybridTouchFader extends ConsumerStatefulWidget {
  final int ccNumber;
  final String label;
  final Color activeColor;
  final Color labelColor;
  final double initialValue;
  final bool isMobile;
  final FaderBehavior behavior;

  const HybridTouchFader({
    super.key,
    required this.ccNumber,
    required this.label,
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
  late AnimationController _progressController;
  late int _ccNumber;
  late String _ccLabel;

  // Gesture state for configuration
  DateTime? _lastTapTime;
  int _tapCount = 0;
  bool _isTapHoldCandidate = false;
  bool _isLongHold = false;
  Timer? _configTimer;
  Timer? _tapResetTimer;
  bool _isDown = false;

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
    _ccLabel = widget.label;

    // Restore value from session state if available, otherwise use initialValue
    final hotValue = ref.read(hotCcValueProvider("0:$_ccNumber")).asData?.value;
    final startValue = hotValue != null
        ? hotValue / 127.0
        : widget.initialValue;

    _animationController = AnimationController(
      vsync: this,
      value: startValue.clamp(0.0, 1.0),
    );

    _progressController = AnimationController(vsync: this);

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
    _progressController.dispose();
    _ccSubscription?.close();
    _configTimer?.cancel();
    _tapResetTimer?.cancel();
    super.dispose();
  }

  void _sendMidiUpdate({bool isFinal = false}) {
    final int ccValue = (_animationController.value * 127).round();
    ref
        .read(midiServiceProvider)
        .sendCC(_ccNumber, ccValue, channel: 0, isFinal: isFinal);
  }

  void _handlePanDown(DragDownDetails details, BoxConstraints constraints) {
    final now = DateTime.now();
    final timeSinceLastTap = _lastTapTime != null
        ? now.difference(_lastTapTime!)
        : const Duration(seconds: 1);

    final mode = ref.read(configGestureModeProvider);

    if (mode == ConfigGestureMode.doubleTapHold) {
      _isTapHoldCandidate =
          _tapCount == 1 && timeSinceLastTap.inMilliseconds < 400;
    } else {
      // Single tap-hold mode: Trigger on first touch (Long Press behavior)
      _isTapHoldCandidate = true;
    }

    setState(() {
      _isDown = true;
      _isLongHold = false;
      _isDragging = false; // Will become true once we actually start dragging
    });

    if (_isTapHoldCandidate) {
      final durationSecs = ref.read(safetyHoldDurationProvider);
      final duration = Duration(milliseconds: (durationSecs * 1000).toInt());

      _progressController.duration = duration;
      _progressController.forward(from: 0);
      _configTimer?.cancel();
      _configTimer = Timer(duration, () {
        if (_isDown && _isTapHoldCandidate && !_isDragging) {
          setState(() => _isLongHold = true);
          _progressController.reset();
          _showConfigMenu();
        }
      });
    }

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
      setState(() => _isDragging = true);
      _sendMidiUpdateThrottled();
      return;
    }

    if (widget.behavior == FaderBehavior.catchUp && _isCatchingUp) {
      final handleY =
          (1.0 - _animationController.value) * constraints.maxHeight;
      final touchY = details.localPosition.dy;

      bool crossed = false;
      if (_mustCrossMovingUp && touchY <= handleY) crossed = true;
      if (!_mustCrossMovingUp && touchY >= handleY) crossed = true;

      if (crossed) {
        _isCatchingUp = false;
      } else {
        return; // Waiting to cross the threshold, ignore this interaction
      }
    }

    // Standard Jump response
    _applyAbsolutePosition(details.localPosition.dy, constraints.maxHeight);
  }

  void _applyAbsolutePosition(double localY, double maxHeight) {
    setState(() => _isDragging = true);
    _animationController.value = (1.0 - (localY / maxHeight)).clamp(0.0, 1.0);
    _sendMidiUpdateThrottled();
  }

  void _sendMidiUpdateThrottled() {
    final nowMs = _throttleStopwatch.elapsedMilliseconds;
    if (nowMs - _lastMidiUpdateTimeMs < _midiUpdateThrottleMs) {
      return; // Throttle to prevent MIDI flooding
    }
    _lastMidiUpdateTimeMs = nowMs;
    _sendMidiUpdate();
  }

  void _handleCcUpdate(int? previous, int? next) {
    if (next == null || next == previous) return;

    if (_isDragging) {
      // If we are touching it, the hardware is now out of sync with our finger.
      // So the next time we let go, the hardware will need to catch up again.
      _hardwareIsCatchingUp = true;
      _lastHardwareValue = null;
      _pendingIncomingNormalized = null; // discard pending
      return; // Prevent echo feedback loop
    }

    _pendingIncomingNormalized = (next / 127.0).clamp(0.0, 1.0);

    if (!_isIncomingUpdateScheduled) {
      _isIncomingUpdateScheduled = true;
      SchedulerBinding.instance.scheduleFrameCallback((_) {
        if (!mounted) return;
        _isIncomingUpdateScheduled = false;

        final incomingNormalized = _pendingIncomingNormalized;
        if (incomingNormalized == null) return;

        if (widget.behavior == FaderBehavior.jump) {
          _animateToIncomingValue(incomingNormalized);
          return;
        }

        if (widget.behavior == FaderBehavior.catchUp ||
            widget.behavior == FaderBehavior.hybrid) {
          // If the hardware was just moved after the user let go of the screen, determine direction
          if (_hardwareIsCatchingUp) {
            if (_lastHardwareValue == null) {
              // First movement of hardware detected. Determine which way it needs to go to cross the app's value.
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
          onPointerUp: (e) {
            setState(() {
              _isDown = false;
              _isTapHoldCandidate = false;
              _progressController.reset();
              _configTimer?.cancel();
            });
          },
          onPointerCancel: (e) {
            setState(() {
              _isDown = false;
              _isTapHoldCandidate = false;
              _progressController.reset();
              _configTimer?.cancel();
            });
          },
          behavior: HitTestBehavior.opaque,
          child: GestureDetector(
            onVerticalDragStart: (d) => _handleDragStart(d, constraints),
            onVerticalDragUpdate: (d) => _handleDragUpdate(d, constraints),
            onVerticalDragCancel: () {
              setState(() {
                _isDragging = false;
                _isDown = false;
                _isTapHoldCandidate = false;
              });
              _configTimer?.cancel();
              _progressController.reset();
              _sendMidiUpdate(isFinal: true);
            },
            onVerticalDragEnd: (_) {
              setState(() {
                _isDragging = false;
                _isDown = false;
                _isTapHoldCandidate = false;
              });
              _configTimer?.cancel();
              _progressController.reset();
              _sendMidiUpdate(isFinal: true);
            },
            onTap: () {
              _lastTapTime = DateTime.now();
              _tapCount++;
              _tapResetTimer?.cancel();
              _tapResetTimer = Timer(const Duration(milliseconds: 600), () {
                _tapCount = 0;
              });
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
                        IgnorePointer(
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
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
                        ),

                        // CC Name Label (long-press to open CC picker)
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          child: Text(
                            _ccLabel,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: Colors.white,
                              fontSize: labelFontSize,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Config Hold Progress
                  if (_isDown &&
                      !_isLongHold &&
                      !_isDragging &&
                      _isTapHoldCandidate)
                    Center(
                      child: AnimatedBuilder(
                        animation: _progressController,
                        builder: (context, child) {
                          return SizedBox(
                            width: 80,
                            height: 80,
                            child: CircularProgressIndicator(
                              value: _progressController.value,
                              strokeWidth: 4,
                              color: Colors.white.withValues(alpha: 0.6),
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.1,
                              ),
                            ),
                          );
                        },
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
}
