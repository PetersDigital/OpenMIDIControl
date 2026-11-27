// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'open_midi_screen.dart'; // For FaderBehavior type
import 'design_system.dart';
import 'midi_service.dart';
import 'midi_settings_state.dart' show mcuFaderProvider, mcuRouteActiveProvider;
import 'midi_action_dispatcher.dart';
import 'performance_ticker_mixin.dart';
import 'widgets/control_config_modal.dart';
import 'widgets/config_gesture_wrapper.dart';
import 'layout_state.dart';
import '../core/models/layout_models.dart';
import '../core/models/action_payload.dart';
import '../core/models/widget_style.dart';
import '../core/utils/control_value_formatter.dart';

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
  final WidgetStyle style;

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
    this.isActive = true,
    this.style = WidgetStyle.defaults,
  });

  final bool isActive;

  @override
  ConsumerState<HybridTouchFader> createState() => _HybridTouchFaderState();
}

class _HybridTouchFaderState extends ConsumerState<HybridTouchFader>
    with TickerProviderStateMixin, PerformanceTickerMixin {
  late AnimationController _animationController;
  late int _ccNumber;
  int _midiChannel = 0;
  late String _ccLabel;
  ActionPayload? _payload;
  late WidgetStyle _style;
  final _midiAction = MidiActionDispatcher();

  // Monotonic clock for reliable MIDI throttling (immune to system clock changes)
  late final Stopwatch _throttleStopwatch;
  late final Stopwatch _midiThrottleStopwatch;

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
  bool _isVisualUpdateQueued = false;

  SpringSimulation? _springSimulation;
  int? _lastPolledValue;
  bool _hasMcuPosition = false;
  ProviderSubscription<LayoutControl?>? _layoutSubscription;

  Timer? _stateDebounceTimer;
  final Map<String, dynamic> _pendingStateChanges = {};

  void _batchStateUpdate(Map<String, dynamic> changes) {
    _pendingStateChanges.addAll(changes);
    _stateDebounceTimer?.cancel();
    _stateDebounceTimer = Timer(const Duration(milliseconds: 8), () {
      if (mounted) {
        setState(() {
          if (_pendingStateChanges.containsKey('isDragging')) {
            _isDragging = _pendingStateChanges['isDragging'];
          }
        });
        _pendingStateChanges.clear();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    initPerformanceMixin();
    _throttleStopwatch = Stopwatch()..start();
    _midiThrottleStopwatch = Stopwatch()..start();
    final control = ref
        .read(layoutStateProvider)
        .getControlById(widget.controlId);
    _ccNumber = control?.defaultCc ?? widget.ccNumber;
    _midiChannel = control?.channel ?? 0;
    _ccLabel = control?.displayName ?? widget.displayName;
    _payload = control?.payload;
    _style = control?.effectiveStyle ?? widget.style;

    // Restore value from session state if available, otherwise use initialValue
    final hotValue = _readFeedback();
    _hasMcuPosition = _mcuFaderStrip != null && hotValue != null;
    final startValue = hotValue != null
        ? _normalizeFeedback(hotValue)
        : _mcuFaderStrip == null
        ? widget.initialValue
        : 0.0;

    _animationController = AnimationController(
      vsync: this,
      value: startValue.clamp(0.0, 1.0),
    );

    _animationController.addListener(() {
      if (_animationController.isAnimating &&
          _pendingIncomingNormalized != null) {
        final target = _pendingIncomingNormalized!;
        final distance = (_animationController.value - target).abs();
        final velocity = _animationController.velocity.abs();

        // Dead-zone clamp to stop unbounded SpringSimulation
        if (distance < 0.001 && velocity < 0.001) {
          _animationController.stop();
          _animationController.value = target;
        }
      }
    });

    if (widget.isActive) {
      _setupMidiListeners();
    }

    _registerLayoutListener();
  }

  void _registerLayoutListener() {
    _layoutSubscription?.close();
    _layoutSubscription = ref.listenManual(
      layoutStateProvider.select((s) => s.getControlById(widget.controlId)),
      (prev, next) {
        final previousAddress = _feedbackAddress;
        final previousStrip = _mcuFaderStrip;
        if (next?.payload != _payload) _finishGesture();
        setState(() {
          _ccNumber = next?.defaultCc ?? widget.ccNumber;
          _midiChannel = next?.channel ?? 0;
          _ccLabel = next?.displayName ?? widget.displayName;
          _payload = next?.payload;
          _style = next?.effectiveStyle ?? widget.style;
        });
        if (previousAddress != _feedbackAddress ||
            previousStrip != _mcuFaderStrip) {
          _pendingIncomingNormalized = null;
          _animationController.stop();
          _lastPolledValue = null;
          if (_mcuFaderStrip != null) _restoreFeedback();
          if (widget.isActive) {
            _setupMidiListeners();
          }
        }
      },
    );
  }

  String? get _feedbackAddress => switch (_payload) {
    CcPayload(:final channel, :final cc, midi2: true) => 'cc32:$channel:$cc',
    PitchBendPayload(:final channel) => 'bend:$channel',
    _ => ccFeedbackAddress(_payload, _midiChannel, _ccNumber),
  };

  int? get _mcuFaderStrip => switch (_payload) {
    McuActionPayload(target: McuTarget.fader, :final strip) => strip,
    _ => null,
  };

  int? _readFeedback() => switch (_mcuFaderStrip) {
    final strip? => ref.read(midiServiceProvider).mcuFaderValue(strip),
    null => ref.read(controlStateProvider).ccValues[_feedbackAddress],
  };

  double _normalizeFeedback(int value) => switch (_payload) {
    McuActionPayload(target: McuTarget.fader) => value / 16383,
    CcPayload(midi2: true) || PitchBendPayload() => value / 0xFFFFFFFF,
    _ => value / 127.0,
  };

  void _setMcuPositionKnown(bool known) {
    if (_hasMcuPosition == known) return;
    setState(() => _hasMcuPosition = known);
  }

  void _restoreFeedback() {
    final value = _readFeedback();
    if (_mcuFaderStrip != null) {
      _setMcuPositionKnown(value != null);
      _pendingIncomingNormalized = null;
      _animationController.stop();
      _animationController.value = value == null
          ? 0
          : _normalizeFeedback(value);
    } else if (value != null) {
      final target = _normalizeFeedback(value);
      if (_animationController.value != target) {
        _animationController.value = target;
      }
    }
  }

  void _setupMidiListeners() {
    clearManagedSubscriptions();
    if (_mcuFaderStrip case final strip?) {
      addManagedSubscription(
        ref.listenManual(mcuFaderProvider(strip), (_, next) {
          if (next.value case final value? when widget.isActive) {
            if (_hasMcuPosition) {
              _handleCcUpdate(value);
            } else {
              _restoreFeedback();
            }
          }
        }),
      );
      addManagedSubscription(
        ref.listenManual(mcuRouteActiveProvider, (_, next) {
          if (next.value == false) {
            _midiAction.end();
            _restoreFeedback();
          }
        }),
      );
      return;
    }
    final address = _feedbackAddress;
    if (address == null) return;
    addManagedSubscription(
      ref.listenManual(hotCcValueProvider(address), (previous, next) {
        if (!widget.isActive) return;
        if (next is AsyncData) {
          final val = next.value;
          if (val != null && val != _lastPolledValue) {
            _lastPolledValue = val;
            _handleCcUpdate(val);
          }
        }
      }),
    );
  }

  @override
  void onAppLifecycleChanged(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _finishGesture();
      _animationController.stop();
    } else if (widget.isActive) {
      _restoreFeedback();
    }
  }

  @override
  void didUpdateWidget(HybridTouchFader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        // Re-setup listeners
        _setupMidiListeners();
        // Re-sync value when coming back to foreground
        _restoreFeedback();
      } else {
        // Suspend heavy resources
        clearManagedSubscriptions();
        _finishGesture();
        _animationController.stop();
        _stateDebounceTimer?.cancel();
      }
    }
  }

  @override
  void dispose() {
    _finishGesture();
    _layoutSubscription?.close();
    _layoutSubscription = null;
    _stateDebounceTimer?.cancel();
    _animationController.dispose();
    disposePerformanceMixin();
    super.dispose();
  }

  void _sendMidiUpdate({bool isFinal = false}) {
    _midiAction.sendPosition(
      ref.read(midiServiceProvider),
      _payload,
      _animationController.value,
      legacyChannel: _midiChannel,
      legacyCc: _ccNumber,
      isFinal: isFinal,
    );
  }

  void _finishGesture() {
    _midiAction.end(
      mcuPosition: _isCatchingUp ? null : _animationController.value,
    );
  }

  void _handlePanDown(DragDownDetails details, BoxConstraints constraints) {
    _batchStateUpdate({'isDragging': true});

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
    if (_mcuFaderStrip != null) _animationController.stop();
    if (_mcuFaderStrip != null && !_hasMcuPosition) {
      _isCatchingUp = false;
      _applyAbsolutePosition(details.localPosition.dy, constraints.maxHeight);
      _setMcuPositionKnown(true);
    } else if (widget.behavior == FaderBehavior.jump ||
        (widget.behavior == FaderBehavior.catchUp && !_isCatchingUp)) {
      _applyAbsolutePosition(details.localPosition.dy, constraints.maxHeight);
    }
    if (_payload is NotePayload ||
        _payload is RelativeCcPayload ||
        _mcuFaderStrip != null) {
      _midiAction.begin(
        ref.read(midiServiceProvider),
        _payload,
        _animationController.value,
      );
    }
  }

  // Throttle MIDI updates to prevent flooding during rapid touch movement
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
      _batchStateUpdate({'isDragging': true});
    }

    if ((_mcuFaderStrip == null || !_isCatchingUp) &&
        _midiThrottleStopwatch.elapsedMilliseconds >= _midiUpdateThrottleMs) {
      _sendMidiUpdate();
      _midiThrottleStopwatch.reset();
    }
  }

  void _applyAbsolutePosition(double localY, double maxHeight) {
    _animationController.value = (1.0 - (localY / maxHeight)).clamp(0.0, 1.0);
  }

  void _triggerVisualUpdate(double incomingNormalized) {
    if (widget.behavior == FaderBehavior.jump) {
      _animateToIncomingValue(incomingNormalized);
    } else {
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
  }

  void _handleCcUpdate(int next) {
    if (_isDragging || _midiAction.holdsMcuFader) {
      // De-sync: The hardware is overriding the app state, but the user is dragging.
      // Set the catchup flag so when they release the app will catchup to the HW state
      _hardwareIsCatchingUp = true;
      _lastHardwareValue = null;
      return;
    }

    // Always schedule standard non-physics update if the user isn't touching it.
    // Physics handles smoothing for 'FaderBehavior.jump'.
    _pendingIncomingNormalized = _normalizeFeedback(next).clamp(0.0, 1.0);

    if (_isVisualUpdateQueued) return;

    if (_throttleStopwatch.elapsedMilliseconds < 16) {
      _isVisualUpdateQueued = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _isVisualUpdateQueued = false;
        _throttleStopwatch.reset();
        _throttleStopwatch.start();
        if (_pendingIncomingNormalized != null && mounted) {
          _triggerVisualUpdate(_pendingIncomingNormalized!);
        }
      });
    } else {
      _throttleStopwatch.reset();
      _throttleStopwatch.start();
      _triggerVisualUpdate(_pendingIncomingNormalized!);
    }
  }

  static final _springDesc = SpringDescription.withDampingRatio(
    mass: 1.0,
    stiffness: 100.0,
    ratio: 0.9,
  );

  void _animateToIncomingValue(double incomingNormalized) {
    final velocity = _springSimulation == null
        ? 0.0
        : _animationController.velocity;
    // MCU readouts need the exact host position when the spring settles.
    final createSpring = _mcuFaderStrip == null
        ? SpringSimulation.new
        : ScrollSpringSimulation.new;
    final simulation = createSpring(
      _springDesc,
      _animationController.value,
      incomingNormalized,
      velocity,
    );
    _springSimulation = simulation;
    _animationController.animateWith(simulation);
  }

  @override
  Widget build(BuildContext context) {
    final waitingForMcu = _mcuFaderStrip != null && !_hasMcuPosition;
    final canPerform =
        _mcuFaderStrip == null ||
        (ref.watch(mcuRouteActiveProvider).value ?? false);
    final double labelFontSize = widget.isMobile ? 14.0 : 18.0;
    final double displayFontSize = widget.isMobile ? 34.0 : 52.0;
    final TextStyle displayTextStyle = TextStyle(
      fontFamily: _style.fontFamily ?? 'Space Grotesk',
      fontSize: displayFontSize,
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: Colors.red,
      height: 1.0,
    );
    final effectiveColor = _style.accentColorValue != null
        ? Color(_style.accentColorValue!)
        : widget.activeColor;
    final Widget activeTrack = Container(color: effectiveColor);

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isCompact = constraints.maxWidth < 80;
          final double horizontalInset = isCompact ? 3.0 : 16.0;
          final double displayPad = isCompact ? 4.0 : 12.0;

          return Listener(
            onPointerDown: !canPerform
                ? null
                : (e) {
                    _handlePanDown(
                      DragDownDetails(localPosition: e.localPosition),
                      constraints,
                    );
                  },
            behavior: HitTestBehavior.opaque,
            child: GestureDetector(
              onVerticalDragStart: !canPerform
                  ? null
                  : (d) => _handleDragStart(d, constraints),
              onVerticalDragUpdate: !canPerform
                  ? null
                  : (d) => _handleDragUpdate(d, constraints),
              onVerticalDragCancel: () {
                _batchStateUpdate({'isDragging': false});
                if (_mcuFaderStrip != null) {
                  _finishGesture();
                } else {
                  _sendMidiUpdate(isFinal: true);
                }
              },
              onVerticalDragEnd: (_) {
                _batchStateUpdate({'isDragging': false});
                if (_mcuFaderStrip != null) {
                  _finishGesture();
                } else {
                  _sendMidiUpdate(isFinal: true);
                }
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
                      builder: (context, child) => FractionallySizedBox(
                        heightFactor: waitingForMcu
                            ? 0
                            : _animationController.value,
                        widthFactor: 1.0,
                        alignment: Alignment.bottomCenter,
                        child: activeTrack,
                      ),
                    ),

                    // Full-width TM1637 Display pinned at top with visible gap
                    Positioned(
                      top: 16,
                      left: horizontalInset,
                      right: horizontalInset,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_style.showNumericReadout) ...[
                            // Readout box — full width, top-padded
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(displayPad),
                              color: const Color(0xFF0C0E12),
                              child: SizedBox(
                                height: isCompact ? 20.0 : 38.0,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: AnimatedBuilder(
                                    animation: _animationController,
                                    builder: (context, child) => Text(
                                      waitingForMcu
                                          ? '—'
                                          : ControlValueFormatter.formatContinuous(
                                              _payload,
                                              _animationController.value,
                                            ),
                                      maxLines: 1,
                                      softWrap: false,
                                      textAlign: TextAlign.center,
                                      style: displayTextStyle.copyWith(
                                        fontFamily: _style.fontFamily,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],

                          // CC Name Label (long-press to open CC picker)
                          ConfigGestureWrapper(
                            id: widget.controlId,
                            onConfigRequested: _showConfigMenu,
                            onRenameRequested: null,
                            child: Container(
                              constraints: BoxConstraints(
                                minWidth: isCompact ? 0 : 64,
                                minHeight: 44,
                              ),
                              alignment: Alignment.center,
                              child: _style.showLabel
                                  ? FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        _ccLabel,
                                        textAlign: TextAlign.center,
                                        style:
                                            AppText.performance(
                                              color: Colors.white,
                                              fontSize: isCompact
                                                  ? 11.0
                                                  : labelFontSize,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: isCompact
                                                  ? 0.3
                                                  : 1.0,
                                            ).copyWith(
                                              fontFamily: _style.fontFamily,
                                            ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
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
      ),
    );
  }

  Future<void> _showConfigMenu() async {
    await showDialog(
      context: context,
      builder: (context) => ControlConfigModal(
        controlId: widget.controlId,
        displayNameLabel: 'Fader Name',
      ),
    );

    // No need to manually update local state anymore as build() will re-pull
    // However, HybridTouchFader currently uses initState for configuration.
    // We should move that to build or use ref.listen.
  }
}
