// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:material_ui/material_ui.dart';

import '../../core/midi_utils.dart';
import '../../core/models/action_payload.dart';

enum _MidiMessageType {
  unassigned('Unassigned'),
  cc('CC'),
  note('Note'),
  pitchBend('Pitch Bend'),
  relativeCc('Relative CC'),
  mcu('MCU');

  const _MidiMessageType(this.label);

  final String label;
}

/// Editable values for one MIDI assignment.
class MidiActionDraft {
  MidiActionDraft({
    ActionPayload? payload,
    int channel = 0,
    int? identifier,
    bool drumPad = false,
    this.allowUnassigned = false,
    this.ccAndNoteOnly = false,
  }) {
    _type = switch (payload) {
      CcPayload() => _MidiMessageType.cc,
      NotePayload() => _MidiMessageType.note,
      PitchBendPayload() => _MidiMessageType.pitchBend,
      RelativeCcPayload() => _MidiMessageType.relativeCc,
      McuActionPayload() => _MidiMessageType.mcu,
      null when allowUnassigned => _MidiMessageType.unassigned,
      null => drumPad ? _MidiMessageType.note : _MidiMessageType.cc,
    };
    this.channel = payload?.midiChannel ?? (channel < 0 ? 0 : channel);
    final number = switch (payload) {
      CcPayload(:final cc) || RelativeCcPayload(:final cc) => cc,
      NotePayload(:final note) => note,
      _ => identifier,
    };
    _identifier = TextEditingController(
      text: number == null || number < 0 ? '' : number.toString(),
    );
    _pitchValue = TextEditingController(
      text: (payload is PitchBendPayload ? payload.value : 8192).toString(),
    );
    _highResolution = payload is CcPayload && payload.highResolution;
    _velocityMode = payload is NotePayload
        ? payload.velocityMode
        : drumPad
        ? NoteVelocityMode.touchPosition
        : NoteVelocityMode.fixed;
    _velocityCurve = payload is NotePayload
        ? payload.velocityCurve
        : drumPad
        ? NoteVelocityCurve.drumPad
        : NoteVelocityCurve.linear;
    _encoding = payload is RelativeCcPayload
        ? payload.encoding
        : RelativeCcEncoding.signedBit;
    _mcuPayload = payload is McuActionPayload ? payload : null;
  }

  late _MidiMessageType _type;
  final bool allowUnassigned;
  final bool ccAndNoteOnly;
  late int channel;
  late final TextEditingController _identifier;
  late final TextEditingController _pitchValue;
  late bool _highResolution;
  late NoteVelocityMode _velocityMode;
  late NoteVelocityCurve _velocityCurve;
  late RelativeCcEncoding _encoding;
  late final McuActionPayload? _mcuPayload;

  bool _canSelect(_MidiMessageType type) => switch (type) {
    _MidiMessageType.unassigned => allowUnassigned,
    _MidiMessageType.cc || _MidiMessageType.note => true,
    _MidiMessageType.pitchBend || _MidiMessageType.relativeCc => !ccAndNoteOnly,
    _MidiMessageType.mcu => false,
  };

  int? _parseNumber(String text, int max) {
    final value = int.tryParse(text.trim(), radix: 10);
    return value != null && value >= 0 && value <= max ? value : null;
  }

  String? _validateIdentifier(String? text) {
    final input = text ?? '';
    if (_type == _MidiMessageType.note) {
      return MidiUtils.parseNoteIdentifier(input) == null
          ? 'Enter a note name or a number from 0 to 127'
          : null;
    }
    final max = _type == _MidiMessageType.cc && _highResolution ? 31 : 127;
    return _parseNumber(input, max) == null
        ? 'Enter a CC number from 0 to $max'
        : null;
  }

  /// Builds the assignment after its form fields have been validated.
  ActionPayload? get payload => switch (_type) {
    _MidiMessageType.unassigned => null,
    _MidiMessageType.cc => CcPayload(
      channel: channel,
      cc: int.parse(_identifier.text.trim(), radix: 10),
      highResolution: _highResolution,
    ),
    _MidiMessageType.note => NotePayload(
      channel: channel,
      note: MidiUtils.parseNoteIdentifier(_identifier.text)!,
      velocityMode: _velocityMode,
      velocityCurve: _velocityCurve,
    ),
    _MidiMessageType.pitchBend => PitchBendPayload(
      channel: channel,
      value: int.parse(_pitchValue.text.trim(), radix: 10),
    ),
    _MidiMessageType.relativeCc => RelativeCcPayload(
      channel: channel,
      cc: int.parse(_identifier.text.trim(), radix: 10),
      encoding: _encoding,
    ),
    _MidiMessageType.mcu => _mcuPayload!,
  };

  void dispose() {
    _identifier.dispose();
    _pitchValue.dispose();
  }
}

class MidiActionFields extends StatefulWidget {
  const MidiActionFields({
    super.key,
    required this.draft,
    required this.usesPitchBendPosition,
    required this.supportsVariableVelocity,
  });

  final MidiActionDraft draft;
  final bool usesPitchBendPosition;
  final bool supportsVariableVelocity;

  static const decoration = InputDecoration(
    filled: true,
    fillColor: Color(0xFF111318),
    border: OutlineInputBorder(),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFF282A2E)),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFFA6C9F8)),
    ),
    labelStyle: TextStyle(color: Color(0xFFC3C7CA)),
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );

  @override
  State<MidiActionFields> createState() => _MidiActionFieldsState();
}

class _MidiActionFieldsState extends State<MidiActionFields> {
  MidiActionDraft get _draft => widget.draft;

  Widget _dropdown<T>({
    required String label,
    required T value,
    required Iterable<T> values,
    required String Function(T) optionLabel,
    required ValueChanged<T> onChanged,
    bool Function(T)? isEnabled,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      dropdownColor: const Color(0xFF282A2E),
      style: const TextStyle(color: Colors.white),
      decoration: MidiActionFields.decoration.copyWith(labelText: label),
      items: [
        for (final option in values)
          DropdownMenuItem(
            value: option,
            enabled: isEnabled?.call(option) ?? true,
            child: Text(optionLabel(option)),
          ),
      ],
      onChanged: (next) {
        if (next != null) setState(() => onChanged(next));
      },
    );
  }

  Widget _numberField({
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.number,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: MidiActionFields.decoration.copyWith(labelText: label),
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = _draft._type;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dropdown(
          label: 'Message Type',
          value: type,
          values: [
            for (final option in _MidiMessageType.values)
              if (option == type ||
                  _draft._canSelect(option) ||
                  (option == _MidiMessageType.mcu &&
                      _draft._mcuPayload != null))
                option,
          ],
          optionLabel: (type) => type.label,
          onChanged: (value) => _draft._type = value,
          isEnabled: _draft._canSelect,
        ),
        if (_draft._canSelect(type) && type != _MidiMessageType.unassigned) ...[
          const SizedBox(height: 12),
          _dropdown(
            label: 'MIDI Channel',
            value: _draft.channel,
            values: Iterable<int>.generate(16),
            optionLabel: (channel) => 'Channel ${channel + 1}',
            onChanged: (value) => _draft.channel = value,
          ),
        ],
        if (_draft._canSelect(type) &&
            type == _MidiMessageType.pitchBend &&
            !widget.usesPitchBendPosition) ...[
          const SizedBox(height: 12),
          _numberField(
            label: 'Pitch Bend Value (0-16383)',
            controller: _draft._pitchValue,
            validator: (value) =>
                _draft._parseNumber(value ?? '', 16383) == null
                ? 'Enter a value from 0 to 16383'
                : null,
          ),
        ],
        if (_draft._canSelect(type) &&
            (type == _MidiMessageType.cc ||
                type == _MidiMessageType.note ||
                type == _MidiMessageType.relativeCc)) ...[
          const SizedBox(height: 12),
          _numberField(
            label: type == _MidiMessageType.note
                ? 'MIDI Note (e.g., C3 or 60)'
                : _draft._highResolution && type == _MidiMessageType.cc
                ? 'CC Number (0-31)'
                : 'CC Number (0-127)',
            controller: _draft._identifier,
            validator: _draft._validateIdentifier,
            keyboardType: type == _MidiMessageType.note
                ? TextInputType.text
                : TextInputType.number,
          ),
        ],
        if (type == _MidiMessageType.cc)
          CheckboxListTile(
            title: const Text(
              '14-bit CC',
              style: TextStyle(color: Colors.white),
            ),
            value: _draft._highResolution,
            onChanged: (value) =>
                setState(() => _draft._highResolution = value ?? false),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        if (type == _MidiMessageType.note &&
            widget.supportsVariableVelocity) ...[
          const SizedBox(height: 12),
          _dropdown(
            label: 'Velocity Mode',
            value: _draft._velocityMode,
            values: NoteVelocityMode.values,
            optionLabel: (mode) => switch (mode) {
              NoteVelocityMode.fixed => 'Fixed',
              NoteVelocityMode.touchPosition => 'Touch Position',
            },
            onChanged: (value) => _draft._velocityMode = value,
          ),
          if (_draft._velocityMode == NoteVelocityMode.touchPosition) ...[
            const SizedBox(height: 12),
            _dropdown(
              label: 'Velocity Curve',
              value: _draft._velocityCurve,
              values: NoteVelocityCurve.values,
              optionLabel: (curve) => switch (curve) {
                NoteVelocityCurve.linear => 'Linear',
                NoteVelocityCurve.drumPad => 'Drum Pad',
              },
              onChanged: (value) => _draft._velocityCurve = value,
            ),
          ],
        ],
        if (type == _MidiMessageType.relativeCc && _draft._canSelect(type)) ...[
          const SizedBox(height: 12),
          _dropdown(
            label: 'Relative Encoding',
            value: _draft._encoding,
            values: RelativeCcEncoding.values,
            optionLabel: (encoding) => switch (encoding) {
              RelativeCcEncoding.signedBit => 'Signed Bit',
              RelativeCcEncoding.twosComplement => 'Two’s Complement',
              RelativeCcEncoding.binaryOffset => 'Binary Offset',
            },
            onChanged: (value) => _draft._encoding = value,
          ),
        ],
      ],
    );
  }
}
