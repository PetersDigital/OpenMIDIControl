// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/ui/open_midi_screen.dart';
import 'package:app/ui/hybrid_touch_fader.dart';
import 'package:app/ui/widgets/hybrid_xy_pad.dart';
import 'package:app/ui/widgets/velocity_drum_pad.dart';
import 'package:app/ui/widgets/endless_encoder.dart';
import 'package:app/ui/widgets/midi_buttons.dart';
import 'package:app/ui/midi_service.dart';
import 'package:app/ui/midi_settings_screen.dart';
import 'package:app/ui/layout_state.dart';
import 'package:app/ui/widgets/editor_control_wrapper.dart';
import 'package:app/core/models/layout_models.dart';

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
    Widget buildWidget({MidiConnectionState? midiState}) {
      return ProviderScope(
        overrides: [
          if (midiState != null)
            connectedMidiDeviceProvider.overrideWith(
              () => MockConnectedMidiDeviceNotifier(midiState),
            ),
          firstLaunchCheckProvider.overrideWith((ref) => Future.value(false)),
        ],
        child: const MaterialApp(home: OpenMIDIMainScreen()),
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

      // Should show individual Drum Pads instead of DrumGridPanel now
      expect(find.byType(VelocityDrumPad), findsWidgets);

      // Tap "UTILITY" tab
      await tester.tap(find.text('UTILITY'));
      await tester.pumpAndSettle();

      // Should show individual Utility widgets instead of UtilityGridPanel now
      expect(find.byType(EndlessEncoderWidget), findsWidgets);
      expect(find.byType(Trigger), findsWidgets);
      expect(find.byType(Toggle), findsWidgets);
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
      expect(find.text('RESET PORTS'), findsOneWidget);
      expect(find.text('DISMISS'), findsOneWidget);
    });

    testWidgets('landscape mode shows SidePanel when settings triggered', (
      WidgetTester tester,
    ) async {
      // Set to landscape
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildWidget());
      // Let the post-frame callback run to expand the island
      await tester.pump();
      // Wait for the animation to actually expand
      await tester.pumpAndSettle();

      // Open MIDI Settings via the dynamic connection island
      await tester.tap(find.byKey(const ValueKey('connection_status_island')));
      // Wait for the overlay animation to complete
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify SidePanel is visible
      expect(find.byType(MidiSettingsScreen), findsOneWidget);

      // Tap the scrim to dismiss
      await tester.tap(find.byKey(const ValueKey('side_panel_scrim')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(MidiSettingsScreen), findsNothing);
    });

    testWidgets('dynamic island expands on double-tap and hold', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildWidget());
      // Wait for initial expansion to finish AND for it to collapse after 3s
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Now it should be collapsed.
      final Finder island = find.byKey(
        const ValueKey('connection_status_island'),
      );
      final initialWidth = tester.getSize(island).width;
      expect(initialWidth, lessThan(40)); // Collapsed width should be ~36

      final center = tester.getCenter(island);

      // Perform Double-Tap and Hold
      // Tap 1
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 100));

      // Tap 2 and Hold
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 100));
      // Hold for 1.2 seconds (default safety hold is 1s)
      await tester.pump(const Duration(milliseconds: 1200));
      await gesture.up();
      await tester.pumpAndSettle();

      // Check if it's expanded.
      final expandedWidth = tester.getSize(island).width;
      expect(expandedWidth, greaterThan(initialWidth + 50));
    });

    testWidgets('dynamic island opens settings on tap when expanded', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildWidget());
      // Let it expand initially
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // It should be expanded now.
      final island = find.byKey(const ValueKey('connection_status_island'));

      // Tap it
      await tester.tap(island);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should show settings
      expect(find.byType(MidiSettingsScreen), findsOneWidget);
    });

    testWidgets('tab bar becomes scrollable when there are > 4 pages', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(layoutStateProvider.notifier);

      // Add 2 more custom pages to make total = 6 pages
      notifier.addPage(PageType.fader, 'Custom Fader');
      notifier.addPage(PageType.xyPad, 'Custom XY');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: OpenMIDIMainScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Find SingleChildScrollView in tab bar
      expect(
        find.descendant(
          of: find.byType(PerformanceZone),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
    });

    testWidgets('layout editor mode wraps controls and handles selection', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      // Initially, no control wrappers should be present
      expect(find.byType(EditorControlWrapper), findsNothing);

      // Tap the Toggle Editor Mode button
      await tester.tap(find.byTooltip('Toggle Editor Mode').first);
      await tester.pumpAndSettle();

      // Now, control wrappers should be present wrapping the faders
      expect(find.byType(EditorControlWrapper), findsWidgets);

      // Verify that no control is selected initially
      expect(find.byIcon(Icons.zoom_out_map), findsNothing);

      // Tap on the first fader to select it
      await tester.tap(
        find.byType(HybridTouchFader).first,
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      // Now, the selected fader should show the resize handle
      expect(find.byIcon(Icons.zoom_out_map), findsOneWidget);
    });
  });
}
