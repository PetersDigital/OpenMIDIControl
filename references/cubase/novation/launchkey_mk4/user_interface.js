var utils = require('./utils');
var colors = require('../common/colors');
var constants = require('./lk4_constants');

/**
 * Makes the Cubase user interface layer
 * @param {LaunchkeyMk4.Config} config
 * @returns {LaunchkeyMk4.UserInterface}
 */
function makeUserInterface(config) {
  if (config.layoutConfig.isMini) {
    return makeMiniUserInterface(config);
  }
  return makeRegularUserInterface(config);
}

/**
 * Makes the Cubase user interface layer for regular sized keys
 * @param {LaunchkeyMk4.Config} config
 * @returns {LaunchkeyMk4.UserInterface}
 */
function makeRegularUserInterface(config) {
  var ui = {};
  ui.shiftableZone = makeShiftableZone(config);
  var xOffset = config.layoutConfig.leftGap;

  makeKeyboard(config);
  if (config.layoutConfig.keys !== 25) {
    xOffset += 4;
  }

  makeOctaveButtons(config, xOffset, 0);
  if (config.layoutConfig.keys === 25) {
    xOffset += 4.25;
  } else if (config.layoutConfig.keys === 37) {
    xOffset += 5.5;
  } else {
    xOffset += 2;
  }

  if (config.layoutConfig.hasFaders) {
    ui.faderSection = makeFaderSection(config, xOffset, 0);
    xOffset += 19;
  }

  ui.trackButtons = makeScreenColumn(config, xOffset, ui.shiftableZone);
  xOffset += 6.5;

  ui.encoderSection = makeEncoderSection(config, xOffset, 0);
  ui.padSection = makePadSection(config, xOffset, 4, ui.shiftableZone);
  ui.encoderModes = makeEncoderModePads(
    config,
    'encoderMode',
    constants.CC_MODES.encoder
  );
  ui.legacyEncoderModes = makeEncoderModePads(
    config,
    'legacyEncoderMode',
    constants.CC_MODES.encoderLegacy
  );
  xOffset += 18.5;

  ui.transportSection = makeTransportSection(config, xOffset, 1.5);

  return ui;
}

/**
 * Makes the Cubase user interface layer for mini sized keys
 * @param {LaunchkeyMk4.Config} config
 * @returns {LaunchkeyMk4.UserInterface}
 */
function makeMiniUserInterface(config) {
  var ui = {};
  ui.shiftableZone = makeShiftableZone(config);
  var xOffset = config.layoutConfig.leftGap;

  makeKeyboard(config);
  xOffset += 3.5;

  ui.trackButtons = makeScreenColumn(config, xOffset, ui.shiftableZone);
  ui.transportSection = makeTransportSection(config, xOffset, 4.5625);
  makeOctaveButtons(config, xOffset, 5.875);
  xOffset += 5.5;

  ui.encoderSection = makeEncoderSection(config, xOffset, 0);
  ui.padSection = makePadSection(config, xOffset, 3.25, ui.shiftableZone);
  ui.encoderModes = makeEncoderModePads(
    config,
    'encoderMode',
    constants.CC_MODES.encoder
  );
  ui.legacyEncoderModes = makeEncoderModePads(
    config,
    'legacyEncoderMode',
    constants.CC_MODES.encoderLegacy
  );

  return ui;
}

/**
 * calculate width of keyboard control
 * @param {LaunchkeyMk4.Config} config
 * @returns {number} width of keyboard control
 */
function calculateKeyboardWidth(config) {
  var keyEnd = config.layoutConfig.keys - 1;
  var factor = config.layoutConfig.keyMultiplier || 1;
  return keyEnd * factor;
}

/**
 * Darkens RGB colors to be able to show active and non active states
 * @param {Common.Rgb} colorArray array of rgb colors
 * @returns {Common.Rgb} array of darkened rgb colors
 */
function darken(colorArray) {
  var factor = 0.3;
  return colorArray.map(function (color) {
    return color * factor;
  });
}

/**
 *
 * @param {LaunchkeyMk4.Config} config
 * @param {string} modeNamePrefix
 * @param {number} cc
 * @returns {MR_SurfaceCustomValueVariable[]}
 */
function makeEncoderModePads(config, modeNamePrefix, cc) {
  var encoderModes = makeModeSwitches(
    config,
    config.maxEncoderModes,
    modeNamePrefix
  );

  encoderModes.forEach(function (encoderMode) {
    encoderMode.mMidiBinding
      .setInputPort(config.midiInput)
      .bindToControlChange(0x6, cc);
  });

  return encoderModes;
}

/**
 *
 * @param {LaunchkeyMk4.Config} config
 * @param {number} xOffset offset in x direction on where to start the encoders
 * @param {number} yOffset offset in y direction on where to start the encoders
 * @returns {LaunchkeyMk4.EncoderSection} Object of mappable surfaces
 */
function makeEncoderSection(config, xOffset, yOffset) {
  var encoders = [];

  var labelFieldEncoders = config.deviceDriver.mSurface.makeLabelField(
    xOffset,
    yOffset,
    config.numChannels * 2,
    1
  );
  for (var i = 0; i < config.numChannels; i++) {
    const encoder = config.deviceDriver.mSurface.makeKnob(
      i * 2 + xOffset,
      yOffset + 1,
      2,
      2
    );

    labelFieldEncoders.relateTo(encoder);

    var surfaceValue = encoder.mSurfaceValue;
    surfaceValue.mMidiBinding
      .setInputPort(config.midiInput)
      .bindToControlChange(0x0f, 0x55 + i)
      .setTypeRelativeBinaryOffset();

    encoders.push(encoder);

    var address = i + 0x15;
    surfaceValue.mOnTitleChange = utils.encoderOnTitleChangeCallback(
      config,
      address
    );

    surfaceValue.mOnDisplayValueChange = utils.encoderOnValueChangeCallback(
      config,
      address
    );
  }

  var isMini = config.layoutConfig.isMini;
  var modeButtons = makeVerticalButtons(
    config,
    config.numChannels * 2 + xOffset,
    yOffset + (isMini ? 0.5 : 0.25),
    isMini ? 1.25 : 1.5,
    0x33
  );

  return {encoders, labelFieldEncoders, modeButtons};
}

/**
 * Faders and Buttons area
 * @param {LaunchkeyMk4.Config} config
 * @param {number} xOffset offset in x direction on where to start the faders and fader buttons area
 * @param {number} yOffset offset in y direction on where to start the faders and fader buttons area
 * @returns {LaunchkeyMk4.FaderSection} Object of mappable surfaces
 */
function makeFaderSection(config, xOffset, yOffset) {
  var faders = [];
  var buttons = [];

  var surface = config.deviceDriver.mSurface;
  var x = xOffset;
  var y = yOffset;
  var width = config.numChannels * 2;
  var labelFieldFaders = surface.makeLabelField(x, y, width, 1);

  for (var i = 0; i < config.numChannels; i++) {
    var channelSettings = {
      offset: i,
      r: 0,
      g: 0,
      b: 0,
      isActive: false,
      hasValueTitle: false,
    };

    x = i * 2 + xOffset;
    y = yOffset + 1;
    var fader = surface.makeFader(x, y, 2, 5);
    setupFader(config, labelFieldFaders, fader, i);
    faders.push(fader);

    y += 5.5;
    var button = surface.makeButton(x, y, 2, 1.5);
    setupButton(config, channelSettings, button, i);
    buttons.push(button);
  }

  var faderSwitches = makeFaderModeSwitches(config);

  x = xOffset + 16;
  y = yOffset + 1;
  var masterFader = surface.makeFader(x, y, 2, 5);
  setupFader(config, null, masterFader, config.numChannels);

  y += 5.5;
  var armSelect = surface.makeButton(x, y, 2, 1.5);
  armSelect.mSurfaceValue.mMidiBinding
    .setInputPort(config.midiInput)
    .bindToControlChange(0x00, 0x2d);

  return {
    faders,
    buttons,
    masterFader,
    armSelect,
    faderModes: faderSwitches.faderModes,
    legacyFaderModes: faderSwitches.legacyFaderModes,
    labelFieldFaders,
  };
}

/**
 * Sets up the bindings for the supplied button
 * @param {LaunchkeyMk4.Config} config
 * @param {{offset: number; hasValueTitle: boolean;}} channelSettings
 * @param {MR_Button} button
 * @param {number} buttonIndex
 */
function setupButton(config, channelSettings, button, buttonIndex) {
  function sendColor(context, value) {
    var address = 0x25 + channelSettings.offset;
    var state = context.getState('subpage.Fader Buttons');
    if (state === 'Arm') {
      sendSetTableColor(config, context, 0xb0, address, 'recReady', value);
    } else if (state === 'Select') {
      /** @type Common.Rgb */
      var rgb = [channelSettings.r, channelSettings.g, channelSettings.b];
      sendSetRGBColor(config, context, 0x53, address, rgb, value);
    }
  }

  button.mSurfaceValue.mMidiBinding
    .setInputPort(config.midiInput)
    .bindToControlChange(0x00, 0x25 + buttonIndex);

  button.mSurfaceValue.mOnTitleChange = colors.resetColorOnTitleChangeCallback(
    config,
    channelSettings,
    0xb0,
    0x25 + buttonIndex
  );

  button.mSurfaceValue.mOnColorChange = function (context, r, g, b) {
    // utils.log('button.mOnColorChange', channelSettings.offset, r, g, b);
    channelSettings.r = r;
    channelSettings.g = g;
    channelSettings.b = b;

    if (channelSettings.hasValueTitle) {
      sendColor(context, 0);
    }
  };

  button.mSurfaceValue.mOnProcessValueChange = function (context, value) {
    // utils.log('button.mOnProcessValueChange', channelSettings.offset, value);
    if (channelSettings.hasValueTitle) {
      sendColor(context, value);
    }
  };
}

/**
 * Sets up the bindings for the supplied fader
 * @param {LaunchkeyMk4.Config} config
 * @param {MR_SurfaceLabelField} labelFieldFaders
 * @param {MR_Fader} fader
 * @param {number} faderIndex
 */
function setupFader(config, labelFieldFaders, fader, faderIndex) {
  if (labelFieldFaders) {
    labelFieldFaders.relateTo(fader);
  }
  fader.mSurfaceValue.mMidiBinding
    .setInputPort(config.midiInput)
    .setOutputPort(config.midiOutput)
    .bindToControlChange(0x0f, 0x05 + faderIndex);

  fader.mSurfaceValue.mOnTitleChange = utils.faderOnTitleChangeCallback(
    config,
    faderIndex + 0x05
  );

  fader.mSurfaceValue.mOnDisplayValueChange = utils.faderOnValueChangeCallback(
    config,
    faderIndex + 0x05
  );
}

/**
 * Make keyboard and adjacent controls
 * @param {LaunchkeyMk4.Config} config
 */
function makeKeyboard(config) {
  var isMini = config.layoutConfig.isMini;
  var surface = config.deviceDriver.mSurface;
  var keyboardWidth = calculateKeyboardWidth(config);
  var lastKeyIndex = config.layoutConfig.keys - 1;
  if (!config.layoutConfig.isMini && config.layoutConfig.keys === 25) {
    // Regular 25 key layout
    surface.makePianoKeys(4, 8.5, keyboardWidth, 8, 0, lastKeyIndex);
    surface.makeBlindPanel(0, 10, 1.5, 5);
    surface.makeBlindPanel(2, 10, 1.5, 5);
  } else {
    // All other key layouts
    surface.makePianoKeys(0, 8.5, keyboardWidth, 8, 0, lastKeyIndex);
    surface.makeBlindPanel(0, 0, 1.5, isMini ? 7.25 : 5);
    surface.makeBlindPanel(isMini ? 1.5 : 2, 0, 1.5, isMini ? 7.25 : 5);
  }

  // This should block the "activate DAW mode" echo message (filters are not yet implemented)
  var fakeNote =
    config.deviceDriver.mSurface.makeCustomValueVariable('fakeNote');
  fakeNote.mMidiBinding
    .setInputPort(config.midiInput)
    .setOutputPort(config.midiOutput)
    .bindToNote(0x0f, 0x0c);
}

/**
 *
 * @param {LaunchkeyMk4.Config} config
 * @param {number} xOffset offset in x direction on where to start the octave controls
 * @param {number} yOffset offset in x direction on where to create the button set
 */
function makeOctaveButtons(config, xOffset, yOffset) {
  var surface = config.deviceDriver.mSurface;
  if (config.layoutConfig.isMini) {
    surface.makeBlindPanel(xOffset, yOffset, 2, 1.375);
    surface.makeBlindPanel(xOffset + 2, yOffset, 2, 1.375);
  } else if (config.layoutConfig.keys === 25) {
    surface.makeBlindPanel(xOffset, yOffset + 8.5, 1.5, 1.375);
    surface.makeBlindPanel(xOffset + 2, yOffset + 8.5, 1.5, 1.375);
  } else {
    surface.makeBlindPanel(xOffset, yOffset, 1.5, 2);
    surface.makeBlindPanel(xOffset, yOffset + 3, 1.5, 2);
  }
}

/**
 * make a single pad
 * @param {LaunchkeyMk4.Config} config
 * @param {number} xOffset offset in x direction on where to create the button set
 * @param {number} yOffset offset in x direction on where to create the button set
 * @param {number} channelIndex The channel index
 * @returns {MR_TriggerPad} Pad object
 */
function makePad(config, xOffset, yOffset, channelIndex) {
  const x = channelIndex * 2 + xOffset;
  return config.deviceDriver.mSurface.makeTriggerPad(x, yOffset, 2, 2);
}

/**
 * make all pads
 * @param {LaunchkeyMk4.Config} config
 * @param {number} xOffset offset in x direction on where to create the button set
 * @param {number} yOffset offset in x direction on where to create the button set
 * @param {LaunchkeyMk4.ShiftableZone} shiftableZone Object containing the normal and shift layers
 * @returns {LaunchkeyMk4.PadSection} Object of all the mappable surfaces
 */
function makePadSection(config, xOffset, yOffset, shiftableZone) {
  var upperPads = [];
  var lowerPads = [];
  var isMini = config.layoutConfig.isMini;

  var modeButtons = makeVerticalButtons(
    config,
    xOffset - (isMini ? 1.25 : 1.5),
    yOffset,
    2,
    0x6a
  );

  if (isMini) {
    var modeButtonsShift = makeVerticalButtons(
      config,
      xOffset - 1.25,
      yOffset,
      2,
      0x66
    );
    modeButtons.bottom.setControlLayer(shiftableZone.normalLayer);
    modeButtons.top.setControlLayer(shiftableZone.normalLayer);
    modeButtonsShift.bottom.setControlLayer(shiftableZone.shiftLayer);
    modeButtonsShift.top.setControlLayer(shiftableZone.shiftLayer);
  }

  for (var i = 0; i < config.numChannels; i++) {
    var channelSettings = {offset: i, hasValueTitle: false, r: 0, g: 0, b: 0};
    var upperPad = makePad(config, xOffset, yOffset, i);
    var lowerPad = makePad(config, xOffset, yOffset + 2, i);
    setupUpperPad(config, channelSettings, upperPad, i);
    setupLowerPad(config, channelSettings, lowerPad, i);
    upperPads.push(upperPad);
    lowerPads.push(lowerPad);
  }

  makeVerticalButtons(config, config.numChannels * 2 + xOffset, yOffset, 2, 0);

  var padSwitches = makePadModeSwitches(config);

  return {
    upperPads,
    lowerPads,
    modeButtons,
    modeButtonsShift,
    padModes: padSwitches.padModes,
    legacyPadModes: padSwitches.legacyPadModes,
  };
}

/**
 *
 * @param {LaunchkeyMk4.Config} config
 * @param {{offset: number; hasValueTitle: boolean;}} channelSettings
 * @param {MR_TriggerPad} lowerPad
 * @param {number} padIndex
 */
function setupLowerPad(config, channelSettings, lowerPad, padIndex) {
  setupPad(config, channelSettings, lowerPad, 0x70 + padIndex);

  lowerPad.mSurfaceValue.mOnProcessValueChange = function (context, value) {
    if (!channelSettings.hasValueTitle) return;
    var address = 0x70 + channelSettings.offset;
    var state = context.getState('subpage.Pads');
    if (state === 'Mute / Solo') {
      sendSetTableColor(config, context, 0x90, address, 'mute', value);
    } else if (state === 'Select / Arm') {
      sendSetTableColor(config, context, 0x90, address, 'recReady', value);
    }
  };
}

/**
 *
 * @param {LaunchkeyMk4.Config} config
 * @param {{offset: number; hasValueTitle: boolean; r: number; g: number; b: number;}} channelSettings
 * @param {MR_TriggerPad} upperPad
 * @param {number} padIndex
 */
function setupUpperPad(config, channelSettings, upperPad, padIndex) {
  setupPad(config, channelSettings, upperPad, 0x60 + padIndex);

  function sendColor(context, value) {
    var address = 0x60 + channelSettings.offset;
    var state = context.getState('subpage.Pads');
    if (state === 'Mute / Solo') {
      sendSetTableColor(config, context, 0x90, address, 'solo', value);
    } else if (state === 'Select / Arm') {
      /** @type Common.Rgb */
      var rgb = [channelSettings.r, channelSettings.g, channelSettings.b];
      sendSetRGBColor(config, context, 0x43, address, rgb, value);
    }
  }

  upperPad.mSurfaceValue.mOnColorChange = function (context, r, g, b) {
    // utils.log('upperPad.mOnColorChange', channelSettings.offset, r, g, b);
    channelSettings.r = r;
    channelSettings.g = g;
    channelSettings.b = b;
    sendColor(context, 0);
  };

  upperPad.mSurfaceValue.mOnProcessValueChange = function (context, value) {
    // utils.log('upperPad.mOnProcessValueChange', channelSettings.offset, value);
    if (channelSettings.hasValueTitle) {
      sendColor(context, value);
    }
  };
}

/**
 *
 * @param {LaunchkeyMk4.Config} config
 * @param {{hasValueTitle: boolean;}} channelSettings
 * @param {MR_TriggerPad} pad
 * @param {number} address
 */
function setupPad(config, channelSettings, pad, address) {
  pad.mSurfaceValue.mMidiBinding
    .setInputPort(config.midiInput)
    .bindToNote(0, address);

  pad.mSurfaceValue.mOnTitleChange = colors.resetColorOnTitleChangeCallback(
    config,
    channelSettings,
    0x90,
    address
  );
}

/**
 *
 * @param {LaunchkeyMk4.Config} config
 * @param {number} numberOfModes
 * @param {string} modeNamePrefix
 * @param {number} cc
 * @return {MR_SurfaceCustomValueVariable[]}
 */
function makeAndBindModeSwitches(config, numberOfModes, modeNamePrefix, cc) {
  var modeSwitches = makeModeSwitches(config, numberOfModes, modeNamePrefix);
  modeSwitches.forEach(function (modeSwitch) {
    modeSwitch.mMidiBinding
      .setInputPort(config.midiInput)
      .bindToControlChange(0x6, cc);
  });
  return modeSwitches;
}

/**
 *
 * @param {LaunchkeyMk4.Config} config
 * @return {{faderModes: MR_SurfaceCustomValueVariable[], legacyFaderModes: MR_SurfaceCustomValueVariable[] }}
 */
function makeFaderModeSwitches(config) {
  return {
    legacyFaderModes: makeAndBindModeSwitches(
      config,
      config.maxFaderModes,
      'legacyFaderMode',
      constants.CC_MODES.faderLegacy
    ),
    faderModes: makeAndBindModeSwitches(
      config,
      config.maxFaderModes,
      'faderMode',
      constants.CC_MODES.fader
    ),
  };
}

/**
 *
 * @param {LaunchkeyMk4.Config} config
 * @param {number} numberOfModes
 * @param {string} modeNamePrefix
 * @return {MR_SurfaceCustomValueVariable[]}
 */
function makeModeSwitches(config, numberOfModes, modeNamePrefix) {
  var modes = [];
  for (var index = 0; index < numberOfModes; ++index) {
    var name = modeNamePrefix + index.toString();
    var mode = config.deviceDriver.mSurface.makeCustomValueVariable(name);
    modes.push(mode);
  }
  return modes;
}

/**
 *
 * @param {LaunchkeyMk4.Config} config
 * @return {{padModes: MR_SurfaceCustomValueVariable[], legacyPadModes: MR_SurfaceCustomValueVariable[] }}
 */
function makePadModeSwitches(config) {
  return {
    legacyPadModes: makeAndBindModeSwitches(
      config,
      config.maxPadModes,
      'legacyPadMode',
      constants.CC_MODES.padLegacy
    ),
    padModes: makeAndBindModeSwitches(
      config,
      config.maxPadModes,
      'padMode',
      constants.CC_MODES.pad
    ),
  };
}

/**
 *
 * @param {LaunchkeyMk4.Config} config
 * @param {number} xOffset offset in x direction on where to start the screen column controls
 * @param {LaunchkeyMk4.ShiftableZone} shiftableZone Object containing the normal and shift layers
 * @returns {LaunchkeyMk4.TrackButtons} an object of all mappable surfaces
 */
function makeScreenColumn(config, xOffset, shiftableZone) {
  var features = {};
  var isMini = config.layoutConfig.isMini;

  // Screen panel
  config.deviceDriver.mSurface.makeBlindPanel(xOffset, 0, 4, isMini ? 2.5 : 2);

  // Shift button
  features.shift = config.deviceDriver.mSurface.makeButton(
    xOffset,
    isMini ? 3.25 : 2,
    2,
    1.375
  );
  features.shift.mSurfaceValue.mMidiBinding
    .setInputPort(config.midiInput)
    .bindToControlChange(0x06, constants.CC_MODES.shift);

  // Legacy Shift button
  features.legacyShift = config.deviceDriver.mSurface.makeButton(
    xOffset,
    isMini ? 3.25 : 2,
    2,
    1.375
  );
  features.legacyShift.mSurfaceValue.mMidiBinding
    .setInputPort(config.midiInput)
    .bindToControlChange(0x06, constants.CC_MODES.shiftLegacy);

  // Settings button
  config.deviceDriver.mSurface.makeBlindPanel(
    xOffset + 2,
    isMini ? 3.25 : 2,
    2,
    1.375
  );

  if (isMini) {
    // Arp and Scale buttons
    config.deviceDriver.mSurface.makeBlindPanel(xOffset + 4.25, 0, 1.25, 1.25);
    config.deviceDriver.mSurface.makeBlindPanel(
      xOffset + 4.25,
      1.25,
      1.25,
      1.25
    );
  } else {
    // Track Left button
    features.trackPrev = config.deviceDriver.mSurface
      .makeButton(xOffset, 4.25, 2, 1.5)
      .setControlLayer(shiftableZone.normalLayer);
    features.trackPrev.mSurfaceValue.mMidiBinding
      .setInputPort(config.midiInput)
      .bindToControlChange(0x00, 0x67);

    // Track Left Shift button
    features.trackPrevShift = config.deviceDriver.mSurface
      .makeButton(xOffset, 4.25, 2, 1.5)
      .setControlLayer(shiftableZone.shiftLayer);
    features.trackPrevShift.mSurfaceValue.mMidiBinding
      .setInputPort(config.midiInput)
      .bindToControlChange(0x00, 0x6d);

    // Track Right button
    features.trackNext = config.deviceDriver.mSurface
      .makeButton(xOffset + 2, 4.25, 2, 1.5)
      .setControlLayer(shiftableZone.normalLayer);
    features.trackNext.mSurfaceValue.mMidiBinding
      .setInputPort(config.midiInput)
      .bindToControlChange(0x00, 0x66);

    // Track Right Shift button
    features.trackNextShift = config.deviceDriver.mSurface
      .makeButton(xOffset + 2, 4.25, 2, 1.5)
      .setControlLayer(shiftableZone.shiftLayer);
    features.trackNextShift.mSurfaceValue.mMidiBinding
      .setInputPort(config.midiInput)
      .bindToControlChange(0x00, 0x6c);

    // Scale and Chord Map buttons
    config.deviceDriver.mSurface.makeBlindPanel(xOffset, 6, 2, 1);
    config.deviceDriver.mSurface.makeBlindPanel(xOffset + 2, 6, 2, 1);

    // Arp and Fixed Chord buttons
    config.deviceDriver.mSurface.makeBlindPanel(xOffset, 7, 2, 1);
    config.deviceDriver.mSurface.makeBlindPanel(xOffset + 2, 7, 2, 1);
  }

  return features;
}

/**
 * Makes the normal and shift control layers
 * @param {LaunchkeyMk4.Config} config
 * @returns {LaunchkeyMk4.ShiftableZone} Object containing the normal and shift layers
 */
function makeShiftableZone(config) {
  var surface = config.deviceDriver.mSurface;
  var zone = surface.makeControlLayerZone('Shiftable Zone');
  return {
    normalLayer: zone.makeControlLayer('Normal Layer'),
    shiftLayer: zone.makeControlLayer('Shift Layer'),
  };
}

/**
 *
 * @param {LaunchkeyMk4.Config} config
 * @param {number} xOffset offset in x direction on where to create the button
 * @param {number} yOffset offset in y direction on where to create the button
 * @param {number} cc Control change number to bind the button to (Function assumes channel 1)
 * @returns {MR_Button}
 */
function makeStateButton(config, xOffset, yOffset, cc) {
  var button = makeStatelessButton(config, xOffset, yOffset, cc);
  var isMini = config.layoutConfig.isMini;
  button.mSurfaceValue.mOnProcessValueChange = function (context, value) {
    if (cc === 0x74) {
      value = 0; // special case Stop, should always use the dim state
    }
    if (
      cc === 0x73 &&
      value !== 0 &&
      isMini &&
      context.getState('subpage.Shift') === 'shifted'
    ) {
      value = 0; // Prevent Play from lighting up brightly when shifted on minis
    }
    var colorValue = constants.BRIGHTNESS[value];
    if ((cc == 0x73 || cc == 0x75) && value !== 0 && isMini) {
      // Brighten Play and Record on minis but not too bright that it bleeds into adjacent LEDs
      colorValue = constants.MEDIUM_BRIGHTNESS;
    }
    config.midiOutput.sendMidi(context, [0xb3, cc, colorValue]);
  };
  return button;
}

/**
 *
 * @param {LaunchkeyMk4.Config} config
 * @param {number} xOffset offset in x direction on where to create the button
 * @param {number} yOffset offset in y direction on where to create the button
 * @param {number} cc Control change number to bind the button to (Function assumes channel 1)
 * @returns {MR_Button}
 */
function makeStatelessButton(config, xOffset, yOffset, cc) {
  var buttonHeight = config.layoutConfig.isMini ? 1.375 : 1.5;
  var button = config.deviceDriver.mSurface.makeButton(
    xOffset,
    yOffset,
    2,
    buttonHeight
  );
  button.mSurfaceValue.mMidiBinding
    .setInputPort(config.midiInput)
    .bindToControlChange(0x00, cc);
  return button;
}

/**
 *
 * @param {LaunchkeyMk4.Config} config
 * @param {number} xOffset offset in x direction on where to start the transport controls
 * @param {number} yOffset offset in y direction on where to start the transport controls
 * @returns {LaunchkeyMk4.TransportSection}
 */
function makeTransportSection(config, xOffset, yOffset) {
  var features = {};

  if (config.layoutConfig.isMini) {
    features.play = makeStateButton(config, xOffset, yOffset, 0x73);
    features.record = makeStateButton(config, xOffset + 2, yOffset, 0x75);
  } else {
    var buttonHeight = 1.5;
    var paddingHeight = 0.5;

    features.captureMidi = makeStatelessButton(config, xOffset, yOffset, 0x4a);
    features.undo = makeStatelessButton(config, xOffset + 2, yOffset, 0x4d);

    yOffset += buttonHeight;
    features.quantize = makeStatelessButton(config, xOffset, yOffset, 0x4b);
    features.metronome = makeStateButton(config, xOffset + 2, yOffset, 0x4c);

    yOffset += paddingHeight + buttonHeight;
    features.stop = makeStateButton(config, xOffset, yOffset, 0x74);
    features.cycle = makeStateButton(config, xOffset + 2, yOffset, 0x76);

    yOffset += buttonHeight;
    features.play = makeStateButton(config, xOffset, yOffset, 0x73);
    features.record = makeStateButton(config, xOffset + 2, yOffset, 0x75);
  }
  features.zoom = makeZoomEncoder(config, 0x56);
  features.marker = makeMarkerEncoder(config, 0x59);

  return features;
}

/**
 *
 * @param {LaunchkeyMk4.Config} config
 * @param {number} cc
 * @returns {LaunchkeyMk4.IncDecEncoder}
 */
function makeZoomEncoder(config, cc) {
  var encoder = utils.makeIncDecEncoder(
    config,
    'ZoomEncoder',
    'Encoders',
    'Transport',
    0
  );
  encoder.bindToControlChange(0x0f, cc);
  return encoder;
}

/**
 *
 * @param {LaunchkeyMk4.Config} config
 * @param {number} cc
 * @returns {LaunchkeyMk4.IncDecEncoder}
 */
function makeMarkerEncoder(config, cc) {
  var encoder = utils.makeIncDecEncoder(
    config,
    'MarkerEncoder',
    'Encoders',
    'Transport',
    0.03
  );
  encoder.bindToControlChange(0x0f, cc);
  return encoder;
}

/**
 *
 * @param {LaunchkeyMk4.Config} config
 * @param {number} xOffset offset in x direction on where to create the button set
 * @param {number} yOffset offset in y direction on where to create the button set
 * @param {number} height height of the buttons
 * @param {number} cc control change number of the top button, bottom is assumed to be cc + 1
 * @returns {LaunchkeyMk4.VerticalButtons} top and bottom Buttons
 */
function makeVerticalButtons(config, xOffset, yOffset, height, cc) {
  var isMini = config.layoutConfig.isMini;
  var top = config.deviceDriver.mSurface.makeButton(
    xOffset,
    yOffset,
    isMini ? 1.25 : 1.5,
    height
  );
  if (cc !== undefined) {
    top.mSurfaceValue.mMidiBinding
      .setInputPort(config.midiInput)
      .bindToControlChange(0x00, cc);
  }

  var bottom = config.deviceDriver.mSurface.makeButton(
    xOffset,
    yOffset + height,
    isMini ? 1.25 : 1.5,
    height
  );
  if (cc !== undefined) {
    bottom.mSurfaceValue.mMidiBinding
      .setInputPort(config.midiInput)
      .bindToControlChange(0x00, cc + 1);
  }

  return {top, bottom};
}

/**
 * set led color to correct color for function and value
 * @param {LaunchkeyMk4.Config} config
 * @param {MR_ActiveDevice} context
 * @param {number} statusByte
 * @param {number} address
 * @param {string} func
 * @param {number} value
 */
function sendSetTableColor(config, context, statusByte, address, func, value) {
  var color = constants.COLORS[func][value];
  config.midiOutput.sendMidi(context, [statusByte, address, color]);
}

/**
 *
 * @param {LaunchkeyMk4.Config} config
 * @param {MR_ActiveDevice} context
 * @param {number} colorSpec
 * @param {number} address
 * @param {Common.Rgb} color
 * @param {number} value
 */
function sendSetRGBColor(config, context, colorSpec, address, color, value) {
  var correctedColor = color;
  if (value === 0) {
    correctedColor = darken(color);
  }
  var r = Math.round(correctedColor[0] * 127);
  var g = Math.round(correctedColor[1] * 127);
  var b = Math.round(correctedColor[2] * 127);

  var sysex = utils.makeSysex(config, [0x01, colorSpec, address, r, g, b]);
  config.midiOutput.sendMidi(context, sysex);
}

module.exports = {
  makeUserInterface,
};
