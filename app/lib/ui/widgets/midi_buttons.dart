// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../midi_service.dart';
import '../midi_settings_state.dart';

enum MidiButtonMode { note, cc }

class MomentaryButton extends ConsumerStatefulWidget {
  final int identifier; // Note or CC number
  final int channel;
  final MidiButtonMode mode;
  final String label;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback? onLongPress;

  const MomentaryButton({
    super.key,
    required this.identifier,
    this.channel = 0,
    this.mode = MidiButtonMode.note,
    this.label = '',
    this.activeColor = const Color(0xFFA6C9F8),
    this.inactiveColor = const Color(0xFF282A2E),
    this.onLongPress,
  });

  @override
  ConsumerState<MomentaryButton> createState() => _MomentaryButtonState();
}

class _MomentaryButtonState extends ConsumerState<MomentaryButton>
    with TickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _progressController;
  Timer? _configTimer;
  bool _isLongHold = false;

  @override
  void initState() {
    super.initState();
    final durationSecs = ref.read(safetyHoldDurationProvider);
    _progressController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (durationSecs * 1000).toInt()),
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    _configTimer?.cancel();
    super.dispose();
  }

  void _handlePointerDown(PointerEvent event) {
    if (_isPressed) return;
    setState(() {
      _isPressed = true;
      _isLongHold = false;
    });

    final durationSecs = ref.read(safetyHoldDurationProvider);
    final duration = Duration(milliseconds: (durationSecs * 1000).toInt());

    _progressController.duration = duration;
    _progressController.forward(from: 0);
    _configTimer?.cancel();
    _configTimer = Timer(duration, () {
      if (_isPressed) {
        setState(() => _isLongHold = true);
        _progressController.reset();
        widget.onLongPress?.call();
      }
    });

    final service = ref.read(midiServiceProvider);
    if (widget.mode == MidiButtonMode.note) {
      service.sendNoteOn(
        widget.identifier,
        127,
        channel: widget.channel,
        isFinal: false,
      );
    } else {
      service.sendCC(
        widget.identifier,
        127,
        channel: widget.channel,
        isFinal: false,
      );
    }
  }

  void _handlePointerUp(PointerEvent event) {
    if (!_isPressed) return;
    _configTimer?.cancel();
    _configTimer = null;
    _progressController.reset();

    setState(() {
      _isPressed = false;
      _isLongHold = false;
    });

    final service = ref.read(midiServiceProvider);
    if (widget.mode == MidiButtonMode.note) {
      service.sendNoteOff(
        widget.identifier,
        channel: widget.channel,
        isFinal: true,
      );
    } else {
      service.sendCC(
        widget.identifier,
        0,
        channel: widget.channel,
        isFinal: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerUp,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        decoration: BoxDecoration(
          color: _isPressed ? widget.activeColor : widget.inactiveColor,
          borderRadius: BorderRadius.zero,
          border: Border.all(
            color: _isPressed ? widget.activeColor : const Color(0xFF111318),
            width: 2.0,
          ),
        ),
        child: Stack(
          children: [
            // Identifier (Top Left)
            Positioned(
              top: 4,
              left: 4,
              child: Text(
                'CC ${widget.identifier}',
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  color: _isPressed
                      ? const Color(0xFF033258).withValues(alpha: 0.6)
                      : const Color(0xFFC3C7CA).withValues(alpha: 0.3),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Center(
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: _isPressed
                      ? const Color(0xFF033258)
                      : const Color(0xFFC3C7CA),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            // Status (Bottom Left)
            Positioned(
              bottom: 4,
              left: 4,
              child: Text(
                _isPressed ? 'ON' : 'OFF',
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  color: _isPressed
                      ? const Color(0xFF033258)
                      : const Color(0xFFC3C7CA).withValues(alpha: 0.3),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Channel (Bottom Right)
            Positioned(
              bottom: 4,
              right: 4,
              child: Text(
                'CH${widget.channel + 1}',
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  color: _isPressed
                      ? const Color(0xFF033258).withValues(alpha: 0.6)
                      : const Color(0xFFC3C7CA).withValues(alpha: 0.3),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (_isPressed && !_isLongHold)
              Center(
                child: AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, child) {
                    return SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        value: _progressController.value,
                        strokeWidth: 3,
                        color: Colors.white.withValues(alpha: 0.6),
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ToggleButton extends ConsumerStatefulWidget {
  final int identifier; // Note or CC number
  final int channel;
  final MidiButtonMode mode;
  final String label;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback? onLongPress;

  const ToggleButton({
    super.key,
    required this.identifier,
    this.channel = 0,
    this.mode = MidiButtonMode.note,
    this.label = '',
    this.activeColor = const Color(0xFFFFB59E), // Distinct color for toggles
    this.inactiveColor = const Color(0xFF282A2E),
    this.onLongPress,
  });

  @override
  ConsumerState<ToggleButton> createState() => _ToggleButtonState();
}

class _ToggleButtonState extends ConsumerState<ToggleButton>
    with TickerProviderStateMixin {
  bool _isActive = false;
  bool _isPressed = false;
  late AnimationController _progressController;
  Timer? _configTimer;
  bool _isLongHold = false;

  @override
  void initState() {
    super.initState();
    final durationSecs = ref.read(safetyHoldDurationProvider);
    _progressController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (durationSecs * 1000).toInt()),
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    _configTimer?.cancel();
    super.dispose();
  }

  void _handlePointerDown(PointerEvent event) {
    if (_isPressed) return;
    setState(() {
      _isPressed = true;
      _isLongHold = false;
    });

    final durationSecs = ref.read(safetyHoldDurationProvider);
    final duration = Duration(milliseconds: (durationSecs * 1000).toInt());

    _progressController.duration = duration;
    _progressController.forward(from: 0);
    _configTimer?.cancel();
    _configTimer = Timer(duration, () {
      if (_isPressed) {
        setState(() => _isLongHold = true);
        _progressController.reset();
        widget.onLongPress?.call();
      }
    });
  }

  void _handlePointerUp(PointerEvent event) {
    if (!_isPressed) return;

    if (!_isLongHold && _isPressed) {
      _toggleState();
    }

    _configTimer?.cancel();
    _configTimer = null;
    _progressController.reset();

    setState(() {
      _isPressed = false;
      _isLongHold = false;
    });
  }

  void _toggleState() {
    setState(() => _isActive = !_isActive);

    final service = ref.read(midiServiceProvider);

    if (widget.mode == MidiButtonMode.note) {
      if (_isActive) {
        service.sendNoteOn(
          widget.identifier,
          127,
          channel: widget.channel,
          isFinal: true,
        );
      } else {
        service.sendNoteOff(
          widget.identifier,
          channel: widget.channel,
          isFinal: true,
        );
      }
    } else {
      if (_isActive) {
        service.sendCC(
          widget.identifier,
          127,
          channel: widget.channel,
          isFinal: true,
        );
      } else {
        service.sendCC(
          widget.identifier,
          0,
          channel: widget.channel,
          isFinal: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerUp,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _isActive ? widget.activeColor : widget.inactiveColor,
          borderRadius: BorderRadius.zero,
          border: Border.all(
            color: _isActive ? widget.activeColor : const Color(0xFF111318),
            width: 2.0,
          ),
        ),
        child: Stack(
          children: [
            // Identifier (Top Left)
            Positioned(
              top: 4,
              left: 4,
              child: Text(
                'CC ${widget.identifier}',
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  color: _isActive
                      ? const Color(0xFF690005).withValues(alpha: 0.6)
                      : const Color(0xFFC3C7CA).withValues(alpha: 0.3),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Center(
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: _isActive
                      ? const Color(0xFF690005)
                      : const Color(0xFFC3C7CA),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            // Status (Bottom Left)
            Positioned(
              bottom: 4,
              left: 4,
              child: Text(
                _isActive ? 'ON' : 'OFF',
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  color: _isActive
                      ? const Color(0xFF690005)
                      : const Color(0xFFC3C7CA).withValues(alpha: 0.3),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Channel (Bottom Right)
            Positioned(
              bottom: 4,
              right: 4,
              child: Text(
                'CH${widget.channel + 1}',
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  color: _isActive
                      ? const Color(0xFF690005).withValues(alpha: 0.6)
                      : const Color(0xFFC3C7CA).withValues(alpha: 0.3),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (_isPressed && !_isLongHold)
              Center(
                child: AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, child) {
                    return SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        value: _progressController.value,
                        strokeWidth: 3,
                        color: Colors.white.withValues(alpha: 0.6),
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
