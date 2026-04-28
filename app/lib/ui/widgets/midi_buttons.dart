// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config_gesture_wrapper.dart';

import '../midi_service.dart';

enum MidiButtonMode { note, cc }

class MomentaryButton extends ConsumerStatefulWidget {
  final int identifier; // Note or CC number
  final int channel;
  final MidiButtonMode mode;
  final String label;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback? onConfigRequested;

  const MomentaryButton({
    super.key,
    required this.identifier,
    this.channel = 0,
    this.mode = MidiButtonMode.note,
    this.label = '',
    this.activeColor = const Color(0xFFA6C9F8),
    this.inactiveColor = const Color(0xFF282A2E),
    this.onConfigRequested,
  });

  @override
  ConsumerState<MomentaryButton> createState() => _MomentaryButtonState();
}

class _MomentaryButtonState extends ConsumerState<MomentaryButton> {
  bool _isPressed = false;

  void _handlePointerDown(PointerEvent event) {
    if (_isPressed) return;

    setState(() {
      _isPressed = true;
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
    setState(() {
      _isPressed = false;
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
    return ConfigGestureWrapper(
      id: 'button_${widget.identifier}',
      onConfigRequested: () => widget.onConfigRequested?.call(),
      child: Listener(
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
            ],
          ),
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
  final VoidCallback? onConfigRequested;

  const ToggleButton({
    super.key,
    required this.identifier,
    this.channel = 0,
    this.mode = MidiButtonMode.note,
    this.label = '',
    this.activeColor = const Color(0xFFFFB59E), // Distinct color for toggles
    this.inactiveColor = const Color(0xFF282A2E),
    this.onConfigRequested,
  });

  @override
  ConsumerState<ToggleButton> createState() => _ToggleButtonState();
}

class _ToggleButtonState extends ConsumerState<ToggleButton> {
  bool _isActive = false;
  bool _isPressed = false;

  void _handlePointerDown(PointerEvent event) {
    if (_isPressed) return;

    setState(() {
      _isPressed = true;
    });
  }

  void _handlePointerUp(PointerEvent event) {
    if (!_isPressed) return;

    _toggleState();

    setState(() {
      _isPressed = false;
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
    return ConfigGestureWrapper(
      id: 'toggle_${widget.identifier}',
      onConfigRequested: () => widget.onConfigRequested?.call(),
      child: Listener(
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
            ],
          ),
        ),
      ),
    );
  }
}
