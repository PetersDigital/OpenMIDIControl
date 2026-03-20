const midiRemoteApi = require('midiremote_api_v1');

// See USB Unit IDs .xls
const result = require('../launchkey_mk4/launchkey_mk4_common')(
  midiRemoteApi,
  37,
  0x02,
  0x14,
  '4401',
  {leftGap: 0, hasFaders: false, keys: 37, keyMultiplier: 1.2}
);
