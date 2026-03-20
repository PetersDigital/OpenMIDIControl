//-----------------------------------------------------------------------------
// 1. DRIVER SETUP - create driver object, midi ports and detection information
//-----------------------------------------------------------------------------

// get the api's entry point
var midiremote_api = require('midiremote_api_v1')

// create the device driver main object
var deviceDriver = midiremote_api.makeDeviceDriver('Akai', 'APC40 MKII', 'Steinberg Media Technologies GmbH')

// create objects representing the hardware's MIDI ports
var midiInput = deviceDriver.mPorts.makeMidiInput()
var midiOutput = deviceDriver.mPorts.makeMidiOutput()

/*
SySEx-ID-Response determined with Cubase and ID Request 7E 7F 06 01
[ F0 7E 00 06 02 47 29 00 
  19 00 01 00 01 00 7F 7F 
  7F 7F 41 31 31 38 30 31
  31 35 37 31 32 39 31 32
  34 00 F7]

Format of response from APC40 Mk2 to Device Inquiry message from User Guide
Byte Number     Value               Description
1               0xF0                MIDI System exclusive message start
2               0x7E                Non-Realtime Message
3               <MIDI Channel>      Common MIDI channel setting
4               0x06                Inquiry Message
5               0x02                Inquiry Response
6               0x47                Manufacturers ID Byte
7               0x29                Product model ID
8               0x00                Number of data bytes to follow (most significant)
9               0x19                Number of data bytes to follow (least significant)
10              <Version1>          Software version major most significant
11              <Version2>          Software version major least significant
12              <Version3>          Software version minor most significant
13              <Version4>          Software version minor least significant
14              <DeviceID>          System Exclusive Device ID
15              <Serial1>           <Reserved, Set to 0x00 in this application>
16              <Serial2>           <Reserved, Set to 0x00 in this application>
17              <Serial3>           <Reserved, Set to 0x00 in this application>
18              <Serial4>           <Reserved, Set to 0x00 in this application>
19              <Manufacturing1>    Manufacturing Data byte 1
20              <Manufacturing2>    Manufacturing Data byte 2
21              <Manufacturing3     Manufacturing Data byte 3
22              <Manufacturing4>    Manufacturing Data byte 4
23              <Manufacturing5>    Manufacturing Data byte 5
24              <Manufacturing6>    Manufacturing Data byte 6
25              <Manufacturing7>    Manufacturing Data byte 7
26              <Manufacturing8>    Manufacturing Data byte 8
27              <Manufacturing9>    Manufacturing Data byte 9
28              <Manufacturing10>   Manufacturing Data byte 10
29              <Manufacturing11>   Manufacturing Data byte 11
30              <Manufacturing12>   Manufacturing Data byte 12
31              <Manufacturing13>   Manufacturing Data byte 13
32              <Manufacturing14>   Manufacturing Data byte 14
33              <Manufacturing15>   Manufacturing Data byte 15
34              <Manufacturing16>   This byte should be set to 0x00. 
35              0xF7                MIDI System exclusive message terminator
*/

deviceDriver.makeDetectionUnit().detectPortPair(midiInput, midiOutput)
    .expectSysexIdentityResponse('47', '2900', '1900')

deviceDriver.mOnActivate = function (activeDevice) {
    // put to DAW mode
    midiOutput.sendMidi(activeDevice, [0xF0, 0x47, 0x7F, 0x29, 0x60, 0x00, 0x04, 0x42, 0x09, 0x01, 0x00, 0xF7])
}

deviceDriver.mOnDeactivate = function (activeDevice) {
    // end DAW mode
    midiOutput.sendMidi(activeDevice, [0xF0, 0x47, 0x7F, 0x29, 0x60, 0x00, 0x04, 0x40, 0x09, 0x01, 0x00, 0xF7])
}

var surface = deviceDriver.mSurface

//-----------------------------------------------------------------------------
// 2. SURFACE LAYOUT - create control elements and midi bindings
//-----------------------------------------------------------------------------

// global variables for spacing, dimensions and midi channel number
var midiChannel = 0

// left side on hardware - first 9 columns 
var numStrips = 8
var numSceneLaunchPads = 5

var wStrip = 2  // knobs and pad rows 1, 2, 3, 4 , 5 and 7
var hKnob = 1.8
var hPad = wStrip / 2

var wPadSmall = wStrip * 0.8 // Clip Stop Row

var wFader = wPadSmall
var hFader = 4
var xOffsetFader = Helper_getInnerCoordCentered(wStrip, wFader)

var sizeSmallQuadPads = wStrip / 2

function Helper_getInnerCoordCentered(sizeOuter, sizeInner) {
    return (sizeOuter / 2 - sizeInner / 2)
}

var mediumElementSpacing = Helper_getInnerCoordCentered(wStrip, wPadSmall)

// create label field for the knobs on the left
var wLabelFieldKnobs = wStrip * numStrips
var hLabelFieldKnobs = 0.75
var labelKnobs = surface.makeLabelField(0, 0, wLabelFieldKnobs, hLabelFieldKnobs)

// create surface elements columns 1-8 
function makeElementStrip(elementIndex, x, y) {
    var elementStrip = {}

    var xElement = x + wStrip * elementIndex
    var yElement = y + hLabelFieldKnobs

    elementStrip.knob = surface.makeKnob(xElement, yElement, wStrip, hKnob)
    elementStrip.knob.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToControlChange(midiChannel, 48 + elementIndex)
    yElement += hKnob

    elementStrip.padRow1 = surface.makeTriggerPad(xElement, yElement, wStrip, hPad)
    elementStrip.padRow1.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannel, 0x20 + elementIndex)
    yElement += hPad

    elementStrip.padRow2 = surface.makeTriggerPad(xElement, yElement, wStrip, hPad)
    elementStrip.padRow2.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannel, 0x18 + elementIndex)
    yElement += hPad

    elementStrip.padRow3 = surface.makeTriggerPad(xElement, yElement, wStrip, hPad)
    elementStrip.padRow3.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannel, 0x10 + elementIndex)
    yElement += hPad

    elementStrip.padRow4 = surface.makeTriggerPad(xElement, yElement, wStrip, hPad)
    elementStrip.padRow4.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannel, 0x08 + elementIndex)
    yElement += hPad

    elementStrip.padRow5 = surface.makeTriggerPad(xElement, yElement, wStrip, hPad)
    elementStrip.padRow5.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannel, 0x00 + elementIndex)
    yElement += hPad

    yElement += mediumElementSpacing
    elementStrip.clipStopPad = surface.makeTriggerPad(xElement + mediumElementSpacing, yElement, wPadSmall, hPad)
    elementStrip.clipStopPad.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannel + elementIndex, 0x34)
    yElement = yElement + hPad + mediumElementSpacing

    elementStrip.padRow7 = surface.makeTriggerPad(xElement, yElement, wStrip, hPad)
    elementStrip.padRow7.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannel + elementIndex, 0x33)
    yElement = yElement + hPad

    elementStrip.smallNumPad = surface.makeTriggerPad(xElement, yElement, sizeSmallQuadPads, sizeSmallQuadPads)
    elementStrip.smallNumPad.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannel + elementIndex, 0x32)

    elementStrip.ABPad = surface.makeTriggerPad(xElement + 1, yElement, sizeSmallQuadPads, sizeSmallQuadPads)
    elementStrip.ABPad.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannel + elementIndex, 0x42)

    yElement = yElement + hPad

    elementStrip.sPad = surface.makeTriggerPad(xElement, yElement, sizeSmallQuadPads, sizeSmallQuadPads)
    elementStrip.sPad.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannel + elementIndex, 0x31)

    elementStrip.recEnablePad = surface.makeTriggerPad(xElement + 1, yElement, sizeSmallQuadPads, sizeSmallQuadPads)
    elementStrip.recEnablePad.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannel + elementIndex, 0x30)
    yElement = yElement + hPad

    elementStrip.fader = surface.makeFader(xElement + xOffsetFader, yElement, wFader, hFader)
    elementStrip.fader.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .bindToControlChange(elementIndex, 7)

    yElement = yElement + hFader

    var labelFader = surface.makeLabelField(xElement, yElement, wStrip, 1)
    labelKnobs.relateTo(elementStrip.knob)
    labelFader.relateTo(elementStrip.fader)

    elementStrip.label = labelFader

    return elementStrip
}

function makeElementStrips(x, y) {
    var elementStrips = []
    for (var i = 0; i < numStrips; ++i)
        elementStrips.push(makeElementStrip(i, x, y))
    return elementStrips
}

// ---- Col 9 ----
// create 5x Scene Launch pads - vertically
function makeSceneLaunchPad(index, x, y, firstMidiCC) {
    var xLaunch = x
    var yLaunch = y + index * hPad
    var sceneLaunchPads = surface.makeTriggerPad(xLaunch, yLaunch, wPadSmall, hPad)
    sceneLaunchPads.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannel, firstMidiCC + index)
    return sceneLaunchPads
}

function makeSceneLaunchPadStrip(x, y) {
    var sceneLaunchPadStrips = []
    for (var i = 0; i < numSceneLaunchPads; ++i)
        sceneLaunchPadStrips.push(makeSceneLaunchPad(i, x, y, 0x52))
    return sceneLaunchPadStrips
}

function makeSceneLaunchPadStopAllClips(x, y) {
    return makeSceneLaunchPad(0, x, y, 0x51)
}

// ---- Buttons - from PAN to NUDGE+ ----
function makeRightSide(x, y) {

    var rightSide = {}

    var hPlayButton = hPad
    var wButton = 1
    var hButton = hPlayButton / 2
    var xButtonSpacing = wStrip / 4
    var yButtonSpacing = 1.1

    var xCol10 = x + xButtonSpacing
    var xCol11 = xCol10 + wStrip
    var xCol12 = xCol11 + wStrip
    var xCol13 = xCol12 + wStrip

    var yPlayButton = y + hLabelFieldKnobs + 0.5
    var yRow1 = yPlayButton + hButton
    var yRow2 = yRow1 + yButtonSpacing
    var yRow3 = yRow2 + yButtonSpacing

    var lampDim = wButton / 2
    var lampSpacing = lampDim / 2
    var yLamp = yPlayButton - 0.5

    rightSide.panButton = surface.makeButton(xCol10, yRow1, wButton, hButton)
    rightSide.panButton.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannel, 0x57)

    rightSide.sendsButton = surface.makeButton(xCol10, yRow2, wButton, hButton)
    rightSide.sendsButton.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannel, 0x58)

    rightSide.userButton = surface.makeButton(xCol10, yRow3, wButton, hButton)
    rightSide.userButton.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannel, 0x59)

    rightSide.playLamp = surface.makeLamp(xCol11 + lampSpacing, yLamp, lampDim, lampDim).setShapeCircle()
    rightSide.playLamp.mSurfaceValue.mMidiBinding.setOutputPort(midiOutput)
        .bindToNote(midiChannel, 0x5B)

    rightSide.playButton = surface.makeButton(xCol11, yPlayButton, wButton, hPlayButton)
    rightSide.playButton.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .bindToNote(midiChannel, 0x5B)

    rightSide.playButton.mSurfaceValue.mOnProcessValueChange = function (activeDevice, value) {
        rightSide.playLamp.mSurfaceValue.setProcessValue(activeDevice, value)
    }

    rightSide.metronomeButton = surface.makeButton(xCol11, yRow2, wButton, hButton)
    rightSide.metronomeButton.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannel, 0x5A)

    rightSide.nudgeMinusButton = surface.makeButton(xCol11, yRow3, wButton, hButton)
    rightSide.nudgeMinusButton.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannel, 0x64)

    rightSide.recordLamp = surface.makeLamp(xCol12 + lampSpacing, yLamp, lampDim, lampDim).setShapeCircle()
    rightSide.recordLamp.mSurfaceValue.mMidiBinding.setOutputPort(midiOutput)
        .bindToNote(midiChannel, 0x5D)

    rightSide.recordButton = surface.makeButton(xCol12, yPlayButton, wButton, hPlayButton)
    rightSide.recordButton.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .bindToNote(midiChannel, 0x5D)

    rightSide.recordButton.mSurfaceValue.mOnProcessValueChange = function (activeDevice, value) {
        rightSide.recordLamp.mSurfaceValue.setProcessValue(activeDevice, value)
    }

    rightSide.tapTempoButton = surface.makeButton(xCol12, yRow2, wButton, hButton)
    rightSide.tapTempoButton.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannel, 0x63)

    rightSide.nudgePlusButton = surface.makeButton(xCol12, yRow3, wButton, hButton)
    rightSide.nudgePlusButton.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannel, 0x65)

    rightSide.sessionLamp = surface.makeLamp(xCol13 + lampSpacing, yLamp, lampDim, lampDim).setShapeCircle()
    rightSide.sessionLamp.mSurfaceValue.mMidiBinding.setOutputPort(midiOutput)
        .bindToNote(midiChannel, 0x66)

    rightSide.sessionButton = surface.makeButton(xCol13, yPlayButton, wButton, hPlayButton)
    rightSide.sessionButton.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .bindToNote(midiChannel, 0x66)
    
    rightSide.sessionButton.mSurfaceValue.mOnProcessValueChange = function (activeDevice, value) {
        rightSide.sessionLamp.mSurfaceValue.setProcessValue(activeDevice, value)
    }

    rightSide.tempoKnob = surface.makeKnob(xCol13 - xButtonSpacing, yRow2, wStrip, hKnob)
    rightSide.tempoKnob.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .bindToControlChange(midiChannel, 13)
        .setTypeRelativeTwosComplement()

    // ---- 4x2 Device Control Knobs ----
    rightSide.deviceControlKnobs = []
    var numRightSideKnobs = 8
    var xKnobsDeviceControl = xCol10 - xButtonSpacing
    var yRow4 = yRow3 + yButtonSpacing

    var wLabelFieldDeviceControl = 4 * wStrip
    var hLabelFieldDeviceControl = 0.75
    rightSide.labelFieldDeviceControl = surface.makeLabelField(xKnobsDeviceControl, yRow4, wLabelFieldDeviceControl, hLabelFieldDeviceControl)

    for (var knobIndex = 0; knobIndex < numRightSideKnobs; ++knobIndex) {
        var row = Math.floor(knobIndex / 4)
        var col = knobIndex % 4
        var xKnob = col * wStrip + xKnobsDeviceControl
        var yKnob = yRow4 + hLabelFieldDeviceControl + row * hKnob

        var dcKnob = surface.makeKnob(xKnob, yKnob, wStrip, hKnob)

        dcKnob.mSurfaceValue.mMidiBinding
            .setInputPort(midiInput).setOutputPort(midiOutput)
            .bindToControlChange(midiChannel, 16 + knobIndex)

        rightSide.deviceControlKnobs.push(dcKnob)
        rightSide.labelFieldDeviceControl.relateTo(dcKnob)
    }

    // ---- create buttons from "device (1)" to "Detail View" ----
    rightSide.elementsRight = []
    var numelementsRightSide = 8

    var yRow6 = yRow4 + hLabelFieldDeviceControl + 2.2 * hKnob

    for (var buttonIndex = 0; buttonIndex < numelementsRightSide; ++buttonIndex) {
        var row = Math.floor(buttonIndex / 4)
        var col = buttonIndex % 4

        var xButton = col * wStrip + xCol10
        var yButton = yRow6 + (row * yButtonSpacing)

        var button = surface.makeButton(xButton, yButton, wButton, hButton)

        button.mSurfaceValue.mMidiBinding
            .setInputPort(midiInput).setOutputPort(midiOutput)
            .bindToNote(midiChannel, 0x3A + buttonIndex)

        rightSide.elementsRight.push(button)
    }

    // ---- shift and bank button ----

    var yRow8 = yRow6 + (2 * yButtonSpacing)
    rightSide.shiftButton = surface.makeButton(xCol12, yRow8, wButton, hButton)
    rightSide.shiftButton.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannel, 0x62)

    rightSide.bankButton = surface.makeButton(xCol13, yRow8, wButton, hButton)
    rightSide.bankButton.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannel, 0x67)

    // ---- Bank Select ---
    var wBankSelect = wButton
    var hBankSelectLeftRight = 1.5 * hPad
    var hBankSelectUpDown = hBankSelectLeftRight / 2

    var wBankSelectButtons = wStrip + wButton - 0.75
    var wBankSelectSideButton = wBankSelect / 2 + 0.2
    var wBankSelectUpDownButton = wBankSelectButtons - 2 * wBankSelectSideButton

    var xBankSelect = xCol10
    rightSide.leftButton = surface.makeButton(xBankSelect, yRow8, wBankSelectSideButton, hBankSelectLeftRight)
    rightSide.leftButton.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannel, 0x61)
    xBankSelect += wBankSelectSideButton

    rightSide.upButton = surface.makeButton(xBankSelect, yRow8, wBankSelectUpDownButton, hBankSelectUpDown)
    rightSide.upButton.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannel, 0x5E)

    rightSide.downButton = surface.makeButton(xBankSelect, yRow8 + hBankSelectUpDown, wBankSelectUpDownButton, hBankSelectUpDown)
    rightSide.downButton.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannel, 0x5F)
    xBankSelect = xBankSelect + wBankSelectUpDownButton

    rightSide.rightButton = surface.makeButton(xBankSelect, yRow8, wBankSelectSideButton, hBankSelectLeftRight)
    rightSide.rightButton.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(midiChannel, 0x60)

    // ---- AB Crossfader ----
    var wABFader = wPadSmall * 2
    var xABFader = xCol12 + wButton / 2 - wABFader / 2
    var hABFader = wStrip
    var yABFader = hLabelFieldKnobs + hKnob + 9 * hPad + 2 * mediumElementSpacing + hFader - hABFader

    rightSide.faderAB = surface.makeFader(xABFader, yABFader, wABFader, hABFader).setTypeHorizontal()
    rightSide.faderAB.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(midiChannel, 15)

    return rightSide
}

// ### create surface elements ###
function makeSurfaceElements(x, y) {
    var surfaceElements = {}

    surfaceElements.elementStrips = makeElementStrips(x, y)

    var xLaunchPadStrip = x + wStrip * numStrips
    var yLaunchPadStrip = y + hLabelFieldKnobs + hKnob
    surfaceElements.sceneLaunchPadStrips = makeSceneLaunchPadStrip(xLaunchPadStrip, yLaunchPadStrip)

    var yLaunchPadStopAllClips = yLaunchPadStrip + numSceneLaunchPads * hPad + mediumElementSpacing
    surfaceElements.sceneLaunchPadStopAllClips = makeSceneLaunchPadStopAllClips(xLaunchPadStrip, yLaunchPadStopAllClips)

    var yLaunchPadMaster = yLaunchPadStopAllClips + hPad + mediumElementSpacing
    surface.makeBlindPanel(xLaunchPadStrip, yLaunchPadMaster, wPadSmall, hPad)

    var yCueLevelKnob = yLaunchPadMaster + hPad
    var hCueLevelKnob = sizeSmallQuadPads * 2
    surfaceElements.cueLevelKnob = surface.makeKnob(xLaunchPadStrip, yCueLevelKnob, wPadSmall, hCueLevelKnob)
    surfaceElements.cueLevelKnob.mSurfaceValue.mMidiBinding
        .setInputPort(midiInput)
        .bindToControlChange(midiChannel, 47)
        .setTypeRelativeTwosComplement()

    var yMasterFader = yCueLevelKnob + hCueLevelKnob
    surfaceElements.masterFader = surface.makeFader(xLaunchPadStrip, yMasterFader, wPadSmall, hFader)
    surfaceElements.masterFader.mSurfaceValue.mMidiBinding
        .setInputPort(midiInput)
        .bindToControlChange(midiChannel, 14)

    var yLabelMasterFader = yMasterFader + hFader
    var labelMainFader = surface.makeLabelField(xLaunchPadStrip, yLabelMasterFader, wFader, 1)
    labelMainFader.relateTo(surfaceElements.masterFader)

    var xRightSide = xLaunchPadStrip + wPadSmall + mediumElementSpacing * 2
    surfaceElements.rightSide = makeRightSide(xRightSide, 0.5)

    return surfaceElements
}

var surfaceElements = makeSurfaceElements(0, 0)
var elementsRight = surfaceElements.rightSide

//-----------------------------------------------------------------------------
// 3. HOST MAPPING - create mapping pages and host bindings
//-----------------------------------------------------------------------------

// create mapping page
var page = deviceDriver.mMapping.makePage('Default')

// create host accessing objects
var hostTrackSelection = page.mHostAccess.mTrackSelection

var mainOutputChannel = page.mHostAccess.mMixConsole.makeMixerBankZone('Stereo Out')
    .includeOutputChannels()
    .makeMixerBankChannel()

var hostMixerBankZone = page.mHostAccess.mMixConsole.makeMixerBankZone()
    .excludeInputChannels()
    .excludeOutputChannels()

// sub page setup for shift mode
var subPageAreaFunctionMode = page.makeSubPageArea('Function Mode')
var subPageFuncMain = subPageAreaFunctionMode.makeSubPage('Main')
var subPageFuncShift = subPageAreaFunctionMode.makeSubPage('Shift')

page.makeActionBinding(elementsRight.shiftButton.mSurfaceValue, subPageFuncShift.mAction.mActivate)
    .setSubPage(subPageFuncMain)

page.makeActionBinding(elementsRight.shiftButton.mSurfaceValue, subPageFuncMain.mAction.mActivate)
    .mapToValueRange(1, 0)
    .setSubPage(subPageFuncShift)

// sub page setup for mixer knobs - top left
var subPageAreaMixerKnobs = page.makeSubPageArea('Mixer Knobs')

var subPageSendList = []
var numSends = 8
for (var sendIndex = 0; sendIndex < numSends; ++sendIndex) {
    var subPageSendLevel = subPageAreaMixerKnobs.makeSubPage('Send Level ' + (sendIndex + 1).toString())
    subPageSendList.push(subPageSendLevel)
}

var subPagePan = subPageAreaMixerKnobs.makeSubPage('Pan')
page.setLabelFieldSubPageArea(labelKnobs, subPageAreaMixerKnobs)
page.makeActionBinding(elementsRight.panButton.mSurfaceValue, subPagePan.mAction.mActivate)
page.makeActionBinding(elementsRight.sendsButton.mSurfaceValue, subPageSendList[0].mAction.mActivate).setSubPage(subPagePan)

for (var sendIndex = 0; sendIndex < numSends; ++sendIndex)
    page.makeActionBinding(elementsRight.sendsButton.mSurfaceValue, subPageSendList[(sendIndex + 1) % numSends].mAction.mActivate).setSubPage(subPageSendList[sendIndex])

// host function bindings - mixer knobs, faders, small pads
var numStrips = 8

for (var stripIndex = 0; stripIndex < numStrips; ++stripIndex) {

    var strip = surfaceElements.elementStrips[stripIndex]
    var mixerBankChannel = hostMixerBankZone.makeMixerBankChannel()

    for (var sendIndex = 0; sendIndex < numSends; ++sendIndex) {
        var sendLevel = mixerBankChannel.mSends.getByIndex(sendIndex).mLevel
        var subPageSend = subPageSendList[sendIndex]
        page.makeValueBinding(strip.knob.mSurfaceValue, sendLevel).setSubPage(subPageSend)
    }

    page.makeValueBinding(strip.knob.mSurfaceValue, mixerBankChannel.mValue.mPan).setSubPage(subPagePan)
    page.makeValueBinding(strip.fader.mSurfaceValue, mixerBankChannel.mValue.mVolume).setValueTakeOverModeScaled()

    page.makeValueBinding(strip.smallNumPad.mSurfaceValue, mixerBankChannel.mValue.mSelected).setTypeToggle()
    page.makeValueBinding(strip.ABPad.mSurfaceValue, mixerBankChannel.mValue.mMute).setTypeToggle()
    page.makeValueBinding(strip.sPad.mSurfaceValue, mixerBankChannel.mValue.mSolo).setTypeToggle()
    page.makeValueBinding(strip.recEnablePad.mSurfaceValue, mixerBankChannel.mValue.mRecordEnable).setTypeToggle()
}

// host function binding - main volume output
page.makeValueBinding(surfaceElements.masterFader.mSurfaceValue, mainOutputChannel.mValue.mVolume)

// host function bindings - device driver knobs
var numKnobs = 8
for (var knobIndex = 0; knobIndex < numKnobs; ++knobIndex) {
    var knobQC = surfaceElements.rightSide.deviceControlKnobs[knobIndex]
    var focusQuickControl = page.mHostAccess.mFocusedQuickControls.getByIndex(knobIndex)
    page.makeValueBinding(knobQC.mSurfaceValue, focusQuickControl)
}

// host function bindings - bank select
page.makeActionBinding(elementsRight.leftButton.mSurfaceValue, hostMixerBankZone.mAction.mPrevBank).setSubPage(subPageFuncMain)
page.makeActionBinding(elementsRight.rightButton.mSurfaceValue, hostMixerBankZone.mAction.mNextBank).setSubPage(subPageFuncMain)
page.makeActionBinding(elementsRight.upButton.mSurfaceValue, hostTrackSelection.mAction.mPrevTrack).setSubPage(subPageFuncMain)
page.makeActionBinding(elementsRight.downButton.mSurfaceValue, hostTrackSelection.mAction.mNextTrack).setSubPage(subPageFuncMain)

page.makeCommandBinding(elementsRight.leftButton.mSurfaceValue, 'Navigate', 'Left').setSubPage(subPageFuncShift)
page.makeCommandBinding(elementsRight.rightButton.mSurfaceValue, 'Navigate', 'Right').setSubPage(subPageFuncShift)
page.makeCommandBinding(elementsRight.upButton.mSurfaceValue, 'Navigate', 'Up').setSubPage(subPageFuncShift)
page.makeCommandBinding(elementsRight.downButton.mSurfaceValue, 'Navigate', 'Down').setSubPage(subPageFuncShift)

// host function bindings - transports
page.makeValueBinding(elementsRight.playButton.mSurfaceValue, page.mHostAccess.mTransport.mValue.mStart).setTypeToggle().setSubPage(subPageFuncMain)
page.makeValueBinding(elementsRight.playButton.mSurfaceValue, page.mHostAccess.mTransport.mValue.mRewind).setTypeToggle().setSubPage(subPageFuncShift)
page.makeValueBinding(elementsRight.recordButton.mSurfaceValue, page.mHostAccess.mTransport.mValue.mRecord).setTypeToggle().setSubPage(subPageFuncMain)
page.makeValueBinding(elementsRight.recordButton.mSurfaceValue, page.mHostAccess.mTransport.mValue.mForward).setTypeToggle().setSubPage(subPageFuncShift)
page.makeCommandBinding(elementsRight.sessionButton.mSurfaceValue, 'Automation', 'Toggle Write Enable All Tracks').setSubPage(subPageFuncMain)
page.makeCommandBinding(elementsRight.sessionButton.mSurfaceValue, 'Automation', 'Toggle Write Enable Selected Tracks').setSubPage(subPageFuncShift)
page.makeValueBinding(elementsRight.metronomeButton.mSurfaceValue, page.mHostAccess.mTransport.mValue.mMetronomeActive).setTypeToggle().setSubPage(subPageFuncMain)
page.makeValueBinding(elementsRight.metronomeButton.mSurfaceValue, page.mHostAccess.mTransport.mValue.mCycleActive).setTypeToggle().setSubPage(subPageFuncShift)
