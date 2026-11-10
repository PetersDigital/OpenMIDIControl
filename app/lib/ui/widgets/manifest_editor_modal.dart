// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design_system.dart';
import '../layout_document_state.dart';
import 'scrollable_dialog_content.dart';

/// Modal dialog for inspecting and editing layout document manifest metadata.
class ManifestEditorModal extends ConsumerStatefulWidget {
  const ManifestEditorModal({super.key});

  @override
  ConsumerState<ManifestEditorModal> createState() =>
      _ManifestEditorModalState();
}

class _ManifestEditorModalState extends ConsumerState<ManifestEditorModal> {
  late final TextEditingController _nameController;
  late final TextEditingController _authorController;
  late final TextEditingController _versionController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _tagsController;

  @override
  void initState() {
    super.initState();
    final manifest = ref.read(layoutDocumentProvider).manifest;
    _nameController = TextEditingController(text: manifest.name);
    _authorController = TextEditingController(text: manifest.author);
    _versionController = TextEditingController(text: manifest.version);
    _descriptionController = TextEditingController(text: manifest.description);
    _tagsController = TextEditingController(text: manifest.tags.join(', '));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _authorController.dispose();
    _versionController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final name = _nameController.text.trim();
    final author = _authorController.text.trim();
    final version = _versionController.text.trim();
    final description = _descriptionController.text.trim();
    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    ref
        .read(layoutDocumentProvider.notifier)
        .updateManifest(
          name: name.isEmpty ? 'Untitled Layout' : name,
          author: author.isEmpty ? 'Anonymous' : author,
          version: version.isEmpty ? '1.0.0' : version,
          description: description,
          tags: tags,
        );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E2024),
      title: Text(
        'LAYOUT METADATA',
        style: AppText.performance(color: Colors.white, fontSize: 18),
      ),
      content: ScrollableDialogContent(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildField('NAME', _nameController, hint: 'Layout Name'),
              const SizedBox(height: 12),
              _buildField(
                'AUTHOR',
                _authorController,
                hint: 'Author / Creator',
              ),
              const SizedBox(height: 12),
              _buildField('VERSION', _versionController, hint: '1.0.0'),
              const SizedBox(height: 12),
              _buildField(
                'DESCRIPTION',
                _descriptionController,
                hint: 'Brief summary of this layout',
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              _buildField(
                'TAGS (COMMA-SEPARATED)',
                _tagsController,
                hint: 'synth, drums, live',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL', style: TextStyle(color: Colors.white60)),
        ),
        FilledButton(onPressed: _handleSave, child: const Text('SAVE')),
      ],
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    String? hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: Colors.white70,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
            filled: true,
            fillColor: Colors.black26,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
