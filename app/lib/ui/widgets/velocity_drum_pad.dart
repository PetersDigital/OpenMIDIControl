// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../midi_service.dart';
import '../design_system.dart';
import 'config_gesture_wrapper.dart';
import 'control_config_modal.dart';
import '../layout_state.dart';
import '../../core/midi_utils.dart';

class DrumPadConfig {
  final int note;
  final int channel;

  const DrumPadConfig({required this.note, required this.channel});

  Map<String, dynamic> toJson() => {'note': note, 'channel': channel};

  factory DrumPadConfig.fromJson(Map<String, dynamic> json) {
    return DrumPadConfig(
      note: json['note'] as int,
      channel: json['channel'] as int,
    );
  }

  DrumPadConfig copyWith({int? note, int? channel}) {
    return DrumPadConfig(
      note: note ?? this.note,
      channel: channel ?? this.channel,
    );
  }
}

class DrumPadConfigManager extends Notifier<Map<String, DrumPadConfig>> {
  @override
  Map<String, DrumPadConfig> build() => const {};

  void setConfig(String id, DrumPadConfig config) {
    state = {...state, id: config};
  }

  void setAllConfigs(Map<String, DrumPadConfig> configs) {
    state = Map.unmodifiable(configs);
  }
}

final drumPadConfigProvider =
    NotifierProvider<DrumPadConfigManager, Map<String, DrumPadConfig>>(
      DrumPadConfigManager.new,
    );

class VelocityDrumPad extends ConsumerStatefulWidget {
  final String id;
  final int note;
  final int channel;
  final String displayName;
  final Color padColor;
  final int minVelocity;
  final int maxVelocity;
  final bool showVelocityGhost;

  const VelocityDrumPad({
    super.key,
    required this.id,
    required this.note,
    this.channel = 9, // Default drum channel
    this.displayName = '',
    this.padColor = const Color(0xFF282A2E),
    this.minVelocity = 30,
    this.maxVelocity = 127,
    this.showVelocityGhost = true,
  });

  @override
  ConsumerState<VelocityDrumPad> createState() => _VelocityDrumPadState();
}

class _VelocityDrumPadState extends ConsumerState<VelocityDrumPad>
    with TickerProviderStateMixin {
  bool _isPressed = false;
  int? _lastVelocity;
  Offset? _lastTouchPosition;
  late String _displayLabel;

  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _displayLabel = widget.displayName;
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
  void dispose() {
    _scaleController.dispose();
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
        .sendNoteOn(note, velocity, channel: channel, isFinal: false);
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
    final isPerformanceLocked = ref
        .watch(layoutStateProvider)
        .isPerformanceLocked;
    final config = ref.watch(drumPadConfigProvider)[widget.id];
    final note = config?.note ?? widget.note;
    final channel = config?.channel ?? widget.channel;

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
                          'config_wrapper_drum_pad_${widget.id}_note',
                        ),
                        id: 'drum_pad_${widget.id}',
                        onConfigRequested: isPerformanceLocked
                            ? null
                            : () =>
                                  _showConfigModal(context, ref, note, channel),
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
                          _displayLabel.isNotEmpty
                              ? _displayLabel
                              : 'PAD $note',
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
    int currentNote,
    int currentChannel,
  ) async {
    final result = await showDialog<ControlConfigResult>(
      context: context,
      builder: (context) => ControlConfigModal(
        initialChannel: currentChannel,
        initialIdentifier: currentNote,
        identifierLabel: 'MIDI Note (e.g., C3 or 36)',
        initialDisplayName: _displayLabel,
        displayNameLabel: 'Pad Name',
      ),
    );

    if (result != null) {
      final trimmedName = (result.displayName ?? '').trim();
      if (result.identifier >= 0 && result.identifier <= 127) {
        final newChannel = result.channel.clamp(0, 15);
        ref
            .read(drumPadConfigProvider.notifier)
            .setConfig(
              widget.id,
              DrumPadConfig(note: result.identifier, channel: newChannel),
            );
      }
      if (trimmedName.isNotEmpty) {
        setState(() {
          _displayLabel = trimmedName;
        });
        ref
            .read(layoutStateProvider.notifier)
            .updateControlLabel(widget.id, trimmedName);
      }
    }
  }
}
