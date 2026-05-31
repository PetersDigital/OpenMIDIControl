// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/models/layout_models.dart';

// All control state is now managed directly within LayoutState using the expanded LayoutControl model.
// This removes the need for page-specific override providers and complex synchronization logic.

// ---------------------------------------------------------------------------
// Layout State
// ---------------------------------------------------------------------------

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

  LayoutPage get activePage => pages[activePageIndex];

  LayoutControl? getControlById(String id) {
    for (final page in pages) {
      for (final control in page.controls) {
        if (control.id == id) return control;
      }
    }
    return null;
  }
}

class LayoutStateNotifier extends Notifier<LayoutState> {
  @override
  LayoutState build() {
    return LayoutState(
      pages: _buildDefaultPages(),
      activePageIndex: 0,
      isPerformanceLocked: false,
    );
  }

  static List<LayoutPage> _buildDefaultPages() {
    return [
      _buildFaderPage(),
      _buildXyPage(),
      _buildPadsPage(),
      _buildUtilityPage(),
    ];
  }

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

  static LayoutPage _buildXyPage() {
    return LayoutPage(
      id: 'page_1',
      name: 'XY',
      controls: [
        LayoutControl(
          id: 'xy_main',
          type: ControlType.xyPad,
          defaultCc: 1, // X-axis
          secondaryCc: 11, // Y-axis
          channel: 0,
          invertY:
              true, // Default to true for standard DAW behavior (bottom=0, top=127)
          customName: 'XY PAD',
        ),
      ],
    );
  }

  static LayoutPage _buildPadsPage() {
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
    return LayoutPage(
      id: 'page_2',
      name: 'PADS',
      controls: List.generate(8, (index) {
        return LayoutControl(
          id: 'pad_$index',
          type: ControlType.drumPad,
          defaultCc: 36 + index,
          channel: 9,
          customName: names[index],
        );
      }),
    );
  }

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

  void togglePerformanceLock() {
    state = state.copyWith(isPerformanceLocked: !state.isPerformanceLocked);
  }

  void setPageIndex(int index) {
    state = state.copyWith(activePageIndex: index);
  }

  void updateControlLabel(String controlId, String label) {
    final updatedPages = state.pages.map((page) {
      final updatedControls = page.controls.map((control) {
        if (control.id == controlId) {
          return control.copyWith(customName: label);
        }
        return control;
      }).toList();
      return page.copyWith(controls: updatedControls);
    }).toList();
    state = state.copyWith(pages: updatedPages);
  }

  void overwriteActivePage(LayoutPage newPage) {
    final updatedPages = [...state.pages];
    updatedPages[state.activePageIndex] = newPage;
    state = state.copyWith(pages: updatedPages);
  }

  void overwriteAllPages(List<LayoutPage> pages) {
    if (pages.isEmpty) return;
    state = state.copyWith(pages: pages, activePageIndex: 0);
  }

  void updateControl(
    String controlId, {
    int? channel,
    int? identifier,
    String? name,
    int? secondaryIdentifier,
    bool? invertX,
    bool? invertY,
  }) {
    final updatedPages = state.pages.map((page) {
      final updatedControls = page.controls.map((control) {
        if (control.id == controlId) {
          return control.copyWith(
            channel: channel,
            defaultCc: identifier,
            customName: name,
            secondaryCc: secondaryIdentifier,
            invertX: invertX,
            invertY: invertY,
          );
        }
        return control;
      }).toList();
      return page.copyWith(controls: updatedControls);
    }).toList();
    state = state.copyWith(pages: updatedPages);
  }

  void resetControl(String controlId) {
    final defaultPages = _buildDefaultPages();
    LayoutControl? defaultControl;
    int pageIdx = -1;
    int controlIdx = -1;

    for (int p = 0; p < defaultPages.length; p++) {
      final idx = defaultPages[p].controls.indexWhere((c) => c.id == controlId);
      if (idx != -1) {
        defaultControl = defaultPages[p].controls[idx];
        pageIdx = p;
        controlIdx = idx;
        break;
      }
    }

    if (defaultControl == null) return;

    final updatedPages = [...state.pages];
    final updatedControls = [...updatedPages[pageIdx].controls];
    updatedControls[controlIdx] = defaultControl;
    updatedPages[pageIdx] = updatedPages[pageIdx].copyWith(
      controls: updatedControls,
    );
    state = state.copyWith(pages: updatedPages);
  }

  void resetPage(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= state.pages.length) return;
    final defaultPages = _buildDefaultPages();
    final defaultPage = defaultPages[pageIndex];

    final updatedPages = [...state.pages];
    updatedPages[pageIndex] = defaultPage;
    state = state.copyWith(pages: updatedPages);
  }

  void clearPage(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= state.pages.length) return;
    final page = state.pages[pageIndex];
    final updatedControls = page.controls.map((control) {
      return control.copyWith(
        defaultCc: -1,
        secondaryCc: -1,
        channel: -1,
        customName: 'Unassigned',
        invertX: false,
        invertY: false,
      );
    }).toList();

    final updatedPages = [...state.pages];
    updatedPages[pageIndex] = page.copyWith(controls: updatedControls);
    state = state.copyWith(pages: updatedPages);
  }

  void clearControl(String controlId) {
    final updatedPages = state.pages.map((page) {
      final updatedControls = page.controls.map((control) {
        if (control.id == controlId) {
          return control.copyWith(
            defaultCc: -1,
            secondaryCc: -1,
            channel: -1,
            customName: 'Unassigned',
            invertX: false,
            invertY: false,
          );
        }
        return control;
      }).toList();
      return page.copyWith(controls: updatedControls);
    }).toList();
    state = state.copyWith(pages: updatedPages);
  }

  void applyDrumPreset(String preset) {
    final padsPageIndex = 2;
    if (padsPageIndex >= state.pages.length) return;

    final existingPage = state.pages[padsPageIndex];
    final updatedControls = [...existingPage.controls];

    if (preset == 'MPC') {
      final notes = [37, 36, 42, 82, 40, 38, 46, 44];
      final names = [
        'SIDE STICK',
        'KICK',
        'HI-HAT C',
        'SHAKER',
        'SNARE 2',
        'SNARE 1',
        'HI-HAT O',
        'HI-HAT P',
      ];
      for (int i = 0; i < updatedControls.length && i < notes.length; i++) {
        updatedControls[i] = updatedControls[i].copyWith(
          defaultCc: notes[i],
          customName: names[i],
        );
      }
    } else if (preset == 'Ableton') {
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
}

final layoutStateProvider = NotifierProvider<LayoutStateNotifier, LayoutState>(
  LayoutStateNotifier.new,
);
