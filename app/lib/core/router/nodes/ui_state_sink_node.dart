// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import '../../models/midi_event.dart';
import 'sink_node.dart';

class UiStateSinkNode extends SinkNode {
  final void Function(Map<int, int>) onUpdateCCs;

  UiStateSinkNode({required this.onUpdateCCs});

  @override
  void execute(List<MidiEvent> events) {
    // Lazy-init the batch update map only when a CC event is observed.
    // This avoids allocations for non-CC or empty event batches.
    Map<int, int>? batchUpdates;
    for (var event in events) {
      if (event.legacyStatusByte >= 0xB0 && event.legacyStatusByte <= 0xBF) {
        batchUpdates ??= {};
        batchUpdates[event.data1] = event.data2;
      }
    }

    if (batchUpdates != null) {
      onUpdateCCs(batchUpdates);
    }
  }
}
