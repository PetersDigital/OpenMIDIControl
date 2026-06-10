// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/models/layout_models.dart';
import 'dart:math' as math;

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
  }) : assert(
         pages.isEmpty ? activePageIndex == 0 : activePageIndex >= 0,
         'Page index cannot be negative',
       ),
       assert(
         pages.isEmpty ? activePageIndex == 0 : activePageIndex < pages.length,
         'Page index out of bounds',
       );

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

  LayoutPage? get activePage => pages.isEmpty ? null : pages[activePageIndex];

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

  LayoutPage _buildBlankPage(PageType type, String name) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = math.Random().nextInt(1000000);
    final pageId = 'page_${timestamp}_$randomSuffix';
    final List<LayoutControl> controls = [];
    int gridColumns = 8;
    int gridRows = 4;

    switch (type) {
      case PageType.fader:
        gridColumns = 8;
        gridRows = 4;
        for (int i = 0; i < 2; i++) {
          controls.add(
            LayoutControl(
              id: 'fader_${timestamp}_${randomSuffix}_$i',
              type: ControlType.fader,
              defaultCc: -1,
              channel: -1,
              customName: 'UNASSIGNED',
              x: i * 4,
              y: 0,
              width: 4,
              height: 4,
            ),
          );
        }
        break;
      case PageType.xyPad:
        gridColumns = 8;
        gridRows = 4;
        controls.add(
          LayoutControl(
            id: 'xy_main_${timestamp}_$randomSuffix',
            type: ControlType.xyPad,
            defaultCc: -1,
            secondaryCc: -1,
            channel: -1,
            invertY: true,
            customName: 'UNASSIGNED',
            x: 0,
            y: 0,
            width: 8,
            height: 4,
          ),
        );
        break;
      case PageType.drumPad:
        gridColumns = 8;
        gridRows = 4;
        for (int i = 0; i < 8; i++) {
          final int col = i % 2;
          final int row = i ~/ 2;
          controls.add(
            LayoutControl(
              id: 'pad_${timestamp}_${randomSuffix}_$i',
              type: ControlType.drumPad,
              defaultCc: -1,
              channel: -1,
              customName: 'UNASSIGNED',
              x: col * 4,
              y: row,
              width: 4,
              height: 1,
            ),
          );
        }
        break;
      case PageType.utility:
        gridColumns = 8;
        gridRows = 6;
        // Encoders
        for (int i = 0; i < 4; i++) {
          final int col = i % 2;
          final int row = i ~/ 2;
          controls.add(
            LayoutControl(
              id: 'encoder_${timestamp}_${randomSuffix}_$i',
              type: ControlType.encoder,
              defaultCc: -1,
              channel: -1,
              customName: 'UNASSIGNED',
              x: col * 4,
              y: row,
              width: 4,
              height: 1,
            ),
          );
        }
        // Toggles
        for (int i = 0; i < 4; i++) {
          final int col = i % 2;
          final int row = i ~/ 2;
          controls.add(
            LayoutControl(
              id: 'toggle_${timestamp}_${randomSuffix}_$i',
              type: ControlType.toggle,
              defaultCc: -1,
              channel: -1,
              customName: 'UNASSIGNED',
              x: col * 4,
              y: 2 + row,
              width: 4,
              height: 1,
            ),
          );
        }
        // Triggers
        for (int i = 0; i < 4; i++) {
          final int col = i % 2;
          final int row = i ~/ 2;
          controls.add(
            LayoutControl(
              id: 'trigger_${timestamp}_${randomSuffix}_$i',
              type: ControlType.trigger,
              defaultCc: -1,
              channel: -1,
              customName: 'UNASSIGNED',
              x: col * 4,
              y: 4 + row,
              width: 4,
              height: 1,
            ),
          );
        }
        break;
    }

    return LayoutPage(
      id: pageId,
      type: type,
      name: name,
      controls: controls,
      gridColumns: gridColumns,
      gridRows: gridRows,
    );
  }

  static LayoutPage _buildFaderPage() {
    return LayoutPage(
      id: 'page_0',
      type: PageType.fader,
      name: 'FADER',
      gridColumns: 8,
      gridRows: 4,
      controls: [
        LayoutControl(
          id: 'fader_0',
          type: ControlType.fader,
          defaultCc: 1,
          channel: 0,
          customName: 'CC1\nDYNAMICS',
          x: 0,
          y: 0,
          width: 4,
          height: 4,
        ),
        LayoutControl(
          id: 'fader_1',
          type: ControlType.fader,
          defaultCc: 11,
          channel: 0,
          customName: 'CC11\nEXPRESSION',
          x: 4,
          y: 0,
          width: 4,
          height: 4,
        ),
      ],
    );
  }

  static LayoutPage _buildXyPage() {
    return LayoutPage(
      id: 'page_1',
      type: PageType.xyPad,
      name: 'XY',
      gridColumns: 8,
      gridRows: 4,
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
          x: 0,
          y: 0,
          width: 8,
          height: 4,
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
      type: PageType.drumPad,
      name: 'PADS',
      gridColumns: 8,
      gridRows: 4,
      controls: List.generate(8, (index) {
        final int col = index % 2;
        final int row = index ~/ 2;
        return LayoutControl(
          id: 'pad_$index',
          type: ControlType.drumPad,
          defaultCc: 36 + index,
          channel: 9,
          customName: names[index],
          x: col * 4,
          y: row,
          width: 4,
          height: 1,
        );
      }),
    );
  }

  static LayoutPage _buildUtilityPage() {
    return LayoutPage(
      id: 'page_3',
      type: PageType.utility,
      name: 'UTILITY',
      gridColumns: 8,
      gridRows: 6,
      controls: [
        // Encoders (Row 0 & 1)
        LayoutControl(
          id: 'encoder_0',
          type: ControlType.encoder,
          defaultCc: 20,
          channel: 0,
          customName: 'ENC 1',
          x: 0,
          y: 0,
          width: 4,
          height: 1,
        ),
        LayoutControl(
          id: 'encoder_1',
          type: ControlType.encoder,
          defaultCc: 21,
          channel: 0,
          customName: 'ENC 2',
          x: 4,
          y: 0,
          width: 4,
          height: 1,
        ),
        LayoutControl(
          id: 'encoder_2',
          type: ControlType.encoder,
          defaultCc: 22,
          channel: 0,
          customName: 'ENC 3',
          x: 0,
          y: 1,
          width: 4,
          height: 1,
        ),
        LayoutControl(
          id: 'encoder_3',
          type: ControlType.encoder,
          defaultCc: 23,
          channel: 0,
          customName: 'ENC 4',
          x: 4,
          y: 1,
          width: 4,
          height: 1,
        ),
        // Toggle Buttons (Row 2 & 3)
        LayoutControl(
          id: 'toggle_0',
          type: ControlType.toggle,
          defaultCc: 24,
          channel: 0,
          customName: 'TOGGLE 1',
          x: 0,
          y: 2,
          width: 4,
          height: 1,
        ),
        LayoutControl(
          id: 'toggle_1',
          type: ControlType.toggle,
          defaultCc: 25,
          channel: 0,
          customName: 'TOGGLE 2',
          x: 4,
          y: 2,
          width: 4,
          height: 1,
        ),
        LayoutControl(
          id: 'toggle_2',
          type: ControlType.toggle,
          defaultCc: 26,
          channel: 0,
          customName: 'TOGGLE 3',
          x: 0,
          y: 3,
          width: 4,
          height: 1,
        ),
        LayoutControl(
          id: 'toggle_3',
          type: ControlType.toggle,
          defaultCc: 27,
          channel: 0,
          customName: 'TOGGLE 4',
          x: 4,
          y: 3,
          width: 4,
          height: 1,
        ),
        // Trigger Buttons (Row 4 & 5)
        LayoutControl(
          id: 'trigger_0',
          type: ControlType.trigger,
          defaultCc: 28,
          channel: 0,
          customName: 'TRIG 1',
          x: 0,
          y: 4,
          width: 4,
          height: 1,
        ),
        LayoutControl(
          id: 'trigger_1',
          type: ControlType.trigger,
          defaultCc: 29,
          channel: 0,
          customName: 'TRIG 2',
          x: 4,
          y: 4,
          width: 4,
          height: 1,
        ),
        LayoutControl(
          id: 'trigger_2',
          type: ControlType.trigger,
          defaultCc: 30,
          channel: 0,
          customName: 'TRIG 3',
          x: 0,
          y: 5,
          width: 4,
          height: 1,
        ),
        LayoutControl(
          id: 'trigger_3',
          type: ControlType.trigger,
          defaultCc: 31,
          channel: 0,
          customName: 'TRIG 4',
          x: 4,
          y: 5,
          width: 4,
          height: 1,
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
    if (state.pages.isEmpty) return;
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

  void resetPage(String pageId) {
    final pageIndex = state.pages.indexWhere((p) => p.id == pageId);
    if (pageIndex == -1) return;

    LayoutPage defaultPage;
    if (pageId == 'page_0') {
      defaultPage = _buildFaderPage();
    } else if (pageId == 'page_1') {
      defaultPage = _buildXyPage();
    } else if (pageId == 'page_2') {
      defaultPage = _buildPadsPage();
    } else if (pageId == 'page_3') {
      defaultPage = _buildUtilityPage();
    } else {
      // For custom pages, reset is equivalent to clear
      clearPage(pageId);
      return;
    }

    final updatedPages = [...state.pages];
    updatedPages[pageIndex] = defaultPage;
    state = state.copyWith(pages: updatedPages);
  }

  void updatePageGridAndName(
    String pageId, {
    String? name,
    int? gridColumns,
    int? gridRows,
  }) {
    final pageIndex = state.pages.indexWhere((p) => p.id == pageId);
    if (pageIndex == -1) return;

    final page = state.pages[pageIndex];
    final int newCols = gridColumns ?? page.gridColumns;
    final int newRows = gridRows ?? page.gridRows;

    // Adjust controls to fit within the new grid dimensions
    final updatedControls = page.controls.map((control) {
      int newWidth = math.min(newCols, control.width);
      int newHeight = math.min(newRows, control.height);
      int newX = math.max(0, math.min(newCols - newWidth, control.x));
      int newY = math.max(0, math.min(newRows - newHeight, control.y));
      return control.copyWith(
        x: newX,
        y: newY,
        width: newWidth,
        height: newHeight,
      );
    }).toList();

    final updatedPages = [...state.pages];
    updatedPages[pageIndex] = page.copyWith(
      name: name ?? page.name,
      gridColumns: newCols,
      gridRows: newRows,
      controls: updatedControls,
    );
    state = state.copyWith(pages: updatedPages);
  }

  void updateControlSpatialData(
    String pageId,
    String controlId, {
    int? x,
    int? y,
    int? width,
    int? height,
  }) {
    final pageIndex = state.pages.indexWhere((p) => p.id == pageId);
    if (pageIndex == -1) return;

    final page = state.pages[pageIndex];
    final controlIndex = page.controls.indexWhere((c) => c.id == controlId);
    if (controlIndex == -1) return;

    final control = page.controls[controlIndex];

    // Constrain logic to page grid
    int newX = x ?? control.x;
    int newY = y ?? control.y;
    int newWidth = width ?? control.width;
    int newHeight = height ?? control.height;

    // Minimum size is 1x1
    newWidth = math.max(1, newWidth);
    newHeight = math.max(1, newHeight);

    // Max size is page grid dimensions
    newWidth = math.min(page.gridColumns, newWidth);
    newHeight = math.min(page.gridRows, newHeight);

    // Clamp coordinates to grid boundaries while taking width/height into account
    newX = math.max(0, math.min(page.gridColumns - newWidth, newX));
    newY = math.max(0, math.min(page.gridRows - newHeight, newY));

    final updatedControl = control.copyWith(
      x: newX,
      y: newY,
      width: newWidth,
      height: newHeight,
    );

    final updatedControls = [...page.controls];
    updatedControls[controlIndex] = updatedControl;

    final updatedPages = [...state.pages];
    updatedPages[pageIndex] = page.copyWith(controls: updatedControls);

    state = state.copyWith(pages: updatedPages);
  }

  void addControlToActivePage(ControlType type, {int? x, int? y}) {
    if (state.pages.isEmpty) return;

    final pageIndex = state.activePageIndex;
    final page = state.pages[pageIndex];

    int defaultWidth = 1;
    int defaultHeight = 1;

    switch (type) {
      case ControlType.fader:
        defaultWidth = 1;
        defaultHeight = 3;
        break;
      case ControlType.xyPad:
        defaultWidth = 2;
        defaultHeight = 2;
        break;
      case ControlType.drumPad:
      case ControlType.encoder:
      case ControlType.trigger:
      case ControlType.toggle:
        defaultWidth = 1;
        defaultHeight = 1;
        break;
    }

    int startX = x ?? 0;
    int startY = y ?? 0;

    // Find the first available empty grid cell if x and y are not provided
    if (x == null || y == null) {
      bool found = false;
      for (int r = 0; r <= page.gridRows - defaultHeight && !found; r++) {
        for (int c = 0; c <= page.gridColumns - defaultWidth && !found; c++) {
          bool overlaps = false;
          for (final control in page.controls) {
            // Check intersection
            if (c < control.x + control.width &&
                c + defaultWidth > control.x &&
                r < control.y + control.height &&
                r + defaultHeight > control.y) {
              overlaps = true;
              break;
            }
          }
          if (!overlaps) {
            startX = c;
            startY = r;
            found = true;
          }
        }
      }

      // If no space is found, just overlap at 0,0 (or clamp it)
      if (!found) {
        startX = 0;
        startY = 0;
      }
    }

    // Clamp coordinates to grid boundaries while taking width/height into account
    startX = math.max(0, math.min(page.gridColumns - defaultWidth, startX));
    startY = math.max(0, math.min(page.gridRows - defaultHeight, startY));

    final newControl = LayoutControl(
      id: '${type.name}_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      defaultCc: -1,
      channel: -1,
      x: startX,
      y: startY,
      width: defaultWidth,
      height: defaultHeight,
    );

    final updatedControls = [...page.controls, newControl];
    final updatedPages = [...state.pages];
    updatedPages[pageIndex] = page.copyWith(controls: updatedControls);

    state = state.copyWith(pages: updatedPages);
  }

  void clearPage(String pageId) {
    final pageIndex = state.pages.indexWhere((p) => p.id == pageId);
    if (pageIndex == -1) return;
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

  void addPage(PageType type, String name) {
    final newPage = _buildBlankPage(type, name);
    final updatedPages = [...state.pages, newPage];
    state = state.copyWith(
      pages: updatedPages,
      activePageIndex: updatedPages.length - 1,
    );
  }

  LayoutPage? removePage(int index) {
    if (index < 0 || index >= state.pages.length) return null;

    final updatedPages = [...state.pages];
    final removedPage = updatedPages.removeAt(index);

    int newActiveIndex = 0;
    if (updatedPages.isNotEmpty) {
      if (state.activePageIndex == index) {
        newActiveIndex = (index >= updatedPages.length)
            ? updatedPages.length - 1
            : index;
      } else if (state.activePageIndex > index) {
        newActiveIndex = state.activePageIndex - 1;
      } else {
        newActiveIndex = state.activePageIndex;
      }
    }

    state = state.copyWith(
      pages: updatedPages,
      activePageIndex: newActiveIndex,
    );

    return removedPage;
  }

  void restorePage(int index, LayoutPage page) {
    final updatedPages = [...state.pages];

    // Clamp the index safely
    int safeIndex = index;
    if (safeIndex < 0) safeIndex = 0;
    if (safeIndex > updatedPages.length) safeIndex = updatedPages.length;

    updatedPages.insert(safeIndex, page);

    // Set activePageIndex to the newly restored index for immediate visual feedback
    state = state.copyWith(pages: updatedPages, activePageIndex: safeIndex);
  }

  void reorderPages(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.pages.length) return;
    if (newIndex < 0 || newIndex >= state.pages.length) return;

    // If the item was dropped back to its original position, do nothing.
    if (oldIndex == newIndex) return;

    final updatedPages = [...state.pages];
    final page = updatedPages.removeAt(oldIndex);
    updatedPages.insert(newIndex, page);

    int newActiveIndex = state.activePageIndex;
    if (state.activePageIndex == oldIndex) {
      newActiveIndex = newIndex;
    } else if (state.activePageIndex > oldIndex &&
        state.activePageIndex <= newIndex) {
      newActiveIndex = state.activePageIndex - 1;
    } else if (state.activePageIndex < oldIndex &&
        state.activePageIndex >= newIndex) {
      newActiveIndex = state.activePageIndex + 1;
    }

    state = state.copyWith(
      pages: updatedPages,
      activePageIndex: newActiveIndex,
    );
  }

  void applyDrumPreset(String pageId, String preset) {
    final pageIndex = state.pages.indexWhere((p) => p.id == pageId);
    if (pageIndex == -1) return;

    final existingPage = state.pages[pageIndex];
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
    updatedPages[pageIndex] = existingPage.copyWith(controls: updatedControls);
    state = state.copyWith(pages: updatedPages);
  }

  void resetToDefault() {
    state = LayoutState(
      pages: _buildDefaultPages(),
      activePageIndex: 0,
      isPerformanceLocked: false,
    );
  }
}

final layoutStateProvider = NotifierProvider<LayoutStateNotifier, LayoutState>(
  LayoutStateNotifier.new,
);
