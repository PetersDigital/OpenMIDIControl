
//-----------------------------------------------------------------------------
// 1. DRIVER SETUP - create driver object, midi ports and detection information
//-----------------------------------------------------------------------------

var midiremote_api = require('midiremote_api_v1')
var deviceDriver = midiremote_api.makeDeviceDriver('Akai', 'MPK249', 'Steinberg Media Technology GmbH')

var midiInput = deviceDriver.mPorts.makeMidiInput();
var midiOutput = deviceDriver.mPorts.makeMidiOutput();

// SySEx-ID-Response by sending [7E 7F 06 01] in Cubase
// [ F0 7E 7F 06 02 47 24 00 
//   19 00 01 00 00 00 00 12 
//   7F 7F 41 31 31 37 30 39
//   31 35 35 35 32 37 37 30
//   38 00 F7]

var detectWin = deviceDriver.makeDetectionUnit()
detectWin.detectPortPair(midiInput, midiOutput)
    .expectInputNameEquals('MPK249')
    .expectOutputNameEquals('MPK249')
    .expectSysexIdentityResponse('47', '2400', '1900')

var detectMacAndWinRT = deviceDriver.makeDetectionUnit()
detectMacAndWinRT.detectPortPair(midiInput, midiOutput)
    .expectInputNameContains('A')
    .expectOutputNameContains('A')
    .expectSysexIdentityResponse('47', '2400', '1900')

// ----------------------------------------------------------------
// Activate hardware preset 10 (Cubase)
// ----------------------------------------------------------------
// To change the preset remotely, you will have to send a SysEx Message to the keyboard. Here is the format:
// F0 47 00 24 30 00 04 01 00 01 xx F7 ;  
// “xx” is the preset number, from 00 (preset 1) to 1D (preset 30). 
deviceDriver.mOnActivate = function (activeDevice) {
    midiOutput.sendMidi(activeDevice, [0xF0, 0x47, 0x00, 0x24, 0x30, 0x00, 0x04, 0x01, 0x00, 0x01, 0x09, 0xF7])
}

deviceDriver.setUserGuide('akai_mpk249.pdf')

var surface = deviceDriver.mSurface

//-----------------------------------------------------------------------------
// 2. SURFACE LAYOUT - create control elements and midi bindings
//-----------------------------------------------------------------------------

function Helper_getInnerCoordCentered(sizeOuter, sizeInner) {
    return (sizeOuter / 2 - sizeInner / 2)
}

function Helper_getEqualSpacingCoord(totalLength, elementSize, numOfElements) {
    return (totalLength - elementSize) / numOfElements
}
//-----------------------------------------------------------------------------
// surface element sizes
//-----------------------------------------------------------------------------

// small square buttons - Full Level, Bank A, Bank B...etc.
var wSmallSquareButton = 1.2
var hSmallSquareButton = 0.7

// Pitch Bend and Modwheel
var wPitchBend = wSmallSquareButton
var hPitchBend = 4.2

// Padmatrix
var padSize = 2
var padSpacing = padSize

// pads and keyboard square buttons - Tap Tempo, Note Repeat, etc.
var wTapTempo = wSmallSquareButton
var hTapTempo = wTapTempo - 0.1

// DAW Control Buttons
var wUpDownDAWControl = 1.2
var wLeftRightDAWControl = 1
var wEnterDAWControl = 0.9

var hLeftRightDAWControl = padSize + 0.1
var hUpDownDAWControl = (hLeftRightDAWControl / 3) + 0.1
var hEnterDAWControl = (hLeftRightDAWControl / 3)

// Display
var wDisplay = 5.8
var hDisplay = 3.2

// Transportbuttons
var wTransport = wTapTempo + 0.2
var hTransport = hTapTempo

// Display Navigation Buttons
var wLeftRightArrowButt = hSmallSquareButton
var hLeftRightArrowButt = padSize - 0.1
var wUpDownArrowButt = 1.1
var hUpDownArrowButt = 1

// Fader
var wFader = padSize
var hFader = 2.2 * padSize

// Knobs
var knobSize = wFader - 0.2

// Piano
var wPiano = 4 * 12
var hPiano = padSize * 4

//-----------------------------------------------------------------------------
// blind panels - left side
//-----------------------------------------------------------------------------
function makeBlindPanelsLeftSide(x, y) {

    // DAW CONTROL
    var xLeftDAWControl = 6 + x - 0.35
    var xUpDownControl = xLeftDAWControl + wLeftRightDAWControl
    var xEnterDAWControl = Helper_getInnerCoordCentered(wUpDownDAWControl, wEnterDAWControl) + xUpDownControl
    var xRightDAWControl = xUpDownControl + wUpDownDAWControl

    var yUpLeftRightDAWControl = padSize + y + 0.1
    var yDownDAWControl = yUpLeftRightDAWControl + hLeftRightDAWControl - hUpDownDAWControl
    var yEnterDAWControl = Helper_getInnerCoordCentered(hLeftRightDAWControl, hEnterDAWControl) + yUpLeftRightDAWControl

    surface.makeBlindPanel(xUpDownControl, yUpLeftRightDAWControl, wUpDownDAWControl, hUpDownDAWControl)            //up
    surface.makeBlindPanel(xLeftDAWControl, yUpLeftRightDAWControl, wLeftRightDAWControl, hLeftRightDAWControl)     //left
    surface.makeBlindPanel(xEnterDAWControl, yEnterDAWControl, wEnterDAWControl, hEnterDAWControl)                  //enter
    surface.makeBlindPanel(xRightDAWControl, yUpLeftRightDAWControl, wLeftRightDAWControl, hLeftRightDAWControl)    //right
    surface.makeBlindPanel(xUpDownControl, yDownDAWControl, wUpDownDAWControl, hUpDownDAWControl)                   //down

    //TAP TEMPO - LATCH
    var xTapTempo = xLeftDAWControl
    var yTapTempo = 2.6 * padSize + y

    var xNoteRepeat = xTapTempo + wUpDownDAWControl + (2 * wLeftRightDAWControl) - wTapTempo
    var yAppreggiator = (padSize * 4) - hTapTempo + y

    surface.makeBlindPanel(xTapTempo, yTapTempo, wTapTempo, hTapTempo) // Tap Tempo
    surface.makeBlindPanel(xTapTempo, yAppreggiator, wTapTempo, hTapTempo) // Arpreggiator

    surface.makeBlindPanel(xNoteRepeat, yTapTempo, wTapTempo, hTapTempo) // Note Repeat
    surface.makeBlindPanel(xNoteRepeat, yAppreggiator, wTapTempo, hTapTempo) // Latch

    // FULL LEVEL - BANK D
    var xFullLevel = xTapTempo + 4
    var yFullLevel = y

    var flatButtonSpacing = Helper_getEqualSpacingCoord(padSize * 4, hSmallSquareButton, 5)

    surface.makeBlindPanel(xFullLevel, yFullLevel, wSmallSquareButton, hSmallSquareButton) // Full Level Button
    yFullLevel += flatButtonSpacing

    surface.makeBlindPanel(xFullLevel, yFullLevel, wSmallSquareButton, hSmallSquareButton) // 16 Level
    yFullLevel += flatButtonSpacing

    surface.makeBlindPanel(xFullLevel, yFullLevel, wSmallSquareButton, hSmallSquareButton) // Bank A
    yFullLevel += flatButtonSpacing

    surface.makeBlindPanel(xFullLevel, yFullLevel, wSmallSquareButton, hSmallSquareButton) // Bank B
    yFullLevel += flatButtonSpacing

    surface.makeBlindPanel(xFullLevel, yFullLevel, wSmallSquareButton, hSmallSquareButton) // Bank C
    yFullLevel += flatButtonSpacing

    surface.makeBlindPanel(xFullLevel, yFullLevel, wSmallSquareButton, hSmallSquareButton) // Bank D
}

//-----------------------------------------------------------------------------
// pad matrix
//-----------------------------------------------------------------------------
var padControlLayerZone = surface.makeControlLayerZone('Pad Bank')
var controlLayerBankA = padControlLayerZone.makeControlLayer('Bank A')
var controlLayerBankB = padControlLayerZone.makeControlLayer('Bank B')
var controlLayerBankC = padControlLayerZone.makeControlLayer('Bank C')
var controlLayerBankD = padControlLayerZone.makeControlLayer('Bank D')

var midiChannelPadStrip = 9

function makePad(padIndex, x, y) {
    var padStrip = {}

    var row = Math.floor(padIndex / 4)
    var col = padIndex % 4
    var xPads = (col * padSpacing) + x + 12
    var yPads = (row * (-padSize)) + (padSize * 3) + y

    padStrip.padOfLayerA = surface.makeTriggerPad(xPads, yPads, padSize, padSize).setControlLayer(controlLayerBankA)
    padStrip.padOfLayerA.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannelPadStrip, 0x24 + padIndex)

    padStrip.padOfLayerB = surface.makeTriggerPad(xPads, yPads, padSize, padSize).setControlLayer(controlLayerBankB)
    padStrip.padOfLayerB.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannelPadStrip, 0x34 + padIndex)

    padStrip.padOfLayerC = surface.makeTriggerPad(xPads, yPads, padSize, padSize).setControlLayer(controlLayerBankC)
    padStrip.padOfLayerC.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannelPadStrip, 0x44 + padIndex)

    padStrip.padOfLayerD = surface.makeTriggerPad(xPads, yPads, padSize, padSize).setControlLayer(controlLayerBankD)
    padStrip.padOfLayerD.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannelPadStrip, 0x54 + padIndex)

    return padStrip
}

//-----------------------------------------------------------------------------
// blind panels - right side
//-----------------------------------------------------------------------------
var totalRowLength = 9
var firstBlindPanelRightSide = 21.5

var numBlindPanelsRow1 = 5
var numBlindPanelsRow2 = 6

var blindPanelSpacing = Helper_getEqualSpacingCoord(totalRowLength, 6 * wSmallSquareButton, 5)

function makeBlindPanelsRightSide(x, y) {

    // display
    var xDisplay = firstBlindPanelRightSide + 0.2 + x
    var yDisplay = 0.5 + y
    surface.makeBlindPanel(xDisplay, yDisplay, wDisplay, hDisplay)

    // preset - preview
    var xPreset = firstBlindPanelRightSide + x
    var yPreset = padSize * 2 + y
    var yOctaveButton = (padSize * 4) - hSmallSquareButton + y

    for (var i = 0; i < numBlindPanelsRow1; ++i) {
        var xSmallDisplayButtons = (i * (wSmallSquareButton + blindPanelSpacing)) + xPreset

        surface.makeBlindPanel(xSmallDisplayButtons, yPreset, wSmallSquareButton, hSmallSquareButton)
        surface.makeBlindPanel(xSmallDisplayButtons, yOctaveButton, wSmallSquareButton, hSmallSquareButton)
    }

    for (var i = 0; i < numBlindPanelsRow2; ++i) {
        var xSmallDisplayButtons = (i * (wSmallSquareButton + blindPanelSpacing)) + xPreset
        surface.makeBlindPanel(xSmallDisplayButtons, yOctaveButton, wSmallSquareButton, hSmallSquareButton)
    }

    // push encoder - "push to enter"
    var xPushToEnterKnob = (5 * (wSmallSquareButton + blindPanelSpacing)) + xPreset - ((knobSize - wSmallSquareButton) / 2)
    var yPushToEnterKnob = y - 0.25

    // blind panel knob - "push to enter"
    surface.makeBlindPanel(xPushToEnterKnob, yPushToEnterKnob, knobSize, knobSize).setShapeCircle()

    // display navigation - arrow buttons
    var xLeftArrowButt = xPushToEnterKnob - 0.25
    var xUpDownArrowButt = Helper_getInnerCoordCentered(knobSize, wUpDownArrowButt) + xPushToEnterKnob
    var xRightArrowButt = xPushToEnterKnob + knobSize - 0.5

    var yUpLeftRightArrowButt = yPushToEnterKnob + knobSize
    var yDownArrowButt = yUpLeftRightArrowButt + hLeftRightArrowButt - hUpDownArrowButt

    // blind panel arrows
    surface.makeBlindPanel(xUpDownArrowButt, yUpLeftRightArrowButt, wUpDownArrowButt, hUpDownArrowButt) // up
    surface.makeBlindPanel(xLeftArrowButt, yUpLeftRightArrowButt, wLeftRightArrowButt, hLeftRightArrowButt) // left
    surface.makeBlindPanel(xRightArrowButt, yUpLeftRightArrowButt, wLeftRightArrowButt, hLeftRightArrowButt) // right
    surface.makeBlindPanel(xUpDownArrowButt, yDownArrowButt, wUpDownArrowButt, hUpDownArrowButt) // down
}

//-----------------------------------------------------------------------------
// blind panels - right side
//-----------------------------------------------------------------------------
var midiChannelTransport = 0
var transportCCs = [0x72, 0x73, 0x74, 0x75, 0x76, 0x77]

function makeTransport(x, y) {
    var transport = {}

    var xTransport = firstBlindPanelRightSide + x
    var yTransport = padSize * 3 + y
    var spacing = Helper_getEqualSpacingCoord(totalRowLength, 5 * wTransport, 4)

    var xBtnLoop = (5 * (wSmallSquareButton + blindPanelSpacing)) + xTransport
    var yBtnLoop = padSize * 2 + y

    transport.btnCycle = surface.makeButton(xBtnLoop, yBtnLoop, wSmallSquareButton, hSmallSquareButton)
    transport.btnCycle.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToControlChange(midiChannelTransport, transportCCs[0])

    transport.btnRewind = surface.makeButton(xTransport, yTransport, wTransport, hTransport)
    transport.btnRewind.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .bindToControlChange(midiChannelTransport, transportCCs[1])

    xTransport += wTransport + spacing
    transport.btnForward = surface.makeButton(xTransport, yTransport, wTransport, hTransport)
    transport.btnForward.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .bindToControlChange(midiChannelTransport, transportCCs[2])

    xTransport += wTransport + spacing
    transport.btnStop = surface.makeButton(xTransport, yTransport, wTransport, hTransport)
    transport.btnStop.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .bindToControlChange(midiChannelTransport, transportCCs[3])

    xTransport += wTransport + spacing
    transport.btnStart = surface.makeButton(xTransport, yTransport, wTransport, hTransport)
    transport.btnStart.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .bindToControlChange(midiChannelTransport, transportCCs[4])

    xTransport += wTransport + spacing
    transport.btnRecord = surface.makeButton(xTransport, yTransport, wTransport, hTransport)
    transport.btnRecord.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .bindToControlChange(midiChannelTransport, transportCCs[5])


    return transport
}

//-----------------------------------------------------------------------------
// fader strips
//-----------------------------------------------------------------------------
var faderControlLayerZone = surface.makeControlLayerZone('Control Bank')
var controlLayerControlBankA = faderControlLayerZone.makeControlLayer('Control Bank A')
var controlLayerControlBankB = faderControlLayerZone.makeControlLayer('Control Bank B')
var controlLayerControlBankC = faderControlLayerZone.makeControlLayer('Control Bank C')

var yFader = knobSize + (hUpDownArrowButt * 1.2)

var faderKnobSpacing = (wFader - knobSize) / 2
var faderButtonSpacing = (wFader - wSmallSquareButton) / 2

function makeFaderStrip(elementIndex, x, y) {
    var faderStrip = {}

    var ySButtons = (padSize * 4) - hSmallSquareButton + y
    var xFaderElement = 32 + x
    var yFaderButton = y - 0.25
    var xKnobElements = wFader * elementIndex + xFaderElement + faderKnobSpacing
    var xFaderElements = wFader * elementIndex + xFaderElement
    var xButtonElements = wFader * elementIndex + xFaderElement + faderButtonSpacing

    // knobs above faders 1-8
    faderStrip.knobA = surface.makeKnob(xKnobElements, yFaderButton, knobSize, knobSize).setControlLayer(controlLayerControlBankA)
    faderStrip.knobA.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .bindToControlChange(elementIndex, 0x0A)

    faderStrip.knobB = surface.makeKnob(xKnobElements, yFaderButton, knobSize, knobSize).setControlLayer(controlLayerControlBankB)
    faderStrip.knobB.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .bindToControlChange(elementIndex + 8, 0x0A)

    faderStrip.knobC = surface.makeKnob(xKnobElements, yFaderButton, knobSize, knobSize).setControlLayer(controlLayerControlBankC)
    faderStrip.knobC.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .bindToControlChange(elementIndex, 0x0C)

    // fader 1-8
    faderStrip.faderA = surface.makeFader(xFaderElements, yFader, wFader, hFader).setControlLayer(controlLayerControlBankA)
    faderStrip.faderA.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .bindToControlChange(elementIndex, 0x07)

    faderStrip.faderB = surface.makeFader(xFaderElements, yFader, wFader, hFader).setControlLayer(controlLayerControlBankB)
    faderStrip.faderB.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .bindToControlChange(elementIndex + 8, 0x07)

    faderStrip.faderC = surface.makeFader(xFaderElements, yFader, wFader, hFader).setControlLayer(controlLayerControlBankC)
    faderStrip.faderC.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .bindToControlChange(elementIndex, 0x08)

    // fader buttons below faders 1-8
    faderStrip.buttonA = surface.makeButton(xButtonElements, ySButtons, wSmallSquareButton, hSmallSquareButton).setControlLayer(controlLayerControlBankA)
    faderStrip.buttonA.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToControlChange(elementIndex, 0x40)

    faderStrip.buttonB = surface.makeButton(xButtonElements, ySButtons, wSmallSquareButton, hSmallSquareButton).setControlLayer(controlLayerControlBankB)
    faderStrip.buttonB.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToControlChange(elementIndex + 8, 0x40)

    faderStrip.buttonC = surface.makeButton(xButtonElements, ySButtons, wSmallSquareButton, hSmallSquareButton).setControlLayer(controlLayerControlBankC)
    faderStrip.buttonC.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToControlChange(elementIndex, 0x41)

    return faderStrip
}

function makeSurfaceElements(x, y) {
    var surfaceElements = {}

    // pitch bend & modwheel
    var xPitchBend = 1.1 + x
    var yPitchBend = 3 + y

    var pitchBend = surface.makeModWheel(xPitchBend, yPitchBend, wPitchBend, hPitchBend)
    pitchBend.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToPitchBend(0)
    xPitchBend = xPitchBend + wPitchBend * 2

    var modWheel = surface.makeModWheel(xPitchBend, yPitchBend, wPitchBend, hPitchBend)
    modWheel.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(0, 0x01)

    // piano keys
    var yPianoKeys = padSize * 5 + y
    surface.makePianoKeys(x, yPianoKeys, wPiano, hPiano, 0, wPiano)

    // blind panels left side
    makeBlindPanelsLeftSide(x, y)

    // blind panels right side
    makeBlindPanelsRightSide(x, y)

    // pad matrix, transports and fader elements
    surfaceElements.numPads = 16
    surfaceElements.numTransports = 6
    surfaceElements.numFaderStrip = 8

    surfaceElements.padStrips = []
    surfaceElements.faderStrips = []

    for (var i = 0; i < surfaceElements.numPads; ++i)
        surfaceElements.padStrips.push(makePad(i, x, y))

    surfaceElements.transport = makeTransport(x, y)

    for (var i = 0; i < surfaceElements.numFaderStrip; ++i)
        surfaceElements.faderStrips.push(makeFaderStrip(i, x, y))

    return surfaceElements
}

var surfaceElements = makeSurfaceElements(0, 0.5)

//-----------------------------------------------------------------------------
// 3. HOST MAPPING - create mapping pages and host bindings
//-----------------------------------------------------------------------------

// create mapping page
var page = deviceDriver.mMapping.makePage('Default')

// create host accessing objects
var hostTransportValue = page.mHostAccess.mTransport.mValue
var hostMixerBankZone = page.mHostAccess.mMixConsole.makeMixerBankZone()
    .excludeInputChannels()
    .excludeOutputChannels()

// fader and fader button 1 - 8 mapping
for (var index = 0; index < surfaceElements.numFaderStrip; ++index) {
    var mixerBankChannel = hostMixerBankZone.makeMixerBankChannel()

    var faderStrip = surfaceElements.faderStrips[index]
    var focusQuickControl = page.mHostAccess.mFocusedQuickControls.getByIndex(index)

    page.makeValueBinding(faderStrip.knobA.mSurfaceValue, focusQuickControl).setValueTakeOverModeScaled()
    page.makeValueBinding(faderStrip.faderA.mSurfaceValue, mixerBankChannel.mValue.mVolume).setValueTakeOverModeScaled()
    page.makeValueBinding(faderStrip.buttonA.mSurfaceValue, mixerBankChannel.mValue.mMute)

    page.makeValueBinding(faderStrip.knobB.mSurfaceValue, focusQuickControl).setValueTakeOverModeScaled()
    page.makeValueBinding(faderStrip.faderB.mSurfaceValue, mixerBankChannel.mValue.mVolume).setValueTakeOverModeScaled()
    page.makeValueBinding(faderStrip.buttonB.mSurfaceValue, mixerBankChannel.mValue.mMute)

    page.makeValueBinding(faderStrip.knobC.mSurfaceValue, focusQuickControl).setValueTakeOverModeScaled()
    page.makeValueBinding(faderStrip.faderC.mSurfaceValue, mixerBankChannel.mValue.mVolume).setValueTakeOverModeScaled()
    page.makeValueBinding(faderStrip.buttonC.mSurfaceValue, mixerBankChannel.mValue.mMute)
}

page.makeValueBinding(surfaceElements.transport.btnCycle.mSurfaceValue, hostTransportValue.mCycleActive).setTypeToggle()
page.makeValueBinding(surfaceElements.transport.btnRewind.mSurfaceValue, hostTransportValue.mRewind).setTypeToggle()
page.makeValueBinding(surfaceElements.transport.btnForward.mSurfaceValue, hostTransportValue.mForward).setTypeToggle()
page.makeValueBinding(surfaceElements.transport.btnStop.mSurfaceValue, hostTransportValue.mStop).setTypeToggle()
page.makeValueBinding(surfaceElements.transport.btnStart.mSurfaceValue, hostTransportValue.mStart).setTypeToggle()
page.makeValueBinding(surfaceElements.transport.btnRecord.mSurfaceValue, hostTransportValue.mRecord).setTypeToggle()
