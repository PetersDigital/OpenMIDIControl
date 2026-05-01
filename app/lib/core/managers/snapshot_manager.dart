// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/layout_models.dart';
import '../models/preset_snapshot.dart';

final snapshotManagerProvider = Provider<SnapshotManager>((ref) {
  return SnapshotManager();
});

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
    // Only allow alphanumeric, spaces, underscores, and hyphens.
    // This explicitly prevents '/', '\', '..', and other problematic characters.
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
        // Fallback to legacy .json
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
          // Include legacy JSON
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
      debugPrint('Error exporting layout: $e');
    }
  }

  Future<LayoutPage?> importLayout() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['omc', 'json'],
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final String jsonString = await file.readAsString();
        final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;

        // Simple check: LayoutPage has 'controls', PresetSnapshot has 'pages'
        if (jsonMap.containsKey('controls')) {
          return LayoutPage.fromJson(jsonMap);
        } else if (jsonMap.containsKey('pages')) {
          // User picked a full preset, maybe just return the first page?
          // For now, let's just fail to import as layout.
          debugPrint('File is a full Preset, not a single Page.');
          return null;
        }
      }
    } catch (e) {
      debugPrint('Error importing layout: $e');
    }
    return null;
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
      FilePickerResult? result = await FilePicker.platform.pickFiles(
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
