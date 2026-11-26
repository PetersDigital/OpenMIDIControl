// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:app/core/models/action_payload.dart';
import 'package:app/ui/midi_action_dispatcher.dart';
import 'package:app/ui/midi_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingMidiService implements MidiService {
  final sent = <(int, int, int, bool)>[];

  @override
  Future<void> sendCC(
    int cc,
    int value, {
    int channel = 0,
    bool isFinal = false,
  }) async {
    sent.add((channel, cc, value, isFinal));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'CC feedback requires a valid legacy address or an absolute assignment',
    () {
      expect(ccFeedbackAddress(null, -1, -1), isNull);
      expect(ccFeedbackAddress(null, -1, 9), isNull);
      expect(ccFeedbackAddress(null, 1, -1), isNull);
      expect(ccFeedbackAddress(null, 16, 9), isNull);
      expect(ccFeedbackAddress(null, 1, 128), isNull);
      expect(ccFeedbackAddress(null, 1, 9), '1:9');
      expect(
        ccFeedbackAddress(const CcPayload(channel: 2, cc: 19), -1, -1),
        '2:19',
      );
      expect(
        ccFeedbackAddress(const PitchBendPayload(channel: 2), 1, 9),
        isNull,
      );
    },
  );

  test(
    'continuous dispatch skips an unassigned fallback and sends valid CC',
    () {
      final service = _RecordingMidiService();
      final dispatch = MidiActionDispatcher();
      dispatch.sendPosition(
        service,
        null,
        0.5,
        legacyChannel: -1,
        legacyCc: -1,
      );
      dispatch.sendPosition(service, null, 0.5, legacyChannel: 0, legacyCc: -1);
      dispatch.sendPosition(
        service,
        null,
        0.5,
        legacyChannel: 0,
        legacyCc: 11,
        isFinal: true,
      );
      expect(service.sent, [(0, 11, 64, true)]);
    },
  );
}
