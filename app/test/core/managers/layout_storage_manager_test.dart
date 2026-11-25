// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/core/managers/layout_storage_manager.dart';
import 'package:app/core/models/layout_document.dart';
import 'package:app/core/models/layout_manifest.dart';
import 'package:app/core/models/layout_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late LayoutStorageManager storageManager;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('omc_storage_test_');
    SharedPreferences.setMockInitialValues({});

    storageManager = LayoutStorageManager(
      customDirProvider: () async => tempDir,
      customPrefsProvider: () => SharedPreferences.getInstance(),
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('LayoutStorageManager Tests', () {
    test(
      'saveDocument, loadDocument, and listDocuments work correctly',
      () async {
        final now = DateTime.now();
        final manifest = LayoutManifest(
          id: 'doc_alpha',
          name: 'Alpha Layout',
          author: 'Tester',
          createdAt: now,
          updatedAt: now,
        );

        final page = LayoutPage(
          id: 'page_1',
          type: PageType.fader,
          name: 'FADERS',
          controls: [],
        );

        final doc = LayoutDocument(
          manifest: manifest,
          pages: [page],
          activePageIndex: 0,
        );

        // Save
        await storageManager.saveDocument(doc);

        final file = File('${tempDir.path}/doc_alpha.omc');
        expect(await file.exists(), isTrue);

        // Load
        final loaded = await storageManager.loadDocument('doc_alpha');
        expect(loaded, isNotNull);
        expect(loaded!.manifest.id, 'doc_alpha');
        expect(loaded.manifest.name, 'Alpha Layout');
        expect(loaded.pages.length, 1);

        // List
        final allDocs = await storageManager.listDocuments();
        expect(allDocs.length, 1);
        expect(allDocs.first.manifest.id, 'doc_alpha');

        // Delete
        await storageManager.deleteDocument('doc_alpha');
        expect(await file.exists(), isFalse);
        expect(await storageManager.loadDocument('doc_alpha'), isNull);
      },
    );

    test('active document ID persistence in SharedPreferences', () async {
      expect(await storageManager.getActiveDocumentId(), isNull);

      await storageManager.setActiveDocumentId('active_123');
      expect(await storageManager.getActiveDocumentId(), 'active_123');
    });
  });
}
