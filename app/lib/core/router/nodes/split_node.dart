// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import '../../models/midi_event.dart';
import '../transformer_node.dart';

/// A semantic pass-through node for duplicating streams.
///
/// While mathematically redundant in an adjacency list router, it serves
/// as a critical structural marker for visual layout editors.
class SplitNode extends TransformerNode {
  @override
  MidiEvent? processSingle(MidiEvent event) {
    return event;
  }

  @override
  List<MidiEvent> process(List<MidiEvent> events) {
    // Simply passes the batch through unmodified. The router's adjacency list
    // handles dispatching this output to all defined children.
    return events;
  }
}
