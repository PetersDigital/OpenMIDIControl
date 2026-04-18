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
    final batch = Int64List(events.length * 2);
    var writeIndex = 0;
    for (var event in events) {
      if (event.messageType == 0x2 && (event.legacyStatusByte & 0xF0) == 0xB0) {
        // Forward explicit CC touch-finality semantics from routed MidiEvents.
        // Upstream routing may preserve isFinal for gesture completion events.
        batch[writeIndex++] = event.ump;
        batch[writeIndex++] = event.isFinal ? 1 : 0;
      }
    }

    if (writeIndex > 0) {
      channel.invokeMethod('sendMidiCCBatch', {'events': batch}).catchError((
        e,
      ) {
        debugPrint('Failed to send MIDI CC batch: $e');
      });
    }
  }
}
