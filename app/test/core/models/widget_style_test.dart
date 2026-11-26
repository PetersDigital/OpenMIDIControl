// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/models/layout_models.dart';
import 'package:app/core/models/widget_style.dart';

void main() {
  group('WidgetStyle model & serialization', () {
    test(
      'curatedPalette has 12 unique valid hex swatches and supported fonts',
      () {
        expect(WidgetStyle.curatedPalette.length, 12);
        final hexes = WidgetStyle.curatedPalette.map((s) => s.hex).toSet();
        expect(hexes.length, 12);
        for (final swatch in WidgetStyle.curatedPalette) {
          expect(WidgetStyle.normalizeHex(swatch.hex), swatch.hex);
          expect(
            WidgetStyle(accentColorHex: swatch.hex).accentColorValue,
            swatch.colorValue,
          );
        }
        expect(WidgetStyle.supportedFonts, [
          'Inter',
          'Space Grotesk',
          'DSEG7Modern',
        ]);
      },
    );

    test('validates hex and fontFamily cleanly on copyWith and fromJson', () {
      const style = WidgetStyle(
        accentColorHex: '#E9C46A',
        fontFamily: 'Inter',
        showLabel: false,
        showNumericReadout: false,
      );
      final roundTrip = WidgetStyle.fromJson(style.toJson());
      expect(roundTrip, style);
      expect(style.accentColorValue, 0xFFE9C46A);
      expect(style.isDefault, isFalse);

      expect(WidgetStyle.normalizeHex(' a6c9f8 '), '#A6C9F8');
      expect(
        () => WidgetStyle.fromJson({'accentColorHex': '#ZZZZZZ'}),
        throwsFormatException,
      );
      expect(
        () => WidgetStyle.fromJson({'fontFamily': 'Comic Sans MS'}),
        throwsFormatException,
      );

      final cleared = style.copyWith(
        clearAccentColor: true,
        clearFontFamily: true,
        showLabel: true,
        showNumericReadout: true,
      );
      expect(cleared.isDefault, isTrue);
      expect(cleared.toJson(), isEmpty);
    });

    test(
      'LayoutControl omits default style in JSON and round-trips custom style',
      () {
        final base = LayoutControl(
          id: 'fader_styled',
          type: ControlType.fader,
          defaultCc: 1,
          channel: 0,
        );
        expect(base.effectiveStyle, WidgetStyle.defaults);
        expect(base.toJson().containsKey('style'), isFalse);

        final customStyle = const WidgetStyle(
          accentColorHex: '#CE93D8',
          fontFamily: 'DSEG7Modern',
          showLabel: false,
          showNumericReadout: true,
        );
        final styled = base.copyWith(style: customStyle);
        final json = styled.toJson();
        expect(json['style'], customStyle.toJson());
        expect(LayoutControl.fromJson(json), styled);

        final reset = styled.copyWith(clearStyle: true);
        expect(reset.style, isNull);
        expect(reset.effectiveStyle, WidgetStyle.defaults);
      },
    );
  });
}
