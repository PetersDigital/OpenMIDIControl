//----------------------------------------------------------------------------------------------------------------------
// 1. DRIVER SETUP - create driver object, midi ports and detection information
//----------------------------------------------------------------------------------------------------------------------

var midiremote_api = require('midiremote_api_v1');
var deviceDriver = midiremote_api.makeDeviceDriver('Korg', 'nanoKONTROL1', 'Steinberg Media Technologies GmbH');

deviceDriver.setUserGuide('korg_nanokontrol1.pdf')

var midiInput = deviceDriver.mPorts.makeMidiInput();
var midiOutput = deviceDriver.mPorts.makeMidiOutput();

deviceDriver.makeDetectionUnit().detectPortPair(midiInput, midiOutput)
    .expectSysexIdentityResponse("42", "0401", "0000")

var surface = deviceDriver.mSurface

var knobCC = [
    [ 0, 14 ], [ 0, 15 ], [ 0, 16 ], [ 0, 17 ], [ 0, 18 ], [ 0, 19 ], [ 0, 20 ], [ 0, 21 ], [ 0, 22 ]
]

var faderCC = [
    [ 0, 2 ], [ 0, 3 ], [ 0, 4 ], [ 0, 5 ], [ 0, 6 ], [ 0, 8 ], [ 0, 9 ], [ 0, 12 ], [ 0, 13 ]
]

var topButtonCC = [
    [ 0, 23 ], [ 0, 24 ], [ 0, 25 ], [ 0, 26 ], [ 0, 27 ], [ 0, 28 ], [ 0, 29 ], [ 0, 30 ], [ 0, 31 ]
]

var bottomButtonCC = [
    [ 0, 33 ], [ 0, 34 ], [ 0, 35 ], [ 0, 36 ], [ 0, 37 ], [ 0, 38 ], [ 0, 39 ], [ 0, 40 ], [ 0, 41 ]
]

//----------------------------------------------------------------------------------------------------------------------
// 2. SURFACE LAYOUT - create control elements and midi bindings
//----------------------------------------------------------------------------------------------------------------------

function makeFaderStrip(channelIndex, x, y) {
    var faderStrip = {};

	var buttonSize = 1.5
    faderStrip.btnSolo = surface.makeButton(x + 4 * channelIndex, y + 1, buttonSize, buttonSize)
    faderStrip.btnMute = surface.makeButton(x + 4 * channelIndex, y + 3.5, buttonSize, buttonSize)
    faderStrip.fader = surface.makeFader(x + 4 * channelIndex + 1.85, y, 1.3, 6).setTypeVertical()
    var bottomLabelField = surface.makeLabelField(x + 4 * channelIndex, y + 6, 4, 1)
    bottomLabelField.relateTo(faderStrip.fader)

    faderStrip.btnSolo.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(topButtonCC[channelIndex][0], topButtonCC[channelIndex][1])
    faderStrip.btnMute.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(bottomButtonCC[channelIndex][0], bottomButtonCC[channelIndex][1])
    faderStrip.fader.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(faderCC[channelIndex][0], faderCC[channelIndex][1])

    return faderStrip
}

function makeKnobStrip(knobIndex, x, y) {
    var knobStrip = {}
    
    knobStrip.knob = surface.makeKnob(x + 4 * knobIndex + 0.1, y, 1.8, 2.2)
    knobStrip.knob.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(knobCC[knobIndex][0], knobCC[knobIndex][1])

    return knobStrip
}

function makeTransport(x, y) {
    var transport = {}

    var w = 3
    var h = 1.5

    function bindMidiCC(button, chn, num) {
        button.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(chn, num)
    }

    var currX = x
    transport.btnRewind = surface.makeButton(currX, y, w, h)
    bindMidiCC(transport.btnRewind, 0, 47)

    currX = currX + w
    transport.btnStart = surface.makeButton(currX, y, w, h)
    bindMidiCC(transport.btnStart, 0, 45)

    currX = currX + w
    transport.btnForward = surface.makeButton(currX, y, w, h)
    bindMidiCC(transport.btnForward, 0, 48)

    currX = x
    transport.btnCycle = surface.makeButton(currX, y + h, w, h)
    bindMidiCC(transport.btnCycle, 0, 49)

    currX = currX + w
    transport.btnStop = surface.makeButton(currX, y + h, w, h)
    bindMidiCC(transport.btnStop, 0, 46)

    currX = currX + w
    transport.btnRecord = surface.makeButton(currX, y + h, w, h)
    bindMidiCC(transport.btnRecord, 0, 44)

    return transport
}

function makeSurfaceElements() {
    var surfaceElements = {}

    surfaceElements.numStrips = 9

    surfaceElements.knobStrips = {}
    surfaceElements.faderStrips = {}

    var xKnobStrip = 12.5
    var yKnobStrip = 0

    for(var i = 0; i < surfaceElements.numStrips; ++i) {
        surfaceElements.knobStrips[i] = makeKnobStrip(i, xKnobStrip, yKnobStrip)
        surfaceElements.faderStrips[i] = makeFaderStrip(i, 11, 2.5)
    }

    surfaceElements.transport = makeTransport(0, 3.5)

	surfaceElements.scene = surface.makeBlindPanel (0, 6.5, 3, 1.5)

	var xLamp = 3.5
	var yLamp = 6.875
	var lampSize = 0.75
	surfaceElements.lamp1 = surface.makeBlindPanel (xLamp, yLamp, lampSize, lampSize)
	surfaceElements.lamp2 = surface.makeBlindPanel (xLamp + 1.25, yLamp, lampSize, lampSize)
	surfaceElements.lamp3 = surface.makeBlindPanel (xLamp + 2.5, yLamp, lampSize, lampSize)
	surfaceElements.lamp4 = surface.makeBlindPanel (xLamp + 3.75, yLamp, lampSize, lampSize)

    // surfaceElements.deviceName = surface.makeLabelField(0, 2, 9, 1)

    return surfaceElements
}

var surfaceElements = makeSurfaceElements()

//----------------------------------------------------------------------------------------------------------------------
// 3. HOST MAPPING - create mapping pages and host bindings
//----------------------------------------------------------------------------------------------------------------------

function makePageWithDefaults(name) {
    var page = deviceDriver.mMapping.makePage(name)

    // page.setLabelFieldText(surfaceElements.deviceName, 'nanoKONTROL1')

    // page.makeCommandBinding(surfaceElements.btn_prevTrack.mSurfaceValue, "Project", "Select Track: Prev")
    // page.makeCommandBinding(surfaceElements.btn_nextTrack.mSurfaceValue, "Project", "Select Track: Next")

    /*page.makeCommandBinding(surfaceElements.btn_inserMarker.mSurfaceValue, "Transport", "Insert Marker")
    page.makeCommandBinding(surfaceElements.btn_prevMarker.mSurfaceValue, "Transport", "Locate Previous Marker")
    page.makeCommandBinding(surfaceElements.btn_nextMarker.mSurfaceValue, "Transport", "Locate Next Marker")*/

    page.makeValueBinding(surfaceElements.transport.btnRewind.mSurfaceValue, page.mHostAccess.mTransport.mValue.mRewind)
    page.makeValueBinding(surfaceElements.transport.btnForward.mSurfaceValue, page.mHostAccess.mTransport.mValue.mForward)
    page.makeValueBinding(surfaceElements.transport.btnStop.mSurfaceValue, page.mHostAccess.mTransport.mValue.mStop).setTypeToggle()
    page.makeValueBinding(surfaceElements.transport.btnStart.mSurfaceValue, page.mHostAccess.mTransport.mValue.mStart).setTypeToggle()
    page.makeValueBinding(surfaceElements.transport.btnCycle.mSurfaceValue, page.mHostAccess.mTransport.mValue.mCycleActive).setTypeToggle()
    page.makeValueBinding(surfaceElements.transport.btnRecord.mSurfaceValue, page.mHostAccess.mTransport.mValue.mRecord).setTypeToggle()

    return page
}

function makePageMixer() {
    var page = makePageWithDefaults('Mixer')

    var hostMixerBankZone = page.mHostAccess.mMixConsole.makeMixerBankZone()
        .excludeInputChannels()
        .excludeOutputChannels()

    for(var i = 0; i < 8; ++i) {
        var channelBankItem = hostMixerBankZone.makeMixerBankChannel()

        var knobValue = surfaceElements.knobStrips[i].knob.mSurfaceValue

        var soloValue = surfaceElements.faderStrips[i].btnSolo.mSurfaceValue
        var muteValue = surfaceElements.faderStrips[i].btnMute.mSurfaceValue
        var faderValue = surfaceElements.faderStrips[i].fader.mSurfaceValue

        page.makeValueBinding (knobValue, channelBankItem.mValue.mPan).setValueTakeOverModeScaled()
        page.makeValueBinding (soloValue, channelBankItem.mValue.mSolo).setTypeToggle()
        page.makeValueBinding (muteValue, channelBankItem.mValue.mMute).setTypeToggle()
        page.makeValueBinding (faderValue, channelBankItem.mValue.mVolume).setValueTakeOverModeScaled()
    }

    page.makeActionBinding(surfaceElements.faderStrips[8].btnSolo.mSurfaceValue, hostMixerBankZone.mAction.mNextBank)
    page.makeActionBinding(surfaceElements.faderStrips[8].btnMute.mSurfaceValue, hostMixerBankZone.mAction.mPrevBank)

    var hostOutMixerBankZone = page.mHostAccess.mMixConsole.makeMixerBankZone('output channels').includeOutputChannels()
    var outBankItem = hostOutMixerBankZone.makeMixerBankChannel()
    page.makeValueBinding(surfaceElements.faderStrips[8].fader.mSurfaceValue, outBankItem.mValue.mVolume).setValueTakeOverModeScaled()
    page.makeValueBinding(surfaceElements.knobStrips[8].knob.mSurfaceValue, outBankItem.mValue.mPan).setValueTakeOverModeScaled()

    return page
}

function makePageSelectedTrack() {
    var page = makePageWithDefaults('Selected Track')

    page.makeActionBinding(surfaceElements.faderStrips[8].btnSolo.mSurfaceValue, page.mHostAccess.mTrackSelection.mAction.mPrevTrack)
    page.makeActionBinding(surfaceElements.faderStrips[8].btnMute.mSurfaceValue, page.mHostAccess.mTrackSelection.mAction.mNextTrack)

    var selectedTrackChannel = page.mHostAccess.mTrackSelection.mMixerChannel
    page.makeValueBinding(surfaceElements.faderStrips[8].fader.mSurfaceValue, selectedTrackChannel.mValue.mVolume).setValueTakeOverModeScaled()
    page.makeValueBinding(surfaceElements.knobStrips[8].knob.mSurfaceValue, selectedTrackChannel.mValue.mPan).setValueTakeOverModeScaled()

    for (var i = 0; i < 8; ++i) {
        page.makeValueBinding (surfaceElements.knobStrips[i].knob.mSurfaceValue, selectedTrackChannel.mQuickControls.getByIndex(i)).setValueTakeOverModeScaled()    
        page.makeValueBinding (surfaceElements.faderStrips[i].fader.mSurfaceValue, selectedTrackChannel.mSends.getByIndex(i).mLevel).setValueTakeOverModeScaled()
        if (i != 7) {
            page.makeValueBinding (surfaceElements.faderStrips[i].btnSolo.mSurfaceValue, selectedTrackChannel.mSends.getByIndex(i).mOn).setTypeToggle()
            page.makeValueBinding (surfaceElements.faderStrips[i].btnMute.mSurfaceValue, selectedTrackChannel.mSends.getByIndex(i).mPrePost).setTypeToggle()
        }
    }
    page.makeValueBinding (surfaceElements.faderStrips[7].btnSolo.mSurfaceValue, page.mHostAccess.mTrackSelection.mMixerChannel.mValue.mSolo).setTypeToggle()
    page.makeValueBinding (surfaceElements.faderStrips[7].btnMute.mSurfaceValue, page.mHostAccess.mTrackSelection.mMixerChannel.mValue.mEditorOpen).setTypeToggle()

    return page
}

function makepageEqOfSelectedTrack() {
    var page = makePageWithDefaults('EQ of Selected Track')

    page.makeActionBinding(surfaceElements.faderStrips[8].btnSolo.mSurfaceValue, page.mHostAccess.mTrackSelection.mAction.mPrevTrack)
    page.makeActionBinding(surfaceElements.faderStrips[8].btnMute.mSurfaceValue, page.mHostAccess.mTrackSelection.mAction.mNextTrack)

    var selectedTrackChannel = page.mHostAccess.mTrackSelection.mMixerChannel
    page.makeValueBinding(surfaceElements.faderStrips[8].fader.mSurfaceValue, selectedTrackChannel.mValue.mVolume).setValueTakeOverModeScaled()
    page.makeValueBinding(surfaceElements.knobStrips[8].knob.mSurfaceValue, selectedTrackChannel.mValue.mPan).setValueTakeOverModeScaled()

    var selectedTrackChannelEQ = page.mHostAccess.mTrackSelection.mMixerChannel.mChannelEQ
    page.makeValueBinding (surfaceElements.knobStrips[0].knob.mSurfaceValue, selectedTrackChannelEQ.mBand1.mFreq).setValueTakeOverModeScaled()
    page.makeValueBinding (surfaceElements.knobStrips[2].knob.mSurfaceValue, selectedTrackChannelEQ.mBand2.mFreq).setValueTakeOverModeScaled()
    page.makeValueBinding (surfaceElements.knobStrips[4].knob.mSurfaceValue, selectedTrackChannelEQ.mBand3.mFreq).setValueTakeOverModeScaled()
    page.makeValueBinding (surfaceElements.knobStrips[6].knob.mSurfaceValue, selectedTrackChannelEQ.mBand4.mFreq).setValueTakeOverModeScaled()
    page.makeValueBinding (surfaceElements.knobStrips[1].knob.mSurfaceValue, selectedTrackChannelEQ.mBand1.mQ).setValueTakeOverModeScaled()
    page.makeValueBinding (surfaceElements.knobStrips[3].knob.mSurfaceValue, selectedTrackChannelEQ.mBand2.mQ).setValueTakeOverModeScaled()
    page.makeValueBinding (surfaceElements.knobStrips[5].knob.mSurfaceValue, selectedTrackChannelEQ.mBand3.mQ).setValueTakeOverModeScaled()
    page.makeValueBinding (surfaceElements.knobStrips[7].knob.mSurfaceValue, selectedTrackChannelEQ.mBand4.mQ).setValueTakeOverModeScaled()

    page.makeValueBinding (surfaceElements.faderStrips[0].fader.mSurfaceValue, selectedTrackChannelEQ.mBand1.mGain).setValueTakeOverModeScaled()
    page.makeValueBinding (surfaceElements.faderStrips[1].fader.mSurfaceValue, selectedTrackChannelEQ.mBand1.mGain).setValueTakeOverModeScaled()
    page.makeValueBinding (surfaceElements.faderStrips[2].fader.mSurfaceValue, selectedTrackChannelEQ.mBand2.mGain).setValueTakeOverModeScaled()
    page.makeValueBinding (surfaceElements.faderStrips[3].fader.mSurfaceValue, selectedTrackChannelEQ.mBand2.mGain).setValueTakeOverModeScaled()
    page.makeValueBinding (surfaceElements.faderStrips[4].fader.mSurfaceValue, selectedTrackChannelEQ.mBand3.mGain).setValueTakeOverModeScaled()
    page.makeValueBinding (surfaceElements.faderStrips[5].fader.mSurfaceValue, selectedTrackChannelEQ.mBand3.mGain).setValueTakeOverModeScaled()
    page.makeValueBinding (surfaceElements.faderStrips[6].fader.mSurfaceValue, selectedTrackChannelEQ.mBand4.mGain).setValueTakeOverModeScaled()
    page.makeValueBinding (surfaceElements.faderStrips[7].fader.mSurfaceValue,  selectedTrackChannelEQ.mBand4.mGain).setValueTakeOverModeScaled()

    page.makeValueBinding (surfaceElements.faderStrips[0].btnSolo.mSurfaceValue, selectedTrackChannelEQ.mBand1.mOn).setTypeToggle()
    page.makeValueBinding (surfaceElements.faderStrips[1].btnSolo.mSurfaceValue, selectedTrackChannelEQ.mBand1.mOn).setTypeToggle()
    page.makeValueBinding (surfaceElements.faderStrips[2].btnSolo.mSurfaceValue, selectedTrackChannelEQ.mBand2.mOn).setTypeToggle()
    page.makeValueBinding (surfaceElements.faderStrips[3].btnSolo.mSurfaceValue, selectedTrackChannelEQ.mBand2.mOn).setTypeToggle()
    page.makeValueBinding (surfaceElements.faderStrips[4].btnSolo.mSurfaceValue, selectedTrackChannelEQ.mBand3.mOn).setTypeToggle()
    page.makeValueBinding (surfaceElements.faderStrips[5].btnSolo.mSurfaceValue, selectedTrackChannelEQ.mBand3.mOn).setTypeToggle()
    page.makeValueBinding (surfaceElements.faderStrips[6].btnSolo.mSurfaceValue, selectedTrackChannelEQ.mBand4.mOn).setTypeToggle()

    page.makeValueBinding (surfaceElements.faderStrips[7].btnSolo.mSurfaceValue, selectedTrackChannel.mValue.mSolo).setTypeToggle()
    page.makeValueBinding (surfaceElements.faderStrips[7].btnMute.mSurfaceValue, selectedTrackChannel.mValue.mEditorOpen).setTypeToggle()

    /*page.setLabelFieldText (surfaceElements.faderStrips[0].btnSoloLabel, 'Band 1 On/Off')
    page.setLabelFieldText (surfaceElements.faderStrips[1].btnSoloLabel, 'Band 1 On/Off')
    page.setLabelFieldText (surfaceElements.faderStrips[2].btnSoloLabel, 'Band 2 On/Off')
    page.setLabelFieldText (surfaceElements.faderStrips[3].btnSoloLabel, 'Band 2 On/Off')
    page.setLabelFieldText (surfaceElements.faderStrips[4].btnSoloLabel, 'Band 3 On/Off')
    page.setLabelFieldText (surfaceElements.faderStrips[5].btnSoloLabel, 'Band 3 On/Off')
    page.setLabelFieldText (surfaceElements.faderStrips[6].btnSoloLabel, 'Band 4 On/Off')
    page.setLabelFieldText (surfaceElements.faderStrips[7].btnSoloLabel, 'Band 4 On/Off')*/

    return page
}

//----------------------------------------------------------------------------------------------------------------------
// Switch nanoKONTROL to expected mode
//----------------------------------------------------------------------------------------------------------------------

deviceDriver.mOnActivate = function(context) {
    console.log('Your KORG nanoKONTORL1 has been detected.')
}

//----------------------------------------------------------------------------------------------------------------------
// Construct Pages
//----------------------------------------------------------------------------------------------------------------------
var pageMixer = makePageMixer()
var pageSelectedTrack = makePageSelectedTrack()
var pageEqOfSelectedTrack = makepageEqOfSelectedTrack()

pageMixer.mOnActivate = function (context) {
	console.log('from script: KORG nanoKONTROL1 "Mixer" page activated')
}

pageSelectedTrack.mOnActivate = function (context) {
	console.log('from script: KORG nanoKONTROL1 "Selected Track" page activated')
}

pageEqOfSelectedTrack.mOnActivate = function (context) {
	console.log('from script: KORG nanoKONTROL1 "EQ of Selected Track" page activated')
}
