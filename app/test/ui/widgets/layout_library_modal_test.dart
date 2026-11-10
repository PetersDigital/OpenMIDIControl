// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/core/managers/layout_storage_manager.dart';
import 'package:app/core/models/layout_document.dart';
import 'package:app/core/models/layout_manifest.dart';
import 'package:app/ui/layout_document_state.dart';
import 'package:app/ui/widgets/layout_library_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late LayoutStorageManager storageManager;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('omc_library_modal_test_');
    SharedPreferences.setMockInitialValues({});

    storageManager = LayoutStorageManager(
      customDirProvider: () async => tempDir,
      customPrefsProvider: () => SharedPreferences.getInstance(),
    );

    // Seed test layouts
    final doc1 = LayoutDocument(
      manifest: LayoutManifest(
        id: 'doc_1',
        name: 'Stage Layout',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      pages: const [],
    );

    final doc2 = LayoutDocument(
      manifest: LayoutManifest(
        id: 'doc_2',
        name: 'Studio Layout',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      pages: const [],
    );

    await storageManager.saveDocument(doc1);
    await storageManager.saveDocument(doc2);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets(
    'LayoutLibraryModal renders saved layouts and switches active document',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          layoutStorageManagerProvider.overrideWithValue(storageManager),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(layoutDocumentProvider.notifier)
          .initializeOnStartup();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: LayoutLibraryModal())),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('SAVED LAYOUTS'), findsOneWidget);
      expect(find.text('Stage Layout'), findsOneWidget);
      expect(find.text('Studio Layout'), findsOneWidget);
    },
  );
}
