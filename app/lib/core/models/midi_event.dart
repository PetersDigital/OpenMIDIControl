// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

class MidiEvent {
  final int ump; // 32-bit Universal MIDI Packet integer
  final int timestamp; // milliseconds
  final int? timestampNs;
  final int? umpWord1;
  final String sourceId; // e.g., device id or port name
  final bool
  isFinal; // Gesture finality semantics for routing and native transport

  /// Accepts an immediate host response at the sent MIDI address.
  final bool acceptFeedback;

  const MidiEvent(
    this.ump,
    this.timestamp, {
    this.umpWord1,
    this.timestampNs,
    this.sourceId = 'unknown',
    this.isFinal = false,
    this.acceptFeedback = false,
  });

  // Bitwise extraction getters for standard MIDI 1.0 Voice fields
  int get messageType => (ump >>> 28) & 0xF;
  int get group => (ump >>> 24) & 0xF;
  int get status => (ump >>> 16) & 0xF0;
  int get channel => (ump >>> 16) & 0x0F;
  int get data1 => (ump >>> 8) & 0xFF; // e.g., CC number
  int get data2 => ump & 0xFF; // e.g., CC value

  // Reserve bank selectors, paired CCs, RPN/NRPN, and channel-mode commands.
  static bool isMidi2AbsoluteCc(int cc) =>
      cc >= 64 && cc <= 119 && (cc < 96 || cc > 101);

  int? get pitchBend32 => messageType == 4 && status == 0xE0 ? umpWord1 : null;
  int? get ccValue32 => messageType == 4 && status == 0xB0 ? umpWord1 : null;
  int? get noteVelocity16 {
    final word1 = umpWord1;
    if (messageType != 4 ||
        (status != 0x80 && status != 0x90) ||
        word1 == null) {
      return null;
    }
    return word1 >>> 16;
  }

  // Exposing the combined legacy status byte (e.g., 0xB0 for CC on Channel 1)
  int get legacyStatusByte => (ump >>> 16) & 0xFF;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MidiEvent &&
        other.ump == ump &&
        other.umpWord1 == umpWord1 &&
        other.timestamp == timestamp &&
        other.timestampNs == timestampNs &&
        other.sourceId == sourceId &&
        other.isFinal == isFinal &&
        other.acceptFeedback == acceptFeedback;
  }

  @override
  int get hashCode => Object.hash(
    ump,
    umpWord1,
    timestamp,
    timestampNs,
    sourceId,
    isFinal,
    acceptFeedback,
  );

  @override
  String toString() {
    final second = umpWord1;
    final suffix = second == null
        ? ''
        : ' 0x${second.toRadixString(16).padLeft(8, '0')}';
    return 'MidiEvent(ump: 0x${ump.toRadixString(16).padLeft(8, '0')}$suffix, status: 0x${legacyStatusByte.toRadixString(16)}, ch: $channel, d1: $data1, d2: $data2, src: $sourceId)';
  }
}
