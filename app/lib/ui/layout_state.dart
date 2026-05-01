// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/models/layout_models.dart';

// ---------------------------------------------------------------------------
// Page-Specific Override Models
// ---------------------------------------------------------------------------

class UtilityGridConfig {
  final int channel;
  final int cc;

  const UtilityGridConfig({required this.channel, required this.cc});

  Map<String, dynamic> toJson() => {'channel': channel, 'cc': cc};

  factory UtilityGridConfig.fromJson(Map<String, dynamic> json) {
    return UtilityGridConfig(
      channel: json['channel'] as int,
      cc: json['cc'] as int,
    );
  }

  UtilityGridConfig copyWith({int? channel, int? cc}) {
    return UtilityGridConfig(
      channel: channel ?? this.channel,
      cc: cc ?? this.cc,
    );
  }
}

class DrumPadConfig {
  final int note;
  final int channel;

  const DrumPadConfig({required this.note, required this.channel});

  Map<String, dynamic> toJson() => {'note': note, 'channel': channel};

  factory DrumPadConfig.fromJson(Map<String, dynamic> json) {
    return DrumPadConfig(
      note: json['note'] as int,
      channel: json['channel'] as int,
    );
  }

  DrumPadConfig copyWith({int? note, int? channel}) {
    return DrumPadConfig(
      note: note ?? this.note,
      channel: channel ?? this.channel,
    );
  }
}

class XYPadConfig {
  final int ccX;
  final int ccY;
  final int channel;
  final bool invertX;
  final bool invertY;

  const XYPadConfig({
    required this.ccX,
    required this.ccY,
    required this.channel,
    required this.invertX,
    required this.invertY,
  });

  Map<String, dynamic> toJson() => {
    'ccX': ccX,
    'ccY': ccY,
    'channel': channel,
    'invertX': invertX,
    'invertY': invertY,
  };

  factory XYPadConfig.fromJson(Map<String, dynamic> json) {
    return XYPadConfig(
      ccX: json['ccX'] as int,
      ccY: json['ccY'] as int,
      channel: json['channel'] as int,
      invertX: json['invertX'] as bool,
      invertY: json['invertY'] as bool,
    );
  }

  XYPadConfig copyWith({
    int? ccX,
    int? ccY,
    int? channel,
    bool? invertX,
    bool? invertY,
  }) {
    return XYPadConfig(
      ccX: ccX ?? this.ccX,
      ccY: ccY ?? this.ccY,
      channel: channel ?? this.channel,
      invertX: invertX ?? this.invertX,
      invertY: invertY ?? this.invertY,
    );
  }
}

// ---------------------------------------------------------------------------
// Page-Specific Notifiers (Moved from individual files)
// ---------------------------------------------------------------------------

class UtilityGridConfigManager
    extends Notifier<Map<String, UtilityGridConfig>> {
  @override
  Map<String, UtilityGridConfig> build() => const {};

  void setConfig(String id, UtilityGridConfig config) {
    state = {...state, id: config};
  }

  void removeConfig(String id) {
    final newState = Map<String, UtilityGridConfig>.from(state);
    newState.remove(id);
    state = Map.unmodifiable(newState);
  }

  void setAllConfigs(Map<String, UtilityGridConfig> configs) {
    state = Map.unmodifiable(configs);
  }
}

class DrumPadConfigManager extends Notifier<Map<String, DrumPadConfig>> {
  @override
  Map<String, DrumPadConfig> build() => const {};

  void setConfig(String id, DrumPadConfig config) {
    state = {...state, id: config};
  }

  void removeConfig(String id) {
    final newState = Map<String, DrumPadConfig>.from(state);
    newState.remove(id);
    state = Map.unmodifiable(newState);
  }

  void setAllConfigs(Map<String, DrumPadConfig> configs) {
    state = Map.unmodifiable(configs);
  }
}

class XYPadConfigManager extends Notifier<Map<String, XYPadConfig>> {
  @override
  Map<String, XYPadConfig> build() => const {};

  void setConfig(String id, XYPadConfig config) {
    state = {...state, id: config};
  }

  void removeConfig(String id) {
    final newState = Map<String, XYPadConfig>.from(state);
    newState.remove(id);
    state = Map.unmodifiable(newState);
  }

  void setAllConfigs(Map<String, XYPadConfig> configs) {
    state = Map.unmodifiable(configs);
  }
}

final utilityGridConfigProvider =
    NotifierProvider<UtilityGridConfigManager, Map<String, UtilityGridConfig>>(
      UtilityGridConfigManager.new,
    );

final drumPadConfigProvider =
    NotifierProvider<DrumPadConfigManager, Map<String, DrumPadConfig>>(
      DrumPadConfigManager.new,
    );

final xyPadConfigProvider =
    NotifierProvider<XYPadConfigManager, Map<String, XYPadConfig>>(
      XYPadConfigManager.new,
    );

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
          channel: 0,
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
      controls: List.generate(8, (index) {
        return LayoutControl(
          id: 'util_$index',
          type: ControlType.trigger,
          defaultCc: 20 + index,
          channel: 0,
          customName: 'UTIL $index',
        );
      }),
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

  void updateControl(
    String controlId, {
    int? channel,
    int? identifier,
    String? name,
    int? secondaryIdentifier,
    bool? invertX,
    bool? invertY,
  }) {
    // 1. Update Global Layout State
    final updatedPages = state.pages.map((page) {
      final updatedControls = page.controls.map((control) {
        if (control.id == controlId) {
          return control.copyWith(
            channel: channel,
            defaultCc: identifier,
            customName: name,
          );
        }
        return control;
      }).toList();
      return page.copyWith(controls: updatedControls);
    }).toList();
    state = state.copyWith(pages: updatedPages);

    // 2. Update Sub-Providers
    if (controlId.startsWith('util_')) {
      ref
          .read(utilityGridConfigProvider.notifier)
          .setConfig(
            controlId,
            UtilityGridConfig(channel: channel ?? 0, cc: identifier ?? 0),
          );
    } else if (controlId.startsWith('pad_')) {
      ref
          .read(drumPadConfigProvider.notifier)
          .setConfig(
            controlId,
            DrumPadConfig(note: identifier ?? 0, channel: channel ?? 9),
          );
    } else if (controlId == 'xy_main') {
      ref
          .read(xyPadConfigProvider.notifier)
          .setConfig(
            controlId,
            XYPadConfig(
              ccX: identifier ?? 1,
              ccY: secondaryIdentifier ?? 11,
              channel: channel ?? 0,
              invertX: invertX ?? false,
              invertY: invertY ?? true,
            ),
          );
    }
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

    // Wipe overrides
    if (controlId.startsWith('util_')) {
      ref.read(utilityGridConfigProvider.notifier).removeConfig(controlId);
    } else if (controlId.startsWith('pad_')) {
      ref.read(drumPadConfigProvider.notifier).removeConfig(controlId);
    } else if (controlId == 'xy_main') {
      ref.read(xyPadConfigProvider.notifier).removeConfig(controlId);
    }
  }

  void clearControl(String controlId) {
    final updatedPages = state.pages.map((page) {
      final updatedControls = page.controls.map((control) {
        if (control.id == controlId) {
          return control.copyWith(
            defaultCc: -1,
            channel: -1,
            customName: 'Unassigned',
          );
        }
        return control;
      }).toList();
      return page.copyWith(controls: updatedControls);
    }).toList();
    state = state.copyWith(pages: updatedPages);

    // Sync sub-providers to "disabled" state
    if (controlId.startsWith('util_')) {
      ref
          .read(utilityGridConfigProvider.notifier)
          .setConfig(controlId, const UtilityGridConfig(channel: -1, cc: -1));
    } else if (controlId.startsWith('pad_')) {
      ref
          .read(drumPadConfigProvider.notifier)
          .setConfig(controlId, const DrumPadConfig(note: -1, channel: -1));
    } else if (controlId == 'xy_main') {
      ref
          .read(xyPadConfigProvider.notifier)
          .setConfig(
            controlId,
            const XYPadConfig(
              ccX: -1,
              ccY: -1,
              channel: -1,
              invertX: false,
              invertY: false,
            ),
          );
    }
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
