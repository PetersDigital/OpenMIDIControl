var constants = require('../common/constants');
var screen = require('../common/screen');
var midi = require('./midi');
var utils = require('../common/base_utils');

/**
 * Control sizes
 */
var controlWidth = 2;
var labelHeight = 1;
var knobWidth = controlWidth;
var knobHeight = knobWidth;
var faderWidth = controlWidth;
var faderHeight = knobHeight * 3;
var buttonWidth = controlWidth;
var buttonHeight = labelHeight;
var screenWidth = controlWidth + 1.5;
var screenHeight = controlWidth;
var smallButtonWidth = 1.5;
var controlButtonXOffset = 0.25;

/**
 * Makes the Cubase user interface layer
 * @param {LaunchControlXl3.Config} config
 * @returns {LaunchControlXl3.UserInterface}
 */
function makeUserInterface(config) {
  var ui = {};

  ui.controlSection = makeControlSection(config);
  ui.encoderSection = makeEncoderSection(config);
  ui.faderSection = makeFaderSection(config);
  ui.faderButtonSection = makeFaderButtonSection(config);

  ui.transportSection = {
    zoom: makeIncDecEncoder(config, 'Zoom', 0, midi.transport.zoom),
    marker: makeIncDecEncoder(config, 'Marker', 0.03, midi.transport.marker),
    loop: makeLoopEncoder(config),
  };

  return ui;
}

/**
 * Makes the UI for the control section on the LHS
 * @param {LaunchControlXl3.Config} config
 * @returns {LaunchControlXl3.ControlSection} Object of mappable surfaces
 */
function makeControlSection(config) {
  var yAdjust = 0.25;
  var xOffset = 0;
  var yOffset = labelHeight - yAdjust;
  var surface = config.deviceDriver.mSurface;

  /** @type {LaunchControlXl3.ControlSection} */
  var controlSection = {
    encoderPageButtons: [],
    trackButtons: [],
    transportButtons: [],
  };

  // Make the screen
  surface.makeBlindPanel(xOffset, yOffset, screenWidth, screenHeight);

  // Make the encoder page buttons
  xOffset = controlButtonXOffset;
  yOffset = knobHeight + labelHeight * 2 + yAdjust;
  for (var i = 0; i < 2; ++i) {
    var x = xOffset + i * smallButtonWidth;
    var button = surface.makeButton(x, yOffset, smallButtonWidth, buttonHeight);
    setupEncoderPageButton(config, button, i);
    controlSection.encoderPageButtons.push(button);
  }

  // Make the track buttons
  yOffset += knobHeight + labelHeight;
  for (var i = 0; i < 2; ++i) {
    var x = xOffset + i * smallButtonWidth;
    var button = surface.makeButton(x, yOffset, smallButtonWidth, buttonHeight);
    setupTrackButton(config, button, i);
    controlSection.trackButtons.push(button);
  }

  // Make the transport buttons
  yOffset += knobHeight + labelHeight * 2;
  for (var i = 0; i < 2; ++i) {
    var y = yOffset + i * buttonHeight;
    var width = smallButtonWidth * 2;
    var button = surface.makeButton(xOffset, y, width, buttonHeight);
    setupTransportButton(config, button, i);
    controlSection.transportButtons.push(button);
  }

  // Make the shift and mode buttons
  yOffset += knobHeight + labelHeight;

  // Shift button
  controlSection.shiftButton = surface.makeButton(
    xOffset,
    yOffset,
    smallButtonWidth * 2,
    buttonHeight
  );
  setupMidiBinding(config, controlSection.shiftButton, midi.shift);

  // Mode button
  controlSection.modeButton = surface.makeButton(
    xOffset,
    yOffset + buttonHeight,
    smallButtonWidth * 2,
    buttonHeight
  );
  setupMidiBinding(config, controlSection.modeButton, midi.mode);

  return controlSection;
}

/**
 * Makes the UI for the encoder section
 * @param {LaunchControlXl3.Config} config The configuration object
 * @returns {LaunchControlXl3.EncoderSection} Object of mappable surfaces
 */
function makeEncoderSection(config) {
  var encoders = [];
  var xOffset = 4;
  var yOffset = 0;

  // Make the label field which spans across the top of the encoders section
  var surface = config.deviceDriver.mSurface;
  var labelField = surface.makeLabelField(
    xOffset,
    yOffset,
    config.numChannels * knobWidth,
    labelHeight
  );
  yOffset += labelHeight;

  // Make the grid of encoders
  for (var row = 0; row < 3; ++row) {
    for (var col = 0; col < config.numChannels; ++col) {
      var encoder = surface.makeKnob(
        col * knobWidth + xOffset,
        yOffset,
        knobWidth,
        knobHeight
      );

      setupEncoder(config, labelField, encoder, col + row * 8);
      encoders.push(encoder);
    }
    yOffset += knobHeight + labelHeight;
  }

  return {encoders, labelField};
}

/**
 * Makes the UI for the button section below the faders
 * @param {LaunchControlXl3.Config} config The configuration object
 * @returns {LaunchControlXl3.FaderButtonSection} Object of mappable surfaces
 */
function makeFaderButtonSection(config) {
  var faderButtonSection = {
    buttons: [],
  };
  var xOffset = 4;
  var yOffset = knobHeight * 4 + labelHeight * 4 + faderHeight;
  var toggleButtons = ['soloArm', 'muteSelect'];
  var surface = config.deviceDriver.mSurface;

  for (var row = 0; row < 2; ++row) {
    var toggleButton = surface.makeButton(
      controlButtonXOffset,
      yOffset,
      smallButtonWidth * 2,
      buttonHeight
    );

    setupMidiBinding(config, toggleButton, {channel: 0, cc: 0x41 + row});
    faderButtonSection[toggleButtons[row]] = toggleButton;

    for (var col = 0; col < config.numChannels; ++col) {
      var button = surface.makeButton(
        col * buttonWidth + xOffset,
        yOffset,
        buttonWidth,
        buttonHeight
      );
      setupMidiBinding(config, button, {channel: 0, cc: 0x25 + col + row * 8});
      faderButtonSection.buttons.push(button);
    }
    yOffset += buttonHeight * 1.5;
  }

  return faderButtonSection;
}

/**
 * Makes the UI for the fader section
 * @param {LaunchControlXl3.Config} config
 * @returns {LaunchControlXl3.FaderSection} Object of mappable surfaces
 */
function makeFaderSection(config) {
  var faders = [];
  var xOffset = 4;
  var yOffset = knobHeight * 4 + labelHeight * 2;

  // Make the label field which spans across the top of the faders section
  var surface = config.deviceDriver.mSurface;
  var labelField = surface.makeLabelField(
    xOffset,
    yOffset,
    config.numChannels * faderWidth,
    labelHeight
  );
  yOffset += labelHeight;

  // Make the faders
  for (var col = 0; col < config.numChannels; ++col) {
    var fader = surface.makeFader(
      col * faderWidth + xOffset,
      yOffset,
      faderWidth,
      faderHeight
    );
    setupFader(config, labelField, fader, col);
    faders.push(fader);
  }

  return {faders, labelField};
}

/**
 * Make the Loop On/Off encoder
 * @param {Common.Config} config
 * @returns {Common.ToggleEncoder}
 */
function makeLoopEncoder(config) {
  var encoder = utils.makeToggleEncoder(
    config,
    constants.TITLES.cycleActivate,
    'DAW Mode',
    'DAW Control'
  );

  encoder.bindToControlChange(
    midi.transport.loop.channel,
    midi.transport.loop.cc
  );

  return encoder;
}

/**
 * make an IncDecEncoder
 * @param {Common.Config} config
 * @param {string} name
 * @param {number} damping
 * @param {{channel: number, cc: number}} midiValues
 * @returns {Common.IncDecEncoder}
 */
function makeIncDecEncoder(config, name, damping, midiValues) {
  var encoder = utils.makeIncDecEncoder(
    config,
    name,
    'DAW Mode',
    'DAW Control',
    damping
  );

  encoder.bindToControlChange(midiValues.channel, midiValues.cc);

  return encoder;
}

/**
 * Sets up the bindings for the supplied button
 * @param {LaunchControlXl3.Config} config The configuration object
 * @param {MR_Button} button The button to setup
 * @param {{channel: number; cc: number}} midiValues The midi values to bind to
 */
function setupMidiBinding(config, button, midiValues) {
  var surfaceValue = button.mSurfaceValue;

  surfaceValue.mMidiBinding
    .setInputPort(config.midiInput)
    .bindToControlChange(midiValues.channel, midiValues.cc);
}

/**
 * Sets up the bindings for the supplied encoder
 * @param {LaunchControlXl3.Config} config The configuration object
 * @param {MR_SurfaceLabelField} labelField The label field for the encoders
 * @param {MR_Knob} encoder The encoder to setup
 * @param {number} row The row index of the encoder
 * @param {number} col The column index of the encoder
 */
function setupEncoder(config, labelField, encoder, index) {
  var cc = 0x4d + index;

  var surfaceValue = encoder.mSurfaceValue;
  surfaceValue.mMidiBinding
    .setInputPort(config.midiInput)
    .bindToControlChange(0x0f, cc)
    .setTypeRelativeBinaryOffset();
}

/**
 * Sets up the bindings for the supplied encoder page button
 * @param {LaunchControlXl3.Config} config The configuration object
 * @param {MR_Button} button The button to setup
 * @param {number} index The index of the button
 */
function setupEncoderPageButton(config, button, index) {
  var midiValues = [midi.pageUp, midi.pageDown];
  setupMidiBinding(config, button, midiValues[index]);
}

/**
 * Sets up the bindings for the supplied fader
 * @param {LaunchControlXl3.Config} config The configuration object
 * @param {MR_SurfaceLabelField} labelField The label field for the faders
 * @param {MR_Fader} fader The fader to setup
 * @param {number} index The index of the fader
 */
function setupFader(config, labelField, fader, index) {
  if (labelField) {
    labelField.relateTo(fader);
  }
  var cc = 0x05 + index;
  var surfaceValue = fader.mSurfaceValue;

  surfaceValue.mMidiBinding
    .setInputPort(config.midiInput)
    .setOutputPort(config.midiOutput)
    .bindToControlChange(0x0f, cc);

  surfaceValue.mOnTitleChange = function (context, objectTitle, valueTitle) {
    screen.sendDisplayText(config, context, cc, 0, false, objectTitle);
    screen.sendDisplayText(config, context, cc, 1, true, valueTitle);
  };

  surfaceValue.mOnDisplayValueChange = function (context, value, units) {
    screen.sendDisplayText(config, context, cc, 2, true, value);
  };
}

/**
 * Sets up the bindings for the supplied track button
 * @param {LaunchControlXl3.Config} config The configuration object
 * @param {MR_Button} button The button to setup
 * @param {number} index The index of the button
 */
function setupTrackButton(config, button, index) {
  var midiValues = [midi.trackLeft, midi.trackRight];
  setupMidiBinding(config, button, midiValues[index]);
}

/**
 * Sets up the bindings for the supplied transport button
 * @param {LaunchControlXl3.Config} config The configuration object
 * @param {MR_Button} button The button to setup
 * @param {number} index The index of the button
 */
function setupTransportButton(config, button, index) {
  var midiValues = [midi.transport.record, midi.transport.play];
  setupMidiBinding(config, button, midiValues[index]);
}

module.exports = {
  makeUserInterface,
};
