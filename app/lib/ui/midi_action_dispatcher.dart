// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:math' as math;

import '../core/models/action_payload.dart';
import 'midi_service.dart';

/// Routes an absolute CC assignment to its existing feedback stream.
String? ccFeedbackAddress(ActionPayload? payload, int channel, int cc) {
  return switch (payload) {
    CcPayload(:final channel, :final cc) => '$channel:$cc',
    null when _hasLegacyCc(channel, cc) => '$channel:$cc',
    _ => null,
  };
}

bool _hasLegacyCc(int channel, int cc) =>
    channel >= 0 && channel <= 15 && cc >= 0 && cc <= 127;

void _sendMidiGate(
  MidiService service,
  ActionPayload payload, {
  required bool pressed,
  int velocity = 127,
  bool isFinal = true,
  bool relativeOnRelease = false,
}) {
  switch (payload) {
    case CcPayload(:final cc, :final channel, :final highResolution):
      if (highResolution && cc < 32) {
        service.sendHighResolutionCc(cc, pressed ? 16383 : 0, channel: channel);
      } else {
        service.sendCC(
          cc,
          pressed ? 127 : 0,
          channel: channel,
          isFinal: isFinal,
        );
      }
    case NotePayload(:final note, :final channel):
      if (pressed) {
        service.sendNoteOn(note, velocity, channel: channel, isFinal: isFinal);
      } else {
        service.sendNoteOff(note, channel: channel, isFinal: isFinal);
      }
    case PitchBendPayload(:final value, :final channel):
      service.sendPitchBend(
        pressed ? value : 8192,
        channel: channel,
        isFinal: isFinal,
      );
    case final RelativeCcPayload relative:
      if (pressed || relativeOnRelease) {
        service.sendRelativeCc(relative, pressed ? 1 : -1);
      }
    case McuActionPayload():
      break;
  }
}

class MidiGate {
  MidiGate() : _transport = false;

  MidiGate.transport() : _transport = true;

  final bool _transport;
  MidiService? _service;
  ActionPayload? _heldPayload;

  ActionPayload? get heldPayload => _heldPayload;

  void press(
    MidiService service,
    ActionPayload payload, {
    int velocity = 127,
    bool isFinal = true,
  }) {
    if (_heldPayload != null) return;
    _service = service;
    _heldPayload = payload;
    if (_transport) {
      service.sendTransportButton(payload, pressed: true);
      return;
    }
    _sendMidiGate(
      service,
      payload,
      pressed: true,
      velocity: velocity,
      isFinal: isFinal,
    );
  }

  void release({bool relativeOnRelease = false}) {
    if (_heldPayload case final payload?) {
      final service = _service!;
      _heldPayload = null;
      _service = null;
      if (_transport) {
        service.sendTransportButton(payload, pressed: false);
        return;
      }
      _sendMidiGate(
        service,
        payload,
        pressed: false,
        relativeOnRelease: relativeOnRelease,
      );
    }
  }
}

/// Tracks one continuous control or axis across a gesture.
class MidiActionDispatcher {
  int? _lastPosition;
  final _noteGate = MidiGate();

  void begin(MidiService service, ActionPayload? payload, double position) {
    _lastPosition = (position * 127).round();
    if (payload case final NotePayload note) {
      final velocity = note.velocityMode == NoteVelocityMode.fixed
          ? 127
          : ((note.velocityCurve == NoteVelocityCurve.drumPad
                        ? position * math.sqrt(position)
                        : position) *
                    127)
                .round()
                .clamp(1, 127);
      _noteGate.press(service, note, velocity: velocity);
    }
  }

  void sendPosition(
    MidiService service,
    ActionPayload? payload,
    double position, {
    required int legacyChannel,
    required int legacyCc,
    bool isFinal = false,
    int? relativeDelta,
  }) {
    switch (payload) {
      case CcPayload(:final channel, :final cc, :final highResolution):
        if (highResolution && cc < 32) {
          service.sendHighResolutionCc(
            cc,
            (position * 16383).round(),
            channel: channel,
          );
        } else {
          service.sendCC(
            cc,
            (position * 127).round(),
            channel: channel,
            isFinal: isFinal,
          );
        }
      case PitchBendPayload(:final channel):
        service.sendPitchBend(
          (position * 16383).round(),
          channel: channel,
          isFinal: isFinal,
        );
      case final RelativeCcPayload relative:
        final step = (position * 127).round();
        final delta = relativeDelta ?? (step - (_lastPosition ?? step));
        _lastPosition = step;
        if (delta != 0) service.sendRelativeCc(relative, delta);
      case NotePayload() || McuActionPayload():
        break;
      case null:
        if (_hasLegacyCc(legacyChannel, legacyCc)) {
          service.sendCC(
            legacyCc,
            (position * 127).round(),
            channel: legacyChannel,
            isFinal: isFinal,
          );
        }
    }
    if (isFinal) end();
  }

  void end() {
    _noteGate.release();
    _lastPosition = null;
  }
}
