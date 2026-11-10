// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/core/managers/layout_storage_manager.dart';
import 'package:app/ui/layout_document_state.dart';
import 'package:app/ui/layout_state.dart';
import 'package:app/core/models/layout_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late LayoutStorageManager storageManager;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('omc_autosave_test_');
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

  group('LayoutDocumentNotifier Auto-Save & Startup Tests', () {
    test(
      'initializeOnStartup creates and persists initial document if none exists',
      () async {
        final container = ProviderContainer(
          overrides: [
            layoutStorageManagerProvider.overrideWithValue(storageManager),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(layoutDocumentProvider.notifier)
            .initializeOnStartup();

        final activeDoc = container.read(layoutDocumentProvider);
        final activeId = await storageManager.getActiveDocumentId();
        expect(activeId, activeDoc.manifest.id);

        final persisted = await storageManager.loadDocument(activeId!);
        expect(persisted, isNotNull);
        expect(persisted!.manifest.name, 'Default Layout');
      },
    );

    test('flushSave persists updated manifest immediately', () async {
      final container = ProviderContainer(
        overrides: [
          layoutStorageManagerProvider.overrideWithValue(storageManager),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(layoutDocumentProvider.notifier)
          .initializeOnStartup();
      container
          .read(layoutDocumentProvider.notifier)
          .updateManifest(name: 'Flushed Name');

      await container.read(layoutDocumentProvider.notifier).flushSave();

      final activeId = await storageManager.getActiveDocumentId();
      final loaded = await storageManager.loadDocument(activeId!);
      expect(loaded!.manifest.name, 'Flushed Name');
    });

    test(
      'layoutState mutations trigger document synchronization and debounced save',
      () async {
        final container = ProviderContainer(
          overrides: [
            layoutStorageManagerProvider.overrideWithValue(storageManager),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(layoutDocumentProvider.notifier)
            .initializeOnStartup();

        // Add a page to layout state
        container
            .read(layoutStateProvider.notifier)
            .addPage(PageType.xyPad, 'NEW XY');

        final activeDoc = container.read(layoutDocumentProvider);
        expect(activeDoc.pages.length, 5);
        expect(activeDoc.pages.last.name, 'NEW XY');

        // Wait for debounce (1000ms + margin)
        await Future<void>.delayed(const Duration(milliseconds: 1100));

        final activeId = await storageManager.getActiveDocumentId();
        final loaded = await storageManager.loadDocument(activeId!);
        expect(loaded!.pages.length, 5);
        expect(loaded.pages.last.name, 'NEW XY');
      },
    );
  });
}
