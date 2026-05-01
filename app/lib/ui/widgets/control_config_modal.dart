// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import '../design_system.dart';
import 'scrollable_dialog_content.dart';
import '../../core/midi_utils.dart';

class ControlConfigResult {
  final int channel;
  final int identifier;
  final String? displayName;

  const ControlConfigResult({
    required this.channel,
    required this.identifier,
    this.displayName,
  });
}

class ControlConfigModal extends StatefulWidget {
  final int initialChannel;
  final int initialIdentifier;
  final String identifierLabel;
  final String? initialDisplayName;
  final String displayNameLabel;
  final VoidCallback? onClear;
  final VoidCallback? onReset;

  const ControlConfigModal({
    super.key,
    this.initialChannel = 0,
    this.initialIdentifier = 0,
    this.identifierLabel = 'MIDI ID (e.g., C3 or 60)',
    this.initialDisplayName,
    this.displayNameLabel = 'Display Name',
    this.onClear,
    this.onReset,
  });

  @override
  State<ControlConfigModal> createState() => _ControlConfigModalState();
}

class _ControlConfigModalState extends State<ControlConfigModal> {
  late int _selectedChannel;
  late TextEditingController _identifierController;
  TextEditingController? _displayNameController;

  @override
  void initState() {
    super.initState();
    _selectedChannel = widget.initialChannel;
    _identifierController = TextEditingController(
      text: widget.initialIdentifier.toString(),
    );
    if (widget.initialDisplayName != null) {
      _displayNameController = TextEditingController(
        text: widget.initialDisplayName,
      );
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _displayNameController?.dispose();
    super.dispose();
  }

  void _save() {
    final identifier = MidiUtils.parseNoteIdentifier(
      _identifierController.text,
    );
    if (identifier == null) return;

    // Clamp values just to be safe
    final clampedIdentifier = identifier;

    Navigator.of(context).pop(
      ControlConfigResult(
        channel: _selectedChannel,
        identifier: clampedIdentifier,
        displayName: _displayNameController?.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configure Control'),
      titlePadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      backgroundColor: const Color(0xFF1E2024),
      titleTextStyle: const TextStyle(
        fontFamily: 'Space Grotesk',
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
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
              initialValue: _selectedChannel,
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
            const SizedBox(height: 12),
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
              inputFormatters: const [], // Allow letters for note names
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
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a number';
                }
                final parsed = MidiUtils.parseNoteIdentifier(value);
                if (parsed == null) {
                  return 'Enter a number (0-127) or note (e.g., C3)';
                }
                return null;
              },
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            if (_displayNameController != null) ...[
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
          ],
        ),
      ),
      actions: [
        if (widget.onClear != null)
          TextButton(
            onPressed: () {
              widget.onClear!();
              Navigator.of(context).pop();
            },
            child: Text(
              'Clear',
              style: AppText.system(color: Colors.redAccent),
            ),
          ),
        if (widget.onReset != null)
          TextButton(
            onPressed: () {
              widget.onReset!();
              Navigator.of(context).pop();
            },
            child: Text(
              'Reset',
              style: AppText.system(color: const Color(0xFFA6C9F8)),
            ),
          ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(
            'Cancel',
            style: AppText.system(color: const Color(0xFFC3C7CA)),
          ),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFA6C9F8),
            foregroundColor: const Color(0xFF0C0E12),
          ),
          child: Text(
            'Save',
            style: AppText.system(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
