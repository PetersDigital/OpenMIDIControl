//----------------------------------------------------------------------------------------------------------------------
// 1. DRIVER SETUP - create driver object, midi ports and detection information
//----------------------------------------------------------------------------------------------------------------------

var midiremote_api = require('midiremote_api_v1')
var deviceDriver = midiremote_api.makeDeviceDriver('Korg', 'nanoKONTROL2', 'Steinberg Media Technologies GmbH')

var midiInput = deviceDriver.mPorts.makeMidiInput()
var midiOutput = deviceDriver.mPorts.makeMidiOutput()

deviceDriver.makeDetectionUnit().detectPortPair(midiInput, midiOutput)
	.expectSysexIdentityResponse('42', '1301', '0000')

var surface = deviceDriver.mSurface

//----------------------------------------------------------------------------------------------------------------------
function switchDeviceToCcModeWithExternalLed(context) {
	var initData = [
		[0xF0, 0x7E, 0x00, 0x06, 0x02, 0x42, 0x13, 0x01, 0x00, 0x00, 0x03, 0x00, 0x01, 0x00, 0xF7],
		[0xF0, 0x42, 0x40, 0x00, 0x01, 0x13, 0x00, 0x5F, 0x42, 0x00, 0xF7],
		[0xF0, 0x7E, 0x00, 0x06, 0x02, 0x42, 0x13, 0x01, 0x00, 0x00, 0x03, 0x00, 0x01, 0x00, 0xF7],

		[0xF0, 0x42, 0x40, 0x00, 0x01, 0x13, 0x00, 0x7F, 0x7F, 0x02, 0x03, 0x05, 0x40, 0x00, 0x00, 0x00,
			0x01, 0x10, 0x01, 0x00, 0x00, 0x00, 0x00, 0x7F, 0x00, 0x01, 0x00, 0x10, 0x00, 0x00, 0x7F, 0x00,
			0x01, 0x00, 0x20, 0x00, 0x7F, 0x00, 0x00, 0x01, 0x00, 0x30, 0x00, 0x7F, 0x00, 0x00, 0x01, 0x00,
			0x40, 0x00, 0x7F, 0x00, 0x10, 0x00, 0x01, 0x00, 0x01, 0x00, 0x7F, 0x00, 0x01, 0x00, 0x00, 0x11,
			0x00, 0x7F, 0x00, 0x01, 0x00, 0x00, 0x21, 0x00, 0x7F, 0x00, 0x01, 0x00, 0x31, 0x00, 0x00, 0x7F,
			0x00, 0x01, 0x00, 0x41, 0x00, 0x00, 0x7F, 0x00, 0x10, 0x01, 0x00, 0x02, 0x00, 0x00, 0x7F, 0x00,
			0x01, 0x00, 0x12, 0x00, 0x7F, 0x00, 0x00, 0x01, 0x00, 0x22, 0x00, 0x7F, 0x00, 0x00, 0x01, 0x00,
			0x32, 0x00, 0x7F, 0x00, 0x01, 0x00, 0x00, 0x42, 0x00, 0x7F, 0x00, 0x10, 0x01, 0x00, 0x00, 0x03,
			0x00, 0x7F, 0x00, 0x01, 0x00, 0x00, 0x13, 0x00, 0x7F, 0x00, 0x01, 0x00, 0x23, 0x00, 0x00, 0x7F,
			0x00, 0x01, 0x00, 0x33, 0x00, 0x00, 0x7F, 0x00, 0x01, 0x00, 0x43, 0x00, 0x7F, 0x00, 0x00, 0x10,
			0x01, 0x00, 0x04, 0x00, 0x7F, 0x00, 0x00, 0x01, 0x00, 0x14, 0x00, 0x7F, 0x00, 0x00, 0x01, 0x00,
			0x24, 0x00, 0x7F, 0x00, 0x01, 0x00, 0x00, 0x34, 0x00, 0x7F, 0x00, 0x01, 0x00, 0x00, 0x44, 0x00,
			0x7F, 0x00, 0x10, 0x01, 0x00, 0x00, 0x05, 0x00, 0x7F, 0x00, 0x01, 0x00, 0x15, 0x00, 0x00, 0x7F,
			0x00, 0x01, 0x00, 0x25, 0x00, 0x00, 0x7F, 0x00, 0x01, 0x00, 0x35, 0x00, 0x7F, 0x00, 0x00, 0x01,
			0x00, 0x45, 0x00, 0x7F, 0x00, 0x00, 0x10, 0x01, 0x00, 0x06, 0x00, 0x7F, 0x00, 0x00, 0x01, 0x00,
			0x16, 0x00, 0x7F, 0x00, 0x01, 0x00, 0x00, 0x26, 0x00, 0x7F, 0x00, 0x01, 0x00, 0x00, 0x36, 0x00,
			0x7F, 0x00, 0x01, 0x00, 0x46, 0x00, 0x00, 0x7F, 0x00, 0x10, 0x01, 0x00, 0x07, 0x00, 0x00, 0x7F,
			0x00, 0x01, 0x00, 0x17, 0x00, 0x00, 0x7F, 0x00, 0x01, 0x00, 0x27, 0x00, 0x7F, 0x00, 0x00, 0x01,
			0x00, 0x37, 0x00, 0x7F, 0x00, 0x00, 0x01, 0x00, 0x47, 0x00, 0x7F, 0x00, 0x10, 0x00, 0x01, 0x00,
			0x3A, 0x00, 0x7F, 0x00, 0x01, 0x00, 0x00, 0x3B, 0x00, 0x7F, 0x00, 0x01, 0x00, 0x00, 0x2E, 0x00,
			0x7F, 0x00, 0x01, 0x00, 0x3C, 0x00, 0x00, 0x7F, 0x00, 0x01, 0x00, 0x3D, 0x00, 0x00, 0x7F, 0x00,
			0x01, 0x00, 0x3E, 0x00, 0x7F, 0x00, 0x00, 0x01, 0x00, 0x2B, 0x00, 0x7F, 0x00, 0x00, 0x01, 0x00,
			0x2C, 0x00, 0x7F, 0x00, 0x01, 0x00, 0x00, 0x2A, 0x00, 0x7F, 0x00, 0x01, 0x00, 0x00, 0x29, 0x00,
			0x7F, 0x00, 0x01, 0x00, 0x2D, 0x00, 0x00, 0x7F, 0x00, 0x7F, 0x7F, 0x7F, 0x7F, 0x00, 0x7F, 0x00,
			0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
			0x00, 0xF7]
	]

	for (var i = 0; i < initData.length; ++i) {
		midiOutput.sendMidi(context, initData[i]);
	}
}

//----------------------------------------------------------------------------------------------------------------------
// 2. SURFACE LAYOUT - create control elements and midi bindings
//----------------------------------------------------------------------------------------------------------------------

function makeFaderStrip(channelIndex, x, y, surfaceElements) {
	var faderStrip = {}

	var buttonSize = 1.5
	faderStrip.btnSolo = surface.makeButton(x + 4 * channelIndex, y, buttonSize, buttonSize)
	faderStrip.btnMute = surface.makeButton(x + 4 * channelIndex, y + 2, buttonSize, buttonSize)
	faderStrip.btnRec = surface.makeButton(x + 4 * channelIndex, y + 4, buttonSize, buttonSize)
	faderStrip.fader = surface.makeFader(x + 4 * channelIndex + 1.85, y, 1.3, 5.5).setTypeVertical()

	surfaceElements.bottomLabelField.relateTo(faderStrip.btnSolo)
	surfaceElements.bottomLabelField.relateTo(faderStrip.btnMute)
	surfaceElements.bottomLabelField.relateTo(faderStrip.btnRec)
	surfaceElements.bottomLabelField.relateTo(faderStrip.fader)

	surfaceElements.bottomLabelFields[channelIndex].relateTo(faderStrip.btnSolo)
	surfaceElements.bottomLabelFields[channelIndex].relateTo(faderStrip.btnMute)
	surfaceElements.bottomLabelFields[channelIndex].relateTo(faderStrip.btnRec)
	surfaceElements.bottomLabelFields[channelIndex].relateTo(faderStrip.fader)

	faderStrip.btnSolo.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToControlChange(0, 32 + channelIndex)
	faderStrip.btnMute.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToControlChange(0, 48 + channelIndex)
	faderStrip.btnRec.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToControlChange(0, 64 + channelIndex)
	faderStrip.fader.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(0, 0 + channelIndex)

	return faderStrip
}

function makeKnobStrip(knobIndex, x, y, surfaceElements) {
	var knobStrip = {}

	knobStrip.knob = surface.makeKnob(x + 4 * knobIndex + 0.1, y, 1.8, 2.2)
	knobStrip.knob.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(0, 16 + knobIndex)

	surfaceElements.bottomLabelField.relateTo(knobStrip.knob)
	surfaceElements.bottomLabelFields[knobIndex].relateTo(knobStrip.knob)

	return knobStrip
}

//----------------------------------------------------------------------------------------------------------------------
function makeTransport(x, y) {
	var transport = {}

	var w = 2
	var h = 2
	var spacing = 0.5

	var currX = x

	function bindMidiCC(button, chn, num) {
		button.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToControlChange(chn, num)
	}

	transport.btnCycle = surface.makeButton(currX, y - 1.6, 2, 1)
	bindMidiCC(transport.btnCycle, 0, 46)

	transport.btnRewind = surface.makeButton(currX, y, w, h)
	bindMidiCC(transport.btnRewind, 0, 43)
	currX = currX + w + spacing

	transport.btnForward = surface.makeButton(currX, y, w, h)
	bindMidiCC(transport.btnForward, 0, 44)
	currX = currX + w + spacing

	transport.btnStop = surface.makeButton(currX, y, w, h)
	bindMidiCC(transport.btnStop, 0, 42)
	currX = currX + w + spacing

	transport.btnStart = surface.makeButton(currX, y, w, h)
	bindMidiCC(transport.btnStart, 0, 41)
	currX = currX + w + spacing

	transport.btnRecord = surface.makeButton(currX, y, w, h)
	bindMidiCC(transport.btnRecord, 0, 45)
	currX = currX + w + spacing

	return transport
}

//----------------------------------------------------------------------------------------------------------------------
function makeSurfaceElements() {
	var surfaceElements = {}

	surfaceElements.bottomLabelField = surface.makeLabelField(13, 10, 32, 1)

	var bottomLabelFields = []
	for (var i = 0; i < 8; ++i) {
		bottomLabelFields.push(surface.makeLabelField(13 + (i * 4), 8.5, 4, 1))
	}
	surfaceElements.bottomLabelFields = bottomLabelFields

	// surfaceElements.bottomLabelField0 = surface.makeLabelField(17, 10, 4, 1)

	var x = 0
	var y = 2.75

	surfaceElements.btn_prevTrack = surface.makeButton(x, y, 2, 1)
	surfaceElements.btn_prevTrack.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToControlChange(0, 58)

	surfaceElements.btn_nextTrack = surface.makeButton(x + 2.5, y, 2, 1)
	surfaceElements.btn_nextTrack.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToControlChange(0, 59)

	surfaceElements.btn_inserMarker = surface.makeButton(x + 5, y + 2, 2, 1)
	surfaceElements.btn_inserMarker.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToControlChange(0, 60)

	surfaceElements.btn_prevMarker = surface.makeButton(x + 7.5, y + 2, 2, 1)
	surfaceElements.btn_prevMarker.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToControlChange(0, 61)

	surfaceElements.btn_nextMarker = surface.makeButton(x + 10, y + 2, 2, 1)
	surfaceElements.btn_nextMarker.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToControlChange(0, 62)

	surfaceElements.numStrips = 8

	surfaceElements.knobStrips = {}
	surfaceElements.faderStrips = {}

	x = 14.5
	y = 0

	for (var i = 0; i < surfaceElements.numStrips; ++i) {
		surfaceElements.knobStrips[i] = makeKnobStrip(i, x, y, surfaceElements)
		surfaceElements.faderStrips[i] = makeFaderStrip(i, 13, 2.5, surfaceElements)
	}

	surfaceElements.transport = makeTransport(0, 6.3)
	surfaceElements.deviceName = surface.makeLabelField(0, 1, 8, 1)

	return surfaceElements
}

var surfaceElements = makeSurfaceElements()

//----------------------------------------------------------------------------------------------------------------------
// 3. HOST MAPPING - create mapping pages and host bindings
//----------------------------------------------------------------------------------------------------------------------

function makePageWithDefaults(name) {
	var page = deviceDriver.mMapping.makePage(name)

	page.setLabelFieldText(surfaceElements.deviceName, 'nanoKONTROL2')

	page.makeCommandBinding(surfaceElements.btn_inserMarker.mSurfaceValue, "Transport", "Insert Marker")
	page.makeCommandBinding(surfaceElements.btn_prevMarker.mSurfaceValue, "Transport", "Locate Previous Marker")
	page.makeCommandBinding(surfaceElements.btn_nextMarker.mSurfaceValue, "Transport", "Locate Next Marker")

	page.makeValueBinding(surfaceElements.transport.btnRewind.mSurfaceValue, page.mHostAccess.mTransport.mValue.mRewind)
	page.makeValueBinding(surfaceElements.transport.btnForward.mSurfaceValue, page.mHostAccess.mTransport.mValue.mForward)
	page.makeValueBinding(surfaceElements.transport.btnStop.mSurfaceValue, page.mHostAccess.mTransport.mValue.mStop).setTypeToggle()
	page.makeValueBinding(surfaceElements.transport.btnStart.mSurfaceValue, page.mHostAccess.mTransport.mValue.mStart).setTypeToggle()
	page.makeValueBinding(surfaceElements.transport.btnCycle.mSurfaceValue, page.mHostAccess.mTransport.mValue.mCycleActive).setTypeToggle()
	page.makeValueBinding(surfaceElements.transport.btnRecord.mSurfaceValue, page.mHostAccess.mTransport.mValue.mRecord).setTypeToggle()

	return page
}

//----------------------------------------------------------------------------------------------------------------------
function makePageMixer() {
	var page = makePageWithDefaults('Mixer')

	var hostMixerBankZone = page.mHostAccess.mMixConsole.makeMixerBankZone()
		.excludeInputChannels()
		.excludeOutputChannels()

	for (var i = 0; i < 8; ++i) {
		var channelBankItem = hostMixerBankZone.makeMixerBankChannel()

		page.makeActionBinding(surfaceElements.btn_prevTrack.mSurfaceValue, hostMixerBankZone.mAction.mPrevBank)
		page.makeActionBinding(surfaceElements.btn_nextTrack.mSurfaceValue, hostMixerBankZone.mAction.mNextBank)

		var knobValue = surfaceElements.knobStrips[i].knob.mSurfaceValue

		var soloValue = surfaceElements.faderStrips[i].btnSolo.mSurfaceValue
		var muteValue = surfaceElements.faderStrips[i].btnMute.mSurfaceValue
		var recValue = surfaceElements.faderStrips[i].btnRec.mSurfaceValue
		var faderValue = surfaceElements.faderStrips[i].fader.mSurfaceValue

		page.makeValueBinding(knobValue, channelBankItem.mValue.mPan).setValueTakeOverModeScaled()
		page.makeValueBinding(soloValue, channelBankItem.mValue.mSolo).setTypeToggle()
		page.makeValueBinding(muteValue, channelBankItem.mValue.mMute).setTypeToggle()
		page.makeValueBinding(recValue, channelBankItem.mValue.mRecordEnable).setTypeToggle()
		page.makeValueBinding(faderValue, channelBankItem.mValue.mVolume).setValueTakeOverModeScaled()
	}

	return page
}

//----------------------------------------------------------------------------------------------------------------------
function makePageSelectedTrack() {
	var page = makePageWithDefaults('Selected Track')

	page.makeActionBinding(surfaceElements.btn_prevTrack.mSurfaceValue, page.mHostAccess.mTrackSelection.mAction.mPrevTrack)
	page.makeActionBinding(surfaceElements.btn_nextTrack.mSurfaceValue, page.mHostAccess.mTrackSelection.mAction.mNextTrack)

	var selectedTrackChannel = page.mHostAccess.mTrackSelection.mMixerChannel
	for (var i = 0; i < 8; ++i) {
		page.makeValueBinding(surfaceElements.knobStrips[i].knob.mSurfaceValue, page.mHostAccess.mTrackSelection.mMixerChannel.mQuickControls.getByIndex(i)).setValueTakeOverModeScaled()
		page.makeValueBinding(surfaceElements.faderStrips[i].fader.mSurfaceValue, selectedTrackChannel.mSends.getByIndex(i).mLevel).setValueTakeOverModeScaled()
		page.makeValueBinding(surfaceElements.faderStrips[i].btnSolo.mSurfaceValue, selectedTrackChannel.mSends.getByIndex(i).mOn).setTypeToggle()
		page.makeValueBinding(surfaceElements.faderStrips[i].btnMute.mSurfaceValue, selectedTrackChannel.mSends.getByIndex(i).mPrePost).setTypeToggle()
	}

	return page
}

//----------------------------------------------------------------------------------------------------------------------
function makepageEqOfSelectedTrack() {
	var page = makePageWithDefaults('EQ of Selected Track')

	page.makeActionBinding(surfaceElements.btn_prevTrack.mSurfaceValue, page.mHostAccess.mTrackSelection.mAction.mPrevTrack)
	page.makeActionBinding(surfaceElements.btn_nextTrack.mSurfaceValue, page.mHostAccess.mTrackSelection.mAction.mNextTrack)

	var selectedTrackChannelEQ = page.mHostAccess.mTrackSelection.mMixerChannel.mChannelEQ
	page.makeValueBinding(surfaceElements.knobStrips[0].knob.mSurfaceValue, selectedTrackChannelEQ.mBand1.mFreq).setValueTakeOverModeScaled()
	page.makeValueBinding(surfaceElements.knobStrips[2].knob.mSurfaceValue, selectedTrackChannelEQ.mBand2.mFreq).setValueTakeOverModeScaled()
	page.makeValueBinding(surfaceElements.knobStrips[4].knob.mSurfaceValue, selectedTrackChannelEQ.mBand3.mFreq).setValueTakeOverModeScaled()
	page.makeValueBinding(surfaceElements.knobStrips[6].knob.mSurfaceValue, selectedTrackChannelEQ.mBand4.mFreq).setValueTakeOverModeScaled()
	page.makeValueBinding(surfaceElements.knobStrips[1].knob.mSurfaceValue, selectedTrackChannelEQ.mBand1.mQ).setValueTakeOverModeScaled()
	page.makeValueBinding(surfaceElements.knobStrips[3].knob.mSurfaceValue, selectedTrackChannelEQ.mBand2.mQ).setValueTakeOverModeScaled()
	page.makeValueBinding(surfaceElements.knobStrips[5].knob.mSurfaceValue, selectedTrackChannelEQ.mBand3.mQ).setValueTakeOverModeScaled()
	page.makeValueBinding(surfaceElements.knobStrips[7].knob.mSurfaceValue, selectedTrackChannelEQ.mBand4.mQ).setValueTakeOverModeScaled()

	page.makeValueBinding(surfaceElements.faderStrips[0].fader.mSurfaceValue, selectedTrackChannelEQ.mBand1.mGain).setValueTakeOverModeScaled()
	// page.makeValueBinding (surfaceElements.faderStrips[1].fader.mSurfaceValue, selectedTrackChannelEQ.mBand1.mType).setValueTakeOverModeScaled() // TODO: Feature request to get the mType to the API [CAN-35696]
	page.makeValueBinding(surfaceElements.faderStrips[2].fader.mSurfaceValue, selectedTrackChannelEQ.mBand2.mGain).setValueTakeOverModeScaled()
	// page.makeValueBinding (surfaceElements.faderStrips[3].fader.mSurfaceValue, selectedTrackChannelEQ.mBand2.mType).setValueTakeOverModeScaled() // TODO: Feature request to get the mType to the API [CAN-35696]
	page.makeValueBinding(surfaceElements.faderStrips[4].fader.mSurfaceValue, selectedTrackChannelEQ.mBand3.mGain).setValueTakeOverModeScaled()
	// page.makeValueBinding (surfaceElements.faderStrips[5].fader.mSurfaceValue, selectedTrackChannelEQ.mBand3.mType).setValueTakeOverModeScaled() // TODO: Feature request to get the mType to the API [CAN-35696]
	page.makeValueBinding(surfaceElements.faderStrips[6].fader.mSurfaceValue, selectedTrackChannelEQ.mBand4.mGain).setValueTakeOverModeScaled()
	// page.makeValueBinding (surfaceElements.faderStrips[7].fader.mSurfaceValue, selectedTrackChannelEQ.mBand4.mType).setValueTakeOverModeScaled() // TODO: Feature request to get the mType to the API [CAN-35696]


	page.makeValueBinding(surfaceElements.faderStrips[0].btnSolo.mSurfaceValue, selectedTrackChannelEQ.mBand1.mOn).setTypeToggle()
	page.makeValueBinding(surfaceElements.faderStrips[2].btnSolo.mSurfaceValue, selectedTrackChannelEQ.mBand2.mOn).setTypeToggle()
	page.makeValueBinding(surfaceElements.faderStrips[4].btnSolo.mSurfaceValue, selectedTrackChannelEQ.mBand3.mOn).setTypeToggle()
	page.makeValueBinding(surfaceElements.faderStrips[6].btnSolo.mSurfaceValue, selectedTrackChannelEQ.mBand4.mOn).setTypeToggle()

	return page
}

//----------------------------------------------------------------------------------------------------------------------
function makePageFocusQuickControls() {
	var page = makePageWithDefaults('Focus Quick Controls')

	page.makeActionBinding(surfaceElements.btn_prevTrack.mSurfaceValue, page.mHostAccess.mTrackSelection.mAction.mPrevTrack)
	page.makeActionBinding(surfaceElements.btn_nextTrack.mSurfaceValue, page.mHostAccess.mTrackSelection.mAction.mNextTrack)

	for (var i = 0; i < 8; ++i) {
        var knobValue = surfaceElements.knobStrips[i].knob.mSurfaceValue
        var focusQCValue = page.mHostAccess.mFocusedQuickControls.getByIndex(i)
        page.makeValueBinding(knobValue, focusQCValue).setValueTakeOverModeScaled()
	}

	return page
}

//----------------------------------------------------------------------------------------------------------------------
// 4. Feedback to the HW controller
//----------------------------------------------------------------------------------------------------------------------
function onActivatePageDefault(context) {

	function sendFeedbackOut(button, ccNr) {
		button.mSurfaceValue.mOnProcessValueChange = function (context, newValue) {
			midiOutput.sendMidi(context, [0xb0, ccNr, Math.round(newValue * 127)])
			// console.log('newValue: ' + newValue)
		}
	}

	sendFeedbackOut(surfaceElements.transport.btnRewind, 43)
	sendFeedbackOut(surfaceElements.transport.btnForward, 44)
	sendFeedbackOut(surfaceElements.transport.btnStop, 42)
	sendFeedbackOut(surfaceElements.transport.btnStart, 41)
	sendFeedbackOut(surfaceElements.transport.btnCycle, 46)
	sendFeedbackOut(surfaceElements.transport.btnRecord, 45)

	for (var i = 0; i < 8; ++i) {
		sendFeedbackOut(surfaceElements.faderStrips[i].btnSolo, 32 + i)
		sendFeedbackOut(surfaceElements.faderStrips[i].btnMute, 48 + i)
		sendFeedbackOut(surfaceElements.faderStrips[i].btnRec, 64 + i)
	}
}

//----------------------------------------------------------------------------------------------------------------------
// Switch nanoKONTROL to expected mode
//----------------------------------------------------------------------------------------------------------------------

deviceDriver.mOnActivate = function (context) {
	console.log('Your KORG nanoKONTORL2 has been switched to the CC Mode and the LED Mode is set to External.')
	switchDeviceToCcModeWithExternalLed(context)
}

//----------------------------------------------------------------------------------------------------------------------
// Construct Pages
//----------------------------------------------------------------------------------------------------------------------
var pageQCsOfFocusQuickControls = makePageFocusQuickControls()
var pageMixer = makePageMixer()
var pageSelectedTrack = makePageSelectedTrack()
var pageEqOfSelectedTrack = makepageEqOfSelectedTrack()

pageQCsOfFocusQuickControls.mOnActivate = function (context) {
	onActivatePageDefault(context)
	console.log('from script: KORG nanoKONTROL2 "QCs of Focus Quick Controls" page activated')
}

pageMixer.mOnActivate = function (context) {
	onActivatePageDefault(context)
	console.log('from script: KORG nanoKONTROL2 "Mixer" page activated')
}

pageSelectedTrack.mOnActivate = function (context) {
	onActivatePageDefault(context)
	console.log('from script: KORG nanoKONTROL2 "Selected Track" page activated')
}

pageEqOfSelectedTrack.mOnActivate = function (context) {
	onActivatePageDefault(context)
	console.log('from script: KORG nanoKONTROL2 "EQ of Selected Track" page activated')
}
