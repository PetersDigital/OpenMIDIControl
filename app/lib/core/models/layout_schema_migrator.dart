// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:uuid/uuid.dart';

import 'layout_document.dart';

/// Function signature for schema migration steps.
typedef SchemaMigrationStep =
    Map<String, dynamic> Function(Map<String, dynamic> input);

/// Registry and pipeline for evolving JSON layout schemas across versions.
///
/// Ensures backward compatibility by transforming legacy and older schema representations
/// into the current schema version shape.
class LayoutSchemaMigrator {
  static const _uuid = Uuid();

  /// Registry mapping a source schema version to the transformation function
  /// that promotes it to the next version (e.g. 0 -> 1, 1 -> 2).
  static final Map<int, SchemaMigrationStep> _migrations = {0: _migrateV0ToV1};

  /// Registers a custom migration handler for testing or future extensions.
  static void registerMigration(int fromVersion, SchemaMigrationStep step) {
    _migrations[fromVersion] = step;
  }

  /// Migrates a raw JSON map up to [LayoutDocument.currentSchemaVersion].
  ///
  /// Detects unversioned legacy schemas (version 0) and processes iterative step
  /// upgrades. Throws [UnsupportedSchemaVersionException] if the version exceeds
  /// the runtime version or if no path exists.
  static Map<String, dynamic> migrate(Map<String, dynamic> source) {
    final Map<String, dynamic> mutableJson = Map<String, dynamic>.from(source);

    // Determine current version in input JSON (missing or null schemaVersion indicates legacy v0)
    int version = _detectSchemaVersion(mutableJson);

    if (version > LayoutDocument.currentSchemaVersion) {
      throw UnsupportedSchemaVersionException(
        version,
        'Cannot migrate future schema version $version. Current supported version is ${LayoutDocument.currentSchemaVersion}.',
      );
    }

    Map<String, dynamic> current = mutableJson;
    while (version < LayoutDocument.currentSchemaVersion) {
      final step = _migrations[version];
      if (step == null) {
        throw UnsupportedSchemaVersionException(
          version,
          'No migration path registered from schema version $version.',
        );
      }
      current = step(current);
      final newVersion = current['schemaVersion'] as int?;
      if (newVersion == null || newVersion <= version) {
        throw StateError(
          'Migration step from version $version failed to advance schemaVersion.',
        );
      }
      version = newVersion;
    }

    return current;
  }

  /// Detects the schema version of the payload.
  /// If `schemaVersion` key is missing, returns 0.
  static int _detectSchemaVersion(Map<String, dynamic> json) {
    final rawVersion = json['schemaVersion'];
    if (rawVersion == null) {
      return 0;
    }
    if (rawVersion is int) {
      return rawVersion;
    }
    throw const UnsupportedSchemaVersionException(
      -1,
      'Invalid "schemaVersion" format in layout JSON.',
    );
  }

  /// Migration handler: v0 (legacy raw layout or PresetSnapshot) -> v1.
  ///
  /// Extracts pages and activePageIndex, synthesizes default manifest metadata,
  /// and wraps them in a schemaVersion: 1 envelope.
  static Map<String, dynamic> _migrateV0ToV1(Map<String, dynamic> v0) {
    final now = DateTime.now().toIso8601String();

    // Extract pages from legacy raw layout or PresetSnapshot
    List<dynamic> pages = const [];
    if (v0.containsKey('pages') && v0['pages'] is List) {
      pages = v0['pages'] as List<dynamic>;
    }

    // Active page index
    final int activePageIndex = (v0['activePageIndex'] is int)
        ? v0['activePageIndex'] as int
        : 0;

    // Check if manifest metadata was partially provided or needs full synthesis
    Map<String, dynamic> manifest;
    if (v0.containsKey('manifest') && v0['manifest'] is Map<String, dynamic>) {
      manifest = Map<String, dynamic>.from(
        v0['manifest'] as Map<String, dynamic>,
      );
      manifest['id'] = manifest['id'] ?? _uuid.v4();
      manifest['name'] = manifest['name'] ?? 'Imported Layout';
      manifest['author'] = manifest['author'] ?? 'Anonymous';
      manifest['version'] = manifest['version'] ?? '1.0.0';
      manifest['description'] = manifest['description'] ?? '';
      manifest['tags'] = manifest['tags'] ?? <String>[];
      manifest['createdAt'] = manifest['createdAt'] ?? now;
      manifest['updatedAt'] = manifest['updatedAt'] ?? now;
    } else {
      manifest = {
        'id': _uuid.v4(),
        'name': 'Default Layout',
        'author': 'Anonymous',
        'version': '1.0.0',
        'description': '',
        'tags': <String>[],
        'createdAt': now,
        'updatedAt': now,
      };
    }

    return {
      'schemaVersion': 1,
      'manifest': manifest,
      'pages': pages,
      'activePageIndex': activePageIndex,
    };
  }
}
