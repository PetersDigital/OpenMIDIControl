// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/midi_event.dart';
import 'sink_node.dart';

@pragma('vm:entry-point')
void _nativeTransportWorker(List<dynamic> args) {
  final SendPort sendPort = args[0] as SendPort;
  final RootIsolateToken token = args[1] as RootIsolateToken;

  BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  const channel = MethodChannel('com.petersdigital.openmidicontrol/midi');

  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((message) {
    if (message is TransferableTypedData) {
      final batch = message.materialize().asInt64List();
      channel.invokeMethod('sendMidiCCBatch', {'events': batch}).catchError((
        e,
      ) {
        debugPrint('Worker: Failed to send MIDI CC batch: $e');
      });
    }
  });
}

class NativeTransportSinkNode extends SinkNode {
  final MethodChannel channel;

  static const int _maxBufferSize = 10;
  static const Duration _flushInterval = Duration(milliseconds: 16);

  static final Int64List _sharedBuffer = Int64List(
    16000,
  ); // 8000 events slots (2 entries per event)

  @visibleForTesting
  static int get sharedBufferCapacity => _sharedBuffer.length;

  final List<MidiEvent> _eventBuffer = [];
  Timer? _flushTimer;

  SendPort? _workerSendPort;
  Isolate? _workerIsolate;
  bool _isDisposed = false;
  final bool useBackgroundWorker;

  NativeTransportSinkNode({
    required this.channel,
    this.useBackgroundWorker = true,
  }) {
    if (useBackgroundWorker) {
      _initWorker();
    }
  }

  Future<void> _initWorker() async {
    final token = RootIsolateToken.instance;
    if (token == null) return;

    final receivePort = ReceivePort();
    try {
      _workerIsolate = await Isolate.spawn(_nativeTransportWorker, [
        receivePort.sendPort,
        token,
      ], debugName: 'NativeTransportWorker');

      if (_isDisposed) {
        _workerIsolate?.kill();
        receivePort.close();
        return;
      }

      _workerSendPort = await receivePort.first as SendPort;
    } catch (e) {
      debugPrint('Failed to initialize native transport worker: $e');
    }
  }

  void _queue(MidiEvent event) {
    _eventBuffer.add(event);
    if (_eventBuffer.length > 6400) {
      _flush();
      if (_eventBuffer.length > 6400) {
        throw StateError('Event buffer overflow');
      }
    }
  }

  @override
  void executeSingle(MidiEvent event) {
    // Filter out non-MIDI 1.0 voice messages
    final statusNibble = event.legacyStatusByte & 0xF0;
    if (event.messageType == 0x2 &&
        (statusNibble == 0x80 ||
            statusNibble == 0x90 ||
            statusNibble == 0xB0 ||
            statusNibble == 0xE0)) {
      _queue(event);

      if (_flushTimer == null || !_flushTimer!.isActive) {
        _flushTimer = Timer(_flushInterval, () => _flush());
      }

      if (event.isFinal || _eventBuffer.length >= _maxBufferSize) {
        _flushTimer?.cancel();
        _flushTimer = null;
        _flush();
      }
    }
  }

  @override
  void execute(List<MidiEvent> events) {
    if (events.isEmpty) return;

    for (var event in events) {
      final statusNibble = event.legacyStatusByte & 0xF0;
      if (event.messageType == 0x2 &&
          (statusNibble == 0x80 ||
              statusNibble == 0x90 ||
              statusNibble == 0xB0 ||
              statusNibble == 0xE0)) {
        _queue(event);
      }
    }

    if (_eventBuffer.isEmpty) return;

    if (_flushTimer == null || !_flushTimer!.isActive) {
      _flushTimer = Timer(_flushInterval, () => _flush());
    }

    if (events.any((e) => e.isFinal) || _eventBuffer.length >= _maxBufferSize) {
      _flushTimer?.cancel();
      _flushTimer = null;
      _flush();
    }
  }

  void _flush() {
    _flushTimer?.cancel();
    _flushTimer = null;

    if (_eventBuffer.isEmpty) {
      return;
    }

    final int count = _eventBuffer.length;
    final int requiredCapacity = count * 2;

    if (_workerSendPort != null) {
      // Background isolate path: allocate new buffer and transfer ownership to avoid GC churn in main isolate
      final buffer = Int64List(requiredCapacity);
      for (int i = 0; i < count; i++) {
        buffer[i * 2] = _eventBuffer[i].ump;
        buffer[i * 2 + 1] = _eventBuffer[i].isFinal ? 1 : 0;
      }
      final transferable = TransferableTypedData.fromList([buffer]);
      _workerSendPort!.send(transferable);
    } else {
      // Main isolate fallback (used during startup or in tests)
      for (int i = 0; i < count; i++) {
        _sharedBuffer[i * 2] = _eventBuffer[i].ump;
        _sharedBuffer[i * 2 + 1] = _eventBuffer[i].isFinal ? 1 : 0;
      }

      final batch = Int64List.sublistView(_sharedBuffer, 0, requiredCapacity);

      channel.invokeMethod('sendMidiCCBatch', {'events': batch}).catchError((
        e,
      ) {
        debugPrint('Failed to send MIDI CC batch: $e');
      });
    }

    _eventBuffer.clear();
  }

  void dispose() {
    _isDisposed = true;
    _flushTimer?.cancel();
    _eventBuffer.clear();
    _workerIsolate?.kill(priority: Isolate.immediate);
  }
}
