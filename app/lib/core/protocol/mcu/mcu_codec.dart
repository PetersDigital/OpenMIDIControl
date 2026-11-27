// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import '../../models/action_payload.dart';
import '../../models/midi_event.dart';

enum McuLampState { off, flashing, on }

sealed class McuFeedback {
  const McuFeedback();
}

final class McuFaderFeedback extends McuFeedback {
  const McuFaderFeedback(this.strip, this.value);

  final int strip;
  final int value;
}

final class McuLampFeedback extends McuFeedback {
  const McuLampFeedback(this.note, this.state);

  final int note;
  final McuLampState state;
}

final class McuTimeDigitFeedback extends McuFeedback {
  const McuTimeDigitFeedback(this.digit, this.value);

  final int digit;
  final int value;
}

abstract final class McuCodec {
  static const trackCount = 8;
  static const faderMax = 0x3FFF;
  static const _touchBase = 0x68;
  static const _vPotTurnBase = 0x10;
  static const _vPotPushBase = 0x20;
  static const _timeDigitBase = 0x40;
  static const _timeDigitCount = 6;
  static const _transportNotes = {
    TransportAction.rewind: 0x5B,
    TransportAction.up: 0x60,
    TransportAction.record: 0x5F,
    TransportAction.left: 0x62,
    TransportAction.stop: 0x5D,
    TransportAction.right: 0x63,
    TransportAction.fastForward: 0x5C,
    TransportAction.down: 0x61,
    TransportAction.play: 0x5E,
    TransportAction.cycle: 0x56,
    TransportAction.bankLeft: 0x2E,
    TransportAction.bankRight: 0x2F,
    TransportAction.channelLeft: 0x30,
    TransportAction.channelRight: 0x31,
  };
  static final _lampNotes = _transportNotes.values.toSet();

  static const headerActions = [
    TransportAction.rewind,
    TransportAction.up,
    TransportAction.record,
    TransportAction.left,
    TransportAction.stop,
    TransportAction.right,
    TransportAction.fastForward,
    TransportAction.down,
    TransportAction.play,
  ];

  static int switchNote(McuActionPayload target) => switch (target.target) {
    McuTarget.fader => _touchBase + _strip(target.strip!, allowMaster: true),
    McuTarget.vPot => _vPotPushBase + _strip(target.strip!),
    McuTarget.channelButton =>
      _buttonBase(target.button!) + _strip(target.strip!),
    McuTarget.transport => _transportNotes[target.action]!,
  };

  static MidiEvent switchEvent(
    McuActionPayload target,
    bool pressed, {
    required int timestamp,
    int group = 0,
  }) => _voice(
    pressed ? 0x90 : 0x80,
    switchNote(target),
    pressed ? 127 : 0,
    timestamp,
    group,
    isFinal: true,
  );

  static MidiEvent faderPosition(
    int strip,
    int value, {
    required int timestamp,
    int group = 0,
    bool isFinal = false,
  }) {
    RangeError.checkValueInInterval(value, 0, faderMax, 'value');
    return _voice(
      0xE0 | _strip(strip, allowMaster: true),
      value & 0x7F,
      value >>> 7,
      timestamp,
      group,
      isFinal: isFinal,
    );
  }

  static List<MidiEvent> vPotTurn(
    int strip,
    int delta, {
    required int timestamp,
    int group = 0,
  }) {
    final cc = _vPotTurnBase + _strip(strip);
    final direction = delta.sign;
    var remaining = delta.abs();
    final events = <MidiEvent>[];
    while (remaining > 0) {
      final step = remaining.clamp(1, 63);
      final value = RelativeCcEncoding.signedBit.encodeStep(direction * step);
      events.add(_voice(0xB0, cc, value, timestamp, group, isFinal: true));
      remaining -= step;
    }
    return events;
  }

  static McuFeedback? decode(MidiEvent event) {
    final midi2 = event.messageType == 4;
    if (midi2 ? event.umpWord1 == null : event.messageType != 2) return null;
    final status = event.status;
    if (status == 0xE0 && event.channel <= trackCount) {
      final value = midi2 ? event.pitchBend32! >>> 18 : event.pitchBend14!;
      return McuFaderFeedback(event.channel, value);
    }
    if ((status == 0x80 || status == 0x90) &&
        event.channel == 0 &&
        (event.data1 < 0x20 || _lampNotes.contains(event.data1))) {
      final velocity = midi2 ? event.umpWord1! >>> 25 : event.data2;
      final state = status == 0x80 || velocity == 0
          ? McuLampState.off
          : velocity == 1
          ? McuLampState.flashing
          : McuLampState.on;
      return McuLampFeedback(event.data1, state);
    }
    final digit = event.data1 - _timeDigitBase;
    if (status == 0xB0 &&
        event.channel == 15 &&
        digit >= 0 &&
        digit < _timeDigitCount) {
      return McuTimeDigitFeedback(
        digit,
        midi2 ? event.umpWord1! >>> 25 : event.data2,
      );
    }
    return null;
  }

  static int _strip(int strip, {bool allowMaster = false}) =>
      RangeError.checkValueInInterval(
        strip,
        0,
        allowMaster ? trackCount : trackCount - 1,
        'strip',
      );

  static int _buttonBase(McuChannelButton button) => switch (button) {
    McuChannelButton.recordArm => 0x00,
    McuChannelButton.solo => 0x08,
    McuChannelButton.mute => 0x10,
    McuChannelButton.select => 0x18,
  };

  static MidiEvent _voice(
    int status,
    int data1,
    int data2,
    int timestamp,
    int group, {
    required bool isFinal,
  }) {
    RangeError.checkValueInInterval(group, 0, 15, 'group');
    return MidiEvent(
      0x20000000 | (group << 24) | (status << 16) | (data1 << 8) | data2,
      timestamp,
      isFinal: isFinal,
      acceptFeedback: true,
    );
  }
}
