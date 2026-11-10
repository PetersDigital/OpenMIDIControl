// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/models/layout_document.dart';
import '../core/models/layout_manifest.dart';
import 'layout_state.dart';

/// Notifier managing the active [LayoutDocument], holding the manifest metadata
/// and current schema version while delegating structural layout mutations to [LayoutStateNotifier].
class LayoutDocumentNotifier extends Notifier<LayoutDocument> {
  static const _uuid = Uuid();

  @override
  LayoutDocument build() {
    final now = DateTime.now();
    final defaultManifest = LayoutManifest(
      id: _uuid.v4(),
      name: 'Default Layout',
      author: 'Anonymous',
      version: '1.0.0',
      description: '',
      tags: const [],
      createdAt: now,
      updatedAt: now,
    );

    // Listen to layoutState changes to update pages/activePageIndex without recreating the document
    ref.listen(layoutStateProvider, (previous, next) {
      if (state.pages != next.pages ||
          state.activePageIndex != next.activePageIndex) {
        state = state.copyWith(
          pages: next.pages,
          activePageIndex: next.activePageIndex,
        );
      }
    });

    final initialLayout = ref.read(layoutStateProvider);

    return LayoutDocument(
      schemaVersion: LayoutDocument.currentSchemaVersion,
      manifest: defaultManifest,
      pages: initialLayout.pages,
      activePageIndex: initialLayout.activePageIndex,
    );
  }

  /// Sets the active document wholly (e.g., when loading a new file).
  void setDocument(LayoutDocument document) {
    state = document;
    ref.read(layoutStateProvider.notifier).overwriteAllPages(document.pages);
    ref
        .read(layoutStateProvider.notifier)
        .setPageIndex(document.activePageIndex);
  }

  /// Updates manifest metadata fields.
  void updateManifest({
    String? name,
    String? author,
    String? version,
    String? description,
    List<String>? tags,
  }) {
    final updatedManifest = state.manifest.copyWith(
      name: name ?? state.manifest.name,
      author: author ?? state.manifest.author,
      version: version ?? state.manifest.version,
      description: description ?? state.manifest.description,
      tags: tags ?? state.manifest.tags,
      updatedAt: DateTime.now(),
    );

    state = state.copyWith(manifest: updatedManifest);
  }

  /// Syncs current layout state pages into the document.
  void syncWithLayoutState() {
    final layoutState = ref.read(layoutStateProvider);
    state = state.copyWith(
      pages: layoutState.pages,
      activePageIndex: layoutState.activePageIndex,
      manifest: state.manifest.copyWith(updatedAt: DateTime.now()),
    );
  }
}

/// Provider exposing the active [LayoutDocument].
final layoutDocumentProvider =
    NotifierProvider<LayoutDocumentNotifier, LayoutDocument>(
      LayoutDocumentNotifier.new,
    );
