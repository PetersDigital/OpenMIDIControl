var constants = require('../common/constants');

const BRIGHTNESS = [32, 127];

var TRANSPORT_ENCODER_NAMES = [
  'Scrub',
  'Zoom',
  constants.TITLES.cycleStart,
  constants.TITLES.cycleEnd,
  constants.TITLES.cycleActivate,
  'Marker',
  '',
  'Tempo',
];

module.exports = {
  BRIGHTNESS,
  TRANSPORT_ENCODER_NAMES,
};
