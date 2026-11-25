// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/models/layout_manifest.dart';

void main() {
  group('LayoutManifest Model Tests', () {
    final now = DateTime.now();

    test('serializes to JSON and deserializes correctly', () {
      final manifest = LayoutManifest(
        id: 'manifest_123',
        name: 'Studio Setup',
        author: 'Alex',
        version: '1.2.0',
        description: 'DAW mapping for production',
        tags: ['studio', 'daw', 'synth'],
        createdAt: now,
        updatedAt: now,
      );

      final json = manifest.toJson();
      expect(json['id'], 'manifest_123');
      expect(json['name'], 'Studio Setup');
      expect(json['author'], 'Alex');
      expect(json['version'], '1.2.0');
      expect(json['description'], 'DAW mapping for production');
      expect(json['tags'], ['studio', 'daw', 'synth']);
      expect(json['createdAt'], now.toIso8601String());
      expect(json['updatedAt'], now.toIso8601String());

      final parsed = LayoutManifest.fromJson(json);
      expect(parsed, equals(manifest));
      expect(parsed.hashCode, equals(manifest.hashCode));
    });

    test('copyWith updates fields correctly', () {
      final manifest = LayoutManifest(
        id: 'm1',
        name: 'Initial Name',
        createdAt: now,
        updatedAt: now,
      );

      final updated = manifest.copyWith(
        name: 'Updated Name',
        author: 'Creator',
        tags: ['live'],
      );

      expect(updated.id, 'm1');
      expect(updated.name, 'Updated Name');
      expect(updated.author, 'Creator');
      expect(updated.tags, ['live']);
      expect(updated.version, '1.0.0');
    });

    test('handles default fallbacks during fromJson', () {
      final minimalJson = {'id': 'm_min', 'name': 'Minimal'};

      final parsed = LayoutManifest.fromJson(minimalJson);
      expect(parsed.id, 'm_min');
      expect(parsed.name, 'Minimal');
      expect(parsed.author, 'Anonymous');
      expect(parsed.version, '1.0.0');
      expect(parsed.description, '');
      expect(parsed.tags, isEmpty);
      expect(parsed.createdAt, isNotNull);
      expect(parsed.updatedAt, isNotNull);
    });
  });
}
