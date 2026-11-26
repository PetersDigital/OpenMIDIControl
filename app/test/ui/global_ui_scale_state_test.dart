// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:app/ui/global_ui_scale_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads a safe scale from missing or invalid preferences', () async {
    for (final (Object? stored, double expected) in [
      (null, 1.0),
      ('invalid', 1.0),
      (double.nan, 1.0),
      (0.5, 0.75),
      (2.0, 1.35),
    ]) {
      SharedPreferences.setMockInitialValues({
        GlobalUiScaleNotifier.storageKey: ?stored,
      });
      final container = ProviderContainer.test();
      expect(await container.read(globalUiScaleProvider.future), expected);
    }
  });

  test(
    'persists the last requested scale while initial loading completes',
    () async {
      SharedPreferences.setMockInitialValues({
        GlobalUiScaleNotifier.storageKey: 0.85,
      });
      final container = ProviderContainer.test();
      final notifier = container.read(globalUiScaleProvider.notifier);
      await Future.wait([notifier.setScale(0.95), notifier.setScale(1.25)]);
      expect(container.read(globalUiScaleProvider).value, 1.25);

      final restarted = ProviderContainer.test();
      expect(await restarted.read(globalUiScaleProvider.future), 1.25);
    },
  );
}
