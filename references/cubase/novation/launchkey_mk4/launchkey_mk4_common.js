var screen = require('../common/screen');
var constants = require('./lk4_constants');
var utils = require('./utils');
var userInterface = require('./user_interface');
var makeHostBindings = require('./host_bindings');

/**
 *
 * @param {MR_MidiRemoteAPI} midiRemoteApi
 * @param {number} sku
 * @param {number} pid1
 * @param {number} pid2
 * @param {LaunchkeyMk4.LayoutConfig} layoutConfig
 */
function moduleForDevice(
  midiRemoteApi,
  sku,
  pid1,
  pid2,
  familyCode,
  layoutConfig
) {
  var appName = midiRemoteApi.mDefaults.getAppName();
  var skuString = sku.toString();
  var isMini = layoutConfig.isMini;
  var deviceName = getDeviceName(skuString, isMini);

  // create the device driver main object
  var deviceDriver = midiRemoteApi.makeDeviceDriver(
    'Novation',
    deviceName,
    'Focusrite PLC'
  );

  // create objects representing the hardware's MIDI ports
  var midiInput = deviceDriver.mPorts.makeMidiInput();
  var midiOutput = deviceDriver.mPorts.makeMidiOutput();

  var maxEncoderModes = 8;
  var maxFaderModes = 5;
  var maxPadModes = 8;
  var numChannels = 8;
  var maxSendSlots = midiRemoteApi.mDefaults.getNumberOfSendSlots();

  /** @type LaunchkeyMk4.Config */
  var config = {
    appName,
    deviceDriver,
    midiInput,
    midiOutput,
    pid1,
    pid2,
    layoutConfig,
    maxEncoderModes,
    maxFaderModes,
    maxPadModes,
    maxSendSlots,
    numChannels,
    displayPriorityTimeout: 50,
    eqAutoOnTimeout: 100,
    staleDisplayTimeout: 100,
    hasIdleCallbacks: false,
    updateDisplayAtIdleTime: false,
    permanentDisplayTarget: 0x20,
    overlayDisplayTarget: 0x21,
  };
  utils.startIdleListener(config);

  ////////////////////////////// INIT

  // Windows
  deviceDriver
    .makeDetectionUnit()
    .detectPortPair(midiInput, midiOutput)
    .expectInputNameContains(getWinPortPartialName(isMini))
    .expectInputNameContains('MIDIIN2')
    .expectOutputNameContains(getWinPortPartialName(isMini))
    .expectOutputNameContains('MIDIOUT2')
    .expectSysexIdentityResponse('002029', familyCode, '0001');

  // Windows RT is the same as Mac so don't have separate detection for WinRT and Mac because that will cause duplicate renders in the Cubase MIDI Remote tab

  // Mac (has individual names for devices, so no identity response is needed)
  deviceDriver
    .makeDetectionUnit()
    .detectPortPair(midiInput, midiOutput)
    .expectInputNameEquals(getMacPortName(true, skuString, isMini))
    .expectOutputNameEquals(getMacPortName(false, skuString, isMini));

  deviceDriver.mOnActivate = function (context) {
    var messages = [
      // Put device into DAW mode
      [0x9f, 0x0c, 0x7f],

      // Set default modes for Pads, Faders and Encoders
      // Ensure that the first sub page for each sub page area matches these defaults to ensure Cubase activates the correct page on initialisation
      [0xb6, constants.CC_MODES.encoder, 0x02], // encoders = plugin
      [0xb6, constants.CC_MODES.pad, 0x02], // pads = DAW
      [0xb6, constants.CC_MODES.fader, 0x01], // faders = volume

      [0xb6, 0x54, 0x7f], // Drumrak ownership

      // Configure the overlay display to be 2 lines with no auto generation
      utils.makeSysex(config, [0x04, config.overlayDisplayTarget, 0x01]),

      // Configure the permanent display to be 3 lines with no auto generation
      utils.makeSysex(config, [0x04, config.permanentDisplayTarget, 0x02]),

      // Set encoders to relative mode
      [0xb6, 0x45, 0x7f],

      // Light up the workflow buttons
      [0xb3, 0x4a, constants.BRIGHTNESS[0]], // Capture MIDI
      [0xb3, 0x4b, constants.BRIGHTNESS[0]], // Quantize
      [0xb3, 0x4d, constants.BRIGHTNESS[0]], // Undo

      [0xb3, 0x67, constants.BRIGHTNESS[1]], // Track Left
      [0xb3, 0x66, constants.BRIGHTNESS[1]], // Track right

      // Configure the master fader display to be ID 2 (3 lines) and auto-trigger display
      utils.makeSysex(config, [0x04, 0x0d, 0x42]),
    ];
    for (var i = 0; i < 8; i++) {
      // Configure each fader display to be ID 2 (3 lines) and auto-trigger display
      messages.push(utils.makeSysex(config, [0x04, 0x05 + i, 0x42]));
    }
    messages.forEach(function (message) {
      midiOutput.sendMidi(context, message);
    });

    // Send the app name to the permanent display
    screen.sendPermanentDisplayText(config, context, ['', appName, '']);

    // reset all LEDs
    utils.resetAllPads(config, context);

    console.log('INIT ' + deviceName + ' Integration');
  };

  deviceDriver.mOnDeactivate = function (context) {
    midiOutput.sendMidi(context, [0xb6, 0x54, 0x00]); // Release drumrack ownership
    midiOutput.sendMidi(context, [0x9f, 0x0c, 0x00]); // set DAW mode off
    console.log('UNINIT ' + deviceName + ' Integration');
  };

  //////////////////// Setup UI

  var ui = userInterface.makeUserInterface(config);
  utils.detectApiFeatures(config, ui);

  //////////////////// Setup Bindings

  makeHostBindings(config, ui);

  //////////////////// Functions
}

/**
 * Gets the device name specific to the supplied sku and mini flag
 * @param {string} skuString
 * @param {boolean} isMini
 * @returns Device specific name
 */
function getDeviceName(skuString, isMini) {
  return [isMini ? 'Launchkey Mini MK4' : 'Launchkey MK4', skuString].join(' ');
}

/**
 * Get the Windows port partial name to use in device detection
 * @param {boolean} isMini
 * @returns Windows port name to use in device detection
 */
function getWinPortPartialName(isMini) {
  return isMini ? 'Launchkey Mini MK4' : 'Launchkey MK4';
}

/**
 * Get the Mac port name to use in device detection
 * @param {boolean} inPort
 * @param {string} skuString
 * @param {boolean} isMini
 * @returns Mac port name to use in device detection
 */
function getMacPortName(inPort, skuString, isMini) {
  return [
    isMini ? 'Launchkey Mini MK4' : 'Launchkey MK4',
    skuString,
    inPort ? 'DAW Out' : 'DAW In',
  ].join(' ');
}

module.exports = moduleForDevice;
