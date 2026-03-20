import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HybridTouchFader extends ConsumerStatefulWidget {
  final int ccNumber;
  final String label;
  final Color activeColor;
  final double initialValue; // 0.0 to 1.0

  const HybridTouchFader({
    Key? key,
    required this.ccNumber,
    required this.label,
    required this.activeColor,
    this.initialValue = 0.0,
  }) : super(key: key);

  @override
  ConsumerState<HybridTouchFader> createState() => _HybridTouchFaderState();
}

class _HybridTouchFaderState extends ConsumerState<HybridTouchFader> {
  late double _currentValue;
  final double _faderResolution = 400.0; // Pixels for a full 0-1 sweep

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      // Moving UP is negative Y in Flutter, so we subtract
      double change = -(details.delta.dy / _faderResolution);
      _currentValue = (_currentValue + change).clamp(0.0, 1.0);
    });

    // TODO for Jules: Wire this to the Riverpod Notifier to send to Kotlin MIDI Bridge
    // ref.read(midiProvider.notifier).sendCC(widget.ccNumber, _currentValue);
  }

  @override
  Widget build(BuildContext context) {
    int midiValue = (_currentValue * 127).round();

    return GestureDetector(
      onVerticalDragUpdate: _handleDragUpdate,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0C0E12), // surface-container-lowest
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // --- THE SOLID FILL RIBBON ---
            FractionallySizedBox(
              heightFactor: _currentValue,
              widthFactor: 1.0,
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.activeColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            // --- BOTTOM ANCHORED GLASSMORPHISM READOUT ---
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C0E12).withOpacity(0.4),
                    border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.label,
                        style: TextStyle(
                          color: widget.activeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        midiValue.toString().padLeft(3, '0'),
                        style: const TextStyle(
                          fontFamily: 'DSEG7Modern',
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
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
    );
  }
}
