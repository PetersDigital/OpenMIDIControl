// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/managers/layout_storage_manager.dart';
import 'package:app/core/models/layout_document.dart';
import 'package:app/core/models/layout_manifest.dart';
import 'package:app/ui/layout_document_state.dart';
import 'package:app/ui/widgets/layout_library_modal.dart';

/// In-memory [LayoutStorageManager] fake for deterministic widget testing
/// without real filesystem I/O inside FakeAsync.
class _FakeLayoutStorageManager extends LayoutStorageManager {
  final Map<String, LayoutDocument> _docs = {};
  String? _activeId;

  @override
  Future<void> saveDocument(LayoutDocument document) async {
    _docs[document.manifest.id] = document;
  }

  @override
  Future<LayoutDocument?> loadDocument(String id) async => _docs[id];

  @override
  Future<List<LayoutDocument>> listDocuments() async => _docs.values.toList();

  @override
  Future<void> deleteDocument(String id) async {
    _docs.remove(id);
  }

  @override
  Future<String?> getActiveDocumentId() async => _activeId;

  @override
  Future<void> setActiveDocumentId(String id) async {
    _activeId = id;
  }
}

void main() {
  late _FakeLayoutStorageManager storageManager;

  setUp(() async {
    storageManager = _FakeLayoutStorageManager();

    final doc1 = LayoutDocument(
      manifest: LayoutManifest(
        id: 'doc_1',
        name: 'Stage Layout',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
      pages: const [],
    );

    final doc2 = LayoutDocument(
      manifest: LayoutManifest(
        id: 'doc_2',
        name: 'Studio Layout',
        createdAt: DateTime(2026, 1, 2),
        updatedAt: DateTime(2026, 1, 2),
      ),
      pages: const [],
    );

    await storageManager.saveDocument(doc1);
    await storageManager.saveDocument(doc2);
  });

  Future<void> openModal(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const LayoutLibraryModal(),
                ),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
  }

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

      await openModal(tester, container);

      expect(find.text('SAVED LAYOUTS'), findsOneWidget);
      expect(find.text('Stage Layout'), findsOneWidget);
      expect(find.text('Studio Layout'), findsOneWidget);

      // Tap Stage Layout to switch active document and close dialog
      await tester.tap(find.text('Stage Layout'));
      await tester.pumpAndSettle();

      expect(container.read(layoutDocumentProvider).manifest.id, 'doc_1');
      expect(
        container.read(layoutDocumentProvider).manifest.name,
        'Stage Layout',
      );
      expect(find.text('SAVED LAYOUTS'), findsNothing);
    },
  );

  testWidgets(
    'LayoutLibraryModal deletes non-active layout after confirmation',
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

      await openModal(tester, container);

      // Tap the delete button for Studio Layout (second delete icon)
      final deleteButtons = find.byIcon(Icons.delete_outline);
      expect(deleteButtons, findsNWidgets(2));
      await tester.tap(deleteButtons.last);
      await tester.pumpAndSettle();

      expect(find.text('DELETE LAYOUT'), findsOneWidget);
      await tester.tap(find.text('DELETE'));
      await tester.pumpAndSettle();

      expect(find.text('Studio Layout'), findsNothing);
      expect(await storageManager.loadDocument('doc_2'), isNull);
    },
  );
}
