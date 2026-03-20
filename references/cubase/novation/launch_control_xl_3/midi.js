module.exports = {
  pageUp: {channel: 0x0, cc: 0x6a},
  pageDown: {channel: 0x0, cc: 0x6b},
  trackLeft: {channel: 0x0, cc: 0x67},
  trackRight: {channel: 0x0, cc: 0x66},
  shift: {channel: 0x6, cc: 0x3f},
  mode: {channel: 0x6, cc: 0x1e},
  transport: {
    // transport buttons
    record: {channel: 0x0, cc: 0x76},
    play: {channel: 0x0, cc: 0x74},
    // transport encoders
    scrub: {channel: 0xf, cc: 0x5d},
    zoom: {channel: 0xf, cc: 0x5e},
    leftLocator: {channel: 0xf, cc: 0x5f},
    rightLocator: {channel: 0xf, cc: 0x60},
    loop: {channel: 0xf, cc: 0x61},
    marker: {channel: 0xf, cc: 0x62},
    notUsed: {channel: 0xf, cc: 0x63},
    tempo: {channel: 0xf, cc: 0x64},
  },
};
