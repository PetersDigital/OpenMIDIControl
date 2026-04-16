// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import '../models/midi_event.dart';

/// Abstract base class for all nodes in the MidiRouter DAG.
abstract class TransformerNode {
  /// Processes a batch of [MidiEvent]s.
  ///
  /// Implementing classes should filter, remap, or simply pass through the events
  /// and return the processed list.
  List<MidiEvent> process(List<MidiEvent> events);
}
