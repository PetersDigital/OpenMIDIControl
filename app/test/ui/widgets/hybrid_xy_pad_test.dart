// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/models/action_payload.dart';
import 'package:app/core/models/layout_models.dart';
import 'package:app/ui/layout_state.dart';
import 'package:app/ui/midi_service.dart';
import 'package:app/ui/widgets/hybrid_xy_pad.dart';

class FakeMidiService implements MidiService {
  int? lastCcX;
  int? lastValX;
  int? lastCcY;
  int? lastValY;
  int? lastChannel;
  final ccs = <(int, int)>[];
  final pitchBends = <(int, int, bool)>[];
  final notes = <(int, int, bool)>[];

  @override
  Future<void> sendCC(
    int cc,
    int value, {
    int channel = 0,
    bool isFinal = false,
  }) async {
    ccs.add((channel, cc));
    lastChannel = channel;
    if (cc == 1) {
      lastCcX = cc;
      lastValX = value;
    } else if (cc == 2) {
      lastCcY = cc;
      lastValY = value;
    }
  }

  @override
  Future<void> sendPitchBend(
    int value, {
    required int channel,
    bool isFinal = false,
  }) async {
    pitchBends.add((channel, value, isFinal));
  }

  @override
  Future<void> sendNoteOn(
    int note,
    int velocity, {
    int channel = 9,
    bool isFinal = false,
  }) async {
    notes.add((channel, note, true));
  }

  @override
  Future<void> sendNoteOff(
    int note, {
    int channel = 9,
    bool isFinal = false,
  }) async {
    notes.add((channel, note, false));
  }

  @override
  Stream<Map<String, dynamic>> get uiStateUpdates => const Stream.empty();

  @override
  Map<String, dynamic> get currentState => {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestLayoutState extends LayoutStateNotifier {
  final LayoutControl control;

  _TestLayoutState(this.control);

  @override
  LayoutState build() => LayoutState(
    activePageIndex: 0,
    isPerformanceLocked: false,
    pages: [
      LayoutPage(
        id: 'xy',
        type: PageType.xyPad,
        name: 'XY',
        controls: [control],
      ),
    ],
  );
}

void main() {
  group('HybridXYPad', () {
    late FakeMidiService fakeMidiService;

    setUp(() {
      fakeMidiService = FakeMidiService();
    });

    Widget createWidgetUnderTest({
      bool invertX = false,
      bool invertY = true,
      LayoutControl? control,
    }) {
      return ProviderScope(
        overrides: [
          midiServiceProvider.overrideWithValue(fakeMidiService),
          if (control != null)
            layoutStateProvider.overrideWith(() => _TestLayoutState(control)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: HybridXYPad(
                  id: "test_xy",
                  ccX: 1,
                  ccY: 2,
                  channel: 0,
                  invertX: invertX,
                  invertY: invertY,
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders initial labels correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text('X: CC1'), findsOneWidget);
      expect(find.text('Y: CC2'), findsOneWidget);
    });

    testWidgets('resolves the legacy Y mapping from the layout', (
      tester,
    ) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          control: LayoutControl(
            id: 'test_xy',
            type: ControlType.xyPad,
            defaultCc: 1,
            channel: 4,
          ),
        ),
      );
      expect(find.text('Y: CC11'), findsOneWidget);

      final pad = find.byType(HybridXYPad);
      await tester.drag(pad, const Offset(30, 30));
      await tester.pump(const Duration(milliseconds: 20));
      expect(fakeMidiService.ccs, contains((4, 11)));
      expect(fakeMidiService.ccs, isNot(contains((4, 2))));
    });

    testWidgets(
      'shows both axes as unassigned when the layout has no channel',
      (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            control: LayoutControl(
              id: 'test_xy',
              type: ControlType.xyPad,
              defaultCc: -1,
              channel: -1,
            ),
          ),
        );
        expect(find.text('X: UNASSIGNED'), findsOneWidget);
        expect(find.text('Y: UNASSIGNED'), findsOneWidget);

        await tester.drag(find.byType(HybridXYPad), const Offset(30, 30));
        await tester.pump(const Duration(milliseconds: 20));
        expect(fakeMidiService.ccs, isEmpty);
      },
    );

    testWidgets('maps coordinates to CC values correctly without inversion', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createWidgetUnderTest(invertX: false, invertY: false),
      );

      final padFinder = find.byType(HybridXYPad);

      final gesture = await tester.createGesture();
      // Down at (50, 150) inside the 200x200 pad.
      // Expected normalized: X = 50/200 = 0.25, Y = 150/200 = 0.75
      // Values (0-127): X = 0.25 * 127 = 32, Y = 0.75 * 127 = 95
      await gesture.down(tester.getTopLeft(padFinder) + const Offset(50, 150));
      await tester.pump();

      expect(fakeMidiService.lastCcX, 1);
      expect(fakeMidiService.lastValX, 32);
      expect(fakeMidiService.lastCcY, 2);
      expect(fakeMidiService.lastValY, 95);

      await gesture.up();
    });

    testWidgets('maps coordinates to CC values correctly with inversion', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createWidgetUnderTest(invertX: true, invertY: true),
      );

      final padFinder = find.byType(HybridXYPad);

      final gesture = await tester.createGesture();
      // Down at (50, 150).
      // Expected normalized: X = 0.25, Y = 0.75
      // With inversion: effectiveX = 0.75, effectiveY = 0.25
      // Values (0-127): X = 0.75 * 127 = 95, Y = 0.25 * 127 = 32
      await gesture.down(tester.getTopLeft(padFinder) + const Offset(50, 150));
      await tester.pump();

      expect(fakeMidiService.lastValX, 95);
      expect(fakeMidiService.lastValY, 32);

      await gesture.up();
    });

    testWidgets('clamps values between 0 and 127 when dragging outside', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createWidgetUnderTest(invertX: false, invertY: false),
      );

      final padFinder = find.byType(HybridXYPad);

      final gesture = await tester.createGesture();
      await gesture.down(tester.getCenter(padFinder));
      await tester.pump();

      // Move completely out of bounds (negative)
      await gesture.moveTo(tester.getTopLeft(padFinder) - const Offset(50, 50));
      await tester.pump(
        const Duration(milliseconds: 20),
      ); // Ensure throttle window passes

      expect(fakeMidiService.lastValX, 0);
      expect(fakeMidiService.lastValY, 0);

      // Move completely out of bounds (positive)
      await gesture.moveTo(
        tester.getBottomRight(padFinder) + const Offset(50, 50),
      );
      await tester.pump(const Duration(milliseconds: 20));

      expect(fakeMidiService.lastValX, 127);
      expect(fakeMidiService.lastValY, 127);

      await gesture.up();
    });

    testWidgets(
      'dispatches independent typed actions and releases the held note',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            control: LayoutControl(
              id: 'test_xy',
              type: ControlType.xyPad,
              defaultCc: 1,
              secondaryCc: 2,
              channel: 0,
              payload: const PitchBendPayload(channel: 4),
              secondaryPayload: const NotePayload(channel: 9, note: 36),
            ),
          ),
        );
        final pad = find.byType(HybridXYPad);
        final gesture = await tester.startGesture(tester.getCenter(pad));
        await gesture.moveBy(const Offset(40, 10));
        await tester.pump(const Duration(milliseconds: 16));
        await gesture.moveTo(tester.getBottomRight(pad));
        await tester.pump(const Duration(milliseconds: 16));
        await gesture.up();

        expect(fakeMidiService.pitchBends.last, (4, 16383, true));
        expect(fakeMidiService.notes, [(9, 36, true), (9, 36, false)]);
        expect(fakeMidiService.lastChannel, isNull);
        await tester.pump(const Duration(milliseconds: 20));
      },
    );
  });
}
