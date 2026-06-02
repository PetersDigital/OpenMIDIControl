// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/layout_models.dart';
import '../layout_state.dart';
import '../design_system.dart';

class PageManagementSection extends ConsumerWidget {
  const PageManagementSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pages = ref.watch(layoutStateProvider).pages;

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PAGE MANAGEMENT',
                style: AppText.system(
                  color: const Color(0xFFC3C7CA),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        if (pages.isNotEmpty)
          SliverReorderableList(
            itemCount: pages.length,
            onReorderItem: (oldIndex, newIndex) {
              ref
                  .read(layoutStateProvider.notifier)
                  .reorderPages(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final page = pages[index];
              return Material(
                key: ValueKey(page.id),
                type: MaterialType.transparency,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2024),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: ListTile(
                    title: Text(
                      page.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      page.type.name.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFA6C9F8),
                        fontSize: 11,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: Theme.of(context).colorScheme.error,
                          onPressed: () =>
                              _confirmDelete(context, ref, index, page.name),
                        ),
                        ReorderableDragStartListener(
                          index: index,
                          child: const Icon(
                            Icons.drag_handle,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          )
        else
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No pages configured.',
                style: AppText.system(color: Colors.white54),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E2024),
                  foregroundColor: const Color(0xFFA6C9F8),
                  side: const BorderSide(color: Colors.white12),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _showAddPageModal(context, ref),
                child: const Text(
                  '+ ADD NEW PAGE',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    int index,
    String name,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2024),
        title: const Text('Delete Page', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "$name"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(layoutStateProvider.notifier).removePage(index);
              Navigator.pop(ctx);
            },
            child: const Text(
              'DELETE',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPageModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111318),
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _AddPageForm(),
      ),
    );
  }
}

class _AddPageForm extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AddPageForm> createState() => _AddPageFormState();
}

class _AddPageFormState extends ConsumerState<_AddPageForm> {
  final _nameController = TextEditingController();
  PageType _selectedType = PageType.utility;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ADD NEW PAGE',
            style: AppText.performance(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            onChanged: (val) {
              if (_errorMessage != null && val.trim().isNotEmpty) {
                setState(() => _errorMessage = null);
              }
            },
            decoration: InputDecoration(
              labelText: 'Page Name',
              labelStyle: const TextStyle(color: Colors.white54),
              errorText: _errorMessage,
              errorStyle: const TextStyle(color: Colors.redAccent),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFA6C9F8)),
              ),
              errorBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.redAccent),
              ),
              focusedErrorBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.redAccent),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Page Type',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<PageType>(
            initialValue: _selectedType,
            dropdownColor: const Color(0xFF1E2024),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFA6C9F8)),
              ),
            ),
            items: PageType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type.name.toUpperCase()),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedType = val);
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA6C9F8),
              foregroundColor: const Color(0xFF1E2024),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () {
              final name = _nameController.text.trim();
              if (name.isNotEmpty) {
                ref
                    .read(layoutStateProvider.notifier)
                    .addPage(_selectedType, name);
                Navigator.pop(context);
              } else {
                setState(() {
                  _errorMessage = 'Page name cannot be empty';
                });
              }
            },
            child: const Text(
              'CREATE PAGE',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
