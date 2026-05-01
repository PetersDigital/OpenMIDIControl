// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/ui/open_midi_screen.dart';
import 'package:app/ui/hybrid_touch_fader.dart';
import 'package:app/ui/widgets/hybrid_xy_pad.dart';
import 'package:app/ui/panels/drum_grid_panel.dart';
import 'package:app/ui/panels/utility_grid_panel.dart';
import 'package:app/ui/midi_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

class MockConnectedMidiDeviceNotifier extends ConnectedMidiDeviceNotifier {
  final MidiConnectionState? _mockState;
  MockConnectedMidiDeviceNotifier([this._mockState]);

  @override
  MidiConnectionState build() {
    return _mockState ?? const MidiConnectionState();
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'hasLaunched': true});
  });

  group('OpenMIDIMainScreen Pagination', () {
    Widget buildWidget() {
      return const ProviderScope(
        child: MaterialApp(home: OpenMIDIMainScreen()),
      );
    }

    testWidgets('renders PerformanceZone with IndexedStack initially', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildWidget());

      // Should find IndexedStack
      expect(find.byType(IndexedStack), findsWidgets);

      // Should find Faders initially
      expect(find.byType(HybridTouchFader), findsNWidgets(2));
    });

    testWidgets('tab buttons navigate to XY Pads and Drum Grid', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildWidget());

      // Tap "XY" tab
      await tester.tap(find.text('XY'));
      await tester.pumpAndSettle();

      // Should show XY Pad
      expect(find.byType(HybridXYPad), findsOneWidget);

      // Tap "PADS" tab
      await tester.tap(find.text('PADS'));
      await tester.pumpAndSettle();

      // Should show Drum Grid
      expect(find.byType(DrumGridPanel), findsOneWidget);

      // Tap "UTILITY" tab
      await tester.tap(find.text('UTILITY'));
      await tester.pumpAndSettle();

      // Should show Utility Grid
      expect(find.byType(UtilityGridPanel), findsOneWidget);
    });

    testWidgets('shows DeviceOfflineOverlay when connection is lost', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectedMidiDeviceProvider.overrideWith(
              () => MockConnectedMidiDeviceNotifier(
                const MidiConnectionState(isConnectionLost: true),
              ),
            ),
          ],
          child: const MaterialApp(home: OpenMIDIMainScreen()),
        ),
      );

      await tester.pump();

      // Should find the overlay
      expect(find.byType(DeviceOfflineOverlay), findsOneWidget);
      expect(find.text('DEVICE OFFLINE'), findsOneWidget);
      expect(find.text('OPEN MIDI SETTINGS'), findsOneWidget);
    });
  });
}
