// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'dart:async';
import 'dart:collection';
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

class _LazyMidiEventList extends ListBase<MidiEvent> {
  final Int64List _data;
  final int _usedLongCount;
  final List<MidiEvent?> _cache;

  _LazyMidiEventList(this._data, this._usedLongCount)
    : _cache = List<MidiEvent?>.filled(
        _usedLongCount > 0 ? _usedLongCount ~/ 2 : 0,
        null,
        growable: false,
      );

  @override
  int get length => _usedLongCount > 0 ? _usedLongCount ~/ 2 : 0;

  @override
  set length(int newLength) =>
      throw UnsupportedError('Cannot modify _LazyMidiEventList');

  @override
  MidiEvent operator [](int index) {
    if (index < 0 || index >= length) throw RangeError.index(index, this);

    final cached = _cache[index];
    if (cached != null) {
      return cached;
    }

    final int i = 1 + (index * 2);
    final event = MidiEvent(_data[i], _data[i + 1]);
    _cache[index] = event;
    return event;
  }

  @override
  void operator []=(int index, MidiEvent value) {
    throw UnsupportedError('Cannot modify _LazyMidiEventList');
  }
}

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

class UsbHostConnectedStateNotifier extends Notifier<bool> {
  @override
  bool build() {
    final service = ref.watch(midiServiceProvider);
    var lastUsbState = 'INIT';

    final systemSub = service.systemEventsStream.listen((event) {
      if (event['type'] != 'usb_state') return;

      final usbState = event['state'] as String? ?? 'INIT';
      if (usbState == lastUsbState) return;
      lastUsbState = usbState;

      // Reset host-connected evidence when USB session changes.
      if (usbState == 'AVAILABLE' ||
          usbState == 'HOST_CONNECTED' ||
          usbState == 'DISCONNECTED' ||
          usbState == 'INIT') {
        state = false;
      }
    });

    ref.onDispose(() {
      systemSub.cancel();
    });

    return false;
  }

  void setConnected() {
    if (!state) {
      state = true;
    }
  }
}

final usbHostConnectedStateProvider =
    NotifierProvider<UsbHostConnectedStateNotifier, bool>(
      UsbHostConnectedStateNotifier.new,
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

  static const EventChannel _systemEventsChannel = EventChannel(
    'com.petersdigital.openmidicontrol/system_events',
  );

  final MidiRouter incomingRouter = MidiRouter();
  final MidiRouter outgoingRouter = MidiRouter();

  late final StreamController<Map<int, int>> _uiStateController;
  Stream<Map<int, int>> get uiStateUpdates => _uiStateController.stream;

  final Map<int, int> _cachedCcState = {};

  MidiService() {
    _uiStateController = StreamController<Map<int, int>>.broadcast(
      onListen: () {
        if (_cachedCcState.isNotEmpty) {
          _uiStateController.add(Map.unmodifiable(_cachedCcState));
        }
      },
    );
    _setupRouters();
  }
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
        final int usedLongCount = data.isNotEmpty ? data[0] : 0;

        // Phase 3: Defer MidiEvent instantiation using a lazy list.
        return _LazyMidiEventList(data, usedLongCount);
      })
      .asBroadcastStream();

  /// System-level events (USB state, device additions, removals).
  late final Stream<Map<dynamic, dynamic>> systemEventsStream =
      _systemEventsChannel
          .receiveBroadcastStream()
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
    if (cc < 0 || cc > 127 || value < 0 || value > 127) {
      debugPrint('Invalid MIDI CC send request: cc=$cc value=$value');
      return;
    }

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
    outgoingRouter.processSingle('source', event);
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
  bool _autoReconnectPending = false;
  String _lastUsbStatus = 'INIT';
  final Stopwatch _eventStopwatch = Stopwatch()..start();
  String? _lastDeviceEventKey;
  int _lastDeviceEventMs = 0;
  static const int _duplicateDeviceEventWindowMs = 500;

  bool _isDuplicateDeviceEvent(String type, dynamic id) {
    final key = '$type:$id';
    final nowMs = _eventStopwatch.elapsedMilliseconds;
    final isDuplicate =
        key == _lastDeviceEventKey &&
        (nowMs - _lastDeviceEventMs) < _duplicateDeviceEventWindowMs;

    _lastDeviceEventKey = key;
    _lastDeviceEventMs = nowMs;
    return isDuplicate;
  }

  void _scheduleDeviceRefresh([VoidCallback? onRefreshComplete]) {
    _deviceRefreshTimer?.cancel();
    _deviceRefreshTimer = Timer(const Duration(milliseconds: 300), () {
      ref.invalidate(midiDevicesProvider);
      onRefreshComplete?.call();
    });
  }

  bool _isPeripheralFingerprint(MidiDevice device) {
    final name = device.name.toLowerCase();
    final manufacturer = device.manufacturer.toLowerCase();
    return name.contains('usb peripheral port') ||
        name.contains('android usb peripheral') ||
        manufacturer.contains('android usb peripheral') ||
        name.contains('openmidicontrol');
  }

  void _tryAutoReconnectPreviousDevice(
    MidiService service,
    MidiDevice? previousDevice,
    int? previousInput,
    int? previousOutput,
  ) {
    if (_autoReconnectPending) return;
    _autoReconnectPending = true;

    Future.delayed(const Duration(milliseconds: 500), () async {
      if (!ref.mounted) {
        _autoReconnectPending = false;
        return;
      }
      _autoReconnectPending = false;

      // Connectivity-phase behavior: only auto-connect in peripheral mode.
      if (ref.read(usbModeProvider) != UsbMode.peripheral) return;

      // Avoid reconnect churn when already connected and stable.
      if (state.connectedDevice != null && !state.isConnectionLost) return;

      if (previousDevice == null) return;

      final devices = await service.getAvailableDevices();
      if (!ref.mounted) return;

      final target = devices.cast<MidiDevice?>().firstWhere(
        (d) =>
            d != null &&
            d.id == previousDevice.id &&
            d.name == previousDevice.name &&
            d.manufacturer == previousDevice.manufacturer,
        orElse: () => null,
      );
      if (target == null) return;

      // Found the matching fingerprint under a new ID. Auto-reconnect!
      connect(target, inputPort: previousInput, outputPort: previousOutput);
      ref.invalidate(midiDevicesProvider);
    });
  }

  void _tryAutoConnectPeripheral(MidiService service) {
    if (_autoReconnectPending) return;
    _autoReconnectPending = true;

    Future(() async {
      if (!ref.mounted) {
        _autoReconnectPending = false;
        return;
      }

      // Connectivity-phase behavior: only auto-connect in peripheral mode.
      if (ref.read(usbModeProvider) != UsbMode.peripheral) {
        _autoReconnectPending = false;
        return;
      }

      // Avoid reconnect churn when already connected and stable.
      if (state.connectedDevice != null && !state.isConnectionLost) {
        _autoReconnectPending = false;
        return;
      }

      final devices = await service.getAvailableDevices();
      if (!ref.mounted) {
        _autoReconnectPending = false;
        return;
      }

      final target = devices.cast<MidiDevice?>().firstWhere(
        (d) =>
            d != null &&
            _isPeripheralFingerprint(d) &&
            d.inputPorts.isNotEmpty &&
            d.outputPorts.isNotEmpty,
        orElse: () => null,
      );
      if (target == null) {
        _autoReconnectPending = false;
        return;
      }

      final inputPort = target.inputPorts.first.number;
      final outputPort = target.outputPorts.first.number;
      final success = await service.connectToDevice(
        target.id,
        inputPort: inputPort,
        outputPort: outputPort,
      );
      if (!ref.mounted) {
        _autoReconnectPending = false;
        return;
      }

      if (success) {
        state = MidiConnectionState(
          connectedDevice: target,
          isConnectionLost: false,
          inputPort: inputPort,
          outputPort: outputPort,
        );
        ref.invalidate(midiDevicesProvider);
      }
      _autoReconnectPending = false;
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
        if (_isDuplicateDeviceEvent(type as String, id)) {
          return;
        }

        // If the removed device is our currently connected device
        if (state.connectedDevice?.id == id) {
          state = state.disconnect(connectionLost: true);
          service.vibrate(
            pattern: [0, 100, 100, 100],
            amplitude: [0, 255, 0, 255],
          );
        }
        // Refresh the available devices list
        _scheduleDeviceRefresh();
      } else if (type == 'added') {
        if (_isDuplicateDeviceEvent(type as String, id)) {
          return;
        }

        // Refresh device list on any new added event.
        _scheduleDeviceRefresh();

        // Check for auto-reconnect if we previously lost connection
        if (state.isConnectionLost) {
          final previousDevice = state.connectedDevice;
          final previousInput = state.inputPort;
          final previousOutput = state.outputPort;

          // Immediately check the new device name/manufacturer to see if it's the one we lost
          if (previousDevice != null) {
            _tryAutoReconnectPreviousDevice(
              service,
              previousDevice,
              previousInput,
              previousOutput,
            );
          }
        }
      } else if (type == 'usb_state') {
        final usbStatus = event['state'] as String? ?? 'INIT';

        // Guardrail: only react to USB state transitions.
        // Duplicate broadcasts can otherwise retrigger disconnect+haptics repeatedly.
        if (usbStatus == _lastUsbStatus) {
          return;
        }
        _lastUsbStatus = usbStatus;

        if (usbStatus == 'DISCONNECTED' || usbStatus == 'INIT') {
          final shouldHandleDisconnect =
              state.connectedDevice != null || !state.isConnectionLost;

          // Only disconnect once per transition to avoid repeated thermal churn.
          if (shouldHandleDisconnect) {
            state = state.disconnect(connectionLost: true);
            service.vibrate(
              pattern: [0, 100, 100, 100],
              amplitude: [0, 255, 0, 255],
            );
          }
          _scheduleDeviceRefresh();
        } else if (usbStatus == 'AVAILABLE') {
          final previousDevice = state.connectedDevice;
          final previousInput = state.inputPort;
          final previousOutput = state.outputPort;

          _scheduleDeviceRefresh(() {
            if (state.isConnectionLost) {
              _tryAutoReconnectPreviousDevice(
                service,
                previousDevice,
                previousInput,
                previousOutput,
              );
            } else {
              _tryAutoConnectPeripheral(service);
            }
          });
        }
      }
    });

    // Capture the notifier once to avoid high-frequency ref.read overhead.
    // ConnectedMidiDeviceNotifier and UsbHostConnectedStateNotifier are both core
    // services whose lifecycles are tied to the app runtime.
    final usbHostConnectedNotifier = ref.read(
      usbHostConnectedStateProvider.notifier,
    );

    final midiSub = service.midiEventsStream.listen((midiEvents) {
      // First real MIDI payload from host confirms host-side link is active.
      if (midiEvents.isNotEmpty) {
        usbHostConnectedNotifier.setConnected();
      }
      // Process incoming events through the DAG starting from the root 'source' node
      service.incomingRouter.process('source', midiEvents);
    });

    ref.onDispose(() {
      _deviceRefreshTimer?.cancel();
      _autoReconnectPending = false;
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
  usbHostConnected,
}

class CcNotifier extends Notifier<ControlState> {
  late final Int32List _hotCcState;
  final List<int> _activeCcs = [];

  @override
  ControlState build() {
    _hotCcState = Int32List(128)..fillRange(0, 128, -1);
    final service = ref.watch(midiServiceProvider);

    final sub = service.uiStateUpdates.listen((updates) {
      updateMultipleCCs(updates);
    });

    ref.onDispose(() {
      sub.cancel();
    });

    final current = service.currentCcState;
    if (current.isNotEmpty) {
      for (final entry in current.entries) {
        if (entry.key >= 0 && entry.key < 128) {
          _hotCcState[entry.key] = entry.value;
          _activeCcs.add(entry.key);
        }
      }
      return ControlState(ccValues: current);
    }

    return ControlState(ccValues: const <int, int>{});
  }

  void updateCC(int cc, int value) {
    if (cc < 0 || cc >= 128) return;
    if (_hotCcState[cc] == value) return;

    if (_hotCcState[cc] == -1) {
      _activeCcs.add(cc);
    }
    _hotCcState[cc] = value;
    _publishState();
  }

  void updateMultipleCCs(Map<int, int> updates) {
    if (updates.isEmpty) return;

    bool hasChanges = false;
    for (final entry in updates.entries) {
      final cc = entry.key;
      final val = entry.value;
      if (cc >= 0 && cc < 128) {
        if (_hotCcState[cc] != val) {
          if (_hotCcState[cc] == -1) {
            _activeCcs.add(cc);
          }
          _hotCcState[cc] = val;
          hasChanges = true;
        }
      }
    }

    if (hasChanges) {
      _publishState();
    }
  }

  void _publishState() {
    final newValues = <int, int>{};
    for (final cc in _activeCcs) {
      newValues[cc] = _hotCcState[cc];
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
  final usbHostConnected = ref.watch(usbHostConnectedStateProvider);
  final manualSelection = ref.watch(manualPortSelectionProvider);

  return resolveMidiStatus(
    connectionState: connectionState,
    devices: devicesAsync.value ?? const <MidiDevice>[],
    usbState: usbState,
    usbMode: usbMode,
    usbHostConnected: usbHostConnected,
    manualSelection: manualSelection,
  );
});

MidiStatus resolveMidiStatus({
  required MidiConnectionState connectionState,
  required List<MidiDevice> devices,
  required String usbState,
  required UsbMode usbMode,
  required bool usbHostConnected,
  required bool manualSelection,
}) {
  if (connectionState.isConnectionLost) {
    return MidiStatus.connectionLost;
  }

  if (usbMode == UsbMode.peripheral && usbHostConnected) {
    return MidiStatus.usbHostConnected;
  }

  if (connectionState.connectedDevice != null) {
    return MidiStatus.connected;
  }

  // USB mode remains the top-level readiness state while the host link is
  // being negotiated, but once a device is actually connected we surface that
  // higher-level connection state instead of staying on READY.
  if (usbMode == UsbMode.peripheral && usbState == 'AVAILABLE') {
    return MidiStatus.usbActive;
  }

  // Strict UX semantics: host link events alone do not imply data flow.
  // UI remains READY until real MIDI payloads are observed.
  if (usbMode == UsbMode.peripheral && usbState == 'HOST_CONNECTED') {
    return MidiStatus.usbActive;
  }

  final visibleDevices = manualSelection
      ? devices
      : devices.where((device) => !device.name.startsWith('Virtual'));

  if (visibleDevices.isNotEmpty) {
    return MidiStatus.available;
  }

  return MidiStatus.disconnected;
}
