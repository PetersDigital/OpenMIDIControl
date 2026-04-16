// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import '../../models/midi_event.dart';
import '../transformer_node.dart';

/// A node that filters incoming [MidiEvent]s based on specific criteria.
class FilterNode extends TransformerNode {
  final int? allowedChannel;
  final int? allowedMessageType;
  final int? minCc;
  final int? maxCc;

  FilterNode({
    this.allowedChannel,
    this.allowedMessageType,
    this.minCc,
    this.maxCc,
  });

  @override
  List<MidiEvent> process(List<MidiEvent> events) {
    if (events.isEmpty) return events;

    final filtered = <MidiEvent>[];
    for (final event in events) {
      if (allowedChannel != null && event.channel != allowedChannel) {
        continue;
      }
      if (allowedMessageType != null &&
          event.messageType != allowedMessageType) {
        continue;
      }
      if (minCc != null || maxCc != null) {
        // Only apply CC range filtering to Control Change messages
        // Assuming MIDI 1.0 Voice Message (0x2) and CC status (0xB0 to 0xBF)
        // messageType == 2, status == 0xB0
        if (event.messageType == 0x2 && event.status == 0xB0) {
          final ccNumber = event.data1;
          if (minCc != null && ccNumber < minCc!) continue;
          if (maxCc != null && ccNumber > maxCc!) continue;
        }
      }
      filtered.add(event);
    }
    return filtered;
  }
}
