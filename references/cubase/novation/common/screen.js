var utils = require('./base_utils');
var constants = require('./constants');

/**
 * Sends the display cache to the device
 * @param {Common.Config} config
 * @param {MR_ActiveDevice} activeDevice
 */
function sendDisplayCache(config, activeDevice) {
  // Get the display cache from the device state
  var jsonDisplayCache = activeDevice.getState(
    constants.STATE_KEYS.displayCache
  );
  if (jsonDisplayCache) {
    var displayCache = JSON.parse(jsonDisplayCache);
    if (Array.isArray(displayCache)) {
      // Find the last trigger index
      var lastTriggerIndex = utils.findLastIndex(
        displayCache,
        function (display) {
          return display.field & 0x40;
        }
      );
      // Build the midi array to send to the device
      var midi = [];
      displayCache.forEach(function (display, index) {
        // Turn off the trigger bit if this is not the last trigger index
        if (index !== lastTriggerIndex) {
          display.field &= ~0x40;
        }
        // Add the sysex message to the midi array
        var sysex = utils.makeSysex(
          config,
          [0x06, display.address, display.field].concat(
            utils.textAsArray(display.text)
          )
        );
        midi = midi.concat(sysex);
      });
      // Send the display cache to the device
      config.midiOutput.sendMidi(activeDevice, midi);
    }
    // Clear the display cache from the device state
    activeDevice.setState(constants.STATE_KEYS.displayCache, '');
  }
}

/**
 * Sends the sysex message to set the display configuration
 * @param {Common.Config} config
 * @param {MR_ActiveDevice} context
 * @param {number} address Encoder/fader cc number associated with text or reserved display targets
 * @param {number} displayConfig Arrangement and operation of the display, see the LK4 Screen SysEx documentation
 */
function sendDisplayConfig(config, context, address, displayConfig) {
  var sysex = utils.makeSysex(config, [0x04, address, displayConfig]);
  config.midiOutput.sendMidi(context, sysex);
}

/**
 * Sends the sysex message to set the display parameter name
 * @param {Common.Config} config
 * @param {MR_ActiveDevice} context
 * @param {number} address Encoder/fader cc number associated with text reserved display targets
 * @param {number} field Zero indexed line to display text on
 * @param {boolean} trigger True to trigger the display
 * @param {string} text Display text
 * @param {boolean} ignoreShiftState True to ignore the shift state when setting the trigger bit
 */
function sendDisplayText(
  config,
  context,
  address,
  field,
  trigger,
  text,
  ignoreShiftState
) {
  if (trigger) {
    field = updateLastDisplayState(
      config,
      context,
      address,
      field,
      ignoreShiftState
    );
  }
  if (config.updateDisplayAtIdleTime && config.hasIdleCallbacks) {
    var jsonDisplayCache = context.getState(constants.STATE_KEYS.displayCache);
    var displayCache = jsonDisplayCache ? JSON.parse(jsonDisplayCache) : [];
    displayCache.push({address, field, text});
    context.setState(
      constants.STATE_KEYS.displayCache,
      JSON.stringify(displayCache)
    );
  } else {
    var sysex = utils.makeSysex(
      config,
      [0x06, address, field].concat(utils.textAsArray(text))
    );
    config.midiOutput.sendMidi(context, sysex);
  }
}

/**
 * Sends the sysex messages to configure the permanent display for a grid and
 * display the supplied title and fields in the grid
 * @param {Common.Config} config
 * @param {MR_ActiveDevice} context
 * @param {string} title
 * @param {string[]} fields
 */
function sendPermanentDisplayGrid(config, context, title, fields) {
  var target = config.permanentDisplayTarget;
  sendDisplayConfig(config, context, target, 0x03);
  sendDisplayText(config, context, target, 0, false, title);
  for (var i = 0; i < 8; ++i) {
    var address = i + 1;
    var trigger = i === 7;
    var text = fields[i] || '-';
    sendDisplayText(config, context, target, address, trigger, text, true);
  }
}

/**
 * Sends the sysex message to set the permanent display text
 * @param {Common.Config} config
 * @param {MR_ActiveDevice} context
 * @param {string[]} lines
 */
function sendPermanentDisplayText(config, context, lines) {
  var target = config.permanentDisplayTarget;
  sendDisplayConfig(config, context, target, 0x02);
  lines.forEach(function (line, index) {
    var trigger = index === lines.length - 1;
    sendDisplayText(config, context, target, index, trigger, line || '', true);
  });
}

/**
 * Sends the sysex message to set the overlay display text
 * @param {Common.Config} config
 * @param {MR_ActiveDevice} context
 * @param {string} title
 * @param {string} body
 * @param {boolean} ignoreShiftState True to ignore the shift state when setting the trigger bit
 */
function sendOverlayDisplayText(
  config,
  context,
  title,
  body,
  ignoreShiftState
) {
  sendDisplayText(
    config,
    context,
    config.overlayDisplayTarget,
    0,
    false,
    title,
    ignoreShiftState
  );
  sendDisplayText(
    config,
    context,
    config.overlayDisplayTarget,
    1,
    true,
    body,
    ignoreShiftState
  );
}

/**
 * Sends the sysex message to set the display text for a group of displays
 * @param {Common.Config} config
 * @param {MR_ActiveDevice} context
 * @param {number} startAddress The first display address to send the title to
 * @param {number} endAddress The last display address to send the title to
 * @param {string} title
 */
function sendTitleToDisplayGroup(
  config,
  context,
  startAddress,
  endAddress,
  title
) {
  for (var address = startAddress; address <= endAddress; ++address) {
    sendDisplayText(config, context, address, 0, false, title);
  }
}

/**
 * NB. This function should only be called from `sendDisplayText` to prevent erroneous display-trigger suppression.
 * Updates the last display time and priority states and returns the supplied `field` value with the trigger bit set if appropriate.
 * @param {Common.Config} config
 * @param {MR_ActiveDevice} context
 * @param {number} address Encoder/fader cc number associated with text or reserved display targets
 * @param {number} field Zero indexed line to display text on
 * @param {boolean} ignoreShiftState True to ignore the shift state when setting the trigger bit
 * @returns The supplied `field` value with the trigger bit set if appropriate
 */
function updateLastDisplayState(
  config,
  context,
  address,
  field,
  ignoreShiftState
) {
  // Prevent the trigger bit from being set if the shift button is down
  if (!ignoreShiftState && context.getState('subpage.Shift') === 'shifted') {
    return field;
  }

  // Get the last display time and priority
  var lastDisplayTimeKey = constants.STATE_KEYS.lastDisplayTime;
  var lastDisplayPriorityKey = constants.STATE_KEYS.lastDisplayPriority;
  var lastDisplayTime = utils.getStateInt(context, lastDisplayTimeKey, 0);
  var lastDisplayPriority = utils.getStateInt(
    context,
    lastDisplayPriorityKey,
    0
  );

  // Set the trigger bit if the last display time was more than `config.displayPriorityTimeout` milliseconds ago
  // or the priority is greater than or equal to the last display priority
  var priorityMap = {};
  priorityMap[config.permanentDisplayTarget] = 2;
  priorityMap[config.overlayDisplayTarget] = 1;

  var priority = priorityMap[address] || 0;
  // Only manual-trigger for higher priorities or when displayPriorityTimeout has elapsed
  var now = Date.now();
  if (
    now - lastDisplayTime > config.displayPriorityTimeout ||
    priority >= lastDisplayPriority
  ) {
    field |= 0x40;

    // Update the last display time and priority
    context.setState(lastDisplayTimeKey, now.toString());
    context.setState(lastDisplayPriorityKey, priority.toString());
  }
  return field;
}

module.exports = {
  sendDisplayCache,
  sendDisplayText,
  sendOverlayDisplayText,
  sendPermanentDisplayGrid,
  sendPermanentDisplayText,
  sendTitleToDisplayGroup,
};
