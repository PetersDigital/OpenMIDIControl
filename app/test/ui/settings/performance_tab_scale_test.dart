// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:app/ui/global_ui_scale_state.dart';
import 'package:app/ui/settings/tabs/performance_tab.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Performance settings loads and saves the grid scale', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      GlobalUiScaleNotifier.storageKey: 0.85,
    });
    final container = ProviderContainer.test();
    await container.read(globalUiScaleProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: PerformanceTab())),
      ),
    );

    expect(find.text('85%'), findsOneWidget);
    final slider = tester.getRect(find.byType(Slider).first);
    await tester.tapAt(Offset(slider.right - 2, slider.center.dy));
    await tester.pumpAndSettle();
    expect(container.read(globalUiScaleProvider).value, 1.35);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble(GlobalUiScaleNotifier.storageKey), 1.35);
    expect(find.text('135%'), findsWidgets);
  });
}
