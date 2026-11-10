// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/ui/settings/tabs/files_tab.dart';
import 'package:app/ui/widgets/manifest_editor_modal.dart';

void main() {
  group('Manifest Metadata UI Tests', () {
    testWidgets(
      'FilesTab displays Layout Metadata section and opens ManifestEditorModal',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: Scaffold(body: FilesTab())),
          ),
        );

        // Verify Manifest section exists
        expect(find.text('LAYOUT METADATA'), findsOneWidget);
        expect(find.text('DEFAULT LAYOUT'), findsOneWidget);

        // Tap on the card
        await tester.tap(find.text('DEFAULT LAYOUT'));
        await tester.pumpAndSettle();

        // Modal dialog appears
        expect(find.byType(ManifestEditorModal), findsOneWidget);
        expect(
          find.text('LAYOUT METADATA'),
          findsNWidgets(2),
        ); // section + title

        // Change layout name and author
        await tester.enterText(
          find.widgetWithText(TextField, 'Layout Name'),
          'Techno Rig',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Author / Creator'),
          'DJ Producer',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'synth, drums, live'),
          'acid, modular, live',
        );

        // Tap SAVE
        await tester.tap(find.text('SAVE'));
        await tester.pumpAndSettle();

        // Modal is closed and FilesTab reflects the new name
        expect(find.byType(ManifestEditorModal), findsNothing);
        expect(find.text('TECHNO RIG'), findsOneWidget);
        expect(find.textContaining('DJ Producer'), findsOneWidget);
      },
    );
  });
}
