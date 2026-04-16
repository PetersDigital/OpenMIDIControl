// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import '../../models/midi_event.dart';
import 'sink_node.dart';

class UiStateSinkNode extends SinkNode {
  final void Function(Map<int, int>) onUpdateCCs;

  UiStateSinkNode({required this.onUpdateCCs});

  @override
  void execute(List<MidiEvent> events) {
    final Map<int, int> batchUpdates = {};
    for (var event in events) {
      if (event.legacyStatusByte >= 0xB0 && event.legacyStatusByte <= 0xBF) {
        batchUpdates[event.data1] = event.data2;
      }
    }

    if (batchUpdates.isNotEmpty) {
      onUpdateCCs(batchUpdates);
    }
  }
}
