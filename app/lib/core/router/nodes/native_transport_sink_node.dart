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
      if (event.messageType == 0x2 && event.status == 0xB0) {
        // Forward explicit CC touch-finality semantics from routed MidiEvents.
        // Upstream routing may preserve isFinal for gesture completion events.
        batch.add({'ump': event.ump, 'isFinal': event.isFinal});
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
