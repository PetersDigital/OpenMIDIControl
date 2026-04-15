// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'open_midi_screen.dart'; // For FaderBehavior type
import 'midi_service.dart';

// Common CC options for the popup menu
const List<Map<String, dynamic>> _kCCOptions = [
  {'cc': 1, 'name': 'Modulation'},
  {'cc': 2, 'name': 'Breath'},
  {'cc': 7, 'name': 'Volume'},
  {'cc': 10, 'name': 'Pan'},
  {'cc': 11, 'name': 'Expression'},
  {'cc': 64, 'name': 'Sustain'},
  {'cc': 71, 'name': 'Resonance'},
  {'cc': 74, 'name': 'Brightness'},
];

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
    with SingleTickerProviderStateMixin {
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

  @override
  void initState() {
    super.initState();
    _throttleStopwatch = Stopwatch()..start();
    _animationController = AnimationController(
      vsync: this,
      value: widget.initialValue.clamp(0.0, 1.0),
    );
    // ⚡ Bolt: Removed .addListener(() { setState(() {}); })
    // to prevent full widget tree rebuilds at 120Hz.
    // Dynamic elements now use AnimatedBuilder directly.
    _ccNumber = widget.ccNumber;
    _ccLabel = widget.label;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _sendMidiUpdate({bool isFinal = false}) {
    final int ccValue = (_animationController.value * 127).round();
    ref.read(midiServiceProvider).sendCC(_ccNumber, ccValue, isFinal: isFinal);
  }

  void _handlePanDown(DragDownDetails details, BoxConstraints constraints) {
    // Only lock the fader from incoming MIDI, don't change values yet
    _isDragging = true;

    if (widget.behavior == FaderBehavior.catchUp) {
      final handleY =
          (1.0 - _animationController.value) * constraints.maxHeight;
      final touchY = details.localPosition.dy;

      // If we touch almost exactly on the handle line (within 20 pixels), grab immediately
      if ((touchY - handleY).abs() < 20.0) {
        _isCatchingUp = false;
      } else {
        _isCatchingUp = true;
        // If touch is physically lower on screen (higher Y value), we must drag UP (decreasing Y) to cross
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

  void _showCCMenu(BuildContext context, Offset offset) async {
    final selected = await showMenu<Map<String, dynamic>>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy,
        offset.dx + 1,
        offset.dy + 1,
      ),
      color: const Color(0xFF1E2024),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      items: _kCCOptions.map((option) {
        final isSelected = option['cc'] == _ccNumber;
        return PopupMenuItem<Map<String, dynamic>>(
          value: option,
          child: Text(
            'CC${option['cc']} – ${option['name']}',
            style: TextStyle(
              fontFamily: 'Inter',
              color: isSelected ? const Color(0xFFA6C9F8) : Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
    );
    if (selected != null) {
      setState(() {
        _ccNumber = selected['cc'] as int;
        _ccLabel =
            'CC${selected['cc']}\n${(selected['name'] as String).toUpperCase()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to external MIDI CC updates for this specific fader's CC only.
    // .select() ensures this listener only fires when our CC value changes.
    ref.listen<
      int?
    >(ccValuesProvider.select((state) => state.ccValues[_ccNumber]), (
      previous,
      next,
    ) {
      if (next == null || next == previous) return;

      if (_isDragging) {
        // If we are touching it, the hardware is now out of sync with our finger.
        // So the next time we let go, the hardware will need to catch up again.
        _hardwareIsCatchingUp = true;
        _lastHardwareValue = null;
        return; // Prevent echo feedback loop
      }

      final incomingNormalized = (next / 127.0).clamp(0.0, 1.0);

      if (widget.behavior == FaderBehavior.jump) {
        // Smoothly interpolate the value using _kFaderSmoothingDuration fallback
        // to avoid 120Hz animation cancellation churn.
        _animationController.animateTo(
          incomingNormalized,
          duration: _kFaderSmoothingDuration,
          curve: Curves.linear,
        );
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

    final double labelFontSize = widget.isMobile ? 14.0 : 18.0;
    final double displayFontSize = widget.isMobile ? 40.0 : 60.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanDown: (d) => _handlePanDown(d, constraints),
          onVerticalDragStart: (d) => _handleDragStart(d, constraints),
          onVerticalDragUpdate: (d) => _handleDragUpdate(d, constraints),
          onVerticalDragCancel: () {
            _isDragging = false;
            _sendMidiUpdate(isFinal: true);
          },
          onVerticalDragEnd: (_) {
            _isDragging = false;
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
                  builder: (context, child) {
                    return FractionallySizedBox(
                      heightFactor: _animationController.value,
                      widthFactor: 1.0,
                      alignment: Alignment.bottomCenter,
                      child: Container(color: widget.activeColor),
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
                                style: TextStyle(
                                  fontFamily: 'DSEG7Modern',
                                  fontSize: displayFontSize,
                                  color: Colors.red.withValues(alpha: 0.06),
                                  height: 1.0,
                                ),
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
                                    style: TextStyle(
                                      fontFamily: 'DSEG7Modern',
                                      fontSize: displayFontSize,
                                      color: Colors.red,
                                      height: 1.0,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      // CC Name Label (long-press to open CC picker)
                      const SizedBox(height: 8),
                      Builder(
                        builder: (labelContext) => GestureDetector(
                          onLongPressStart: (details) {
                            _showCCMenu(context, details.globalPosition);
                          },
                          behavior: HitTestBehavior.translucent,
                          child: Padding(
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
                                // No text shadow — easier to read as requested
                              ),
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
        );
      },
    );
  }
}
