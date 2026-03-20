var constants = require('../common/constants');

const COLORS = {
  mute: [15, 14],
  solo: [59, 57],
  recReady: [7, 5],
  select: [2, 3],
};
const BRIGHTNESS = [32, 127];
const MEDIUM_BRIGHTNESS = 64;

var TRANSPORT_ENCODER_NAMES = [
  'Scrub',
  'Zoom',
  constants.TITLES.cycleStart,
  constants.TITLES.cycleEnd,
  'Marker',
];

const CC_MODES = {
  encoder: 0x1e,
  encoderLegacy: 0x41,
  fader: 0x1f,
  faderLegacy: 0x42,
  pad: 0x1d,
  padLegacy: 0x40,
  shift: 0x3f,
  shiftLegacy: 0x48,
};

module.exports = {
  CC_MODES,
  COLORS,
  BRIGHTNESS,
  MEDIUM_BRIGHTNESS,
  TRANSPORT_ENCODER_NAMES,
};
