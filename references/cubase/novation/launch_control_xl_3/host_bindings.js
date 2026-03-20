var colors = require('../common/colors');
var SubPages = require('../common/sub-pages');
var screen = require('../common/screen');
var constants = require('../common/constants');
var lcxl3Constants = require('./lcxl3_constants');
var actionBindings = require('../common/action-bindings');
var midi = require('./midi');
var utils = require('../common/base_utils');

var faderButtonTopRowSubPageAreaName = 'Fader Buttons Solo / Arm';
var faderButtonBottomRowSubPageAreaName = 'Fader Buttons Mute / Select';
var dawModeSubPageAreaName = 'DAW Mode';
var transportEncoderHostValue = 'transportEncoderHostValue';

var subPageNames = {
  solo: 'Solo',
  arm: 'Arm',
  mute: 'Mute',
  select: 'Select',
  dawControl: 'DAW Control',
  dawMixer: 'DAW Mixer',
};

var IncDecCommandBindings = {
  zoom: {
    commandCategory: 'Zoom',
    commandName: {dec: 'Zoom Out', inc: 'Zoom In'},
    display: {title: 'Zoom', dec: 'Out', inc: 'In'},
  },
  marker: {
    commandCategory: 'Transport',
    commandName: {dec: 'Locate Previous Marker', inc: 'Locate Next Marker'},
    display: {title: 'Marker Select', dec: 'Previous', inc: 'Next'},
  },
};

/**
 *
 * @param {LaunchControlXl3.Config} config
 * @param {LaunchControlXl3.UserInterface} ui
 * @returns {MR_FactoryMappingPage}
 */
function makeHostBindings(config, ui) {
  var page = config.deviceDriver.mMapping.makePage('Default');
  var hostMixerBankZone = makeMixerBankZone(config, page);

  var subPages = makeSubPages(config, ui, page);

  bindSelectedTrackNameListener(config, page);

  actionBindings.bindShiftButton(
    page,
    subPages.Shift,
    ui.controlSection.shiftButton
  );
  bindDawControlButton(
    config,
    page,
    subPages[dawModeSubPageAreaName],
    ui.controlSection.modeButton
  );
  bindTransport(config, ui, page, subPages.Shift);
  bindTrackButtons(config, ui, page, hostMixerBankZone, subPages.Shift);
  bindEncoders(config, ui, page, hostMixerBankZone, subPages);
  bindEncoderPageButtons(page, ui.controlSection.encoderPageButtons, subPages);
  bindTransportEncoders(config, ui, page);
  bindFaders(config, ui, page, hostMixerBankZone);
  bindFaderButtons(config, ui, page, hostMixerBankZone, subPages);

  return page;
}

/**
 * Bind the encoder page buttons
 * @param {MR_FactoryMappingPage} page Page to work in
 * @param {[pageUp: MR_Button, pageDown: MR_Button]} pageButtons
 * @param {LaunchControlXl3.SubPages} subPages
 */
function bindEncoderPageButtons(page, pageButtons, subPages) {
  var subPageArea = page.makeSubPageArea('PageButtons');
  var dummySubPage = subPageArea.makeSubPage('PageButtonsDawControl');
  var dawControlSubPage =
    subPages[dawModeSubPageAreaName][subPageNames.dawControl];

  // bind the Sends SubPages to the page buttons
  actionBindings.bindPageButtons(pageButtons, page, subPages.Sends);

  // bind the `DAW Control` SubPage to the page buttons with a dummy sub page
  // this will effectively disable the page buttons when the DAW Control sub
  // page is active
  pageButtons.forEach(function (pageButton) {
    page
      .makeActionBinding(
        pageButton.mSurfaceValue,
        dummySubPage.mAction.mActivate
      )
      .setSubPage(dawControlSubPage);
  });
}

/**
 * Binds the listener to cache the selected track name and update the display.
 * @param {LaunchkeyMk4.Config} config
 * @param {MR_FactoryMappingPage} page Page to work in
 */
function bindSelectedTrackNameListener(config, page) {
  var mixerChannel = page.mHostAccess.mTrackSelection.mMixerChannel;
  mixerChannel.mOnTitleChange = function (activeDevice, activeMapping, name) {
    if (name !== utils.getSelectedTrackName(activeDevice)) {
      utils.setSelectedTrackName(activeDevice, name);
      screen.sendOverlayDisplayText(
        config,
        activeDevice,
        'Selected Track',
        name,
        false
      );
      // Send encoder title for all appropriate encoder displays
      var dawMode = utils.getSubPage(activeDevice, dawModeSubPageAreaName);
      if (dawMode === subPageNames.dawControl) {
        // Update the QC & EQ encoder displays for the selected track
        screen.sendTitleToDisplayGroup(config, activeDevice, 0x0d, 0x1c, name);
      }
    }
  };
}

/**
 * Binds the transport encoders
 * @param {LaunchControlXl3.Config} config
 * @param {LaunchControlXl3.UserInterface} ui
 * @param {MR_FactoryMappingPage} page Page to work in
 */
function bindTransportEncoders(config, ui, page) {
  // Scrub
  bindTransportEncoderLocator(
    config,
    page,
    'mTransportLocator',
    midi.transport.scrub.cc
  );

  // Zoom
  actionBindings.makeTransportEncoderCommandBinding(
    config,
    page,
    ui.transportSection.zoom,
    IncDecCommandBindings.zoom
  );

  // LPS
  bindTransportEncoderLocator(
    config,
    page,
    'mCycleLocatorLeft',
    midi.transport.leftLocator.cc
  );

  // LPE
  bindTransportEncoderLocator(
    config,
    page,
    'mCycleLocatorRight',
    midi.transport.rightLocator.cc
  );

  // Loop On/Off
  bindTransportLoopToggle(config, page, ui.transportSection.loop);

  // Marker
  actionBindings.makeTransportEncoderCommandBinding(
    config,
    page,
    ui.transportSection.marker,
    IncDecCommandBindings.marker
  );

  // Tempo
  actionBindings.bindTransportEncoderTempo(
    config,
    page,
    midi.transport.tempo.cc,
    dawModeSubPageAreaName,
    subPageNames.dawControl
  );
}

/**
 * Binds the transport Loop On/Off toggle
 * @param {LaunchControlXl3.Config} config
 * @param {MR_FactoryMappingPage} page Page to work in
 * @param {Common.ToggleEncoder} loop
 */
function bindTransportLoopToggle(config, page, loop) {
  var subPageAreaName = dawModeSubPageAreaName;
  var subPageName = subPageNames.dawControl;
  var valueBinding = page
    .makeValueBinding(
      loop.customValueVariable,
      page.mHostAccess.mTransport.mValue.mCycleActive
    )
    .setTypeToggle();

  valueBinding.mOnValueChange = function (device, mapping, value) {
    var text = value === 1 ? 'On' : 'Off';
    device.setState(constants.STATE_KEYS.cycleActive, text);
    var currentSubPage = utils.getSubPage(device, subPageAreaName);
    if (currentSubPage !== subPageName) return;
    screen.sendOverlayDisplayText(
      config,
      device,
      constants.TITLES.cycleActivate,
      text
    );
    updateDawControlEncoderLeds(config, device);
  };
}

/**
 * Bind the transport locators to the encoders
 * @param {LaunchControlXl3.Config} config
 * @param {MR_FactoryMappingPage} page Page to work in
 * @param {string} locatorName
 * @param {number} encoderCc
 */
function bindTransportEncoderLocator(config, page, locatorName, encoderCc) {
  actionBindings.bindTransportEncoderLocator(
    config,
    page,
    locatorName,
    encoderCc,
    dawModeSubPageAreaName,
    subPageNames.dawControl
  );
}

/**
 * Bind the DAW Control/Mixer buttons to activate the DAW Mode subpages.
 * @param {LaunchControlXl3.Config} config
 * @param {MR_FactoryMappingPage} page Page to work in
 * @param {LaunchControlXl3.SubPages['DAW Mode']} subPages
 * @param {MR_Button} dawControlButton
 */
function bindDawControlButton(config, page, subPages, dawControlButton) {
  /** @type {MR_SubPage} */
  var dawControl = subPages[subPageNames.dawControl];
  /** @type {MR_SubPage} */
  var dawMixer = subPages[subPageNames.dawMixer];

  page
    .makeActionBinding(
      dawControlButton.mSurfaceValue,
      dawControl.mAction.mActivate
    )
    .setSubPage(dawMixer)
    .filterByValue(2 / 127);

  page
    .makeActionBinding(
      dawControlButton.mSurfaceValue,
      dawMixer.mAction.mActivate
    )
    .setSubPage(dawControl)
    .filterByValue(1 / 127);
}

/**
 * Binds the transport
 * @param {LaunchControlXl3.Config} config
 * @param {LaunchControlXl3.UserInterface} ui
 * @param {MR_FactoryMappingPage} page Page to work in
 * @param {LaunchControlXl3.SubPages['Shift']} subPage
 */
function bindTrackButtons(config, ui, page, hostMixerBankZone, subPages) {
  var trackPrev = ui.controlSection.trackButtons[0];
  var trackNext = ui.controlSection.trackButtons[1];

  page
    .makeActionBinding(
      trackPrev.mSurfaceValue,
      page.mHostAccess.mTrackSelection.mAction.mPrevTrack
    )
    .setSubPage(subPages.unshifted);
  page
    .makeActionBinding(
      trackNext.mSurfaceValue,
      page.mHostAccess.mTrackSelection.mAction.mNextTrack
    )
    .setSubPage(subPages.unshifted);

  page
    .makeActionBinding(
      trackPrev.mSurfaceValue,
      hostMixerBankZone.zone.mAction.mPrevBank
    )
    .setSubPage(subPages.shifted);
  page
    .makeActionBinding(
      trackNext.mSurfaceValue,
      hostMixerBankZone.zone.mAction.mNextBank
    )
    .setSubPage(subPages.shifted);
}

/**
 * Binds the transport
 * @param {LaunchControlXl3.Config} config
 * @param {LaunchControlXl3.UserInterface} ui
 * @param {MR_FactoryMappingPage} page Page to work in
 * @param {LaunchControlXl3.SubPages['Shift']} subPage
 */
function bindTransport(config, ui, page, subPage) {
  var recordButton = ui.controlSection.transportButtons[0];
  var playButton = ui.controlSection.transportButtons[1];

  page
    .makeValueBinding(
      recordButton.mSurfaceValue,
      page.mHostAccess.mTransport.mValue.mRecord
    )
    .setTypeToggle();

  page
    .makeValueBinding(
      playButton.mSurfaceValue,
      page.mHostAccess.mTransport.mValue.mStart
    )
    .setSubPage(subPage.unshifted)
    .setTypeToggle();

  page
    .makeValueBinding(
      playButton.mSurfaceValue,
      page.mHostAccess.mTransport.mValue.mStop
    )
    .setSubPage(subPage.shifted)
    .setTypeToggle();

  recordButton.mSurfaceValue.mOnProcessValueChange = function (context, value) {
    config.midiOutput.sendMidi(context, [
      0xb0 + midi.transport.record.channel,
      midi.transport.record.cc,
      constants.COLORS.record[value],
    ]);
  };

  playButton.mSurfaceValue.mOnProcessValueChange = function (context, value) {
    // Invert the value if the shift button is pressed
    if (context.getState('subpage.Shift') === 'shifted') {
      value = value === 0 ? 1 : 0;
    }

    var color = constants.COLORS.play[value];

    config.midiOutput.sendMidi(context, [
      0xb0 + midi.transport.play.channel,
      midi.transport.play.cc,
      color,
    ]);
  };
}

/**
 * Binds the encoders
 * @param {LaunchControlXl3.Config} config
 * @param {LaunchControlXl3.UserInterface} ui
 * @param {MR_FactoryMappingPage} page Page to work in
 * @param {Common.MixerBankZone} hostMixerBankZone Object containing host mixer bank zone and channels
 * @param {LaunchControlXl3.SubPages} subPages
 */
function bindEncoders(config, ui, page, hostMixerBankZone, subPages) {
  var dawModeSubPages = subPages[dawModeSubPageAreaName];
  var dawControlSubPage = dawModeSubPages[subPageNames.dawControl];
  var dawMixerSubPage = dawModeSubPages[subPageNames.dawMixer];
  var hostValue = page.mCustom.makeHostValueVariable(transportEncoderHostValue);

  var eqBands = [
    page.mHostAccess.mTrackSelection.mMixerChannel.mChannelEQ.mBand1,
    page.mHostAccess.mTrackSelection.mMixerChannel.mChannelEQ.mBand2,
    page.mHostAccess.mTrackSelection.mMixerChannel.mChannelEQ.mBand3,
    page.mHostAccess.mTrackSelection.mMixerChannel.mChannelEQ.mBand4,
  ];

  for (
    var channelIndex = 0;
    channelIndex < config.numChannels;
    ++channelIndex
  ) {
    var hostMixerBankChannel = hostMixerBankZone.channels[channelIndex];
    var topEncoder = ui.encoderSection.encoders[channelIndex];
    var middleEncoder = ui.encoderSection.encoders[channelIndex + 8];
    var bottomEncoder = ui.encoderSection.encoders[channelIndex + 16];

    // DAW Mixer mode

    // Sends
    var numberOfSendPages = subPages.Sends.length;
    for (var sendPage = 0; sendPage < numberOfSendPages; ++sendPage) {
      var sendSubPage = subPages.Sends[sendPage];
      [topEncoder, middleEncoder].forEach(function (encoder, index) {
        var sendSlotIndex = sendPage * 2 + index;
        var sendSlot = hostMixerBankChannel.mSends.getByIndex(sendSlotIndex);
        page
          .makeValueBinding(encoder.mSurfaceValue, sendSlot.mLevel)
          .setSubPage(dawMixerSubPage)
          .setSubPage(sendSubPage);
      });
    }

    // Pan
    page
      .makeValueBinding(
        bottomEncoder.mSurfaceValue,
        hostMixerBankChannel.mValue.mPan
      )
      .setSubPage(dawMixerSubPage);

    // DAW Control Mode

    // Quick Controls
    var quickControl =
      page.mHostAccess.mTrackSelection.mMixerChannel.mQuickControls.getByIndex(
        channelIndex
      );

    page
      .makeValueBinding(topEncoder.mSurfaceValue, quickControl)
      .setSubPage(dawControlSubPage);
    quickControl.mOnTitleChange = function (
      activeDevice,
      activeMapping,
      objectTitle,
      valueTitle
    ) {
      var dawMode = utils.getSubPage(activeDevice, dawModeSubPageAreaName);
      if (dawMode === subPageNames.dawControl) {
        updateEncoderQuickControlLed(config, activeDevice, this, !!valueTitle);
      }
    }.bind(channelIndex);

    // EQ
    bindEqEncoder(
      config,
      page,
      middleEncoder,
      channelIndex,
      eqBands
    ).setSubPage(dawControlSubPage);

    // Transport
    // Bind each encoder to a dummy variable and set to the DAW Control
    // subpage, without this the encoder would continue to be bound to
    // the pan value even when the DAW Control subpage is active
    page
      .makeValueBinding(bottomEncoder.mSurfaceValue, hostValue)
      .setSubPage(dawControlSubPage);
  }
}

function bindEqEncoder(config, page, encoder, channelIndex, eqBands) {
  var isEven = channelIndex % 2 !== 0;
  var eqBand = eqBands[Math.floor(channelIndex / 2)];
  var value = isEven ? eqBand.mGain : eqBand.mFreq;
  var eqBinding = page.makeValueBinding(encoder.mSurfaceValue, value);

  var autoEqBinding;
  if (isEven) {
    autoEqBinding = actionBindings.bindEqAutoOn(
      config,
      page,
      eqBinding,
      eqBand,
      'eqEncoder' + channelIndex
    );
  }

  return {
    setSubPage(subPage) {
      eqBinding.setSubPage(subPage);
      if (autoEqBinding) {
        autoEqBinding.setSubPage(subPage);
      }
    },
  };
}

/**
 * Binds the faders
 * @param {LaunchControlXl3.Config} config
 * @param {LaunchControlXl3.UserInterface} ui
 * @param {MR_FactoryMappingPage} page Page to work in
 * @param {Common.MixerBankZone} hostMixerBankZone Object containing host mixer bank zone and channels
 */
function bindFaders(config, ui, page, hostMixerBankZone) {
  for (
    var channelIndex = 0;
    channelIndex < config.numChannels;
    ++channelIndex
  ) {
    var hostMixerBankChannel = hostMixerBankZone.channels[channelIndex];
    page
      .makeValueBinding(
        ui.faderSection.faders[channelIndex].mSurfaceValue,
        hostMixerBankChannel.mValue.mVolume
      )
      .setValueTakeOverModeScaled();
  }
}

/**
 * Binds the fader buttons
 * @param {LaunchControlXl3.Config} config
 * @param {LaunchControlXl3.UserInterface} ui
 * @param {MR_FactoryMappingPage} page Page to work in
 * @param {Common.MixerBankZone} hostMixerBankZone Object containing host mixer bank zone and channels
 * @param {LaunchControlXl3.SubPages} subPages
 */
function bindFaderButtons(config, ui, page, hostMixerBankZone, subPages) {
  /** @type {LaunchControlXl3.SubPages['Fader Buttons Solo / Arm']} */
  var soloArmSubPageArea = subPages[faderButtonTopRowSubPageAreaName];
  /** @type {LaunchControlXl3.SubPages['Fader Buttons Mute / Select']} */
  var muteSelectSubPageArea = subPages[faderButtonBottomRowSubPageAreaName];
  var buttons = ui.faderButtonSection.buttons;

  // bind the Solo/Arm toggle button
  bindFaderButtonToggle(page, ui.faderButtonSection.soloArm, [
    soloArmSubPageArea.Solo,
    soloArmSubPageArea.Arm,
  ]);

  // bind the Mute/Select toggle button
  bindFaderButtonToggle(page, ui.faderButtonSection.muteSelect, [
    muteSelectSubPageArea.Mute,
    muteSelectSubPageArea.Select,
  ]);

  // bind the two rows of buttons
  for (
    var channelIndex = 0;
    channelIndex < config.numChannels;
    ++channelIndex
  ) {
    var hostMixerBankChannel = hostMixerBankZone.channels[channelIndex];

    /** @type {Common.ChannelSettings} */
    var channelSettings = {
      offset: channelIndex,
      r: 0,
      g: 0,
      b: 0,
      isActive: false,
      hasValueTitle: false,
    };

    // top row fader buttons
    bindSoloArmButton(
      config,
      page,
      hostMixerBankChannel,
      buttons[channelIndex],
      soloArmSubPageArea,
      channelSettings
    );

    // bottom row fader buttons
    bindMuteSelectButtons(
      config,
      page,
      hostMixerBankChannel,
      buttons[channelIndex + 8],
      muteSelectSubPageArea,
      channelSettings
    );
  }
}

/**
 *
 * @param {LaunchControlXl3.Config} config
 * @param {MR_FactoryMappingPage} page Page to work in
 * @param {MR_MixerBankChannel} hostMixerBankChannel
 * @param {MR_Button} button
 * @param {LaunchControlXl3.SubPages['Fader Buttons Solo / Arm']} soloArmSubPageArea
 * @param {Common.ChannelSettings} channelSettings
 */
function bindSoloArmButton(
  config,
  page,
  hostMixerBankChannel,
  button,
  soloArmSubPageArea,
  channelSettings
) {
  function sendColor(context, value) {
    var address = 0x25 + channelSettings.offset;
    var state = utils.getSubPage(context, faderButtonTopRowSubPageAreaName);
    var states = {
      Solo: 'solo',
      Arm: 'recReady',
    };
    var func = states[state];
    colors.sendSetTableColor(config, context, 0xb0, address, func, value);
  }

  var surfaceValue = button.mSurfaceValue;
  surfaceValue.mOnTitleChange = colors.resetColorOnTitleChangeCallback(
    config,
    channelSettings,
    0xb0,
    0x25 + channelSettings.offset
  );

  surfaceValue.mOnProcessValueChange = function (context, value) {
    if (channelSettings.hasValueTitle) {
      sendColor(context, value);
    }
  };

  // This is a crazy workaround for https://forums.steinberg.net/t/842187: Running the below
  // block twice keeps `mOnTitleChange` and `mOnColorChange` working on Cubase >= 12.0.60 for
  // surface variables bound to the involved host variables.
  // (hack copied from here https://github.com/bjoluc/cubase-mcu-midiremote/blob/main/src/mapping/index.ts#L49)
  for (var i = 0; i < 2; i++) {
    page
      .makeValueBinding(surfaceValue, hostMixerBankChannel.mValue.mSolo)
      .setSubPage(soloArmSubPageArea.Solo)
      .setTypeToggle();

    page
      .makeValueBinding(surfaceValue, hostMixerBankChannel.mValue.mRecordEnable)
      .setSubPage(soloArmSubPageArea.Arm)
      .setTypeToggle();
  }
}

/**
 *
 * @param {LaunchControlXl3.Config} config
 * @param {MR_FactoryMappingPage} page Page to work in
 * @param {MR_MixerBankChannel} hostMixerBankChannel
 * @param {MR_Button} button
 * @param {LaunchControlXl3.SubPages['Fader Buttons Mute / Select']} muteSelectSubPageArea
 * @param {Common.ChannelSettings} channelSettings
 */
function bindMuteSelectButtons(
  config,
  page,
  hostMixerBankChannel,
  button,
  muteSelectSubPageArea,
  channelSettings
) {
  function sendColor(context, value) {
    var address = 0x25 + channelSettings.offset + 8;
    var state = utils.getSubPage(context, faderButtonBottomRowSubPageAreaName);

    if (state === 'Select') {
      /** @type Common.Rgb */
      var rgb = [channelSettings.r, channelSettings.g, channelSettings.b];
      colors.sendSetRGBColor(config, context, 0x53, address, rgb, value);
    } else if (state === 'Mute') {
      colors.sendSetTableColor(config, context, 0xb0, address, 'mute', value);
    }
  }

  var surfaceValue = button.mSurfaceValue;
  surfaceValue.mOnTitleChange = colors.resetColorOnTitleChangeCallback(
    config,
    channelSettings,
    0xb0,
    0x25 + channelSettings.offset + 8
  );

  surfaceValue.mOnColorChange = function (context, r, g, b) {
    channelSettings.r = r;
    channelSettings.g = g;
    channelSettings.b = b;

    if (channelSettings.hasValueTitle) {
      sendColor(context, 0);
    }
  };

  surfaceValue.mOnProcessValueChange = function (context, value) {
    if (channelSettings.hasValueTitle) {
      sendColor(context, value);
    }
  };

  // This is a crazy workaround for https://forums.steinberg.net/t/842187: Running the below
  // block twice keeps `mOnTitleChange` and `mOnColorChange` working on Cubase >= 12.0.60 for
  // surface variables bound to the involved host variables.
  // (hack copied from here https://github.com/bjoluc/cubase-mcu-midiremote/blob/main/src/mapping/index.ts#L49)
  for (var i = 0; i < 2; i++) {
    page
      .makeValueBinding(surfaceValue, hostMixerBankChannel.mValue.mMute)
      .setSubPage(muteSelectSubPageArea.Mute)
      .setTypeToggle();

    page
      .makeValueBinding(surfaceValue, hostMixerBankChannel.mValue.mSelected)
      .setSubPage(muteSelectSubPageArea.Select); // No setTypeToggle for track selection
  }
}

/**
 * Binds the fader button toggle
 * @param {MR_FactoryMappingPage} page Page to work in
 * @param {MR_Button} button The button to bind to
 * @param {[MR_SubPage, MR_SubPage]} subPages A pair of sub pages to toggle between
 */
function bindFaderButtonToggle(page, button, subPages) {
  var surfaceValue = button.mSurfaceValue;

  page
    .makeActionBinding(surfaceValue, subPages[0].mAction.mActivate)
    .setSubPage(subPages[1]);

  page
    .makeActionBinding(surfaceValue, subPages[1].mAction.mActivate)
    .setSubPage(subPages[0]);
}

/**
 * Create a mixer bank zone
 * @param {LaunchControlXl3.Config} config
 * @param {MR_FactoryMappingPage} page
 * @returns {Common.MixerBankZone}
 */
function makeMixerBankZone(config, page) {
  var zone = page.mHostAccess.mMixConsole
    .makeMixerBankZone()
    .excludeInputChannels()
    .excludeOutputChannels()
    .setFollowVisibility(true);

  var channels = [];
  for (
    var channelIndex = 0;
    channelIndex < config.numChannels;
    ++channelIndex
  ) {
    var mixerBankChannel = zone.makeMixerBankChannel();
    mixerBankChannel.mOnTitleChange = function (
      activeDevice,
      activeMapping,
      name
    ) {
      utils.setTrackName(activeDevice, this, name);

      // Update the encoder column LEDs when in DAW Mixer mode
      var subPage = utils.getSubPage(activeDevice, dawModeSubPageAreaName);
      if (subPage === subPageNames.dawMixer) {
        var sendPage = activeDevice.getState('subpage.Sends');
        updateDawMixerEncoderColumnLeds(config, activeDevice, this, sendPage);
      }
    }.bind(channelIndex);
    channels[channelIndex] = mixerBankChannel;
  }

  return {zone, channels};
}

/**
 * Make sub pages
 * @param {LaunchControlXl3.Config} config
 * @param {LaunchControlXl3.UserInterface} ui
 * @param {MR_FactoryMappingPage} page Page to work in
 * @return {LaunchControlXl3.SubPages}
 */
function makeSubPages(config, ui, page) {
  var subPages = SubPages.makeSubPageContainer(config, page);

  makeShiftSubPages(subPages);
  makeDawModeSubPages(ui, subPages);

  // top row fader buttons
  makeFaderButtonSubPages(subPages, faderButtonTopRowSubPageAreaName, [
    subPageNames.solo,
    subPageNames.arm,
  ]).onActivate = function (config, device, name) {
    var armSoloColors = {
      Arm: constants.COLORS.recReady[1],
      Solo: constants.COLORS.solo[1],
    };
    screen.sendOverlayDisplayText(config, device, 'Button Mode', name);
    config.midiOutput.sendMidi(device, [0xb0, 0x41, armSoloColors[name]]); // Set the colour of the Solo/Arm button
  };

  // bottom row fader buttons
  makeFaderButtonSubPages(subPages, faderButtonBottomRowSubPageAreaName, [
    subPageNames.mute,
    subPageNames.select,
  ]).onActivate = function (config, device, name) {
    var muteSelectColors = {
      Mute: constants.COLORS.mute[1],
      Select: constants.COLORS.select[1],
    };
    screen.sendOverlayDisplayText(config, device, 'Button Mode', name);
    config.midiOutput.sendMidi(device, [0xb0, 0x42, muteSelectColors[name]]); // Set the colour of the Mute/Select button
  };

  makeSendsSubpages(subPages, config.maxSendSlots);

  return subPages;
}

/**
 * Make shift sub pages
 * @param {LaunchControlXl3.SubPages} subPages
 */
function makeShiftSubPages(subPages) {
  var shiftPageArea = subPages.makeSubPageArea('Shift');

  shiftPageArea.makeSubPage('unshifted');
  shiftPageArea.makeSubPage('shifted');
}

/**
 * Make sub pages for DAW Control/Mixer
 * @param {LaunchControlXl3.UserInterface} ui
 * @param {LaunchControlXl3.SubPages} subPages
 */
function makeDawModeSubPages(ui, subPages) {
  var subPageArea = subPages.makeSubPageArea(dawModeSubPageAreaName);

  subPageArea.makeSubPage(subPageNames.dawMixer);
  subPageArea.makeSubPage(subPageNames.dawControl);

  subPageArea.onActivate = function (config, device, name) {
    // Set each row of encoders to relative mode
    config.midiOutput.sendMidi(device, [0xb6, 0x45, 0x7f]);
    config.midiOutput.sendMidi(device, [0xb6, 0x48, 0x7f]);
    config.midiOutput.sendMidi(device, [0xb6, 0x49, 0x7f]);

    var currentSendPage = device.getState('subpage.Sends');
    updateEncoderLeds(config, device, name, currentSendPage);
    updateEncoderDisplays(config, ui, device, name);

    utils.updatePageButtonLeds(
      config,
      device,
      lcxl3Constants.BRIGHTNESS,
      midi.pageUp.cc,
      midi.pageDown.cc,
      name !== subPageNames.dawControl && currentSendPage !== 'Sends 1',
      name !== subPageNames.dawControl && currentSendPage !== 'Sends 4'
    );
  };
}

/**
 * Updates the encoders display configurations and contents depending on DAW mode
 * @param {LaunchControlXl3.Config} config
 * @param {LaunchControlXl3.UserInterface} ui
 * @param {MR_ActiveDevice} context
 * @param {string} pageName
 */
function updateEncoderDisplays(config, ui, context, pageName) {
  // Configure bottom row of encoder displays to be 3-lines.
  // Pan has preview and auto-trigger, transport has preview only
  var displayConfig = pageName == subPageNames.dawMixer ? 0x62 : 0x22;
  utils.configureDisplayGroup(config, context, 0x1d, 0x24, displayConfig);

  // Setup the displays depending on the current DAW mode
  if (pageName == subPageNames.dawMixer) {
    setupSendsEncoderDisplays(config, ui);
    setupPanEncoderDisplays(config, ui);
  } else {
    setupQcEncoderDisplays(config, ui, context);
    setupEqEncoderDisplays(config, ui, context);
    setupTransportEncoderDisplays(config, ui, context);
  }
}

/**
 * Sets up the encoder display callbacks to update the display fields
 * @param {LaunchControlXl3.Config} config
 * @param {MR_SurfaceElementValue} surfaceValue
 * @param {number} address
 * @param {number} trackIndex
 * @param {boolean} titleIsSelectedTrack
 */
function setupEncoderDisplayCallbacks(
  config,
  surfaceValue,
  address,
  trackIndex,
  titleIsSelectedTrack
) {
  surfaceValue.mOnTitleChange = function (context, objectTitle, valueTitle) {
    var parameterName =
      utils.mapEncoderParameterName(objectTitle, valueTitle) || '-';
    screen.sendDisplayText(config, context, address, 1, false, parameterName);
    context.setState(
      constants.STATE_KEYS.lastEncoderDisplayTime,
      Date.now().toString()
    );
  };
  surfaceValue.mOnDisplayValueChange = function (context, value, units) {
    var encoderTitle = titleIsSelectedTrack
      ? utils.getSelectedTrackName(context)
      : utils.getTrackName(context, trackIndex);
    screen.sendDisplayText(config, context, address, 0, false, encoderTitle);
    screen.sendDisplayText(config, context, address, 2, false, value);
    context.setState(
      constants.STATE_KEYS.lastEncoderDisplayTime,
      Date.now().toString()
    );
  };
}

/**
 * Sets up the callbacks for the EQ encoders to update the displays appropriately
 * @param {LaunchControlXl3.Config} config
 * @param {LaunchControlXl3.UserInterface} ui
 */
function setupEqEncoderDisplays(config, ui, context) {
  var encoderTitle = utils.getSelectedTrackName(context);
  for (var index = 0; index < config.numChannels; ++index) {
    var address = index + 0x15;
    var surfaceValue = ui.encoderSection.encoders[index + 8].mSurfaceValue;
    setupEncoderDisplayCallbacks(config, surfaceValue, address, index, true);
    screen.sendDisplayText(config, context, address, 0, false, encoderTitle);
  }
}

/**
 * Sets up the callbacks for the Quick Control encoders to update the displays appropriately
 * @param {LaunchControlXl3.Config} config
 * @param {LaunchControlXl3.UserInterface} ui
 */
function setupQcEncoderDisplays(config, ui, context) {
  var encoderTitle = utils.getSelectedTrackName(context);
  for (var index = 0; index < config.numChannels; ++index) {
    var address = index + 0x0d;
    var surfaceValue = ui.encoderSection.encoders[index].mSurfaceValue;
    setupEncoderDisplayCallbacks(config, surfaceValue, address, index, true);
    screen.sendDisplayText(config, context, address, 0, false, encoderTitle);
  }
}

/**
 * Sets up the callbacks for the pan encoders to update the displays appropriately
 * @param {LaunchControlXl3.Config} config
 * @param {LaunchControlXl3.UserInterface} ui
 */
function setupPanEncoderDisplays(config, ui) {
  for (var index = 0; index < config.numChannels; ++index) {
    var address = index + 0x1d;
    var surfaceValue = ui.encoderSection.encoders[index + 16].mSurfaceValue;
    setupEncoderDisplayCallbacks(config, surfaceValue, address, index, false);
  }
}

/**
 * Sets up the callbacks for the sends encoders to update the displays appropriately
 * @param {LaunchControlXl3.Config} config
 * @param {LaunchControlXl3.UserInterface} ui
 */
function setupSendsEncoderDisplays(config, ui) {
  var encoders = ui.encoderSection.encoders;
  for (var index = 0; index < config.numChannels; ++index) {
    var address1 = index + 0x0d;
    var address2 = address1 + config.numChannels;
    var surfaceValue1 = encoders[index].mSurfaceValue;
    var surfaceValue2 = encoders[index + config.numChannels].mSurfaceValue;
    setupEncoderDisplayCallbacks(config, surfaceValue1, address1, index, false);
    setupEncoderDisplayCallbacks(config, surfaceValue2, address2, index, false);
  }
}

/**
 * Sets up the transport encoder preview displays
 * @param {LaunchControlXl3.Config} config
 * @param {LaunchControlXl3.UserInterface} ui
 * @param {MR_ActiveDevice} context
 */
function setupTransportEncoderDisplays(config, ui, context) {
  for (var index = 0; index < config.numChannels; index++) {
    // Remove the callbacks setup for the pan encoders
    var encoder = ui.encoderSection.encoders[index + 16];
    var surfaceValue = encoder.mSurfaceValue;
    surfaceValue.mOnTitleChange = function () {};
    surfaceValue.mOnDisplayValueChange = function () {};
    // Send the transport encoder display text for previews
    var address = 0x1d + index;
    var text = lcxl3Constants.TRANSPORT_ENCODER_NAMES[index] || '';
    screen.sendDisplayText(config, context, address, 0, false, 'Transport');
    screen.sendDisplayText(config, context, address, 1, false, text);
    screen.sendDisplayText(config, context, address, 2, false, '');
  }
}

/**
 * Updates the LED colours for the encoders
 * @param {LaunchControlXl3.Config} config
 * @param {MR_ActiveDevice} device
 * @param {string} pageName
 * @param {string} sendPageName
 */
function updateEncoderLeds(config, device, pageName, sendPageName) {
  if (pageName === subPageNames.dawControl) {
    updateDawControlEncoderLeds(config, device);
  } else if (pageName === subPageNames.dawMixer) {
    updateDawMixerEncoderLeds(config, device, sendPageName);
  }
}

/**
 * Updates the LED colours for the encoders when in DAW Control mode
 * @param {LaunchControlXl3.Config} config
 * @param {MR_ActiveDevice} device
 */
function updateDawControlEncoderLeds(config, device) {
  // Quick Control LEDs are set individually in bindEncoders

  // EQ LEDs
  for (var cc = 0x15; cc < 0x1d; ++cc) {
    var color =
      cc % 2 === 0
        ? constants.RGB_COLORS.eqGain
        : constants.RGB_COLORS.eqFrequency;
    var message = utils.makeSysex(config, [0x01, 0x53, cc].concat(color));
    config.midiOutput.sendMidi(device, message);
  }

  // Transport LEDs
  var cycleActive = device.getState(constants.STATE_KEYS.cycleActive) === 'On';
  var loopColor = cycleActive
    ? constants.RGB_COLORS.loop
    : constants.RGB_COLORS.loopDim;
  [
    {cc: midi.transport.scrub.cc, color: constants.RGB_COLORS.scrub},
    {cc: midi.transport.zoom.cc, color: constants.RGB_COLORS.zoom},
    {cc: midi.transport.leftLocator.cc, color: loopColor},
    {cc: midi.transport.rightLocator.cc, color: loopColor},
    {cc: midi.transport.loop.cc, color: loopColor},
    {cc: midi.transport.marker.cc, color: constants.RGB_COLORS.marker},
    {cc: midi.transport.notUsed.cc, color: constants.RGB_COLORS.off},
    {cc: midi.transport.tempo.cc, color: constants.RGB_COLORS.tempo},
  ].forEach(function (led) {
    var message = utils.makeSysex(
      config,
      [0x01, 0x53, led.cc - 0x40].concat(led.color)
    );
    config.midiOutput.sendMidi(device, message);
  });
}

/**
 * Updates the LED colours for the quick controls when in DAW Control mode
 * @param {LaunchControlXl3.Config} config
 * @param {MR_ActiveDevice} device
 * @param {number} index
 * @param {boolean} on
 */
function updateEncoderQuickControlLed(config, device, index, on) {
  var cc = 0x0d + index;
  var color = on ? constants.RGB_COLORS.quickControl : constants.RGB_COLORS.off;
  var message = utils.makeSysex(config, [0x01, 0x53, cc].concat(color));
  config.midiOutput.sendMidi(device, message);
}

/**
 * Updates the LED colours for the encoders when in DAW Mixer mode
 * @param {LaunchControlXl3.Config} config
 * @param {MR_ActiveDevice} device
 * @param {string} pageName
 * @param {string} sendPageName
 */
function updateDawMixerEncoderLeds(config, device, sendPageName) {
  for (var i = 0; i < config.numChannels; ++i) {
    updateDawMixerEncoderColumnLeds(config, device, i, sendPageName);
  }
}

/**
 * Updates the LED colours for the supplied encoder column index
 * @param {LaunchControlXl3.Config} config
 * @param {MR_ActiveDevice} device
 * @param {number} column
 * @param {string} sendPageName
 */
function updateDawMixerEncoderColumnLeds(config, device, column, sendPageName) {
  var channelName = utils.getTrackName(device, column);
  var cc = column + 0x0d;
  var messages = [];
  var color;
  if (channelName) {
    color = constants.RGB_COLORS.sendsOdd;
    messages.push(utils.makeSysex(config, [0x01, 0x53, cc].concat(color)));
    cc += config.numChannels;
    color = constants.RGB_COLORS.sendsEven;
    messages.push(utils.makeSysex(config, [0x01, 0x53, cc].concat(color)));
    cc += config.numChannels;
    color = constants.RGB_COLORS.pan;
    messages.push(utils.makeSysex(config, [0x01, 0x53, cc].concat(color)));
  } else {
    color = constants.RGB_COLORS.off;
    messages.push(utils.makeSysex(config, [0x01, 0x53, cc].concat(color)));
    cc += config.numChannels;
    messages.push(utils.makeSysex(config, [0x01, 0x53, cc].concat(color)));
    cc += config.numChannels;
    messages.push(utils.makeSysex(config, [0x01, 0x53, cc].concat(color)));
  }
  messages.forEach(function (message) {
    config.midiOutput.sendMidi(device, message);
  });
}

/**
 *
 * @param {LaunchControlXl3.SubPages} subPages
 * @param {number} maxSendSlots
 */
function makeSendsSubpages(subPages, maxSendSlots) {
  var subPageAreaName = 'Sends';
  var subPageArea = subPages.makeSubPageArea(subPageAreaName);
  subPages.Sends = [];

  subPageArea.onActivate = function (config, device, name) {
    // Calculate the slots from the name
    var startSlot = (parseInt(name.slice(6), 10) - 1) * 2 + 1;
    var endSlot = startSlot + 1;

    // Update the display to show the new subpage
    screen.sendOverlayDisplayText(
      config,
      device,
      'Sends',
      'Slots ' + startSlot + '-' + endSlot
    );

    // Set each row of encoders to relative mode
    utils.updatePageButtonLeds(
      config,
      device,
      lcxl3Constants.BRIGHTNESS,
      midi.pageUp.cc,
      midi.pageDown.cc,
      name !== 'Sends 1',
      name !== 'Sends 4'
    );
  };

  var sendPages = maxSendSlots / 2;

  for (var sendPage = 0; sendPage < sendPages; ++sendPage) {
    var subPageName = 'Sends ' + (sendPage + 1);
    var subPage = subPageArea.makeSubPage(subPageName);
    // Sends will be addded to the subPages object using the `subPageName` variable
    // for example, "Send 1", "Send 2".. etc. This is useful when looking up the
    // sub page using the name.  We also store the "Sends" sub pages in an array
    // for convenience so we can easily grab all the Sends subpages without
    // needing to know how many there are
    subPages.Sends.push(subPage);
  }
}

/**
 * Make fader button sub pages
 * @param {LaunchControlXl3.SubPages} subPages
 * @param {string} subPageAreaName
 * @param {[firstPageName: string, secondPageName: string]} subPageNames
 */
function makeFaderButtonSubPages(subPages, subPageAreaName, subPageNames) {
  var subPageArea = subPages.makeSubPageArea(subPageAreaName);

  // The order of creation is important here. The first one created will be the default mode.
  subPageArea.makeSubPage(subPageNames[0]);
  subPageArea.makeSubPage(subPageNames[1]);
  return subPageArea;
}

module.exports = makeHostBindings;
