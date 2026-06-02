// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/ui/widgets/page_management.dart';
import 'package:app/core/models/layout_models.dart';
import 'package:app/ui/layout_state.dart';

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

  test(
    'LayoutStateNotifier reorders pages correctly (onReorderItem behavior)',
    () {
      final container = ProviderContainer();

      // Initial pages: FADERS (page_0), XYPAD (page_1), PADS (page_2), UTILITY (page_3)
      final initialPages = container.read(layoutStateProvider).pages;
      expect(initialPages[0].id, 'page_0');
      expect(initialPages[1].id, 'page_1');
      expect(initialPages[2].id, 'page_2');
      expect(initialPages[3].id, 'page_3');

      final notifier = container.read(layoutStateProvider.notifier);

      // Reorder page_0 (FADERS) to index 2 (between PADS and UTILITY)
      // with onReorderItem: oldIndex = 0, newIndex = 2
      notifier.reorderPages(0, 2);

      var pages = container.read(layoutStateProvider).pages;
      expect(pages[0].id, 'page_1');
      expect(pages[1].id, 'page_2');
      expect(pages[2].id, 'page_0');
      expect(pages[3].id, 'page_3');

      // Reorder page_0 (at index 2) back to index 0
      // with onReorderItem: oldIndex = 2, newIndex = 0
      notifier.reorderPages(2, 0);

      pages = container.read(layoutStateProvider).pages;
      expect(pages[0].id, 'page_0');
      expect(pages[1].id, 'page_1');
      expect(pages[2].id, 'page_2');
      expect(pages[3].id, 'page_3');
    },
  );

  testWidgets('PageManagementSection can delete a page and undo it', (
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

    // Initial pages include 'FADER' (one for title, one for type subtitle)
    expect(find.text('FADER'), findsNWidgets(2));

    // Tap delete button for the first page
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    // Verify dialog is shown
    expect(find.text('Delete Page'), findsOneWidget);

    // Tap DELETE in dialog
    await tester.tap(find.text('DELETE'));
    await tester.pumpAndSettle();

    // Dialog should be closed, and 'FADER' removed from the list
    expect(find.text('Delete Page'), findsNothing);
    expect(find.text('FADER'), findsNothing);

    // Verify SnackBar is shown with text 'FADER deleted'
    expect(find.text('FADER deleted'), findsOneWidget);
    expect(find.text('UNDO'), findsOneWidget);

    // Tap UNDO
    await tester.tap(find.text('UNDO'));
    await tester.pumpAndSettle();

    // Verify 'FADER' is restored
    expect(find.text('FADER'), findsNWidgets(2));

    // Elapse any remaining SnackBar dismiss timers to avoid pending timer failure
    await tester.pump(const Duration(seconds: 5));
  });
}
