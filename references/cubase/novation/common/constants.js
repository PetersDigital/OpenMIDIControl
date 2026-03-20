var COLORS = {
  mute: [15, 14],
  solo: [59, 57],
  recReady: [7, 5],
  select: [2, 3],
  play: [23, 21],
  record: [7, 5],
};

var RGB_COLORS = {
  scrub: [0x38, 0x7f, 0x6e],
  zoom: [0x00, 0x0e, 0x7f],
  loop: [0x38, 0x00, 0x6f],
  loopDim: [0x0f, 0x00, 0x28],
  marker: [0x2f, 0x2f, 0x2f],
  off: [0x00, 0x00, 0x00],
  tempo: [0x00, 0x47, 0x00],
  eqFrequency: [0x5b, 0x3d, 0x7f],
  eqGain: [0x35, 0x00, 0x60],
  quickControl: [0x00, 0x28, 0x7f],
  sendsOdd: [0x7f, 0x7f, 0x00],
  sendsEven: [0x7f, 0x3d, 0x00],
  pan: [0x7f, 0x00, 0x00],
};

var STATE_KEYS = {
  channelNamePrefix: 'channel',
  channelNameSuffix: 'Name',
  cycleActive: 'cycleActive',
  displayCache: 'displayCache',
  lastDisplayPriority: 'lastDisplayPriority',
  lastDisplayTime: 'lastDisplayTime',
  lastEncoderDisplayTime: 'lastEncoderDisplayTime',
  lastSubpageActivedTime: 'lastSubpageActivedTime',
  selectedTrackName: 'selectedTrackName',
  subPagePrefix: 'subpage.',
};

var TITLES = {
  cycleActivate: 'Cycle Activate',
  cycleStart: 'Left Locator',
  cycleEnd: 'Right Locator',
};

module.exports = {
  COLORS,
  RGB_COLORS,
  STATE_KEYS,
  TITLES,
};
