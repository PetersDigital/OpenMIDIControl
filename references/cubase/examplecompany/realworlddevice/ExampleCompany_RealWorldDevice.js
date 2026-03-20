//-----------------------------------------------------------------------------
// 0. INCLUDE common functions
//-----------------------------------------------------------------------------
var helper = require('./helper')

//-----------------------------------------------------------------------------
// 1. DRIVER SETUP - create driver object, midi ports and detection information
//-----------------------------------------------------------------------------

var midiremote_api = require('midiremote_api_v1')

var deviceDriver = midiremote_api.makeDeviceDriver('ExampleCompany', 'RealWorldDevice', 'Steinberg Media Technologies GmbH')

var midiInput = deviceDriver.mPorts.makeMidiInput()
var midiOutput = deviceDriver.mPorts.makeMidiOutput()

deviceDriver.makeDetectionUnit().detectPortPair(midiInput, midiOutput)
    .expectInputNameEquals('RealWorld In')
    .expectOutputNameEquals('RealWorld Out')

deviceDriver.makeDetectionUnit().detectPortPair(midiInput, midiOutput)
    .expectInputNameEquals('MIDIIN (RealWorld)')
    .expectOutputNameEquals('MIDIOUT (RealWorld)')

deviceDriver.makeDetectionUnit().detectPortPair(midiInput, midiOutput)
    .expectInputNameEquals('MIDIIN (RealWorld) 2')
    .expectOutputNameEquals('MIDIOUT (RealWorld) 2')

deviceDriver.makeDetectionUnit().detectPortPair(midiInput, midiOutput)
    .expectInputNameEquals('MIDIIN (RealWorld) 3')
    .expectOutputNameEquals('MIDIOUT (RealWorld) 3')

var surface = deviceDriver.mSurface

//-----------------------------------------------------------------------------
// 2. SURFACE LAYOUT - create control elements and midi bindings
//-----------------------------------------------------------------------------

function makeFaderStrip(channelIndex, x, y) {
    var faderStrip = {}

    faderStrip.btnMute = surface.makeButton(x + 2 * channelIndex, y, 2, 1)
    faderStrip.btnSolo = surface.makeButton(x + 2 * channelIndex, y + 1, 2, 1)
    faderStrip.fader = surface.makeFader(x + 2 * channelIndex, y + 3, 2, 6).setTypeVertical()

    faderStrip.btnMute.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(15, 59 + channelIndex)
    faderStrip.btnSolo.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(15, 67 + channelIndex)
    faderStrip.fader.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(15, 41 + channelIndex)

    faderStrip.fader.mSurfaceValue.mOnProcessValueChange = function (context, newValue, oldValue) {
        midiOutput.sendMidi(context, helper.sysex.setDisplayValueOfColumn(channelIndex, 0, newValue * (127)))
    }

    faderStrip.fader.mSurfaceValue.mOnDisplayValueChange = function (context, value, units) {
        midiOutput.sendMidi(context, helper.sysex.displaySetTextOfColumn(channelIndex, 2, value))
    }

    faderStrip.fader.mSurfaceValue.mOnTitleChange = function (context, objectTitle, valueTitle) {
        midiOutput.sendMidi(context, helper.sysex.displaySetTextOfColumn(channelIndex, 0, objectTitle))
        midiOutput.sendMidi(context, helper.sysex.displaySetTextOfColumn(channelIndex, 1, valueTitle))
    }

    faderStrip.fader.mSurfaceValue.mOnColorChange = function (context, r, g, b, a, isActive) {
        function updateRow(rowIdx, r, g, b, a) {
            midiOutput.sendMidi(context, helper.sysex.setDisplayColorOfColumn(channelIndex, rowIdx, r * 127 * a, g * 127 * a, b * 127 * a))
        }

        function updateAllRows(r, g, b, a) {
            for(var rowIdx = 0; rowIdx < 4; ++rowIdx)
                updateRow(rowIdx, r, g, b, a)
        }

        if(isActive)
            updateAllRows(r, g, b, a)
        else
            updateAllRows(1, 1, 1, 1)
    }

    return faderStrip
}

function makeKnobStrip(knobIndex, x, y) {
    var knobStrip = {}
    
    knobStrip.knob = surface.makeKnob(x + 2 * knobIndex, y, 2, 2)
    knobStrip.knob.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(15, 21 + knobIndex).setTypeRelativeTwosComplement()

    knobStrip.button = surface.makeButton(x + 2 * knobIndex, y + 4, 2, 1)
    knobStrip.button.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(15, 51 + knobIndex)

    knobStrip.pad1 = surface.makeTriggerPad(x + 2 * knobIndex, y + 5, 2, 2)
    knobStrip.pad1.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToNote(15, 96 + knobIndex)

    knobStrip.pad2 = surface.makeTriggerPad(x + 2 * knobIndex, y + 7, 2, 2)
    knobStrip.pad2.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToNote(15, 112 + knobIndex)

    return knobStrip
}

function makeTransport(x, y) {
    var transport = {}

    var w = 2
    var h = 2

    var currX = x

    function bindMidiCC(button, chn, num) {
        button.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(chn, num)
    }
    
    transport.btnRewind = surface.makeButton(currX, y, w, h)
    bindMidiCC(transport.btnRewind, 15, 112)
    currX = currX + w

    transport.btnForward = surface.makeButton(currX, y, w, h)
    bindMidiCC(transport.btnForward, 15, 113)
    currX = currX + w

    transport.btnStop = surface.makeButton(currX, y, w, h)
    bindMidiCC(transport.btnStop, 15, 114)
    currX = currX + w

    transport.btnStart = surface.makeButton(currX, y, w, h)
    bindMidiCC(transport.btnStart, 15, 115)
    currX = currX + w

    transport.btnCycle = surface.makeButton(currX, y, w, h)
    bindMidiCC(transport.btnCycle, 15, 116)
    currX = currX + w

    transport.btnRecord = surface.makeButton(currX, y, w, h)
    bindMidiCC(transport.btnRecord, 15, 117)
    currX = currX + w

    return transport
}

function makeSurfaceElements() {
    var surfaceElements = {}

    surfaceElements.btn_prevTrack = surface.makeButton(0, 7, 2, 1)
    surfaceElements.btn_prevTrack.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(15, 102)

    surfaceElements.btn_nextTrack = surface.makeButton(2, 7, 2, 1)
    surfaceElements.btn_nextTrack.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(15, 103)

    surfaceElements.btn_prevBinding = surface.makeButton(0, 3, 2, 1)
    surfaceElements.btn_prevBinding.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(15, 81)
    
    surfaceElements.btn_nextBinding = surface.makeButton(0, 4, 2, 1)
    surfaceElements.btn_nextBinding.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(15, 82)
    
    surfaceElements.btn_prevChannelBank = surface.makeButton(2, 3, 2, 1)
    surfaceElements.btn_prevChannelBank.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(15, 85)
    
    surfaceElements.btn_nextChannelBank = surface.makeButton(2, 4, 2, 1)
    surfaceElements.btn_nextChannelBank.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(15, 86)

    surfaceElements.numStrips = 8

    surfaceElements.knobStrips = {}
    surfaceElements.faderStrips = {}

    var xKnobStrip = 5
    var yKnobStrip = 0

    surfaceElements.knobStripBlindPanel = surface.makeBlindPanel(xKnobStrip, yKnobStrip + 2, surfaceElements.numStrips * 2, 2)

    for(var i = 0; i < surfaceElements.numStrips; ++i) {
        surfaceElements.knobStrips[i] = makeKnobStrip(i, xKnobStrip, yKnobStrip)
        surfaceElements.faderStrips[i] = makeFaderStrip(i, 24, 0)
    }

    surfaceElements.transport = makeTransport(41, 7)

    surfaceElements.pianoKeys = surface.makePianoKeys(5, 10, 48, 7, 0, 48)

    return surfaceElements
}

var surfaceElements = makeSurfaceElements()

function makeTransportDisplayFeedback(button, ledID, colorID) {
	button.mSurfaceValue.mOnProcessValueChange = function (context, newValue) {
		midiOutput.sendMidi(context, [ 0xbf, ledID, colorID * newValue ])
	}
}

makeTransportDisplayFeedback(surfaceElements.transport.btnRewind, 112, 3)
makeTransportDisplayFeedback(surfaceElements.transport.btnForward, 113, 3)
makeTransportDisplayFeedback(surfaceElements.transport.btnStop, 114, 3)
makeTransportDisplayFeedback(surfaceElements.transport.btnStart, 115, 21)
makeTransportDisplayFeedback(surfaceElements.transport.btnCycle, 116, 49)
makeTransportDisplayFeedback(surfaceElements.transport.btnRecord, 117, 5)

//-----------------------------------------------------------------------------
// 3. HOST MAPPING - create mapping pages and host bindings
//-----------------------------------------------------------------------------

function makePageWithDefaults(name) {
    var page = deviceDriver.mMapping.makePage(name)

    page.makeActionBinding(surfaceElements.btn_prevTrack.mSurfaceValue, page.mHostAccess.mTrackSelection.mAction.mPrevTrack)
    page.makeActionBinding(surfaceElements.btn_nextTrack.mSurfaceValue, page.mHostAccess.mTrackSelection.mAction.mNextTrack)

    page.makeValueBinding(surfaceElements.transport.btnRewind.mSurfaceValue, page.mHostAccess.mTransport.mValue.mRewind)
    page.makeValueBinding(surfaceElements.transport.btnForward.mSurfaceValue, page.mHostAccess.mTransport.mValue.mForward)
    page.makeValueBinding(surfaceElements.transport.btnStop.mSurfaceValue, page.mHostAccess.mTransport.mValue.mStop).setTypeToggle()
    page.makeValueBinding(surfaceElements.transport.btnStart.mSurfaceValue, page.mHostAccess.mTransport.mValue.mStart).setTypeToggle()
    page.makeValueBinding(surfaceElements.transport.btnCycle.mSurfaceValue, page.mHostAccess.mTransport.mValue.mCycleActive).setTypeToggle()
    page.makeValueBinding(surfaceElements.transport.btnRecord.mSurfaceValue, page.mHostAccess.mTransport.mValue.mRecord).setTypeToggle()

    return page
}

function makeSubPage(subPageArea, name) {
    var subPage = subPageArea.makeSubPage(name)
    var msgText = 'sub page ' + name + ' activated'
    subPage.mOnActivate = function(activeDevice) {
        console.log(msgText)
    }
    return subPage
}

function makePageMixer() {
    var page = makePageWithDefaults('Mixer')

    var knobSubPageArea = page.makeSubPageArea('Knobs')

    var subPageVolume = makeSubPage(knobSubPageArea, 'Volume')
    var subPagePan = makeSubPage(knobSubPageArea, 'Pan')

    var subPageListSendLevel = []

    var numSendLevelSubPages = midiremote_api.mDefaults.getNumberOfSendSlots ()
    for(var subPageIdx = 0; subPageIdx < numSendLevelSubPages; ++subPageIdx) {
        var nameSubPage = 'Send Level ' + (subPageIdx + 1).toString()
        var subPageSendLevel = makeSubPage(knobSubPageArea, nameSubPage)
        subPageListSendLevel.push(subPageSendLevel)
    }

    var hostMixerBankZone = page.mHostAccess.mMixConsole.makeMixerBankZone()
        .excludeInputChannels()
        .excludeOutputChannels()

    page.makeActionBinding(surfaceElements.btn_prevChannelBank.mSurfaceValue, hostMixerBankZone.mAction.mPrevBank)
    page.makeActionBinding(surfaceElements.btn_nextChannelBank.mSurfaceValue, hostMixerBankZone.mAction.mNextBank)

    page.makeActionBinding(surfaceElements.btn_prevBinding.mSurfaceValue, knobSubPageArea.mAction.mPrev)
    page.makeActionBinding(surfaceElements.btn_nextBinding.mSurfaceValue, knobSubPageArea.mAction.mNext)

    function bindChannelBankItem(index) {
        var channelBankItem = hostMixerBankZone.makeMixerBankChannel()

        var knobValue = surfaceElements.knobStrips[index].knob.mSurfaceValue
        var selectedButtonValue = surfaceElements.knobStrips[index].button.mSurfaceValue

        var muteValue = surfaceElements.faderStrips[index].btnMute.mSurfaceValue
        var soloValue = surfaceElements.faderStrips[index].btnSolo.mSurfaceValue
        var faderValue = surfaceElements.faderStrips[index].fader.mSurfaceValue

        page.makeValueBinding (knobValue, channelBankItem.mValue.mVolume).setSubPage(subPageVolume)
        page.makeValueBinding (knobValue, channelBankItem.mValue.mPan).setSubPage(subPagePan)

        for(var subPageIdx = 0; subPageIdx < numSendLevelSubPages; ++subPageIdx) {
            var sendLevel = channelBankItem.mSends.getByIndex(subPageIdx).mLevel
            var subPage = subPageListSendLevel[subPageIdx]
            page.makeValueBinding (knobValue, sendLevel).setSubPage(subPage)
        }

        page.makeValueBinding (selectedButtonValue, channelBankItem.mValue.mSelected)

        page.makeValueBinding (muteValue, channelBankItem.mValue.mMute).setTypeToggle()
        page.makeValueBinding (soloValue, channelBankItem.mValue.mSolo).setTypeToggle()
        page.makeValueBinding (faderValue, channelBankItem.mValue.mVolume)
    }

    for(var i = 0; i < 8; ++i)
        bindChannelBankItem(i)

    return page
}

function makePageSelectedTrack() {
    var page = makePageWithDefaults('Selected Track')

    var selectedTrackChannel = page.mHostAccess.mTrackSelection.mMixerChannel

    for(var idx = 0; idx < surfaceElements.knobStrips.length; ++idx)
        page.makeValueBinding (surfaceElements.knobStrips[idx].knob.mSurfaceValue, selectedTrackChannel.mQuickControls.getByIndex(idx))
    
    return page
}

var pageMixer = makePageMixer()
var pageSelectedTrack = makePageSelectedTrack()

pageMixer.mOnActivate = function (context) {
	helper.display.reset(context, midiOutput)
	console.log('from script: RealWorldDevice page "Mixer" activated')
}

pageSelectedTrack.mOnActivate = function (context) {
	helper.display.reset(context, midiOutput)
	console.log('from script: RealWorldDevice page "Selected Track" activated')
}
