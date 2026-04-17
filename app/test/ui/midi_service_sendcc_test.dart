// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/ui/midi_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MidiService.sendCC', () {
    const channel = MethodChannel('com.petersdigital.openmidicontrol/midi');
    late List<Map<dynamic, dynamic>> capturedEvents;
    late Completer<void> callCompleter;

    setUp(() {
      capturedEvents = [];
      callCompleter = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'sendMidiCCBatch') {
              final events = (call.arguments as Map)['events'] as List<dynamic>;
              capturedEvents = events.cast<Map<dynamic, dynamic>>();
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

      expect(capturedEvents.length, 1);
      expect(capturedEvents.first['isFinal'], isTrue);
    });
  });
}
