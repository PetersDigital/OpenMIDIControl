//-----------------------------------------------------------------------------
// 1. DRIVER SETUP - create driver object, midi ports and detection information
//-----------------------------------------------------------------------------

// get the api's entry point
var midiremote_api = require('midiremote_api_v1')

// create the device driver main object
var deviceDriver = midiremote_api.makeDeviceDriver('Akai', 'APC MINI', 'Steinberg Media Technologies GmbH')

// create objects representing the hardware's MIDI ports
var midiInput = deviceDriver.mPorts.makeMidiInput()
var midiOutput = deviceDriver.mPorts.makeMidiOutput()

// Sysex-ID-Response determined with WIN & Cubase 
// [ F0 7E 7F 06 02|47|28 00 
//   19 01 00 00 00 7F 00 00 
//   00 00 00 00 00 00 00 00
//   00 00 00 00 00 00 00 00 
//   00 00 F7]

deviceDriver.makeDetectionUnit().detectPortPair(midiInput, midiOutput)
    .expectSysexIdentityResponse('47', '2800', '1901')

var surface = deviceDriver.mSurface

//-----------------------------------------------------------------------------
// 2. SURFACE LAYOUT - create control elements and midi bindings
//-----------------------------------------------------------------------------

var midiChannel = 0

// create pad matrix
var wPad = 2
var hPad = 1

function makeMatrixPad(padIndex) {
    var padStrip = {}

    var row = Math.floor(padIndex / 8)
    var col = padIndex % 8

    var xPads = (wPad * col)
    var yPads = (7 * hPad) - (row * hPad)

    padStrip.pad = surface.makeTriggerPad(xPads, yPads, wPad, hPad)
    padStrip.pad.mSurfaceValue.mMidiBinding
        .setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannel, 0x00 + padIndex)

    return padStrip
}

// create Scene Launch Pads
var buttonSize = hPad

function makeRightStripPad(padIndex) {

    var xScenePads = (wPad * 8) + ((wPad - buttonSize) / 2)
    var yScenePads = (padIndex * hPad)

    var sceneLaunchPad = surface.makeButton(xScenePads, yScenePads, buttonSize, buttonSize).setShapeCircle()
    sceneLaunchPad.mSurfaceValue.mMidiBinding
        .setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannel, 0x52 + padIndex)

    return sceneLaunchPad
}

// create shift pad 
var shiftPadSize = hPad
var xShift = (wPad * 8) + ((wPad - shiftPadSize) / 2)
var yShift = 8

var shiftPad = surface.makeTriggerPad(xShift, yShift, shiftPadSize, shiftPadSize)
shiftPad.mSurfaceValue.mMidiBinding
    .setInputPort(midiInput)
    .setOutputPort(midiOutput)
    .bindToNote(midiChannel, 0x62)

// create round pad/button row
function makeStripButton(buttonIndex) {
    var buttonsStrip = {}

    var xButtons = (wPad * buttonIndex) + ((wPad - buttonSize) / 2)
    var yButtons = (8 * hPad)

    buttonsStrip.button = surface.makeButton(xButtons, yButtons, buttonSize, buttonSize).setShapeCircle()
    buttonsStrip.button.mSurfaceValue.mMidiBinding
        .setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannel, 0x40 + buttonIndex)

    return buttonsStrip
}

// create fader and labels
var wFader = wPad - 0.2
var hFader = 3 * hPad

function makeFader(faderIndex) {
    var faderStrip = {}

    var xFader = (wPad * faderIndex) + ((wPad - wFader) / 2)
    var yFader = (9 * hPad)
    var xLabel = (wPad * faderIndex)
    var yLabel = yFader + hFader

    faderStrip.fader = surface.makeFader(xFader, yFader, wFader, hFader)
    faderStrip.fader.mSurfaceValue.mMidiBinding
        .setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToControlChange(midiChannel, 0x30 + faderIndex)

    var label = surface.makeLabelField(xLabel, yLabel, wPad, 1)

    label.relateTo(faderStrip.fader)

    faderStrip.label = label

    return faderStrip
}

// create surface elements 
function makeSurfaceElements() {
    var surfaceElements = {}

    surfaceElements.numElements = 8
    surfaceElements.numPads = 8 * 8
    surfaceElements.numFaders = 9

    surfaceElements.padMatrix = []
    surfaceElements.rightStripPads = []
    surfaceElements.stripButtons = []
    surfaceElements.stripFaders = []

    for (var i = 0; i < surfaceElements.numPads; ++i)
        surfaceElements.padMatrix.push(makeMatrixPad(i))

    for (var j = 0; j < surfaceElements.numElements; ++j) {
        surfaceElements.rightStripPads.push(makeRightStripPad(j))
        surfaceElements.stripButtons.push(makeStripButton(j))
    }

    for (var l = 0; l < surfaceElements.numFaders; ++l)
        surfaceElements.stripFaders.push(makeFader(l))

    return surfaceElements
}

var surfaceElements = makeSurfaceElements()
var rightStripPads = surfaceElements.rightStripPads
var stripButtons = surfaceElements.stripButtons
var stripFaders = surfaceElements.stripFaders

//-----------------------------------------------------------------------------
// 3. HOST MAPPING - create mapping pages and host bindings
//-----------------------------------------------------------------------------

// create mapping page
var page = deviceDriver.mMapping.makePage('Default')

// create host accessing objects
var hostTransport = page.mHostAccess.mTransport.mValue

var hostMixerBankZone = page.mHostAccess.mMixConsole.makeMixerBankZone()
    .excludeInputChannels()
    .excludeOutputChannels()

var mainOutputChannel = page.mHostAccess.mMixConsole.makeMixerBankZone('Stereo Out')
    .includeOutputChannels()
    .makeMixerBankChannel()

// create sub pages for shift functions
var subPageAreaFunctionMode = page.makeSubPageArea('Function Mode')
var subPageFuncMain = subPageAreaFunctionMode.makeSubPage('Main')

var subPageVolume = subPageAreaFunctionMode.makeSubPage('Volume')
var subPagePan = subPageAreaFunctionMode.makeSubPage('Pan')
var subPageSend = subPageAreaFunctionMode.makeSubPage('Send')
var subPageQC = subPageAreaFunctionMode.makeSubPage('Focus Quick Controls')

var subPageFuncShift = subPageAreaFunctionMode.makeSubPage('Shift')

// create shift mode
page.makeActionBinding(shiftPad.mSurfaceValue, subPageFuncShift.mAction.mActivate)
    .setSubPage(subPageFuncMain)

page.makeActionBinding(shiftPad.mSurfaceValue, subPageFuncMain.mAction.mActivate)
    .mapToValueRange(1, 0)
    .setSubPage(subPageFuncShift)

// Scene Launch - MIDI bindings
page.makeValueBinding(rightStripPads[5].mSurfaceValue, hostTransport.mCycleActive).setTypeToggle().setSubPage(subPageFuncMain)
page.makeValueBinding(rightStripPads[6].mSurfaceValue, hostTransport.mRecord).setTypeToggle().setSubPage(subPageFuncMain)
page.makeValueBinding(rightStripPads[7].mSurfaceValue, hostTransport.mStart).setTypeToggle().setSubPage(subPageFuncMain)

page.makeValueBinding(rightStripPads[5].mSurfaceValue, hostTransport.mMetronomeActive).setTypeToggle().setSubPage(subPageFuncShift)
page.makeValueBinding(rightStripPads[6].mSurfaceValue, hostTransport.mRewind).setTypeToggle().setSubPage(subPageFuncShift)
page.makeValueBinding(rightStripPads[7].mSurfaceValue, hostTransport.mForward).setTypeToggle().setSubPage(subPageFuncShift)

// Round Pads/Buttons - MIDI bindings
page.makeCommandBinding(stripButtons[0].button.mSurfaceValue, 'Navigate', 'Up').setSubPage(subPageFuncShift)
page.makeCommandBinding(stripButtons[1].button.mSurfaceValue, 'Navigate', 'Down').setSubPage(subPageFuncShift)
page.makeCommandBinding(stripButtons[2].button.mSurfaceValue, 'Navigate', 'Left').setSubPage(subPageFuncShift)
page.makeCommandBinding(stripButtons[3].button.mSurfaceValue, 'Navigate', 'Right').setSubPage(subPageFuncShift)

page.makeActionBinding(stripButtons[4].button.mSurfaceValue, subPageVolume.mAction.mActivate)
    .setSubPage(subPageFuncShift)

page.makeActionBinding(stripButtons[5].button.mSurfaceValue, subPagePan.mAction.mActivate)
    .setSubPage(subPageFuncShift)

page.makeActionBinding(stripButtons[6].button.mSurfaceValue, subPageSend.mAction.mActivate)
    .setSubPage(subPageFuncShift)

page.makeActionBinding(stripButtons[7].button.mSurfaceValue, subPageQC.mAction.mActivate)
    .setSubPage(subPageFuncShift)

// fader and round pads/buttons MIDI bindings
for (var index = 0; index < surfaceElements.numElements; ++index) {
    var mixerBankChannel = hostMixerBankZone.makeMixerBankChannel()
    var sendLevel = mixerBankChannel.mSends.getByIndex(index).mLevel
    var panLevel = mixerBankChannel.mValue.mPan
    var focusQuickControl = page.mHostAccess.mFocusedQuickControls.getByIndex(index)

    page.makeValueBinding(stripFaders[index].fader.mSurfaceValue, mixerBankChannel.mValue.mVolume).setValueTakeOverModeScaled().setSubPage(subPageVolume)
    page.makeValueBinding(stripFaders[index].fader.mSurfaceValue, panLevel).setValueTakeOverModeScaled().setSubPage(subPagePan)
    page.makeValueBinding(stripFaders[index].fader.mSurfaceValue, sendLevel).setValueTakeOverModeScaled().setSubPage(subPageSend)
    page.makeValueBinding(stripFaders[index].fader.mSurfaceValue, focusQuickControl).setValueTakeOverModeScaled().setSubPage(subPageQC)
}

// fader 9 - Main Volume
page.makeValueBinding(stripFaders[8].fader.mSurfaceValue, mainOutputChannel.mValue.mVolume)

//round pads/buttons main
page.makeActionBinding(stripButtons[0].button.mSurfaceValue, page.mHostAccess.mTrackSelection.mAction.mPrevTrack).setSubPage(subPageFuncMain)
page.makeActionBinding(stripButtons[1].button.mSurfaceValue, page.mHostAccess.mTrackSelection.mAction.mNextTrack).setSubPage(subPageFuncMain)
page.makeActionBinding(stripButtons[2].button.mSurfaceValue, hostMixerBankZone.mAction.mPrevBank).setSubPage(subPageFuncMain)
page.makeActionBinding(stripButtons[3].button.mSurfaceValue, hostMixerBankZone.mAction.mNextBank).setSubPage(subPageFuncMain)

page.makeCommandBinding(stripButtons[4].button.mSurfaceValue, 'Transport', 'Return to Zero').setSubPage(subPageFuncMain)
page.makeCommandBinding(stripButtons[5].button.mSurfaceValue, 'Transport', 'Goto End').setSubPage(subPageFuncMain)
page.makeCommandBinding(stripButtons[6].button.mSurfaceValue, 'Edit', 'Undo').setSubPage(subPageFuncMain)
page.makeCommandBinding(stripButtons[7].button.mSurfaceValue, 'Edit', 'Redo').setSubPage(subPageFuncMain)
