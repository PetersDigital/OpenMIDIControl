// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/models/midi_event.dart';
import 'package:app/core/router/nodes/filter_node.dart';
import 'package:app/core/router/nodes/remap_node.dart';
import 'package:app/core/router/nodes/split_node.dart';

void main() {
  group('Transformer Nodes Unit Tests', () {
    // Helper to generate UMP integers
    // UMP format for MIDI 1.0 Voice:
    // [4 bits Message Type][4 bits Group][8 bits Status][8 bits Data1][8 bits Data2]
    int createUmp(
      int messageType,
      int group,
      int status,
      int data1,
      int data2,
    ) {
      return (messageType << 28) |
          (group << 24) |
          (status << 16) |
          (data1 << 8) |
          data2;
    }

    test('FilterNode properly filters by channel', () {
      final filter = FilterNode(
        allowedChannel: 2,
      ); // 0-indexed, so channel 2 is 0x_2

      final events = [
        MidiEvent(createUmp(0x2, 0, 0xB0, 10, 127), 0), // CC on ch 0
        MidiEvent(createUmp(0x2, 0, 0xB2, 10, 127), 0), // CC on ch 2 (allowed)
        MidiEvent(createUmp(0x2, 0, 0xB3, 10, 127), 0), // CC on ch 3
      ];

      final result = filter.process(events);
      expect(result.length, 1);
      expect(result.first.channel, 2);
    });

    test('FilterNode properly filters by message type', () {
      final filter = FilterNode(allowedMessageType: 0x2); // Only MIDI 1.0 Voice

      final events = [
        MidiEvent(createUmp(0x1, 0, 0xF8, 0, 0), 0), // System Real-Time
        MidiEvent(
          createUmp(0x2, 0, 0xB0, 10, 127),
          0,
        ), // MIDI 1.0 Voice (allowed)
      ];

      final result = filter.process(events);
      expect(result.length, 1);
      expect(result.first.messageType, 0x2);
    });

    test('FilterNode properly filters by CC range', () {
      final filter = FilterNode(minCc: 10, maxCc: 20);

      final events = [
        MidiEvent(createUmp(0x2, 0, 0xB0, 5, 127), 0), // Too low
        MidiEvent(createUmp(0x2, 0, 0xB0, 15, 127), 0), // In range (allowed)
        MidiEvent(createUmp(0x2, 0, 0xB0, 25, 127), 0), // Too high
      ];

      final result = filter.process(events);
      expect(result.length, 1);
      expect(result.first.data1, 15);
    });

    test('FilterNode applies CC range filtering across MIDI channels', () {
      final filter = FilterNode(minCc: 10, maxCc: 20);

      final events = [
        MidiEvent(createUmp(0x2, 0, 0xB2, 9, 127), 0), // ch 2, too low
        MidiEvent(createUmp(0x2, 0, 0xB2, 12, 127), 0), // ch 2, in range
        MidiEvent(createUmp(0x2, 0, 0xBF, 30, 127), 0), // ch 15, too high
      ];

      final result = filter.process(events);
      expect(result.length, 1);
      expect(result.first.channel, 2);
      expect(result.first.data1, 12);
    });

    test('RemapNode accurately remaps CC values', () {
      final remap = RemapNode(
        sourceCc: 10,
        destCc: 20,
        sourceMin: 0,
        sourceMax: 127,
        destMin: 0,
        destMax: 63, // Half scale
      );

      final events = [
        MidiEvent(createUmp(0x2, 0, 0xB0, 10, 127), 0), // Will be mapped to 63
        MidiEvent(createUmp(0x2, 0, 0xB0, 10, 64), 0), // Will be mapped to ~32
        MidiEvent(
          createUmp(0x2, 0, 0xB0, 5, 127),
          0,
        ), // Different CC, untouched
      ];

      final result = remap.process(events);
      expect(result.length, 3);

      // Check first remapped
      expect(result[0].data1, 20); // destCc
      expect(result[0].data2, 63); // max mapped

      // Check second remapped (half)
      expect(result[1].data1, 20);
      expect(result[1].data2, 32);

      // Check third (untouched)
      expect(result[2].data1, 5);
      expect(result[2].data2, 127);
    });

    test('RemapNode remaps CC values on non-zero MIDI channels', () {
      final remap = RemapNode(
        sourceCc: 10,
        destCc: 21,
        sourceMin: 0,
        sourceMax: 127,
        destMin: 0,
        destMax: 127,
      );

      final events = [
        MidiEvent(createUmp(0x2, 0, 0xB5, 10, 64), 0), // ch 5, remap target
        MidiEvent(createUmp(0x2, 0, 0xB6, 10, 32), 0), // ch 6, remap target
      ];

      final result = remap.process(events);
      expect(result.length, 2);
      expect(result[0].channel, 5);
      expect(result[0].data1, 21);
      expect(result[0].data2, 64);
      expect(result[1].channel, 6);
      expect(result[1].data1, 21);
      expect(result[1].data2, 32);
    });

    test('RemapNode remaps CC on Channel 4 (status 0xB3)', () {
      final remap = RemapNode(
        sourceCc: 10,
        destCc: 40,
        sourceMin: 0,
        sourceMax: 127,
        destMin: 0,
        destMax: 127,
      );

      final events = [MidiEvent(createUmp(0x2, 0, 0xB3, 10, 99), 0)];

      final result = remap.process(events);
      expect(result.length, 1);
      expect(result.first.channel, 3);
      expect(result.first.legacyStatusByte, 0xB3);
      expect(result.first.data1, 40);
      expect(result.first.data2, 99);
    });

    test(
      'RemapNode handles zero-width source range (division by zero guard)',
      () {
        final remap = RemapNode(
          sourceCc: 10,
          destCc: 10,
          sourceMin: 64,
          sourceMax: 64,
          destMin: 100,
          destMax: 120,
        );

        final events = [MidiEvent(createUmp(0x2, 0, 0xB0, 10, 64), 0)];

        // Should not throw and should return destMin per logic
        final result = remap.process(events);
        expect(result.first.data2, 100);
      },
    );

    test('RemapNode handles inverted destination range', () {
      final remap = RemapNode(
        sourceCc: 10,
        destCc: 10,
        sourceMin: 0,
        sourceMax: 127,
        destMin: 127,
        destMax: 0,
      );

      final events = [
        MidiEvent(createUmp(0x2, 0, 0xB0, 10, 0), 0), // Should map to 127
        MidiEvent(createUmp(0x2, 0, 0xB0, 10, 127), 0), // Should map to 0
        MidiEvent(createUmp(0x2, 0, 0xB0, 10, 64), 0), // Should map to ~63
      ];

      final result = remap.process(events);
      expect(result[0].data2, 127);
      expect(result[1].data2, 0);
      // Math: 127 + ((64 * -127) - 63) ~/ 127 = 127 + (-8128 - 63) ~/ 127 = 127 - 64 = 63
      expect(result[2].data2, 63);
    });

    test('SplitNode passes batches through unmodified', () {
      final split = SplitNode();
      final events = [
        MidiEvent(createUmp(0x2, 0, 0xB0, 10, 127), 0),
        MidiEvent(createUmp(0x2, 0, 0xB0, 11, 127), 0),
      ];

      final result = split.process(events);
      expect(result.length, 2);
      // Same references returned
      expect(result, same(events));
    });
  });
}
