// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/midi_event.dart';
import 'sink_node.dart';

class NativeTransportSinkNode extends SinkNode {
  final MethodChannel channel;

  NativeTransportSinkNode({required this.channel});

  @override
  void execute(List<MidiEvent> events) {
    final batch = <Map<String, dynamic>>[];
    for (var event in events) {
      if (event.legacyStatusByte >= 0xB0 && event.legacyStatusByte <= 0xBF) {
        // We assume CC events for now as per MidiService.sendCC
        // isFinal is a bit tricky here since we don't track touch end state in the DAG yet.
        // We'll default to false, as rapid routing updates don't easily map to touch events.
        batch.add({'ump': event.ump, 'isFinal': false});
      }
    }

    if (batch.isNotEmpty) {
      channel.invokeMethod('sendMidiCCBatch', {'events': batch}).catchError((
        e,
      ) {
        debugPrint('Failed to send MIDI CC batch: $e');
      });
    }
  }
}
