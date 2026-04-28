// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../midi_service.dart';
import '../midi_settings_state.dart';

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
    with TickerProviderStateMixin {
  bool _isPressed = false;
  int? _lastVelocity;
  Offset? _lastTouchPosition;

  late AnimationController _scaleController;
  late AnimationController _progressController;
  Timer? _configTimer;
  bool _isLongHold = false;

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

    final durationSecs = ref.read(safetyHoldDurationProvider);
    _progressController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (durationSecs * 1000).toInt()),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _progressController.dispose();
    _configTimer?.cancel();
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
      _isLongHold = false;
    });

    final durationSecs = ref.read(safetyHoldDurationProvider);
    final duration = Duration(milliseconds: (durationSecs * 1000).toInt());

    _scaleController.reverse();
    _progressController.duration = duration;
    _progressController.forward(from: 0);

    // Start config timer
    _configTimer?.cancel();
    _configTimer = Timer(duration, () {
      if (_isPressed) {
        setState(() => _isLongHold = true);
        _progressController.reset();
        _showConfigModal(context, ref, note, channel);
      }
    });

    ref
        .read(midiServiceProvider)
        .sendNoteOn(note, velocity, channel: channel, isFinal: false);
  }

  void _handlePointerUpOrCancel(PointerEvent event, int note, int channel) {
    if (!_isPressed) return;

    _configTimer?.cancel();
    _configTimer = null;
    _progressController.reset();

    setState(() {
      _isPressed = false;
      _lastVelocity = null;
      _lastTouchPosition = null;
      _isLongHold = false;
    });

    _scaleController.forward();

    ref
        .read(midiServiceProvider)
        .sendNoteOff(note, channel: channel, isFinal: true);
  }

  String _getNoteName(int note) {
    final noteNames = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];
    final name = noteNames[note % 12];
    final octave = (note ~/ 12) - 1;
    return '$name$octave';
  }

  int? _parseNoteName(String name) {
    final noteNames = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];
    final match = RegExp(
      r'^([A-G]#?)(-?\d+)$',
      caseSensitive: false,
    ).firstMatch(name.trim());
    if (match == null) {
      // Fallback to numeric if it's just a number
      return int.tryParse(name.trim());
    }
    final notePart = match.group(1)!.toUpperCase();
    final octavePart = int.parse(match.group(2)!);
    final noteIndex = noteNames.indexOf(notePart);
    if (noteIndex == -1) return null;
    return (octavePart + 1) * 12 + noteIndex;
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
                    ? (_isLongHold ? Colors.white : const Color(0xFFE9C46A))
                    : widget.padColor,
                borderRadius: BorderRadius.zero,
                border: Border.all(
                  color: _isPressed
                      ? (_isLongHold
                            ? Colors.white.withValues(alpha: 0.8)
                            : widget.padColor.withValues(alpha: 0.8))
                      : const Color(0xFF111318).withValues(alpha: 0.5),
                  width: _isPressed ? 2.0 : 1.0,
                ),
              ),
              child: Stack(
                children: [
                  // Note Name (Top Left)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Text(
                      _getNoteName(note),
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        color: _isPressed
                            ? const Color(0xFF1E2024).withValues(alpha: 0.8)
                            : const Color(0xFFC3C7CA).withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),

                  // MIDI Channel (Bottom Right)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Text(
                      'CH${channel + 1}',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
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
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
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

                  // Central Label
                  Center(
                    child: Text(
                      widget.label.isNotEmpty ? widget.label : 'PAD $note',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: _isPressed
                            ? const Color(0xFF1E2024)
                            : const Color(0xFFC3C7CA),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),

                  // 4-second Config Hold Progress
                  if (_isPressed && !_isLongHold)
                    Center(
                      child: AnimatedBuilder(
                        animation: _progressController,
                        builder: (context, child) {
                          return SizedBox(
                            width: 60,
                            height: 60,
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

  Future<void> _showConfigModal(
    BuildContext context,
    WidgetRef ref,
    int currentNote,
    int currentChannel,
  ) async {
    final noteController = TextEditingController(
      text: _getNoteName(currentNote),
    );
    final channelController = TextEditingController(
      text: (currentChannel + 1).toString(),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2024),
        title: Text(
          'Configure ${widget.label}',
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Space Grotesk',
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: noteController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'MIDI Note (e.g. C3 or 36)',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            TextField(
              controller: channelController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'MIDI Channel (1-16)',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('SAVE'),
          ),
        ],
      ),
    );

    if (result == true) {
      final newNote = _parseNoteName(noteController.text);
      final newChannelInput = int.tryParse(channelController.text);
      if (newNote != null && newChannelInput != null) {
        // Convert back to 0-indexed channel
        final newChannel = (newChannelInput - 1).clamp(0, 15);
        ref
            .read(drumPadConfigProvider.notifier)
            .setConfig(
              widget.id,
              DrumPadConfig(note: newNote, channel: newChannel),
            );
      }
    }
  }
}
