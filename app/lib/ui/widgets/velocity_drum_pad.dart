// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../core/models/action_payload.dart';
import '../../core/models/layout_models.dart';
import '../midi_action_dispatcher.dart';
import '../midi_service.dart';
import '../design_system.dart';
import '../performance_ticker_mixin.dart';
import 'config_gesture_wrapper.dart';
import 'control_config_modal.dart';
import '../layout_state.dart';
import '../../core/midi_utils.dart';

class VelocityDrumPad extends ConsumerStatefulWidget {
  final String controlId;
  final Color padColor;
  final int minVelocity;
  final int maxVelocity;
  final bool showVelocityGhost;

  const VelocityDrumPad({
    super.key,
    required this.controlId,
    required this.pageId,
    this.padColor = const Color(0xFF282A2E),
    this.minVelocity = 30,
    this.maxVelocity = 127,
    this.showVelocityGhost = true,
    this.isActive = true,
  });

  final String pageId;
  final bool isActive;

  @override
  ConsumerState<VelocityDrumPad> createState() => _VelocityDrumPadState();
}

class _VelocityDrumPadState extends ConsumerState<VelocityDrumPad>
    with TickerProviderStateMixin, PerformanceTickerMixin {
  bool _isPressed = false;
  int? _lastVelocity;
  Offset? _lastTouchPosition;
  int? _activePointer;
  final _midiGate = MidiGate();

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
  void didUpdateWidget(VelocityDrumPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive && !widget.isActive) {
      _scaleController.stop();
      _resetPress();
    }
  }

  @override
  void onAppLifecycleChanged(AppLifecycleState state) {
    // Suspend the scale animation while the app is backgrounded to free
    // the animation thread and prevent resource drain on suspended views.
    if (state != AppLifecycleState.resumed) {
      _scaleController.stop();
      setState(_resetPress);
    }
  }

  @override
  void dispose() {
    _midiGate.release();
    _scaleController.dispose();
    disposePerformanceMixin();
    super.dispose();
  }

  void _handlePointerDown(
    PointerDownEvent event,
    Size size,
    ActionPayload? payload,
  ) {
    if (_activePointer != null) return;
    _activePointer = event.pointer;

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

    if (payload case NotePayload(velocityMode: NoteVelocityMode.fixed)) {
      intensity = 1.0;
    } else if (payload is! NotePayload ||
        payload.velocityCurve == NoteVelocityCurve.drumPad) {
      intensity = math.pow(intensity, 1.5).toDouble();
    }

    final velocity =
        widget.minVelocity +
        ((widget.maxVelocity - widget.minVelocity) * intensity).round();

    setState(() {
      _isPressed = true;
      _lastVelocity = velocity;
      _lastTouchPosition = touchOffset;
    });

    _scaleController.reverse();

    if (payload != null) {
      _midiGate.press(
        ref.read(midiServiceProvider),
        payload,
        velocity: velocity,
      );
    }
  }

  void _resetPress() {
    _activePointer = null;
    _isPressed = false;
    _lastVelocity = null;
    _lastTouchPosition = null;
    _midiGate.release();
  }

  void _handlePointerUpOrCancel(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    setState(_resetPress);

    _scaleController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final control = ref.watch(
      layoutStateProvider.select((s) {
        final page = s.pages.firstWhereOrNull((p) => p.id == widget.pageId);
        if (page == null) return null;
        return page.controls.firstWhereOrNull((c) => c.id == widget.controlId);
      }),
    );

    if (control == null) return const SizedBox.shrink();

    final isPerformanceLocked = ref.watch(
      layoutStateProvider.select((s) => s.isPerformanceLocked),
    );
    final note = control.defaultCc;
    final channel = control.channel;
    final configured = control.payload;
    // The legacy drum grid renders all of its controls as note pads.
    final payload =
        control.type != ControlType.drumPad &&
            configured is CcPayload &&
            !configured.highResolution &&
            configured.channel == channel &&
            configured.cc == note
        ? NotePayload(
            channel: channel,
            note: note,
            velocityMode: NoteVelocityMode.touchPosition,
            velocityCurve: NoteVelocityCurve.drumPad,
          )
        : configured;
    final displayLabel = control.displayName;
    final style = control.effectiveStyle;
    final customAccent = style.accentColorValue != null
        ? Color(style.accentColorValue!)
        : null;
    final pressedBg = customAccent ?? const Color(0xFFE9C46A);
    final pressedFg =
        customAccent != null &&
            ThemeData.estimateBrightnessForColor(customAccent) ==
                Brightness.dark
        ? Colors.white
        : const Color(0xFF1E2024);

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);

          return Listener(
            onPointerDown: (event) => _handlePointerDown(event, size, payload),
            onPointerUp: _handlePointerUpOrCancel,
            onPointerCancel: _handlePointerUpOrCancel,
            behavior: HitTestBehavior.opaque,
            child: ScaleTransition(
              scale: _scaleController,
              child: Container(
                decoration: BoxDecoration(
                  color: _isPressed ? pressedBg : widget.padColor,
                  borderRadius: BorderRadius.zero,
                  border: Border.all(
                    color: _isPressed
                        ? pressedBg.withValues(alpha: 0.85)
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
                          child: style.showNumericReadout
                              ? Text(
                                  payload?.displayLabel ??
                                      MidiUtils.getNoteName(note),
                                  style: AppText.performance(
                                    color: _isPressed
                                        ? pressedFg.withValues(alpha: 0.8)
                                        : const Color(
                                            0xFFC3C7CA,
                                          ).withValues(alpha: 0.5),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                  ).copyWith(fontFamily: style.fontFamily),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),

                    // MIDI Channel (Bottom Right)
                    if (style.showNumericReadout)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Text(
                          'CH${(payload?.midiChannel ?? channel) + 1}',
                          style: AppText.system(
                            color: _isPressed
                                ? pressedFg.withValues(alpha: 0.6)
                                : const Color(
                                    0xFFC3C7CA,
                                  ).withValues(alpha: 0.3),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ).copyWith(fontFamily: style.fontFamily),
                        ),
                      ),

                    // Velocity (Bottom Left)
                    if (style.showNumericReadout)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Text(
                          'V:${_lastVelocity ?? 0}',
                          style: AppText.performance(
                            color: _isPressed
                                ? pressedFg.withValues(alpha: 0.8)
                                : const Color(
                                    0xFFC3C7CA,
                                  ).withValues(alpha: 0.4),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ).copyWith(fontFamily: style.fontFamily),
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
                    if (style.showLabel)
                      Center(
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 60,
                            minHeight: 44,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            displayLabel.isNotEmpty
                                ? displayLabel
                                : 'PAD $note',
                            textAlign: TextAlign.center,
                            style: AppText.performance(
                              color: _isPressed
                                  ? pressedFg
                                  : const Color(0xFFC3C7CA),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ).copyWith(fontFamily: style.fontFamily),
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
        displayNameLabel: 'Pad Name',
      ),
    );
  }
}
