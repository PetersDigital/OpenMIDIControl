// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/ui/widgets/page_management.dart';
import 'package:app/core/models/layout_models.dart';

void main() {
  testWidgets('PageManagementSection can add a new page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CustomScrollView(slivers: [PageManagementSection()]),
          ),
        ),
      ),
    );

    // Verify initial pages are loaded (or check if list elements exist)
    expect(find.text('PAGE MANAGEMENT'), findsOneWidget);
    expect(find.text('+ ADD NEW PAGE'), findsOneWidget);

    // Tap "+ ADD NEW PAGE" button
    await tester.tap(find.text('+ ADD NEW PAGE'));
    await tester.pumpAndSettle();

    // Verify that the bottom sheet modal appeared
    expect(find.text('ADD NEW PAGE'), findsOneWidget);
    expect(find.text('CREATE PAGE'), findsOneWidget);

    // Try tapping "CREATE PAGE" without entering a name (name is empty)
    await tester.tap(find.text('CREATE PAGE'));
    await tester.pumpAndSettle();

    // The modal should still be visible because name is empty
    expect(find.text('ADD NEW PAGE'), findsOneWidget);

    // Enter page name
    await tester.enterText(find.byType(TextField), 'Test Custom Page');
    await tester.pumpAndSettle();

    // Tap "CREATE PAGE"
    await tester.tap(find.text('CREATE PAGE'));
    await tester.pumpAndSettle();

    // Verify modal is closed
    expect(find.text('ADD NEW PAGE'), findsNothing);

    // Verify the new page is in the list
    expect(find.text('Test Custom Page'), findsOneWidget);
  });

  testWidgets('PageManagementSection updates page type dropdown correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CustomScrollView(slivers: [PageManagementSection()]),
          ),
        ),
      ),
    );

    await tester.tap(find.text('+ ADD NEW PAGE'));
    await tester.pumpAndSettle();

    // The default selected type is UTILITY (since PageType.utility is initialValue)
    // Let's open the dropdown and select DRUMPAD
    await tester.tap(find.byType(DropdownButtonFormField<PageType>));
    await tester.pumpAndSettle();

    // Select the "DRUMPAD" item from the menu
    await tester.tap(find.text('DRUMPAD').last);
    await tester.pumpAndSettle();

    // Enter name
    await tester.enterText(find.byType(TextField), 'Drum Page');
    await tester.pumpAndSettle();

    // Tap "CREATE PAGE"
    await tester.tap(find.text('CREATE PAGE'));
    await tester.pumpAndSettle();

    // Verify the page was created and has the type "DRUMPAD"
    expect(find.text('Drum Page'), findsOneWidget);
    expect(find.text('DRUMPAD'), findsNWidgets(2));
  });
}
