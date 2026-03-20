//-----------------------------------------------------------------------------
// Cubase / Nuendo 12+ Integration for Launchkey MKIII
// (c) Focusrite PLC
// v1 written by Jan 'half/byte' Krutisch in Summer 2021
// With help from J.Trappe/ Steinberg
// jan@krutisch.de
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// 1. DRIVER SETUP - create driver object, midi ports and detection information
//-----------------------------------------------------------------------------

// get the api's entry point
const midiremote_api = require('midiremote_api_v1');

// create the device driver main object
const deviceDriver = midiremote_api.makeDeviceDriver(
  'Novation',
  'Launchkey MK3 88',
  'Focusrite PLC'
);

// create objects representing the hardware's MIDI ports
const midiInput = deviceDriver.mPorts.makeMidiInput();
const midiOutput = deviceDriver.mPorts.makeMidiOutput();

const COLORS = {
  mute: [15, 14],
  solo: [59, 57],
  recReady: [7, 5],
  select: [2, 3],
};

// Windows
// Windows
deviceDriver
  .makeDetectionUnit()
  .detectPortPair(midiInput, midiOutput)
  .expectInputNameContains('LKMK3 MIDI')
  .expectInputNameContains('MIDIIN')
  .expectOutputNameContains('LKMK3 MIDI')
  .expectOutputNameContains('MIDIOUT')
  .expectSysexIdentityResponse('002029', '4001', '0000');

// Windows RT
deviceDriver
  .makeDetectionUnit()
  .detectPortPair(midiInput, midiOutput)
  .expectInputNameContains('LKMK3 MIDI')
  .expectInputNameContains('Port 2')
  .expectOutputNameContains('LKMK3 MIDI')
  .expectOutputNameContains('Port 2')
  .expectSysexIdentityResponse('002029', '4001', '0000');

// Mac (has individual names for devices, so no identity response is needed)
deviceDriver
  .makeDetectionUnit()
  .detectPortPair(midiInput, midiOutput)
  .expectInputNameEquals('Launchkey MK3 88 LKMK3 DAW Out')
  .expectOutputNameEquals('Launchkey MK3 88 LKMK3 DAW In');

deviceDriver.mOnActivate = function (context) {
  var messages = [
    [0x9f, 0x0c, 0x7f], // set DAW mode
    // Set default modes for Pads, Faders and Knobs
    [0xbf, 0x03, 0x02], // pads = session
    [0xbf, 0x0a, 0x01], // faders = volume
    [0xbf, 0x09, 0x03], // pots = volume
    makeSysex(
      [0x04, 0x00].concat(textAsArray(midiremote_api.mDefaults.getAppName()))
    ),
    makeSysex([0x04, 0x01]),
    [0xb0, 0x6a, 0x00],
    [0xb0, 0x6b, 0x00],
  ];
  messages.forEach(function (message) {
    midiOutput.sendMidi(context, message);
  });
  resetAllPads(context);
  console.log('INIT Launchkey Integration LK88');
};

deviceDriver.mOnDeactivate = function (context) {
  midiOutput.sendMidi(context, [0x9f, 0x0c, 0x00]); // set DAW mode off
  console.log('TERM Launchkey Integration LK61');
};

var numChannels = 8;
var maxKnobModes = 8;
var maxPadModes = 8;
var maxFaderModes = 8;

/**
 *
 * @param {MR_ActiveDevice} context
 */
function resetAllPads(context) {
  for (var i = 0; i < 8; i++) {
    midiOutput.sendMidi(context, [0x90, 0x60 + i, 0]);
    midiOutput.sendMidi(context, [0x90, 0x70 + i, 0]);
    midiOutput.sendMidi(context, [0xb0, 0x25 + i, 0]);
  }
}

/**
 *
 * @param {number[]} arr
 * @returns {number[]}
 */
function makeSysex(arr) {
  return [0xf0, 0x00, 0x20, 0x29, 0x02, 0x12].concat(arr, [0xf7]);
}

/**
 *
 * @param {string} text
 * @returns {number[]}
 */
function textAsArray(text) {
  var ary = [];
  var i, l;
  l = text.length;
  for (i = 0; i < l; i++) {
    var charCode = text.charCodeAt(i);
    if (charCode >= 0x20 && charCode <= 0x7f) {
      ary.push(charCode);
    }
  }
  return ary;
}

/**
 *
 * @param {MR_ActiveDevice} context
 * @param {number} address
 * @param {string} text
 */
function sendSetParameterName(context, address, text) {
  var sysex = makeSysex([0x07, address].concat(textAsArray(text)));
  midiOutput.sendMidi(context, sysex);
}

/**
 *
 * @param {MR_ActiveDevice} context
 * @param {number} address
 * @param {string} value
 * @param {string} units
 */
function sendSetParameterValue(context, address, value, units) {
  var sysex = makeSysex([0x08, address].concat(textAsArray(value)));
  midiOutput.sendMidi(context, sysex);
}

/**
 * Send temporary text to text display
 * @param {MR_ActiveDevice} context
 * @param {number} row
 * @param {string} text
 */
function sendTemporaryText(context, row, text) {
  var sysex = makeSysex([0x09, row].concat(textAsArray(text)));
  midiOutput.sendMidi(context, sysex);
}

/**
 * set led color to correct color for function and value
 * @param {MR_ActiveDevice} context
 * @param {number} address
 * @param {string} func
 * @param {number} value
 */
function sendSetPadColor(context, address, func, value) {
  var color = COLORS[func][value];
  midiOutput.sendMidi(context, [0x90, address, color]);
}

/**
 * set led color to correct color for function and value
 * @param {MR_ActiveDevice} context
 * @param {number} address
 * @param {string} func
 * @param {number} value
 */
function sendSetButtonColor(context, address, func, value) {
  var color = COLORS[func][value];
  midiOutput.sendMidi(context, [0xb0, address, color]);
}

/**
 *
 * @param {MR_ActiveDevice} context
 * @param {number} address
 * @param {number[]} color
 * @param {number} value
 */
function sendSetRGBColor(context, address, color, value) {
  var correctedColor = color;
  if (value === 0) {
    correctedColor = darken(color);
  }
  var r = Math.round(correctedColor[0] * 127);
  var g = Math.round(correctedColor[1] * 127);
  var b = Math.round(correctedColor[2] * 127);

  var sysex = makeSysex([0x01, 0x43, address, r, g, b]);
  midiOutput.sendMidi(context, sysex);
}

/**
 *
 * @param {MR_ActiveDevice} context
 * @param {number} address
 * @param {number[]} color
 * @param {number} value
 */
function sendSetRGBButtonColor(context, address, color, value) {
  var correctedColor = color;
  if (value === 0) {
    correctedColor = darken(color);
  }
  var r = Math.round(correctedColor[0] * 127);
  var g = Math.round(correctedColor[1] * 127);
  var b = Math.round(correctedColor[2] * 127);

  var sysex = makeSysex([0x01, 0x53, address, r, g, b]);
  midiOutput.sendMidi(context, sysex);
}

/**
 * Darkens RGB colors to be able to show active and non active states
 * @param {Array} colorArray array of rgb colors
 * @returns {Array} array of darkened rgb colors
 */
function darken(colorArray) {
  var r = colorArray[0],
    g = colorArray[1],
    b = colorArray[2];
  var factor = 0.8;
  const highest = Math.max(r, g, b);
  const newHighest = highest - Math.min(highest, factor);
  const decreaseFraction = highest - newHighest / highest;
  return [
    r - r * decreaseFraction,
    g - g * decreaseFraction,
    b - b * decreaseFraction,
  ];
}

/**
 * Pots & Pads area
 * @param {MR_DeviceSurface} s
 * @param {number} xOffset
 * @param {number} yOffset
 * @returns {object}
 */
function makePotsAndPads(s, xOffset, yOffset) {
  var pots = [];
  var upperPads = [];
  var lowerPads = [];

  var labelFieldPots = s.makeLabelField(xOffset, yOffset, numChannels * 2, 1);

  for (var i = 0; i < numChannels; i++) {
    const knob = s.makeKnob(i * 2 + xOffset, yOffset + 1, 2, 2);

    labelFieldPots.relateTo(knob);

    knob.mSurfaceValue.mMidiBinding
      .setInputPort(midiInput)
      .bindToControlChange(0xf, 0x15 + i);

    const localAddress = 0x38 + i;
    knob.mSurfaceValue.mOnTitleChange = function (
      context,
      objectTitle,
      valueTitle
    ) {
      sendSetParameterName(
        context,
        this,
        valueTitle + ' (' + objectTitle + ')'
      );
    }.bind(localAddress);

    knob.mSurfaceValue.mOnDisplayValueChange = function (
      context,
      value,
      units
    ) {
      sendSetParameterValue(context, this, value, units);
    }.bind(localAddress);

    pots.push(knob);

    var channelSettings = {
      offset: i,
      r: 0,
      g: 0,
      b: 0,
      isActive: false,
      hasValueTitle: false,
    };

    const upperPad = s.makeTriggerPad(i * 2 + xOffset, yOffset + 3, 2, 2);
    upperPad.mSurfaceValue.mMidiBinding
      .setInputPort(midiInput)
      .bindToNote(0, 0x60 + i);

    upperPad.mSurfaceValue.mOnTitleChange = function (
      context,
      objectTitle,
      valueTitle
    ) {
      var offset = this.channelSettings.offset;
      var hasValueTitle = valueTitle.length !== 0;
      this.channelSettings.hasValueTitle = hasValueTitle;
      if (this.channelSettings.hasValueTitle === false)
        midiOutput.sendMidi(context, [0x90, 0x60 + offset, 0]);
    }.bind({channelSettings});

    upperPad.mSurfaceValue.mOnColorChange =
      /**
       * Save colors to be used in the
       * @param {MR_ActiveDevice} context
       * @param {number} r
       * @param {number} g
       * @param {number} b
       * @param {number} a
       * @param {boolean} isActive
       */
      function (context, r, g, b, a, isActive) {
        this.r = r;
        this.g = g;
        this.b = b;
      }.bind(channelSettings);

    upperPad.mSurfaceValue.mOnProcessValueChange = function (
      context,
      newValue
    ) {
      var offset = this.offset;
      if (!this.hasValueTitle) return;
      var state = context.getState('subpage.pads');
      if (state === 'Mute / Solo') {
        sendSetPadColor(context, 0x60 + offset, 'mute', newValue);
      } else if (state === 'Select / Arm') {
        sendSetPadColor(context, 0x60 + offset, 'select', newValue);
        sendSetRGBColor(
          context,
          0x60 + offset,
          [this.r, this.g, this.b],
          newValue
        );
      }
    }.bind(channelSettings);
    upperPads.push(upperPad);

    const lowerPad = s.makeTriggerPad(i * 2 + xOffset, yOffset + 5, 2, 2);
    lowerPad.mSurfaceValue.mMidiBinding
      .setInputPort(midiInput)
      .bindToNote(0, 0x70 + i);

    lowerPad.mSurfaceValue.mOnTitleChange = function (
      context,
      objectTitle,
      valueTitle
    ) {
      var offset = this.channelSettings.offset;
      var hasValueTitle = valueTitle.length !== 0;
      this.channelSettings.hasValueTitle = hasValueTitle;
      if (this.channelSettings.hasValueTitle === false)
        midiOutput.sendMidi(context, [0x90, 0x70 + offset, 0]);
    }.bind({channelSettings});

    lowerPad.mSurfaceValue.mOnColorChange = function (
      context,
      r,
      g,
      b,
      a,
      isActive
    ) {
      var offset = this;
    }.bind(i);

    lowerPad.mSurfaceValue.mOnProcessValueChange = function (
      context,
      newValue
    ) {
      var offset = this.offset;
      if (!this.hasValueTitle) return;
      var state = context.getState('subpage.pads');
      if (state === 'Mute / Solo') {
        sendSetPadColor(context, 0x70 + offset, 'solo', newValue);
      } else if (state === 'Select / Arm') {
        sendSetPadColor(context, 0x70 + offset, 'recReady', newValue);
      }
    }.bind(channelSettings);

    lowerPads.push(lowerPad);
  }
  return {pots, lowerPads, upperPads, labelFieldPots};
}

var potsAndPads = makePotsAndPads(deviceDriver.mSurface, 20, 0);

/**
 * Faders and Buttons area
 * @param {MR_DeviceSurface} s
 * @param {number} xOffset
 * @param {number} yOffset
 * @returns {object}
 */
function makeFadersAndButtons(s, xOffset, yOffset) {
  var faders = [];
  var buttons = [];

  var labelFieldFaders = s.makeLabelField(xOffset, yOffset, numChannels * 2, 1);

  for (var i = 0; i < numChannels; i++) {
    var channelSettings = {
      offset: i,
      r: 0,
      g: 0,
      b: 0,
      isActive: false,
      hasValueTitle: false,
    };

    var fader = s.makeFader(i * 2 + xOffset, yOffset + 1, 2, 5);
    labelFieldFaders.relateTo(fader);
    fader.mSurfaceValue.mMidiBinding
      .setInputPort(midiInput)
      .setOutputPort(midiOutput)
      .bindToControlChange(0x0f, 0x35 + i);
    faders.push(fader);

    var localAddress = 0x50 + i;
    fader.mSurfaceValue.mOnTitleChange = function (
      context,
      objectTitle,
      valueTitle
    ) {
      sendSetParameterName(context, this, valueTitle + ' (' + objectTitle + ')');
    }.bind(localAddress);

    fader.mSurfaceValue.mOnDisplayValueChange = function (
      context,
      value,
      units
    ) {
      sendSetParameterValue(context, this, value, units);
    }.bind(localAddress);

    var button = s.makeButton(i * 2 + xOffset, yOffset + 6, 2, 1);
    button.mSurfaceValue.mMidiBinding
      .setInputPort(midiInput)
      .bindToControlChange(0x0f, 0x25 + i);

    button.mSurfaceValue.mOnTitleChange = function (
      context,
      objectTitle,
      valueTitle
    ) {
      var offset = this.channelSettings.offset;
      var hasValueTitle = valueTitle.length !== 0;
      this.channelSettings.hasValueTitle = hasValueTitle;
      if (this.channelSettings.hasValueTitle === false)
        midiOutput.sendMidi(context, [0xb0, 0x25 + offset, 0]);
    }.bind({channelSettings});

    button.mSurfaceValue.mOnColorChange =
      /**
       * Save colors to be used in the
       * @param {MR_ActiveDevice} context
       * @param {number} r
       * @param {number} g
       * @param {number} b
       * @param {number} a
       * @param {boolean} isActive
       */
      function (context, r, g, b, a, isActive) {
        this.r = r;
        this.g = g;
        this.b = b;
      }.bind(channelSettings);

    button.mSurfaceValue.mOnProcessValueChange = function (context, value) {
      const offset = this.offset;
      if (!this.hasValueTitle) return;
      const state = context.getState('subpage.faderButtons');
      if (state === 'Arm') {
        sendSetButtonColor(context, 0x25 + offset, 'recReady', value);
      } else if (state === 'Select') {
        sendSetButtonColor(context, 0x25 + offset, 'select', value);
        sendSetRGBButtonColor(
          context,
          0x25 + offset,
          [this.r, this.g, this.b],
          value
        );
      }
    }.bind(channelSettings);

    buttons.push(button);
  }

  var faderModes = [];
  for (var fmi = 0; fmi < maxFaderModes; ++fmi) {
    var faderMode = s.makeCustomValueVariable('faderMode' + fmi.toString());
    faderMode.mMidiBinding
      .setInputPort(midiInput)
      .setOutputPort(midiOutput)
      .bindToControlChange(0x0f, 0x0a);
    faderModes.push(faderMode);
  }

  var masterFader = s.makeFader(xOffset + 16, yOffset + 1, 2, 5);
  masterFader.mSurfaceValue.mMidiBinding
    .setInputPort(midiInput)
    .setOutputPort(midiOutput)
    .bindToControlChange(0x0f, 0x3d);
  masterFader.mSurfaceValue.mOnTitleChange = function (
    context,
    objectTitle,
    valueTitle
  ) {
    sendSetParameterName(context, 0x58, valueTitle);
  };

  masterFader.mSurfaceValue.mOnDisplayValueChange = function (
    context,
    value,
    units
  ) {
    sendSetParameterValue(context, 0x58, value, units);
  };

  var armSelect = s.makeButton(xOffset + 16, yOffset + 6, 2, 1);
  armSelect.mSurfaceValue.mMidiBinding
    .setInputPort(midiInput)
    .bindToControlChange(0x0f, 0x2d);

  return {
    faders,
    buttons,
    masterFader,
    armSelect,
    faderModes,
    labelFieldFaders,
  };
}

var fadersAndButtons = makeFadersAndButtons(deviceDriver.mSurface, 39, 0);

/**
 * Pad adjacent controls
 * @param {MR_DeviceSurface} s
 * @param {number} xOffset
 * @param {number} yOffset
 * @returns
 */
function makePadAdjacent(s, xOffset, yOffset) {
  var padAdjacent = {};

  padAdjacent.up = s.makeButton(xOffset, yOffset + 3, 2, 2);
  padAdjacent.up.mSurfaceValue.mMidiBinding
    .setInputPort(midiInput)
    .bindToControlChange(0x0f, 0x6a);

  padAdjacent.down = s.makeButton(xOffset, yOffset + 5, 2, 2);
  padAdjacent.down.mSurfaceValue.mMidiBinding
    .setInputPort(midiInput)
    .bindToControlChange(0x0f, 0x6b);

  padAdjacent.launch = s.makeButton(xOffset + 18, yOffset + 3, 2, 2);
  padAdjacent.launch.mSurfaceValue.mMidiBinding
    .setInputPort(midiInput)
    .bindToControlChange(0x00, 0x68);

  padAdjacent.stopMuteSolo = s.makeButton(xOffset + 18, yOffset + 5, 2, 2);

  padAdjacent.stopMuteSolo.mSurfaceValue.mMidiBinding
    .setInputPort(midiInput)
    .bindToControlChange(0x00, 0x69);

  padAdjacent.deviceSelect = s.makeBlindPanel(
    xOffset + 18,
    yOffset + 0.75,
    2,
    1
  );
  padAdjacent.deviceLock = s.makeBlindPanel(xOffset + 18, yOffset + 1.75, 2, 1);

  padAdjacent.knobModes = [];
  for (var kmi = 0; kmi < maxKnobModes; ++kmi) {
    var knobMode = s.makeCustomValueVariable('knobMode' + kmi.toString());
    knobMode.mMidiBinding
      .setInputPort(midiInput)
      .setOutputPort(midiOutput)
      .bindToControlChange(0xf, 0x09);
    padAdjacent.knobModes.push(knobMode);
  }

  padAdjacent.padModes = [];
  for (var pmi = 0; pmi < maxPadModes; ++pmi) {
    var padMode = s.makeCustomValueVariable('padMode' + pmi.toString());
    padMode.mMidiBinding
      .setInputPort(midiInput)
      .setOutputPort(midiOutput)
      .bindToControlChange(0xf, 0x03);
    padAdjacent.padModes.push(padMode);
  }
  return padAdjacent;
}

var padAdjacent = makePadAdjacent(deviceDriver.mSurface, 18, 0);

/**
 * Left controls, like track left, track right
 * @param {MR_DeviceSurface} s
 * @param {number} xOffset
 * @param {number} yOffset
 * @returns {object}
 */
function makeLeftButtons(s, xOffset, yOffset) {
  var leftButtons = {};
  s = deviceDriver.mSurface;

  leftButtons.shift = s.makeButton(xOffset + 3, 3, 2, 1);

  leftButtons.shift.mSurfaceValue.mMidiBinding
    .setInputPort(midiInput)
    .setOutputPort(midiOutput)
    .bindToControlChange(0x00, 0x6c);

  leftButtons.settings = s.makeBlindPanel(xOffset + 5, 3, 2, 1);
  leftButtons.trackLeft = s.makeButton(xOffset + 3, 5, 2, 1);
  leftButtons.trackLeft.mSurfaceValue.mMidiBinding
    .setInputPort(midiInput)
    .setOutputPort(midiOutput)
    .bindToControlChange(0xf, 0x67);
  leftButtons.trackRight = s.makeButton(xOffset + 5, 5, 2, 1);
  leftButtons.trackRight.mSurfaceValue.mMidiBinding
    .setInputPort(midiInput)
    .setOutputPort(midiOutput)
    .bindToControlChange(0xf, 0x66);
  leftButtons.navigation = s.makeBlindPanel(xOffset + 3, 6, 2, 1);
  leftButtons.fixedChord = s.makeBlindPanel(xOffset + 5, 6, 2, 1);

  leftButtons.arp = s.makeBlindPanel(xOffset + 0, yOffset + 1, 2, 1);
  leftButtons.scale = s.makeBlindPanel(xOffset + 0, yOffset + 2.66, 2, 1);
  leftButtons.octaveMinus = s.makeBlindPanel(xOffset + 0, yOffset + 4.33, 2, 1);
  leftButtons.octavePlus = s.makeBlindPanel(xOffset + 0, yOffset + 6, 2, 1);

  return leftButtons;
}
var leftButtons = makeLeftButtons(deviceDriver.mSurface, 10, 0);

/**
 *
 * @param {MR_DeviceSurface} s
 * @returns {object}
 */
function makeKeyboard(s) {
  const features = {};
  features.keys = s.makePianoKeys(0, 9, 75, 8, 9, 96);
  features.pitchBend = s.makeBlindPanel(5.5, 1, 1, 5);
  features.modWheel = s.makeBlindPanel(7.5, 1, 1, 5);
  features.display = deviceDriver.mSurface.makeBlindPanel(13, 0, 4, 2);
  // This should block the "activate DAW mode" echo message (filters are not yet implemented)
  features.fakeNote = s.makeCustomValueVariable('fakeNote');
  features.fakeNote.mMidiBinding
    .setInputPort(midiInput)
    .setOutputPort(midiOutput)
    .bindToNote(0x0f, 0x0c);

  return features;
}

makeKeyboard(deviceDriver.mSurface);

/**
 * creates the transport controls
 * @param {MR_DeviceSurface} s
 * @param {number} xOffset
 * @param {number} yOffset
 * @returns {object}
 */
function makeTransport(s, xOffset, yOffset) {
  const transport = {};
  transport.captureMidi = s.makeButton(xOffset, yOffset, 2, 1);
  transport.captureMidi.mSurfaceValue.mMidiBinding
    .setInputPort(midiInput)
    .setOutputPort(midiOutput)
    .bindToControlChange(0xf, 0x4a);
  transport.quantize = s.makeButton(xOffset + 2, yOffset, 2, 1);
  transport.quantize.mSurfaceValue.mMidiBinding
    .setInputPort(midiInput)
    .setOutputPort(midiOutput)
    .bindToControlChange(0xf, 0x4b);
  transport.metronome = s.makeButton(xOffset + 4, yOffset, 2, 1);
  transport.metronome.mSurfaceValue.mMidiBinding
    .setInputPort(midiInput)
    .setOutputPort(midiOutput)
    .bindToControlChange(0xf, 0x4c);
  transport.undo = s.makeButton(xOffset + 6, yOffset, 2, 1);
  transport.undo.mSurfaceValue.mMidiBinding
    .setInputPort(midiInput)
    .setOutputPort(midiOutput)
    .bindToControlChange(0xf, 0x4d);

  transport.play = s.makeButton(xOffset, yOffset + 1, 2, 1);
  transport.play.mSurfaceValue.mMidiBinding
    .setInputPort(midiInput)
    .setOutputPort(midiOutput)
    .bindToControlChange(0xf, 0x73);
  transport.stop = s.makeButton(xOffset + 2, yOffset + 1, 2, 1);
  transport.stop.mSurfaceValue.mMidiBinding
    .setInputPort(midiInput)
    .setOutputPort(midiOutput)
    .bindToControlChange(0xf, 0x74);
  transport.record = s.makeButton(xOffset + 4, yOffset + 1, 2, 1);
  transport.record.mSurfaceValue.mMidiBinding
    .setInputPort(midiInput)
    .setOutputPort(midiOutput)
    .bindToControlChange(0xf, 0x75);
  transport.cycle = s.makeButton(xOffset + 6, yOffset + 1, 2, 1);
  transport.cycle.mSurfaceValue.mMidiBinding
    .setInputPort(midiInput)
    .setOutputPort(midiOutput)
    .bindToControlChange(0xf, 0x76);

  return transport;
}

var transport = makeTransport(deviceDriver.mSurface, 58, 5);

/**
 *
 * @param {MR_SubPageArea} subPageArea
 * @param {string} subPageAreaName
 * @param {string} name
 * @returns {MR_SubPage}
 */
function makeSubPage(subPageArea, subPageAreaName, name) {
  var subPage = subPageArea.makeSubPage(name);
  var message = 'SUB PAGE ACTIVATED: ' + subPageAreaName + ' - ' + name;
  subPage.mOnActivate = function (device) {
    if (name != null) {
      device.setState('subpage.' + subPageAreaName, name);
      if (subPageAreaName === 'pads') {
        if (name === 'Mute / Solo') {
          midiOutput.sendMidi(device, [0xb0, 0x69, 0x0e]);
          sendTemporaryText(device, 0, 'Pad Mode');
          sendTemporaryText(device, 1, 'Mute / Solo');
        } else if (name == 'Select / Arm') {
          sendTemporaryText(device, 0, 'Pad Mode');
          sendTemporaryText(device, 1, 'Select / Arm');
          midiOutput.sendMidi(device, [0xb0, 0x69, 0x05]);
        } else if (name == 'Other') {
          midiOutput.sendMidi(device, [0xb0, 0x69, 0x00]);
        }
      }
      if (subPageAreaName === 'faderButtons') {
        if (name === 'Arm') {
          sendTemporaryText(device, 0, 'Button Mode');
          sendTemporaryText(device, 1, 'Arm');
          midiOutput.sendMidi(device, [0xb0, 0x2d, 0x05]);
        } else if (name === 'Select') {
          sendTemporaryText(device, 0, 'Button Mode');
          sendTemporaryText(device, 1, 'Select');
          midiOutput.sendMidi(device, [0xb0, 0x2d, 0x03]);
        }
      }
    }
  };
  return subPage;
}

function makePage() {
  var page = deviceDriver.mMapping.makePage('Default');
  // Global mappings
  page
    .makeValueBinding(
      transport.play.mSurfaceValue,
      page.mHostAccess.mTransport.mValue.mStart
    )
    .setTypeToggle();
  page
    .makeValueBinding(
      transport.stop.mSurfaceValue,
      page.mHostAccess.mTransport.mValue.mStop
    )
    .setTypeToggle();
  page
    .makeValueBinding(
      transport.record.mSurfaceValue,
      page.mHostAccess.mTransport.mValue.mRecord
    )
    .setTypeToggle();
  page
    .makeValueBinding(
      transport.cycle.mSurfaceValue,
      page.mHostAccess.mTransport.mValue.mCycleActive
    )
    .setTypeToggle();
  page
    .makeValueBinding(
      transport.metronome.mSurfaceValue,
      page.mHostAccess.mTransport.mValue.mMetronomeActive
    )
    .setTypeToggle();
  page.makeCommandBinding(
    transport.captureMidi.mSurfaceValue,
    'Transport',
    'Global Retrospective Record'
  );
  page.makeCommandBinding(
    transport.quantize.mSurfaceValue,
    'Quantize Category',
    'Quantize'
  );

  var knobSubPageArea = page.makeSubPageArea('Knobs');
  var subPagePan = makeSubPage(knobSubPageArea, 'knobs', 'Pan');
  var subPageVolume = makeSubPage(knobSubPageArea, 'knobs', 'Volume');
  var subPageDevice = makeSubPage(knobSubPageArea, 'knobs', 'Device');
  var subPageSend1 = makeSubPage(knobSubPageArea, 'knobs', 'Send 1');
  var subPageSend2 = makeSubPage(knobSubPageArea, 'knobs', 'Send 2');

  var faderSubPageArea = page.makeSubPageArea('Faders');
  var faderButtonSubPageArea = page.makeSubPageArea('Fader Buttons');

  var faderSubPageVolume = makeSubPage(faderSubPageArea, 'faders', 'Volume');
  var faderSubPageDevice = makeSubPage(faderSubPageArea, 'faders', 'Device');
  var faderSubPageSend1 = makeSubPage(faderSubPageArea, 'faders', 'Send 1');
  var faderSubPageSend2 = makeSubPage(faderSubPageArea, 'faders', 'Send 2');

  var faderButtonSubPageArm = makeSubPage(
    faderButtonSubPageArea,
    'faderButtons',
    'Arm'
  );
  var faderButtonSubPageSelect = makeSubPage(
    faderButtonSubPageArea,
    'faderButtons',
    'Select'
  );

  var shiftPageArea = page.makeSubPageArea('Shift');
  var subPageUnshifted = makeSubPage(shiftPageArea, 'shift', 'unshifted');
  var subPageShifted = makeSubPage(shiftPageArea, 'shift', 'shifted');

  var padSubPageArea = page.makeSubPageArea('Pads');

  var padSubPageSelectArm = makeSubPage(padSubPageArea, 'pads', 'Select / Arm');
  var padSubPageMuteSolo = makeSubPage(padSubPageArea, 'pads', 'Mute / Solo');
  var padSubPageOtherModes = makeSubPage(padSubPageArea, 'pads', 'Other');

  page.setLabelFieldSubPageArea(potsAndPads.labelFieldPots, knobSubPageArea);
  page.setLabelFieldSubPageArea(
    fadersAndButtons.labelFieldFaders,
    faderSubPageArea
  );

  page
    .makeActionBinding(
      leftButtons.shift.mSurfaceValue,
      subPageShifted.mAction.mActivate
    )
    .setSubPage(subPageUnshifted);
  page
    .makeActionBinding(
      leftButtons.shift.mSurfaceValue,
      subPageUnshifted.mAction.mActivate
    )
    .setSubPage(subPageShifted)
    .mapToValueRange(1, 0);

  var knobModeSetupMap = {
    0: [subPageDevice, 2],
    1: [subPageVolume, 1],
    2: [subPagePan, 3],
    3: [subPageSend1, 4],
    4: [subPageSend2, 5],
  };

  for (var kmi = 0; kmi < maxKnobModes; ++kmi) {
    /** @type {MR_SurfaceCustomValueVariable} */
    var knobMode = padAdjacent.knobModes[kmi];
    var knobModeSetup = knobModeSetupMap[kmi];
    if (!knobModeSetup) continue;
    /** @type {MR_SubPage} */
    var subPage = knobModeSetup[0];
    var ccVal = knobModeSetup[1];
    var filterValueNormalized = ccVal / 127;
    page
      .makeActionBinding(knobMode, subPage.mAction.mActivate)
      .filterByValue(filterValueNormalized);
  }

  var padModeSetupMap = {
    0: [padSubPageSelectArm, 2],
    1: [padSubPageOtherModes, 1],
    2: [padSubPageOtherModes, 3],
    3: [padSubPageOtherModes, 4],
    4: [padSubPageOtherModes, 5],
    5: [padSubPageOtherModes, 6],
    6: [padSubPageOtherModes, 7],
    7: [padSubPageOtherModes, 8],
  };

  for (var pmi = 0; pmi < maxPadModes; ++pmi) {
    /** @type {MR_SurfaceCustomValueVariable} */
    var padMode = padAdjacent.padModes[pmi];
    var padModeSetup = padModeSetupMap[pmi];
    if (!padModeSetup) continue;
    /** @type {MR_SubPage} */
    var subPage = padModeSetup[0];
    var ccVal = padModeSetup[1];
    var filterValueNormalized = ccVal / 127;
    page
      .makeActionBinding(padMode, subPage.mAction.mActivate)
      .filterByValue(filterValueNormalized);
  }

  var faderModeSetupMap = {
    0: [faderSubPageDevice, 2],
    1: [faderSubPageVolume, 1],
    2: [faderSubPageSend1, 4],
    3: [faderSubPageSend2, 5],
  };

  for (var fmi = 0; fmi < maxFaderModes; ++fmi) {
    /** @type {MR_SurfaceCustomValueVariable} */
    var faderMode = fadersAndButtons.faderModes[fmi];
    var faderModeSetup = faderModeSetupMap[fmi];
    if (!faderModeSetup) continue;
    /** @type {MR_SubPage} */
    var subPage = faderModeSetup[0];
    var ccVal = faderModeSetup[1];
    var filterValueNormalized = ccVal / 127;
    page
      .makeActionBinding(faderMode, subPage.mAction.mActivate)
      .filterByValue(filterValueNormalized);
  }

  var hostMixerBankZone = page.mHostAccess.mMixConsole
    .makeMixerBankZone()
    .excludeInputChannels()
    .excludeOutputChannels();

  page
    .makeActionBinding(
      leftButtons.trackLeft.mSurfaceValue,
      hostMixerBankZone.mAction.mPrevBank
    )
    .setSubPage(subPageUnshifted);
  page
    .makeActionBinding(
      leftButtons.trackRight.mSurfaceValue,
      hostMixerBankZone.mAction.mNextBank
    )
    .setSubPage(subPageUnshifted);

  page
    .makeActionBinding(
      leftButtons.trackLeft.mSurfaceValue,
      page.mHostAccess.mTrackSelection.mAction.mPrevTrack
    )
    .setSubPage(subPageShifted);
  page
    .makeActionBinding(
      leftButtons.trackRight.mSurfaceValue,
      page.mHostAccess.mTrackSelection.mAction.mNextTrack
    )
    .setSubPage(subPageShifted);

  page
    .makeCommandBinding(transport.undo.mSurfaceValue, 'Edit', 'Undo')
    .setSubPage(subPageUnshifted);
  page
    .makeCommandBinding(transport.undo.mSurfaceValue, 'Edit', 'Redo')
    .setSubPage(subPageShifted);

  page
    .makeActionBinding(
      padAdjacent.stopMuteSolo.mSurfaceValue,
      padSubPageMuteSolo.mAction.mActivate
    )
    .setSubPage(padSubPageSelectArm);

  page
    .makeActionBinding(
      padAdjacent.stopMuteSolo.mSurfaceValue,
      padSubPageSelectArm.mAction.mActivate
    )
    .setSubPage(padSubPageMuteSolo);

  page
    .makeActionBinding(
      padAdjacent.stopMuteSolo.mSurfaceValue,
      padSubPageOtherModes.mAction.mActivate
    )
    .setSubPage(padSubPageOtherModes);

  page.makeActionBinding(
    fadersAndButtons.armSelect.mSurfaceValue,
    faderButtonSubPageArea.mAction.mNext
  );

  var mixerBankZoneStereoOut = page.mHostAccess.mMixConsole
    .makeMixerBankZone('Stereo Out')
    .includeOutputChannels(); // additional mixerbankzone decorated with channel type filter
  var firstStereoOut = mixerBankZoneStereoOut.makeMixerBankChannel();
  page
    .makeValueBinding(
      fadersAndButtons.masterFader.mSurfaceValue,
      firstStereoOut.mValue.mVolume
    )
    .setValueTakeOverModeScaled();

  for (var channelIndex = 0; channelIndex < numChannels; ++channelIndex) {
    var hostMixerBankChannel = hostMixerBankZone.makeMixerBankChannel();
    var quickControls = page.mHostAccess.mFocusedQuickControls;

    var knobSurfaceValue = potsAndPads.pots[channelIndex].mSurfaceValue;
    var quickControl = quickControls.getByIndex(channelIndex);
    page
      .makeValueBinding(knobSurfaceValue, quickControl)
      .setSubPage(subPageDevice)
      .setValueTakeOverModeScaled();

    page
      .makeValueBinding(knobSurfaceValue, hostMixerBankChannel.mValue.mVolume)
      .setSubPage(subPageVolume)
      .setValueTakeOverModeScaled();

    page
      .makeValueBinding(knobSurfaceValue, hostMixerBankChannel.mValue.mPan)
      .setSubPage(subPagePan)
      .setValueTakeOverModeScaled();

    var sendLevel1 = hostMixerBankChannel.mSends.getByIndex(0).mLevel;
    page
      .makeValueBinding(knobSurfaceValue, sendLevel1)
      .setSubPage(subPageSend1)
      .setValueTakeOverModeScaled();

    var sendLevel2 = hostMixerBankChannel.mSends.getByIndex(1).mLevel;
    page
      .makeValueBinding(knobSurfaceValue, sendLevel2)
      .setSubPage(subPageSend2)
      .setValueTakeOverModeScaled();

    var upperPadSurfaceValue =
      potsAndPads.upperPads[channelIndex].mSurfaceValue;
    var lowerPadSurfaceValue =
      potsAndPads.lowerPads[channelIndex].mSurfaceValue;
    page
      .makeValueBinding(
        upperPadSurfaceValue,
        hostMixerBankChannel.mValue.mSelected
      )
      .setSubPage(padSubPageSelectArm)
      .setTypeToggle();
    page
      .makeValueBinding(
        lowerPadSurfaceValue,
        hostMixerBankChannel.mValue.mRecordEnable
      )
      .setSubPage(padSubPageSelectArm)
      .setTypeToggle();
    page
      .makeValueBinding(upperPadSurfaceValue, hostMixerBankChannel.mValue.mMute)
      .setSubPage(padSubPageMuteSolo)
      .setTypeToggle();
    page
      .makeValueBinding(lowerPadSurfaceValue, hostMixerBankChannel.mValue.mSolo)
      .setSubPage(padSubPageMuteSolo)
      .setTypeToggle();

    const faderValue = fadersAndButtons.faders[channelIndex].mSurfaceValue;

    page
      .makeValueBinding(faderValue, quickControl)
      .setSubPage(faderSubPageDevice)
      .setValueTakeOverModeScaled();

    page
      .makeValueBinding(faderValue, hostMixerBankChannel.mValue.mVolume)
      .setSubPage(faderSubPageVolume)
      .setValueTakeOverModeScaled();

    page
      .makeValueBinding(faderValue, sendLevel1)
      .setSubPage(faderSubPageSend1)
      .setValueTakeOverModeScaled();
    page
      .makeValueBinding(faderValue, sendLevel2)
      .setSubPage(faderSubPageSend2)
      .setValueTakeOverModeScaled();

    const buttonValue = fadersAndButtons.buttons[channelIndex].mSurfaceValue;

    page
      .makeValueBinding(buttonValue, hostMixerBankChannel.mValue.mRecordEnable)
      .setSubPage(faderButtonSubPageArm)
      .setTypeToggle();

    page
      .makeValueBinding(buttonValue, hostMixerBankChannel.mValue.mSelected)
      .setSubPage(faderButtonSubPageSelect)
      .setTypeToggle();
  }
  return page;
}

var mixerPage = makePage();
