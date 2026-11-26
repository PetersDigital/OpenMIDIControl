// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:app/core/models/widget_style.dart';
import 'package:app/ui/layout_state.dart';
import 'package:app/ui/widgets/control_config_modal.dart';

void main() {
  group('ControlConfigModal Appearance controls', () {
    testWidgets(
      'persists curated swatch, font, and visibility toggles, and clears back to default',
      (WidgetTester tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) =>
                          const ControlConfigModal(controlId: 'fader_0'),
                    ),
                    child: const Text('Open Modal'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettle();

        expect(find.text('APPEARANCE'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('style_color_default')),
          findsOneWidget,
        );
        for (final swatch in WidgetStyle.curatedPalette) {
          expect(
            find.byKey(ValueKey('style_color_${swatch.hex}')),
            findsOneWidget,
          );
        }

        // Select Warm Amber (#E9C46A), DSEG7Modern, and hide label/readout.
        final amberSwatch = find.byKey(const ValueKey('style_color_#E9C46A'));
        await tester.ensureVisible(amberSwatch);
        await tester.tap(amberSwatch);
        await tester.pump();

        final fontDropdown = find.byKey(const ValueKey('style_font_dropdown'));
        await tester.ensureVisible(fontDropdown);
        await tester.tap(fontDropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text('DSEG7Modern').last);
        await tester.pumpAndSettle();

        final showLabelBox = find.byKey(const ValueKey('style_show_label'));
        await tester.ensureVisible(showLabelBox);
        await tester.tap(showLabelBox);

        final showReadoutBox = find.byKey(
          const ValueKey('style_show_numeric_readout'),
        );
        await tester.ensureVisible(showReadoutBox);
        await tester.tap(showReadoutBox);
        await tester.pump();

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        final updated = container
            .read(layoutStateProvider)
            .getControlById('fader_0')!;
        expect(
          updated.style,
          const WidgetStyle(
            accentColorHex: '#E9C46A',
            fontFamily: 'DSEG7Modern',
            showLabel: false,
            showNumericReadout: false,
          ),
        );

        // Re-open modal -> hydrates saved style, then reset to default -> clears style to null.
        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<CheckboxListTile>(
                find.byKey(const ValueKey('style_show_label')),
              )
              .value,
          isFalse,
        );
        expect(
          tester
              .widget<CheckboxListTile>(
                find.byKey(const ValueKey('style_show_numeric_readout')),
              )
              .value,
          isFalse,
        );

        final defaultSwatch = find.byKey(const ValueKey('style_color_default'));
        await tester.ensureVisible(defaultSwatch);
        await tester.tap(defaultSwatch);

        await tester.ensureVisible(
          find.byKey(const ValueKey('style_font_dropdown')),
        );
        await tester.tap(find.byKey(const ValueKey('style_font_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Default').last);
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(const ValueKey('style_show_label')),
        );
        await tester.tap(find.byKey(const ValueKey('style_show_label')));
        await tester.ensureVisible(
          find.byKey(const ValueKey('style_show_numeric_readout')),
        );
        await tester.tap(
          find.byKey(const ValueKey('style_show_numeric_readout')),
        );
        await tester.pump();

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(
          container.read(layoutStateProvider).getControlById('fader_0')!.style,
          isNull,
        );
      },
    );
  });
}
