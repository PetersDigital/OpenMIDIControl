//-----------------------------------------------------------------------------
// 1. DRIVER SETUP - create driver object, midi ports and detection information
//-----------------------------------------------------------------------------
var midiremote_api = require('midiremote_api_v1');
var deviceDriver = midiremote_api.makeDeviceDriver('Arturia', 'MiniLab mkII', 'Steinberg Media Technologies GmbH');
var midiInput = deviceDriver.mPorts.makeMidiInput();
var midiOutput = deviceDriver.mPorts.makeMidiOutput();

deviceDriver.makeDetectionUnit().detectPortPair(midiInput, midiOutput)
	.expectSysexIdentityResponse('00206B', '0200', '0402')

function enterDawMode(/** @type {MR_ActiveDevice} */activeDevice) {
	midiOutput.sendMidi(activeDevice, [0xF0, 0x00, 0x20, 0x6B, 0x7F, 0x42, 0x05, 0x02, 0xF7])
	midiOutput.sendSysexFile(activeDevice, 'arturia_minilab_mk2.syx', 1)
	activeDevice.setState('isALABMOD', 'false')
}

deviceDriver.mOnActivate = function (/** @type {MR_ActiveDevice} */ activeDevice) {
	enterDawMode(activeDevice)
}

deviceDriver.setUserGuide('arturia_minilab_mk2.pdf')

function isEqualNArrayItems(/** @type {number[]} */lhs, /** @type {number[]} */rhs, /** @type {number} */num) {
	for (var i = 0; i < num; ++i)
		if (lhs[i] !== rhs[i])
			return false
	return true
}

midiInput.mOnSysex = function (/** @type {MR_ActiveDevice} */activeDevice, /** @type {number[]} */msg) {
	if (isEqualNArrayItems(msg, [0xF0, 0x00, 0x20, 0x6B, 0x7F, 0x42], 6)) {
		var tail = msg.slice(6)
		// SWITCH DEVICE MEMORY SLOT PRESET
		if (tail[0] === 0x1B) {
			var slotIndex = tail[1]
			if (slotIndex === 1) // DAW Mode
				enterDawMode(activeDevice)
			else
				activeDevice.setState('isALABMOD', 'true')
		}
	}
}

//-----------------------------------------------------------------------------
// 2. SURFACE LAYOUT - create control elements and midi bindings
//-----------------------------------------------------------------------------
var encoders = []

var midiCCs = [112, 74, 71, 76, 77, 93, 73, 75, 114, 18, 19, 16, 17, 91, 79, 72]
var x = 16
var y = 0
var size = 9
for (var i = 0; i < 16; ++i) {
	if (i % 8 == 0) {
		var pushEncoder = deviceDriver.mSurface.makePushEncoder(x, y, size, size);
		pushEncoder.mPushValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToControlChange(15, midiCCs[i] + 1);
		pushEncoder.mEncoderValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToControlChange(15, midiCCs[i]).setTypeRelativeBinaryOffset();
		encoders.push(pushEncoder)
	} else {
		var knob = deviceDriver.mSurface.makeKnob(x, y, size, size);
		knob.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToControlChange(15, midiCCs[i]).setTypeRelativeBinaryOffset();
		encoders.push(knob)
	}

	x += 9
	if (i == 7) {
		x = 16
		y = 9
	}
}

for (var i = 0; i < 8; ++i) {
	deviceDriver.mSurface.makeBlindPanel(16 + i * 9 + 0.5, 20, 8, 8)
}

deviceDriver.mSurface.makeBlindPanel(1, 10, 6, 19);
deviceDriver.mSurface.makeBlindPanel(8, 10, 6, 19);
deviceDriver.mSurface.makePianoKeys(0, 31, 88, 20, 0, 24);

deviceDriver.mSurface.makeBlindPanel(1, 0, 6, 4); // Shift button
deviceDriver.mSurface.makeBlindPanel(8, 0, 6, 4); // Pad 1-8/9-16 button
deviceDriver.mSurface.makeBlindPanel(1, 5, 6, 4); // Oct- button
deviceDriver.mSurface.makeBlindPanel(8, 5, 6, 4); // Oct+ button

//-----------------------------------------------------------------------------
// 3. HOST MAPPING - create mapping pages and host bindings
//-----------------------------------------------------------------------------

function makePageFocusQuickControls() {
	var page = deviceDriver.mMapping.makePage('Focus Quick Controls')
	page.makeValueBinding(encoders[0].mPushValue, page.mHostAccess.mFocusedQuickControls.mFocusLockedValue).setTypeToggle()
	page.makeValueBinding(encoders[8].mEncoderValue, page.mHostAccess.mMouseCursor.mValueUnderMouse)
	page.makeValueBinding(encoders[8].mPushValue, page.mHostAccess.mMouseCursor.mValueLocked).setTypeToggle()
	for (var i = 0; i < 8; ++i) {
		var surfaceValue = i == 0 ? encoders[i].mEncoderValue : encoders[i].mSurfaceValue
		page.makeValueBinding(surfaceValue, page.mHostAccess.mFocusedQuickControls.getByIndex(i))
	}
	return page
}

function makePageMixer() {
	var page = deviceDriver.mMapping.makePage('Mixer');

	var hostMixerBankZone = page.mHostAccess.mMixConsole.makeMixerBankZone()
		.excludeInputChannels()
		.excludeOutputChannels()

	page.makeActionBinding(encoders[0].mPushValue, hostMixerBankZone.mAction.mPrevBank)
	page.makeActionBinding(encoders[8].mPushValue, hostMixerBankZone.mAction.mNextBank)

	for (var i = 0; i < 8; ++i) {
		var channelBankItem = hostMixerBankZone.makeMixerBankChannel()
		if (i == 0) {
			page.makeValueBinding(encoders[i].mEncoderValue, channelBankItem.mValue.mPan)
			page.makeValueBinding(encoders[i + 8].mEncoderValue, channelBankItem.mValue.mVolume)
			continue
		}

		page.makeValueBinding(encoders[i].mSurfaceValue, channelBankItem.mValue.mPan)
		page.makeValueBinding(encoders[i + 8].mSurfaceValue, channelBankItem.mValue.mVolume)
	}
	return page
}

function makePageEqOfSelectedTrack() {
	var page = deviceDriver.mMapping.makePage('EQ of Selected Track');

	page.makeActionBinding(encoders[0].mPushValue, page.mHostAccess.mTrackSelection.mAction.mPrevTrack)
	page.makeActionBinding(encoders[8].mPushValue, page.mHostAccess.mTrackSelection.mAction.mNextTrack)

	var selectedTrackChannelEQ = page.mHostAccess.mTrackSelection.mMixerChannel.mChannelEQ
	page.makeValueBinding(encoders[0].mEncoderValue, selectedTrackChannelEQ.mBand1.mFreq)
	page.makeValueBinding(encoders[2].mSurfaceValue, selectedTrackChannelEQ.mBand2.mFreq)
	page.makeValueBinding(encoders[4].mSurfaceValue, selectedTrackChannelEQ.mBand3.mFreq)
	page.makeValueBinding(encoders[6].mSurfaceValue, selectedTrackChannelEQ.mBand4.mFreq)
	page.makeValueBinding(encoders[1].mSurfaceValue, selectedTrackChannelEQ.mBand1.mQ)
	page.makeValueBinding(encoders[3].mSurfaceValue, selectedTrackChannelEQ.mBand2.mQ)
	page.makeValueBinding(encoders[5].mSurfaceValue, selectedTrackChannelEQ.mBand3.mQ)
	page.makeValueBinding(encoders[7].mSurfaceValue, selectedTrackChannelEQ.mBand4.mQ)

	page.makeValueBinding(encoders[8].mEncoderValue, selectedTrackChannelEQ.mBand1.mGain)
	// page.makeValueBinding (encoders[9].mEncoderValue, selectedTrackChannelEQ.mBand1.mType) // TODO: Feature request to get the mType to the API [CAN-35696]
	page.makeValueBinding(encoders[10].mSurfaceValue, selectedTrackChannelEQ.mBand2.mGain)
	// page.makeValueBinding (encoders[11].mEncoderValue, selectedTrackChannelEQ.mBand2.mType) // TODO: Feature request to get the mType to the API [CAN-35696]
	page.makeValueBinding(encoders[12].mSurfaceValue, selectedTrackChannelEQ.mBand3.mGain)
	// page.makeValueBinding (encoders[13].mEncoderValue, selectedTrackChannelEQ.mBand3.mType) // TODO: Feature request to get the mType to the API [CAN-35696]
	page.makeValueBinding(encoders[14].mSurfaceValue, selectedTrackChannelEQ.mBand4.mGain)
	// page.makeValueBinding (encoders[15].mEncoderValue, selectedTrackChannelEQ.mBand4.mType) // TODO: Feature request to get the mType to the API [CAN-35696]

	return page
}

//----------------------------------------------------------------------------------------------------------------------
// MAKE PAGES
//----------------------------------------------------------------------------------------------------------------------
makePageFocusQuickControls()
makePageMixer()
makePageEqOfSelectedTrack()
