// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

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

  Future<void> savePreset(String name, PresetSnapshot preset) async {
    final dir = await _presetsDir;
    final file = File('${dir.path}/$name.json');
    final jsonStr = jsonEncode(preset.toJson());
    await file.writeAsString(jsonStr);
  }

  Future<PresetSnapshot?> loadPreset(String name) async {
    try {
      final dir = await _presetsDir;
      final file = File('${dir.path}/$name.json');
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
      if (entity is File && entity.path.endsWith('.json')) {
        final filename = entity.uri.pathSegments.last;
        presetNames.add(filename.substring(0, filename.length - 5));
      }
    }
    return presetNames;
  }

  Future<void> deletePreset(String name) async {
    final dir = await _presetsDir;
    final file = File('${dir.path}/$name.json');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
