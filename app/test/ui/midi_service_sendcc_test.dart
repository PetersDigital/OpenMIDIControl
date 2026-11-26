// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/models/action_payload.dart';
import 'package:app/ui/midi_action_dispatcher.dart';
import 'package:app/ui/midi_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MidiService outgoing packets', () {
    const channel = MethodChannel('com.petersdigital.openmidicontrol/midi');
    late Int64List capturedEvents;
    late List<int> allEvents;
    late Completer<void> callCompleter;

    setUp(() {
      capturedEvents = Int64List(0);
      allEvents = [];
      callCompleter = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'sendMidiCCBatch' ||
                call.method == 'sendMidiBatchV2') {
              final events = (call.arguments as Map)['events'] as Int64List;
              capturedEvents = events;
              allEvents.addAll(events);
              if (!callCompleter.isCompleted) {
                callCompleter.complete();
              }
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('propagates isFinal through sendCC and native transport', () async {
      final service = MidiService(useBackgroundWorker: false);

      await service.sendCC(10, 64, isFinal: true);
      await callCompleter.future;

      expect(capturedEvents.length, 2);
      expect(capturedEvents[0], isNot(0));
      expect(capturedEvents[1], 1);
    });

    test('sends non-final CC through sendCC and native transport', () async {
      final service = MidiService(useBackgroundWorker: false);

      await service.sendCC(20, 32, isFinal: false);
      await callCompleter.future;

      expect(capturedEvents.length, 2);
      expect(capturedEvents[0], isNot(0));
      expect(capturedEvents[1], 0);
    });

    test('packs pitch bend as LSB then MSB on the assigned channel', () async {
      final service = MidiService(useBackgroundWorker: false);
      addTearDown(service.dispose);

      await service.sendPitchBend(0, channel: 2, isFinal: true);
      await service.sendPitchBend(8192, channel: 2, isFinal: true);
      await service.sendPitchBend(16383, channel: 2, isFinal: true);
      expect(allEvents, [0x20E20000, 1, 0x20E20040, 1, 0x20E27F7F, 1]);
    });

    test('preserves MT 4 words and flags in mixed outbound batches', () async {
      final service = MidiService(useBackgroundWorker: false);
      addTearDown(service.dispose);

      await service.sendAbsoluteCc32(6, 1, channel: 2, isFinal: true);
      expect(allEvents, isEmpty);
      await service.sendPitchBend32(0, channel: 2);
      await service.sendCC(10, 64, channel: 2);
      await service.sendAbsoluteCc32(74, 0xFFFFFFFF, channel: 2, isFinal: true);

      expect(capturedEvents, [
        -2,
        0x40E20000,
        0,
        0,
        0x20B20A40,
        0,
        0,
        0x40B24A00,
        0xFFFFFFFF,
        1,
      ]);
    });

    test('sends an ordered high-resolution CC pair together', () async {
      final service = MidiService(useBackgroundWorker: false);
      addTearDown(service.dispose);

      await service.sendHighResolutionCc(7, (64 << 7) | 23, channel: 4);
      expect(capturedEvents, [0x20B40740, 1, 0x20B42717, 1]);
    });

    test(
      'transport gates send reliable CC and notes without local feedback',
      () {
        final service = MidiService(useBackgroundWorker: false);
        addTearDown(service.dispose);
        final gate = MidiGate.transport();
        const cc = CcPayload(channel: 2, cc: 10);
        const note = NotePayload(channel: 3, note: 60);
        const highResolution = CcPayload(
          channel: 5,
          cc: 1,
          highResolution: true,
        );

        for (final payload in [cc, note, highResolution]) {
          gate.press(service, payload);
          gate.release();
        }

        expect(allEvents, [
          0x20B20A7F,
          3,
          0x20B20A00,
          3,
          0x20933C7F,
          3,
          0x20833C00,
          3,
          0x20B5017F,
          3,
          0x20B5217F,
          3,
          0x20B50100,
          3,
          0x20B52100,
          3,
        ]);
        expect(service.currentState['buttons'], isNull);
      },
    );

    test(
      'delivers each relative step without altering absolute CC feedback',
      () async {
        final service = MidiService(useBackgroundWorker: false);
        addTearDown(service.dispose);

        for (final encoding in RelativeCcEncoding.values) {
          final payload = RelativeCcPayload(
            channel: 3,
            cc: 16,
            encoding: encoding,
          );
          await service.sendRelativeCc(payload, 0);
          await service.sendRelativeCc(payload, 1);
          await service.sendRelativeCc(payload, 1);
          await service.sendRelativeCc(payload, -1);
        }

        expect(allEvents, [
          0x20B31001,
          1,
          0x20B31001,
          1,
          0x20B31041,
          1,
          0x20B31001,
          1,
          0x20B31001,
          1,
          0x20B3107F,
          1,
          0x20B31041,
          1,
          0x20B31041,
          1,
          0x20B3103F,
          1,
        ]);
        final ccs = service.currentState['ccs'] as Map?;
        expect(ccs?.containsKey('3:16'), isNot(isTrue));
      },
    );

    test('splits a relative movement into lossless ordered steps', () async {
      final service = MidiService(useBackgroundWorker: false);
      addTearDown(service.dispose);
      const payload = RelativeCcPayload(
        channel: 3,
        cc: 16,
        encoding: RelativeCcEncoding.binaryOffset,
      );

      await service.sendRelativeCc(payload, -70);
      expect(capturedEvents, [0x20B31001, 1, 0x20B31039, 1]);
    });
  });
}
