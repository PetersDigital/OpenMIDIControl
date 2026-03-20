module.exports = {
  /**
   * Makes the normal and shift control layers
   * @param {Common.Config} config
   * @param {string} name The name of the zone
   * @returns {Common.ControlLayerZone} Object containing the zone layers
   */
  makeControlLayerZone(config, name) {
    var surface = config.deviceDriver.mSurface;
    var zone = surface.makeControlLayerZone(name);

    return {
      defaultLayer: zone.makeControlLayer('Default Layer'),
      altLayer: zone.makeControlLayer('Alt Layer'),
    };
  },
};
