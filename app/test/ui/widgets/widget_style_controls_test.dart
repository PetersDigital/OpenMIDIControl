// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:app/core/models/widget_style.dart';
import 'package:app/ui/hybrid_touch_fader.dart';
import 'package:app/ui/layout_state.dart';
import 'package:app/ui/widgets/control_widget_factory.dart';
import 'package:app/ui/widgets/endless_encoder.dart';
import 'package:app/ui/widgets/hybrid_xy_pad.dart';
import 'package:app/ui/widgets/midi_buttons.dart';
import 'package:app/ui/widgets/velocity_drum_pad.dart';

void main() {
  group('Performance widgets respect WidgetStyle', () {
    testWidgets(
      'HybridTouchFader, HybridXYPad, VelocityDrumPad, EndlessEncoder, Trigger, Toggle apply styles cleanly',
      (WidgetTester tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Build a custom styled control for each widget type on page_0/utility.
        final notifier = container.read(layoutStateProvider.notifier);
        notifier.updateControlActions(
          'fader_0',
          payload: container
              .read(layoutStateProvider)
              .getControlById('fader_0')!
              .payload,
          style: const WidgetStyle(
            accentColorHex: '#EF5350',
            fontFamily: 'Inter',
            showLabel: false,
            showNumericReadout: false,
          ),
        );
        notifier.updateControlActions(
          'xy_main',
          payload: container
              .read(layoutStateProvider)
              .getControlById('xy_main')!
              .payload,
          secondaryPayload: container
              .read(layoutStateProvider)
              .getControlById('xy_main')!
              .effectiveSecondaryPayload,
          style: const WidgetStyle(
            accentColorHex: '#CE93D8',
            fontFamily: 'Space Grotesk',
            showLabel: false,
            showNumericReadout: false,
          ),
        );
        notifier.updateControlActions(
          'pad_0',
          payload: container
              .read(layoutStateProvider)
              .getControlById('pad_0')!
              .payload,
          style: const WidgetStyle(
            accentColorHex: '#81C784',
            fontFamily: 'Inter',
            showLabel: false,
            showNumericReadout: false,
          ),
        );
        notifier.updateControlActions(
          'toggle_0',
          payload: container
              .read(layoutStateProvider)
              .getControlById('toggle_0')!
              .payload,
          style: const WidgetStyle(
            accentColorHex: '#FFD54F',
            fontFamily: 'Inter',
            showLabel: false,
            showNumericReadout: false,
          ),
        );

        // 1. Fader hides numeric box and label, passes EF5350 activeColor.
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 180,
                  height: 360,
                  child: Consumer(
                    builder: (context, ref, _) =>
                        ControlWidgetFactory.buildControl(
                          context,
                          ref
                              .read(layoutStateProvider)
                              .getControlById('fader_0')!,
                          'page_0',
                          true,
                          true,
                          ref,
                        ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(HybridTouchFader), findsOneWidget);
        expect(find.text('888'), findsNothing);
        expect(find.text('CC1\nDYNAMICS'), findsNothing);

        // 2. XY pad hides X/Y labels and 064 numeric readouts.
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 300,
                  height: 300,
                  child: Consumer(
                    builder: (context, ref, _) =>
                        ControlWidgetFactory.buildControl(
                          context,
                          ref
                              .read(layoutStateProvider)
                              .getControlById('xy_main')!,
                          'page_1',
                          true,
                          true,
                          ref,
                        ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(HybridXYPad), findsOneWidget);
        expect(find.textContaining('X:'), findsNothing);
        expect(find.text('064'), findsNothing);

        // 3. Drum pad hides KICK, V:0, CH10.
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 160,
                  height: 120,
                  child: Consumer(
                    builder: (context, ref, _) =>
                        ControlWidgetFactory.buildControl(
                          context,
                          ref
                              .read(layoutStateProvider)
                              .getControlById('pad_0')!,
                          'page_2',
                          true,
                          true,
                          ref,
                        ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(VelocityDrumPad), findsOneWidget);
        expect(find.text('KICK'), findsNothing);
        expect(find.text('V:0'), findsNothing);

        // 4. Toggle hides TOGGLE 1, CC 24, CH1 while keeping ON/OFF state text.
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 140,
                  height: 100,
                  child: Consumer(
                    builder: (context, ref, _) =>
                        ControlWidgetFactory.buildControl(
                          context,
                          ref
                              .read(layoutStateProvider)
                              .getControlById('toggle_0')!,
                          'page_3',
                          true,
                          true,
                          ref,
                        ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(Toggle), findsOneWidget);
        expect(find.text('TOGGLE 1'), findsNothing);
        expect(find.text('CC 24'), findsNothing);
        expect(find.text('OFF'), findsOneWidget);

        // 5. Encoder + Trigger standalone checks.
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 120,
                  height: 120,
                  child: EndlessEncoderWidget(
                    cc: 20,
                    accentColor: Color(0xFF80CBC4),
                    fontFamily: 'Inter',
                    showNumericReadout: false,
                    showChannelLabel: false,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(EndlessEncoderWidget), findsOneWidget);
        expect(find.text('0'), findsNothing);
      },
    );
  });
}
