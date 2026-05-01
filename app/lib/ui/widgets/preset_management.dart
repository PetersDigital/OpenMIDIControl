// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/managers/snapshot_manager.dart';
import '../../core/models/preset_snapshot.dart';
import '../layout_state.dart';
import '../midi_service.dart';
import '../design_system.dart';
import 'scrollable_dialog_content.dart';

class SavePresetDialog extends ConsumerStatefulWidget {
  const SavePresetDialog({super.key});

  @override
  ConsumerState<SavePresetDialog> createState() => _SavePresetDialogState();
}

class _SavePresetDialogState extends ConsumerState<SavePresetDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E2024),
      title: Text(
        'SAVE PRESET',
        style: AppText.performance(color: Colors.white, fontSize: 18),
      ),
      content: ScrollableDialogContent(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Preset Name',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              autofocus: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL', style: TextStyle(color: Colors.white60)),
        ),
        FilledButton(
          onPressed: () async {
            final name = _controller.text.trim();
            if (name.isEmpty) return;

            final controlState = ref.read(controlStateProvider);
            final layoutState = ref.read(layoutStateProvider);

            final snapshot = PresetSnapshot(
              controlState: controlState,
              pages: layoutState.pages,
            );

            final navigator = Navigator.of(context);
            await ref.read(snapshotManagerProvider).savePreset(name, snapshot);
            if (!mounted) return;
            navigator.pop(name);
          },
          child: const Text('SAVE'),
        ),
      ],
    );
  }
}

class LoadPresetDialog extends ConsumerWidget {
  const LoadPresetDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(snapshotManagerProvider);

    return AlertDialog(
      backgroundColor: const Color(0xFF1E2024),
      title: Text(
        'LOAD PRESET',
        style: AppText.performance(color: Colors.white, fontSize: 18),
      ),
      content: ScrollableDialogContent(
        child: FutureBuilder<List<String>>(
          future: manager.listPresets(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final presets = snapshot.data ?? [];
            if (presets.isEmpty) {
              return const Center(
                child: Text(
                  'No presets found',
                  style: TextStyle(color: Colors.white38),
                ),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: presets.map((name) {
                return ListTile(
                  title: Text(
                    name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    onPressed: () async {
                      await manager.deletePreset(name);
                      // Force rebuild
                      (context as Element).markNeedsBuild();
                    },
                  ),
                  onTap: () async {
                    final preset = await manager.loadPreset(name);
                    if (!context.mounted) return;
                    if (preset != null) {
                      ref
                          .read(controlStateProvider.notifier)
                          .injectState(preset.controlState);
                      ref
                          .read(layoutStateProvider.notifier)
                          .overwriteAllPages(preset.pages);
                      Navigator.pop(context, name);
                    }
                  },
                );
              }).toList(),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CLOSE', style: TextStyle(color: Colors.white60)),
        ),
      ],
    );
  }
}
