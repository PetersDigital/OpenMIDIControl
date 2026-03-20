const midiRemoteApi = require('midiremote_api_v1');

// See USB Unit IDs .xls
const result = require('../launchkey_mk4/launchkey_mk4_common')(
  midiRemoteApi,
  25,
  0x02,
  0x13,
  '4101',
  {leftGap: 0, hasFaders: false, keys: 25, keyMultiplier: 1.1, isMini: true}
);
