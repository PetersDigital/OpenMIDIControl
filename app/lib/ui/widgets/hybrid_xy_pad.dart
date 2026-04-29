// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design_system.dart';
import '../midi_service.dart';
import 'config_gesture_wrapper.dart';

class XYPadConfig {
  final int ccX;
  final int ccY;
  final int channel;
  final bool invertX;
  final bool invertY;

  const XYPadConfig({
    required this.ccX,
    required this.ccY,
    required this.channel,
    required this.invertX,
    required this.invertY,
  });

  Map<String, dynamic> toJson() => {
    'ccX': ccX,
    'ccY': ccY,
    'channel': channel,
    'invertX': invertX,
    'invertY': invertY,
  };

  factory XYPadConfig.fromJson(Map<String, dynamic> json) {
    return XYPadConfig(
      ccX: json['ccX'] as int,
      ccY: json['ccY'] as int,
      channel: json['channel'] as int,
      invertX: json['invertX'] as bool,
      invertY: json['invertY'] as bool,
    );
  }

  XYPadConfig copyWith({
    int? ccX,
    int? ccY,
    int? channel,
    bool? invertX,
    bool? invertY,
  }) {
    return XYPadConfig(
      ccX: ccX ?? this.ccX,
      ccY: ccY ?? this.ccY,
      channel: channel ?? this.channel,
      invertX: invertX ?? this.invertX,
      invertY: invertY ?? this.invertY,
    );
  }
}

class XYPadConfigManager extends Notifier<Map<String, XYPadConfig>> {
  @override
  Map<String, XYPadConfig> build() => const {};

  void setConfig(String id, XYPadConfig config) {
    state = {...state, id: config};
  }

  void setAllConfigs(Map<String, XYPadConfig> configs) {
    state = Map.unmodifiable(configs);
  }
}

final xyPadConfigProvider =
    NotifierProvider<XYPadConfigManager, Map<String, XYPadConfig>>(
      XYPadConfigManager.new,
    );

class HybridXYPad extends ConsumerStatefulWidget {
  final String id;
  final int ccX;
  final int ccY;
  final int channel;
  final bool invertX;
  final bool invertY;
  final Color padColor;

  const HybridXYPad({
    super.key,
    required this.id,
    required this.ccX,
    required this.ccY,
    this.channel = 0,
    this.invertX = false,
    this.invertY = true, // By default, Y=0 is usually bottom in audio software
    this.padColor = const Color(0xFF282A2E),
  });

  @override
  ConsumerState<HybridXYPad> createState() => _HybridXYPadState();
}

class _HybridXYPadState extends ConsumerState<HybridXYPad>
    with TickerProviderStateMixin {
  bool _isDragging = false;
  double _normalizedX = 0.5;
  double _normalizedY = 0.5;

  Timer? _throttleTimer;
  bool _canSend = true;
  bool _hasPendingSend = false;

  // Gesture state (Managed by ConfigGestureWrapper)
  ProviderSubscription<AsyncValue<int>>? _ccXSubscription;
  ProviderSubscription<AsyncValue<int>>? _ccYSubscription;

  @override
  void initState() {
    super.initState();
    final config = ref.read(xyPadConfigProvider)[widget.id];
    final channel = config?.channel ?? widget.channel;
    final ccX = config?.ccX ?? widget.ccX;
    final ccY = config?.ccY ?? widget.ccY;

    final hotX = ref.read(hotCcValueProvider("$channel:$ccX")).asData?.value;
    final hotY = ref.read(hotCcValueProvider("$channel:$ccY")).asData?.value;

    if (hotX != null) {
      _normalizedX = hotX / 127.0;
    }
    if (hotY != null) {
      _normalizedY = hotY / 127.0;
    }

    _setupListeners();
  }

  void _setupListeners() {
    _ccXSubscription?.close();
    _ccYSubscription?.close();

    final config = ref.read(xyPadConfigProvider)[widget.id];
    final channel = config?.channel ?? widget.channel;
    final ccX = config?.ccX ?? widget.ccX;
    final ccY = config?.ccY ?? widget.ccY;

    _ccXSubscription = ref.listenManual<AsyncValue<int>>(
      hotCcValueProvider("$channel:$ccX"),
      (previous, next) => next.whenData(_handleXUpdate),
    );
    _ccYSubscription = ref.listenManual<AsyncValue<int>>(
      hotCcValueProvider("$channel:$ccY"),
      (previous, next) => next.whenData(_handleYUpdate),
    );
  }

  @override
  void dispose() {
    _ccXSubscription?.close();
    _ccYSubscription?.close();
    _throttleTimer?.cancel();
    super.dispose();
  }

  void _showConfigMenu() {
    final currentConfig =
        ref.read(xyPadConfigProvider)[widget.id] ??
        XYPadConfig(
          ccX: widget.ccX,
          ccY: widget.ccY,
          channel: widget.channel,
          invertX: widget.invertX,
          invertY: widget.invertY,
        );
    _showConfigDialog(context, currentConfig);
  }

  void _handleXUpdate(int val) {
    if (_isDragging) return;
    if (!mounted) return;

    final config = ref.read(xyPadConfigProvider)[widget.id];
    final invertX = config?.invertX ?? widget.invertX;
    final norm = val / 127.0;

    setState(() {
      _normalizedX = invertX ? 1.0 - norm : norm;
    });
  }

  void _handleYUpdate(int val) {
    if (_isDragging) return;
    if (!mounted) return;

    final config = ref.read(xyPadConfigProvider)[widget.id];
    final invertY = config?.invertY ?? widget.invertY;
    final norm = val / 127.0;

    setState(() {
      _normalizedY = invertY ? 1.0 - norm : norm;
    });
  }

  void _updatePosition(
    Offset localPosition,
    Size size, {
    required bool isFinal,
  }) {
    final double nx = (localPosition.dx / size.width).clamp(0.0, 1.0);
    final double ny = (localPosition.dy / size.height).clamp(0.0, 1.0);

    setState(() {
      _normalizedX = nx;
      _normalizedY = ny;
    });

    _sendMidi(isFinal: isFinal);
  }

  void _sendMidi({required bool isFinal}) {
    if (!_canSend && !isFinal) {
      setState(() => _isDragging = true);
      _hasPendingSend = true;
      return;
    }

    _canSend = false;
    _hasPendingSend = false;
    _throttleTimer?.cancel();

    _throttleTimer = Timer(const Duration(milliseconds: 16), () {
      _canSend = true;
      if (_hasPendingSend && mounted && _isDragging) {
        _sendMidi(isFinal: false);
      }
    });

    final config = ref.read(xyPadConfigProvider)[widget.id];
    final effectiveCcX = config?.ccX ?? widget.ccX;
    final effectiveCcY = config?.ccY ?? widget.ccY;
    final effectiveChannel = config?.channel ?? widget.channel;
    final effectiveInvertX = config?.invertX ?? widget.invertX;
    final effectiveInvertY = config?.invertY ?? widget.invertY;

    final effectiveX = effectiveInvertX ? 1.0 - _normalizedX : _normalizedX;
    final effectiveY = effectiveInvertY ? 1.0 - _normalizedY : _normalizedY;

    final valX = (effectiveX * 127).round().clamp(0, 127);
    final valY = (effectiveY * 127).round().clamp(0, 127);

    final service = ref.read(midiServiceProvider);

    // Batch these closely together
    service.sendCC(
      effectiveCcX,
      valX,
      channel: effectiveChannel,
      isFinal: isFinal,
    );
    service.sendCC(
      effectiveCcY,
      valY,
      channel: effectiveChannel,
      isFinal: isFinal,
    );
  }

  void _showConfigDialog(BuildContext context, XYPadConfig currentConfig) {
    final ccXController = TextEditingController(
      text: currentConfig.ccX.toString(),
    );
    final ccYController = TextEditingController(
      text: currentConfig.ccY.toString(),
    );
    final channelController = TextEditingController(
      text: currentConfig.channel.toString(),
    );
    bool invertX = currentConfig.invertX;
    bool invertY = currentConfig.invertY;
    final scrollController = ScrollController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E2024),
          title: Text(
            'XY Pad Config (${widget.id})',
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Space Grotesk',
            ),
          ),
          content: Scrollbar(
            controller: scrollController,
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: ccXController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'X Axis CC',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: ccYController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Y Axis CC',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: channelController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'MIDI Channel (0-15)',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: const Text(
                      'Invert X',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: invertX,
                    onChanged: (v) =>
                        setDialogState(() => invertX = v ?? false),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: const Text(
                      'Invert Y',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: invertY,
                    onChanged: (v) =>
                        setDialogState(() => invertY = v ?? false),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'CANCEL',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () {
                final newConfig = XYPadConfig(
                  ccX: int.tryParse(ccXController.text) ?? currentConfig.ccX,
                  ccY: int.tryParse(ccYController.text) ?? currentConfig.ccY,
                  channel:
                      int.tryParse(channelController.text) ??
                      currentConfig.channel,
                  invertX: invertX,
                  invertY: invertY,
                );
                ref
                    .read(xyPadConfigProvider.notifier)
                    .setConfig(widget.id, newConfig);
                Navigator.pop(context);
              },
              child: const Text(
                'SAVE',
                style: TextStyle(color: Color(0xFFA6C9F8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Re-setup listeners if config changes
    ref.listen(xyPadConfigProvider, (prev, next) {
      _setupListeners();
    });

    final config = ref.watch(xyPadConfigProvider)[widget.id];
    final ccX = config?.ccX ?? widget.ccX;
    final ccY = config?.ccY ?? widget.ccY;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return GestureDetector(
          onPanStart: (details) {
            setState(() {
              _isDragging = true;
            });
            _updatePosition(details.localPosition, size, isFinal: false);
          },
          onPanUpdate: (details) {
            _updatePosition(details.localPosition, size, isFinal: false);
          },
          onPanEnd: (details) {
            setState(() {
              _isDragging = false;
            });
            // Send final definitive update
            _sendMidi(isFinal: true);
          },
          onPanCancel: () {
            setState(() {
              _isDragging = false;
            });
            _sendMidi(isFinal: true);
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            decoration: BoxDecoration(
              color: widget.padColor,
              borderRadius: BorderRadius.zero,
              border: Border.all(
                color: _isDragging
                    ? const Color(0xFFA6C9F8)
                    : const Color(0xFF111318).withValues(alpha: 0.5),
                width: _isDragging ? 2.0 : 1.0,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.zero,
              child: Stack(
                children: [
                  // Center guide lines
                  CustomPaint(size: Size.infinite, painter: _XYGridPainter()),
                  // Active crosshairs
                  Positioned(
                    left: _normalizedX * size.width - 0.5,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 1,
                      color: _isDragging
                          ? const Color(0xFFA6C9F8)
                          : const Color(0xFFA6C9F8).withValues(alpha: 0.3),
                    ),
                  ),
                  Positioned(
                    top: _normalizedY * size.height - 0.5,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 1,
                      color: _isDragging
                          ? const Color(0xFFA6C9F8)
                          : const Color(0xFFA6C9F8).withValues(alpha: 0.3),
                    ),
                  ),
                  // Touch Point Marker
                  Positioned(
                    left: (_normalizedX * size.width) - 15,
                    top: (_normalizedY * size.height) - 15,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isDragging
                            ? const Color(0xFFA6C9F8).withValues(alpha: 0.8)
                            : const Color(0xFFA6C9F8).withValues(alpha: 0.4),
                        border: Border.all(
                          color: const Color(0xFFA6C9F8),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  // Live Readouts
                  Positioned(
                    top: 8,
                    right: 8,
                    child: ConfigGestureWrapper(
                      id: '${widget.id}_x_readout',
                      isDragging: _isDragging,
                      onConfigRequested: _showConfigMenu,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 60,
                          minHeight: 60,
                        ),
                        alignment: Alignment.topRight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              (((config?.invertX ?? widget.invertX)
                                          ? (1.0 - _normalizedX)
                                          : _normalizedX) *
                                      127)
                                  .round()
                                  .toString()
                                  .padLeft(3, '0'),
                              style: const TextStyle(
                                fontFamily: 'DSEG7Modern',
                                color: Color(0xFFA6C9F8),
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'X: CC$ccX',
                              style: AppText.performance(
                                color: Colors.white24,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: ConfigGestureWrapper(
                      id: '${widget.id}_y_readout',
                      isDragging: _isDragging,
                      onConfigRequested: _showConfigMenu,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 60,
                          minHeight: 60,
                        ),
                        alignment: Alignment.bottomLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Y: CC$ccY',
                              style: AppText.performance(
                                color: Colors.white24,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              (((config?.invertY ?? widget.invertY)
                                          ? (1.0 - _normalizedY)
                                          : _normalizedY) *
                                      127)
                                  .round()
                                  .toString()
                                  .padLeft(3, '0'),
                              style: const TextStyle(
                                fontFamily: 'DSEG7Modern',
                                color: Color(0xFFA6C9F8),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _XYGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
