// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import '../midi_utils.dart';
import '../models/action_payload.dart';
import '../protocol/mcu/mcu_codec.dart';

/// Formats live control readouts to match each assigned MIDI or MCU parameter.
abstract final class ControlValueFormatter {
  static const List<(double, double)> _mcuDbAnchors = [
    (0.0005, -90.0),
    (0.05, -60.0),
    (0.15, -40.0),
    (0.41604, -20.0),
    (0.789, 0.0),
    (1.0, 6.02),
  ];

  /// Formats a normalized continuous control position (`0.0..1.0`).
  static String formatContinuous(ActionPayload? payload, double normalized) {
    final n = normalized.clamp(0.0, 1.0).toDouble();
    return switch (payload) {
      McuActionPayload(target: McuTarget.fader) => formatMcuDb(n),
      PitchBendPayload() => _formatSignedPercent(n),
      CcPayload(highResolution: true) ||
      CcPayload(midi2: true) => '${(n * 100).round()}%',
      RelativeCcPayload() => 'REL',
      NotePayload(:final note) => MidiUtils.getNoteName(note),
      _ => '${(n * 127).round()}',
    };
  }

  /// Maps normalized MCU fader position (`0.0..1.0`) to a <=5-char dB string.
  static String formatMcuDb(double normalized) {
    final n = normalized.clamp(0.0, 1.0).toDouble();
    if (n <= _mcuDbAnchors.first.$1) return '-∞';
    final db = _interpolateDb(n);
    if (db <= -9.95) return db.toStringAsFixed(1);
    if (db < -0.005) return db.toStringAsFixed(2);
    if (db <= 0.005) return '0.00';
    return '+${db.toStringAsFixed(2)}';
  }

  /// Formats an encoder readout, preferring MCU V-Pot Pan feedback when active.
  static String formatEncoder(
    ActionPayload? payload,
    int currentValue, {
    McuVPotRingFeedback? vPotRing,
  }) {
    if (payload case McuActionPayload(target: McuTarget.vPot)) {
      final pos = vPotRing?.position;
      if (pos != null && pos >= 1 && pos <= 11) {
        if (pos == 1) return 'L';
        if (pos == 11) return 'R';
        if (pos == 6) return 'C';
        return pos < 6 ? 'L${(6 - pos) * 20}' : 'R${(pos - 6) * 20}';
      }
      return 'PAN';
    }
    if (payload is RelativeCcPayload) return '$currentValue';
    return formatContinuous(payload, currentValue / 127.0);
  }

  static double _interpolateDb(double normalized) {
    for (var i = 1; i < _mcuDbAnchors.length; i++) {
      final (x0, y0) = _mcuDbAnchors[i - 1];
      final (x1, y1) = _mcuDbAnchors[i];
      if (normalized <= x1) {
        final t = (normalized - x0) / (x1 - x0);
        return y0 + t * (y1 - y0);
      }
    }
    return _mcuDbAnchors.last.$2;
  }

  static String _formatSignedPercent(double normalized) {
    final pct = ((normalized * 2.0 - 1.0) * 100).round();
    return pct > 0 ? '+$pct%' : '$pct%';
  }
}
