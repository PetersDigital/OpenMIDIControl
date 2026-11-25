// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/models/action_payload.dart';
import 'package:app/core/models/layout_document.dart';
import 'package:app/core/models/layout_schema_migrator.dart';

void main() {
  group('LayoutSchemaMigrator Tests', () {
    test('migrates unversioned raw layout JSON (v0 -> v1 -> v2)', () {
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

      expect(migrated['schemaVersion'], 2);
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
      expect(doc.schemaVersion, 2);
      expect(doc.pages.length, 1);
      expect(doc.pages.first.name, 'LEGACY FADER');
      expect(doc.pages.first.controls.first.defaultCc, 7);
      expect(
        doc.pages.first.controls.first.payload,
        const CcPayload(channel: 0, cc: 7),
      );
      expect(
        LayoutDocument.fromJson(jsonDecode(jsonEncode(doc.toJson()))),
        doc,
      );
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

    test('migrates unversioned PresetSnapshot JSON (v0 -> v1 -> v2)', () {
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

      expect(migrated['schemaVersion'], 2);
      expect((migrated['pages'] as List).length, 1);
      expect(migrated['activePageIndex'], 0);

      final doc = LayoutDocument.fromJson(legacySnapshot);
      expect(doc.schemaVersion, 2);
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

    test('migrates v1 assignments and preserves the original document', () {
      final v1 = {
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
        'pages': [
          {
            'id': 'controls',
            'type': 'utility',
            'name': 'Controls',
            'controls': [
              _legacyControl('xyPad', cc: 0, channel: 15, secondaryCc: 127),
              _legacyControl('drumPad', cc: 36, channel: 9),
              _legacyControl('encoder', cc: 12, channel: 0),
              _legacyControl('trigger', cc: 40, channel: 1),
              _legacyControl('toggle', cc: 41, channel: 1),
              _legacyControl('xyPad', cc: 10, channel: 0),
              _legacyControl('xyPad', cc: 10, channel: 0, secondaryCc: -1),
              _legacyControl('fader', cc: -1, channel: -1),
              _legacyControl('fader', cc: 7, channel: -1),
            ],
          },
          {'id': 'empty', 'type': 'utility', 'name': 'Empty', 'controls': []},
        ],
        'activePageIndex': 1,
      };

      final original = jsonEncode(v1);
      final migrated = LayoutSchemaMigrator.migrate(v1);
      expect(migrated['schemaVersion'], 2);
      expect(migrated['manifest'], v1['manifest']);
      expect(migrated['activePageIndex'], 1);
      expect(jsonEncode(v1), original);
      expect(LayoutSchemaMigrator.migrate(v1), migrated);

      final doc = LayoutDocument.fromJson(v1);
      final controls = doc.pages.first.controls;
      expect(controls.map((control) => control.payload), [
        const CcPayload(channel: 15, cc: 0),
        const NotePayload(
          channel: 9,
          note: 36,
          velocityMode: NoteVelocityMode.touchPosition,
          velocityCurve: NoteVelocityCurve.drumPad,
        ),
        const CcPayload(channel: 0, cc: 12),
        const CcPayload(channel: 1, cc: 40),
        const CcPayload(channel: 1, cc: 41),
        const CcPayload(channel: 0, cc: 10),
        const CcPayload(channel: 0, cc: 10),
        null,
        null,
      ]);
      expect(
        controls.first.secondaryPayload,
        const CcPayload(channel: 15, cc: 127),
      );
      expect(controls[5].secondaryCc, isNull);
      expect(controls[5].secondaryPayload, isNull);
      expect(
        controls[5].effectiveSecondaryPayload,
        const CcPayload(channel: 0, cc: 11),
      );
      expect(controls[5].toJson().containsKey('secondaryPayload'), isFalse);
      expect(controls[6].secondaryCc, -1);
      expect(controls[6].secondaryPayload, isNull);
      expect(controls[6].effectiveSecondaryPayload, isNull);
      expect(controls[7].defaultCc, -1);
      expect(controls[8].channel, -1);
      expect(
        LayoutDocument.fromJson(jsonDecode(jsonEncode(doc.toJson()))),
        doc,
      );
    });

    test('passes through the current schema without migration', () {
      final current = {'schemaVersion': 2, 'pages': []};
      expect(LayoutSchemaMigrator.migrate(current), current);
    });

    test(
      'throws UnsupportedSchemaVersionException on future schemaVersion',
      () {
        final futureVersionJson = {
          'schemaVersion': 3,
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

Map<String, dynamic> _legacyControl(
  String type, {
  required int cc,
  required int channel,
  int? secondaryCc,
}) => {
  'id': '$type:$cc:$channel:$secondaryCc',
  'type': type,
  'defaultCc': cc,
  'channel': channel,
  'secondaryCc': ?secondaryCc,
};
