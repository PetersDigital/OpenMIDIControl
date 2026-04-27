// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/ui/widgets/control_config_modal.dart';

void main() {
  testWidgets('ControlConfigModal renders correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ControlConfigModal(initialChannel: 0, initialIdentifier: 22),
        ),
      ),
    );

    expect(find.text('Configure Control'), findsOneWidget);
    expect(find.text('Channel 1'), findsOneWidget); // Dropdown selected item
    expect(find.widgetWithText(TextFormField, '22'), findsOneWidget);
  });

  testWidgets('ControlConfigModal validates identifier input', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ControlConfigModal())),
    );

    // Enter an invalid number
    await tester.enterText(find.byType(TextFormField), '150');
    await tester.pumpAndSettle();

    expect(find.text('Must be between 0 and 127'), findsOneWidget);
  });

  testWidgets('ControlConfigModal returns data on save', (
    WidgetTester tester,
  ) async {
    ControlConfigResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<ControlConfigResult>(
                  context: context,
                  builder: (context) => const ControlConfigModal(
                    initialChannel: 1,
                    initialIdentifier: 50,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Change value
    await tester.enterText(find.byType(TextFormField), '64');
    await tester.pumpAndSettle();

    // Tap Save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.channel, 1);
    expect(result!.identifier, 64);
  });

  testWidgets('ControlConfigModal returns null on cancel', (
    WidgetTester tester,
  ) async {
    ControlConfigResult? result = const ControlConfigResult(
      channel: 0,
      identifier: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final r = await showDialog<ControlConfigResult>(
                  context: context,
                  builder: (context) => const ControlConfigModal(),
                );
                // only overwrite if null was returned (to test if cancel works)
                result = r;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
