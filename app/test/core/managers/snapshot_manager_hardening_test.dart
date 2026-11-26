// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/managers/snapshot_manager.dart';
import 'package:app/core/models/action_payload.dart';
import 'package:app/core/models/layout_document.dart';
import 'package:app/core/models/layout_manifest.dart';
import 'package:app/core/models/layout_models.dart';

final class _PickedFile extends PlatformFile {
  _PickedFile(this.name, this.uri);

  @override
  final String name;

  @override
  final Uri uri;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestFilePicker extends FilePickerPlatform {
  List<PlatformFile> files = [];

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    return files;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late SnapshotManager snapshotManager;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('omc_import_export_test_');
    snapshotManager = SnapshotManager();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Layout file picker', () {
    late _TestFilePicker picker;

    setUp(() {
      final original = FilePickerPlatform.instance;
      addTearDown(() {
        FilePickerPlatform.instance = original;
      });
      picker = _TestFilePicker();
      FilePickerPlatform.instance = picker;
    });

    test(
      'rejects unsupported picker selections before reading the file',
      () async {
        final missingFile = File('${tempDir.path}/not-read.omc');
        picker.files = [_PickedFile('layout.omc.txt', missingFile.uri)];

        final document = await snapshotManager.importLayoutDocument();
        final page = await snapshotManager.importLayout();

        expect(document.errorMessage, 'Choose an .omc or .json layout file.');
        expect(page.errorMessage, 'Choose an .omc or .json layout file.');
      },
    );

  });

  group('Hardened SnapshotManager Import/Export Tests', () {
    test(
      'importLayoutDocument imports current documents and upgrades v1',
      () async {
        final docFile = File('${tempDir.path}/layout.omc');
        final doc = LayoutDocument(
          manifest: LayoutManifest(
            id: 'v1_doc_id',
            name: 'Stage Layout',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          pages: [
            LayoutPage(
              id: 'page_1',
              type: PageType.fader,
              name: 'FADERS',
              controls: [
                LayoutControl(
                  id: 'volume',
                  type: ControlType.fader,
                  defaultCc: 7,
                  channel: 0,
                ),
              ],
            ),
          ],
          activePageIndex: 0,
        );

        await docFile.writeAsString(jsonEncode(doc.toJson()));

        final result = await snapshotManager.importLayoutDocument(
          fileOverride: docFile,
        );
        expect(result.isSuccess, isTrue);
        expect(result.wasUpgraded, isFalse);
        expect(result.document!.manifest.name, 'Stage Layout');
        expect(result.document!.pages.length, 1);

        final legacyJson = doc.toJson();
        legacyJson['schemaVersion'] = 1;
        final legacyPages = legacyJson['pages'] as List<Map<String, dynamic>>;
        final legacyControls =
            legacyPages.single['controls'] as List<Map<String, dynamic>>;
        legacyControls.single.remove('payload');
        await docFile.writeAsString(jsonEncode(legacyJson));

        final upgraded = await snapshotManager.importLayoutDocument(
          fileOverride: docFile,
        );
        expect(upgraded.wasUpgraded, isTrue);
        expect(upgraded.document, doc);
        expect(
          upgraded.document!.pages.single.controls.single.payload,
          const CcPayload(channel: 0, cc: 7),
        );
      },
    );

    test(
      'importLayoutDocument upgrades legacy raw layout JSON to v2',
      () async {
        final legacyFile = File('${tempDir.path}/legacy_raw.omc');
        final legacyJson = {
          'pages': [
            {
              'id': 'legacy_page',
              'type': 'drumPad',
              'name': 'DRUMS',
              'controls': [],
            },
          ],
        };

        await legacyFile.writeAsString(jsonEncode(legacyJson));

        final result = await snapshotManager.importLayoutDocument(
          fileOverride: legacyFile,
        );
        expect(result.isSuccess, isTrue);
        expect(result.wasUpgraded, isTrue);
        expect(result.document!.schemaVersion, 2);
        expect(result.document!.manifest.name, 'Imported Layout');
        expect(result.document!.pages.first.name, 'DRUMS');
      },
    );

    test(
      'importLayoutDocument rejects unsupported future schema versions gracefully',
      () async {
        final futureFile = File('${tempDir.path}/future.omc');
        final futureJson = {'schemaVersion': 99, 'manifest': {}, 'pages': []};

        await futureFile.writeAsString(jsonEncode(futureJson));

        final result = await snapshotManager.importLayoutDocument(
          fileOverride: futureFile,
        );
        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('99'));
      },
    );

    test(
      'importLayoutDocument handles corrupted JSON with actionable error message',
      () async {
        final corruptFile = File('${tempDir.path}/corrupt.omc');
        await corruptFile.writeAsString('{{{ invalid json ...');

        final result = await snapshotManager.importLayoutDocument(
          fileOverride: corruptFile,
        );
        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('Corrupted JSON'));
      },
    );

    test('importLayout imports standalone LayoutPage successfully', () async {
      final pageFile = File('${tempDir.path}/page.omc');
      final page = LayoutPage(
        id: 'page_solo',
        type: PageType.xyPad,
        name: 'SOLO XY',
        controls: [],
      );

      await pageFile.writeAsString(jsonEncode(page.toJson()));

      final result = await snapshotManager.importLayout(fileOverride: pageFile);
      expect(result.isSuccess, isTrue);
      expect(result.page!.name, 'SOLO XY');
    });
  });
}
