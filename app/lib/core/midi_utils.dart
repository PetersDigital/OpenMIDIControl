// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

class MidiUtils {
  static const List<String> _noteNames = [
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

  /// Converts a MIDI note number (0-127) to a string representation (e.g., "C3").
  static String getNoteName(int note) {
    final name = _noteNames[note % 12];
    final octave = (note ~/ 12) - 2;
    return '$name$octave';
  }

  /// Parses a string into a MIDI note number (0-127).
  /// Supports both raw numbers ("60") and note names ("C3", "Db2").
  /// Returns null if the format is invalid.
  static int? parseNoteIdentifier(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // Try parsing as a raw number first
    final numeric = int.tryParse(trimmed);
    if (numeric != null) {
      if (numeric >= 0 && numeric <= 127) return numeric;
      return null;
    }

    // Try parsing as a note name
    final match = RegExp(
      r'^([A-G][#b]?)(-?\d+)$',
      caseSensitive: false,
    ).firstMatch(trimmed);

    if (match == null) return null;

    String notePart = match.group(1)!.toUpperCase();
    final int octavePart = int.parse(match.group(2)!);

    // Normalize enharmonics
    if (notePart == 'DB') notePart = 'C#';
    if (notePart == 'EB') notePart = 'D#';
    if (notePart == 'GB') notePart = 'F#';
    if (notePart == 'AB') notePart = 'G#';
    if (notePart == 'BB') notePart = 'A#';

    final int noteIndex = _noteNames.indexOf(notePart);
    if (noteIndex == -1) return null;

    final int result = (octavePart + 2) * 12 + noteIndex;
    if (result < 0 || result > 127) return null;

    return result;
  }
}
