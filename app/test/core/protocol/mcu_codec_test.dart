// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:app/core/models/action_payload.dart';
import 'package:app/core/models/midi_event.dart';
import 'package:app/core/protocol/mcu/mcu_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fader wire positions and touch notes cover all strips and master', () {
    for (var strip = 0; strip <= 8; strip++) {
      for (final value in [0, 8192, 8193, 16383]) {
        final packet = McuCodec.faderPosition(strip, value, timestamp: 0);
        expect(packet.channel, strip);
        final feedback = McuCodec.decode(packet)! as McuFaderFeedback;
        expect((feedback.strip, feedback.value), (strip, value));
      }
      final target = McuActionPayload.fader(strip);
      expect(
        McuCodec.switchEvent(target, true, timestamp: 0).ump,
        0x2090687F + (strip << 8),
      );
      expect(
        McuCodec.switchEvent(target, false, timestamp: 0).ump,
        0x20806800 + (strip << 8),
      );
    }
    expect(McuCodec.faderPosition(0, 8193, timestamp: 0).ump, 0x20E00140);
    expect(() => McuCodec.faderPosition(9, 0, timestamp: 0), throwsRangeError);
    expect(
      () => McuCodec.faderPosition(0, 16384, timestamp: 0),
      throwsRangeError,
    );
  });

  test('strip, encoder and 3×3 header targets map to their MCU addresses', () {
    for (var strip = 0; strip < 8; strip++) {
      for (final (button, base) in [
        (McuChannelButton.recordArm, 0x00),
        (McuChannelButton.solo, 0x08),
        (McuChannelButton.mute, 0x10),
        (McuChannelButton.select, 0x18),
      ]) {
        expect(
          McuCodec.switchNote(McuActionPayload.channelButton(strip, button)),
          base + strip,
        );
      }
      expect(McuCodec.switchNote(McuActionPayload.vPot(strip)), 0x20 + strip);
    }
    expect(
      McuCodec.headerActions.map(
        (role) => McuCodec.switchNote(McuActionPayload.transport(role)),
      ),
      [0x5B, 0x60, 0x5F, 0x62, 0x5D, 0x63, 0x5C, 0x61, 0x5E],
    );
    for (final (role, note) in [
      (TransportAction.cycle, 0x56),
      (TransportAction.bankLeft, 0x2E),
      (TransportAction.bankRight, 0x2F),
      (TransportAction.channelLeft, 0x30),
      (TransportAction.channelRight, 0x31),
    ]) {
      expect(McuCodec.switchNote(McuActionPayload.transport(role)), note);
    }
    for (final role in TransportAction.values) {
      final target = McuActionPayload.transport(role);
      expect(ActionPayload.fromJson(target.toJson()), target);
    }
    expect(
      () =>
          ActionPayload.fromJson({'type': 'mcu', 'target': 'vPot', 'strip': 8}),
      throwsFormatException,
    );
  });

  test('V-Pots preserve repeated steps and split signed magnitudes', () {
    expect(McuCodec.vPotTurn(7, 0, timestamp: 0), isEmpty);
    expect(McuCodec.vPotTurn(7, 1, timestamp: 0).single.ump, 0x20B01701);
    expect(McuCodec.vPotTurn(7, -1, timestamp: 0).single.ump, 0x20B01741);
    expect(McuCodec.vPotTurn(7, -127, timestamp: 0).map((e) => e.ump), [
      0x20B0177F,
      0x20B0177F,
      0x20B01741,
    ]);
  });

  test('MT 2 and MT 4 host replies decode to matching feedback', () {
    final bend =
        McuCodec.decode(const MidiEvent(0x40E70000, 0, umpWord1: 0x80040001))!
            as McuFaderFeedback;
    expect((bend.strip, bend.value), (7, 8193));
    for (final (packet, state) in [
      (const MidiEvent(0x20905E00, 0), McuLampState.off),
      (const MidiEvent(0x20905E01, 0), McuLampState.flashing),
      (const MidiEvent(0x40905E00, 0, umpWord1: 0xFFFF0000), McuLampState.on),
      (const MidiEvent(0x40805E00, 0, umpWord1: 0xFFFF0000), McuLampState.off),
    ]) {
      final lamp = McuCodec.decode(packet)! as McuLampFeedback;
      expect((lamp.note, lamp.state), (0x5E, state));
    }
    for (final event in [
      const MidiEvent(0x20BF4531, 0),
      const MidiEvent(0x40BF4500, 0, umpWord1: 0x62000000),
    ]) {
      final digit = McuCodec.decode(event)! as McuTimeDigitFeedback;
      expect((digit.digit, digit.value), (5, 0x31));
    }
    expect(McuCodec.decode(const MidiEvent(0x20913C7F, 0)), isNull);
  });
}
