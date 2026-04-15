// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/models/control_state.dart';

void main() {
  group('ControlState', () {
    test('Constructor creates immutable ccValues map', () {
      final state = ControlState(ccValues: {1: 64, 2: 127});

      expect(state.ccValues[1], 64);
      expect(state.ccValues[2], 127);
      expect(() => state.ccValues[3] = 0, throwsUnsupportedError);
    });

    test('Constructor defensively copies input map', () {
      final mutableMap = <int, int>{1: 64};
      final state = ControlState(ccValues: mutableMap);

      // Mutating original should not affect state
      mutableMap[2] = 127;
      expect(state.ccValues.containsKey(2), isFalse);
    });

    test('copyWith returns new immutable instance with updated values', () {
      final original = ControlState(ccValues: {1: 64, 2: 32});

      final copied = original.copyWith(ccValues: {1: 100, 2: 32, 3: 64});

      expect(copied.ccValues[1], 100);
      expect(copied.ccValues[2], 32);
      expect(copied.ccValues[3], 64);
      expect(copied, isNot(same(original)));
    });

    test('copyWith with no arguments preserves existing state', () {
      final original = ControlState(ccValues: {1: 64});

      final copied = original.copyWith();

      expect(copied.ccValues, original.ccValues);
      expect(copied, isNot(same(original)));
    });

    test('copyWith produces immutable result', () {
      final state = ControlState(ccValues: {1: 64});
      final copied = state.copyWith(ccValues: {1: 100});

      expect(() => copied.ccValues[2] = 0, throwsUnsupportedError);
    });

    test('copyWithCC updates a single CC number correctly', () {
      final state = ControlState(ccValues: {1: 64, 2: 32});

      final updated = state.copyWithCC(1, 100);

      expect(updated.ccValues[1], 100);
      expect(updated.ccValues[2], 32);
      expect(updated, isNot(same(state)));
    });

    test('copyWithCC adds new CC when key does not exist', () {
      final state = ControlState(ccValues: {1: 64});

      final updated = state.copyWithCC(10, 127);

      expect(updated.ccValues[10], 127);
      expect(updated.ccValues[1], 64);
    });

    test('copyWithCC produces immutable result', () {
      final state = ControlState(ccValues: {1: 64});
      final updated = state.copyWithCC(1, 100);

      expect(() => updated.ccValues[2] = 0, throwsUnsupportedError);
    });

    test('copyWithCC preserves existing CCs unchanged', () {
      final state = ControlState(ccValues: {1: 64, 2: 32, 3: 16});

      final updated = state.copyWithCC(2, 100);

      expect(updated.ccValues[1], 64);
      expect(updated.ccValues[2], 100);
      expect(updated.ccValues[3], 16);
    });
  });
}
