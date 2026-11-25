// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

enum NoteVelocityMode { fixed, touchPosition }

enum NoteVelocityCurve { linear, drumPad }

enum RelativeCcEncoding { signedBit, twosComplement, binaryOffset }

enum McuTarget { fader, vPot, channelButton, transport }

enum McuChannelButton { recordArm, solo, mute, select }

enum McuTransportAction {
  play,
  stop,
  record,
  cycle,
  rewind,
  fastForward,
  bankLeft,
  bankRight,
}

/// A persisted MIDI action assignment for a layout control or axis.
sealed class ActionPayload {
  const ActionPayload();

  factory ActionPayload.fromJson(Map<String, dynamic> json) {
    return switch (json['type']) {
      'cc' => CcPayload(
        channel: _readInt(json, 'channel', 15),
        cc: _readInt(json, 'cc', 127),
        highResolution: _readBool(json, 'highResolution'),
      ),
      'note' => NotePayload(
        channel: _readInt(json, 'channel', 15),
        note: _readInt(json, 'note', 127),
        velocityMode: _readEnum(json, 'velocityMode', NoteVelocityMode.values),
        velocityCurve: _readEnum(
          json,
          'velocityCurve',
          NoteVelocityCurve.values,
        ),
      ),
      'pitchBend' => PitchBendPayload(
        channel: _readInt(json, 'channel', 15),
        value: _readInt(json, 'value', 16383),
      ),
      'relativeCc' => RelativeCcPayload(
        channel: _readInt(json, 'channel', 15),
        cc: _readInt(json, 'cc', 127),
        encoding: _readEnum(json, 'encoding', RelativeCcEncoding.values),
      ),
      'mcu' => McuActionPayload._fromJson(json),
      _ => throw FormatException(
        'Unknown action payload type: ${json['type']}',
      ),
    };
  }

  Map<String, dynamic> toJson();

  Object get _fields;

  @override
  bool operator ==(Object other) =>
      other is ActionPayload &&
      other.runtimeType == runtimeType &&
      other._fields == _fields;

  @override
  int get hashCode => Object.hash(runtimeType, _fields);

  static int _readInt(Map<String, dynamic> json, String key, int max) {
    final value = json[key];
    if (value is int && value >= 0 && value <= max) return value;
    throw FormatException(
      'Action payload $key must be an integer from 0 to $max.',
    );
  }

  static bool _readBool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return false;
    if (value is bool) return value;
    throw FormatException('Action payload $key must be a boolean.');
  }

  static T _readEnum<T extends Enum>(
    Map<String, dynamic> json,
    String key,
    List<T> values,
  ) {
    final name = json[key];
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw FormatException('Invalid action payload $key: $name');
  }
}

final class CcPayload extends ActionPayload {
  final int channel;
  final int cc;
  final bool highResolution;

  const CcPayload({
    required this.channel,
    required this.cc,
    this.highResolution = false,
  }) : assert(channel >= 0 && channel <= 15),
       assert(cc >= 0 && cc <= 127);

  @override
  Object get _fields => (channel, cc, highResolution);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'cc',
    'channel': channel,
    'cc': cc,
    if (highResolution) 'highResolution': true,
  };
}

final class NotePayload extends ActionPayload {
  final int channel;
  final int note;
  final NoteVelocityMode velocityMode;
  final NoteVelocityCurve velocityCurve;

  const NotePayload({
    required this.channel,
    required this.note,
    this.velocityMode = NoteVelocityMode.fixed,
    this.velocityCurve = NoteVelocityCurve.linear,
  }) : assert(channel >= 0 && channel <= 15),
       assert(note >= 0 && note <= 127);

  @override
  Object get _fields => (channel, note, velocityMode, velocityCurve);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'note',
    'channel': channel,
    'note': note,
    'velocityMode': velocityMode.name,
    'velocityCurve': velocityCurve.name,
  };
}

final class PitchBendPayload extends ActionPayload {
  final int channel;
  final int value;

  const PitchBendPayload({required this.channel, this.value = 8192})
    : assert(channel >= 0 && channel <= 15),
      assert(value >= 0 && value <= 16383);

  @override
  Object get _fields => (channel, value);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'pitchBend',
    'channel': channel,
    'value': value,
  };
}

final class RelativeCcPayload extends ActionPayload {
  final int channel;
  final int cc;
  final RelativeCcEncoding encoding;

  const RelativeCcPayload({
    required this.channel,
    required this.cc,
    required this.encoding,
  }) : assert(channel >= 0 && channel <= 15),
       assert(cc >= 0 && cc <= 127);

  @override
  Object get _fields => (channel, cc, encoding);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'relativeCc',
    'channel': channel,
    'cc': cc,
    'encoding': encoding.name,
  };
}

/// An MCU target reserved for the protocol engine.
final class McuActionPayload extends ActionPayload {
  final McuTarget target;
  final int? strip;
  final McuChannelButton? button;
  final McuTransportAction? action;

  const McuActionPayload.fader(int index)
    : assert(index >= 0 && index <= 8),
      strip = index,
      target = McuTarget.fader,
      button = null,
      action = null;

  const McuActionPayload.vPot(int index)
    : assert(index >= 0 && index <= 7),
      strip = index,
      target = McuTarget.vPot,
      button = null,
      action = null;

  const McuActionPayload.channelButton(int index, McuChannelButton this.button)
    : assert(index >= 0 && index <= 7),
      strip = index,
      target = McuTarget.channelButton,
      action = null;

  const McuActionPayload.transport(McuTransportAction this.action)
    : target = McuTarget.transport,
      strip = null,
      button = null;

  factory McuActionPayload._fromJson(Map<String, dynamic> json) {
    return switch (ActionPayload._readEnum(json, 'target', McuTarget.values)) {
      McuTarget.fader => McuActionPayload.fader(
        ActionPayload._readInt(json, 'strip', 8),
      ),
      McuTarget.vPot => McuActionPayload.vPot(
        ActionPayload._readInt(json, 'strip', 7),
      ),
      McuTarget.channelButton => McuActionPayload.channelButton(
        ActionPayload._readInt(json, 'strip', 7),
        ActionPayload._readEnum(json, 'button', McuChannelButton.values),
      ),
      McuTarget.transport => McuActionPayload.transport(
        ActionPayload._readEnum(json, 'action', McuTransportAction.values),
      ),
    };
  }

  @override
  Object get _fields => (target, strip, button, action);

  @override
  Map<String, dynamic> toJson() => {
    'type': 'mcu',
    'target': target.name,
    if (strip != null) 'strip': strip,
    if (button != null) 'button': button!.name,
    if (action != null) 'action': action!.name,
  };
}
