// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../design_system.dart';
import 'scrollable_dialog_content.dart';
import '../../core/midi_utils.dart';
import '../layout_state.dart';

class ControlConfigModal extends ConsumerStatefulWidget {
  final String controlId;
  final String identifierLabel;
  final String? secondaryIdentifierLabel;
  final String displayNameLabel;

  const ControlConfigModal({
    super.key,
    required this.controlId,
    this.identifierLabel = 'MIDI ID (e.g., C3 or 60)',
    this.secondaryIdentifierLabel,
    this.displayNameLabel = 'Display Name',
  });

  @override
  ConsumerState<ControlConfigModal> createState() => _ControlConfigModalState();
}

class _ControlConfigModalState extends ConsumerState<ControlConfigModal> {
  late int _selectedChannel;
  late TextEditingController _identifierController;
  TextEditingController? _secondaryIdentifierController;
  TextEditingController? _displayNameController;
  bool _invertX = false;
  bool _invertY = false;

  @override
  void initState() {
    super.initState();
    final control = ref
        .read(layoutStateProvider)
        .getControlById(widget.controlId);

    _selectedChannel = control?.channel ?? 0;
    _identifierController = TextEditingController(
      text: control?.defaultCc == -1 ? '' : control?.defaultCc.toString() ?? '',
    );

    if (control?.customName != null && control?.customName != 'Unassigned') {
      _displayNameController = TextEditingController(text: control!.customName);
    } else {
      _displayNameController = TextEditingController();
    }

    if (widget.secondaryIdentifierLabel != null) {
      _secondaryIdentifierController = TextEditingController(
        text: control?.secondaryCc?.toString() ?? '',
      );
      _invertX = control?.invertX ?? false;
      _invertY = control?.invertY ?? false;
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _secondaryIdentifierController?.dispose();
    _displayNameController?.dispose();
    super.dispose();
  }

  void _save() {
    final identifier = MidiUtils.parseNoteIdentifier(
      _identifierController.text,
    );
    final secondaryIdentifier = _secondaryIdentifierController != null
        ? MidiUtils.parseNoteIdentifier(_secondaryIdentifierController!.text)
        : null;

    if (identifier == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid MIDI identifier')));
      return;
    }

    ref
        .read(layoutStateProvider.notifier)
        .updateControl(
          widget.controlId,
          channel: _selectedChannel,
          identifier: identifier,
          name: _displayNameController?.text,
          secondaryIdentifier: secondaryIdentifier,
          invertX: _invertX,
          invertY: _invertY,
        );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E2024),
      title: Text(
        'Configure Control',
        style: AppText.performance(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: ScrollableDialogContent(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MIDI Channel',
              style: TextStyle(
                fontFamily: 'Inter',
                color: Color(0xFFC3C7CA),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _selectedChannel < 0 ? 0 : _selectedChannel,
              dropdownColor: const Color(0xFF282A2E),
              decoration: const InputDecoration(
                filled: true,
                fillColor: Color(0xFF111318),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF282A2E)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFA6C9F8)),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              items: List.generate(16, (index) {
                return DropdownMenuItem(
                  value: index,
                  child: Text(
                    'Channel ${index + 1}',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedChannel = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            Text(
              widget.identifierLabel,
              style: const TextStyle(
                fontFamily: 'Inter',
                color: Color(0xFFC3C7CA),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _identifierController,
              keyboardType: TextInputType.text,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                filled: true,
                fillColor: Color(0xFF111318),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF282A2E)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFA6C9F8)),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
            if (widget.secondaryIdentifierLabel != null) ...[
              const SizedBox(height: 16),
              Text(
                widget.secondaryIdentifierLabel!,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFFC3C7CA),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _secondaryIdentifierController,
                keyboardType: TextInputType.text,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Color(0xFF111318),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF282A2E)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFA6C9F8)),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text(
                  'Invert X',
                  style: TextStyle(color: Colors.white),
                ),
                value: _invertX,
                onChanged: (v) => setState(() => _invertX = v ?? false),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                title: const Text(
                  'Invert Y',
                  style: TextStyle(color: Colors.white),
                ),
                value: _invertY,
                onChanged: (v) => setState(() => _invertY = v ?? false),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ],
            const SizedBox(height: 16),
            Text(
              widget.displayNameLabel,
              style: const TextStyle(
                fontFamily: 'Inter',
                color: Color(0xFFC3C7CA),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _displayNameController,
              textInputAction: TextInputAction.done,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                filled: true,
                fillColor: Color(0xFF111318),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF282A2E)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFA6C9F8)),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        Row(
          children: [
            TextButton(
              onPressed: () {
                ref
                    .read(layoutStateProvider.notifier)
                    .clearControl(widget.controlId);
                Navigator.of(context).pop();
              },
              child:
                  Text('Clear', style: AppText.system(color: Colors.redAccent)),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                ref
                    .read(layoutStateProvider.notifier)
                    .resetControl(widget.controlId);
                Navigator.of(context).pop();
              },
              child: Text(
                'Reset',
                style: AppText.system(color: const Color(0xFFA6C9F8)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: AppText.system(color: const Color(0xFFC3C7CA)),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA6C9F8),
                foregroundColor: const Color(0xFF0C0E12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                'Save',
                style: AppText.system(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
