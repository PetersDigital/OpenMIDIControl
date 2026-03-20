var screen = require('../common/screen');
var constants = require('../common/constants');
var utils = require('./utils');
var SubPages = require('../common/sub-pages');
var actionBindings = require('../common/action-bindings');

/** @type {LaunchkeyMk4.IncDecCommandBindings} */
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
 * @param {LaunchkeyMk4.Config} config
 * @param {LaunchkeyMk4.UserInterface} ui
 * @returns
 */
function makeHostBindings(config, ui) {
  var page = config.deviceDriver.mMapping.makePage('Default');
  var hostMixerBankZone = makeMixerBankZone(config, page);
  var stereoOut = makeStereoOut(page);

  var subPages = makeSubPages(config, page);

  bindSelectedTrackNameListener(config, page);

  // faders
  bindFaderButtons(
    config,
    ui,
    page,
    hostMixerBankZone,
    subPages['Fader Buttons']
  );
  bindFaders(config, ui, page, hostMixerBankZone, subPages.Faders);
  bindMasterFader(config, ui, page, stereoOut);

  // pads
  bindDawPads(config, ui, page, hostMixerBankZone, subPages.Pads);
  bindPageButtons(ui.padSection.modeButtons, page, [subPages.Pads.Other]);

  // encoders
  // The first encoder sub page will be activated by default so order is important here.
  bindPluginEncoders(config, ui, page, subPages.Encoders);
  bindMixerEncoders(config, ui, page, hostMixerBankZone, subPages.Encoders);
  bindSendsEncoders(config, ui, page, hostMixerBankZone, subPages.Encoders);
  bindTransportEncoders(config, ui, page, subPages.Encoders);
  bindPageButtons(ui.encoderSection.modeButtons, page, [
    subPages.Encoders.Other,
  ]);

  bindEncoderModeActivations(page, subPages.Encoders, ui.legacyEncoderModes);
  bindEncoderModeActivations(page, subPages.Encoders, ui.encoderModes);
  bindPadModeActivations(page, subPages.Pads, ui.padSection.legacyPadModes);
  bindPadModeActivations(page, subPages.Pads, ui.padSection.padModes);

  bindShiftableButtons(config, ui, page, hostMixerBankZone, subPages.Shift);
  bindTransport(config, ui, page, subPages.Shift);

  return page;
}

/**
 *
 * @param {MR_FactoryMappingPage} page Page to work in
 * @param {LaunchkeyMk4.SubPageSetup[]} subPageSetups
 * @param {MR_SurfaceCustomValueVariable[]} modes
 */
function bindSubPageActivations(page, subPageSetups, modes) {
  modes.forEach(function (mode, index) {
    var subPageSetup = subPageSetups[index];
    var subPage = subPageSetup.subPage;
    var ccVal = subPageSetup.ccVal;
    var filterValueNormalized = ccVal / 127;

    if (subPage != null) {
      page
        .makeActionBinding(mode, subPage.mAction.mActivate)
        .filterByValue(filterValueNormalized);
    }
  });
}

/**
 * Binds the page buttons to cycle through the supplied sub pages
 * @param {LaunchkeyMk4.VerticalButtons} modeButtons
 * @param {MR_FactoryMappingPage} page Page to work in
 * @param {MR_SubPage[]} subPages
 */
function bindPageButtons(modeButtons, page, subPages) {
  actionBindings.bindPageButtons(
    [modeButtons.top, modeButtons.bottom],
    page,
    subPages
  );
}

/**
 * Binds the fader buttons
 * @param {LaunchkeyMk4.Config} config
 * @param {LaunchkeyMk4.UserInterface} ui
 * @param {MR_FactoryMappingPage} page Page to work in
 * @param {Common.MixerBankZone} hostMixerBankZone Object containing host mixer bank zone and channels
 * @param {LaunchkeyMk4.SubPages['Fader Buttons']} subPages
 */
function bindFaderButtons(config, ui, page, hostMixerBankZone, subPages) {
  if (config.layoutConfig.hasFaders) {
    // Bind the Arm/Select button to toggle between the 'Select'and 'Arm' sub-pages
    page
      .makeActionBinding(
        ui.faderSection.armSelect.mSurfaceValue,
        subPages.Select.mAction.mActivate
      )
      .setSubPage(subPages.Arm);

    page
      .makeActionBinding(
        ui.faderSection.armSelect.mSurfaceValue,
        subPages.Arm.mAction.mActivate
      )
      .setSubPage(subPages.Select);

    // Bind the fader buttons to perform the 'Select' or 'Arm' actions depending which sub-page is active.
    for (
      var channelIndex = 0;
      channelIndex < config.numChannels;
      ++channelIndex
    ) {
      var hostMixerBankChannel = hostMixerBankZone.channels[channelIndex];
      const buttonValue = ui.faderSection.buttons[channelIndex].mSurfaceValue;

      // This is a crazy workaround for https://forums.steinberg.net/t/842187: Running the below
      // block twice keeps `mOnTitleChange` and `mOnColorChange` working on Cubase >= 12.0.60 for
      // surface variables bound to the involved host variables.
      // (hack copied from here https://github.com/bjoluc/cubase-mcu-midiremote/blob/main/src/mapping/index.ts#L49)
      for (var i = 0; i < 2; i++) {
        page
          .makeValueBinding(
            buttonValue,
            hostMixerBankChannel.mValue.mRecordEnable
          )
          .setSubPage(subPages.Arm)
          .setTypeToggle();

        page
          .makeValueBinding(buttonValue, hostMixerBankChannel.mValue.mSelected)
          .setSubPage(subPages.Select); // No setTypeToggle for track selection
      }
    }
  }
}

/**
 * Binds the faders
 * @param {LaunchkeyMk4.Config} config
 * @param {LaunchkeyMk4.UserInterface} ui
 * @param {MR_FactoryMappingPage} page Page to work in
 * @param {Common.MixerBankZone} hostMixerBankZone Object containing host mixer bank zone and channels
 * @param {LaunchkeyMk4.SubPages['Faders']} subPages
 */
function bindFaders(config, ui, page, hostMixerBankZone, subPages) {
  if (config.layoutConfig.hasFaders) {
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
        .setSubPage(subPages.Volume)
        .setValueTakeOverModeScaled();
    }
    var faderModeSetups = [
      {ccVal: 0x01, subPage: subPages.Volume},
      {ccVal: 0x06, subPage: subPages.Other},
      {ccVal: 0x07, subPage: subPages.Other},
      {ccVal: 0x08, subPage: subPages.Other},
      {ccVal: 0x09, subPage: subPages.Other},
    ];

    bindSubPageActivations(page, faderModeSetups, ui.faderSection.faderModes);
  }
}

/**
 * Binds the master fader
 * @param {LaunchkeyMk4.Config} config
 * @param {LaunchkeyMk4.UserInterface} ui
 * @param {MR_FactoryMappingPage} page Page to work in
 * @param {MR_MixerBankChannel} stereoOut Stereo out channel
 */
function bindMasterFader(config, ui, page, stereoOut) {
  if (config.layoutConfig.hasFaders) {
    page
      .makeValueBinding(
        ui.faderSection.masterFader.mSurfaceValue,
        stereoOut.mValue.mVolume
      )
      .setValueTakeOverModeScaled();
  }
}

/**
 * Binds the mixer encoders
 * @param {LaunchkeyMk4.Config} config
 * @param {LaunchkeyMk4.UserInterface} ui
 * @param {MR_FactoryMappingPage} page Page to work in
 * @param {Common.MixerBankZone} hostMixerBankZone Object containing host mixer bank zone and channels
 * @param {LaunchkeyMk4.SubPages['Encoders']} subPages
 */
function bindMixerEncoders(config, ui, page, hostMixerBankZone, subPages) {
  // Bind the up/down buttons to change the active sub page
  bindPageButtons(ui.encoderSection.modeButtons, page, [
    subPages.Volume,
    subPages.Pan,
    subPages.EQ,
  ]);

  // Bind each encoder to volume and pan
  for (
    var channelIndex = 0;
    channelIndex < config.numChannels;
    ++channelIndex
  ) {
    var hostMixerBankChannel = hostMixerBankZone.channels[channelIndex];
    var encoder = ui.encoderSection.encoders[channelIndex].mSurfaceValue;
    page
      .makeValueBinding(encoder, hostMixerBankChannel.mValue.mVolume)
      .setSubPage(subPages.Volume);

    page
      .makeValueBinding(encoder, hostMixerBankChannel.mValue.mPan)
      .setSubPage(subPages.Pan);
  }

  // Bind each encoder to an eq parameter of the selected track
  var maxEqBands = 4;
  for (var eqBandIndex = 0; eqBandIndex < maxEqBands; ++eqBandIndex) {
    var eqBandName = 'mBand' + (eqBandIndex + 1);
    var eqBand =
      page.mHostAccess.mTrackSelection.mMixerChannel.mChannelEQ[eqBandName];
    var encoderIndex = eqBandIndex * 2;
    var encoderFrequency =
      ui.encoderSection.encoders[encoderIndex].mSurfaceValue;
    var encoderGain =
      ui.encoderSection.encoders[encoderIndex + 1].mSurfaceValue;
    page
      .makeValueBinding(encoderFrequency, eqBand.mFreq)
      .setSubPage(subPages.EQ);
    var eqGainBinding = page
      .makeValueBinding(encoderGain, eqBand.mGain)
      .setSubPage(subPages.EQ);

    actionBindings
      .bindEqAutoOn(config, page, eqGainBinding, eqBand, eqBandName)
      .setSubPage(subPages.EQ);
  }
}

/**
 * Binds the DAW pads
 * @param {LaunchkeyMk4.Config} config
 * @param {LaunchkeyMk4.UserInterface} ui
 * @param {MR_FactoryMappingPage} page Page to work in
 * @param {Common.MixerBankZone} hostMixerBankZone
 * @param {LaunchkeyMk4.SubPages['Pads']} subPages
 */
function bindDawPads(config, ui, page, hostMixerBankZone, subPages) {
  var padSubPageSelectArm = subPages['Select / Arm'];
  var padSubPageMuteSolo = subPages['Mute / Solo'];

  bindPageButtons(ui.padSection.modeButtons, page, [
    padSubPageSelectArm,
    padSubPageMuteSolo,
  ]);

  for (
    var channelIndex = 0;
    channelIndex < config.numChannels;
    ++channelIndex
  ) {
    var upperPadSurfaceValue =
      ui.padSection.upperPads[channelIndex].mSurfaceValue;

    var lowerPadSurfaceValue =
      ui.padSection.lowerPads[channelIndex].mSurfaceValue;

    var channel = hostMixerBankZone.channels[channelIndex];

    // This is a crazy workaround for https://forums.steinberg.net/t/842187: Running the below
    // block twice keeps `mOnTitleChange` and `mOnColorChange` working on Cubase >= 12.0.60 for
    // surface variables bound to the involved host variables.
    // (hack copied from here https://github.com/bjoluc/cubase-mcu-midiremote/blob/main/src/mapping/index.ts#L49)
    for (var i = 0; i < 2; i++) {
      page
        .makeValueBinding(upperPadSurfaceValue, channel.mValue.mSelected)
        .setSubPage(padSubPageSelectArm); // No setTypeToggle for track selection

      page
        .makeValueBinding(lowerPadSurfaceValue, channel.mValue.mRecordEnable)
        .setSubPage(padSubPageSelectArm)
        .setTypeToggle();

      page
        .makeValueBinding(upperPadSurfaceValue, channel.mValue.mSolo)
        .setSubPage(padSubPageMuteSolo)
        .setTypeToggle();

      page
        .makeValueBinding(lowerPadSurfaceValue, channel.mValue.mMute)
        .setSubPage(padSubPageMuteSolo)
        .setTypeToggle();
    }
  }
}

/**
 * Binds the plugins encoders
 * @param {LaunchkeyMk4.Config} config
 * @param {LaunchkeyMk4.UserInterface} ui
 * @param {MR_FactoryMappingPage} page Page to work in
 * @param {LaunchkeyMk4.SubPages['Encoders']} subPages
 */
function bindPluginEncoders(config, ui, page, subPages) {
  // Bind the up/down buttons to change the active sub page
  bindPageButtons(ui.encoderSection.modeButtons, page, [
    subPages['Quick Controls'],
  ]);

  // Bind each encoder to one of the quick controls
  var maxQuickControls = 8;
  for (
    var quickControlIndex = 0;
    quickControlIndex < maxQuickControls;
    ++quickControlIndex
  ) {
    var quickControl =
      page.mHostAccess.mTrackSelection.mMixerChannel.mQuickControls.getByIndex(
        quickControlIndex
      );
    var encoder = ui.encoderSection.encoders[quickControlIndex].mSurfaceValue;
    page
      .makeValueBinding(encoder, quickControl)
      .setSubPage(subPages['Quick Controls']);
  }
}

/**
 * Binds the listener to cache the selected track name and update the display.
 * Also binds the listener to update the drum pads color.
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
        config.layoutConfig.isMini
      );
      // Send encoder title for all encoders if encoder mode is plugin or eq
      var activeEncoderSubPage = utils.getActiveEncoderSubPage(activeDevice);
      if (['EQ', 'Quick Controls'].indexOf(activeEncoderSubPage) !== -1) {
        utils.sendAllEncodersDisplayTitle(config, activeDevice, name);
      }
    }
  };

  mixerChannel.mOnColorChange = function (device, mapping, r, g, b) {
    r = Math.round(r * 127);
    g = Math.round(g * 127);
    b = Math.round(b * 127);
    var midiOutput = config.midiOutput;
    for (var drum = 0x24; drum <= 0x33; ++drum) {
      midiOutput.sendMidi(
        device,
        utils.makeSysex(config, [0x01, 0x63, drum, r, g, b])
      );
    }
  };
}

/**
 * Binds the sends encoders
 * @param {LaunchkeyMk4.Config} config
 * @param {LaunchkeyMk4.UserInterface} ui
 * @param {MR_FactoryMappingPage} page Page to work in
 * @param {Common.MixerBankZone} hostMixerBankZone Object containing host mixer bank zone and channels
 * @param {LaunchkeyMk4.SubPages['Encoders']} subPages
 */
function bindSendsEncoders(config, ui, page, hostMixerBankZone, subPages) {
  // Bind the up/down buttons to change the active sub page
  bindPageButtons(ui.encoderSection.modeButtons, page, subPages.Sends);

  // Bind the up/down buttons to change the active sends sub page and bind the encoders to the sends
  for (var sendSlot = 0; sendSlot < config.maxSendSlots; ++sendSlot) {
    // Bind each encoder to sends[sendSlot]
    var subPage = subPages.Sends[sendSlot];
    for (
      var channelIndex = 0;
      channelIndex < config.numChannels;
      ++channelIndex
    ) {
      var hostMixerBankChannel = hostMixerBankZone.channels[channelIndex];
      var encoder = ui.encoderSection.encoders[channelIndex].mSurfaceValue;
      page
        .makeValueBinding(
          encoder,
          hostMixerBankChannel.mSends.getByIndex(sendSlot).mLevel
        )
        .setSubPage(subPage);
    }
  }
}

/**
 * Bind all buttons that can be shifted *and* the shift button
 * @param {LaunchkeyMk4.Config} config
 * @param {LaunchkeyMk4.UserInterface} ui
 * @param {MR_FactoryMappingPage} page page to work in
 * @param {Common.MixerBankZone} hostMixerBankZone MixerBankZone for the track banking
 * @param {LaunchkeyMk4.SubPages['Shift']} subPages
 */
function bindShiftableButtons(config, ui, page, hostMixerBankZone, subPages) {
  actionBindings.bindShiftButton(page, subPages, ui.trackButtons.shift);

  page
    .makeActionBinding(
      ui.trackButtons.legacyShift.mSurfaceValue,
      subPages.shifted.mAction.mActivate
    )
    .setSubPage(subPages.unshifted);
  page
    .makeActionBinding(
      ui.trackButtons.legacyShift.mSurfaceValue,
      subPages.unshifted.mAction.mActivate
    )
    .setSubPage(subPages.shifted)
    .mapToValueRange(1, 0);

  if (!config.layoutConfig.isMini) {
    page
      .makeActionBinding(
        ui.trackButtons.trackPrev.mSurfaceValue,
        page.mHostAccess.mTrackSelection.mAction.mPrevTrack
      )
      .setSubPage(subPages.unshifted);
    page
      .makeActionBinding(
        ui.trackButtons.trackNext.mSurfaceValue,
        page.mHostAccess.mTrackSelection.mAction.mNextTrack
      )
      .setSubPage(subPages.unshifted);

    page
      .makeActionBinding(
        ui.trackButtons.trackPrevShift.mSurfaceValue,
        hostMixerBankZone.zone.mAction.mPrevBank
      )
      .setSubPage(subPages.shifted);
    page
      .makeActionBinding(
        ui.trackButtons.trackNextShift.mSurfaceValue,
        hostMixerBankZone.zone.mAction.mNextBank
      )
      .setSubPage(subPages.shifted);

    page
      .makeCommandBinding(
        ui.transportSection.undo.mSurfaceValue,
        'Edit',
        'Undo'
      )
      .setSubPage(subPages.unshifted);

    page
      .makeCommandBinding(
        ui.transportSection.undo.mSurfaceValue,
        'Edit',
        'Redo'
      )
      .setSubPage(subPages.shifted);
  } else {
    page
      .makeActionBinding(
        ui.padSection.modeButtonsShift.top.mSurfaceValue,
        page.mHostAccess.mTrackSelection.mAction.mPrevTrack
      )
      .setSubPage(subPages.shifted);
    page
      .makeActionBinding(
        ui.padSection.modeButtonsShift.bottom.mSurfaceValue,
        page.mHostAccess.mTrackSelection.mAction.mNextTrack
      )
      .setSubPage(subPages.shifted);
  }
}

/**
 * Bind all transport buttons (except undo/redo)
 * @param {LaunchkeyMk4.Config} config
 * @param {LaunchkeyMk4.UserInterface} ui
 * @param {MR_FactoryMappingPage} page Page to work in
 * @param {LaunchkeyMk4.SubPages['Shift']} subPages
 */
function bindTransport(config, ui, page, subPages) {
  if (config.layoutConfig.isMini) {
    page
      .makeValueBinding(
        ui.transportSection.play.mSurfaceValue,
        page.mHostAccess.mTransport.mValue.mStart
      )
      .setSubPage(subPages.unshifted)
      .setTypeToggle();
    page
      .makeValueBinding(
        ui.transportSection.record.mSurfaceValue,
        page.mHostAccess.mTransport.mValue.mRecord
      )
      .setSubPage(subPages.unshifted)
      .setTypeToggle();

    // Shift+Play is stop
    page
      .makeValueBinding(
        ui.transportSection.play.mSurfaceValue,
        page.mHostAccess.mTransport.mValue.mStop
      )
      .setSubPage(subPages.shifted)
      .setTypeToggle();

    // Shift+Record is capture midi
    page
      .makeCommandBinding(
        ui.transportSection.record.mSurfaceValue,
        'Transport',
        'Global Retrospective Record'
      )
      .setSubPage(subPages.shifted);
  } else {
    page
      .makeValueBinding(
        ui.transportSection.play.mSurfaceValue,
        page.mHostAccess.mTransport.mValue.mStart
      )
      .setTypeToggle();
    page
      .makeValueBinding(
        ui.transportSection.record.mSurfaceValue,
        page.mHostAccess.mTransport.mValue.mRecord
      )
      .setTypeToggle();
    page
      .makeValueBinding(
        ui.transportSection.stop.mSurfaceValue,
        page.mHostAccess.mTransport.mValue.mStop
      )
      .setTypeToggle();
    page
      .makeValueBinding(
        ui.transportSection.cycle.mSurfaceValue,
        page.mHostAccess.mTransport.mValue.mCycleActive
      )
      .setTypeToggle();
    page
      .makeValueBinding(
        ui.transportSection.metronome.mSurfaceValue,
        page.mHostAccess.mTransport.mValue.mMetronomeActive
      )
      .setTypeToggle();
    page.makeCommandBinding(
      ui.transportSection.captureMidi.mSurfaceValue,
      'Transport',
      'Global Retrospective Record'
    );
    page.makeCommandBinding(
      ui.transportSection.quantize.mSurfaceValue,
      'Quantize Category',
      'Quantize'
    );
  }
}

/**
 *
 * @param {LaunchkeyMk4.Config} config
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
    'Encoders',
    'Transport'
  );
}

/**
 * Binds the transport encoders
 * @param {LaunchkeyMk4.Config} config
 * @param {LaunchkeyMk4.UserInterface} ui
 * @param {MR_FactoryMappingPage} page Page to work in
 * @param {LaunchkeyMk4.SubPages['Encoders']} subPages
 */
function bindTransportEncoders(config, ui, page, subPages) {
  var zoom = ui.transportSection.zoom;
  var marker = ui.transportSection.marker;

  // Bind the up/down buttons to change the active sub page
  bindPageButtons(ui.encoderSection.modeButtons, page, [subPages.Transport]);

  bindTransportEncoderLocator(config, page, 'mTransportLocator', 0x55);
  bindTransportEncoderLocator(config, page, 'mCycleLocatorLeft', 0x57);
  bindTransportEncoderLocator(config, page, 'mCycleLocatorRight', 0x58);
  actionBindings.bindTransportEncoderTempo(
    config,
    page,
    0x5c,
    'Encoders',
    'Transport'
  );

  actionBindings.makeTransportEncoderCommandBinding(
    config,
    page,
    zoom,
    IncDecCommandBindings.zoom
  );
  actionBindings.makeTransportEncoderCommandBinding(
    config,
    page,
    marker,
    IncDecCommandBindings.marker
  );

  // Hack to display the transport label - Bind each encoder to a dummy variable
  bindTransportEncodersToHostValue(config, ui, page, subPages.Transport);
}

/**
 *
 * @param {LaunchkeyMk4.Config} config
 * @param {LaunchkeyMk4.UserInterface} ui
 * @param {MR_FactoryMappingPage} page
 * @param {MR_SubPage} subPage
 */
function bindTransportEncodersToHostValue(config, ui, page, subPage) {
  var hostValue = page.mCustom.makeHostValueVariable(
    'transportEncoderHostValue'
  );

  for (var index = 0; index < config.numChannels; ++index) {
    var encoder = ui.encoderSection.encoders[index];
    page.makeValueBinding(encoder.mSurfaceValue, hostValue).setSubPage(subPage);
  }
}

/**
 *
 * @param {MR_FactoryMappingPage} page
 * @param {LaunchkeyMk4.SubPages['Encoders']} encoderSubPages
 * @param {MR_SurfaceCustomValueVariable[]} encoderModes
 */
function bindEncoderModeActivations(page, encoderSubPages, encoderModes) {
  var encoderModeSetups = [
    {ccVal: 0x02, subPage: encoderSubPages['Quick Controls']},
    {ccVal: 0x01, subPage: encoderSubPages.Volume},
    {ccVal: 0x04, subPage: encoderSubPages.Sends[0]},
    {ccVal: 0x05, subPage: encoderSubPages.Transport},
    {ccVal: 0x06, subPage: encoderSubPages.Other},
    {ccVal: 0x07, subPage: encoderSubPages.Other},
    {ccVal: 0x08, subPage: encoderSubPages.Other},
    {ccVal: 0x09, subPage: encoderSubPages.Other},
  ];
  bindSubPageActivations(page, encoderModeSetups, encoderModes);
}

/**
 *
 * @param {MR_FactoryMappingPage} page
 * @param {LaunchkeyMk4.SubPages['Pads']} padSubPages
 * @param {MR_SurfaceCustomValueVariable[]} padModes
 */
function bindPadModeActivations(page, padSubPages, padModes) {
  var padModeSetups = [
    {ccVal: 0x02, subPage: padSubPages['Select / Arm']},
    {ccVal: 0x0f, subPage: padSubPages.Other},
    {ccVal: 0x04, subPage: padSubPages.Other},
    {ccVal: 0x0d, subPage: padSubPages.Other},
    {ccVal: 0x05, subPage: padSubPages.Other},
    {ccVal: 0x06, subPage: padSubPages.Other},
    {ccVal: 0x07, subPage: padSubPages.Other},
    {ccVal: 0x08, subPage: padSubPages.Other},
  ];
  bindSubPageActivations(page, padModeSetups, padModes);
}

/**
 * Create a mixer bank zone
 * @param {LaunchkeyMk4.Config} config
 * @param {MR_FactoryMappingPage} page
 * @returns {Common.MixerBankZone}
 */
function makeMixerBankZone(config, page) {
  var hostMixerBankZone = page.mHostAccess.mMixConsole
    .makeMixerBankZone()
    .excludeInputChannels()
    .excludeOutputChannels()
    .setFollowVisibility(true);

  var hostMixerBankChannels = [];
  for (
    var channelIndex = 0;
    channelIndex < config.numChannels;
    ++channelIndex
  ) {
    var mixerBankChannel = hostMixerBankZone.makeMixerBankChannel();
    mixerBankChannel.mOnTitleChange = function (
      activeDevice,
      activeMapping,
      name
    ) {
      utils.setTrackName(activeDevice, this, name);
    }.bind(channelIndex);
    hostMixerBankChannels[channelIndex] = mixerBankChannel;
  }

  return {
    zone: hostMixerBankZone,
    channels: hostMixerBankChannels,
  };
}

/**
 *
 * @param {MR_FactoryMappingPage} page
 * @returns {MR_MixerBankChannel}
 */
function makeStereoOut(page) {
  var mixerBankZoneStereoOut = page.mHostAccess.mMixConsole
    .makeMixerBankZone('Stereo Out')
    .includeOutputChannels(); // additional mixerbankzone decorated with channel type filter
  var firstStereoOut = mixerBankZoneStereoOut.makeMixerBankChannel();
  return firstStereoOut;
}

/**
 *
 * @param {LaunchkeyMk4.Config} config
 * @param {MR_FactoryMappingPage} page Page to work in
 * @return {LaunchkeyMk4.SubPages}
 */
function makeSubPages(config, page) {
  var subPages = SubPages.makeSubPageContainer(config, page);

  makeShiftSubPages(subPages);
  makeFaderButtonSubPages(subPages);
  makeFaderSubPages(subPages);
  makeEncoderSubPages(subPages, config.maxSendSlots);
  makePadSubPages(subPages);

  return subPages;
}
/**
 *
 * @param {LaunchkeyMk4.SubPages} subPages
 */
function makeShiftSubPages(subPages) {
  var shiftPageArea = subPages.makeSubPageArea('Shift');

  shiftPageArea.onActivate = function (config, device, name) {
    if (name === 'shifted') {
      utils.sendAllEncodersDisplayTitle(config, device);
    }
  };

  shiftPageArea.makeSubPage('unshifted');
  shiftPageArea.makeSubPage('shifted');
}

/**
 *
 * @param {LaunchkeyMk4.SubPages} subPages
 */
function makeFaderButtonSubPages(subPages) {
  var faderButtonPageArea = subPages.makeSubPageArea('Fader Buttons');

  faderButtonPageArea.onActivate = function (config, device, name) {
    utils.sendFaderButtonsModeChange(config, device, name);
  };

  // Create the 'Arm' and 'Select' sub-pages for the fader buttons
  // The order of creation is important here. The first one created will be the default mode for the arm/select button.
  // To match the spec, create the Arm page first.
  faderButtonPageArea.makeSubPage('Arm');
  faderButtonPageArea.makeSubPage('Select');
}

/**
 *
 * @param {LaunchkeyMk4.SubPages} subPages
 */
function makeFaderSubPages(subPages) {
  var faderSubPageArea = subPages.makeSubPageArea('Faders');
  faderSubPageArea.makeSubPage('Volume');
  faderSubPageArea.makeSubPage('Other');
}

/**
 *
 * @param {LaunchkeyMk4.SubPages} subPages
 * @param {number} maxSendSlots
 */
function makeEncoderSubPages(subPages, maxSendSlots) {
  var subPageAreaName = 'Encoders';
  var encoderSubPageArea = subPages.makeSubPageArea(subPageAreaName);

  encoderSubPageArea.onActivate = function (config, device, name) {
    utils.sendEncodersModeChange(config, device, name);
  };

  // Plugin
  encoderSubPageArea.makeSubPage('Quick Controls');

  // Mixer
  encoderSubPageArea.makeSubPage('Volume', 'Mixer');
  encoderSubPageArea.makeSubPage('Pan', 'Mixer');
  encoderSubPageArea.makeSubPage('EQ', 'Mixer');

  // Sends
  subPages.Encoders.Sends = [];
  for (var sendSlot = 0; sendSlot < maxSendSlots; ++sendSlot) {
    var sendName = 'Sends ' + (sendSlot + 1);
    var subPage = encoderSubPageArea.makeSubPage(sendName, 'Sends');
    // Sends will be addded to the subPages object using the `sendName` variable
    // for example, "Send 1", "Send 2".. etc. This is useful when looking up the
    // sub page using the name.  We also store the "Sends" sub pages in an array
    // for convenience so we can easily grab all the Sends subpages without
    // needing to know how many there are
    subPages.Encoders.Sends.push(subPage);
  }

  // Transport
  encoderSubPageArea.makeSubPage('Transport');

  // Other
  encoderSubPageArea.makeSubPage('Other');
}

/**
 *
 * @param {LaunchkeyMk4.SubPages} subPages
 */
function makePadSubPages(subPages) {
  var subPageAreaName = 'Pads';
  var padSubPageArea = subPages.makeSubPageArea(subPageAreaName);

  padSubPageArea.onActivate = function (config, device, name) {
    utils.sendPadsModeChange(config, device, name);
  };

  // The first pad sub page will be activated by default so order is important here.
  padSubPageArea.makeSubPage('Select / Arm', 'DAW');
  padSubPageArea.makeSubPage('Mute / Solo', 'DAW');
  padSubPageArea.makeSubPage('Other');
}

module.exports = makeHostBindings;
