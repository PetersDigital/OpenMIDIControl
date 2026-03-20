const midiRemoteApi = require('midiremote_api_v1');

// See USB Unit IDs .xls
const result = require('../launchkey_mk4/launchkey_mk4_common')(
  midiRemoteApi,
  61,
  0x02,
  0x14,
  '4601',
  {leftGap: 9, hasFaders: true, keys: 61, keyMultiplier: 1.2}
);
