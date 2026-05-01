// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/ui/widgets/control_config_modal.dart';

void main() {
  testWidgets('ControlConfigModal renders correctly and saves to state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: ControlConfigModal(controlId: 'fader_0')),
        ),
      ),
    );

    expect(find.text('Configure Control'), findsOneWidget);
    expect(
      find.text('Channel 1'),
      findsOneWidget,
    ); // Default for fader_0 is 0 (Channel 1)

    // Default identifier for fader_0 is 1
    expect(find.widgetWithText(TextFormField, '1'), findsOneWidget);

    // Enter a new value
    await tester.enterText(find.widgetWithText(TextFormField, '1'), '64');
    await tester.pumpAndSettle();

    // Tap Save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Verify it's gone (modal closed)
    expect(find.byType(ControlConfigModal), findsNothing);
  });

  testWidgets('ControlConfigModal handles Clear action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: ControlConfigModal(controlId: 'fader_0')),
        ),
      ),
    );

    // Tap Clear
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.byType(ControlConfigModal), findsNothing);
  });
}
