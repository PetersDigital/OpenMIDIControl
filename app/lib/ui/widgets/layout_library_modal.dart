// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/managers/layout_storage_manager.dart';
import '../../core/models/layout_document.dart';
import '../design_system.dart';
import '../layout_document_state.dart';
import 'scrollable_dialog_content.dart';

/// Modal dialog for browsing, switching, and deleting saved local layouts.
class LayoutLibraryModal extends ConsumerStatefulWidget {
  const LayoutLibraryModal({super.key});

  @override
  ConsumerState<LayoutLibraryModal> createState() => _LayoutLibraryModalState();
}

class _LayoutLibraryModalState extends ConsumerState<LayoutLibraryModal> {
  List<LayoutDocument>? _layouts;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLayouts();
  }

  Future<void> _loadLayouts() async {
    setState(() => _isLoading = true);
    final storage = ref.read(layoutStorageManagerProvider);
    final documents = await storage.listDocuments();
    if (mounted) {
      setState(() {
        _layouts = documents;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectLayout(LayoutDocument doc) async {
    await ref.read(layoutDocumentProvider.notifier).setDocument(doc);
    if (mounted) {
      Navigator.of(context).pop(doc.manifest.name);
    }
  }

  Future<void> _deleteLayout(LayoutDocument doc) async {
    final activeId = ref.read(layoutDocumentProvider).manifest.id;
    if (doc.manifest.id == activeId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete the currently active layout.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2024),
        title: Text(
          'DELETE LAYOUT',
          style: AppText.performance(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          'Delete layout "${doc.manifest.name}" permanently?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.white60),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final storage = ref.read(layoutStorageManagerProvider);
      await storage.deleteDocument(doc.manifest.id);
      await _loadLayouts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeId = ref.watch(
      layoutDocumentProvider.select((d) => d.manifest.id),
    );

    return AlertDialog(
      backgroundColor: const Color(0xFF1E2024),
      title: Text(
        'SAVED LAYOUTS',
        style: AppText.performance(color: Colors.white, fontSize: 18),
      ),
      content: ScrollableDialogContent(
        child: SizedBox(
          width: 420,
          child: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              : (_layouts == null || _layouts!.isEmpty)
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No saved layouts found.',
                      style: TextStyle(color: Colors.white38),
                    ),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _layouts!.map((doc) {
                    final isActive = doc.manifest.id == activeId;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.white10 : Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isActive
                              ? const Color(0xFFA6C9F8)
                              : const Color(0x14FFFFFF),
                        ),
                      ),
                      child: ListTile(
                        dense: true,
                        title: Text(
                          doc.manifest.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          'v${doc.manifest.version} • ${doc.pages.length} page(s)'
                          '${isActive ? ' (ACTIVE)' : ''}',
                          style: TextStyle(
                            color: isActive
                                ? const Color(0xFFA6C9F8)
                                : Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isActive)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Colors.white38,
                                ),
                                onPressed: () => _deleteLayout(doc),
                              ),
                            Icon(
                              isActive
                                  ? Icons.check_circle
                                  : Icons.chevron_right,
                              color: isActive
                                  ? const Color(0xFFA6C9F8)
                                  : Colors.white24,
                              size: 18,
                            ),
                          ],
                        ),
                        onTap: isActive ? null : () => _selectLayout(doc),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CLOSE', style: TextStyle(color: Colors.white60)),
        ),
      ],
    );
  }
}
