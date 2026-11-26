// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:convert';

import 'package:app/core/models/action_payload.dart';
import 'package:app/ui/header_transport_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('HeaderTransportMappingsNotifier', () {
    test('defaults all nine roles to unassigned on a fresh install', () async {
      expect(HeaderTransportRole.values, hasLength(9));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(headerTransportMappingsProvider.notifier)
          .ensureLoaded();

      final mappings = container.read(headerTransportMappingsProvider);
      expect(mappings, isEmpty);
      for (final role in HeaderTransportRole.values) {
        expect(mappings[role], isNull);
      }
    });

    test(
      'persists CC and Note assignments and reloads them in a fresh container',
      () async {
        const playPayload = NotePayload(channel: 0, note: 94);
        const stopPayload = CcPayload(channel: 2, cc: 118);

        final first = ProviderContainer();
        addTearDown(first.dispose);

        final firstNotifier = first.read(
          headerTransportMappingsProvider.notifier,
        );
        await firstNotifier.setAssignment(
          HeaderTransportRole.play,
          playPayload,
        );
        await firstNotifier.setAssignment(
          HeaderTransportRole.stop,
          stopPayload,
        );

        expect(
          first.read(headerTransportMappingsProvider)[HeaderTransportRole.play],
          playPayload,
        );
        expect(
          first.read(headerTransportMappingsProvider)[HeaderTransportRole.stop],
          stopPayload,
        );

        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(HeaderTransportMappingsNotifier.storageKey);
        expect(raw, isNotNull);
        final stored = jsonDecode(raw!) as Map<String, dynamic>;
        expect(stored['play'], playPayload.toJson());
        expect(stored['stop'], stopPayload.toJson());

        final reloaded = ProviderContainer();
        addTearDown(reloaded.dispose);

        await reloaded
            .read(headerTransportMappingsProvider.notifier)
            .ensureLoaded();

        final restored = reloaded.read(headerTransportMappingsProvider);
        expect(restored[HeaderTransportRole.play], playPayload);
        expect(restored[HeaderTransportRole.stop], stopPayload);
        expect(restored[HeaderTransportRole.record], isNull);
      },
    );

    test('clears assignments and keeps them unassigned after reload', () async {
      const recordPayload = NotePayload(channel: 1, note: 95);
      const rewindPayload = CcPayload(channel: 0, cc: 115);

      final first = ProviderContainer();
      addTearDown(first.dispose);

      final notifier = first.read(headerTransportMappingsProvider.notifier);
      await notifier.setAssignment(HeaderTransportRole.record, recordPayload);
      await notifier.setAssignment(HeaderTransportRole.rewind, rewindPayload);

      await notifier.clearAssignment(HeaderTransportRole.record);
      await notifier.setAssignment(HeaderTransportRole.rewind, null);

      expect(first.read(headerTransportMappingsProvider), isEmpty);

      final reloaded = ProviderContainer();
      addTearDown(reloaded.dispose);

      await reloaded
          .read(headerTransportMappingsProvider.notifier)
          .ensureLoaded();

      final restored = reloaded.read(headerTransportMappingsProvider);
      expect(restored[HeaderTransportRole.record], isNull);
      expect(restored[HeaderTransportRole.rewind], isNull);
    });

    test('rejects unsupported payload types', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(headerTransportMappingsProvider.notifier);

      expect(
        () => notifier.setAssignment(
          HeaderTransportRole.up,
          const PitchBendPayload(channel: 0),
        ),
        throwsArgumentError,
      );
      expect(
        () => notifier.setAssignment(
          HeaderTransportRole.down,
          const RelativeCcPayload(
            channel: 0,
            cc: 16,
            encoding: RelativeCcEncoding.signedBit,
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => notifier.setAssignment(
          HeaderTransportRole.left,
          const McuActionPayload.transport(TransportAction.play),
        ),
        throwsArgumentError,
      );
    });

    test(
      'ignores unknown keys, malformed entries, and unsupported payloads on reload',
      () async {
        const validCc = CcPayload(channel: 3, cc: 24);
        SharedPreferences.setMockInitialValues({
          HeaderTransportMappingsNotifier.storageKey: jsonEncode({
            'play': validCc.toJson(),
            'unknownRole': validCc.toJson(),
            'stop': {'type': 'pitchBend', 'channel': 0, 'value': 8192},
            'record': 'not-a-map',
            'rewind': {'type': 'cc', 'channel': 99, 'cc': 1},
          }),
        });

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await container
            .read(headerTransportMappingsProvider.notifier)
            .ensureLoaded();

        final mappings = container.read(headerTransportMappingsProvider);
        expect(mappings, {HeaderTransportRole.play: validCc});
      },
    );

    test('serializes concurrent edits without dropping assignments', () async {
      const leftPayload = CcPayload(channel: 0, cc: 10);
      const rightPayload = NotePayload(channel: 0, note: 60);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(headerTransportMappingsProvider.notifier);
      await Future.wait([
        notifier.setAssignment(HeaderTransportRole.left, leftPayload),
        notifier.setAssignment(HeaderTransportRole.right, rightPayload),
      ]);

      final mappings = container.read(headerTransportMappingsProvider);
      expect(mappings[HeaderTransportRole.left], leftPayload);
      expect(mappings[HeaderTransportRole.right], rightPayload);
    });
  });
}
