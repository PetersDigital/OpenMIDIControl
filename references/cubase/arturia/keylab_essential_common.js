
//-----------------------------------------------------------------------------
// 2. SURFACE LAYOUT - create control elements and midi bindings
//-----------------------------------------------------------------------------
var buttonsW = 2.5
var buttonsH = 1.5

function makeModWheels(surface, x, y, w, h) {
	surface.makeBlindPanel(x, y, w, h) // dummy pitch bend
	surface.makeBlindPanel(x + 3, y, w, h) // mod wheel
}

function makeFunctionButtons(surface, x, y) {
	surface.makeBlindPanel(x, y, buttonsW, buttonsH) // Chord
	surface.makeBlindPanel(x + 3, y, buttonsW, buttonsH) // Trans
	surface.makeBlindPanel(x, y + 4, buttonsW, buttonsH) // Oct-
	surface.makeBlindPanel(x + 3, y + 4, buttonsW, buttonsH) // Oct+
}

function makeMidiMapButtons(surface, x, y) {
	surface.makeBlindPanel(x, y, buttonsW, buttonsH) // Map Select
	surface.makeBlindPanel(x, y + 2, buttonsW, buttonsH) // MIDI CH
}

function makePads(surface, x, y, w, h) {
	for (var i = 0; i < 4; ++i) {
		surface.makeBlindPanel(x + (i * 3.5), y, w, h)
		surface.makeBlindPanel(x + (i * 3.5), y + 5, w, h)
	}
}

//----------------------------------------------------------------------------------------------------------------------
/**
 * @param {number} x
 * @param {number} y
 * @param {MR_DeviceMidiInput} midiInput
 * @param {MR_DeviceMidiOutput} midiOutput
 * @param {number} midiCh
 * @param {number} pitch
 * @returns {Object}
 */
function makeDawCommandCenter(surface, x, y, midiInput, midiOutput, midiCh, pitch, surfaceElements) {

	surfaceElements.btn_save = surface.makeButton(x, y, buttonsW, buttonsH)
	surfaceElements.btn_save.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToNote(midiCh, pitch)

	surfaceElements.btn_undo = surface.makeButton(x + 5, y, buttonsW, buttonsH)
	surfaceElements.btn_undo.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToNote(midiCh, pitch + 1)

	surfaceElements.btn_activatePunchIn = surface.makeButton(x, y + 2, buttonsW, buttonsH)
	surfaceElements.btn_activatePunchIn.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToNote(midiCh, pitch + 7)

	surfaceElements.btn_activatePunchOut = surface.makeButton(x, y + 2, buttonsW, buttonsH)
	surfaceElements.btn_activatePunchOut.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToNote(midiCh, pitch + 8)

	surfaceElements.btn_activateMetronome = surface.makeButton(x + 5, y + 2, buttonsW, buttonsH)
	surfaceElements.btn_activateMetronome.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToNote(midiCh, pitch + 9)

	surfaceElements.btn_activateMetronome.mSurfaceValue.mOnProcessValueChange = (function (activeDevice, value) {
		if (value > 0)
			this.midiOutput.sendMidi(activeDevice, [0x90, 89, 127])
		else {
			this.midiOutput.sendMidi(activeDevice, [0x90, 89, 0])
			this.midiOutput.sendMidi(activeDevice, [0x80, 89, 0])
		}
	}).bind({ midiOutput })
}

function Helper_updateDisplay(/** @type {string} */idRow1, /** @type {string} */idRow2, /** @type {MR_ActiveDevice} */activeDevice, /** @type {MR_DeviceMidiOutput} */midiOutput) {

	var displayRow1 = activeDevice.getState(idRow1)
	var displayRow2 = activeDevice.getState(idRow2)

	activeDevice.setState('Row1', displayRow1)
	activeDevice.setState('Row2', displayRow2)

	// activeDevice.setState('DisplayRow2', displayRow2)

	var lenRow1 = displayRow1.length < 16 ? displayRow1.length : 16
	var lenRow2 = displayRow2.length < 16 ? displayRow2.length : 16

	var data = [0xF0, 0x00, 0x20, 0x6B, 0x7F, 0x42, 0x04, 0x00, 0x60, 0x01]
	for (var i = 0; i < lenRow1; ++i)
		data.push(displayRow1.charCodeAt(i))
	while (lenRow1++ < 16)
		data.push(0x20)
	data.push(0)

	data.push(0x02)

	for (var i = 0; i < lenRow2; ++i)
		data.push(displayRow2.charCodeAt(i))
	while (lenRow2++ < 16)
		data.push(0x20)
	data.push(0)

	data.push(0xF7)

	midiOutput.sendMidi(activeDevice, data)
}

//----------------------------------------------------------------------------------------------------------------------
/**
 * @param {number} x
 * @param {number} y
 * @param {MR_DeviceMidiInput} midiInput
 * @param {MR_DeviceMidiOutput} midiOutput
 * @param {number} midiCh
 * @returns {Object}
 */
function makeDisplaySection(/** @type {MR_DeviceSurface} */surface, x, y, midiInput, midiOutput, midiCh, surfaceElements) { // x = 47, y = 0

	surfaceElements.knobStripBlindPanel = surface.makeBlindPanel(x + 1, y, 10.5, 2.5)

	surfaceElements.btn_cancel = surface.makeButton(x, y + 3, 2.5, 1.5)
	surfaceElements.btn_cancel.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToNote(0, 101);

	surfaceElements.btn_openBrowser = surface.makeButton(x + 10, y + 3, 2.5, 1.5)
	surfaceElements.btn_openBrowser.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToNote(midiCh, 100);

	surfaceElements.aiKnob = surface.makePushEncoder(x + 3.4, y + 3, 5.6, 6.3)
	surfaceElements.aiKnob.mEncoderValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(midiCh, 60).setTypeRelativeSignedBit()
	surfaceElements.aiKnob.mPushValue.mMidiBinding.setInputPort(midiInput).bindToNote(midiCh, 84)

	surfaceElements.btn_prevTrack = surface.makeButton(x + 1, y + 7, 2.5, 1.5)
	surfaceElements.btn_prevTrack.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToNote(0, 98)

	surfaceElements.btn_nextTrack = surface.makeButton(x + 9, y + 7, 2.5, 1.5)
	surfaceElements.btn_nextTrack.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToNote(0, 99)
}

//----------------------------------------------------------------------------------------------------------------------
/**
 * @param {number} x
 * @param {number} y
 * @param {MR_DeviceMidiInput} midiInput
 * @param {MR_DeviceMidiOutput} midiOutput
 * @param {number} midiCh
 * @param {number} pitch
 * @returns {Object}
 */
function makePagesSubpagesSwitchers(surface, x, y, midiInput, midiOutput, midiCh, pitch, surfaceElements) {

	var prevNext_button_zone = {
		surfaceButton1: surface.makeButton(x, y, buttonsW, buttonsH),
		surfaceButton2: surface.makeButton(x, y + 3.2, buttonsW, buttonsH),
		customValueNext: surface.makeCustomValueVariable('SubPageSwitcherNext'),
		customValuePrev: surface.makeCustomValueVariable('SubPageSwitcherPrev')
	}

	prevNext_button_zone.surfaceButton1.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToNote(midiCh, pitch + 3)
	prevNext_button_zone.surfaceButton2.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToNote(midiCh, pitch + 2)
	prevNext_button_zone.customValueNext.mMidiBinding.setInputPort(midiInput).bindToNote(midiCh, pitch + 1)
	prevNext_button_zone.customValuePrev.mMidiBinding.setInputPort(midiInput).bindToNote(midiCh, pitch)

	prevNext_button_zone.customValueNext.mOnProcessValueChange = function (activeDevice, value) {
		prevNext_button_zone.surfaceButton1.mSurfaceValue.setProcessValue(activeDevice, value)
	}

	prevNext_button_zone.customValuePrev.mOnProcessValueChange = function (activeDevice, value) {
		prevNext_button_zone.surfaceButton2.mSurfaceValue.setProcessValue(activeDevice, value)
	}

	surface.makeBlindPanel(x, 6.4, buttonsW, buttonsH) // Live/Bank button doesn't send MIDI Message

	surfaceElements.prevNext_button_zone = prevNext_button_zone
}

//----------------------------------------------------------------------------------------------------------------------
/**
 * @param {number} x
 * @param {number} y
 * @param {number} w
 * @param {number} h
 * @param {MR_DeviceMidiInput} midiInput
 * @param {MR_DeviceMidiOutput} midiOutput
 * @returns {Object}
 */
function makeTransport(surface, x, y, w, h, midiInput, midiOutput, surfaceElements) {
	var transport = {}
	var currX = x

	function bindMidiNote(button, chn, pitch) {
		button.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToNote(chn, pitch)
	}

	transport.btnCycle = surface.makeButton(currX, y, w, h)
	bindMidiNote(transport.btnCycle, 0, 86)
	currX = currX + w

	transport.btnRewind = surface.makeButton(currX, y, w, h)
	bindMidiNote(transport.btnRewind, 0, 91)
	currX = currX + w

	transport.btnForward = surface.makeButton(currX, y, w, h)
	bindMidiNote(transport.btnForward, 0, 92)
	currX = x
	y += h

	transport.btnStop = surface.makeButton(currX, y, w, h)
	bindMidiNote(transport.btnStop, 0, 93)
	currX = currX + w

	transport.btnStart = surface.makeButton(currX, y, w, h)
	bindMidiNote(transport.btnStart, 0, 94)
	currX = currX + w

	transport.btnRecord = surface.makeButton(currX, y, w, h)
	bindMidiNote(transport.btnRecord, 0, 95)
	currX = currX + w

	surfaceElements.transport = transport
}

//----------------------------------------------------------------------------------------------------------------------
/**
 * @param {number} channelIndex
 * @param {number} x
 * @param {number} y
 * @param {number} w
 * @param {number} h
 * @param {MR_DeviceMidiInput} midiInput
 * @param {MR_DeviceMidiOutput} midiOutput
 * @returns {Object}
 */
function makeFaderStrip(surface, channelIndex, x, y, w, h, midiInput, midiOutput) {
	var faderStrip = {};
	faderStrip.fader = surface.makeFader(x + 3.5 * channelIndex, y + 3, w, h)
	faderStrip.fader.mSurfaceValue.mMidiBinding
		.setInputPort(midiInput)
		.bindToPitchBend(0 + channelIndex)
	return faderStrip
}

/**
 * @param {number} knobIndex
 * @param {number} x
 * @param {number} y
 * @param {number} w
 * @param {number} h
 * @param {MR_DeviceMidiInput} midiInput
 * @param {MR_DeviceMidiOutput} midiOutput
 * @returns {Object}
 */
function makeKnobStrip(surface, knobIndex, x, y, w, h, midiInput, midiOutput) {
	var knobStrip = {}

	knobStrip.knob = surface.makeKnob(x + 3.5 * knobIndex + 19, y, w, h)
	knobStrip.knob.mSurfaceValue.mMidiBinding
		.setInputPort(midiInput)
		.bindToControlChange(0, 16 + knobIndex)
		.setTypeRelativeSignedBit()

	return knobStrip
}

/**
 * @param {number} x
 * @param {number} y
 * @param {MR_DeviceMidiInput} midiInput
 * @param {MR_DeviceMidiOutput} midiOutput
 * @returns {Object}
 */
// function makeChannelStrip(/** @type {MR_MidiRemoteAPI} */midiremote_api, surface, x, y, stripSize, midiInput)
function makeChannelStrip(/** @type {MR_DeviceSurface} */surface, x, y, stripSize, midiInput, midiOutput, surfaceElements) {
	surfaceElements.numStrips = stripSize

	var labelFieldKnobs = surface.makeLabelField(x + 19, y, 3.5 * surfaceElements.numStrips, 1)
	var labelFieldAsSeparator = surface.makeLabelField(x + 19, y + 3.75, 3.5 * surfaceElements.numStrips, 1)

	surfaceElements.labelFieldKnobs = labelFieldKnobs
	surfaceElements.knobStrips = {}
	surfaceElements.faderStrips = {}

	for (var i = 0; i < surfaceElements.numStrips; ++i) {
		surfaceElements.knobStrips[i] = makeKnobStrip(surface, i, x, y + 1, 2.5, 3, midiInput, midiOutput)
		surfaceElements.faderStrips[i] = makeFaderStrip(surface, i, x + 19.250, y + 1.5, 2, 5, midiInput, midiOutput)

		labelFieldKnobs.relateTo(surfaceElements.knobStrips[i].knob)

		var labelFieldFader = surface.makeLabelField(x + 18.5 + i * 3.5, y + 9.5, 3.5, 1)
		labelFieldFader.relateTo(surfaceElements.faderStrips[i].fader)
	}

	surface.makeBlindPanel(x + 47, y + 1, 2.5, 2.5).setShapeCircle()  // Doesn't send any MIDI data????

	// surfaceElements.masterKnob = makeKnobStrip(deviceDriver, 8, x, y, 2.5, 3, midiInput)// Doesn't send any MIDI data????
	surfaceElements.masterFader = makeFaderStrip(surface, 8, x + 19.250, y + 1.5, 2, 5, midiInput, midiOutput)
	var labelFieldMasterFader = surface.makeLabelField(x + 18.5 + 8 * 3.5, y + 9.5, 3.5, 1)
	labelFieldMasterFader.relateTo(surfaceElements.masterFader.fader)
}

//-----------------------------------------------------------------------------
// 3. HOST MAPPING - create mapping pages and host bindings
//-----------------------------------------------------------------------------
function makePageWithDefaults(name, /** @type {MR_DeviceDriver} */deviceDriver, surfaceElements, hostDefaults, midiOutput) {
	/** @type {MR_FactoryMappingPage} */
	var page = deviceDriver.mMapping.makePage(name)

	page.makeValueBinding(surfaceElements.transport.btnRewind.mSurfaceValue, page.mHostAccess.mTransport.mValue.mRewind).setTypeToggle()
	page.makeValueBinding(surfaceElements.transport.btnForward.mSurfaceValue, page.mHostAccess.mTransport.mValue.mForward).setTypeToggle()
	page.makeValueBinding(surfaceElements.transport.btnStop.mSurfaceValue, page.mHostAccess.mTransport.mValue.mStop).setTypeToggle()
	page.makeValueBinding(surfaceElements.transport.btnStart.mSurfaceValue, page.mHostAccess.mTransport.mValue.mStart).setTypeToggle()
	page.makeValueBinding(surfaceElements.transport.btnCycle.mSurfaceValue, page.mHostAccess.mTransport.mValue.mCycleActive).setTypeToggle()
	page.makeValueBinding(surfaceElements.transport.btnRecord.mSurfaceValue, page.mHostAccess.mTransport.mValue.mRecord).setTypeToggle()

	page.makeValueBinding(surfaceElements.aiKnob.mEncoderValue, page.mHostAccess.mMouseCursor.mValueUnderMouse)
	page.makeValueBinding(surfaceElements.aiKnob.mPushValue, page.mHostAccess.mMouseCursor.mValueLocked).setTypeToggle()

	page.makeCommandBinding(surfaceElements.btn_save.mSurfaceValue, "File", "Save")
	page.makeCommandBinding(surfaceElements.btn_undo.mSurfaceValue, "Edit", "Undo")
	page.makeCommandBinding(surfaceElements.btn_activatePunchIn.mSurfaceValue, "Transport", "Auto Punch In")
	page.makeCommandBinding(surfaceElements.btn_activatePunchOut.mSurfaceValue, "Transport", "Auto Punch Out")
	page.makeValueBinding(surfaceElements.btn_activateMetronome.mSurfaceValue, page.mHostAccess.mTransport.mValue.mMetronomeActive).setTypeToggle()

	page.makeCommandBinding(surfaceElements.btn_openBrowser.mSurfaceValue, 'Preset', 'Open/Close Browser')
	page.makeValueBinding(surfaceElements.btn_cancel.mSurfaceValue, page.mHostAccess.mTrackSelection.mMixerChannel.mValue.mInstrumentOpen).setTypeToggle()

	page.makeCommandBinding(surfaceElements.btn_prevTrack.mSurfaceValue, 'Navigate', 'Up')
	page.makeCommandBinding(surfaceElements.btn_nextTrack.mSurfaceValue, 'Navigate', 'Down')

	var hostMixerBankZone = page.mHostAccess.mMixConsole.makeMixerBankZone()
	return { page }
}

//----------------------------------------------------------------------------------------------------------------------
/**
 * 
 * @param {MR_HostDefaults} hostDefaults 
 * @param {MR_DeviceDriver} deviceDriver 
 * @param {Object} surfaceElements 
 * @returns 
 */
function makePageQuickControls(hostDefaults, deviceDriver, surfaceElements, /** @type {MR_DeviceMidiOutput} */midiOutput) {
	var pageDefaults = makePageWithDefaults('Quick Controls', deviceDriver, surfaceElements, hostDefaults, midiOutput)
	var page = pageDefaults.page

	var focusQuickControls = page.mHostAccess.mFocusedQuickControls

	var quickControls = []

	var qcSize = Math.min(hostDefaults.getNumberOfQuickControls(), 8)

	function locfunc_updateDisplay(/** @type {MR_ActiveDevice} */activeDevice, /** @type {MR_DeviceMidiOutput} */midiOutput, qcSize) {
		var trackTitle = activeDevice.getState('TrackTitle')

		var fqcObjectTitles = []
		for (var i = 0; i < qcSize; ++i) {
			var currObjectTitle = activeDevice.getState('FQCObjectTitle' + i.toString())
			console.log(currObjectTitle)
			if (!!currObjectTitle && fqcObjectTitles.indexOf(currObjectTitle) === -1)
				fqcObjectTitles.push(currObjectTitle)
		}

		var fqcObjectTitle =
			fqcObjectTitles.length === 1 ? fqcObjectTitles[0] : 'Quick Controls'

		fqcObjectTitle =
			!fqcObjectTitle ? 'Quick Controls' :
				trackTitle.indexOf(fqcObjectTitle) !== -1 ? 'Quick Controls' :
					fqcObjectTitle.indexOf(trackTitle) !== -1 ? fqcObjectTitle :
						fqcObjectTitle

		activeDevice.setState('Row1', fqcObjectTitle)
		Helper_updateDisplay('Row1', 'TrackTitle', activeDevice, midiOutput)
	}

	for (var qcIndex = 0; qcIndex < qcSize; ++qcIndex) {
		var quickControl = focusQuickControls.getByIndex(qcIndex)
		page.makeValueBinding(
			surfaceElements.knobStrips[qcIndex].knob.mSurfaceValue,
			quickControl
		)
		quickControls.push(quickControl)

		quickControl.mOnTitleChange = (function (activeDevice, activeMapping, objectTitle) {
			activeDevice.setState('FQCObjectTitle' + this.qcIndex.toString(), objectTitle)
			if (this.qcIndex === qcSize - 1)
				locfunc_updateDisplay(activeDevice, midiOutput, this.qcIndex)
		}).bind({ midiOutput, qcIndex, qcSize })
	}

	page.mHostAccess.mTrackSelection.mMixerChannel.mValue.mVolume.mOnTitleChange = (function (activeDevice, activeMapping, objectTitle) {
		activeDevice.setState('TrackTitle', objectTitle)
	}).bind({ midiOutput })

	var onActivate = (function (activeDevice) {
		activeDevice.setState('PageInfo', 'Quick Controls')
		locfunc_updateDisplay(activeDevice, this.midiOutput, this.qcSize)
	}).bind({ midiOutput, qcSize })

	return { page, onActivate }
}

//----------------------------------------------------------------------------------------------------------------------
/**
 * 
 * @param {MR_HostDefaults} hostDefaults 
 * @param {MR_DeviceDriver} deviceDriver 
 * @param {Object} surfaceElements 
 * @returns 
 */
function makePageMixer(hostDefaults, deviceDriver, surfaceElements, /** @type {MR_DeviceMidiOutput} */midiOutput) {
	var pageDefaults = makePageWithDefaults('Mixer', deviceDriver, surfaceElements, hostDefaults, midiOutput)
	var page = pageDefaults.page

	var hostMixerBankZone = page.mHostAccess.mMixConsole.makeMixerBankZone()
		.excludeInputChannels()
		.excludeOutputChannels()

	var hostMixerBankZoneOutputs = page.mHostAccess.mMixConsole.makeMixerBankZone('Main')
		.includeOutputChannels()
	var hostMixerChannelMainOut = hostMixerBankZoneOutputs.makeMixerBankChannel()

	var mixerBankZoneChannels = []
	for (var chIndex = 0; chIndex < 8; ++chIndex)
		mixerBankZoneChannels.push(hostMixerBankZone.makeMixerBankChannel())

	function bindChannelBankItem(index) {
		var channelBankItem = mixerBankZoneChannels[index]
		var faderValue = surfaceElements.faderStrips[index].fader.mSurfaceValue
		page.makeValueBinding(faderValue, channelBankItem.mValue.mVolume).setValueTakeOverModeScaled()
	}

	for (var i = 0; i < 8; ++i) {
		bindChannelBankItem(i)
	}

	page.makeValueBinding(surfaceElements.masterFader.fader.mSurfaceValue, hostMixerChannelMainOut.mValue.mVolume).setValueTakeOverModeScaled()
	
	function locfunc_updateDisplay(activeDevice) {
		var bankInfo = activeDevice.getState('BankInfoFirst')
		if(bankInfo.length > 7)
			bankInfo = bankInfo.substring(0, 4) + (bankInfo.substring(bankInfo.length - 3))
		/** @type {string} */
		var bankInfoFinal = activeDevice.getState('BankInfoFinal')
		if (bankInfoFinal) {
			if(bankInfoFinal.length > 7)
				bankInfoFinal = bankInfoFinal.substring(0, 4) + bankInfoFinal.substring(bankInfoFinal.length - 3)
			bankInfo += '..' + bankInfoFinal
		}	
		activeDevice.setState('BankInfo', bankInfo)
		Helper_updateDisplay('PageInfo', 'BankInfo', activeDevice, midiOutput)
	}

	if (mixerBankZoneChannels.length > 0)
		mixerBankZoneChannels[0].mValue.mVolume.mOnTitleChange = function (activeDevice, activeMapping, objectTitle) {
			activeDevice.setState('BankInfoFirst', objectTitle)
		}
	if (mixerBankZoneChannels.length > 1)
		mixerBankZoneChannels[mixerBankZoneChannels.length - 1].mValue.mVolume.mOnTitleChange = function (activeDevice, activeMapping, objectTitle) {
			activeDevice.setState('BankInfoFinal', objectTitle)
			locfunc_updateDisplay(activeDevice)
		}

	var numKnobStrips = Object.keys(surfaceElements.knobStrips).length
	// console.log('numKnobStrips:' + numKnobStrips.toString())

	var subPageAreaKnobs = page.makeSubPageArea('Knobs')

	

	function forEachKnob(funcVisitKnob) {
		for (var i = 0; i < numKnobStrips; ++i)
			funcVisitKnob(surfaceElements.knobStrips[i].knob, i)
	}

	var subPageAreaKnobsPan = subPageAreaKnobs.makeSubPage('Pan')
	forEachKnob((function (/** @type {MR_Knob} */knob, /** @type {number} */index) {
		var subPage = this.subPageAreaKnobsPan
		// console.log('SP PAN - i: ' + index.toString())
		page.makeValueBinding(knob.mSurfaceValue, mixerBankZoneChannels[index].mValue.mPan)
			.setSubPage(subPage)
		subPage.mOnActivate = (function (activeDevice) {
			activeDevice.setState('PageInfo', 'Mixer - Pan')
			locfunc_updateDisplay(activeDevice)
		}).bind({ midiOutput })
		
	}).bind({ subPageAreaKnobsPan, mixerBankZoneChannels }))

	var numSends = hostDefaults.getNumberOfSendSlots()

	for (var sendIndex = 0; sendIndex < numSends; ++sendIndex) {
		var subPage = subPageAreaKnobs.makeSubPage('Send ' + (sendIndex + 1).toString())
		forEachKnob((function (/** @type {MR_Knob} */knob, /** @type {number} */index) {
			var subPage = this.subPage
			var sendIndex = this.sendIndex
			// console.log('SP Sends[' + (sendIndex + 1).toString() + '] - i: ' + index.toString())
			page.makeValueBinding(knob.mSurfaceValue, mixerBankZoneChannels[index].mSends.getByIndex(sendIndex).mLevel)
				.setSubPage(subPage)
			subPage.mOnActivate = (function (activeDevice) {
				activeDevice.setState('PageInfo', 'Mixer - Sends ' + (sendIndex + 1).toString())
				locfunc_updateDisplay(activeDevice)
			}).bind({ midiOutput })
		}).bind({ subPage, sendIndex }))
	}

	page.makeActionBinding(surfaceElements.prevNext_button_zone.surfaceButton1.mSurfaceValue, subPageAreaKnobs.mAction.mNext)
	page.makeActionBinding(surfaceElements.prevNext_button_zone.surfaceButton2.mSurfaceValue, subPageAreaKnobs.mAction.mPrev)

	var onActivate = (function (activeDevice) {
		activeDevice.setState('PageInfo', 'Mixer - Pan')
		activeDevice.setState('BankInfo', '')
		activeDevice.setState('BankInfoFirst', '')
		activeDevice.setState('BankInfoFinal', '')
		locfunc_updateDisplay(activeDevice)
	}).bind({ midiOutput })

	return { page, onActivate }
}

//----------------------------------------------------------------------------------------------------------------------
/**
 * @param {MR_HostDefaults} hostDefaults
 * @param {MR_DeviceDriver} deviceDriver
 * @param {Object} surfaceElements
 */
function makeHostMapping(hostDefaults, deviceDriver, surfaceElements, surface, midiOutput) {

	var resPageQCs = makePageQuickControls(hostDefaults, deviceDriver, surfaceElements, midiOutput)
	var pageQCs = resPageQCs.page
	pageQCs.mOnActivate = (function (context) {
		onActivatePageDefault(context, deviceDriver, surfaceElements, surface, midiOutput)
		this.onActivate(context)
	}).bind({ onActivate: resPageQCs.onActivate })

	var resPageMixer = makePageMixer(hostDefaults, deviceDriver, surfaceElements, midiOutput)
	var pageMixer = resPageMixer.page
	pageMixer.mOnActivate = (function (context) {
		onActivatePageDefault(context, deviceDriver, surfaceElements, surface, midiOutput)
		this.onActivate(context)
	}).bind({ onActivate: resPageMixer.onActivate })
}

//----------------------------------------------------------------------------------------------------------------------
// 4. Feedback to the HW controller
//----------------------------------------------------------------------------------------------------------------------
function onActivatePageDefault(context, deviceDriver, surfaceElements, surface, midiOutput) {

	context.setState('TrackTitle', '')
	context.setState('PageInfo', '')
	Helper_updateDisplay('TrackTitle', 'PageInfo', context, midiOutput)

	function sendNoteOut(surfaceElement, NoteNr) {
		surfaceElement.mSurfaceValue.mOnProcessValueChange = function (context, newValue) {
			midiOutput.sendMidi(context, [0x90, NoteNr, Math.round(newValue * 127)])
			// console.log('newValue: ' + newValue)
		}
	}

	sendNoteOut(surfaceElements.transport.btnCycle, 86)
	sendNoteOut(surfaceElements.transport.btnRewind, 91)
	sendNoteOut(surfaceElements.transport.btnForward, 92)
	sendNoteOut(surfaceElements.transport.btnStop, 93)
	sendNoteOut(surfaceElements.transport.btnStart, 94)
	sendNoteOut(surfaceElements.transport.btnRecord, 95)

	sendNoteOut(surfaceElements.prevNext_button_zone.surfaceButton1, 49)
	sendNoteOut(surfaceElements.prevNext_button_zone.surfaceButton2, 48)

	// sendNoteOut(surface.btn_activatePunchIn, 87) // Cubase doesn't send this data out
	// sendNoteOut(surface.btn_activateMetronome, 89) // Cubase doesn't send this data out
}

//----------------------------------------------------------------------------------------------------------------------
// 4. Feedback to the HW controller
//----------------------------------------------------------------------------------------------------------------------
/**
 * 
 * @param {MR_DeviceDriver} deviceDriver
 * @param {MR_DeviceMidiOutput} midiOutput
 */
function makeActivationHandling(deviceDriver, midiOutput) {
	deviceDriver.mOnActivate = function (context) {

		// turn off 'vegas mode'
		midiOutput.sendMidi(context, [
			0xF0, 0x00, 0x20, 0x6B, 0x7F, 0x42, 0x02, 0x00, 0x40, 0x50, 0x00, 0xF7
		])

		// switch to DAW mode
		midiOutput.sendMidi(context, [
			0xF0, 0x00, 0x20, 0x6B, 0x7F, 0x42, 0x05, 0x02, 0xF7
		])

		// turn on DAW mode 'Mackie'
		midiOutput.sendMidi(context, [
			0xF0, 0x00, 0x20, 0x6B, 0x7F, 0x42, 0x02, 0x00, 0x40, 0x51, 0x00, 0xF7
		])

		// turn on DAW fader mode 'Jump'
		midiOutput.sendMidi(context, [
			0xF0, 0x00, 0x20, 0x6B, 0x7F, 0x42, 0x02, 0x00, 0x40, 0x52, 0x01, 0xF7
		])
	}
}

//-----------------------------------------------------------------------------
// RETURN to require ----------------------------------------------------------
//-----------------------------------------------------------------------------
module.exports = {
	makeModWheels,
	makeFunctionButtons,
	makeMidiMapButtons,
	makePads,
	makeDawCommandCenter,
	makeTransport,
	makeDisplaySection,
	makePagesSubpagesSwitchers,
	makeChannelStrip,
	makeHostMapping,
	makeActivationHandling
}
