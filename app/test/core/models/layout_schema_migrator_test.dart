// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/models/layout_document.dart';
import 'package:app/core/models/layout_schema_migrator.dart';

void main() {
  group('LayoutSchemaMigrator Tests', () {
    test('migrates unversioned legacy raw layout JSON (v0 -> v1)', () {
      final legacyRawLayout = {
        'pages': [
          {
            'id': 'page_legacy',
            'type': 'fader',
            'name': 'LEGACY FADER',
            'controls': [
              {
                'id': 'fader_0',
                'type': 'fader',
                'defaultCc': 7,
                'channel': 0,
                'customName': 'VOLUME',
                'x': 0,
                'y': 0,
                'width': 2,
                'height': 3,
              },
            ],
            'gridColumns': 8,
            'gridRows': 4,
          },
        ],
        'activePageIndex': 0,
      };

      final migrated = LayoutSchemaMigrator.migrate(legacyRawLayout);

      expect(migrated['schemaVersion'], 1);
      expect(migrated['pages'], isList);
      expect((migrated['pages'] as List).length, 1);
      expect(migrated['activePageIndex'], 0);

      // Verify synthesized manifest
      final manifest = migrated['manifest'] as Map<String, dynamic>;
      expect(manifest['id'], isNotEmpty);
      expect(manifest['name'], 'Default Layout');
      expect(manifest['author'], 'Anonymous');
      expect(manifest['version'], '1.0.0');
      expect(manifest['description'], '');
      expect(manifest['tags'], isEmpty);
      expect(manifest['createdAt'], isNotEmpty);
      expect(manifest['updatedAt'], isNotEmpty);

      // Verify LayoutDocument can directly parse it
      final doc = LayoutDocument.fromJson(legacyRawLayout);
      expect(doc.schemaVersion, 1);
      expect(doc.pages.length, 1);
      expect(doc.pages.first.name, 'LEGACY FADER');
      expect(doc.pages.first.controls.first.defaultCc, 7);
    });

    test(
      'supports custom defaultName for imported legacy layouts lacking manifest',
      () {
        final legacyRawLayout = {
          'pages': [
            {
              'id': 'page_imported',
              'type': 'fader',
              'name': 'FADER',
              'controls': [],
            },
          ],
        };

        final migrated = LayoutSchemaMigrator.migrate(
          legacyRawLayout,
          defaultName: 'Imported Layout',
        );

        final manifest = migrated['manifest'] as Map<String, dynamic>;
        expect(manifest['name'], 'Imported Layout');

        final doc = LayoutDocument.fromJson(
          legacyRawLayout,
          defaultName: 'Imported Layout',
        );
        expect(doc.manifest.name, 'Imported Layout');
      },
    );

    test('migrates unversioned legacy PresetSnapshot JSON (v0 -> v1)', () {
      final legacySnapshot = {
        'controlState': {
          'activeValues': {'fader_0': 0.75},
        },
        'pages': [
          {
            'id': 'page_snapshot',
            'type': 'drumPad',
            'name': 'DRUMS',
            'controls': [],
            'gridColumns': 8,
            'gridRows': 4,
          },
        ],
      };

      final migrated = LayoutSchemaMigrator.migrate(legacySnapshot);

      expect(migrated['schemaVersion'], 1);
      expect((migrated['pages'] as List).length, 1);
      expect(migrated['activePageIndex'], 0);

      final doc = LayoutDocument.fromJson(legacySnapshot);
      expect(doc.schemaVersion, 1);
      expect(doc.pages.first.id, 'page_snapshot');
      expect(doc.pages.first.name, 'DRUMS');
    });

    test(
      'retains existing manifest metadata during v0 -> v1 migration when present',
      () {
        final legacyWithPartialManifest = {
          'manifest': {
            'id': 'custom_manifest_id',
            'name': 'Custom Project',
            'author': 'Producer',
          },
          'pages': [],
        };

        final migrated = LayoutSchemaMigrator.migrate(
          legacyWithPartialManifest,
        );
        final manifest = migrated['manifest'] as Map<String, dynamic>;
        expect(manifest['id'], 'custom_manifest_id');
        expect(manifest['name'], 'Custom Project');
        expect(manifest['author'], 'Producer');
        expect(manifest['version'], '1.0.0');
      },
    );

    test('passes through valid current schemaVersion 1 without mutation', () {
      final currentV1 = {
        'schemaVersion': 1,
        'manifest': {
          'id': 'uuid_1',
          'name': 'Test Layout',
          'author': 'Tester',
          'version': '1.0.0',
          'description': 'Desc',
          'tags': ['synth'],
          'createdAt': '2026-01-01T00:00:00.000',
          'updatedAt': '2026-01-01T00:00:00.000',
        },
        'pages': [],
        'activePageIndex': 0,
      };

      final migrated = LayoutSchemaMigrator.migrate(currentV1);
      expect(migrated['schemaVersion'], 1);
      expect(migrated['manifest']['name'], 'Test Layout');
      expect(migrated['manifest']['id'], 'uuid_1');
    });

    test(
      'throws UnsupportedSchemaVersionException on future schemaVersion',
      () {
        final futureVersionJson = {
          'schemaVersion': 2,
          'manifest': {},
          'pages': [],
        };

        expect(
          () => LayoutSchemaMigrator.migrate(futureVersionJson),
          throwsA(isA<UnsupportedSchemaVersionException>()),
        );
      },
    );

    test(
      'throws UnsupportedSchemaVersionException on invalid schemaVersion format',
      () {
        final invalidFormatJson = {'schemaVersion': 'one', 'pages': []};

        expect(
          () => LayoutSchemaMigrator.migrate(invalidFormatJson),
          throwsA(isA<UnsupportedSchemaVersionException>()),
        );
      },
    );
  });
}
