//-----------------------------------------------------------------------------
// Cubase / Nuendo 12+ Integration for avatar EMK-25
// written by Heaven Jie in 2022
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// 1. DRIVER SETUP
//-----------------------------------------------------------------------------

// get the api's entry point
var midiremote_api = require("midiremote_api_v1");

// create the device driver main object
var deviceDriver = midiremote_api.makeDeviceDriver("Avatar", "EMK-25", "HXW Technology Co., Ltd");

// create objects representing the hardware's MIDI ports
var midiInput = deviceDriver.mPorts.makeMidiInput();
var midiOutput = deviceDriver.mPorts.makeMidiOutput();

// Windows
deviceDriver
	.makeDetectionUnit()
	.detectPortPair(midiInput, midiOutput)
	.expectInputNameContains("MIDI KeyBoard 25A")
	.expectInputNameContains("MIDIIN")
	.expectOutputNameContains("MIDI KeyBoard 25A")
	.expectOutputNameContains("MIDIOUT");

// Windows RT
deviceDriver
	.makeDetectionUnit()
	.detectPortPair(midiInput, midiOutput)
	.expectInputNameContains("MIDI KeyBoard 25A")
	.expectInputNameContains("Port 2")
	.expectOutputNameContains("MIDI KeyBoard 25A")
	.expectOutputNameContains("Port 2");

// Mac
deviceDriver
	.makeDetectionUnit()
	.detectPortPair(midiInput, midiOutput)
	.expectInputNameEquals("MIDI KeyBoard 25A")
	.expectOutputNameEquals("MIDI KeyBoard 25A");

deviceDriver.mOnActivate = function (activeDevice) {
	// set DAW mode
	midiOutput.sendMidi(activeDevice, [0x9f, 0x00, 0x7f]);
	midiOutput.sendMidi(activeDevice, [0xbf, 0x0e, 0x00]);
	midiOutput.sendMidi(activeDevice, [0xbf, 0x0f, 0x01]);
};

deviceDriver.setUserGuide("avatar_emk_25.pdf");

//-----------------------------------------------------------------------------
// SURFACE LAYOUT
//-----------------------------------------------------------------------------

var surface = deviceDriver.mSurface;

var padControlLayerZone = surface.makeControlLayerZone("Control Bank");
var padControlLayerControlBankA = padControlLayerZone.makeControlLayer("Control Bank A");
var padControlLayerControlBankB = padControlLayerZone.makeControlLayer("Control Bank B");

function makeKnobStrip(knobColumn, x, y, ccNr) {
	var knobStrip = {};
	knobStrip.knob = surface.makeKnob(x * knobColumn + 4, y, 2.2, 2.5);
	knobStrip.knob.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(0, ccNr).setValueRange(0, 100);

	return knobStrip;
}

function makeTriggerPads(padColumnIndex, width, y, ccNr, noteNr) {
	var triggerPads = {};

	triggerPads.padA = surface.makeTriggerPad(width * padColumnIndex + 18, y, width, width).setControlLayer(padControlLayerControlBankA);
	triggerPads.padA.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToNote(9, noteNr);
	triggerPads.padB = surface.makeTriggerPad(width * padColumnIndex + 18, y, width, width).setControlLayer(padControlLayerControlBankB);
	triggerPads.padB.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(9, ccNr);

	return triggerPads;
}

function makeSurfaceElements() {
	var surfaceElements = {};

	surfaceElements.numKnobs = 8;
	surfaceElements.numTriggerPads = 9;
	surfaceElements.knobStrips = {};
	surfaceElements.triggerPads = {};

	var x = 2.3;
	var y = -0.5;
	for (var i = 0; i < surfaceElements.numKnobs; ++i) {
		var knobIndex = i;
		var Nr = [70, 71, 72, 73, 74, 75, 76, 77];
		if (i > 3) {
			knobIndex = i - 4;
			y = 2.1;
		}
		var ccNr = Nr[i];

		surfaceElements.knobStrips[i] = makeKnobStrip(knobIndex, x, y, ccNr);
	}

	x = 2;
	y = 4;
	surfaceElements.triggerPads = {};
	for (var i = 0; i < surfaceElements.numTriggerPads; ++i) {
		var padColumn = i % 3;
		y = 4 - Math.floor(i / 3) * 2;

		var Nr = [36, 38, 42, 50, 48, 43, 49, 46, 51];
		var noteNr = Nr[i];

		var ccNr = i + 20;

		surfaceElements.triggerPads[i] = makeTriggerPads(padColumn, x, y, ccNr, noteNr);
	}

	// Joystick and Keyboard

	surface.makeBlindPanel(0.25, 2.3, 3, 3).setShapeCircle();
	surface.makePianoKeys(0, 7.1, 25, 6, 0, 24);

	// Hardware exclusive buttons

	surface.makeBlindPanel(16.4, 0.2, 1.4, 1.4).setShapeCircle();

	var yButtonRow = 4.8;

	surface.makeBlindPanel(4.4, yButtonRow, 1.4, 1.4).setShapeCircle();
	surface.makeBlindPanel(5.8, yButtonRow, 1.4, 1.4).setShapeCircle();
	surface.makeBlindPanel(9.0, yButtonRow, 1.4, 1.4).setShapeCircle();
	surface.makeBlindPanel(10.4, yButtonRow, 1.4, 1.4).setShapeCircle();
	surface.makeBlindPanel(11.8, yButtonRow, 1.4, 1.4).setShapeCircle();

	surface.makeBlindPanel(14.0, yButtonRow, 1.9, 1.4).setShapeCircle();

	surface.makeBlindPanel(13.4, 2.2, 1.4, 1.4).setShapeCircle();
	surface.makeBlindPanel(14.8, 2.2, 1.4, 1.4).setShapeCircle();

	// Screen

	surface.makeBlindPanel(13.4, 0.2, 2.8, 1.6);

	return surfaceElements;
}

var surfaceElements = makeSurfaceElements();

//-----------------------------------------------------------------------------
// HOST MAPPING
//-----------------------------------------------------------------------------

function makePageSelectedTrack() {
	var page = deviceDriver.mMapping.makePage("Selected Track");

	var selectedTrackChannel = page.mHostAccess.mTrackSelection.mMixerChannel;
	for (var i = 0; i < 8; ++i) {
		page.makeValueBinding(
			surfaceElements.knobStrips[i].knob.mSurfaceValue,
			page.mHostAccess.mFocusedQuickControls.getByIndex(i)
		).setValueTakeOverModeScaled();
	}

	page.makeValueBinding(surfaceElements.triggerPads[2].padB.mSurfaceValue, page.mHostAccess.mTransport.mValue.mForward);
	page.makeValueBinding(surfaceElements.triggerPads[3].padB.mSurfaceValue, selectedTrackChannel.mValue.mSolo).setTypeToggle();
	page.makeValueBinding(surfaceElements.triggerPads[8].padB.mSurfaceValue, selectedTrackChannel.mValue.mEditorOpen).setTypeToggle();
	page.makeValueBinding(surfaceElements.triggerPads[1].padB.mSurfaceValue, page.mHostAccess.mTransport.mValue.mStart).setTypeToggle();
	page.makeValueBinding(surfaceElements.triggerPads[0].padB.mSurfaceValue, page.mHostAccess.mTransport.mValue.mRewind);
	page.makeValueBinding(surfaceElements.triggerPads[5].padB.mSurfaceValue, selectedTrackChannel.mValue.mMute).setTypeToggle();
	page.makeValueBinding(surfaceElements.triggerPads[6].padB.mSurfaceValue, selectedTrackChannel.mValue.mMonitorEnable).setTypeToggle();
	page.makeValueBinding(surfaceElements.triggerPads[4].padB.mSurfaceValue, page.mHostAccess.mTransport.mValue.mRecord).setTypeToggle();
	page.makeValueBinding(surfaceElements.triggerPads[7].padB.mSurfaceValue, page.mHostAccess.mTransport.mValue.mCycleActive).setTypeToggle();

	return page;
}

makePageSelectedTrack();
