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
  static const MethodChannel _channel = MethodChannel('com.petersdigital.openmidicontrol/midi');

  Future<List<MidiDevice>> getAvailableDevices() async {
    try {
      final List<dynamic>? result = await _channel.invokeMethod('getMidiDevices');
      if (result != null) {
        return result.map((e) => MidiDevice.fromMap(e as Map<dynamic, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Failed to get MIDI devices: $e');
      return [];
    }
  }

  Future<bool> connectToDevice(String id) async {
    try {
      final bool? result = await _channel.invokeMethod('connectToDevice', {'id': id});
      return result ?? false;
    } catch (e) {
      debugPrint('Failed to connect to device $id: $e');
      return false;
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

class ConnectedMidiDeviceNotifier extends Notifier<MidiDevice?> {
  @override
  MidiDevice? build() => null;

  Future<bool> connect(MidiDevice device) async {
    final service = ref.read(midiServiceProvider);
    final success = await service.connectToDevice(device.id);
    if (success) {
      state = device;
    } else {
      state = null;
    }
    return success;
  }
}

final connectedMidiDeviceProvider = NotifierProvider<ConnectedMidiDeviceNotifier, MidiDevice?>(
  ConnectedMidiDeviceNotifier.new,
);
