// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/models/control_state.dart';
import 'package:app/ui/diagnostics/diagnostics_logger.dart';

void main() {
  group('Performance Hardening Models', () {
    test('ControlState.raw initializes correctly and preserves version', () {
      final ccValues = {"0:1": 64};
      final noteStates = {
        60: {127},
      };
      final buttonStates = {"0:1": true};
      const version = 42;

      final state = ControlState.raw(
        version: version,
        ccValues: ccValues,
        noteStates: noteStates,
        buttonStates: buttonStates,
      );

      expect(state.version, version);
      expect(state.ccValues, ccValues);
      expect(state.noteStates, noteStates);
      expect(state.buttonStates, buttonStates);

      // Verify identity to ensure no copying happened in the raw constructor
      expect(identical(state.ccValues, ccValues), isTrue);
      expect(identical(state.noteStates, noteStates), isTrue);
      expect(identical(state.buttonStates, buttonStates), isTrue);
    });

    test('DiagnosticsState preserves version ID', () {
      final state = DiagnosticsState(entries: [], version: 123);
      expect(state.version, 123);
    });
  });
}
