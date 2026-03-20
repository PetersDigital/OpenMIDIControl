//-----------------------------------------------------------------------------
// Cubase / Nuendo 12+ Integration for Launchkey Mini MKIII
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
  'Launchkey Mini MK3',
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
deviceDriver
  .makeDetectionUnit()
  .detectPortPair(midiInput, midiOutput)
  .expectOutputNameContains('2')
  .expectOutputNameContains('Launchkey Mini MK3')
  .expectInputNameContains('2')
  .expectInputNameContains('Launchkey Mini MK3');

// Mac (has individual names for devices, so no identity response is needed)
// TODO: Check these values
deviceDriver
  .makeDetectionUnit()
  .detectPortPair(midiInput, midiOutput)
  .expectInputNameContains('Launchkey Mini MK3')
  .expectInputNameContains('DAW Port')
  .expectOutputNameContains('Launchkey Mini MK3')
  .expectOutputNameContains('DAW Port');

deviceDriver.mOnActivate = function (context) {
  var messages = [
    [0x9f, 0x0c, 0x7f], // set DAW mode
    // Set default modes for Pads, Faders and Knobs
    [0xbf, 0x03, 0x02], // pads = session
    [0xbf, 0x09, 0x01], // pots = volume
  ];
  messages.forEach(function (message) {
    midiOutput.sendMidi(context, message);
  });
  // reset all LEDs
  resetAllPads(context);
  console.log('INIT Launchkey Mini Integration');
};

deviceDriver.mOnDeactivate = function (context) {
  midiOutput.sendMidi(context, [0x9f, 0x0c, 0x00]); // set DAW mode off
};

var numChannels = 8;
var maxKnobModes = 6;
var maxPadModes = 3;
var maxSessionModes = 2;

/**
 *
 * @param {MR_ActiveDevice} context
 */
function resetAllPads(context) {
  for (var i = 0; i < 8; i++) {
    midiOutput.sendMidi(context, [0x90, 0x60 + i, 0]);
    midiOutput.sendMidi(context, [0x90, 0x70 + i, 0]);
  }
}

/**
 *
 * @param {number[]} arr
 * @returns {number[]}
 */
function makeSysex(arr) {
  return [0xf0, 0x00, 0x20, 0x29, 0x02, 0x0b].concat(arr, [0xf7]);
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

var potsAndPads = makePotsAndPads(deviceDriver.mSurface, 6.5, 0);

/**
 * Pad adjacent controls
 * @param {MR_DeviceSurface} s
 * @param {number} xOffset
 * @param {number} yOffset
 * @returns
 */
function makePadAdjacent(s, xOffset, yOffset) {
  var padAdjacent = {};

  padAdjacent.launch = s.makeButton(xOffset, yOffset + 3, 2, 2);
  padAdjacent.launch.mSurfaceValue.mMidiBinding
    .setInputPort(midiInput)
    .bindToControlChange(0x00, 0x68);

  padAdjacent.stopMuteSolo = s.makeButton(xOffset, yOffset + 5, 2, 2);

  padAdjacent.stopMuteSolo.mSurfaceValue.mMidiBinding
    .setInputPort(midiInput)
    .bindToControlChange(0x00, 0x69);

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

var padAdjacent = makePadAdjacent(deviceDriver.mSurface, 22.5, 0);

/**
 * Left controls, like track left, track right
 * @param {MR_DeviceSurface} s
 * @param {number} xOffset
 * @param {number} yOffset
 * @returns {object}
 */
function makeLeftButtons(s, xOffset, yOffset) {
  var leftButtons = {};
  leftButtons.shift = s.makeButton(xOffset, yOffset + 1, 1.5, 1);

  leftButtons.shift.mSurfaceValue.mMidiBinding
    .setInputPort(midiInput)
    .setOutputPort(midiOutput)
    .bindToControlChange(0x00, 0x6c);

  leftButtons.transpose = s.makeBlindPanel(xOffset, yOffset + 3, 1.5, 1);
  leftButtons.octaveMinus = s.makeBlindPanel(xOffset, yOffset + 5, 1.5, 1);
  leftButtons.octavePlus = s.makeBlindPanel(xOffset, yOffset + 6, 1.5, 1);

  return leftButtons;
}
var leftButtons = makeLeftButtons(deviceDriver.mSurface, 4.2, 0);

/**
 *
 * @param {MR_DeviceSurface} s
 * @returns {object}
 */
function makeKeyboard(s) {
  const features = {};
  features.keys = s.makePianoKeys(0, 7.5, 28.5, 7, 0, 24);
  features.pitchBend = s.makeBlindPanel(0, 1, 1.5, 6);
  features.modWheel = s.makeBlindPanel(2, 1, 1.5, 6);
  features.fakeNote = s.makeCustomValueVariable('fakeNote');
  features.fakeNote.mMidiBinding
    .setInputPort(midiInput)
    .setOutputPort(midiOutput)
    .bindToNote(0x0f, 0x0c);

  return features;
}
var keyboardFeatures = makeKeyboard(deviceDriver.mSurface);

/**
 * creates the transport controls
 * @param {MR_DeviceSurface} s
 * @param {number} xOffset
 * @param {number} yOffset
 * @returns {object}
 */
function makeTransport(s, xOffset, yOffset) {
  const transport = {};
  transport.trackLeft = s.makeButton(xOffset, yOffset + 2, 1.5, 1);
  transport.trackLeft.mSurfaceValue.mMidiBinding
    .setInputPort(midiInput)
    .setOutputPort(midiOutput)
    .bindToControlChange(0xf, 0x67);
  transport.trackRight = s.makeButton(xOffset + 1.7, yOffset + 2, 1.5, 1);
  transport.trackRight.mSurfaceValue.mMidiBinding
    .setInputPort(midiInput)
    .setOutputPort(midiOutput)
    .bindToControlChange(0xf, 0x66);

  transport.play = s.makeButton(xOffset, yOffset + 4, 1.5, 1);
  transport.play.mSurfaceValue.mMidiBinding
    .setInputPort(midiInput)
    .setOutputPort(midiOutput)
    .bindToControlChange(0xf, 0x73);
  transport.record = s.makeButton(xOffset + 1.7, yOffset + 4, 1.5, 1);
  transport.record.mSurfaceValue.mMidiBinding
    .setInputPort(midiInput)
    .setOutputPort(midiOutput)
    .bindToControlChange(0xf, 0x75);

  return transport;
}

var transport = makeTransport(deviceDriver.mSurface, 25.2, 2);

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
      if (name === 'Mute / Solo') {
        midiOutput.sendMidi(device, [0xb0, 0x69, 0x0e]);
      } else if (name == 'Select / Arm') {
        midiOutput.sendMidi(device, [0xb0, 0x69, 0x05]);
      } else if (name == 'Other') {
        midiOutput.sendMidi(device, [0xb0, 0x69, 0x00]);
      }
    }
    console.log(message);
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
      transport.record.mSurfaceValue,
      page.mHostAccess.mTransport.mValue.mRecord
    )
    .setTypeToggle();
  // page.makeCommandBinding(
  //   transport.captureMidi.mSurfaceValue,
  //   'Transport',
  //   'Global Retrospective Record'
  // );
  var knobSubPageArea = page.makeSubPageArea('Knobs');
  var subPagePan = makeSubPage(knobSubPageArea, 'knobs', 'Pan');
  var subPageVolume = makeSubPage(knobSubPageArea, 'knobs', 'Volume');
  var subPageDevice = makeSubPage(knobSubPageArea, 'knobs', 'Device');
  var subPageSend1 = makeSubPage(knobSubPageArea, 'knobs', 'Send 1');
  var subPageSend2 = makeSubPage(knobSubPageArea, 'knobs', 'Send 2');
  var subPageCustom = makeSubPage(knobSubPageArea, 'knobs', 'Custom');

  var shiftPageArea = page.makeSubPageArea('Shift');
  var subPageUnshifted = makeSubPage(shiftPageArea, 'shift', 'unshifted');
  var subPageShifted = makeSubPage(shiftPageArea, 'shift', 'shifted');

  var padSubPageArea = page.makeSubPageArea('Pads');

  var padSubPageSelectArm = makeSubPage(padSubPageArea, 'pads', 'Select / Arm');
  var padSubPageMuteSolo = makeSubPage(padSubPageArea, 'pads', 'Mute / Solo');
  var padSubPageOtherModes = makeSubPage(padSubPageArea, 'pads', 'Other');

  page.setLabelFieldSubPageArea(potsAndPads.labelFieldPots, knobSubPageArea);

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
    5: [subPageCustom, 0],
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
    1: [padSubPageOtherModes, 5],
    2: [padSubPageOtherModes, 1],
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

  var hostMixerBankZone = page.mHostAccess.mMixConsole
    .makeMixerBankZone()
    .excludeInputChannels()
    .excludeOutputChannels();

  page.makeActionBinding(
    transport.trackLeft.mSurfaceValue,
    page.mHostAccess.mTrackSelection.mAction.mPrevTrack
  );
  page.makeActionBinding(
    transport.trackRight.mSurfaceValue,
    page.mHostAccess.mTrackSelection.mAction.mNextTrack
  );

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
  }
  return page;
}

var mixerPage = makePage();
