const midiRemoteApi = require('midiremote_api_v1');

// See USB Unit IDs .xls
const result = require('../launchkey_mk4/launchkey_mk4_common')(
  midiRemoteApi,
  37,
  0x02,
  0x13,
  '4201',
  {leftGap: 5, hasFaders: false, keys: 37, keyMultiplier: 1.1, isMini: true}
);
