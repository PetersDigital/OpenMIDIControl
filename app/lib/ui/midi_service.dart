import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MidiDevice {
  final String id;
  final String name;
  final String manufacturer;

  MidiDevice({
    required this.id,
    required this.name,
    required this.manufacturer,
  });

  factory MidiDevice.fromMap(Map<dynamic, dynamic> map) {
    return MidiDevice(
      id: map['id'] as String? ?? 'unknown',
      name: map['name'] as String? ?? 'Unknown MIDI Device',
      manufacturer: map['manufacturer'] as String? ?? 'Unknown Manufacturer',
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

  Future<bool> connectToDevice(String id) async {
    try {
      final bool? result = await _channel.invokeMethod('connectToDevice', {
        'id': id,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('Failed to connect to device $id: $e');
      return false;
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

  const MidiConnectionState({
    this.connectedDevice,
    this.isConnectionLost = false,
  });

  MidiConnectionState copyWith({
    MidiDevice? connectedDevice,
    bool? isConnectionLost,
  }) {
    return MidiConnectionState(
      // using a specific pattern here for nullable copyWith if needed,
      // but simpler to just re-instantiate
      connectedDevice: connectedDevice,
      isConnectionLost: isConnectionLost ?? this.isConnectionLost,
    );
  }

  MidiConnectionState disconnect({bool connectionLost = false}) {
    return MidiConnectionState(
      connectedDevice: null,
      isConnectionLost: connectionLost,
    );
  }
}

class ConnectedMidiDeviceNotifier extends Notifier<MidiConnectionState> {
  @override
  MidiConnectionState build() {
    final service = ref.watch(midiServiceProvider);

    // Listen to device connection events from Kotlin
    service.midiEventsStream.listen((event) {
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
          if (state.isConnectionLost) {
            state = state.disconnect(connectionLost: false);
          }
          ref.invalidate(midiDevicesProvider);
        }
      }
    });

    return const MidiConnectionState();
  }

  Future<bool> connect(MidiDevice device) async {
    final service = ref.read(midiServiceProvider);
    service.vibrate(duration: 50); // Stronger lightImpact equivalent
    final success = await service.connectToDevice(device.id);
    if (success) {
      state = MidiConnectionState(
        connectedDevice: device,
        isConnectionLost: false,
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
    state = state.disconnect(connectionLost: false);
  }
}

final connectedMidiDeviceProvider =
    NotifierProvider<ConnectedMidiDeviceNotifier, MidiConnectionState>(
      ConnectedMidiDeviceNotifier.new,
    );

enum MidiStatus { disconnected, available, connected, connectionLost }

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
