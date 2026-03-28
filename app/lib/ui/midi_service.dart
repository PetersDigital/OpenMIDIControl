import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/control_state.dart';
import '../core/models/midi_event.dart';
import 'midi_settings_state.dart'
    show manualPortSelectionProvider, usbModeProvider, UsbMode;

class MidiPort {
  final int number;
  final String name;

  MidiPort({required this.number, required this.name});

  factory MidiPort.fromMap(Map<dynamic, dynamic> map) {
    return MidiPort(
      number: map['number'] as int? ?? 0,
      name: map['name'] as String? ?? 'Unknown Port',
    );
  }
}

class UsbConnectionStateNotifier extends Notifier<String> {
  @override
  String build() {
    final service = ref.watch(midiServiceProvider);

    final sub = service.systemEventsStream.listen((event) {
      if (event['type'] == 'usb_state') {
        state = event['state'] as String? ?? 'INIT';
      }
    });

    ref.onDispose(() {
      sub.cancel();
    });

    return 'INIT';
  }
}

final usbConnectionStateProvider =
    NotifierProvider<UsbConnectionStateNotifier, String>(
      UsbConnectionStateNotifier.new,
    );

class MidiDevice {
  final String id;
  final String name;
  final String manufacturer;
  final List<MidiPort> inputPorts;
  final List<MidiPort> outputPorts;

  MidiDevice({
    required this.id,
    required this.name,
    required this.manufacturer,
    this.inputPorts = const [],
    this.outputPorts = const [],
  });

  factory MidiDevice.fromMap(Map<dynamic, dynamic> map) {
    final rawInPorts = map['inputPorts'] as List<dynamic>? ?? [];
    final rawOutPorts = map['outputPorts'] as List<dynamic>? ?? [];

    return MidiDevice(
      id: map['id'] as String? ?? 'unknown',
      name: map['name'] as String? ?? 'Unknown MIDI Device',
      manufacturer: map['manufacturer'] as String? ?? 'Unknown Manufacturer',
      inputPorts: rawInPorts.map((p) => MidiPort.fromMap(p as Map)).toList(),
      outputPorts: rawOutPorts.map((p) => MidiPort.fromMap(p as Map)).toList(),
    );
  }
}

class MidiService {
  static const MethodChannel _channel = MethodChannel(
    'com.petersdigital.openmidicontrol/midi',
  );
  static const EventChannel _eventsChannel = EventChannel(
    'com.petersdigital.openmidicontrol/midi_events',
  );

  late final Stream<dynamic> _rawStream = _eventsChannel
      .receiveBroadcastStream()
      .asBroadcastStream();

  /// High-performance stream of parsed MIDI events.
  late final Stream<List<MidiEvent>> midiEventsStream = _rawStream
      .where((e) {
        return e is Int64List;
      })
      .map((event) {
        final data = event as Int64List;
        final List<MidiEvent> parsedEvents = [];

        // Decode the 1D LongArray batch (Pairs of UMP Integer, Timestamp)
        for (int i = 0; i < data.length; i += 2) {
          int ump = data[i];
          int timestamp = data[i + 1];

          // Phase 3: Directly initialize UMP events natively using the bitwise getters in the model
          parsedEvents.add(MidiEvent(ump, timestamp));
        }

        return parsedEvents;
      })
      .asBroadcastStream();

  /// System-level events (USB state, device additions, removals).
  late final Stream<Map<dynamic, dynamic>> systemEventsStream = _rawStream
      .where((e) {
        if (e is! Map) return false;
        final type = e['type'];
        return type == 'added' || type == 'removed' || type == 'usb_state';
      })
      .cast<Map<dynamic, dynamic>>()
      .asBroadcastStream();

  Future<List<MidiDevice>> getAvailableDevices() async {
    try {
      final List<dynamic>? result = await _channel.invokeMethod(
        'getMidiDevices',
      );
      if (result != null) {
        return result
            .map((e) => MidiDevice.fromMap(e as Map<dynamic, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Failed to get MIDI devices: $e');
      return [];
    }
  }

  Future<bool> connectToDevice(
    String id, {
    int? inputPort,
    int? outputPort,
  }) async {
    try {
      final bool? result = await _channel.invokeMethod(
        'connectToDevice',
        {'id': id, 'inputPort': inputPort, 'outputPort': outputPort}
          ..removeWhere((key, value) => value == null),
      );
      return result ?? false;
    } catch (e) {
      debugPrint('Failed to connect to device $id: $e');
      return false;
    }
  }

  Future<void> disconnectDevice() async {
    try {
      await _channel.invokeMethod('disconnectDevice');
    } catch (e) {
      debugPrint('Failed to disconnect device: $e');
    }
  }

  Future<void> sendCC(int cc, int value, {bool isFinal = false}) async {
    try {
      await _channel.invokeMethod('sendMidiCC', {
        'cc': cc,
        'value': value,
        'isFinal': isFinal,
      });
    } catch (e) {
      debugPrint('Failed to send CC $cc: $e');
    }
  }

  Future<void> setUsbMode(String mode) async {
    try {
      await _channel.invokeMethod('setUsbMode', {'mode': mode});
    } catch (e) {
      debugPrint('Failed to set USB mode: $e');
    }
  }

  Future<void> vibrate({
    int? duration,
    List<int>? pattern,
    List<int>? amplitude,
  }) async {
    try {
      if (pattern != null && amplitude != null) {
        await _channel.invokeMethod('vibrate', {
          'pattern': pattern,
          'amplitude': amplitude,
        });
      } else {
        await _channel.invokeMethod('vibrate', {'duration': duration ?? 50});
      }
    } catch (e) {
      debugPrint('Failed to trigger native haptic: $e');
      // Fallback to Flutter haptics if native fails
      if (duration != null && duration > 100) {
        HapticFeedback.vibrate();
      } else {
        HapticFeedback.mediumImpact();
      }
    }
  }
}

final midiServiceProvider = Provider<MidiService>((ref) {
  return MidiService();
});

final midiDevicesProvider = FutureProvider<List<MidiDevice>>((ref) async {
  final service = ref.watch(midiServiceProvider);
  return await service.getAvailableDevices();
});

class MidiConnectionState {
  final MidiDevice? connectedDevice;
  final bool isConnectionLost;
  final int? inputPort;
  final int? outputPort;

  const MidiConnectionState({
    this.connectedDevice,
    this.isConnectionLost = false,
    this.inputPort,
    this.outputPort,
  });

  MidiConnectionState copyWith({
    MidiDevice? connectedDevice,
    bool? isConnectionLost,
    int? inputPort,
    int? outputPort,
  }) {
    return MidiConnectionState(
      // preserve existing connection when parameter is omitted.
      // To intentionally clear connectedDevice, provide explicit null sentinel support.
      connectedDevice: connectedDevice ?? this.connectedDevice,
      isConnectionLost: isConnectionLost ?? this.isConnectionLost,
      inputPort: inputPort ?? this.inputPort,
      outputPort: outputPort ?? this.outputPort,
    );
  }

  MidiConnectionState disconnect({bool connectionLost = false}) {
    // We only wipe the ports if it was intentionally disconnected by the user.
    // If connection was lost, we keep the ports around for silent auto-reconnect.
    return MidiConnectionState(
      connectedDevice: connectionLost ? connectedDevice : null,
      isConnectionLost: connectionLost,
      inputPort: connectionLost ? inputPort : null,
      outputPort: connectionLost ? outputPort : null,
    );
  }
}

class ConnectedMidiDeviceNotifier extends Notifier<MidiConnectionState> {
  @override
  MidiConnectionState build() {
    final service = ref.watch(midiServiceProvider);

    // Listen to device connection events from Kotlin
    final systemSub = service.systemEventsStream.listen((event) {
      final type = event['type'];
      final id = event['id'];

      if (type == 'removed') {
        // If the removed device is our currently connected device
        if (state.connectedDevice?.id == id) {
          state = state.disconnect(connectionLost: true);
          service.vibrate(
            pattern: [0, 100, 100, 100],
            amplitude: [0, 255, 0, 255],
          );
        } else {
          // General removal of a non-connected device
          service.vibrate(duration: 500);
        }
        // Refresh the available devices list
        ref.invalidate(midiDevicesProvider);
      } else if (type == 'added') {
        // Refresh device list on any new added event.
        ref.invalidate(midiDevicesProvider);

        // Check for auto-reconnect if we previously lost connection
        if (state.isConnectionLost) {
          final previousDevice = state.connectedDevice;
          final previousInput = state.inputPort;
          final previousOutput = state.outputPort;

          // Immediately check the new device name/manufacturer to see if it's the one we lost
          if (previousDevice != null) {
            // Wait for the new device list to populate from Android
            Future.delayed(const Duration(milliseconds: 500), () async {
              final devices = await service.getAvailableDevices();
              final newDevice = devices.cast<MidiDevice?>().firstWhere(
                (d) =>
                    d != null &&
                    d.id == id &&
                    d.name == previousDevice.name &&
                    d.manufacturer == previousDevice.manufacturer,
                orElse: () => null,
              );

              if (newDevice != null) {
                // Found the matching fingerprint under a new ID. Auto-reconnect!
                connect(
                  newDevice,
                  inputPort: previousInput,
                  outputPort: previousOutput,
                );
                ref.invalidate(midiDevicesProvider);
              }
            });
          }
        }
      } else if (type == 'usb_state') {
        final usbStatus = event['state'];

        if (usbStatus == 'DISCONNECTED' || usbStatus == 'INIT') {
          // FORCE the teardown. Do NOT hide this behind a connectedDevice != null check.
          // The physical cable is gone; the state must reflect it immediately.
          state = state.disconnect(connectionLost: true);
          service.vibrate(
            pattern: [0, 100, 100, 100],
            amplitude: [0, 255, 0, 255],
          );
          ref.invalidate(midiDevicesProvider);
        }
      }
    });

    final midiSub = service.midiEventsStream.listen((midiEvents) {
      final Map<int, int> batchUpdates = {};
      for (var midiEvent in midiEvents) {
        if (midiEvent.legacyStatusByte >= 0xB0 && midiEvent.legacyStatusByte <= 0xBF) {
          batchUpdates[midiEvent.data1] = midiEvent.data2;
        }
      }

      // Update state EXACTLY once per batch to prevent O(N) map churning/rebuilds
      if (batchUpdates.isNotEmpty) {
        ref.read(ccValuesProvider.notifier).updateMultipleCCs(batchUpdates);
      }
    });

    ref.onDispose(() {
      systemSub.cancel();
      midiSub.cancel();
    });

    return const MidiConnectionState();
  }

  Future<bool> connect(
    MidiDevice device, {
    int? inputPort,
    int? outputPort,
  }) async {
    final service = ref.read(midiServiceProvider);
    service.vibrate(duration: 50); // Stronger lightImpact equivalent
    final success = await service.connectToDevice(
      device.id,
      inputPort: inputPort,
      outputPort: outputPort,
    );
    if (success) {
      state = MidiConnectionState(
        connectedDevice: device,
        isConnectionLost: false,
        inputPort: inputPort,
        outputPort: outputPort,
      );
      service.vibrate(duration: 100); // Stronger mediumImpact equivalent
    } else {
      state = state.disconnect();
    }
    return success;
  }

  void disconnect() {
    final service = ref.read(midiServiceProvider);
    service.vibrate(duration: 50);
    service.disconnectDevice();
    state = state.disconnect(connectionLost: false);
  }
}

final connectedMidiDeviceProvider =
    NotifierProvider<ConnectedMidiDeviceNotifier, MidiConnectionState>(
      ConnectedMidiDeviceNotifier.new,
    );

enum MidiStatus {
  disconnected,
  available,
  connected,
  connectionLost,
  usbActive,
}

class CcNotifier extends Notifier<ControlState> {
  @override
  ControlState build() {
    return ControlState(ccValues: const <int, int>{});
  }

  void updateCC(int cc, int value) {
    if (state.ccValues[cc] == value) return;
    state = state.copyWithCC(cc, value);
  }

  void updateMultipleCCs(Map<int, int> updates) {
    if (updates.isEmpty) return;
    
    // Check if any values actually changed before creating a new map
    var hasChanges = false;
    for (final entry in updates.entries) {
      if (state.ccValues[entry.key] != entry.value) {
        hasChanges = true;
        break;
      }
    }
    if (!hasChanges) return;

    // Only copy changed entries for better performance
    final newValues = Map<int, int>.from(state.ccValues);
    for (final entry in updates.entries) {
      newValues[entry.key] = entry.value;
    }
    state = state.copyWith(ccValues: newValues);
  }
}

final ccValuesProvider = NotifierProvider<CcNotifier, ControlState>(
  CcNotifier.new,
);

final midiStatusProvider = Provider<MidiStatus>((ref) {
  final connectionState = ref.watch(connectedMidiDeviceProvider);
  final devicesAsync = ref.watch(midiDevicesProvider);
  final usbState = ref.watch(usbConnectionStateProvider);
  final usbMode = ref.watch(usbModeProvider);

  // USB Mode takes highest precedence if in peripheral mode and connected
  if (usbMode == UsbMode.peripheral && usbState == 'AVAILABLE') {
    return MidiStatus.usbActive;
  }

  if (connectionState.isConnectionLost) {
    return MidiStatus.connectionLost;
  }

  if (connectionState.connectedDevice != null) {
    return MidiStatus.connected;
  }

  final devices = devicesAsync.value ?? [];
  // Exclude internal ports from the "available" check if manual selection is off,
  // otherwise the UI will always show AVAILABLE because of the virtual ports.
  final manualSelection = ref.watch(manualPortSelectionProvider);
  final externalDevices = devices
      .where((d) => manualSelection || d.manufacturer != 'PetersDigital')
      .toList();

  if (externalDevices.isNotEmpty) {
    return MidiStatus.available;
  }

  return MidiStatus.disconnected;
});
