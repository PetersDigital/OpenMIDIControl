var constants = require('./constants');
var screen = require('./screen');
var utils = require('./base_utils');

/** Reusable Action bindings */
module.exports = {
  /**
   * Sets up binding to turn on the eq band when the encoder value changes
   * @param {Common.Config} config
   * @param {MR_FactoryMappingPage} page Page to work in
   * @param {MR_SubPage} subPage
   * @param {MR_ValueBinding} eqValueBinding
   * @param {MR_ChannelEQBand} eqBand
   * @param {string} eqBandName
   */
  bindEqAutoOn(config, page, eqValueBinding, eqBand, eqBandName) {
    // Create a custom value variable to use to turn on the eq band
    var customValue =
      config.deviceDriver.mSurface.makeCustomValueVariable(eqBandName);
    var binding = page.makeValueBinding(customValue, eqBand.mOn);

    eqValueBinding.mOnValueChange = function (activeDevice) {
      // Ignore if we're within `config.eqAutoOnTimeout` milliseconds of the last time the sub page was activated
      var key = constants.STATE_KEYS.lastSubpageActivedTime;
      var lastSubpageActivedTime = utils.getStateInt(activeDevice, key, 0);
      if (Date.now() - lastSubpageActivedTime > config.eqAutoOnTimeout) {
        customValue.setProcessValue(activeDevice, 1);
      }
    };
    return binding;
  },

  /**
   * Binds the page buttons to cycle through the supplied sub pages
   * @param {[MR_Button, MR_Button]} pageButtons
   * @param {MR_FactoryMappingPage} page Page to work in
   * @param {MR_SubPage[]} subPages
   */
  bindPageButtons(pageButtons, page, subPages) {
    var maxSubPages = subPages.length;

    if (maxSubPages > 0) {
      // Always bind the up button for the first sub page to activate the same sub page, otherwise Cubase will erroneoulsy use other bindings
      var subPage = subPages[0];
      page
        .makeActionBinding(
          pageButtons[0].mSurfaceValue,
          subPage.mAction.mActivate
        )
        .setSubPage(subPage);

      // If there is only one sub page then bind the down button to it, otherwise Cubase will erroneoulsy use other bindings
      if (maxSubPages === 1) {
        page
          .makeActionBinding(
            pageButtons[1].mSurfaceValue,
            subPage.mAction.mActivate
          )
          .setSubPage(subPage);
        return;
      }

      // Bind the up/down buttons to change the active sub page
      subPages.forEach(function (subPage, index) {
        // TODO - Ensure up/down buttons only light up when they can be used
        if (index > 0) {
          // Bind the up button to set the active sub page to the previous sub page
          var subPagePrev = subPages[index - 1];
          page
            .makeActionBinding(
              pageButtons[0].mSurfaceValue,
              subPagePrev.mAction.mActivate
            )
            .setSubPage(subPage);
        }
        if (index < maxSubPages - 1) {
          // Bind the bottom button to set the active sub page to the next sub page
          var subPageNext = subPages[index + 1];
          page
            .makeActionBinding(
              pageButtons[1].mSurfaceValue,
              subPageNext.mAction.mActivate
            )
            .setSubPage(subPage);
        }
      });
    }
  },

  /**
   * Bind the Shift button to activate the shift subpage.
   * @param {MR_FactoryMappingPage} page Page to work in
   * @param {Common.ShiftSubPage} subPages
   * @param {MR_Button} shiftButton
   */
  bindShiftButton(page, subPages, shiftButton) {
    page
      .makeActionBinding(
        shiftButton.mSurfaceValue,
        subPages.shifted.mAction.mActivate
      )
      .setSubPage(subPages.unshifted);
    page
      .makeActionBinding(
        shiftButton.mSurfaceValue,
        subPages.unshifted.mAction.mActivate
      )
      .setSubPage(subPages.shifted)
      .mapToValueRange(1, 0);
  },

  /**
   * Bind the transport locator to a custom value variable and update the locator time on change.
   * @param {Common.Config} config
   * @param {MR_FactoryMappingPage} page Page to work in
   * @param {string} locatorName
   * @param {number} encoderCc
   * @param {string} subPageAreaName
   * @param {string} subPageName
   */
  bindTransportEncoderLocator(
    config,
    page,
    locatorName,
    encoderCc,
    subPageAreaName,
    subPageName
  ) {
    // Listen for the tranport locator time change to cache time, value and active mapping
    var locatorValue = {};
    var locator =
      page.mHostAccess.mTransport.mTimeDisplay.mPrimary[locatorName];
    var updateDisplay = false;
    locator.mOnChange = function (activeDevice, activeMapping, time, format) {
      locatorValue = {
        activeDevice,
        activeMapping,
        time,
        format,
      };
      if (updateDisplay) {
        updateDisplay = false;
        var titleMap = {
          mTransportLocator: 'Scrub',
          mCycleLocatorLeft: constants.TITLES.cycleStart,
          mCycleLocatorRight: constants.TITLES.cycleEnd,
        };
        var title = titleMap[locatorName];
        screen.sendOverlayDisplayText(config, activeDevice, title, time);
      }
    };

    // Create a custom value variable to hold the value bound to the encoder
    var customValue =
      config.deviceDriver.mSurface.makeCustomValueVariable(locatorName);
    customValue.mMidiBinding
      .setInputPort(config.midiInput)
      .bindToControlChange(0x0f, encoderCc)
      .setTypeRelativeBinaryOffset();

    // Listen to the custom variable changes to update the transport locator time
    customValue.mOnProcessValueChange = function (activeDevice, value, diff) {
      var resetValue = 0.5;
      var valueWasReset = value === resetValue && Math.abs(diff) >= 0.4;
      var currentSubPage = utils.getSubPage(activeDevice, subPageAreaName);
      if (currentSubPage !== subPageName || valueWasReset) return;

      var delta = diff > 0 ? 1 : -1;
      var time = utils.adjustTimeString(
        locatorValue.time,
        locatorValue.format,
        delta
      );
      updateDisplay = true;
      locator.setTime(locatorValue.activeMapping, time);

      // Wrap the encoder values to prevent range stops
      if (value < 0.1 || value > 0.9) {
        customValue.setProcessValue(activeDevice, resetValue);
      }
    };
  },

  /**
   *
   * @param {LaunchkeyMk4.Config} config
   * @param {MR_FactoryMappingPage} page Page to work in
   * @param {number} encoderCc
   * @param {string} subPageAreaName
   * @param {string} subPageName
   */
  bindTransportEncoderTempo(
    config,
    page,
    encoderCc,
    subPageAreaName,
    subPageName
  ) {
    // Listen for tempo change to update the display in Transport mode
    var tempoValue = {};
    var timeDisplay = page.mHostAccess.mTransport.mTimeDisplay;
    timeDisplay.mOnChangeTempoBPM = function (
      activeDevice,
      activeMapping,
      bpm
    ) {
      tempoValue = {
        activeDevice,
        activeMapping,
        bpm: Math.round(bpm),
      };
      var currentSubPage = utils.getSubPage(activeDevice, subPageAreaName);
      if (currentSubPage === subPageName) {
        screen.sendOverlayDisplayText(
          config,
          activeDevice,
          'Tempo',
          tempoValue.bpm + ' BPM'
        );
      }
    };

    // Create a custom value variable to hold the value bound to the encoder
    var customValue =
      config.deviceDriver.mSurface.makeCustomValueVariable('tempoEncoder');
    customValue.mMidiBinding
      .setInputPort(config.midiInput)
      .bindToControlChange(0x0f, encoderCc)
      .setTypeRelativeBinaryOffset();

    // Listen to the custom variable changes to update the transport tempo time
    var valueWasReset = false; // Keep outside the function to prevent false positives when trying to calculate the reset inside the function
    customValue.mOnProcessValueChange = function (activeDevice, value, diff) {
      var resetValue = 0.5;
      var currentSubPage = utils.getSubPage(activeDevice, subPageAreaName);
      if (currentSubPage !== subPageName || valueWasReset) {
        valueWasReset = false;
        return;
      }

      diff *= 25; // Multiplier for the encoder sensitivity
      var delta = diff > 0 ? Math.ceil(diff) : Math.floor(diff);
      tempoValue.bpm += delta;
      timeDisplay.setTempoBPM(tempoValue.activeMapping, tempoValue.bpm);

      // Wrap the encoder values to prevent range stops
      if (value < 0.1 || value > 0.9) {
        valueWasReset = true;
        customValue.setProcessValue(activeDevice, resetValue);
      }
    };
  },

  /**
   *
   * @param {Common.Config} config
   * @param {MR_FactoryMappingPage} page
   * @param {Common.IncDecEncoder} incDecEncoder
   * @param {Common.IncDecCommandBinding} commandBinding
   */
  makeTransportEncoderCommandBinding(
    config,
    page,
    incDecEncoder,
    commandBinding
  ) {
    var decValue = incDecEncoder.decValue;
    var incValue = incDecEncoder.incValue;
    var commandCategory = commandBinding.commandCategory;
    var commandName = commandBinding.commandName;

    page.makeCommandBinding(decValue, commandCategory, commandName.dec);
    page.makeCommandBinding(incValue, commandCategory, commandName.inc);

    incDecEncoder.onProcessValueChange = function (activeDevice, value, diff) {
      screen.sendOverlayDisplayText(
        config,
        activeDevice,
        commandBinding.display.title,
        diff > 0 ? commandBinding.display.inc : commandBinding.display.dec
      );
    };
  },
};
