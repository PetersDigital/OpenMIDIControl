// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/control_state.dart';
import '../core/models/midi_event.dart';
import '../core/router/midi_router.dart';
import '../core/router/nodes/native_transport_sink_node.dart';
import '../core/router/nodes/split_node.dart';
import '../core/router/nodes/ui_state_sink_node.dart';
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

  final MidiRouter incomingRouter = MidiRouter();
  final MidiRouter outgoingRouter = MidiRouter();

  MidiService() {
    _setupRouters();
  }

  // Intentionally never closed: MidiService is a singleton Provider with app lifetime.
  final StreamController<Map<int, int>> _uiStateController =
      StreamController<Map<int, int>>.broadcast();
  Stream<Map<int, int>> get uiStateUpdates => _uiStateController.stream;

  final Map<int, int> _cachedCcState = {};
  Map<int, int> get currentCcState => Map.unmodifiable(_cachedCcState);

  final Stopwatch _stopwatch = Stopwatch()..start();

  void _setupRouters() {
    // Add default root nodes for the DAG to process from
    incomingRouter.addNode('source', SplitNode());
    outgoingRouter.addNode('source', SplitNode());

    // Set up the NativeTransportSinkNode here
    outgoingRouter.addNode(
      'nativeSink',
      NativeTransportSinkNode(channel: _channel),
    );

    // Connect root to sink by default so events flow out
    outgoingRouter.addEdge('source', 'nativeSink');

    // UI state sink for processing incoming CC streams cleanly
    incomingRouter.addNode(
      'uiStateSink',
      UiStateSinkNode(
        onUpdateCCs: (batchUpdates) {
          if (batchUpdates.isNotEmpty) {
            _cachedCcState.addAll(batchUpdates);
            _uiStateController.add(batchUpdates);
          }
        },
      ),
    );
    incomingRouter.addEdge('source', 'uiStateSink');
  }

  late final Stream<dynamic> _rawStream = _eventsChannel
      .receiveBroadcastStream();

  /// High-performance stream of parsed MIDI events.
  late final Stream<List<MidiEvent>> midiEventsStream = _rawStream
      .where((e) {
        return e is Int64List;
      })
      .map((event) {
        final data = event as Int64List;
        final List<MidiEvent> parsedEvents = [];

        // Decode the 1D LongArray batch (Pairs of UMP Integer, Timestamp)
        for (int i = 0; i + 1 < data.length; i += 2) {
          int ump = data[i];
          int timestamp = data[i + 1];

          // Phase 3: Directly initialize UMP events natively using the bitwise getters in the model
          parsedEvents.add(MidiEvent(ump, timestamp));
        }

        return parsedEvents;
      });

  /// System-level events (USB state, device additions, removals).
  late final Stream<Map<dynamic, dynamic>> systemEventsStream = _rawStream
      .where((e) {
        if (e is! Map) return false;
        final type = e['type'];
        return type == 'added' || type == 'removed' || type == 'usb_state';
      })
      .cast<Map<dynamic, dynamic>>();

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
    // Construct a UMP for the CC event.
    // [4 bits Message Type][4 bits Group][8 bits Status][8 bits Data1][8 bits Data2]
    // Message Type = 0x2 (MIDI 1.0 Voice)
    // Group = 0 (default)
    // Status = 0xB0 (CC on channel 0) -> let's assume channel 0 for now as previous logic didn't specify
    // Data1 = cc
    // Data2 = value
    int ump =
        (0x2 << 28) |
        (0x0 << 24) |
        (0xB0 << 16) |
        ((cc & 0xFF) << 8) |
        (value & 0xFF);
    final event = MidiEvent(
      ump,
      _stopwatch.elapsedMilliseconds,
      isFinal: isFinal,
    );

    // Process through the outgoing router starting from the root 'source' node.
    outgoingRouter.process('source', [event]);
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
  Timer? _deviceRefreshTimer;

  void _scheduleDeviceRefresh() {
    _deviceRefreshTimer?.cancel();
    _deviceRefreshTimer = Timer(const Duration(milliseconds: 300), () {
      ref.invalidate(midiDevicesProvider);
    });
  }

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
        _scheduleDeviceRefresh();
      } else if (type == 'added') {
        // Refresh device list on any new added event.
        _scheduleDeviceRefresh();

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
          _scheduleDeviceRefresh();
        }
      }
    });

    final midiSub = service.midiEventsStream.listen((midiEvents) {
      // Process incoming events through the DAG starting from the root 'source' node
      service.incomingRouter.process('source', midiEvents);
    });

    ref.onDispose(() {
      _deviceRefreshTimer?.cancel();
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
    final service = ref.watch(midiServiceProvider);

    final sub = service.uiStateUpdates.listen((updates) {
      updateMultipleCCs(updates);
    });

    ref.onDispose(() {
      sub.cancel();
    });

    return ControlState(
      ccValues: service.currentCcState.isNotEmpty
          ? service.currentCcState
          : const <int, int>{},
    );
  }

  void updateCC(int cc, int value) {
    if (state.ccValues[cc] == value) return;
    state = state.copyWithCC(cc, value);
  }

  void updateMultipleCCs(Map<int, int> updates) {
    if (updates.isEmpty) return;

    // Lazy-init: only allocate new map when first change is detected
    Map<int, int>? newValues;
    for (final entry in updates.entries) {
      if (state.ccValues[entry.key] != entry.value) {
        newValues ??= Map<int, int>.from(state.ccValues);
        newValues[entry.key] = entry.value;
      }
    }
    if (newValues != null) {
      state = state.copyWith(ccValues: newValues);
    }
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
