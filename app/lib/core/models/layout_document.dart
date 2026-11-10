// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:collection/collection.dart';

import 'layout_manifest.dart';
import 'layout_models.dart';
import 'layout_schema_migrator.dart';

/// Exception thrown when encountering a layout schema version that cannot be parsed
/// or migrated by the current application runtime.
class UnsupportedSchemaVersionException implements Exception {
  final int schemaVersion;
  final String message;

  const UnsupportedSchemaVersionException(this.schemaVersion, [String? message])
    : message = message ?? 'Schema version $schemaVersion is not supported.';

  @override
  String toString() => 'UnsupportedSchemaVersionException: $message';
}

/// Versioned container envelope wrapping layout metadata and structural state.
///
/// Applied strictly at I/O boundaries (file persistence and import/export),
/// keeping the hot-path state manager (`LayoutStateNotifier`) fast and unencumbered.
class LayoutDocument {
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final LayoutManifest manifest;
  final List<LayoutPage> pages;
  final int activePageIndex;

  LayoutDocument({
    this.schemaVersion = currentSchemaVersion,
    required this.manifest,
    required this.pages,
    this.activePageIndex = 0,
  }) : assert(
         pages.isEmpty ? activePageIndex == 0 : activePageIndex >= 0,
         'activePageIndex cannot be negative',
       ),
       assert(
         pages.isEmpty ? activePageIndex == 0 : activePageIndex < pages.length,
         'activePageIndex out of bounds',
       );

  /// Creates a copy with optional field replacements.
  LayoutDocument copyWith({
    int? schemaVersion,
    LayoutManifest? manifest,
    List<LayoutPage>? pages,
    int? activePageIndex,
  }) {
    return LayoutDocument(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      manifest: manifest ?? this.manifest,
      pages: pages ?? this.pages,
      activePageIndex: activePageIndex ?? this.activePageIndex,
    );
  }

  /// Serializes the layout document to a JSON map conforming to [currentSchemaVersion].
  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'manifest': manifest.toJson(),
      'pages': pages.map((p) => p.toJson()).toList(),
      'activePageIndex': activePageIndex,
    };
  }

  /// Deserializes a [LayoutDocument] from JSON.
  /// Automatically runs the migration pipeline via [LayoutSchemaMigrator.migrate]
  /// to migrate legacy or older schema versions before model construction.
  /// If [defaultName] is provided, it is used when migrating legacy schemas lacking manifest metadata.
  factory LayoutDocument.fromJson(
    Map<String, dynamic> rawJson, {
    String defaultName = 'Default Layout',
  }) {
    final migrated = LayoutSchemaMigrator.migrate(
      rawJson,
      defaultName: defaultName,
    );

    final version = migrated['schemaVersion'] as int;
    if (version != currentSchemaVersion) {
      throw UnsupportedSchemaVersionException(
        version,
        'Expected schema version $currentSchemaVersion but got $version after migration.',
      );
    }

    final manifestMap = migrated['manifest'] as Map<String, dynamic>;
    final pagesList =
        (migrated['pages'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>()
            .map(LayoutPage.fromJson)
            .toList() ??
        <LayoutPage>[];
    final activeIndex = migrated['activePageIndex'] as int? ?? 0;

    return LayoutDocument(
      schemaVersion: version,
      manifest: LayoutManifest.fromJson(manifestMap),
      pages: pagesList,
      activePageIndex: activeIndex,
    );
  }

  @override
  String toString() =>
      'LayoutDocument(v$schemaVersion, manifest: ${manifest.name}, pages: ${pages.length})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LayoutDocument &&
        other.schemaVersion == schemaVersion &&
        other.manifest == manifest &&
        other.activePageIndex == activePageIndex &&
        const ListEquality<LayoutPage>().equals(other.pages, pages);
  }

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    manifest,
    activePageIndex,
    const ListEquality<LayoutPage>().hash(pages),
  );
}
