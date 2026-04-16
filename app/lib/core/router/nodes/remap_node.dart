// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import '../../models/midi_event.dart';
import '../transformer_node.dart';

/// A node that remaps [MidiEvent] CC values or changes CC numbers.
class RemapNode extends TransformerNode {
  final int sourceCc;
  final int destCc;
  final int sourceMin;
  final int sourceMax;
  final int destMin;
  final int destMax;

  RemapNode({
    required this.sourceCc,
    required this.destCc,
    this.sourceMin = 0,
    this.sourceMax = 127,
    this.destMin = 0,
    this.destMax = 127,
  });

  @override
  List<MidiEvent> process(List<MidiEvent> events) {
    if (events.isEmpty) return events;

    bool needsTransformation = false;
    for (final event in events) {
      if (event.messageType == 0x2 &&
          (event.status & 0xF0) == 0xB0 &&
          event.data1 == sourceCc) {
        needsTransformation = true;
        break;
      }
    }

    if (!needsTransformation) return events;

    final remapped = <MidiEvent>[];
    for (final event in events) {
      if (event.messageType == 0x2 &&
          (event.status & 0xF0) == 0xB0 &&
          event.data1 == sourceCc) {
        final val = event.data2;
        // Clamp input value to source range
        int clampedVal = val < sourceMin
            ? sourceMin
            : (val > sourceMax ? sourceMax : val);

        // Scale to destination range
        int mappedVal;
        if (sourceMax == sourceMin) {
          mappedVal = destMin;
        } else {
          // Linear mapping
          double normalized =
              (clampedVal - sourceMin) / (sourceMax - sourceMin);
          mappedVal = (destMin + normalized * (destMax - destMin)).round();
        }

        // Reconstruct the 32-bit UMP integer with the new CC number and value
        // UMP format for MIDI 1.0 Voice:
        // [4 bits Message Type][4 bits Group][8 bits Status][8 bits Data1][8 bits Data2]

        // Clear out the old Data1 and Data2 bytes (lower 16 bits)
        int umpWithoutData = event.ump & 0xFFFF0000;

        // Ensure new CC number and mapped value are within 8-bit limits
        int finalData1 = destCc & 0xFF;
        int finalData2 = mappedVal & 0xFF;

        int newUmp = umpWithoutData | (finalData1 << 8) | finalData2;

        remapped.add(
          MidiEvent(newUmp, event.timestamp, sourceId: event.sourceId),
        );
      } else {
        remapped.add(event);
      }
    }
    return remapped;
  }
}
