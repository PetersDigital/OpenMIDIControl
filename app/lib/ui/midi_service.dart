// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../core/lifecycle/app_lifecycle_manager.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:isolate';

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

/// Helper to identify if a device is the native Android USB peripheral port.
/// Broadened to handle manufacturer-specific naming (Samsung, etc.) and localization.
bool isPeripheralPort(MidiDevice device) {
  final name = device.name.toLowerCase();
  final manufacturer = device.manufacturer.toLowerCase();

  // Explicitly exclude internal virtual ports created by this app.
  if (manufacturer.contains('petersdigital') || name.contains('virtual')) {
    return false;
  }

  // Peripheral ports often contain these strings depending on OEM/Manufacturer.
  // Google (Pixel), Samsung (Galaxy), Android (Generic), etc.
  return name.contains('peripheral') ||
      name.contains('android usb') ||
      name.contains('usb client') ||
      manufacturer.contains('android') ||
      manufacturer.contains('google') ||
      manufacturer.contains('samsung') ||
      (name.contains('usb') && name.contains('midi'));
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

  SendPort? _workerSendPort;
  final List<dynamic> _queuedEvents = [];
  late final ReceivePort _workerReceivePort;
  StreamSubscription<dynamic>? _workerReceivePortSubscription;
  Isolate? _workerIsolate;

  final MidiRouter outgoingRouter = MidiRouter();

  late final StreamController<Map<String, dynamic>> _uiStateController;
  Stream<Map<String, dynamic>> get uiStateUpdates => _uiStateController.stream;

  late final Stream<List<MidiEvent>> midiEventsStream;

  late final StreamController<bool> _hostConnectionController;
  Stream<bool> get hostConnectionStream => _hostConnectionController.stream;

  bool _hostLinkConfirmed = false;

  final Map<String, dynamic> _cachedState = {};

  MidiService() {
    _uiStateController = StreamController<Map<String, dynamic>>.broadcast(
      onListen: () {
        if (_cachedState.isNotEmpty) {
          _uiStateController.add(Map.unmodifiable(_cachedState));
        }
      },
    );
    _hostConnectionController = StreamController<bool>.broadcast();

    // Reset native state on startup/hot-restart to clear deduplication buffers
    _channel.invokeMethod('resetMidiTransport').catchError((e) {
      debugPrint('Failed to reset MIDI transport: $e');
    });

    _setupRouters();
    _initStreams();
    _initWorker();
  }
  Map<String, dynamic> get currentState => Map.unmodifiable(_cachedState);

  final Stopwatch _stopwatch = Stopwatch()..start();

  late final Stream<dynamic> _rawStream;
  StreamSubscription<dynamic>? _rawStreamSubscription;

  void _initStreams() {
    _rawStream = _eventsChannel.receiveBroadcastStream();

    midiEventsStream = _rawStream.where((e) => e is Int64List).map((event) {
      final data = event as Int64List;
      return _LazyMidiEventList(data, data.isNotEmpty ? data[0] : 0);
    }).asBroadcastStream();

    _rawStreamSubscription = _rawStream.listen((event) {
      if (event is Int64List) {
        final int usedLongCount = event.isNotEmpty ? event[0] : 0;

        if (usedLongCount > 0 && !_hostLinkConfirmed) {
          _hostLinkConfirmed = true;
          _hostConnectionController.add(true);
        }

        if (_workerSendPort != null) {
          _workerSendPort!.send(event);
        } else {
          _queuedEvents.add(event);
        }
      }
    });
  }

  Future<void> _initWorker() async {
    _workerReceivePort = ReceivePort();
    _workerReceivePortSubscription = _workerReceivePort.listen((message) {
      if (message is SendPort) {
        _workerSendPort = message;
        if (_queuedEvents.isNotEmpty) {
          for (final e in _queuedEvents) {
            _workerSendPort!.send(e);
          }
          _queuedEvents.clear();
        }
      } else if (message is (String, dynamic)) {
        final type = message.$1;
        final payload = message.$2;

        if (type == 'state_update') {
          _handleStateUpdate(payload as Map<String, dynamic>);
        }
      }
    });

    _workerIsolate = await Isolate.spawn(
      _midiWorkerEntryPoint,
      _workerReceivePort.sendPort,
      debugName: 'MidiWorkerIsolate',
    );
  }

  void _handleStateUpdate(Map<String, dynamic> updates) {
    if (updates.isEmpty) return;

    final unmodifiableUpdates = <String, dynamic>{};

    final ccs = updates['ccs'] as Map<String, int>?;
    if (ccs != null && ccs.isNotEmpty) {
      final currentCcs =
          _cachedState['ccs'] as Map<String, int>? ?? <String, int>{};
      final nextCcs = Map<String, int>.unmodifiable({...currentCcs, ...ccs});
      _cachedState['ccs'] = nextCcs;
      unmodifiableUpdates['ccs'] = Map<String, int>.unmodifiable(ccs);
    }

    final notes = updates['notes'] as Map<int, List<int>>?;
    if (notes != null) {
      final nextNotes = Map<int, List<int>>.unmodifiable(
        notes.map((k, v) => MapEntry(k, List<int>.unmodifiable(v))),
      );
      _cachedState['notes'] = nextNotes;
      unmodifiableUpdates['notes'] = nextNotes;
    }

    final buttons = updates['buttons'] as Map<String, bool>?;
    if (buttons != null && buttons.isNotEmpty) {
      final currentButtons =
          _cachedState['buttons'] as Map<String, bool>? ?? <String, bool>{};
      final nextButtons = Map<String, bool>.unmodifiable({
        ...currentButtons,
        ...buttons,
      });
      _cachedState['buttons'] = nextButtons;
      unmodifiableUpdates['buttons'] = Map<String, bool>.unmodifiable(buttons);
    }

    if (unmodifiableUpdates.isNotEmpty) {
      _uiStateController.add(
        Map<String, dynamic>.unmodifiable(unmodifiableUpdates),
      );
    }
  }

  void _setupRouters() {
    // Add default root nodes for the DAG to process from
    outgoingRouter.addNode('source', SplitNode());

    // Set up the NativeTransportSinkNode here
    outgoingRouter.addNode(
      'nativeSink',
      NativeTransportSinkNode(channel: _channel),
    );

    // Loopback for local UI synchronization (e.g. Fader -> XY Pad)
    outgoingRouter.addNode(
      'uiSyncSink',
      UiStateSinkNode(
        onStateUpdate: (updates) {
          // Immediately ingest local changes into the UI state
          _handleStateUpdate(updates);
        },
      ),
    );

    // Connect root to both sinks so events flow out to host AND loop back to UI
    outgoingRouter.addEdge('source', 'nativeSink');
    outgoingRouter.addEdge('source', 'uiSyncSink');
  }

  void dispose() {
    _rawStreamSubscription?.cancel();
    _workerReceivePortSubscription?.cancel();
    _uiStateController.close();
    _hostConnectionController.close();
    _workerReceivePort.close();
    _workerIsolate?.kill();
  }

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

  Future<void> sendCC(
    int cc,
    int value, {
    int channel = 0,
    bool isFinal = false,
  }) async {
    if (cc < 0 ||
        cc > 127 ||
        value < 0 ||
        value > 127 ||
        channel < 0 ||
        channel > 15) {
      debugPrint(
        'Invalid MIDI CC send request: cc=$cc value=$value channel=$channel',
      );
      return;
    }

    int ump =
        (0x2 << 28) |
        (0x0 << 24) |
        ((0xB0 | channel) << 16) |
        ((cc & 0xFF) << 8) |
        (value & 0xFF);
    final event = MidiEvent(
      ump,
      _stopwatch.elapsedMilliseconds,
      isFinal: isFinal,
    );

    outgoingRouter.processSingle('source', event);
  }

  Future<void> sendNoteOn(
    int note,
    int velocity, {
    int channel = 9,
    bool isFinal = false,
  }) async {
    if (note < 0 ||
        note > 127 ||
        velocity < 0 ||
        velocity > 127 ||
        channel < 0 ||
        channel > 15) {
      debugPrint(
        'Invalid MIDI NoteOn send request: note=$note velocity=$velocity channel=$channel',
      );
      return;
    }

    int ump =
        (0x2 << 28) |
        (0x0 << 24) |
        ((0x90 | channel) << 16) |
        ((note & 0xFF) << 8) |
        (velocity & 0xFF);
    final event = MidiEvent(
      ump,
      _stopwatch.elapsedMilliseconds,
      isFinal: isFinal,
    );
    outgoingRouter.processSingle('source', event);
  }

  Future<void> sendNoteOff(
    int note, {
    int channel = 9,
    bool isFinal = false,
  }) async {
    if (note < 0 || note > 127 || channel < 0 || channel > 15) {
      debugPrint(
        'Invalid MIDI NoteOff send request: note=$note channel=$channel',
      );
      return;
    }

    // Note off uses 0x80 status, velocity 0
    int ump =
        (0x2 << 28) |
        (0x0 << 24) |
        ((0x80 | channel) << 16) |
        ((note & 0xFF) << 8) |
        0x00;
    final event = MidiEvent(
      ump,
      _stopwatch.elapsedMilliseconds,
      isFinal: isFinal,
    );
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
  final devices = await service.getAvailableDevices();
  final usbMode = ref.watch(usbModeProvider);

  if (usbMode == UsbMode.peripheral) {
    // Hide internal virtual ports to prevent auto-routing loops and premature
    // connections when the app is acting as a hardware peripheral for a host PC.
    return devices
        .where(
          (d) =>
              !d.manufacturer.toLowerCase().contains('petersdigital') &&
              !d.name.toLowerCase().contains('virtual'),
        )
        .toList();
  }
  return devices;
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
  final List<VoidCallback> _pendingRefreshCallbacks = [];
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
    if (onRefreshComplete != null) {
      _pendingRefreshCallbacks.add(onRefreshComplete);
    }

    // Coalesce multiple refresh requests into a single delayed execution
    // instead of resetting the timer (which can delay refresh forever in bursts)
    if (_deviceRefreshTimer != null && _deviceRefreshTimer!.isActive) {
      return;
    }

    _deviceRefreshTimer = Timer(const Duration(milliseconds: 300), () {
      ref.invalidate(midiDevicesProvider);

      if (_pendingRefreshCallbacks.isNotEmpty) {
        final callbacks = List<VoidCallback>.from(_pendingRefreshCallbacks);
        _pendingRefreshCallbacks.clear();
        for (final cb in callbacks) {
          cb();
        }
      }
    });
  }

  bool _isPeripheralFingerprint(MidiDevice device) {
    return isPeripheralPort(device);
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

      final devices = await ref.read(midiDevicesProvider.future);
      if (!ref.mounted) return;

      final target = devices.cast<MidiDevice?>().firstWhere(
        (d) =>
            d != null &&
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

      final devices = await ref.read(midiDevicesProvider.future);
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

      if (type == 'removed' || type == 'DISCONNECT') {
        if (_isDuplicateDeviceEvent(type as String, id)) {
          return;
        }

        // If the removed device is our currently connected device
        if (state.connectedDevice?.id == id || type == 'DISCONNECT') {
          final isTargetDevice = id == null || state.connectedDevice?.id == id;
          if (isTargetDevice) {
            state = state.disconnect(connectionLost: true);
            service.vibrate(
              pattern: [0, 100, 100, 100],
              amplitude: [0, 255, 0, 255],
            );
          }
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

    final hostSub = service.hostConnectionStream.listen((isConnected) {
      if (isConnected) {
        usbHostConnectedNotifier.setConnected();
      }
    });

    ref.onDispose(() {
      _deviceRefreshTimer?.cancel();
      _pendingRefreshCallbacks.clear();
      _autoReconnectPending = false;
      systemSub.cancel();
      hostSub.cancel();
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
  usbHostAwaitingPort,
  usbHostConnected,
}

class ControlStateNotifier extends Notifier<ControlState> {
  final Map<String, int> _hotCcState = {};
  final Map<int, Set<int>> _hotNoteStates = {};
  final Map<String, bool> _hotButtonStates = {};

  final Map<String, StreamController<int>> _hotCcControllers = {};
  Timer? _pendingIncomingPublishTimer;
  bool _hasPendingIncomingState = false;
  static const Duration _incomingStatePublishInterval = Duration(
    milliseconds: 16,
  );

  bool _isPaused = false;

  @override
  ControlState build() {
    final service = ref.watch(midiServiceProvider);

    ref.listen(appLifecycleStateProvider, (previous, next) {
      _isPaused =
          (next == AppLifecycleState.paused ||
          next == AppLifecycleState.hidden);
    });

    final sub = service.uiStateUpdates.listen((updates) {
      if (_isPaused) return;
      ingestIncomingUpdates(updates);
    });

    ref.onDispose(() {
      sub.cancel();
      _pendingIncomingPublishTimer?.cancel();
      for (final controller in _hotCcControllers.values) {
        controller.close();
      }
    });

    final current = service.currentState;
    if (current.isNotEmpty) {
      final ccs = current['ccs'] as Map<String, int>? ?? {};
      _hotCcState.addAll(ccs);

      final notes = current['notes'] as Map<int, List<int>>? ?? {};
      for (final entry in notes.entries) {
        _hotNoteStates[entry.key] = entry.value.toSet();
      }

      final buttons = current['buttons'] as Map<String, bool>? ?? {};
      _hotButtonStates.addAll(buttons);

      return ControlState(
        ccValues: _hotCcState,
        noteStates: _hotNoteStates,
        buttonStates: _hotButtonStates,
      );
    }

    return ControlState(
      ccValues: const <String, int>{},
      noteStates: const <int, Set<int>>{},
      buttonStates: const <String, bool>{},
    );
  }

  Stream<int> watchHotCc(String address) async* {
    final current = _hotCcState[address];
    if (current != null) {
      yield current;
    }

    final controller = _hotCcControllers.putIfAbsent(
      address,
      () => StreamController<int>.broadcast(),
    );
    yield* controller.stream;
  }

  void ingestIncomingUpdates(Map<String, dynamic> updates) {
    if (updates.isEmpty) return;

    bool hasChanges = false;

    final ccs = updates['ccs'] as Map<String, int>?;
    if (ccs != null && ccs.isNotEmpty) {
      if (_applyCcUpdates(ccs)) hasChanges = true;
    }

    final notes = updates['notes'] as Map<int, List<int>>?;
    if (notes != null) {
      _hotNoteStates.clear();
      for (final entry in notes.entries) {
        _hotNoteStates[entry.key] = entry.value.toSet();
      }
      hasChanges = true;
    }

    final buttons = updates['buttons'] as Map<String, bool>?;
    if (buttons != null && buttons.isNotEmpty) {
      _hotButtonStates.addAll(buttons);
      hasChanges = true;
    }

    if (!hasChanges) return;

    _hasPendingIncomingState = true;
    _pendingIncomingPublishTimer ??= Timer(_incomingStatePublishInterval, () {
      _pendingIncomingPublishTimer = null;
      if (!_hasPendingIncomingState) return;
      _hasPendingIncomingState = false;
      _publishState();
    });
  }

  void injectState(ControlState presetState) {
    _hotNoteStates.clear();
    _hotButtonStates.clear();

    for (final entry in presetState.noteStates.entries) {
      _hotNoteStates[entry.key] = Set.from(entry.value);
    }
    _hotButtonStates.addAll(presetState.buttonStates);

    _hotCcState.clear();
    for (final entry in presetState.ccValues.entries) {
      _hotCcState[entry.key] = entry.value;
      _hotCcControllers[entry.key]?.add(entry.value);
    }

    _publishState();
  }

  void updateCC(String address, int value) {
    if (!_applySingleCcUpdate(address, value)) return;
    _publishState();
  }

  void updateMultipleCCs(Map<String, int> updates) {
    if (updates.isEmpty) return;
    if (_applyCcUpdates(updates)) {
      _publishState();
    }
  }

  bool _applyCcUpdates(Map<String, int> updates) {
    bool hasChanges = false;
    for (final entry in updates.entries) {
      if (_applySingleCcUpdate(entry.key, entry.value)) {
        hasChanges = true;
      }
    }
    return hasChanges;
  }

  bool _applySingleCcUpdate(String address, int value) {
    if (_hotCcState[address] == value) return false;

    _hotCcState[address] = value;
    _hotCcControllers[address]?.add(value);
    return true;
  }

  void _publishState() {
    state = ControlState(
      ccValues: Map<String, int>.of(_hotCcState),
      noteStates: Map<int, Set<int>>.of(_hotNoteStates),
      buttonStates: Map<String, bool>.of(_hotButtonStates),
    );
  }
}

final controlStateProvider =
    NotifierProvider<ControlStateNotifier, ControlState>(
      ControlStateNotifier.new,
    );

/// Single-layer StreamProvider for per-CC hot values.
/// Eliminates the previous intermediate StreamProvider wrapper.
final hotCcValueProvider = StreamProvider.autoDispose.family<int, String>((
  ref,
  address,
) {
  final notifier = ref.watch(controlStateProvider.notifier);
  return notifier.watchHotCc(address);
});

final midiStatusProvider = Provider<MidiStatus>((ref) {
  final connectionState = ref.watch(connectedMidiDeviceProvider);
  final devices = ref.watch(
    midiDevicesProvider.select(
      (asyncVal) => asyncVal.value ?? const <MidiDevice>[],
    ),
  );
  final usbState = ref.watch(usbConnectionStateProvider);
  final usbMode = ref.watch(usbModeProvider);
  final usbHostConnected = ref.watch(usbHostConnectedStateProvider);
  final manualSelection = ref.watch(manualPortSelectionProvider);

  return resolveMidiStatus(
    connectionState: connectionState,
    devices: devices,
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

  if (connectionState.connectedDevice != null) {
    if (usbMode == UsbMode.peripheral) {
      // If we are in peripheral mode and connected to the host port,
      // or if the native layer has confirmed an active data link.
      if (usbHostConnected ||
          isPeripheralPort(connectionState.connectedDevice!)) {
        return MidiStatus.usbHostConnected;
      }
    }
    return MidiStatus.connected;
  }

  if (usbMode == UsbMode.peripheral && usbHostConnected) {
    return MidiStatus.usbHostAwaitingPort;
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

void _midiWorkerEntryPoint(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  final incomingRouter = MidiRouter();
  incomingRouter.addNode('source', SplitNode());
  incomingRouter.addNode(
    'uiStateSink',
    UiStateSinkNode(
      onStateUpdate: (batchUpdates) {
        if (batchUpdates.isNotEmpty) {
          mainSendPort.send(('state_update', batchUpdates));
        }
      },
    ),
  );
  incomingRouter.addEdge('source', 'uiStateSink');

  receivePort.listen((message) {
    if (message is Int64List) {
      final int usedLongCount = message.isNotEmpty ? message[0] : 0;
      final events = _LazyMidiEventList(message, usedLongCount);
      incomingRouter.process('source', events);
    }
  });
}
