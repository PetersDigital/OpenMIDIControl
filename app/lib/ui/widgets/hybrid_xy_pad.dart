// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../midi_service.dart';

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

class _HybridXYPadState extends ConsumerState<HybridXYPad> {
  bool _isDragging = false;
  double _normalizedX = 0.5;
  double _normalizedY = 0.5;

  Timer? _throttleTimer;
  bool _canSend = true;
  bool _hasPendingSend = false;

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

  @override
  void dispose() {
    _throttleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              borderRadius: BorderRadius.circular(12),
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
              borderRadius: BorderRadius.circular(12),
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
                  // Labels
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Text(
                      'X: CC$ccX',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Text(
                      'Y: CC$ccY',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
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
