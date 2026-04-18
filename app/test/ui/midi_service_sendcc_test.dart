// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/ui/midi_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MidiService.sendCC', () {
    const channel = MethodChannel('com.petersdigital.openmidicontrol/midi');
    late Int64List capturedEvents;
    late Completer<void> callCompleter;

    setUp(() {
      capturedEvents = Int64List(0);
      callCompleter = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'sendMidiCCBatch') {
              final events = (call.arguments as Map)['events'] as Int64List;
              capturedEvents = events;
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
      final service = MidiService();

      await service.sendCC(10, 64, isFinal: true);
      await callCompleter.future;

      expect(capturedEvents.length, 2);
      expect(capturedEvents[1], 1);
    });
  });
}
