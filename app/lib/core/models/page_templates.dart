// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:math' as math;

import 'action_payload.dart';
import 'layout_models.dart';

/// Identifiers for built-in factory page templates.
enum PageTemplateId {
  factoryFaderBank,
  drumGrid4x4,
  xyAndEncoders,
  mixerStub8Track,
  mcuMixer8Track,
}

/// Immutable blueprint for a single control inside a [PageTemplate].
class TemplateControlSpec {
  final String idPrefix;
  final ControlType type;
  final int defaultCc;
  final int channel;
  final String? customName;
  final int? secondaryCc;
  final ActionPayload? payload;
  final ActionPayload? secondaryPayload;
  final bool invertX;
  final bool invertY;
  final int x;
  final int y;
  final int width;
  final int height;

  const TemplateControlSpec({
    required this.idPrefix,
    required this.type,
    required this.defaultCc,
    required this.channel,
    this.customName,
    this.secondaryCc,
    this.payload,
    this.secondaryPayload,
    this.invertX = false,
    this.invertY = false,
    required this.x,
    required this.y,
    this.width = 1,
    this.height = 1,
  });

  /// Materializes a concrete [LayoutControl] shifted by ([xOffset], [yOffset]).
  LayoutControl instantiate(String id, {int xOffset = 0, int yOffset = 0}) {
    return LayoutControl(
      id: id,
      type: type,
      defaultCc: defaultCc,
      channel: channel,
      customName: customName,
      secondaryCc: secondaryCc,
      payload: payload,
      secondaryPayload: secondaryPayload,
      invertX: invertX,
      invertY: invertY,
      x: x + xOffset,
      y: y + yOffset,
      width: width,
      height: height,
    );
  }
}

/// Immutable factory page template capable of creating a page or stamping onto one.
class PageTemplate {
  final PageTemplateId id;
  final String name;
  final String defaultPageName;
  final String description;
  final PageType pageType;
  final int gridColumns;
  final int gridRows;
  final List<TemplateControlSpec> controls;

  PageTemplate({
    required this.id,
    required this.name,
    required this.defaultPageName,
    required this.description,
    required this.pageType,
    required this.gridColumns,
    required this.gridRows,
    required List<TemplateControlSpec> controls,
  }) : controls = List<TemplateControlSpec>.unmodifiable(controls);

  int get controlCount => controls.length;

  int get boundingWidth {
    if (controls.isEmpty) return 0;
    var maxX = 0;
    for (final control in controls) {
      maxX = math.max(maxX, control.x + control.width);
    }
    return maxX;
  }

  int get boundingHeight {
    if (controls.isEmpty) return 0;
    var maxY = 0;
    for (final control in controls) {
      maxY = math.max(maxY, control.y + control.height);
    }
    return maxY;
  }

  /// Verifies positive bounds, contained controls, and zero pairwise overlaps.
  bool get isValid {
    if (gridColumns <= 0 || gridRows <= 0 || controls.isEmpty) return false;

    for (var i = 0; i < controls.length; i++) {
      final a = controls[i];
      if (a.x < 0 || a.y < 0 || a.width < 1 || a.height < 1) return false;
      if (a.x + a.width > gridColumns || a.y + a.height > gridRows) {
        return false;
      }
      for (var j = i + 1; j < controls.length; j++) {
        final b = controls[j];
        final overlaps =
            a.x < b.x + b.width &&
            a.x + a.width > b.x &&
            a.y < b.y + b.height &&
            a.y + a.height > b.y;
        if (overlaps) return false;
      }
    }
    return true;
  }

  /// Creates a new [LayoutPage] populated with concrete controls from this template.
  LayoutPage instantiatePage({
    required String pageId,
    required String idSuffix,
    String? customName,
  }) {
    final trimmed = customName?.trim();
    final pageName = (trimmed != null && trimmed.isNotEmpty)
        ? trimmed
        : defaultPageName;

    return LayoutPage(
      id: pageId,
      type: pageType,
      name: pageName,
      gridColumns: gridColumns,
      gridRows: gridRows,
      controls: instantiateControls(idSuffix: idSuffix),
    );
  }

  /// Creates concrete [LayoutControl] instances shifted by ([xOffset], [yOffset]).
  List<LayoutControl> instantiateControls({
    required String idSuffix,
    int xOffset = 0,
    int yOffset = 0,
  }) {
    return List<LayoutControl>.generate(controls.length, (index) {
      final spec = controls[index];
      return spec.instantiate(
        '${spec.idPrefix}_${idSuffix}_$index',
        xOffset: xOffset,
        yOffset: yOffset,
      );
    });
  }
}

/// Curated built-in factory page templates for quick performance setup.
abstract final class FactoryPageTemplates {
  static const List<String> _gmDrumNames = [
    'KICK',
    'RIM',
    'SNARE 1',
    'CLAP',
    'SNARE 2',
    'LOW TOM',
    'CLOSED HH',
    'MID TOM',
    'PEDAL HH',
    'HIGH TOM',
    'OPEN HH',
    'TOM 4',
    'CRASH 1',
    'RIDE 1',
    'CHINESE',
    'BELL',
  ];

  static final PageTemplate _factoryFaderBank = PageTemplate(
    id: PageTemplateId.factoryFaderBank,
    name: 'Factory Fader Bank',
    defaultPageName: 'FADER BANK',
    description: '4 orchestral faders (CC 1, 11, 7, 74)',
    pageType: PageType.fader,
    gridColumns: 8,
    gridRows: 4,
    controls: const [
      TemplateControlSpec(
        idPrefix: 'fader',
        type: ControlType.fader,
        defaultCc: 1,
        channel: 0,
        customName: 'CC1\nDYNAMICS',
        payload: CcPayload(channel: 0, cc: 1),
        x: 0,
        y: 0,
        width: 2,
        height: 4,
      ),
      TemplateControlSpec(
        idPrefix: 'fader',
        type: ControlType.fader,
        defaultCc: 11,
        channel: 0,
        customName: 'CC11\nEXPRESSION',
        payload: CcPayload(channel: 0, cc: 11),
        x: 2,
        y: 0,
        width: 2,
        height: 4,
      ),
      TemplateControlSpec(
        idPrefix: 'fader',
        type: ControlType.fader,
        defaultCc: 7,
        channel: 0,
        customName: 'CC7\nVOLUME',
        payload: CcPayload(channel: 0, cc: 7),
        x: 4,
        y: 0,
        width: 2,
        height: 4,
      ),
      TemplateControlSpec(
        idPrefix: 'fader',
        type: ControlType.fader,
        defaultCc: 74,
        channel: 0,
        customName: 'CC74\nBRIGHTNESS',
        payload: CcPayload(channel: 0, cc: 74),
        x: 6,
        y: 0,
        width: 2,
        height: 4,
      ),
    ],
  );

  static final PageTemplate _drumGrid4x4 = PageTemplate(
    id: PageTemplateId.drumGrid4x4,
    name: '4x4 Velocity Drum Grid',
    defaultPageName: '4X4 DRUMS',
    description: '16 GM pads on Ch 10 (Notes 36–51)',
    pageType: PageType.drumPad,
    gridColumns: 8,
    gridRows: 4,
    controls: List<TemplateControlSpec>.generate(16, (i) {
      final note = 36 + i;
      return TemplateControlSpec(
        idPrefix: 'pad',
        type: ControlType.drumPad,
        defaultCc: note,
        channel: 9,
        customName: _gmDrumNames[i],
        payload: NotePayload(
          channel: 9,
          note: note,
          velocityMode: NoteVelocityMode.touchPosition,
          velocityCurve: NoteVelocityCurve.drumPad,
        ),
        x: (i % 4) * 2,
        y: i ~/ 4,
        width: 2,
        height: 1,
      );
    }),
  );

  static final PageTemplate _xyAndEncoders = PageTemplate(
    id: PageTemplateId.xyAndEncoders,
    name: 'XY + Encoders',
    defaultPageName: 'XY + ENC',
    description: 'Split XY pad with 4 continuous encoders',
    pageType: PageType.xyPad,
    gridColumns: 8,
    gridRows: 4,
    controls: [
      const TemplateControlSpec(
        idPrefix: 'xy',
        type: ControlType.xyPad,
        defaultCc: 1,
        secondaryCc: LayoutControl.defaultXySecondaryCc,
        channel: 0,
        customName: 'XY PAD',
        payload: CcPayload(channel: 0, cc: 1),
        secondaryPayload: CcPayload(
          channel: 0,
          cc: LayoutControl.defaultXySecondaryCc,
        ),
        invertY: true,
        x: 0,
        y: 0,
        width: 4,
        height: 4,
      ),
      for (var i = 0; i < 4; i++)
        TemplateControlSpec(
          idPrefix: 'encoder',
          type: ControlType.encoder,
          defaultCc: 20 + i,
          channel: 0,
          customName: 'ENC ${i + 1}',
          payload: CcPayload(channel: 0, cc: 20 + i),
          x: 4 + (i % 2) * 2,
          y: (i ~/ 2) * 2,
          width: 2,
          height: 2,
        ),
    ],
  );

  static final PageTemplate _mixerStub8Track = PageTemplate(
    id: PageTemplateId.mixerStub8Track,
    name: '8-Track Mixer Stub',
    defaultPageName: '8-CH MIXER',
    description: '8 channels with Mute, Solo, and Faders',
    pageType: PageType.fader,
    gridColumns: 8,
    gridRows: 6,
    controls: [
      for (var i = 0; i < 8; i++) ...[
        TemplateControlSpec(
          idPrefix: 'mute',
          type: ControlType.toggle,
          defaultCc: 102,
          channel: i,
          customName: 'M${i + 1}',
          payload: CcPayload(channel: i, cc: 102),
          x: i,
          y: 0,
          width: 1,
          height: 1,
        ),
        TemplateControlSpec(
          idPrefix: 'solo',
          type: ControlType.toggle,
          defaultCc: 103,
          channel: i,
          customName: 'S${i + 1}',
          payload: CcPayload(channel: i, cc: 103),
          x: i,
          y: 1,
          width: 1,
          height: 1,
        ),
        TemplateControlSpec(
          idPrefix: 'ch_fader',
          type: ControlType.fader,
          defaultCc: 7,
          channel: i,
          customName: 'CH ${i + 1}',
          payload: CcPayload(channel: i, cc: 7),
          x: i,
          y: 2,
          width: 1,
          height: 4,
        ),
      ],
    ],
  );

  static final PageTemplate _mcuMixer8Track = PageTemplate(
    id: PageTemplateId.mcuMixer8Track,
    name: 'MCU 8-Track Mixer',
    defaultPageName: 'MCU MIXER',
    description:
        'Eight strips and master. Select MCU in MIDI Ports Configuration.',
    pageType: PageType.fader,
    gridColumns: 9,
    gridRows: 9,
    controls: [
      for (var strip = 0; strip < 8; strip++) ...[
        TemplateControlSpec(
          idPrefix: 'mcu_vpot',
          type: ControlType.encoder,
          defaultCc: -1,
          channel: 0,
          customName: 'V${strip + 1}',
          payload: McuActionPayload.vPot(strip),
          x: strip,
          y: 0,
        ),
        for (final button in McuChannelButton.values)
          TemplateControlSpec(
            idPrefix: 'mcu_${button.name}',
            type: ControlType.trigger,
            defaultCc: -1,
            channel: 0,
            customName: switch (button) {
              McuChannelButton.recordArm => 'REC',
              McuChannelButton.solo => 'SOLO',
              McuChannelButton.mute => 'MUTE',
              McuChannelButton.select => 'SEL',
            },
            payload: McuActionPayload.channelButton(strip, button),
            x: strip,
            y: button.index + 1,
          ),
      ],
      for (var strip = 0; strip <= 8; strip++)
        TemplateControlSpec(
          idPrefix: 'mcu_fader',
          type: ControlType.fader,
          defaultCc: -1,
          channel: 0,
          customName: strip == 8 ? 'MASTER' : 'CH ${strip + 1}',
          payload: McuActionPayload.fader(strip),
          x: strip,
          y: 5,
          height: 4,
        ),
    ],
  );

  static final List<PageTemplate> all = List<PageTemplate>.unmodifiable([
    _factoryFaderBank,
    _drumGrid4x4,
    _xyAndEncoders,
    _mixerStub8Track,
    _mcuMixer8Track,
  ]);

  static PageTemplate byId(PageTemplateId id) {
    return all.firstWhere((template) => template.id == id);
  }
}
