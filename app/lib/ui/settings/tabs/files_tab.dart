// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/managers/snapshot_manager.dart';
import '../../../core/models/preset_snapshot.dart';
import '../../layout_state.dart';
import '../../midi_service.dart';
import '../../widgets/preset_management.dart';

const _kAccent = Color(0xFFA6C9F8);
const _kCardBg = Color(0xFF1A1C20);
const _kBorderNormal = Color(0x14FFFFFF);
const _kSectionLabel = TextStyle(
  fontFamily: 'Inter',
  color: Color(0xFFC3C7CA),
  fontSize: 11,
  fontWeight: FontWeight.bold,
  letterSpacing: 2.0,
);

class FilesTab extends StatelessWidget {
  const FilesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: const [
        _InternalPresetSection(),
        _FileDivider(),
        _FullPresetSection(),
        _FileDivider(),
        _ActivePageSection(),
        SizedBox(height: 32),
      ],
    );
  }
}

class _FileDivider extends StatelessWidget {
  const _FileDivider();
  @override
  Widget build(BuildContext context) =>
      const Divider(color: Color(0x1AFFFFFF), height: 32);
}

// ---------------------------------------------------------------------------
// Internal list section
// ---------------------------------------------------------------------------

class _InternalPresetSection extends ConsumerWidget {
  const _InternalPresetSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('INTERNAL LIBRARY (.OMC)', style: _kSectionLabel),
        ),
        _FileCard(
          icon: Icons.save_outlined,
          label: 'SAVE TO INTERNAL LIST',
          subtitle:
              'Save current configuration to the internal preset library.',
          iconColor: _kAccent,
          onTap: () => _handleSave(context, ref),
        ),
        const SizedBox(height: 8),
        _FileCard(
          icon: Icons.folder_open_outlined,
          label: 'LOAD FROM INTERNAL LIST',
          subtitle: 'Load a configuration from your internal library.',
          iconColor: _kAccent,
          onTap: () => _handleLoad(context, ref),
        ),
      ],
    );
  }

  Future<void> _handleSave(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => const SavePresetDialog(),
    );
    if (result != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Preset "$result" saved.')));
    }
  }

  Future<void> _handleLoad(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => const LoadPresetDialog(),
    );
    if (result != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Loaded preset "$result".')));
    }
  }
}

// ---------------------------------------------------------------------------
// Full preset export/import
// ---------------------------------------------------------------------------

class _FullPresetSection extends ConsumerWidget {
  const _FullPresetSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('FULL PRESET (.OMC)', style: _kSectionLabel),
        ),
        _FileCard(
          icon: Icons.share,
          label: 'EXPORT FULL PRESET',
          subtitle: 'Share your entire 4-page configuration as a file.',
          iconColor: _kAccent,
          onTap: () {
            final snapshot = PresetSnapshot(
              controlState: ref.read(controlStateProvider),
              pages: ref.read(layoutStateProvider).pages,
            );
            ref
                .read(snapshotManagerProvider)
                .exportFullPreset('OMC_Preset', snapshot);
          },
        ),
        const SizedBox(height: 8),
        _FileCard(
          icon: Icons.file_download,
          label: 'IMPORT FULL PRESET',
          subtitle: 'Load an entire configuration from an external .omc file.',
          iconColor: _kAccent,
          onTap: () => _handleImportFull(context, ref),
        ),
      ],
    );
  }

  Future<void> _handleImportFull(BuildContext context, WidgetRef ref) async {
    final preset = await ref.read(snapshotManagerProvider).importFullPreset();
    if (preset != null && context.mounted) {
      ref.read(controlStateProvider.notifier).injectState(preset.controlState);
      ref.read(layoutStateProvider.notifier).overwriteAllPages(preset.pages);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imported full OMC preset successfully.')),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Active page export/import
// ---------------------------------------------------------------------------

class _ActivePageSection extends ConsumerWidget {
  const _ActivePageSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('ACTIVE PAGE (.OMC)', style: _kSectionLabel),
        ),
        _FileCard(
          icon: Icons.ios_share,
          label: 'EXPORT ACTIVE PAGE',
          subtitle: 'Share just the currently active page mapping.',
          iconColor: Colors.white54,
          onTap: () {
            final page = ref.read(layoutStateProvider).activePage;
            if (page != null) {
              ref.read(snapshotManagerProvider).exportActiveLayout(page);
            }
          },
        ),
        const SizedBox(height: 8),
        _FileCard(
          icon: Icons.file_open_outlined,
          label: 'IMPORT ACTIVE PAGE',
          subtitle: 'Overwrite the active page from an external .omc file.',
          iconColor: Colors.white54,
          onTap: () => _handleImportPage(context, ref),
        ),
      ],
    );
  }

  Future<void> _handleImportPage(BuildContext context, WidgetRef ref) async {
    final page = await ref.read(snapshotManagerProvider).importLayout();
    if (page != null && context.mounted) {
      ref.read(layoutStateProvider.notifier).overwriteActivePage(page);
    }
  }
}

// ---------------------------------------------------------------------------
// Shared card
// ---------------------------------------------------------------------------

class _FileCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color iconColor;
  final VoidCallback onTap;

  const _FileCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorderNormal),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }
}
