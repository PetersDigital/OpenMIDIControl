// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/ui/layout_document_state.dart';
import 'package:app/ui/layout_state.dart';
import 'package:app/core/models/layout_models.dart';
import 'package:app/core/models/layout_manifest.dart';
import 'package:app/core/models/layout_document.dart';

void main() {
  group('LayoutDocumentNotifier Tests', () {
    test(
      'initializes with default manifest and mirrors layoutStateProvider pages',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final doc = container.read(layoutDocumentProvider);
        expect(doc.schemaVersion, 1);
        expect(doc.manifest.name, 'Default Layout');
        expect(doc.manifest.author, 'Anonymous');
        expect(doc.manifest.version, '1.0.0');
        expect(doc.pages.length, 4);
        expect(doc.activePageIndex, 0);
      },
    );

    test('updateManifest modifies manifest properties', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(layoutDocumentProvider.notifier)
          .updateManifest(
            name: 'Live Performance',
            author: 'Synthesist',
            version: '2.0.0',
            description: 'My live set mapping',
            tags: ['live', 'daw'],
          );

      final doc = container.read(layoutDocumentProvider);
      expect(doc.manifest.name, 'Live Performance');
      expect(doc.manifest.author, 'Synthesist');
      expect(doc.manifest.version, '2.0.0');
      expect(doc.manifest.description, 'My live set mapping');
      expect(doc.manifest.tags, ['live', 'daw']);
    });

    test(
      'setDocument replaces active document and syncs layoutStateProvider',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final newPage = LayoutPage(
          id: 'custom_page',
          type: PageType.xyPad,
          name: 'CUSTOM XY',
          controls: [],
        );

        final newDoc = LayoutDocument(
          manifest: LayoutManifest(
            id: 'custom_doc_id',
            name: 'Custom Doc',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          pages: [newPage],
          activePageIndex: 0,
        );

        container.read(layoutDocumentProvider.notifier).setDocument(newDoc);

        final activeDoc = container.read(layoutDocumentProvider);
        expect(activeDoc.manifest.id, 'custom_doc_id');
        expect(activeDoc.pages.length, 1);

        final layoutState = container.read(layoutStateProvider);
        expect(layoutState.pages.length, 1);
        expect(layoutState.pages.first.id, 'custom_page');
      },
    );
  });
}
