// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import '../design_system.dart';
import 'package:flutter/services.dart';

class ControlConfigResult {
  final int channel;
  final int identifier;

  const ControlConfigResult({required this.channel, required this.identifier});
}

class ControlConfigModal extends StatefulWidget {
  final int initialChannel;
  final int initialIdentifier;
  final String identifierLabel;

  const ControlConfigModal({
    super.key,
    this.initialChannel = 0,
    this.initialIdentifier = 0,
    this.identifierLabel = 'CC / Note Number',
  });

  @override
  State<ControlConfigModal> createState() => _ControlConfigModalState();
}

class _ControlConfigModalState extends State<ControlConfigModal> {
  late int _selectedChannel;
  late TextEditingController _identifierController;

  @override
  void initState() {
    super.initState();
    _selectedChannel = widget.initialChannel;
    _identifierController = TextEditingController(
      text: widget.initialIdentifier.toString(),
    );
  }

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  void _save() {
    final identifier = int.tryParse(_identifierController.text) ?? 0;

    // Clamp values just to be safe
    final clampedIdentifier = identifier.clamp(0, 127);

    Navigator.of(context).pop(
      ControlConfigResult(
        channel: _selectedChannel,
        identifier: clampedIdentifier,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configure Control'),
      backgroundColor: const Color(0xFF1E2024),
      titleTextStyle: const TextStyle(
        fontFamily: 'Inter',
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      content: Column(
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
            value: _selectedChannel,
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
          const SizedBox(height: 24),
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
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a number';
              }
              final num = int.tryParse(value);
              if (num == null || num < 0 || num > 127) {
                return 'Must be between 0 and 127';
              }
              return null;
            },
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
        ],
      ),
      actions: [
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
