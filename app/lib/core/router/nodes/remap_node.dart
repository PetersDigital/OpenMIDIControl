// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:math' as math;
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
  }) : assert(sourceCc >= 0 && sourceCc <= 127),
       assert(destCc >= 0 && destCc <= 127),
       assert(sourceMin >= 0 && sourceMin <= 127),
       assert(sourceMax >= 0 && sourceMax <= 127),
       assert(destMin >= 0 && destMin <= 127),
       assert(destMax >= 0 && destMax <= 127);

  @override
  MidiEvent? processSingle(MidiEvent event) {
    if (event.messageType == 0x2 &&
        (event.status & 0xF0) == 0xB0 &&
        event.data1 == sourceCc) {
      final mappedVal = _remapValue(event.data2);

      int umpWithoutData = event.ump & 0xFFFF0000;
      final int finalData1 = destCc.clamp(0, 127);
      final int finalData2 = mappedVal.clamp(0, 127);
      int newUmp =
          ((umpWithoutData |
              ((finalData1 & 0xFF) << 8) |
              (finalData2 & 0xFF))) &
          0xFFFFFFFF;

      return MidiEvent(
        newUmp,
        event.timestamp,
        sourceId: event.sourceId,
        isFinal: event.isFinal,
      );
    }
    return event;
  }

  int _remapValue(int val) {
    // 1. Resolve actual min/max for the source range to handle inverted configuration.
    final srcMin = math.min(sourceMin, sourceMax);
    final srcMax = math.max(sourceMin, sourceMax);

    // 2. Guard input clamping against inverted source bounds.
    final clampedVal = val.clamp(srcMin, srcMax);

    // 3. Division by Zero Guard: Bypass scaling if the range is zero-width.
    if (sourceMax == sourceMin) {
      return destMin;
    }

    // 4. Linear mapping with integer arithmetic using rounded division.
    final diff = (clampedVal - sourceMin) * (destMax - destMin);
    final range = sourceMax - sourceMin;
    final rounding = diff >= 0 ? (range ~/ 2) : -(range ~/ 2);

    int mappedVal = destMin + (diff + rounding) ~/ range;

    // 5. Safe Clamp: Use resolved min/max to support inverted destination ranges (e.g., 127-0).
    final actualDestMin = math.min(destMin, destMax);
    final actualDestMax = math.max(destMin, destMax);

    return mappedVal.clamp(actualDestMin, actualDestMax);
  }

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
        final mappedVal = _remapValue(event.data2);

        int umpWithoutData = event.ump & 0xFFFF0000;
        final int finalData1 = destCc.clamp(0, 127);
        final int finalData2 = mappedVal.clamp(0, 127);

        int newUmp =
            ((umpWithoutData |
                ((finalData1 & 0xFF) << 8) |
                (finalData2 & 0xFF))) &
            0xFFFFFFFF;

        remapped.add(
          MidiEvent(
            newUmp,
            event.timestamp,
            sourceId: event.sourceId,
            isFinal: event.isFinal,
          ),
        );
      } else {
        remapped.add(event);
      }
    }
    return remapped;
  }
}
