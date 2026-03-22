import 'package:flutter/material.dart';

import 'open_midi_screen.dart'; // For FaderBehavior type

// Common CC options for the popup menu
const List<Map<String, dynamic>> _kCCOptions = [
  {'cc': 1, 'name': 'Modulation'},
  {'cc': 2, 'name': 'Breath'},
  {'cc': 7, 'name': 'Volume'},
  {'cc': 10, 'name': 'Pan'},
  {'cc': 11, 'name': 'Expression'},
  {'cc': 64, 'name': 'Sustain'},
  {'cc': 71, 'name': 'Resonance'},
  {'cc': 74, 'name': 'Brightness'},
];

class HybridTouchFader extends StatefulWidget {
  final int ccNumber;
  final String label;
  final Color activeColor;
  final Color labelColor;
  final double initialValue;
  final bool isMobile;
  final FaderBehavior behavior;

  const HybridTouchFader({
    super.key,
    required this.ccNumber,
    required this.label,
    required this.activeColor,
    required this.labelColor,
    this.initialValue = 0.0,
    this.isMobile = true,
    this.behavior = FaderBehavior.jump,
  });

  @override
  State<HybridTouchFader> createState() => _HybridTouchFaderState();
}

class _HybridTouchFaderState extends State<HybridTouchFader> {
  late double _currentValue;
  late int _ccNumber;
  late String _ccLabel;

  // State for catchUp behavior
  bool _isCatchingUp = false;
  bool _mustCrossMovingUp = false;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue.clamp(0.0, 1.0);
    _ccNumber = widget.ccNumber;
    _ccLabel = widget.label;
  }

  void _handleDragDown(DragDownDetails details, BoxConstraints constraints) {
    if (widget.behavior == FaderBehavior.jump) {
      _applyAbsolutePosition(details.localPosition.dy, constraints.maxHeight);
      return;
    }

    if (widget.behavior == FaderBehavior.catchUp) {
      final handleY = (1.0 - _currentValue) * constraints.maxHeight;
      final touchY = details.localPosition.dy;
      
      // If we touch almost exactly on the handle line (within 20 pixels), grab immediately
      if ((touchY - handleY).abs() < 20.0) {
        _isCatchingUp = false;
        _applyAbsolutePosition(touchY, constraints.maxHeight);
      } else {
        _isCatchingUp = true;
        // If touch is physically lower on screen (higher Y value), we must drag UP (decreasing Y) to cross
        _mustCrossMovingUp = touchY > handleY;
      }
    }
  }

  void _handleDragUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (widget.behavior == FaderBehavior.hybrid) {
      setState(() {
        _currentValue = (_currentValue - (details.delta.dy / constraints.maxHeight)).clamp(0.0, 1.0);
      });
      return;
    }

    if (widget.behavior == FaderBehavior.catchUp && _isCatchingUp) {
      final handleY = (1.0 - _currentValue) * constraints.maxHeight;
      final touchY = details.localPosition.dy;

      bool crossed = false;
      if (_mustCrossMovingUp && touchY <= handleY) crossed = true;
      if (!_mustCrossMovingUp && touchY >= handleY) crossed = true;

      if (crossed) {
        _isCatchingUp = false;
      } else {
        return; // Waiting to cross the threshold, ignore this interaction
      }
    }

    // Standard Jump response
    _applyAbsolutePosition(details.localPosition.dy, constraints.maxHeight);
  }

  void _applyAbsolutePosition(double localY, double maxHeight) {
    setState(() {
      _currentValue = (1.0 - (localY / maxHeight)).clamp(0.0, 1.0);
    });
  }

  void _showCCMenu(BuildContext context, Offset offset) async {
    final selected = await showMenu<Map<String, dynamic>>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy,
        offset.dx + 1,
        offset.dy + 1,
      ),
      color: const Color(0xFF1E2024),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      items: _kCCOptions.map((option) {
        final isSelected = option['cc'] == _ccNumber;
        return PopupMenuItem<Map<String, dynamic>>(
          value: option,
          child: Text(
            'CC${option['cc']} – ${option['name']}',
            style: TextStyle(
              fontFamily: 'Inter',
              color: isSelected ? const Color(0xFFA6C9F8) : Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
    );
    if (selected != null) {
      setState(() {
        _ccNumber = selected['cc'] as int;
        _ccLabel =
            'CC${selected['cc']}\n${(selected['name'] as String).toUpperCase()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final int ccValue = (_currentValue * 127).round();
    final double labelFontSize = widget.isMobile ? 14.0 : 18.0;
    final double displayFontSize = widget.isMobile ? 40.0 : 60.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onVerticalDragUpdate: (d) => _handleDragUpdate(d, constraints),
          onPanDown: (d) => _handleDragDown(d, constraints),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xFF111318),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Filled active track
                FractionallySizedBox(
                  heightFactor: _currentValue,
                  widthFactor: 1.0,
                  alignment: Alignment.bottomCenter,
                  child: Container(color: widget.activeColor),
                ),

                // Full-width TM1637 Display pinned at top with visible gap
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Black readout box — full width, top-padded
                      IgnorePointer(
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
                          color: const Color(0xFF0C0E12),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Ghost segments — very faint
                              Text(
                                "888",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'DSEG7Modern',
                                  fontSize: displayFontSize,
                                  color: Colors.red.withValues(alpha: 0.06),
                                  height: 1.0,
                                ),
                              ),
                              // Active value
                              Text(
                                ccValue.toString().padLeft(3, ' '),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'DSEG7Modern',
                                  fontSize: displayFontSize,
                                  color: Colors.red,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // CC Name Label (long-press to open CC picker)
                      const SizedBox(height: 8),
                      Builder(
                        builder: (labelContext) => GestureDetector(
                          onLongPressStart: (details) {
                            _showCCMenu(context, details.globalPosition);
                          },
                          behavior: HitTestBehavior.translucent,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 4.0,
                            ),
                            child: Text(
                              _ccLabel,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: Colors.white,
                                fontSize: labelFontSize,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                                // No text shadow — easier to read as requested
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
