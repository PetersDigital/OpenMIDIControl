
//-----------------------------------------------------------------------------
// 1. DRIVER SETUP - create driver object, midi ports and detection information
//-----------------------------------------------------------------------------

var midiremote_api = require('midiremote_api_v1')
var deviceDriver = midiremote_api.makeDeviceDriver('Akai', 'MPK mini mk3', 'Steinberg Media Technologies GmbH')

var midiInput = deviceDriver.mPorts.makeMidiInput();
var midiOutput = deviceDriver.mPorts.makeMidiOutput();

// SySEx-ID-Response determined with WIN & Cubase 
// [ F0 7E 7F 06 02|47|49 00 
//   19 00 01 01 08 00 00 00 
//   00 00 41 33 32 30 31 32
//   32 25 31 30 30 32 33 31 
//   38 00 F7]

// Detection for WIN, WinRT and MAC
deviceDriver.makeDetectionUnit().detectPortPair(midiInput, midiOutput)
    .expectSysexIdentityResponse('47', '4900', '1900')

deviceDriver.mOnActivate = function (activeDevice) {
    midiOutput.sendSysexFile(activeDevice, 'akai_mpkmini_mk3.syx', 5)
}

deviceDriver.setUserGuide('akai_mpkmini_mk3.pdf')

var surface = deviceDriver.mSurface

//----------------------------------------------------------------------------------------------------------------------
// 2. SURFACE LAYOUT - create control elements and midi bindings
//----------------------------------------------------------------------------------------------------------------------

function makeKnobStrip(knobIndex, x, y, ccNr) {
    var knobStrip = {}
    
    knobStrip.knob = surface.makeKnob(x * knobIndex + 16, y, 2, 2.3)
    knobStrip.knob.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(0, ccNr).setTypeRelativeTwosComplement()

    return knobStrip
}

function makeTriggerPads(padIndex, x, y, ccNr) {
    var triggerPads = {}
    
    triggerPads.pad = surface.makeTriggerPad(x * padIndex + 3.5, y, 2.7, 2.7)
    triggerPads.pad.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(9, ccNr)

    return triggerPads
}

function makeSurfaceElements() {
    var surfaceElements = {}

    surfaceElements.numStrips = 8
    surfaceElements.knobStrips = {}

    var x = 2.3
    var y = 1.75
    for(var i = 0; i < surfaceElements.numStrips; ++i) {
        var knobIndex = i
        if (i > 3) {
            knobIndex = i - 4
            y = 4.15 
        } 
        var ccNr = i + 70
        
        surfaceElements.knobStrips[i] = makeKnobStrip(knobIndex, x, y, ccNr) 
    }

    x = 3
    y = 3
    surfaceElements.triggerPads = {}
    for(var i = 0; i < surfaceElements.numStrips; ++i) {
        var padIndex = i
        if (i > 3) {
            padIndex = i - 4
            y = 0
        } 
        var ccNr = i + 16 
        
        surfaceElements.triggerPads[i] = makeTriggerPads(padIndex, x, y, ccNr)
        // surfaceElements.triggerPads[i + 8] = makeTriggerPads(padIndex, x, y, programChange + 8) // TODO: Bind it to 2 MIDI messages to be able to use both BANK A and BANK B on the HW ; The 2nd message is: programChange = i + 8
    }

    surface.makeBlindPanel(0.35, 0, 2, 2).setShapeCircle()
    surface.makePianoKeys(0, 7.1, 25, 6, 0, 24)

	// var joyStickXY = surface.makeJoyStickXY(0, 0, 2, 2);
	// joyStickXY.mX.mMidiBinding.setInputPort(midiInput).setIsConsuming(false).bindToPitchBend (0);
	// joyStickXY.mY.mMidiBinding.setInputPort(midiInput).setIsConsuming(false).bindToControlChange (0, 1);

    // Lefthand Buttons
    surface.makeBlindPanel(0, 2.5, 1.3, 1)
    surface.makeBlindPanel(1.4, 2.5, 1.3, 1)
    surface.makeBlindPanel(0, 3.6, 1.3, 1)
    surface.makeBlindPanel(1.4, 3.6, 1.3, 1)
    surface.makeBlindPanel(0, 4.7, 1.3, 1)
    surface.makeBlindPanel(1.4, 4.7, 1.3, 1)

    surface.makeBlindPanel(16, 0, 2.7, 1.5)
    // Pad Controls
    surface.makeBlindPanel(19, 0.27, 1.3, 1)
    surface.makeBlindPanel(20.5, 0.27, 1.3, 1)
    surface.makeBlindPanel(22, 0.27, 1.3, 1)
    surface.makeBlindPanel(23.5, 0.27, 1.3, 1)
    return surfaceElements
}

var surfaceElements = makeSurfaceElements()


//----------------------------------------------------------------------------------------------------------------------
// 3. HOST MAPPING - create mapping pages and host bindings
//----------------------------------------------------------------------------------------------------------------------

function makePageSelectedTrack() {
    var page = deviceDriver.mMapping.makePage('Selected Track')

    var selectedTrackChannel = page.mHostAccess.mTrackSelection.mMixerChannel
    for (var i = 0; i < 8; ++i) {
        page.makeValueBinding (surfaceElements.knobStrips[i].knob.mSurfaceValue, page.mHostAccess.mFocusedQuickControls.getByIndex(i)).setValueTakeOverModeJump()// setValueTakeOverModeScaled()//selectedTrackChannel.//mQuickControls.getByIndex(i)).setValueTakeOverModeScaled()
    }
    page.makeActionBinding (surfaceElements.triggerPads[0].pad.mSurfaceValue, page.mHostAccess.mTrackSelection.mAction.mNextTrack)
    page.makeValueBinding (surfaceElements.triggerPads[1].pad.mSurfaceValue, selectedTrackChannel.mValue.mSolo).setTypeToggle()
    page.makeValueBinding (surfaceElements.triggerPads[2].pad.mSurfaceValue, selectedTrackChannel.mValue.mEditorOpen).setTypeToggle()
    page.makeValueBinding (surfaceElements.triggerPads[3].pad.mSurfaceValue, page.mHostAccess.mTransport.mValue.mStart).setTypeToggle()
    page.makeActionBinding (surfaceElements.triggerPads[4].pad.mSurfaceValue, page.mHostAccess.mTrackSelection.mAction.mPrevTrack)
    page.makeValueBinding (surfaceElements.triggerPads[5].pad.mSurfaceValue, selectedTrackChannel.mValue.mMute).setTypeToggle()
    page.makeValueBinding (surfaceElements.triggerPads[6].pad.mSurfaceValue, selectedTrackChannel.mValue.mMonitorEnable).setTypeToggle()
    page.makeValueBinding (surfaceElements.triggerPads[7].pad.mSurfaceValue, page.mHostAccess.mTransport.mValue.mRecord).setTypeToggle()

    return page
}

//----------------------------------------------------------------------------------------------------------------------
// Construct Pages
//----------------------------------------------------------------------------------------------------------------------
var pageSelectedTrack = makePageSelectedTrack()

pageSelectedTrack.mOnActivate = function (context) {
	console.log('from script: AKAI MPKmini "Selected Track" page activated')
}
