// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:app/core/models/layout_models.dart';
import 'package:app/ui/global_ui_scale_state.dart';
import 'package:app/ui/hybrid_touch_fader.dart';
import 'package:app/ui/layout_state.dart';
import 'package:app/ui/midi_service.dart';
import 'package:app/ui/open_midi_screen.dart';
import 'package:app/ui/widgets/hybrid_xy_pad.dart';
import 'package:app/ui/widgets/performance_grid_viewport.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingMidiService extends MidiService {
  final lastValues = <int, int>{};

  @override
  Future<void> sendCC(
    int cc,
    int value, {
    int channel = 0,
    bool isFinal = false,
  }) async {
    lastValues[cc] = value;
  }
}

class _TestLayout extends LayoutStateNotifier {
  @override
  LayoutState build() => LayoutState(
    pages: [
      LayoutPage(
        id: 'test',
        type: PageType.utility,
        name: 'TEST',
        gridColumns: 2,
        gridRows: 1,
        controls: [
          LayoutControl(
            id: 'fader',
            type: ControlType.fader,
            defaultCc: 1,
            channel: 0,
          ),
          LayoutControl(
            id: 'xy',
            type: ControlType.xyPad,
            defaultCc: 2,
            secondaryCc: 3,
            channel: 0,
            x: 1,
          ),
        ],
      ),
    ],
    activePageIndex: 0,
    isPerformanceLocked: false,
  );
}

Offset _point(Rect rect, double x, double y) =>
    rect.topLeft + Offset(rect.width * x, rect.height * y);

void main() {
  testWidgets(
    'fader and XY output agree across scale and pan with two touches',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final midi = _RecordingMidiService();
      final container = ProviderContainer.test(
        overrides: [
          layoutStateProvider.overrideWith(_TestLayout.new),
          midiServiceProvider.overrideWithValue(midi),
        ],
      );
      await container.read(globalUiScaleProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: PerformanceZone())),
        ),
      );

      final fader = find.byType(HybridTouchFader);
      final xy = find.byType(HybridXYPad);
      final viewport = find.byType(PerformanceGridViewport);
      final unscaledFader = tester.getRect(fader);
      final tab = tester.getTopLeft(find.text('TEST'));

      Future<void> exerciseControls() async {
        midi.lastValues.clear();
        final faderRect = tester.getRect(fader);
        final xyRect = tester.getRect(xy);
        final faderTouch = await tester.startGesture(
          _point(faderRect, 0.6, 0.43),
        );
        final xyTouch = await tester.startGesture(_point(xyRect, 0.30, 0.22));
        await faderTouch.moveTo(_point(faderRect, 0.6, 0.50));
        await xyTouch.moveTo(_point(xyRect, 0.37, 0.29));
        await faderTouch.moveTo(_point(faderRect, 0.6, 0.55));
        await xyTouch.moveTo(_point(xyRect, 0.43, 0.40));
        await faderTouch.up();
        await xyTouch.up();
        await tester.pump(const Duration(milliseconds: 20));
        expect(midi.lastValues, {1: 57, 2: 55, 3: 51});
      }

      await exerciseControls();
      await container.read(globalUiScaleProvider.notifier).setScale(0.75);
      await tester.pump();
      expect(
        tester.getRect(fader).width,
        closeTo(unscaledFader.width * 0.75, 0.01),
      );
      expect(tester.getTopLeft(find.text('TEST')), tab);
      expect(find.byTooltip('Pan grid'), findsNothing);
      await exerciseControls();

      await container.read(globalUiScaleProvider.notifier).setScale(1.35);
      await tester.pump();
      final zoomedFader = tester.getRect(fader);
      expect(zoomedFader.width, closeTo(unscaledFader.width * 1.35, 0.01));
      expect(tester.getTopLeft(find.text('TEST')), tab);
      await exerciseControls();

      final hold = await tester.startGesture(_point(zoomedFader, 0.6, 0.43));
      midi.lastValues.clear();
      await tester.tap(find.byTooltip('Pan grid'));
      await tester.pump();
      await tester.drag(viewport, const Offset(-120, -110));
      await tester.pump();
      expect(tester.getRect(fader), zoomedFader);
      await hold.cancel();

      midi.lastValues.clear();
      await tester.drag(viewport, const Offset(-120, -110));
      await tester.pump();
      expect(midi.lastValues, isEmpty);
      expect(tester.getTopLeft(fader).dx, lessThan(zoomedFader.left));
      expect(tester.getTopLeft(fader).dy, lessThan(zoomedFader.top));
      await tester.tap(find.byTooltip('Finish panning'));
      await tester.pump();
      await exerciseControls();

      await tester.tap(find.byTooltip('Pan grid'));
      await tester.pump();
      await tester.drag(viewport, const Offset(-1000, -1000));
      await tester.pump();
      expect(
        tester.getBottomRight(xy).dx,
        lessThan(tester.getRect(viewport).right),
      );
      expect(
        tester.getBottomRight(fader).dy,
        closeTo(tester.getRect(viewport).bottom, 0.01),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
