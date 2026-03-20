const midiRemoteApi = require('midiremote_api_v1');

// See USB Unit IDs .xls
const result = require('../launchkey_mk4/launchkey_mk4_common')(
  midiRemoteApi,
  49,
  0x02,
  0x14,
  '4501',
  {leftGap: 0, hasFaders: true, keys: 49, keyMultiplier: 1.2}
);
