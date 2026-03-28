// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

class MidiEvent {
  final int ump; // 32-bit Universal MIDI Packet integer
  final int timestamp; // nanoseconds or milliseconds
  final String sourceId; // e.g., device id or port name

  const MidiEvent(
    this.ump,
    this.timestamp, {
    this.sourceId = 'unknown',
  });

  // Bitwise extraction getters for standard MIDI 1.0 Voice fields
  int get messageType => (ump >> 28) & 0xF;
  int get group => (ump >> 24) & 0xF;
  int get status => (ump >> 16) & 0xF0;
  int get channel => (ump >> 16) & 0x0F;
  int get data1 => (ump >> 8) & 0xFF; // e.g., CC number
  int get data2 => ump & 0xFF; // e.g., CC value

  // Exposing the combined legacy status byte (e.g., 0xB0 for CC on Channel 1)
  int get legacyStatusByte => (ump >> 16) & 0xFF;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MidiEvent &&
        other.ump == ump &&
        other.timestamp == timestamp &&
        other.sourceId == sourceId;
  }

  @override
  int get hashCode => ump.hashCode ^ timestamp.hashCode ^ sourceId.hashCode;

  @override
  String toString() {
    return 'MidiEvent(ump: 0x${ump.toRadixString(16).padLeft(8, '0')}, status: 0x${legacyStatusByte.toRadixString(16)}, ch: $channel, d1: $data1, d2: $data2, src: $sourceId)';
  }
}
