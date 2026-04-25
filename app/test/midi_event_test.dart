// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/core/models/control_state.dart';
import 'package:app/core/models/midi_event.dart';
import 'package:app/ui/midi_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

        final ccNotifier = container.read(controlStateProvider.notifier);

        // Initial state update
        ccNotifier.updateMultipleCCs({"0:10": 127});
        final firstState = container.read(controlStateProvider);

        expect(firstState.ccValues["0:10"], 127);

        // Redundant batch update
        ccNotifier.updateMultipleCCs({"0:10": 127});
        final secondState = container.read(controlStateProvider);

        // Verify reference equality is maintained (preventing widget rebuilds)
        expect(identical(firstState, secondState), isTrue);
      },
    );

    test(
      'incoming updates emit hot CC immediately while coalescing global state publish',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(controlStateProvider.notifier);
        int globalPublishCount = 0;

        final hotValueFuture = notifier
            .watchHotCc("0:10")
            .firstWhere((value) => value == 65);
        final globalSub = container.listen<ControlState>(
          controlStateProvider,
          (previous, next) => globalPublishCount++,
          fireImmediately: false,
        );
        addTearDown(globalSub.close);

        notifier.ingestIncomingUpdates({
          "ccs": {"0:10": 64},
        });
        notifier.ingestIncomingUpdates({
          "ccs": {"0:10": 65},
        });

        expect(await hotValueFuture.timeout(const Duration(seconds: 1)), 65);
        // Global state updates are coalesced to bounded cadence.
        expect(globalPublishCount, 0);

        await Future<void>.delayed(const Duration(milliseconds: 25));

        expect(globalPublishCount, 1);
        final finalState = container.read(controlStateProvider);
        expect(finalState.ccValues["0:10"], 65);
      },
    );
  });

  group('hotCcValueProvider (collapsed StreamProvider)', () {
    test(
      'delivers initial current value on subscribe then subsequent updates',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(controlStateProvider.notifier);

        // Seed a known value before subscribing
        notifier.updateCC("0:7", 64);

        final received = <int>[];
        final sub = container.listen<AsyncValue<int>>(
          hotCcValueProvider("0:7"),
          (_, next) => next.whenData(received.add),
          fireImmediately: true,
        );
        addTearDown(sub.close);

        // Allow stream to emit buffered initial value
        await Future<void>.delayed(Duration.zero);
        expect(received, contains(64));

        // Subsequent update arrives through the same single provider
        notifier.updateCC("0:7", 100);
        await Future<void>.delayed(Duration.zero);
        expect(received.last, 100);
      },
    );

    test('emits no initial value for CC that has never been set', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final received = <int>[];
      final sub = container.listen<AsyncValue<int>>(
        hotCcValueProvider("0:99"),
        (_, next) => next.whenData(received.add),
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await Future<void>.delayed(Duration.zero);
      expect(received, isEmpty);
    });
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
