// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/managers/layout_storage_manager.dart';
import '../core/models/layout_document.dart';
import '../core/models/layout_manifest.dart';
import 'layout_state.dart';

/// Notifier managing the active [LayoutDocument], holding manifest metadata,
/// delegating layout mutations to [LayoutStateNotifier], and handling debounced auto-save.
class LayoutDocumentNotifier extends Notifier<LayoutDocument> {
  static const _uuid = Uuid();
  Timer? _debounceTimer;
  bool _isLoading = false;

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

    // Listen to layoutState changes to update pages/activePageIndex and schedule auto-save
    ref.listen(layoutStateProvider, (previous, next) {
      if (_isLoading) return;
      if (state.pages != next.pages ||
          state.activePageIndex != next.activePageIndex) {
        state = state.copyWith(
          pages: next.pages,
          activePageIndex: next.activePageIndex,
          manifest: state.manifest.copyWith(updatedAt: DateTime.now()),
        );
        _scheduleAutoSave();
      }
    });

    ref.onDispose(() {
      _debounceTimer?.cancel();
    });

    final initialLayout = ref.read(layoutStateProvider);

    return LayoutDocument(
      schemaVersion: LayoutDocument.currentSchemaVersion,
      manifest: defaultManifest,
      pages: initialLayout.pages,
      activePageIndex: initialLayout.activePageIndex,
    );
  }

  /// Loads the active document on startup or creates and persists a default document if none exists.
  Future<void> initializeOnStartup() async {
    _isLoading = true;
    try {
      final storage = ref.read(layoutStorageManagerProvider);
      final activeId = await storage.getActiveDocumentId();

      if (activeId != null) {
        final existing = await storage.loadDocument(activeId);
        if (existing != null) {
          state = existing;
          ref
              .read(layoutStateProvider.notifier)
              .overwriteAllPages(existing.pages);
          ref
              .read(layoutStateProvider.notifier)
              .setPageIndex(existing.activePageIndex);
          return;
        }
      }

      // First run or active document missing: persist initial document
      await storage.saveDocument(state);
      await storage.setActiveDocumentId(state.manifest.id);
    } finally {
      _isLoading = false;
    }
  }

  /// Sets the active document wholly (e.g., when loading a new file or preset).
  Future<void> setDocument(LayoutDocument document) async {
    _isLoading = true;
    try {
      state = document;
      ref.read(layoutStateProvider.notifier).overwriteAllPages(document.pages);
      ref
          .read(layoutStateProvider.notifier)
          .setPageIndex(document.activePageIndex);

      final storage = ref.read(layoutStorageManagerProvider);
      await storage.saveDocument(document);
      await storage.setActiveDocumentId(document.manifest.id);
    } finally {
      _isLoading = false;
    }
  }

  /// Updates manifest metadata fields and schedules auto-save.
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
    _scheduleAutoSave();
  }

  /// Debounces write operation to local storage by 1000ms.
  void _scheduleAutoSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () async {
      final storage = ref.read(layoutStorageManagerProvider);
      await storage.saveDocument(state);
      await storage.setActiveDocumentId(state.manifest.id);
    });
  }

  /// Immediately persists state to disk without debounce delay.
  Future<void> flushSave() async {
    _debounceTimer?.cancel();
    final storage = ref.read(layoutStorageManagerProvider);
    await storage.saveDocument(state);
    await storage.setActiveDocumentId(state.manifest.id);
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
