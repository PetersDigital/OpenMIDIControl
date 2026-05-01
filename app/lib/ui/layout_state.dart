// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/models/layout_models.dart';

/// State object for the layout engine.
/// Tracks pages, active page index, and performance lock state.
class LayoutState {
  final List<LayoutPage> pages;
  final int activePageIndex;
  final bool isPerformanceLocked;

  LayoutState({
    required this.pages,
    required this.activePageIndex,
    required this.isPerformanceLocked,
  }) : assert(activePageIndex >= 0, 'Page index cannot be negative'),
       assert(activePageIndex < pages.length, 'Page index out of bounds');

  /// Create a copy with optional field overrides.
  LayoutState copyWith({
    List<LayoutPage>? pages,
    int? activePageIndex,
    bool? isPerformanceLocked,
  }) {
    return LayoutState(
      pages: pages ?? this.pages,
      activePageIndex: activePageIndex ?? this.activePageIndex,
      isPerformanceLocked: isPerformanceLocked ?? this.isPerformanceLocked,
    );
  }

  /// Get the currently active page.
  LayoutPage get activePage => pages[activePageIndex];

  @override
  String toString() =>
      'LayoutState(pages: ${pages.length}, activePage: $activePageIndex, locked: $isPerformanceLocked)';
}

/// Notifier for the layout state.
/// Provides mutations and initialization of layout pages.
class LayoutStateNotifier extends Notifier<LayoutState> {
  @override
  LayoutState build() {
    return LayoutState(
      pages: _buildDefaultPages(),
      activePageIndex: 0,
      isPerformanceLocked: false,
    );
  }

  /// Build the 4 default pages matching legacy tabs.
  static List<LayoutPage> _buildDefaultPages() {
    return [
      _buildFaderPage(),
      _buildXyPage(),
      _buildPadsPage(),
      _buildUtilityPage(),
    ];
  }

  /// Page 0: FADER (8 faders)
  static LayoutPage _buildFaderPage() {
    return LayoutPage(
      id: 'page_0',
      name: 'FADER',
      controls: [
        LayoutControl(
          id: 'fader_0',
          type: ControlType.fader,
          defaultCc: 1,
          channel: 0,
          customName: 'CC1\nDYNAMICS',
        ),
        LayoutControl(
          id: 'fader_1',
          type: ControlType.fader,
          defaultCc: 11,
          channel: 0,
          customName: 'CC11\nEXPRESSION',
        ),
        LayoutControl(
          id: 'fader_2',
          type: ControlType.fader,
          defaultCc: 7,
          channel: 0,
          customName: 'CC7\nVOLUME',
        ),
        LayoutControl(
          id: 'fader_3',
          type: ControlType.fader,
          defaultCc: 10,
          channel: 0,
          customName: 'CC10\nPAN',
        ),
        LayoutControl(
          id: 'fader_4',
          type: ControlType.fader,
          defaultCc: 12,
          channel: 0,
          customName: 'CC12\nCUSTOM1',
        ),
        LayoutControl(
          id: 'fader_5',
          type: ControlType.fader,
          defaultCc: 13,
          channel: 0,
          customName: 'CC13\nCUSTOM2',
        ),
        LayoutControl(
          id: 'fader_6',
          type: ControlType.fader,
          defaultCc: 14,
          channel: 0,
          customName: 'CC14\nCUSTOM3',
        ),
        LayoutControl(
          id: 'fader_7',
          type: ControlType.fader,
          defaultCc: 15,
          channel: 0,
          customName: 'CC15\nCUSTOM4',
        ),
      ],
    );
  }

  /// Page 1: XY (1 XY pad with dual-axis control)
  static LayoutPage _buildXyPage() {
    return LayoutPage(
      id: 'page_1',
      name: 'XY',
      controls: [
        LayoutControl(
          id: 'xy_main',
          type: ControlType.xyPad,
          defaultCc: 1, // X-axis
          channel: 0,
          customName: 'XY PAD',
        ),
        // Note: The Y-axis is typically CC 11, but represented as a single control
      ],
    );
  }

  /// Page 2: PADS (8 drum pads, channel 9, notes 36-43)
  static LayoutPage _buildPadsPage() {
    return LayoutPage(
      id: 'page_2',
      name: 'PADS',
      controls: [
        LayoutControl(
          id: 'drum_pad_0',
          type: ControlType.drumPad,
          defaultCc: 36, // Kick
          channel: 9,
          customName: 'KICK 1',
        ),
        LayoutControl(
          id: 'drum_pad_1',
          type: ControlType.drumPad,
          defaultCc: 37, // Snare 1
          channel: 9,
          customName: 'SNARE 1',
        ),
        LayoutControl(
          id: 'drum_pad_2',
          type: ControlType.drumPad,
          defaultCc: 38, // Snare 2
          channel: 9,
          customName: 'SNARE 2',
        ),
        LayoutControl(
          id: 'drum_pad_3',
          type: ControlType.drumPad,
          defaultCc: 39, // Clap
          channel: 9,
          customName: 'CLAP',
        ),
        LayoutControl(
          id: 'drum_pad_4',
          type: ControlType.drumPad,
          defaultCc: 40, // Snare 3
          channel: 9,
          customName: 'SNARE 3',
        ),
        LayoutControl(
          id: 'drum_pad_5',
          type: ControlType.drumPad,
          defaultCc: 41, // Tom 1
          channel: 9,
          customName: 'TOM 1',
        ),
        LayoutControl(
          id: 'drum_pad_6',
          type: ControlType.drumPad,
          defaultCc: 42, // Hat Closed
          channel: 9,
          customName: 'HAT C',
        ),
        LayoutControl(
          id: 'drum_pad_7',
          type: ControlType.drumPad,
          defaultCc: 43, // Tom 2
          channel: 9,
          customName: 'TOM 2',
        ),
      ],
    );
  }

  /// Page 3: UTILITY (4 encoders + 4 toggles + 4 trigger)
  static LayoutPage _buildUtilityPage() {
    return LayoutPage(
      id: 'page_3',
      name: 'UTILITY',
      controls: [
        // Encoders (Row 0 & 1)
        LayoutControl(
          id: 'encoder_0',
          type: ControlType.encoder,
          defaultCc: 20,
          channel: 0,
          customName: 'ENC 1',
        ),
        LayoutControl(
          id: 'encoder_1',
          type: ControlType.encoder,
          defaultCc: 21,
          channel: 0,
          customName: 'ENC 2',
        ),
        LayoutControl(
          id: 'encoder_2',
          type: ControlType.encoder,
          defaultCc: 22,
          channel: 0,
          customName: 'ENC 3',
        ),
        LayoutControl(
          id: 'encoder_3',
          type: ControlType.encoder,
          defaultCc: 23,
          channel: 0,
          customName: 'ENC 4',
        ),
        // Toggle Buttons (Row 2 & 3)
        LayoutControl(
          id: 'toggle_0',
          type: ControlType.toggle,
          defaultCc: 24,
          channel: 0,
          customName: 'TOGGLE 1',
        ),
        LayoutControl(
          id: 'toggle_1',
          type: ControlType.toggle,
          defaultCc: 25,
          channel: 0,
          customName: 'TOGGLE 2',
        ),
        LayoutControl(
          id: 'toggle_2',
          type: ControlType.toggle,
          defaultCc: 26,
          channel: 0,
          customName: 'TOGGLE 3',
        ),
        LayoutControl(
          id: 'toggle_3',
          type: ControlType.toggle,
          defaultCc: 27,
          channel: 0,
          customName: 'TOGGLE 4',
        ),
        // Trigger Buttons (Row 4 & 5)
        LayoutControl(
          id: 'trigger_0',
          type: ControlType.trigger,
          defaultCc: 28,
          channel: 0,
          customName: 'TRIG 1',
        ),
        LayoutControl(
          id: 'trigger_1',
          type: ControlType.trigger,
          defaultCc: 29,
          channel: 0,
          customName: 'TRIG 2',
        ),
        LayoutControl(
          id: 'trigger_2',
          type: ControlType.trigger,
          defaultCc: 30,
          channel: 0,
          customName: 'TRIG 3',
        ),
        LayoutControl(
          id: 'trigger_3',
          type: ControlType.trigger,
          defaultCc: 31,
          channel: 0,
          customName: 'TRIG 4',
        ),
      ],
    );
  }

  /// Set the active page by index.
  void setPageIndex(int index) {
    if (index >= 0 && index < state.pages.length) {
      state = state.copyWith(activePageIndex: index);
    }
  }

  /// Update the custom name of a control by ID.
  /// Searches through all pages to find the control.
  void updateControlLabel(String controlId, String label) {
    final updatedPages = state.pages.map((page) {
      final controlIndex = page.controls.indexWhere(
        (control) => control.id == controlId,
      );
      if (controlIndex != -1) {
        final updatedControls = [...page.controls];
        updatedControls[controlIndex] = updatedControls[controlIndex].copyWith(
          customName: label,
        );
        return page.copyWith(controls: updatedControls);
      }
      return page;
    }).toList();

    state = state.copyWith(pages: updatedPages);
  }

  /// Replace the active page with an imported page while preserving
  /// the original page id to avoid routing/index breakage.
  void overwriteActivePage(LayoutPage importedPage) {
    final index = state.activePageIndex;
    if (index < 0 || index >= state.pages.length) return;

    final existingPage = state.pages[index];
    final mergedPage = importedPage.copyWith(id: existingPage.id);
    final updatedPages = [...state.pages];
    updatedPages[index] = mergedPage;

    state = state.copyWith(pages: updatedPages);
  }

  /// Toggle the performance lock state.
  void togglePerformanceLock() {
    state = state.copyWith(isPerformanceLocked: !state.isPerformanceLocked);
  }

  /// Set performance lock to a specific state.
  void setPerformanceLock(bool locked) {
    state = state.copyWith(isPerformanceLocked: locked);
  }

  /// Apply a drum pad layout preset (MPC or Ableton).
  void applyDrumPreset(String preset) {
    const padsPageIndex = 2;
    if (padsPageIndex >= state.pages.length) return;

    final existingPage = state.pages[padsPageIndex];
    final updatedControls = [...existingPage.controls];

    if (preset == 'MPC') {
      // MPC: Bottom-to-top chromatic
      // Row 3 (Bottom): 36, 37
      // Row 2: 38, 39
      // Row 1: 40, 41
      // Row 0 (Top): 42, 43
      final notes = [42, 43, 40, 41, 38, 39, 36, 37];
      final names = [
        'HAT C',
        'TOM 2',
        'SNARE 3',
        'TOM 1',
        'SNARE 2',
        'CLAP',
        'KICK 1',
        'SNARE 1',
      ];

      for (int i = 0; i < updatedControls.length && i < notes.length; i++) {
        updatedControls[i] = updatedControls[i].copyWith(
          defaultCc: notes[i],
          customName: names[i],
        );
      }
    } else if (preset == 'Ableton') {
      // Ableton: Top-to-bottom linear chromatic (Legacy)
      final notes = [36, 37, 38, 39, 40, 41, 42, 43];
      final names = [
        'KICK 1',
        'SNARE 1',
        'SNARE 2',
        'CLAP',
        'SNARE 3',
        'TOM 1',
        'HAT C',
        'TOM 2',
      ];

      for (int i = 0; i < updatedControls.length && i < notes.length; i++) {
        updatedControls[i] = updatedControls[i].copyWith(
          defaultCc: notes[i],
          customName: names[i],
        );
      }
    }

    final updatedPages = [...state.pages];
    updatedPages[padsPageIndex] = existingPage.copyWith(
      controls: updatedControls,
    );

    state = state.copyWith(pages: updatedPages);
  }

  /// Reset a specific control on a specific page to its factory default.
  void resetControlToDefault(int pageIndex, int controlIndex) {
    if (pageIndex < 0 || pageIndex >= state.pages.length) return;

    final defaultPages = _buildDefaultPages();
    final defaultPage = defaultPages[pageIndex];
    if (controlIndex < 0 || controlIndex >= defaultPage.controls.length) return;

    final defaultControl = defaultPage.controls[controlIndex];

    final updatedPages = [...state.pages];
    final pageToUpdate = updatedPages[pageIndex];
    final updatedControls = [...pageToUpdate.controls];
    updatedControls[controlIndex] = defaultControl;

    updatedPages[pageIndex] = pageToUpdate.copyWith(controls: updatedControls);
    state = state.copyWith(pages: updatedPages);
  }

  /// Clear (unbind) a specific control on a specific page.
  void clearControl(int pageIndex, int controlIndex) {
    if (pageIndex < 0 || pageIndex >= state.pages.length) return;

    final updatedPages = [...state.pages];
    final pageToUpdate = updatedPages[pageIndex];
    final updatedControls = [...pageToUpdate.controls];

    if (controlIndex < 0 || controlIndex >= updatedControls.length) return;

    updatedControls[controlIndex] = updatedControls[controlIndex].copyWith(
      defaultCc: -1,
      channel: -1,
      customName: 'Unassigned',
    );

    updatedPages[pageIndex] = pageToUpdate.copyWith(controls: updatedControls);
    state = state.copyWith(pages: updatedPages);
  }
}

/// Global Riverpod provider for layout state.
final layoutStateProvider = NotifierProvider<LayoutStateNotifier, LayoutState>(
  LayoutStateNotifier.new,
);
