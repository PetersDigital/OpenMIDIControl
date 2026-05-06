// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/models/control_state.dart';

void main() {
  group('ControlState', () {
    test('Constructor creates immutable ccValues map', () {
      final state = ControlState(
        ccValues: {"0:1": 64},
        noteStates: {},
        buttonStates: {},
      );

      expect(state.ccValues["0:1"], 64);
      expect(() => state.ccValues["0:1"] = 0, throwsUnsupportedError);
    });

    test('Constructor defensively copies input map', () {
      final mutableMap = <String, int>{"0:1": 64};
      final state = ControlState(
        ccValues: mutableMap,
        noteStates: {},
        buttonStates: {},
      );

      // Mutating original should not affect state
      mutableMap["0:2"] = 127;
      expect(state.ccValues.containsKey("0:2"), isFalse);
    });

    test('copyWith returns new immutable instance with updated values', () {
      final original = ControlState(
        ccValues: {"0:1": 64},
        noteStates: {},
        buttonStates: {},
      );

      final copied = original.copyWith(
        ccValues: {"0:1": 100, "0:2": 32, "0:3": 64},
      );

      expect(copied.ccValues["0:1"], 100);
      expect(copied.ccValues["0:2"], 32);
      expect(copied.ccValues["0:3"], 64);
      expect(copied, isNot(same(original)));
    });

    test('copyWith with no arguments preserves existing state', () {
      final original = ControlState(
        ccValues: {"0:1": 64},
        noteStates: {},
        buttonStates: {},
      );

      final copied = original.copyWith();

      expect(copied.ccValues, original.ccValues);
      expect(copied, isNot(same(original)));
    });

    test('copyWith updates a single CC address correctly', () {
      final state = ControlState(
        ccValues: {"0:1": 64},
        noteStates: {},
        buttonStates: {},
      );

      final updated = state.copyWith(
        ccValues: Map.of(state.ccValues)..["0:1"] = 100,
      );

      expect(updated.ccValues["0:1"], 100);

      expect(updated, isNot(same(state)));
    });

    test('copyWith adds new CC address when key does not exist', () {
      final state = ControlState(
        ccValues: {"0:1": 64},
        noteStates: {},
        buttonStates: {},
      );

      final updated = state.copyWith(
        ccValues: Map.of(state.ccValues)..["0:10"] = 127,
      );

      expect(updated.ccValues["0:10"], 127);
      expect(updated.ccValues["0:1"], 64);
    });

    test('copyWith preserves existing CCs unchanged', () {
      final state = ControlState(
        ccValues: {"0:1": 64},
        noteStates: {},
        buttonStates: {},
      );

      final updated = state.copyWith(
        ccValues: Map.of(state.ccValues)..["0:2"] = 100,
      );

      expect(updated.ccValues["0:1"], 64);

      expect(updated.ccValues["0:2"], 100);
    });
  });
}
