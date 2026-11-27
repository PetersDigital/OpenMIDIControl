// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:app/core/models/action_payload.dart';
import 'package:app/core/protocol/mcu/mcu_codec.dart';
import 'package:app/core/utils/control_value_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ControlValueFormatter', () {
    test('formats MCU fader normalized positions to <=5-char dB labels', () {
      const mcuFader = McuActionPayload.fader(0);
      expect(ControlValueFormatter.formatContinuous(mcuFader, 0.0), '-∞');
      expect(ControlValueFormatter.formatContinuous(mcuFader, 0.0005), '-∞');
      expect(
        ControlValueFormatter.formatContinuous(mcuFader, 6816 / 16383),
        '-20.0',
      );
      expect(ControlValueFormatter.formatContinuous(mcuFader, 0.789), '0.00');
      expect(ControlValueFormatter.formatContinuous(mcuFader, 1.0), '+6.02');

      for (var i = 0; i <= 100; i++) {
        final label = ControlValueFormatter.formatContinuous(
          mcuFader,
          i / 100.0,
        );
        expect(label.length, lessThanOrEqualTo(5), reason: 'at $i%: $label');
      }
    });

    test('formats MCU V-Pot feedback and relative/legacy encoders', () {
      const vPot = McuActionPayload.vPot(0);
      expect(ControlValueFormatter.formatEncoder(vPot, 0), 'PAN');
      expect(
        ControlValueFormatter.formatEncoder(
          vPot,
          0,
          vPotRing: const McuVPotRingFeedback(0, 0x11),
        ),
        'L',
      );
      expect(
        ControlValueFormatter.formatEncoder(
          vPot,
          0,
          vPotRing: const McuVPotRingFeedback(0, 0x12),
        ),
        'L80',
      );
      expect(
        ControlValueFormatter.formatEncoder(
          vPot,
          0,
          vPotRing: const McuVPotRingFeedback(0, 0x15),
        ),
        'L20',
      );
      expect(
        ControlValueFormatter.formatEncoder(
          vPot,
          0,
          vPotRing: const McuVPotRingFeedback(0, 0x56),
        ),
        'C',
      );
      expect(
        ControlValueFormatter.formatEncoder(
          vPot,
          0,
          vPotRing: const McuVPotRingFeedback(0, 0x17),
        ),
        'R20',
      );
      expect(
        ControlValueFormatter.formatEncoder(
          vPot,
          0,
          vPotRing: const McuVPotRingFeedback(0, 0x1A),
        ),
        'R80',
      );
      expect(
        ControlValueFormatter.formatEncoder(
          vPot,
          0,
          vPotRing: const McuVPotRingFeedback(0, 0x1B),
        ),
        'R',
      );
      expect(
        ControlValueFormatter.formatEncoder(
          const RelativeCcPayload(
            channel: 0,
            cc: 16,
            encoding: RelativeCcEncoding.signedBit,
          ),
          64,
        ),
        '64',
      );
    });

    test('formats Generic MIDI payloads concisely for humans', () {
      const pb = PitchBendPayload(channel: 0);
      expect(ControlValueFormatter.formatContinuous(pb, 0.0), '-100%');
      expect(ControlValueFormatter.formatContinuous(pb, 0.5), '0%');
      expect(ControlValueFormatter.formatContinuous(pb, 1.0), '+100%');

      const cc14 = CcPayload(channel: 0, cc: 1, highResolution: true);
      const cc32 = CcPayload(channel: 0, cc: 74, midi2: true);
      expect(ControlValueFormatter.formatContinuous(cc14, 0.0), '0%');
      expect(ControlValueFormatter.formatContinuous(cc32, 0.5), '50%');
      expect(ControlValueFormatter.formatContinuous(cc32, 1.0), '100%');

      const cc7 = CcPayload(channel: 0, cc: 74);
      expect(ControlValueFormatter.formatContinuous(cc7, 0.0), '0');
      expect(ControlValueFormatter.formatContinuous(cc7, 64 / 127.0), '64');
      expect(ControlValueFormatter.formatContinuous(cc7, 1.0), '127');

      expect(
        ControlValueFormatter.formatContinuous(
          const RelativeCcPayload(
            channel: 0,
            cc: 10,
            encoding: RelativeCcEncoding.signedBit,
          ),
          0.5,
        ),
        'REL',
      );
      expect(
        ControlValueFormatter.formatContinuous(
          const NotePayload(channel: 0, note: 60),
          1.0,
        ),
        'C3',
      );
    });
  });
}
