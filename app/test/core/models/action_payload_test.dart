// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:convert';

import 'package:app/core/models/action_payload.dart';
import 'package:app/core/models/layout_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final payloads = [
    const CcPayload(channel: 0, cc: 0),
    const CcPayload(channel: 15, cc: 31, highResolution: true),
    const NotePayload(channel: 0, note: 127),
    const NotePayload(
      channel: 9,
      note: 36,
      velocityMode: NoteVelocityMode.touchPosition,
      velocityCurve: NoteVelocityCurve.drumPad,
    ),
    const PitchBendPayload(channel: 0),
    const PitchBendPayload(channel: 15, value: 16383),
    for (final encoding in RelativeCcEncoding.values)
      RelativeCcPayload(channel: 2, cc: 127, encoding: encoding),
    const McuActionPayload.fader(8),
    const McuActionPayload.vPot(7),
    const McuActionPayload.channelButton(0, McuChannelButton.recordArm),
    const McuActionPayload.transport(McuTransportAction.fastForward),
  ];

  for (final payload in payloads) {
    test('round-trips ${payload.toJson()}', () {
      final parsed = ActionPayload.fromJson(
        jsonDecode(jsonEncode(payload.toJson())),
      );
      expect(parsed, payload);
      expect(parsed.hashCode, payload.hashCode);
    });
  }

  test('transport action roles preserve their MCU wire names', () {
    expect(TransportAction.values.map((action) => action.name), [
      'play',
      'stop',
      'record',
      'cycle',
      'rewind',
      'fastForward',
      'bankLeft',
      'bankRight',
    ]);
    for (final action in TransportAction.values) {
      final json = {
        'type': 'mcu',
        'target': 'transport',
        'action': action.name,
      };
      final payload = McuActionPayload.transport(action);
      expect(ActionPayload.fromJson(json), payload);
      expect(payload.toJson(), json);
    }
  });

  test('rejects unknown variants and invalid wire values', () {
    final invalid = [
      {'type': 'unknown'},
      {'type': 'cc', 'channel': -1, 'cc': 0},
      {'type': 'cc', 'channel': 0, 'cc': 128},
      {'type': 'cc', 'channel': 0, 'cc': 0, 'highResolution': 'true'},
      {'type': 'pitchBend', 'channel': 0, 'value': 16384},
      {'type': 'relativeCc', 'channel': 0, 'cc': 7, 'encoding': 'unknown'},
      {'type': 'mcu', 'target': 'vPot', 'strip': 8},
      {'type': 'mcu', 'target': 'transport'},
    ];
    for (final json in invalid) {
      expect(() => ActionPayload.fromJson(json), throwsFormatException);
    }
  });

  test('preserves both typed axes through layout copies and JSON', () {
    final control = LayoutControl(
      id: 'xy',
      type: ControlType.xyPad,
      defaultCc: 10,
      secondaryCc: 11,
      channel: 0,
      payload: const PitchBendPayload(channel: 3),
      secondaryPayload: const RelativeCcPayload(
        channel: 7,
        cc: 22,
        encoding: RelativeCcEncoding.binaryOffset,
      ),
    );
    final copy = control.copyWith(x: 2, customName: 'Pan and modulation');
    expect(copy.payload, control.payload);
    expect(copy.secondaryPayload, control.secondaryPayload);
    expect(copy.effectiveSecondaryPayload, same(control.secondaryPayload));
    expect(LayoutControl.fromJson(jsonDecode(jsonEncode(copy.toJson()))), copy);
    expect(
      copy.copyWith(payload: const CcPayload(channel: 0, cc: 10)),
      isNot(copy),
    );

    final remappedY = copy.copyWith(secondaryCc: 16);
    expect(remappedY.payload, copy.payload);
    expect(remappedY.secondaryPayload, const CcPayload(channel: 0, cc: 16));
    final cleared = remappedY.copyWith(
      defaultCc: -1,
      secondaryCc: -1,
      channel: -1,
    );
    expect(cleared.payload, isNull);
    expect(cleared.secondaryPayload, isNull);
  });

  test('leaves Y unassigned when the legacy XY channel is unassigned', () {
    final control = LayoutControl(
      id: 'xy',
      type: ControlType.xyPad,
      defaultCc: -1,
      channel: -1,
    );
    expect(control.effectiveSecondaryPayload, isNull);
  });
}
