// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/action_payload.dart';
import '../../core/models/layout_models.dart';
import '../design_system.dart';
import 'midi_action_fields.dart';
import 'scrollable_dialog_content.dart';
import '../../core/midi_utils.dart';
import '../layout_state.dart';

class ControlConfigModal extends ConsumerStatefulWidget {
  final String controlId;
  final String displayNameLabel;

  const ControlConfigModal({
    super.key,
    required this.controlId,
    this.displayNameLabel = 'Display Name',
  });

  @override
  ConsumerState<ControlConfigModal> createState() => _ControlConfigModalState();
}

class _ControlConfigModalState extends ConsumerState<ControlConfigModal> {
  final _formKey = GlobalKey<FormState>();
  late final ControlType? _controlType;
  late final MidiActionDraft _primaryAction;
  TextEditingController? _secondaryIdentifierController;
  CcPayload? _originalSecondaryCc;
  String? _originalSecondaryText;
  late final TextEditingController _displayNameController;
  bool _invertX = false;
  bool _invertY = false;

  bool get _isXy => _controlType == ControlType.xyPad;
  bool get _isContinuous => switch (_controlType) {
    ControlType.fader || ControlType.xyPad || ControlType.encoder => true,
    _ => false,
  };

  @override
  void initState() {
    super.initState();
    final control = ref
        .read(layoutStateProvider)
        .getControlById(widget.controlId);

    _controlType = control?.type;
    _primaryAction = MidiActionDraft(
      payload: control?.payload,
      channel: control?.channel ?? 0,
      identifier: control?.defaultCc,
      drumPad: _controlType == ControlType.drumPad,
    );

    final name = control?.customName;
    _displayNameController = TextEditingController(
      text: name == 'Unassigned' ? null : name,
    );

    if (_isXy && control != null) {
      final secondary = control.secondaryPayload;
      if (secondary == null || secondary is CcPayload) {
        final configuredCc = secondary is CcPayload ? secondary : null;
        final cc = configuredCc?.cc ?? control.secondaryCc;
        _originalSecondaryCc = configuredCc;
        _originalSecondaryText = cc == null || cc < 0 ? '' : cc.toString();
        _secondaryIdentifierController = TextEditingController(
          text: _originalSecondaryText,
        );
      }
      _invertX = control.invertX;
      _invertY = control.invertY;
    }
  }

  @override
  void dispose() {
    _primaryAction.dispose();
    _secondaryIdentifierController?.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final secondaryText = _secondaryIdentifierController?.text.trim();
    CcPayload? secondary;
    if (secondaryText != null &&
        secondaryText.isNotEmpty &&
        secondaryText != _originalSecondaryText) {
      final cc = MidiUtils.parseNoteIdentifier(secondaryText)!;
      secondary = CcPayload(
        channel: _originalSecondaryCc?.channel ?? _primaryAction.channel,
        cc: cc,
        highResolution:
            cc < 32 && (_originalSecondaryCc?.highResolution ?? false),
      );
    }

    ref
        .read(layoutStateProvider.notifier)
        .updateControlActions(
          widget.controlId,
          payload: _primaryAction.payload,
          secondaryPayload: secondary,
          name: _displayNameController.text,
          invertX: _isXy ? _invertX : null,
          invertY: _isXy ? _invertY : null,
        );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E2024),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Configure Control',
            style: AppText.performance(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Color(0xFFC3C7CA)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashRadius: 20,
          ),
        ],
      ),
      content: ScrollableDialogContent(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isXy) ...[
                const Text(
                  'X Axis',
                  style: TextStyle(color: Color(0xFFC3C7CA)),
                ),
                const SizedBox(height: 8),
              ],
              MidiActionFields(
                draft: _primaryAction,
                usesPitchBendPosition: _isContinuous,
                supportsVariableVelocity:
                    _isContinuous || _controlType == ControlType.drumPad,
              ),
              if (_isXy) ...[
                if (_secondaryIdentifierController != null) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _secondaryIdentifierController,
                    keyboardType: TextInputType.text,
                    style: const TextStyle(color: Colors.white),
                    decoration: MidiActionFields.decoration.copyWith(
                      labelText: 'Y-Axis CC Number (0-127)',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      return text.isNotEmpty &&
                              MidiUtils.parseNoteIdentifier(text) == null
                          ? 'Enter a number from 0 to 127'
                          : null;
                    },
                  ),
                ],
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
              TextFormField(
                controller: _displayNameController,
                textInputAction: TextInputAction.done,
                style: const TextStyle(color: Colors.white),
                decoration: MidiActionFields.decoration.copyWith(
                  labelText: widget.displayNameLabel,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
          child: Row(
            children: [
              TextButton(
                onPressed: () {
                  ref
                      .read(layoutStateProvider.notifier)
                      .clearControl(widget.controlId);
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Clear',
                  style: AppText.system(color: Colors.redAccent),
                ),
              ),
              const SizedBox(width: 8),
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
              const Spacer(),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA6C9F8),
                  foregroundColor: const Color(0xFF0C0E12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  'Save',
                  style: AppText.system(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
