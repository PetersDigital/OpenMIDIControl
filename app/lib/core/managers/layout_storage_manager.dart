// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/layout_document.dart';

/// Provider exposing [LayoutStorageManager].
final layoutStorageManagerProvider = Provider<LayoutStorageManager>((ref) {
  return LayoutStorageManager();
});

/// Local persistence service for [LayoutDocument] files.
///
/// Stores layout templates and documents under `<app_documents>/layouts/{id}.omc`.
class LayoutStorageManager {
  static const String activeDocumentKey = 'omc_active_layout_document_id';

  final Future<Directory> Function()? _customDirProvider;
  final Future<SharedPreferences> Function()? _customPrefsProvider;

  LayoutStorageManager({
    Future<Directory> Function()? customDirProvider,
    Future<SharedPreferences> Function()? customPrefsProvider,
  }) : _customDirProvider = customDirProvider,
       _customPrefsProvider = customPrefsProvider;

  Future<Directory> get _layoutsDir async {
    if (_customDirProvider != null) {
      final dir = await _customDirProvider();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
    final docDir = await getApplicationDocumentsDirectory();
    final layoutsDir = Directory('${docDir.path}/layouts');
    if (!await layoutsDir.exists()) {
      await layoutsDir.create(recursive: true);
    }
    return layoutsDir;
  }

  Future<SharedPreferences> get _prefs async {
    if (_customPrefsProvider != null) {
      return _customPrefsProvider();
    }
    return SharedPreferences.getInstance();
  }

  /// Sanitizes document ID to prevent directory traversal.
  String _sanitizeId(String id) {
    final sanitized = id.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return sanitized.isEmpty ? 'unnamed_layout' : sanitized;
  }

  /// Saves a [LayoutDocument] to disk as `{id}.omc`.
  Future<void> saveDocument(LayoutDocument document) async {
    try {
      final dir = await _layoutsDir;
      final file = File('${dir.path}/${_sanitizeId(document.manifest.id)}.omc');
      final jsonStr = jsonEncode(document.toJson());
      await file.writeAsString(jsonStr);
    } catch (e) {
      debugPrint(
        'LayoutStorageManager: Error saving document ${document.manifest.id}: $e',
      );
      rethrow;
    }
  }

  /// Loads a [LayoutDocument] by its ID. Returns null if not found.
  Future<LayoutDocument?> loadDocument(String id) async {
    try {
      final dir = await _layoutsDir;
      var file = File('${dir.path}/${_sanitizeId(id)}.omc');
      if (!await file.exists()) {
        // Also check legacy or .omc.json if needed
        file = File('${dir.path}/${_sanitizeId(id)}.omc.json');
      }
      if (!await file.exists()) {
        return null;
      }
      final jsonStr = await file.readAsString();
      final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      return LayoutDocument.fromJson(jsonMap);
    } catch (e) {
      debugPrint('LayoutStorageManager: Error loading document $id: $e');
      return null;
    }
  }

  /// Lists all saved [LayoutDocument] items stored locally.
  Future<List<LayoutDocument>> listDocuments() async {
    final dir = await _layoutsDir;
    final List<LayoutDocument> documents = [];

    await for (final entity in dir.list()) {
      if (entity is File &&
          (entity.path.endsWith('.omc') || entity.path.endsWith('.omc.json'))) {
        try {
          final content = await entity.readAsString();
          final jsonMap = jsonDecode(content) as Map<String, dynamic>;
          final doc = LayoutDocument.fromJson(jsonMap);
          documents.add(doc);
        } catch (e) {
          debugPrint('LayoutStorageManager: Error parsing ${entity.path}: $e');
        }
      }
    }

    return documents;
  }

  /// Deletes a layout document by ID.
  Future<void> deleteDocument(String id) async {
    try {
      final dir = await _layoutsDir;
      final fileOmc = File('${dir.path}/${_sanitizeId(id)}.omc');
      final fileJson = File('${dir.path}/${_sanitizeId(id)}.omc.json');
      if (await fileOmc.exists()) await fileOmc.delete();
      if (await fileJson.exists()) await fileJson.delete();
    } catch (e) {
      debugPrint('LayoutStorageManager: Error deleting document $id: $e');
    }
  }

  /// Returns the ID of the active document from SharedPreferences.
  Future<String?> getActiveDocumentId() async {
    final prefs = await _prefs;
    return prefs.getString(activeDocumentKey);
  }

  /// Persists the active document ID in SharedPreferences.
  Future<void> setActiveDocumentId(String id) async {
    final prefs = await _prefs;
    await prefs.setString(activeDocumentKey, id);
  }
}
