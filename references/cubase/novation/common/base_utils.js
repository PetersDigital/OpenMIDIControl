var constants = require('./constants');

/**
 * Increments/decrements a time string
 * @param {string} time Time string
 * @param {string} format Format of the time string
 * @param {number} delta Amount to increment/decrement by
 */
function adjustTimeString(time, format, delta) {
  switch (format) {
    case 'Bars+Beats': // English
    case 'Takte+Zählzeiten': // German
    case 'Mesure': // French
    case 'Compases+Tiempos': // Spanish
    case 'Misure e movimenti': // Italian
    case 'Compassos+Pulsações': // Portuguese
      time = incrementBarsBeats(time, delta);
      break;
    case 'Seconds': // English
    case 'Sekunden': // German
    case 'Secondes': // French
    case 'Segundos': // Spanish & Portuguese
    case 'Secondi': // Italian
      time = incrementSecondsString(time, delta);
      break;
    case 'Samples': // English, German
    case 'Échantillons': // French
    case 'Muestras': // Spanish
    case 'Campioni': // Italian
    case 'Amostras': // Portuguese
      time = incrementSamplesString(time, delta);
      break;
    case 'Timecode': // English, German, French, Italian, Portuguese
    case 'Código de tiempo': // Spanish
      time = incrementTimecodeString(time, delta);
      break;
    case '60 fps (User)': // English, German
    case '60 fps (Perso)': // French
    case '60 fps (Usuario)': // Spanish
    case '60 fps (utente)': // Italian
    case '60 fps (Usuário)': // Portuguese
      time = incrementFpsUserString(time, delta);
      break;
    default:
      // All other supported languages (Japanese, Chinese, Russian) will default to bars+beats only
      time = incrementBarsBeats(time, delta);
      break;
  }
  return time;
}

/**
 * Sends the sysex messages to configure the display group
 * @param {LaunchkeyMk4Common.Config} config
 * @param {MR_ActiveDevice} context
 * @param {number} startId First encoder/fader cc number in group
 * @param {number} endId Last encoder/fader cc number in group
 * @param {number} displayConfig See LK4 Screen SysEx spec
 */
function configureDisplayGroup(config, context, startId, endId, displayConfig) {
  for (var i = startId; i <= endId; i++) {
    var sysex = makeSysex(config, [0x04, i, displayConfig]);
    config.midiOutput.sendMidi(context, sysex);
  }
}

/**
 * Finds the last index in the array where the predicate is true
 * @param {Array} array The array to search
 * @param {Function} predicate The function to test each element
 * @returns {number} The index of the last element that satisfies the predicate, or -1 if no elements satisfy the predicate
 */
function findLastIndex(array, predicate) {
  for (var i = array.length - 1; i >= 0; --i) {
    if (predicate(array[i], i, array)) {
      return i;
    }
  }
  return -1;
}

/**
 * Gets the selected track name from the device state
 * @param {MR_ActiveDevice} context
 * @returns The selected track name
 */
function getSelectedTrackName(context) {
  return context.getState(constants.STATE_KEYS.selectedTrackName);
}

/**
 * Gets the integer value from the device state matching the supplied key or returns the default value if the state is not set or is not a number
 * @param {MR_ActiveDevice} context
 * @param {string} key
 * @param {number} defaultValue
 * @returns {number} The integer value of the state matching the supplied key or the default value if the state is not set or is not a number
 */
function getStateInt(context, key, defaultValue) {
  var value = parseInt(context.getState(key));
  if (isNaN(value)) {
    value = defaultValue;
  }
  return value;
}

/**
 * Gets the current subpage for the supplied subPageAreaName
 * @param {MR_ActiveDevice} context
 * @param {string} subPageAreaName
 * @returns The current subpage for the supplied subPageAreaName
 */
function getSubPage(context, subPageAreaName) {
  var key = constants.STATE_KEYS.subPagePrefix + subPageAreaName;
  return context.getState(key);
}

/**
 * Gets the track name for the supplied track index
 * @param {MR_ActiveDevice} context
 * @param {number} trackIndex
 * @returns The track name for the supplied track index
 */
function getTrackName(context, trackIndex) {
  var key =
    constants.STATE_KEYS.channelNamePrefix +
    trackIndex +
    constants.STATE_KEYS.channelNameSuffix;
  return context.getState(key);
}

/**
 * Increments/decrements a Bars+Beats string
 * @param {string} text Bars+Beats string
 * @param {number} delta Amount to increment by
 * @returns {string} Incremented Bars+Beats string
 */
function incrementBarsBeats(text, delta) {
  return incrementTimeString(text, 1, delta, '.', [1, 1, 1, 0]);
}

/**
 * Increments/decrements a time string formatted as HH:MM:SS:FF(F).
 * @param {string} fpsString Frames per second string
 * @param {string} separator Frames per second string separator character
 * @param {number} secondsDelta Number of seconds to increment by
 * @returns {string} Adjusted frames per second string
 */
function incrementFpsString(fpsString, separator, secondsDelta) {
  // Convert the time string to number of seconds
  var hoursAdjuster = 3600;
  var minutesAdjuster = 60;
  var frames = 0;
  var totalSeconds = fpsString
    .split(separator)
    .map(function (part) {
      var result = parseInt(part);
      if (isNaN(result)) {
        result = 0;
      }
      return result;
    })
    .reduce(function (accumulator, currentValue, currentIndex) {
      switch (currentIndex) {
        case 0:
          accumulator += currentValue * hoursAdjuster;
          break;
        case 1:
          accumulator += currentValue * minutesAdjuster;
          break;
        case 2:
          accumulator += currentValue;
          break;
        case 3:
          frames = currentValue;
          break;
      }
      return accumulator;
    }, 0);

  // Adjust the secondsDelta by one if we're decrementing and frames is non-zero
  if (secondsDelta < 0 && frames > 0) {
    ++secondsDelta;
  }
  frames = 0;

  // Increment the seconds
  totalSeconds += secondsDelta;

  // Ensure we don't go negative
  totalSeconds = Math.max(totalSeconds, 0);

  // Rejoin the parts
  var hours = Math.floor(totalSeconds / hoursAdjuster);
  var minutes = Math.floor((totalSeconds / minutesAdjuster) % 60);
  var seconds = Math.floor(totalSeconds) % 60;
  return [hours, minutes, seconds, frames].join(separator);
}

/**
 * Increments/decrements a Frames per second string
 * @param {string} time Frames per second string
 * @param {number} delta Amount to increment by
 * @returns {string} Incremented Frames per second string
 */
function incrementFpsUserString(time, delta) {
  return incrementFpsString(time, '.', delta);
}

/**
 * Increments/decrements a Samples string
 * @param {string} time Samples string
 * @param {number} delta Amount to increment by
 * @returns {string} Incremented Samples string
 */
function incrementSamplesString(time, delta) {
  return Math.max(parseInt(time) + delta, 0).toString();
}

/**
 * Increments/decrements a Seconds string
 * @param {string} time Seconds string
 * @param {number} delta Amount to increment by
 * @returns {string} Incremented Seconds string
 */
function incrementSecondsString(time, delta) {
  // Replace the milliseconds separator with a colon
  time = time.replace('.', ':');

  // Increment the time
  time = incrementFpsString(time, ':', delta);

  // Replace the milliseconds separator with a period
  var msIndex = time.lastIndexOf(':');
  if (msIndex !== -1) {
    time = time.substring(0, msIndex) + '.' + time.substring(msIndex + 1);
  }

  return time;
}

/**
 * Increments/decrements a Timecode string
 * @param {string} time Timecode string
 * @param {number} delta Amount to increment by
 * @returns {string} Incremented Timecode string
 */
function incrementTimecodeString(time, delta) {
  return incrementFpsString(time, ':', delta);
}

/**
 * Increments/decrements a time string
 * @param {string} timeString time string
 * @param {number} partIndex Index of the time string part to increment
 * @param {number} delta Amount to increment/decrement by
 * @param {string} separator Time string separator character
 * @param {number[]} baseValues Base values for each part of the time string
 * @returns {string} Incremented string string
 */
function incrementTimeString(
  timeString,
  partIndex,
  delta,
  separator,
  baseValues
) {
  // Split the time string into integer parts
  var parts = timeString.split(separator).map(function (part) {
    return parseInt(part);
  });

  // Ensure the partIndex is in range
  partIndex = Math.min(partIndex, parts.length - 1);

  // Reset the sub parts and adjust the delta if required
  var deltaAdjusted = false;
  for (var subIndex = partIndex + 1; subIndex < parts.length; ++subIndex) {
    var part = parts[subIndex];
    var baseValue = baseValues[subIndex];

    if (!deltaAdjusted && delta < 0 && part > baseValue) {
      // Adjust the delta once to account for the resetting the sub parts if we are decrementing
      ++delta;
      deltaAdjusted = true;
    }

    // Reset this sub part
    parts[subIndex] = baseValue;
  }

  // Do the increment
  parts[partIndex] = Math.max(parts[partIndex] + delta, 0);

  // Rejoin the parts
  return parts
    .map(function (part) {
      return part.toString();
    })
    .join(separator);
}

/**
 * Logs the supplied arguments to the console
 */
function log() {
  var args = Array.prototype.slice.call(arguments);
  console.log(args.join(', '));
}

/**
 * Makes an IncDecEncoder that can be bound to key commands
 *
 * ```js
 * page.makeCommandBinding(zoomEncoder.decValue, 'Zoom', 'Zoom Out');
 * page.makeCommandBinding(zoomEncoder.incValue, 'Zoom', 'Zoom In');
 * ```
 *
 * @param {Config} config
 * @param {string} name The name to give the custom value variable
 * @param {string} subPageAreaName
 * @param {string} subPageName The sub page to operate in.  The encoder will only work if the `subpage.<subPageAresName>` state on the context equals this string
 * @param {number} dampingThreshold The threshold for the encoder to be considered as having moved. Set to 0 for no damping, 0.03 for a small amount of damping, 0.5 for a lot of damping.
 * @returns {LaunchkeyMk4.IncDecEncoder}
 */
function makeIncDecEncoder(
  config,
  name,
  subPageAreaName,
  subPageName,
  dampingThreshold
) {
  var surface = config.deviceDriver.mSurface;
  var customValue = surface.makeCustomValueVariable(name);
  var encoderValue = 0;
  var resetGuard = false;

  /** @type IncDecEncoder */
  var encoder = {
    decValue: surface.makeCustomValueVariable('devValue'),
    incValue: surface.makeCustomValueVariable('incValue'),
    bindToControlChange(channel, cc) {
      return customValue.mMidiBinding
        .setInputPort(config.midiInput)
        .bindToControlChange(channel, cc)
        .setTypeRelativeBinaryOffset();
    },
  };

  function setEncodervalue(activeDevice, value, diff) {
    if (resetGuard) {
      // Ignore this change when the resetGuard has been set by customValue.mOnProcessValueChange below
      resetGuard = false;
      return;
    }

    encoderValue += diff;
    if (encoderValue < -dampingThreshold) {
      encoder.decValue.setProcessValue(activeDevice, 1);
      encoderValue = 0;
    } else if (encoderValue > dampingThreshold) {
      encoder.incValue.setProcessValue(activeDevice, 1);
      encoderValue = 0;
    } else {
      // Prevent screen update if we haven't changed changed the value
      return;
    }
    if (encoder.onProcessValueChange) {
      encoder.onProcessValueChange(activeDevice, value, diff);
    }
  }

  customValue.mOnProcessValueChange = function (activeDevice, value, diff) {
    var resetValue = 0.5;
    var valueWasReset = value === resetValue && Math.abs(diff) > 0.4;
    var currentSubPage = getSubPage(activeDevice, subPageAreaName);
    if (currentSubPage !== subPageName || valueWasReset) return;

    setEncodervalue(activeDevice, value, diff);

    if (value < 0.1 || value > 0.9) {
      resetGuard = true;
      customValue.setProcessValue(activeDevice, resetValue);
    }
  };

  return encoder;
}

/**
 * Makes a toggle Encoder that can be used like a button with 2 states, `0`,
 * and `1`. Turning the encoder  clockwise will set the value to `1`, and
 * counter clockwise will set the value to `0`.
 *
 * @param {Common.Config} config
 * @param {string} name
 * @param {string} subPageAreaName
 * @param {string} subPageName
 * @returns {Common.ToggleEncoder}
 */
function makeToggleEncoder(config, name, subPageAreaName, subPageName) {
  var surface = config.deviceDriver.mSurface;
  var customValue = surface.makeCustomValueVariable(name);
  var toggleValue = surface.makeCustomValueVariable('Toggle ' + name);
  var encoderValue = 0;
  var resetGuard = false;

  var encoder = {
    customValueVariable: toggleValue,
    bindToControlChange(channel, cc) {
      return customValue.mMidiBinding
        .setInputPort(config.midiInput)
        .bindToControlChange(channel, cc)
        .setTypeRelativeBinaryOffset();
    },
  };

  function setEncodervalue(activeDevice, value, diff) {
    if (resetGuard) {
      // Ignore this change when the resetGuard has been set by customValue.mOnProcessValueChange below
      resetGuard = false;
      return;
    }

    encoderValue += diff;
    if (encoderValue < 0) {
      toggleValue.setProcessValue(activeDevice, 0);
      encoderValue = 0;
    } else if (encoderValue > 0) {
      toggleValue.setProcessValue(activeDevice, 1);
      encoderValue = 0;
    } else {
      // Prevent screen update if we haven't changed changed the value
      return;
    }
  }

  customValue.mOnProcessValueChange = function (activeDevice, value, diff) {
    var resetValue = 0.5;
    var valueWasReset = value === resetValue && Math.abs(diff) > 0.4;
    var currentSubPage = getSubPage(activeDevice, subPageAreaName);
    if (currentSubPage !== subPageName || valueWasReset) {
      return;
    }

    setEncodervalue(activeDevice, value, diff);

    if (value < 0.1 || value > 0.9) {
      resetGuard = true;
      customValue.setProcessValue(activeDevice, resetValue);
    }
  };

  return encoder;
}

/**
 * Wrap sysex message
 * @param {Config} config
 * @param {number[]} arr Message to wrap in standard sysex
 * @returns {number[]} complete Sysex message
 */
function makeSysex(config, arr) {
  return [0xf0, 0x00, 0x20, 0x29, config.pid1, config.pid2].concat(arr, [0xf7]);
}

/**
 * Maps Cubase supplied `objectTitle` and `valueTitle` to a parameter name.
 * NB. Getting the current active subpage by calling `getState('subpage.Encoders')` can NOT be used in this function.
 *    In some scenarios `mapEncoderParameterName` is called before `context.setState` resulting in the wrong subpage being detected.
 * @param {string} objectTitle
 * @param {string} valueTitle
 * @returns {string} Parameter name according to the DAW script
 */
function mapEncoderParameterName(objectTitle, valueTitle) {
  var parameterName = typeof objectTitle === 'string' ? objectTitle : '';

  var matchFx = parameterName.match(/FX [\d]{1,2}-(.*)/);
  if (matchFx) {
    parameterName = matchFx[1];
  } else {
    var matchEmptySendSlot = parameterName.match(/^\d+$/);
    if (!matchEmptySendSlot) {
      var parameterNameMap = {
        'Volume': 'Volume',
        'Pan Left-Right': 'Pan',
        'EQ 1 Freq': 'Lo Freq',
        'EQ 1 Gain': 'Lo Gain',
        'EQ 2 Freq': 'LMF Freq',
        'EQ 2 Gain': 'LMF Gain',
        'EQ 3 Freq': 'HMF Freq',
        'EQ 3 Gain': 'HMF Gain',
        'EQ 4 Freq': 'Hi Freq',
        'EQ 4 Gain': 'Hi Gain',
      };
      parameterName = parameterNameMap[valueTitle] || valueTitle;
    }
  }
  return parameterName;
}

/**
 * Saves the supplied track name to the device state
 * @param {MR_ActiveDevice} context
 * @param {string} trackName
 */
function setSelectedTrackName(context, trackName) {
  context.setState(constants.STATE_KEYS.selectedTrackName, trackName);
}

/**
 * Saves the supplied subPageName for the supplied subPageAreaName
 * @param {MR_ActiveDevice} context
 * @param {string} subPageAreaName
 * @param {string} subPageName
 */
function setSubPage(context, subPageAreaName, subPageName) {
  var key = constants.STATE_KEYS.subPagePrefix + subPageAreaName;
  context.setState(key, subPageName);
}

/**
 * Saves the track name for the supplied track index
 * @param {MR_ActiveDevice} context
 * @param {number} trackIndex
 * @param {string} trackName
 */
function setTrackName(context, trackIndex, trackName) {
  var key =
    constants.STATE_KEYS.channelNamePrefix +
    trackIndex +
    constants.STATE_KEYS.channelNameSuffix;
  return context.setState(key, trackName);
}

/**
 * convert string safely into byte array that can be safely sent
 * @param {string} text Input text
 * @returns {number[]} An array of char codes
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
 * @param {Common.Config} config
 * @param {MR_ActiveDevice} context
 * @param {[number, number]} brightnessValues
 * @param {number} ccUp
 * @param {number} ccDown
 * @param {boolean | null} enableUp
 * @param {boolean | null} enableDown
 */
function updatePageButtonLeds(
  config,
  context,
  brightnessValues,
  ccUp,
  ccDown,
  enableUp,
  enableDown
) {
  var up = 0;
  if (typeof enableUp === 'boolean') {
    up = enableUp ? brightnessValues[1] : brightnessValues[0];
  }
  var down = 0;
  if (typeof enableDown === 'boolean') {
    down = enableDown ? brightnessValues[1] : brightnessValues[0];
  }
  config.midiOutput.sendMidi(context, [0xb3, ccUp, up]);
  config.midiOutput.sendMidi(context, [0xb3, ccDown, down]);
}

module.exports = {
  adjustTimeString,
  configureDisplayGroup,
  findLastIndex,
  getSelectedTrackName,
  getStateInt,
  getSubPage,
  getTrackName,
  log,
  makeIncDecEncoder,
  makeToggleEncoder,
  makeSysex,
  mapEncoderParameterName,
  setSelectedTrackName,
  setSubPage,
  setTrackName,
  textAsArray,
  updatePageButtonLeds,
};
