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
  MidiEvent? processSingle(MidiEvent event) {
    if (allowedChannel != null && event.channel != allowedChannel) {
      return null;
    }
    if (allowedMessageType != null && event.messageType != allowedMessageType) {
      return null;
    }
    if (minCc != null || maxCc != null) {
      if (event.messageType == 0x2 && (event.legacyStatusByte & 0xF0) == 0xB0) {
        final ccNumber = event.data1;
        if (minCc != null && ccNumber < minCc!) return null;
        if (maxCc != null && ccNumber > maxCc!) return null;
      }
    }
    return event;
  }

  @override
  List<MidiEvent> process(List<MidiEvent> events) {
    if (events.isEmpty) return events;

    // Fast-path: check if any filtering is needed
    bool needsFiltering = false;
    for (int i = 0; i < events.length; i++) {
      final event = events[i];
      if (allowedChannel != null && event.channel != allowedChannel) {
        needsFiltering = true;
        break;
      }
      if (allowedMessageType != null &&
          event.messageType != allowedMessageType) {
        needsFiltering = true;
        break;
      }
      if (minCc != null || maxCc != null) {
        if (event.messageType == 0x2 &&
            (event.legacyStatusByte & 0xF0) == 0xB0) {
          final ccNumber = event.data1;
          if (minCc != null && ccNumber < minCc!) {
            needsFiltering = true;
            break;
          }
          if (maxCc != null && ccNumber > maxCc!) {
            needsFiltering = true;
            break;
          }
        }
      }
    }

    if (!needsFiltering) return events;

    final filtered = <MidiEvent>[];
    for (int i = 0; i < events.length; i++) {
      final event = events[i];
      if (allowedChannel != null && event.channel != allowedChannel) {
        continue;
      }
      if (allowedMessageType != null &&
          event.messageType != allowedMessageType) {
        continue;
      }
      if (minCc != null || maxCc != null) {
        if (event.messageType == 0x2 &&
            (event.legacyStatusByte & 0xF0) == 0xB0) {
          final ccNumber = event.data1;
          if (minCc != null && ccNumber < minCc!) continue;
          if (maxCc != null && ccNumber > maxCc!) continue;
        }
      }
      filtered.add(event); // Pass by reference
    }
    return filtered;
  }
}
