// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../midi_service.dart';

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
}

final drumPadConfigProvider =
    NotifierProvider<DrumPadConfigManager, Map<String, DrumPadConfig>>(
      DrumPadConfigManager.new,
    );

class VelocityDrumPad extends ConsumerStatefulWidget {
  final String id;
  final int note;
  final int channel;
  final String label;
  final Color padColor;
  final int minVelocity;
  final int maxVelocity;
  final bool showVelocityGhost;

  const VelocityDrumPad({
    super.key,
    required this.id,
    required this.note,
    this.channel = 9, // Default drum channel
    this.label = '',
    this.padColor = const Color(0xFF282A2E),
    this.minVelocity = 30,
    this.maxVelocity = 127,
    this.showVelocityGhost = true,
  });

  @override
  ConsumerState<VelocityDrumPad> createState() => _VelocityDrumPadState();
}

class _VelocityDrumPadState extends ConsumerState<VelocityDrumPad>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  int? _lastVelocity;
  Offset? _lastTouchPosition;

  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
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
    if (!_isPressed) return;

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
    final config = ref.watch(drumPadConfigProvider)[widget.id];
    final note = config?.note ?? widget.note;
    final channel = config?.channel ?? widget.channel;

    return LayoutBuilder(
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
                color: _isPressed
                    ? widget.padColor.withValues(alpha: 0.8)
                    : widget.padColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isPressed
                      ? widget.padColor.withValues(alpha: 0.8)
                      : const Color(0xFF111318).withValues(alpha: 0.5),
                  width: _isPressed ? 2.0 : 1.0,
                ),
                boxShadow: _isPressed
                    ? [
                        BoxShadow(
                          color: widget.padColor.withValues(alpha: 0.5),
                          blurRadius: 20,
                          blurStyle: BlurStyle.inner,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Stack(
                children: [
                  // Optional: Ghost hit indicator for visual feedback of hit position
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

                  // Label
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.label.isNotEmpty ? widget.label : 'PAD $note',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: _isPressed
                                ? Colors.white
                                : const Color(0xFFC3C7CA),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (_isPressed && _lastVelocity != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'V: $_lastVelocity',
                              style: const TextStyle(
                                fontFamily: 'DSEG7Modern',
                                color: Colors.white70,
                                fontSize: 12,
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
}
