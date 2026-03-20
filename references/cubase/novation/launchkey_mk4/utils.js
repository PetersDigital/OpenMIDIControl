var commonConstants = require('../common/constants');
var screen = require('../common/screen');
var utils = require('../common/base_utils');
var constants = require('./lk4_constants');

/**
 * Detects Cubase API features
 * @param {LaunchkeyMk4.Config} config
 * @param {LaunchkeyMk4.UserInterface} ui
 */
function detectApiFeatures(config, ui) {
  config.hasIdleCallbacks =
    ui.trackButtons.shift.mSurfaceValue.mTouchState != null;
}

/**
 * Handles mOnTitleChange callbacks for encoders.
 * @param {LaunchkeyMk4.Config} config
 * @param {number} address Encoder cc number
 * @returns {(arg0: MR_ActiveDevice, arg1: string, arg2: string) => void} Callback function to handle mOnTitleChange for encoders
 */
function encoderOnTitleChangeCallback(config, address) {
  return function (context, objectTitle, valueTitle) {
    if (hasTransportPageActivatedRecently(config, context)) {
      // Ignore title changes for transport encoders when the transport page has been recently activated
      return;
    }
    var parameterName = utils.mapEncoderParameterName(objectTitle, valueTitle);
    screen.sendDisplayText(config, context, address, 1, false, parameterName);
    context.setState(
      commonConstants.STATE_KEYS.lastEncoderDisplayTime,
      Date.now().toString()
    );
  };
}

/**
 * Handles mOnDisplayValueChange callbacks for encoders.
 * @param {LaunchkeyMk4.Config} config
 * @param {number} address Encoder cc number
 * @returns {(arg0: MR_ActiveDevice, arg1: string, arg2: string) => void} Callback function to handle mOnDisplayValueChange for encoders
 */
function encoderOnValueChangeCallback(config, address) {
  return function (context, value, units) {
    if (hasTransportPageActivatedRecently(config, context)) {
      // Ignore title changes for transport encoders when the transport page has been recently activated
      return;
    }
    var encoderTitle = getEncoderTitle(context, address);
    screen.sendDisplayText(config, context, address, 0, false, encoderTitle);
    screen.sendDisplayText(config, context, address, 2, false, value);
    context.setState(
      commonConstants.STATE_KEYS.lastEncoderDisplayTime,
      Date.now().toString()
    );
  };
}

/**
 * Handles mOnTitleChange callbacks for faders.
 * @param {LaunchkeyMk4.Config} config
 * @param {number} address Fader cc number
 * @returns {(arg0: MR_ActiveDevice, arg1: string, arg2: string) => void} Callback function to handle mOnTitleChange for faders
 */
function faderOnTitleChangeCallback(config, address) {
  return function (context, objectTitle, valueTitle) {
    screen.sendDisplayText(config, context, address, 0, false, objectTitle);
    screen.sendDisplayText(config, context, address, 1, true, valueTitle);
  };
}

/**
 * Handles mOnDisplayValueChange callbacks for faders.
 * @param {LaunchkeyMk4.Config} config
 * @param {number} address Fader cc number
 * @returns {(arg0: MR_ActiveDevice, arg1: string, arg2: string) => void} Callback function to handle mOnDisplayValueChange for faders
 */
function faderOnValueChangeCallback(config, address) {
  return function (context, value, units) {
    screen.sendDisplayText(config, context, address, 2, true, value);
  };
}

/**
 * Gets the active encoder subpage name
 * @param {MR_ActiveDevice} context
 * @returns The active encoder subpage
 */
function getActiveEncoderSubPage(context) {
  return context.getState('subpage.Encoders');
}

/**
 * Gets the title of the encoder based on the current subpage and matching the supplied encoder address
 * @param {MR_ActiveDevice} context
 * @param {number} address Encoder cc number
 * @returns {string} The title of the encoder
 */
function getEncoderTitle(context, address) {
  var title = '';
  var activeEncoderSubPage = getActiveEncoderSubPage(context);
  if (activeEncoderSubPage === 'Transport') {
    title = 'Transport';
  } else if (['EQ', 'Quick Controls'].indexOf(activeEncoderSubPage) !== -1) {
    title = utils.getSelectedTrackName(context);
  } else {
    title = utils.getTrackName(context, address - 0x15);
  }
  return title;
}

/**
 * Checks if the transport encoder page has been recently activated (in the last 100ms) and that the shift key is down.
 * @param {LaunchkeyMk4.Config} config
 * @param {MR_ActiveDevice} context
 * @returns {boolean} True if the transport encoder page has been recently activated and the shift key is down, otherwise false.
 */
function hasTransportPageActivatedRecently(config, context) {
  var activeEncoderSubPage = getActiveEncoderSubPage(context);
  if (activeEncoderSubPage === 'Transport') {
    var key = commonConstants.STATE_KEYS.lastSubpageActivedTime;
    var lastSubpageActivedTime = utils.getStateInt(context, key, 0);
    if (Date.now() - lastSubpageActivedTime < config.staleDisplayTimeout) {
      return context.getState('subpage.Shift') === 'shifted';
    }
  }
  return false;
}

/**
 * reset all pad colors
 * @param {LaunchkeyMk4.Config} config
 * @param {MR_ActiveDevice} context Active device
 */
function resetAllPads(config, context) {
  if (config.layoutConfig.hasFaders) {
    for (var i = 0; i < 8; i++) {
      // The pads are not reset anymore because the default mode is drum mode and so the colours are controlled by firmware
      config.midiOutput.sendMidi(context, [0xb0, 0x25 + i, 0]); // Set LED colour of fader buttons
    }
    config.midiOutput.sendMidi(context, [0xb0, 0x2d, 0]); // Set LED colour of last fader button
  }
}

/**
 * Clears the display text on all encoders if the last encoder display update was more than `config.staleDisplayTimeout` milliseconds ago
 * @param {LaunchkeyMk4.Config} config
 * @param {MR_ActiveDevice} context
 */
function resetStaleEncoderDisplays(config, context) {
  var lastEncoderDisplayTimeKey =
    commonConstants.STATE_KEYS.lastEncoderDisplayTime;
  var lastEncoderDisplayTime = utils.getStateInt(
    context,
    lastEncoderDisplayTimeKey,
    0
  );
  var now = Date.now();
  if (now - lastEncoderDisplayTime > config.staleDisplayTimeout) {
    sendAllEncodersDisplayText(config, context, '', '', '');
    context.setState(lastEncoderDisplayTimeKey, now.toString());
  }
}

/**
 * Sends the display text to all encoder displays
 * @param {LaunchkeyMk4.Config} config
 * @param {MR_ActiveDevice} context
 * @param {string} title
 * @param {string} name
 * @param {string} value
 */
function sendAllEncodersDisplayText(config, context, title, name, value) {
  for (var index = 0; index < config.numChannels; index++) {
    var address = 0x15 + index;
    screen.sendDisplayText(config, context, address, 0, false, title);
    screen.sendDisplayText(config, context, address, 1, false, name);
    screen.sendDisplayText(config, context, address, 2, false, value);
  }
}

/**
 * Sends the display title text to all encoders
 * @param {LaunchkeyMk4.Config} config
 * @param {MR_ActiveDevice} context
 * @param {string} title - The title to display if supplied, otherwise the title is retrieved from the device state
 */
function sendAllEncodersDisplayTitle(config, context, title) {
  for (var index = 0; index < config.numChannels; index++) {
    var address = 0x15 + index;
    if (title === undefined) {
      title = getEncoderTitle(context, address);
    }
    screen.sendDisplayText(config, context, address, 0, false, title);
  }
}

/**
 * Sends the sysex message to set the mode change display text
 * @param {LaunchkeyMk4.Config} config
 * @param {MR_ActiveDevice} context
 * @param {string} name
 */
function sendEncodersModeChange(config, context, name) {
  // Set encoders to relative mode
  config.midiOutput.sendMidi(context, [0xb6, 0x45, 0x7f]);

  // Configure the displays for the new mode
  var displayConfig = name === 'Transport' ? 0x22 : 0x62;
  utils.configureDisplayGroup(config, context, 0x15, 0x1c, displayConfig);

  if (name.indexOf('Sends') === 0) {
    screen.sendOverlayDisplayText(
      config,
      context,
      'Sends',
      'Slot ' + name.slice(6)
    );
    updatePageButtonLeds(
      config,
      context,
      0x33,
      0x34,
      name !== 'Sends 1',
      name !== 'Sends 8'
    );
    resetStaleEncoderDisplays(config, context);
  } else {
    switch (name) {
      case 'Volume':
      case 'Pan':
      case 'EQ':
        screen.sendOverlayDisplayText(config, context, 'Mixer', name);
        updatePageButtonLeds(
          config,
          context,
          0x33,
          0x34,
          name !== 'Volume',
          name !== 'EQ'
        );
        resetStaleEncoderDisplays(config, context);
        break;
      case 'Quick Controls':
        screen.sendOverlayDisplayText(config, context, 'Pot Mode', 'Plugin');
        updatePageButtonLeds(config, context, 0x33, 0x34, false, false);
        var title = getEncoderTitle(context, 0x15);
        resetStaleEncoderDisplays(config, context);
        break;
      case 'Transport':
        screen.sendOverlayDisplayText(config, context, 'Pot Mode', 'Transport');
        updatePageButtonLeds(config, context, 0x33, 0x34, false, false);
        sendTransportEncoderNames(config, context);
        break;
      default:
        updatePageButtonLeds(config, context, 0x33, 0x34, null, null);
        break;
    }
  }

  if (name === 'Transport') {
    screen.sendPermanentDisplayGrid(config, context, 'Transport', [
      'Scrb',
      'Zoom',
      'LLoc',
      'RLoc',
      'Mark',
      '',
      '',
      'BPM',
    ]);
  } else {
    screen.sendPermanentDisplayText(config, context, ['', config.appName, '']);
  }
}

/**
 * Sends the sysex message to set the mode change display text and updates the colour of the arm/select button
 * @param {LaunchkeyMk4.Config} config
 * @param {MR_ActiveDevice} device
 * @param {string} name
 */
function sendFaderButtonsModeChange(config, device, name) {
  if (config.layoutConfig.hasFaders) {
    if (name === 'Arm') {
      screen.sendOverlayDisplayText(config, device, 'Button Mode', 'Arm');
      config.midiOutput.sendMidi(device, [0xb0, 0x2d, 0x05]); // Set the colour of the arm/select button
    } else if (name === 'Select') {
      screen.sendOverlayDisplayText(config, device, 'Button Mode', 'Select');
      config.midiOutput.sendMidi(device, [0xb0, 0x2d, 0x03]); // Set the colour of the arm/select button
    }
  }
}

/**
 * Sends the sysex message to set the mode change display text
 * @param {LaunchkeyMk4.Config} config
 * @param {MR_ActiveDevice} device
 * @param {string} name
 */
function sendPadsModeChange(config, device, name) {
  if (name === 'Mute / Solo') {
    screen.sendOverlayDisplayText(config, device, 'Solo', 'Mute');
    updatePageButtonLeds(config, device, 0x6a, 0x6b, true, false);
  } else if (name == 'Select / Arm') {
    screen.sendOverlayDisplayText(config, device, 'Select', 'Arm');
    updatePageButtonLeds(config, device, 0x6a, 0x6b, false, true);
  } else {
    updatePageButtonLeds(config, device, 0x6a, 0x6b, null, null);
  }
}

/**
 * Sends the display text values for Transport encoders
 *
 * @param {LaunchkeyMk4.Config} config
 * @param {MR_ActiveDevice} context
 */
function sendTransportEncoderNames(config, context) {
  for (var index = 0; index < config.numChannels; index++) {
    var address = 0x15 + index;
    var text = constants.TRANSPORT_ENCODER_NAMES[index] || '';
    screen.sendDisplayText(config, context, address, 0, false, '');
    screen.sendDisplayText(config, context, address, 1, false, text);
    screen.sendDisplayText(config, context, address, 2, false, '');
  }
}

/**
 * Starts the idle listener to send the display cache when the device is idle
 * @param {Config} config
 */
function startIdleListener(config) {
  config.deviceDriver.mOnIdle = function (activeDevice) {
    screen.sendDisplayCache(config, activeDevice);
  };
}

/**
 *
 * @param {LaunchkeyMk4.Config} config
 * @param {MR_ActiveDevice} context
 * @param {number} ccUp
 * @param {number} ccDown
 * @param {boolean | null} enableUp
 * @param {boolean | null} enableDown
 */
function updatePageButtonLeds(
  config,
  context,
  ccUp,
  ccDown,
  enableUp,
  enableDown
) {
  var up = 0;
  if (typeof enableUp === 'boolean') {
    up = enableUp ? constants.BRIGHTNESS[1] : constants.BRIGHTNESS[0];
  }
  var down = 0;
  if (typeof enableDown === 'boolean') {
    down = enableDown ? constants.BRIGHTNESS[1] : constants.BRIGHTNESS[0];
  }
  config.midiOutput.sendMidi(context, [0xb3, ccUp, up]);
  config.midiOutput.sendMidi(context, [0xb3, ccDown, down]);
}

Object.assign(utils, {
  detectApiFeatures,
  encoderOnTitleChangeCallback,
  encoderOnValueChangeCallback,
  faderOnTitleChangeCallback,
  faderOnValueChangeCallback,
  getActiveEncoderSubPage,
  resetAllPads,
  sendAllEncodersDisplayTitle,
  sendEncodersModeChange,
  sendFaderButtonsModeChange,
  sendPadsModeChange,
  startIdleListener,
});

module.exports = utils;
