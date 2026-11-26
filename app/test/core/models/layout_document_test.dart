// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/core/models/action_payload.dart';
import 'package:app/core/models/layout_manifest.dart';
import 'package:app/core/models/layout_models.dart';
import 'package:app/core/models/layout_document.dart';
import 'package:app/ui/header_transport_state.dart';

void main() {
  group('LayoutDocument Envelope Tests', () {
    final now = DateTime.now();

    test('latch duration round-trips and missing values use the default', () {
      final defaultPad = LayoutControl(
        id: 'latch',
        type: ControlType.latchPad,
        defaultCc: 64,
        channel: 3,
      );
      expect(defaultPad.toJson().containsKey('latchDurationMs'), isFalse);
      expect(LayoutControl.fromJson(defaultPad.toJson()).latchDurationMs, 1000);
      final edited = defaultPad.copyWith(latchDurationMs: 2500);
      expect(edited, isNot(defaultPad));
      expect(LayoutControl.fromJson(edited.toJson()), edited);
      expect(edited.withActions(payload: edited.payload).latchDurationMs, 2500);
      expect(
        () =>
            LayoutControl.fromJson({...edited.toJson(), 'latchDurationMs': 0}),
        throwsFormatException,
      );
    });

    test(
      'round-trips aftertouch defaults, remaps, and disabled expression',
      () {
        final pad = LayoutControl(
          id: 'aftertouch',
          type: ControlType.aftertouchPad,
          defaultCc: 60,
          channel: 3,
        );
        const note = NotePayload(
          channel: 3,
          note: 60,
          velocityMode: NoteVelocityMode.touchPosition,
          velocityCurve: NoteVelocityCurve.drumPad,
        );
        const remapped = CcPayload(channel: 3, cc: 71);
        expect(pad.payload, note);
        expect(
          pad.effectiveSecondaryPayload,
          const CcPayload(channel: 3, cc: 74),
        );
        final page = LayoutPage(
          id: 'pads',
          type: PageType.drumPad,
          name: 'Pads',
          controls: [
            pad,
            pad
                .copyWith(id: 'remapped')
                .withActions(payload: note, secondaryPayload: remapped),
            pad
                .copyWith(id: 'disabled')
                .withActions(payload: note, clearSecondary: true),
          ],
        );
        final document = LayoutDocument(
          manifest: LayoutManifest(
            id: 'doc',
            name: 'Pads',
            createdAt: now,
            updatedAt: now,
          ),
          pages: [page],
          activePageIndex: 0,
        );
        final restored = LayoutDocument.fromJson(
          jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>,
        );
        expect(restored, document);
        expect(
          restored.pages.single.controls.last.effectiveSecondaryPayload,
          isNull,
        );
        expect(
          restored.pages.single.controls[1].effectiveSecondaryPayload,
          remapped,
        );
      },
    );

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
        manifest: manifest,
        pages: [page],
        activePageIndex: 0,
      );

      final json = document.toJson();
      expect(json['schemaVersion'], 2);
      expect(json['manifest']['id'], 'doc_1');
      expect(json['pages'].length, 1);
      expect(json['activePageIndex'], 0);
      expect(control.toJson().containsKey('transportAction'), isFalse);

      final parsed = LayoutDocument.fromJson(json);
      expect(parsed.schemaVersion, 2);
      expect(parsed.manifest.name, 'Main Layout');
      expect(parsed.pages.length, 1);
      expect(parsed.pages.first.id, 'p_0');
      expect(parsed.pages.first.controls.first.id, 'ctl_0');
      expect(parsed, equals(document));
      expect(parsed.hashCode, equals(document.hashCode));
    });

    test(
      'skips legacy transportButton entries on v1/v2 import without touching global header mappings',
      () async {
        const savedHeaderPlay = NotePayload(channel: 0, note: 94);
        SharedPreferences.setMockInitialValues({
          HeaderTransportMappingsNotifier.storageKey: jsonEncode({
            'play': savedHeaderPlay.toJson(),
          }),
        });

        final container = ProviderContainer();
        addTearDown(container.dispose);
        await container
            .read(headerTransportMappingsProvider.notifier)
            .ensureLoaded();

        final v2Json = {
          'schemaVersion': 2,
          'manifest': LayoutManifest(
            id: 'legacy_dev_doc',
            name: 'Dev Fixture',
            createdAt: now,
            updatedAt: now,
          ).toJson(),
          'pages': [
            {
              'id': 'p_0',
              'type': 'utility',
              'name': 'UTILITY',
              'controls': [
                {
                  'id': 'transport_play',
                  'type': 'transportButton',
                  'transportAction': 'play',
                  'defaultCc': 94,
                  'channel': 0,
                  'payload': {'type': 'note', 'channel': 0, 'note': 94},
                },
                {
                  'id': 'kept_fader',
                  'type': 'fader',
                  'defaultCc': 1,
                  'channel': 0,
                },
              ],
            },
          ],
          'activePageIndex': 0,
        };

        final v1Json = {...v2Json, 'schemaVersion': 1};

        final importedV2 = LayoutDocument.fromJson(v2Json);
        final importedV1 = LayoutDocument.fromJson(v1Json);

        for (final doc in [importedV2, importedV1]) {
          final controls = doc.pages.single.controls;
          expect(controls.map((c) => c.id), ['kept_fader']);
          expect(controls.single.type, ControlType.fader);
        }

        // Global header transport mappings remain untouched by layout import.
        expect(container.read(headerTransportMappingsProvider), {
          HeaderTransportRole.play: savedHeaderPlay,
        });
      },
    );

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
      expect(updated.schemaVersion, 2);
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
