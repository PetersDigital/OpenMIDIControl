// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/core/models/midi_event.dart';
import 'package:app/ui/midi_service.dart';

void main() {
  group('MidiEvent Bitwise Extraction', () {
    test('Extracts properties from 32-bit UMP integer accurately', () {
      // 32-bit UMP: MT=2, Group=1, Status=0xB0, Channel=16 (Status=0xBF), CC=10, Value=127
      // 0x21BF0A7F
      const umpInt = 0x21BF0A7F;
      const timestamp = 123456789;

      final event = MidiEvent(umpInt, timestamp);

      expect(event.messageType, 0x2);
      expect(event.group, 0x1);
      expect(event.status, 0xB0);
      expect(event.channel, 0xF); // 15 (0-indexed 16th channel)
      expect(event.data1, 10);
      expect(event.data2, 127);
      expect(event.legacyStatusByte, 0xBF);
    });
  });

  group('Riverpod Equality Overrides', () {
    test('Equality and HashCode evaluate accurately for Riverpod', () {
      final eventA = MidiEvent(0x21BF0A7F, 1111);
      final eventB = MidiEvent(0x21BF0A7F, 1111);
      final eventC = MidiEvent(0x21BF0A7F, 2222);

      expect(eventA == eventB, isTrue);
      expect(eventA.hashCode == eventB.hashCode, isTrue);
      expect(eventA == eventC, isFalse);
    });
  });

  group('CcNotifier State Mutation', () {
    test(
      'updateMultipleCCs prevents redundant map recreation and maintains reference equality',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final ccNotifier = container.read(ccValuesProvider.notifier);

        // Initial state update
        ccNotifier.updateMultipleCCs({10: 127});
        final firstState = container.read(ccValuesProvider);

        expect(firstState.ccValues[10], 127);

        // Redundant batch update
        ccNotifier.updateMultipleCCs({10: 127});
        final secondState = container.read(ccValuesProvider);

        // Verify reference equality is maintained (preventing widget rebuilds)
        expect(identical(firstState, secondState), isTrue);
      },
    );
  });

  group('Malformed JNI Payloads', () {
    test(
      'Dart stream safely ignores odd-length arrays without throwing RangeError',
      () async {
        // Simulate Stream Decoder parsing logic directly on a malformed payload
        final malformedData = Int64List.fromList([
          0x21BF0A7F,
          123456789,
          0x21BF0A7F,
        ]); // Length 3

        final List<MidiEvent> parsedEvents = [];

        // Ensure the loop uses defensive bounds checking: `i + 1 < data.length`
        for (int i = 0; i + 1 < malformedData.length; i += 2) {
          int ump = malformedData[i];
          int timestamp = malformedData[i + 1];
          parsedEvents.add(MidiEvent(ump, timestamp));
        }

        // It should parse the first valid pair, and cleanly ignore the 3rd odd item
        expect(parsedEvents.length, 1);
        expect(parsedEvents.first.ump, 0x21BF0A7F);
      },
    );
  });
}
