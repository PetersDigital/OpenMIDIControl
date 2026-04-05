// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'package:flutter_test/flutter_test.dart';

import 'package:app/ui/midi_service.dart';

void main() {
  group('MidiPort', () {
    test('fromMap parses valid map correctly', () {
      final map = <dynamic, dynamic>{'number': 1, 'name': 'Test Port'};

      final port = MidiPort.fromMap(map);

      expect(port.number, 1);
      expect(port.name, 'Test Port');
    });

    test('fromMap defaults number to 0 when missing', () {
      final map = <dynamic, dynamic>{'name': 'Test Port'};

      final port = MidiPort.fromMap(map);

      expect(port.number, 0);
    });

    test('fromMap defaults name to "Unknown Port" when missing', () {
      final map = <dynamic, dynamic>{'number': 2};

      final port = MidiPort.fromMap(map);

      expect(port.name, 'Unknown Port');
    });
  });

  group('MidiDevice', () {
    test('fromMap parses full device map correctly', () {
      final map = <dynamic, dynamic>{
        'id': 'dev-1',
        'name': 'Kontrol S49',
        'manufacturer': 'Native Instruments',
        'inputPorts': [
          <dynamic, dynamic>{'number': 0, 'name': 'Port A'},
        ],
        'outputPorts': [
          <dynamic, dynamic>{'number': 1, 'name': 'Port B'},
        ],
      };

      final device = MidiDevice.fromMap(map);

      expect(device.id, 'dev-1');
      expect(device.name, 'Kontrol S49');
      expect(device.manufacturer, 'Native Instruments');
      expect(device.inputPorts.length, 1);
      expect(device.inputPorts.first.number, 0);
      expect(device.outputPorts.length, 1);
      expect(device.outputPorts.first.name, 'Port B');
    });

    test('fromMap defaults missing fields to safe values', () {
      final map = <dynamic, dynamic>{};

      final device = MidiDevice.fromMap(map);

      expect(device.id, 'unknown');
      expect(device.name, 'Unknown MIDI Device');
      expect(device.manufacturer, 'Unknown Manufacturer');
      expect(device.inputPorts, isEmpty);
      expect(device.outputPorts, isEmpty);
    });

    test('fromMap handles null port lists gracefully', () {
      final map = <dynamic, dynamic>{
        'id': 'dev-2',
        'inputPorts': null,
        'outputPorts': null,
      };

      final device = MidiDevice.fromMap(map);

      expect(device.inputPorts, isEmpty);
      expect(device.outputPorts, isEmpty);
    });

    test('fromMap handles empty port lists', () {
      final map = <dynamic, dynamic>{
        'id': 'dev-3',
        'inputPorts': <dynamic>[],
        'outputPorts': <dynamic>[],
      };

      final device = MidiDevice.fromMap(map);

      expect(device.inputPorts, isEmpty);
      expect(device.outputPorts, isEmpty);
    });
  });

  group('MidiConnectionState', () {
    test('Default constructor initializes with nulls and false', () {
      const state = MidiConnectionState();

      expect(state.connectedDevice, isNull);
      expect(state.isConnectionLost, isFalse);
      expect(state.inputPort, isNull);
      expect(state.outputPort, isNull);
    });

    test('copyWith preserves existing values when no args provided', () {
      final device = MidiDevice(
        id: 'dev-1',
        name: 'Test',
        manufacturer: 'Test Mfr',
      );
      final original = MidiConnectionState(
        connectedDevice: device,
        isConnectionLost: false,
        inputPort: 1,
        outputPort: 2,
      );

      final copied = original.copyWith();

      expect(copied.connectedDevice, same(device));
      expect(copied.isConnectionLost, isFalse);
      expect(copied.inputPort, 1);
      expect(copied.outputPort, 2);
    });

    test('copyWith updates only provided fields', () {
      final device = MidiDevice(
        id: 'dev-1',
        name: 'Test',
        manufacturer: 'Test Mfr',
      );
      final original = MidiConnectionState(
        connectedDevice: device,
        isConnectionLost: false,
        inputPort: 1,
        outputPort: 2,
      );

      final updated = original.copyWith(isConnectionLost: true);

      expect(updated.connectedDevice, same(device));
      expect(updated.isConnectionLost, isTrue);
      expect(updated.inputPort, 1);
      expect(updated.outputPort, 2);
    });

    test('copyWith does NOT clear connectedDevice when omitted (null coalescing)', () {
      final device = MidiDevice(
        id: 'dev-1',
        name: 'Test',
        manufacturer: 'Test Mfr',
      );
      final original = MidiConnectionState(connectedDevice: device);

      final updated = original.copyWith(isConnectionLost: true);

      // This is the intentional design: omitting connectedDevice preserves it
      expect(updated.connectedDevice, same(device));
    });

    test('disconnect clears device and ports for intentional disconnect', () {
      final device = MidiDevice(
        id: 'dev-1',
        name: 'Test',
        manufacturer: 'Test Mfr',
      );
      final original = MidiConnectionState(
        connectedDevice: device,
        isConnectionLost: false,
        inputPort: 1,
        outputPort: 2,
      );

      final disconnected = original.disconnect(connectionLost: false);

      expect(disconnected.connectedDevice, isNull);
      expect(disconnected.isConnectionLost, isFalse);
      expect(disconnected.inputPort, isNull);
      expect(disconnected.outputPort, isNull);
    });

    test('disconnect preserves device and ports for connection loss (auto-reconnect)', () {
      final device = MidiDevice(
        id: 'dev-1',
        name: 'Test',
        manufacturer: 'Test Mfr',
      );
      final original = MidiConnectionState(
        connectedDevice: device,
        isConnectionLost: false,
        inputPort: 1,
        outputPort: 2,
      );

      final lost = original.disconnect(connectionLost: true);

      expect(lost.connectedDevice, same(device));
      expect(lost.isConnectionLost, isTrue);
      expect(lost.inputPort, 1);
      expect(lost.outputPort, 2);
    });
  });
}
