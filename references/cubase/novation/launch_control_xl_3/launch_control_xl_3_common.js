var utils = require('../common/base_utils');
var screen = require('../common/screen');
var userInterface = require('./user_interface');
var makeHostBindings = require('./host_bindings');
var constants = require('./lcxl3_constants');
var midi = require('./midi');

var space = ' ';
var emptyString = '';

function moduleForDevice(midiRemoteApi, deviceId, familyCode) {
  var pid1 = 0x02;
  var pid2 = 0x15;
  var appName = midiRemoteApi.mDefaults.getAppName();
  var deviceName = getDeviceName(deviceId);

  // create the device driver main object
  var deviceDriver = midiRemoteApi.makeDeviceDriver(
    'Novation',
    deviceName,
    'Focusrite PLC'
  );

  // create objects representing the hardware's MIDI ports
  var midiInput = deviceDriver.mPorts.makeMidiInput();
  var midiOutput = deviceDriver.mPorts.makeMidiOutput();

  var maxSendSlots = midiRemoteApi.mDefaults.getNumberOfSendSlots();

  // Setup the config object to be used throughout the script
  /** @type LaunchControlXl3.Config */
  var config = {
    appName,
    deviceDriver,
    midiInput,
    midiOutput,
    pid1,
    pid2,
    numChannels: 8,
    maxSendSlots,
    displayPriorityTimeout: 50,
    eqAutoOnTimeout: 100,
    permanentDisplayTarget: 0x35,
    overlayDisplayTarget: 0x36,
  };

  // Initialize the device driver and detect the device

  // Windows
  deviceDriver
    .makeDetectionUnit()
    .detectPortPair(midiInput, midiOutput)
    .expectInputNameContains(getWinPortName(true, deviceId))
    .expectOutputNameContains(getWinPortName(false, deviceId))
    .expectSysexIdentityResponse('002029', familyCode, '0001');

  // Windows RT is the same as Mac so don't have separate detection for WinRT and Mac because that will cause duplicate renders in the Cubase MIDI Remote tab

  // Mac
  deviceDriver
    .makeDetectionUnit()
    .detectPortPair(midiInput, midiOutput)
    .expectInputNameEquals(getMacPortName(true, deviceId))
    .expectOutputNameEquals(getMacPortName(false, deviceId));

  // Setup the deviceDriver activation callbacks
  deviceDriver.mOnActivate = function (context) {
    var messages = [
      // Put device into DAW mode
      [0x9f, 0x0c, 0x7f],

      // Configure the overlay display to be 2 lines with no auto generation
      utils.makeSysex(config, [0x04, config.overlayDisplayTarget, 0x01]),

      // Configure the permanent display to be 3 lines with no auto generation
      utils.makeSysex(config, [0x04, config.permanentDisplayTarget, 0x02]),

      // Set each encoder row to relative mode
      [0xb6, 0x45, 0x7f],
      [0xb6, 0x48, 0x7f],
      [0xb6, 0x49, 0x7f],

      // Set DAW mode to "DAW Mixer" mode
      [0xb0 + midi.mode.channel, midi.mode.cc, 0x01],

      // Light up the track buttons
      [0xb3, 0x67, constants.BRIGHTNESS[1]], // Track Left
      [0xb3, 0x66, constants.BRIGHTNESS[1]], // Track right
    ];
    for (var i = 0; i < 8; i++) {
      // Configure each fader display to be ID 2 (3 lines) and auto-trigger display
      messages.push(utils.makeSysex(config, [0x04, 0x05 + i, 0x42]));
    }
    for (i = 0; i < 16; ++i) {
      // Configure the first 16 encoder displays to be three lines with auto-trigger and preview
      messages.push(utils.makeSysex(config, [0x04, 0x0d + i, 0x62]));
    }
    messages.forEach(function (message) {
      midiOutput.sendMidi(context, message);
    });

    // Send the app name to the permanent display
    screen.sendPermanentDisplayText(config, context, [
      emptyString,
      appName,
      emptyString,
    ]);

    console.log('INIT ' + deviceName + ' Integration');
  };

  deviceDriver.mOnDeactivate = function (context) {
    midiOutput.sendMidi(context, [0x9f, 0x0c, 0x00]); // set DAW mode off
    console.log('UNINIT ' + deviceName + ' Integration');
  };

  // Create the UI and setup bindings
  var ui = userInterface.makeUserInterface(config);
  makeHostBindings(config, ui);
}

/**
 * Gets the device name specific to the supplied deviceId
 * @param {string} deviceId
 * @returns Device specific name
 */
function getDeviceName(deviceId) {
  return ['Launch Control XL 3 Device', deviceId].join(space);
}

/**
 * Get the Mac port name to use in device detection
 * @param {boolean} inPort Flag indicating whether the in port or out port name is required
 * @param {number} deviceId The device number
 * @returns Mac port name to use in device detection
 */
function getMacPortName(inPort, deviceId) {
  return ['LCXL3', deviceId, inPort ? 'DAW Out' : 'DAW In'].join(space);
}

/**
 * Get the Windows port name to use in device detection
 * @param {boolean} inPort Flag indicating whether the in port or out port name is required
 * @param {number} deviceId The device number
 * @returns Windows port name to use in device detection
 */
function getWinPortName(inPort, deviceId) {
  return [inPort ? 'MIDIIN2' : 'MIDIOUT2', '(LCXL3', deviceId, 'MIDI)'].join(
    space
  );
}

module.exports = moduleForDevice;
