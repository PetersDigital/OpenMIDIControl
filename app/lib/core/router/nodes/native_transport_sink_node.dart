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
      _sendBatch(channel, batch);
    }
  });
}

void _sendBatch(MethodChannel channel, Int64List batch) {
  final method = batch[0] == -2 ? 'sendMidiBatchV2' : 'sendMidiCCBatch';
  unawaited(
    channel
        .invokeMethod<bool>(method, {'events': batch})
        .then<void>(
          (_) {},
          onError: (Object error) =>
              debugPrint('Failed to send MIDI batch: $error'),
        ),
  );
}

class NativeTransportSinkNode extends SinkNode {
  final MethodChannel channel;

  static const int _maxBufferSize = 10;
  static const Duration _flushInterval = Duration(milliseconds: 16);

  static final Int64List _sharedBuffer = Int64List(1 + 8000 * 3);

  @visibleForTesting
  static int get sharedBufferCapacity => _sharedBuffer.length;

  final List<MidiEvent> _eventBuffer = [];
  bool _usesMidi2 = false;
  Timer? _flushTimer;

  SendPort? _workerSendPort;
  ReceivePort? _workerReceivePort;
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
    _workerReceivePort = receivePort;
    try {
      _workerIsolate = await Isolate.spawn(_nativeTransportWorker, [
        receivePort.sendPort,
        token,
      ], debugName: 'NativeTransportWorker');

      if (_isDisposed) {
        _workerIsolate?.kill(priority: Isolate.immediate);
        _workerIsolate = null;
        receivePort.close();
        _workerReceivePort = null;
        return;
      }

      _workerSendPort = await receivePort.first as SendPort;
    } catch (e) {
      debugPrint('Failed to initialize native transport worker: $e');
    }
  }

  void _queue(MidiEvent event) {
    _eventBuffer.add(event);
    _usesMidi2 |= event.messageType == 4;
    if (_eventBuffer.length > 6400) {
      _flush();
      if (_eventBuffer.length > 6400) {
        throw StateError('Event buffer overflow');
      }
    }
  }

  @override
  void executeSingle(MidiEvent event) {
    if (_supports(event)) {
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

    for (final event in events) {
      if (_supports(event)) _queue(event);
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

    final worker = _workerSendPort;
    final count = _eventBuffer.length;
    final stride = _usesMidi2 ? 3 : 2;
    final requiredCapacity = count * stride + (_usesMidi2 ? 1 : 0);
    final batch = worker == null
        ? Int64List.sublistView(_sharedBuffer, 0, requiredCapacity)
        : Int64List(requiredCapacity);

    var offset = 0;
    if (_usesMidi2) batch[offset++] = -2;
    for (final event in _eventBuffer) {
      batch[offset++] = event.ump;
      if (_usesMidi2) batch[offset++] = event.umpWord1 ?? 0;
      batch[offset++] = _transportFlags(event);
    }

    if (worker == null) {
      _sendBatch(channel, batch);
    } else {
      worker.send(TransferableTypedData.fromList([batch]));
    }
    _eventBuffer.clear();
    _usesMidi2 = false;
  }

  static bool _supports(MidiEvent event) {
    if (event.messageType == 2) {
      return switch (event.status) {
        0x80 || 0x90 || 0xB0 || 0xE0 => true,
        _ => false,
      };
    }
    final value = event.umpWord1;
    if (event.messageType != 4 ||
        value == null ||
        value < 0 ||
        value > 0xFFFFFFFF) {
      return false;
    }
    return switch (event.status) {
      0xE0 => event.ump & 0xFFFF == 0,
      0xB0 => event.data2 == 0 && MidiEvent.isMidi2AbsoluteCc(event.data1),
      _ => false,
    };
  }

  static int _transportFlags(MidiEvent event) =>
      (event.isFinal ? 1 : 0) | (event.acceptFeedback ? 2 : 0);

  void dispose() {
    _isDisposed = true;
    _flushTimer?.cancel();
    _flushTimer = null;
    _eventBuffer.clear();
    _workerReceivePort?.close();
    _workerReceivePort = null;
    _workerSendPort = null;
    _workerIsolate?.kill(priority: Isolate.immediate);
    _workerIsolate = null;
  }
}
