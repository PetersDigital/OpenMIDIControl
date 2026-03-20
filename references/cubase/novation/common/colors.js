var utils = require('./base_utils');
var constants = require('./constants');

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

module.exports = {
  /**
   *
   * @param {Common.Config} config
   * @param {{hasValueTitle: boolean}} bindTo The object to bind the callback to
   * @param {number} statusByte
   * @param {number} dataByte The value of the data byte (cc or note number) for the object
   * @returns {(arg0: MR_ActiveDevice, arg1: string, arg2: string) => void}
   */
  resetColorOnTitleChangeCallback(config, bindTo, statusByte, dataByte) {
    return function (context, objectTitle, valueTitle) {
      this.hasValueTitle = valueTitle.length > 0;
      if (this.hasValueTitle === false) {
        config.midiOutput.sendMidi(context, [statusByte, dataByte, 0]);
      }
    }.bind(bindTo);
  },

  /**
   * set led color to correct color for function and value
   * @param {Common.Config} config
   * @param {MR_ActiveDevice} context
   * @param {number} statusByte
   * @param {number} address
   * @param {string} func
   * @param {number} value
   */
  sendSetTableColor(config, context, statusByte, address, func, value) {
    var color = constants.COLORS[func][value];
    config.midiOutput.sendMidi(context, [statusByte, address, color]);
  },

  /**
   *
   * @param {Common.Config} config
   * @param {MR_ActiveDevice} context
   * @param {number} colorSpec
   * @param {number} address
   * @param {Common.Rgb} color
   * @param {number} value
   */
  sendSetRGBColor(config, context, colorSpec, address, color, value) {
    var correctedColor = color;
    if (value === 0) {
      correctedColor = darken(color);
    }
    var r = Math.round(correctedColor[0] * 127);
    var g = Math.round(correctedColor[1] * 127);
    var b = Math.round(correctedColor[2] * 127);

    var sysex = utils.makeSysex(config, [0x01, colorSpec, address, r, g, b]);
    config.midiOutput.sendMidi(context, sysex);
  },
};
