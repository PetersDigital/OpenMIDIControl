// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/models/layout_manifest.dart';
import 'package:app/core/models/layout_models.dart';
import 'package:app/core/models/layout_document.dart';

void main() {
  group('LayoutDocument Envelope Tests', () {
    final now = DateTime.now();

    test('serializes to JSON and round-trips correctly', () {
      final manifest = LayoutManifest(
        id: 'doc_1',
        name: 'Main Layout',
        createdAt: now,
        updatedAt: now,
      );

      final control = LayoutControl(
        id: 'ctl_0',
        type: ControlType.fader,
        defaultCc: 1,
        channel: 0,
        x: 0,
        y: 0,
        width: 2,
        height: 3,
      );

      final page = LayoutPage(
        id: 'p_0',
        type: PageType.fader,
        name: 'FADER',
        controls: [control],
      );

      final document = LayoutDocument(
        schemaVersion: 1,
        manifest: manifest,
        pages: [page],
        activePageIndex: 0,
      );

      final json = document.toJson();
      expect(json['schemaVersion'], 1);
      expect(json['manifest']['id'], 'doc_1');
      expect(json['pages'].length, 1);
      expect(json['activePageIndex'], 0);

      final parsed = LayoutDocument.fromJson(json);
      expect(parsed.schemaVersion, 1);
      expect(parsed.manifest.name, 'Main Layout');
      expect(parsed.pages.length, 1);
      expect(parsed.pages.first.id, 'p_0');
      expect(parsed.pages.first.controls.first.id, 'ctl_0');
      expect(parsed, equals(document));
      expect(parsed.hashCode, equals(document.hashCode));
    });

    test('copyWith updates document properties', () {
      final manifest = LayoutManifest(
        id: 'doc_1',
        name: 'Main',
        createdAt: now,
        updatedAt: now,
      );
      final doc = LayoutDocument(
        manifest: manifest,
        pages: const [],
        activePageIndex: 0,
      );

      final updated = doc.copyWith(activePageIndex: 0);
      expect(updated.manifest.name, 'Main');
      expect(updated.schemaVersion, 1);
    });

    test(
      'throws UnsupportedSchemaVersionException on unsupported future schema version',
      () {
        final futureJson = {
          'schemaVersion': 999,
          'manifest': {
            'id': 'future_id',
            'name': 'Future Layout',
            'createdAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          },
          'pages': [],
          'activePageIndex': 0,
        };

        expect(
          () => LayoutDocument.fromJson(futureJson),
          throwsA(isA<UnsupportedSchemaVersionException>()),
        );
      },
    );
  });
}
