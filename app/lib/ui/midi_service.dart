import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Stream<dynamic> get midiEventsStream =>
      _eventsChannel.receiveBroadcastStream();

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

  Future<bool> connectToDevice(String id, {int? inputPort, int? outputPort}) async {
    try {
      final bool? result = await _channel.invokeMethod('connectToDevice', {
        'id': id,
        'inputPort': inputPort,
        'outputPort': outputPort,
      }..removeWhere((key, value) => value == null));
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

  Future<void> sendCC(int cc, int value) async {
    try {
      await _channel.invokeMethod('sendMidiCC', {
        'cc': cc,
        'value': value,
      });
    } catch (e) {
      debugPrint('Failed to send CC $cc: $e');
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
      // using a specific pattern here for nullable copyWith if needed,
      // but simpler to just re-instantiate
      connectedDevice: connectedDevice,
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
    service.midiEventsStream.listen((event) {
      debugPrint("MIDI FLUTTER IN: $event");
      if (event is Map) {
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
                  (d) => d != null && d.id == id &&
                         d.name == previousDevice.name &&
                         d.manufacturer == previousDevice.manufacturer,
                  orElse: () => null,
                );

                if (newDevice != null) {
                  // Found the matching fingerprint under a new ID. Auto-reconnect!
                  connect(newDevice, inputPort: previousInput, outputPort: previousOutput);
                }
              });
            }
          } else {
            // General addition, just refresh UI
            ref.invalidate(midiDevicesProvider);
          }
        } else if (type == 'cc') {
          final ccNumber = event['cc'] as int?;
          final value = event['value'] as int?;
          if (ccNumber != null && value != null) {
            ref.read(ccValuesProvider.notifier).updateCC(ccNumber, value);
          }
        }
      }
    });

    return const MidiConnectionState();
  }

  Future<bool> connect(MidiDevice device, {int? inputPort, int? outputPort}) async {
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

enum MidiStatus { disconnected, available, connected, connectionLost }

// State is stored as an integer (0-127).
// In Riverpod 2.x/3.x, passing arguments to a Notifier happens via Family.
// For CC, we just want a simple state to sync inbound and outbound.
// A simpler alternative to FamilyNotifier is to just expose a map or use a custom class.
class CCState {
  final Map<int, int> values;
  CCState({this.values = const {}});

  CCState copyWith(int cc, int val) {
    final newValues = Map<int, int>.from(values);
    newValues[cc] = val;
    return CCState(values: newValues);
  }
}

class CcNotifier extends Notifier<CCState> {
  @override
  CCState build() {
    return CCState();
  }

  void updateCC(int cc, int value) {
    state = state.copyWith(cc, value);
  }
}

final ccValuesProvider = NotifierProvider<CcNotifier, CCState>(CcNotifier.new);

final midiStatusProvider = Provider<MidiStatus>((ref) {
  final connectionState = ref.watch(connectedMidiDeviceProvider);
  final devicesAsync = ref.watch(midiDevicesProvider);

  if (connectionState.isConnectionLost) {
    return MidiStatus.connectionLost;
  }

  if (connectionState.connectedDevice != null) {
    return MidiStatus.connected;
  }

  final devices = devicesAsync.value ?? [];
  if (devices.isNotEmpty) {
    return MidiStatus.available;
  }

  return MidiStatus.disconnected;
});
