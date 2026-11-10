// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/layout_document.dart';
import '../models/layout_models.dart';
import '../models/layout_schema_migrator.dart';
import '../models/preset_snapshot.dart';

final snapshotManagerProvider = Provider<SnapshotManager>((ref) {
  return SnapshotManager();
});

/// Result wrapper for layout document import operations providing upgrade metadata and status.
class LayoutImportResult {
  final LayoutDocument? document;
  final bool wasUpgraded;
  final String? errorMessage;

  const LayoutImportResult({
    this.document,
    this.wasUpgraded = false,
    this.errorMessage,
  });

  bool get isSuccess => document != null && errorMessage == null;
}

/// Result wrapper for single layout page import operations.
class PageImportResult {
  final LayoutPage? page;
  final bool wasUpgraded;
  final String? errorMessage;

  const PageImportResult({
    this.page,
    this.wasUpgraded = false,
    this.errorMessage,
  });

  bool get isSuccess => page != null && errorMessage == null;
}

class SnapshotManager {
  Future<Directory> get _presetsDir async {
    final docDir = await getApplicationDocumentsDirectory();
    final presetsDir = Directory('${docDir.path}/presets');
    if (!await presetsDir.exists()) {
      await presetsDir.create(recursive: true);
    }
    return presetsDir;
  }

  /// Sanitizes the preset name to prevent path traversal and illegal characters.
  String _sanitizeName(String name) {
    final sanitized = name.trim().replaceAll(RegExp(r'[^a-zA-Z0-9 _\-]'), '_');
    return sanitized.isEmpty ? 'unnamed_preset' : sanitized;
  }

  Future<void> savePreset(String name, PresetSnapshot preset) async {
    final dir = await _presetsDir;
    final sanitizedName = _sanitizeName(name);
    final file = File('${dir.path}/$sanitizedName.omc');
    final jsonStr = jsonEncode(preset.toJson());
    await file.writeAsString(jsonStr);
  }

  Future<PresetSnapshot?> loadPreset(String name) async {
    try {
      final dir = await _presetsDir;
      final sanitizedName = _sanitizeName(name);
      var file = File('${dir.path}/$sanitizedName.omc');
      if (!await file.exists()) {
        file = File('${dir.path}/$sanitizedName.json');
      }
      if (!await file.exists()) {
        return null;
      }
      final jsonStr = await file.readAsString();
      final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      return PresetSnapshot.fromJson(jsonMap);
    } catch (e) {
      return null;
    }
  }

  Future<List<String>> listPresets() async {
    final dir = await _presetsDir;
    final List<String> presetNames = [];
    await for (final entity in dir.list()) {
      if (entity is File) {
        final path = entity.path;
        if (path.endsWith('.omc')) {
          final filename = entity.uri.pathSegments.last;
          presetNames.add(filename.substring(0, filename.length - 4));
        } else if (path.endsWith('.json')) {
          final filename = entity.uri.pathSegments.last;
          presetNames.add(filename.substring(0, filename.length - 5));
        }
      }
    }
    return presetNames;
  }

  Future<void> deletePreset(String name) async {
    final dir = await _presetsDir;
    final sanitizedName = _sanitizeName(name);
    final fileOmc = File('${dir.path}/$sanitizedName.omc');
    final fileJson = File('${dir.path}/$sanitizedName.json');
    if (await fileOmc.exists()) await fileOmc.delete();
    if (await fileJson.exists()) await fileJson.delete();
  }

  /// Exports the layout document wrapped in the versioned [LayoutDocument] envelope.
  Future<void> exportLayoutDocument(LayoutDocument document) async {
    try {
      final String jsonString = jsonEncode(document.toJson());
      final directory = await getTemporaryDirectory();
      final sanitizedFileName = _sanitizeName(
        document.manifest.name,
      ).toLowerCase();
      final file = File('${directory.path}/$sanitizedFileName.omc');

      await file.writeAsString(jsonString);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'OpenMIDIControl Layout: ${document.manifest.name}',
        ),
      );
    } catch (e) {
      debugPrint('Error exporting layout document: $e');
    }
  }

  /// Exports an active single page wrapped as a standalone [LayoutPage] JSON.
  Future<void> exportActiveLayout(LayoutPage page) async {
    try {
      final String jsonString = jsonEncode(page.toJson());
      final directory = await getTemporaryDirectory();
      final sanitizedFileName = page.name.replaceAll(' ', '_').toLowerCase();
      final file = File('${directory.path}/$sanitizedFileName.omc');

      await file.writeAsString(jsonString);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'OpenMIDIControl Layout: ${page.name}',
        ),
      );
    } catch (e) {
      debugPrint('Error exporting active layout: $e');
    }
  }

  /// Imports a layout document with validation and schema migration.
  Future<LayoutImportResult> importLayoutDocument({File? fileOverride}) async {
    try {
      File? targetFile = fileOverride;
      if (targetFile == null) {
        FilePickerResult? result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['omc', 'json'],
        );
        if (result != null && result.files.single.path != null) {
          targetFile = File(result.files.single.path!);
        }
      }

      if (targetFile == null) {
        return const LayoutImportResult();
      }

      final String content = await targetFile.readAsString();
      final dynamic decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        return const LayoutImportResult(
          errorMessage: 'Invalid file format: Expected JSON object.',
        );
      }

      final bool isLegacy = !decoded.containsKey('schemaVersion');
      final LayoutDocument document = LayoutDocument.fromJson(decoded);

      return LayoutImportResult(document: document, wasUpgraded: isLegacy);
    } on UnsupportedSchemaVersionException catch (e) {
      return LayoutImportResult(errorMessage: e.message);
    } on FormatException catch (e) {
      return LayoutImportResult(
        errorMessage: 'Corrupted JSON file: ${e.message}',
      );
    } catch (e) {
      return LayoutImportResult(errorMessage: 'Failed to import layout: $e');
    }
  }

  /// Imports a single layout page with validation.
  Future<PageImportResult> importLayout({File? fileOverride}) async {
    try {
      File? targetFile = fileOverride;
      if (targetFile == null) {
        FilePickerResult? result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['omc', 'json'],
        );
        if (result != null && result.files.single.path != null) {
          targetFile = File(result.files.single.path!);
        }
      }

      if (targetFile == null) {
        return const PageImportResult();
      }

      final String content = await targetFile.readAsString();
      final dynamic decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        return const PageImportResult(
          errorMessage: 'Invalid file format: Expected JSON object.',
        );
      }

      if (decoded.containsKey('controls')) {
        return PageImportResult(page: LayoutPage.fromJson(decoded));
      } else if (decoded.containsKey('pages')) {
        // Document or preset provided: extract first page with upgrade note
        final migrated = LayoutSchemaMigrator.migrate(decoded);
        final doc = LayoutDocument.fromJson(migrated);
        if (doc.pages.isNotEmpty) {
          return PageImportResult(page: doc.pages.first, wasUpgraded: true);
        }
      }

      return const PageImportResult(
        errorMessage: 'File does not contain valid layout page controls.',
      );
    } on UnsupportedSchemaVersionException catch (e) {
      return PageImportResult(errorMessage: e.message);
    } on FormatException catch (e) {
      return PageImportResult(
        errorMessage: 'Corrupted JSON file: ${e.message}',
      );
    } catch (e) {
      return PageImportResult(errorMessage: 'Failed to import page: $e');
    }
  }

  Future<void> exportFullPreset(String name, PresetSnapshot preset) async {
    try {
      final String jsonString = jsonEncode(preset.toJson());
      final directory = await getTemporaryDirectory();
      final sanitizedFileName = _sanitizeName(name);
      final file = File('${directory.path}/$sanitizedFileName.omc');

      await file.writeAsString(jsonString);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'OpenMIDIControl Preset: $name',
        ),
      );
    } catch (e) {
      debugPrint('Error exporting preset: $e');
    }
  }

  Future<PresetSnapshot?> importFullPreset() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['omc', 'json'],
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final String jsonString = await file.readAsString();
        final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;

        if (jsonMap.containsKey('pages')) {
          return PresetSnapshot.fromJson(jsonMap);
        }
      }
    } catch (e) {
      debugPrint('Error importing preset: $e');
    }
    return null;
  }
}
