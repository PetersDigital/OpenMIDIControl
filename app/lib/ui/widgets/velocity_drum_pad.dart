// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../midi_service.dart';
import '../design_system.dart';
import '../performance_ticker_mixin.dart';
import 'config_gesture_wrapper.dart';
import 'control_config_modal.dart';
import '../layout_state.dart';
import '../../core/midi_utils.dart';

class VelocityDrumPad extends ConsumerStatefulWidget {
  final int index;
  final Color padColor;
  final int minVelocity;
  final int maxVelocity;
  final bool showVelocityGhost;

  const VelocityDrumPad({
    super.key,
    required this.index,
    this.padColor = const Color(0xFF282A2E),
    this.minVelocity = 30,
    this.maxVelocity = 127,
    this.showVelocityGhost = true,
  });

  @override
  ConsumerState<VelocityDrumPad> createState() => _VelocityDrumPadState();
}

class _VelocityDrumPadState extends ConsumerState<VelocityDrumPad>
    with
        TickerProviderStateMixin,
        WidgetsBindingObserver,
        PerformanceTickerMixin {
  bool _isPressed = false;
  int? _lastVelocity;
  Offset? _lastTouchPosition;

  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    initPerformanceMixin();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
      reverseDuration: const Duration(milliseconds: 150),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Suspend the scale animation while the app is backgrounded to free
    // the animation thread and prevent resource drain on suspended views.
    if (state != AppLifecycleState.resumed) {
      _scaleController.stop();
    }
    // Delegate to the mixin to handle any registered tickers as well.
    super.didChangeAppLifecycleState(state);
  }

  @override
  void dispose() {
    _scaleController.dispose();
    disposePerformanceMixin();
    super.dispose();
  }

  void _handlePointerDown(
    PointerDownEvent event,
    Size size,
    int note,
    int channel,
  ) {
    if (_isPressed) return;

    final center = Offset(size.width / 2, size.height / 2);
    final touchOffset = event.localPosition;

    // Calculate distance from center
    final distance = (touchOffset - center).distance;

    // Max distance is roughly the distance from center to corner
    final maxDistance = math.sqrt(
      math.pow(size.width / 2, 2) + math.pow(size.height / 2, 2),
    );

    // Calculate velocity (1.0 at center, 0.0 at edge)
    double intensity = 1.0 - (distance / maxDistance).clamp(0.0, 1.0);

    // Apply a slight curve to make the "sweet spot" at the center feel more natural
    intensity = math.pow(intensity, 1.5).toDouble();

    final velocity =
        widget.minVelocity +
        ((widget.maxVelocity - widget.minVelocity) * intensity).round();

    setState(() {
      _isPressed = true;
      _lastVelocity = velocity;
      _lastTouchPosition = touchOffset;
    });

    _scaleController.reverse();

    ref
        .read(midiServiceProvider)
        .sendNoteOn(note, velocity, channel: channel, isFinal: true);
  }

  void _handlePointerUpOrCancel(PointerEvent event, int note, int channel) {
    setState(() {
      _isPressed = false;
      _lastVelocity = null;
      _lastTouchPosition = null;
    });

    _scaleController.forward();

    ref
        .read(midiServiceProvider)
        .sendNoteOff(note, channel: channel, isFinal: true);
  }

  @override
  Widget build(BuildContext context) {
    final control = ref.watch(
      layoutStateProvider.select(
        (s) => s.pages.length > 2 && widget.index < s.pages[2].controls.length
            ? s.pages[2].controls[widget.index]
            : null,
      ),
    );

    if (control == null) return const SizedBox.shrink();

    final isPerformanceLocked = ref.watch(
      layoutStateProvider.select((s) => s.isPerformanceLocked),
    );
    final note = control.defaultCc;
    final channel = control.channel;
    final displayLabel = control.displayName;

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);

          return Listener(
            onPointerDown: (event) =>
                _handlePointerDown(event, size, note, channel),
            onPointerUp: (event) =>
                _handlePointerUpOrCancel(event, note, channel),
            onPointerCancel: (event) =>
                _handlePointerUpOrCancel(event, note, channel),
            behavior: HitTestBehavior.opaque,
            child: ScaleTransition(
              scale: _scaleController,
              child: Container(
                decoration: BoxDecoration(
                  color: _isPressed ? const Color(0xFFE9C46A) : widget.padColor,
                  borderRadius: BorderRadius.zero,
                  border: Border.all(
                    color: _isPressed
                        ? widget.padColor.withValues(alpha: 0.8)
                        : const Color(0xFF111318).withValues(alpha: 0.5),
                    width: _isPressed ? 2.0 : 1.0,
                  ),
                ),
                child: Stack(
                  children: [
                    // Note Name (Top Left)
                    Positioned(
                      top: 0,
                      left: 0,
                      child: ConfigGestureWrapper(
                        key: ValueKey(
                          'config_wrapper_drum_pad_${control.id}_note',
                        ),
                        id: 'drum_pad_${control.id}',
                        onConfigRequested: isPerformanceLocked
                            ? null
                            : () => _showConfigModal(context, ref, control.id),
                        child: Container(
                          padding: const EdgeInsets.only(
                            top: 8,
                            left: 10,
                            bottom: 20,
                            right: 20,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 60,
                            minHeight: 60,
                          ),
                          alignment: Alignment.topLeft,
                          child: Text(
                            MidiUtils.getNoteName(note),
                            style: AppText.performance(
                              color: _isPressed
                                  ? const Color(
                                      0xFF1E2024,
                                    ).withValues(alpha: 0.8)
                                  : const Color(
                                      0xFFC3C7CA,
                                    ).withValues(alpha: 0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // MIDI Channel (Bottom Right)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Text(
                        'CH${channel + 1}',
                        style: AppText.system(
                          color: _isPressed
                              ? const Color(0xFF1E2024).withValues(alpha: 0.6)
                              : const Color(0xFFC3C7CA).withValues(alpha: 0.3),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // Velocity (Bottom Left)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Text(
                        'V:${_lastVelocity ?? 0}',
                        style: AppText.performance(
                          color: _isPressed
                              ? const Color(0xFF1E2024).withValues(alpha: 0.8)
                              : const Color(0xFFC3C7CA).withValues(alpha: 0.4),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    // Ghost hit indicator
                    if (widget.showVelocityGhost &&
                        _isPressed &&
                        _lastTouchPosition != null)
                      Positioned(
                        left: _lastTouchPosition!.dx - 20,
                        top: _lastTouchPosition!.dy - 20,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                      ),

                    // Central Label (Static display)
                    Center(
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 60,
                          minHeight: 44,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          displayLabel.isNotEmpty ? displayLabel : 'PAD $note',
                          textAlign: TextAlign.center,
                          style: AppText.performance(
                            color: _isPressed
                                ? const Color(0xFF1E2024)
                                : const Color(0xFFC3C7CA),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
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

  Future<void> _showConfigModal(
    BuildContext context,
    WidgetRef ref,
    String controlId,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => ControlConfigModal(
        controlId: controlId,
        identifierLabel: 'MIDI Note (e.g., C3 or 36)',
        displayNameLabel: 'Pad Name',
      ),
    );
  }
}
