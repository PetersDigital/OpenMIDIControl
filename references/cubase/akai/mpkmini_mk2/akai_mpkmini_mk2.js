//-----------------------------------------------------------------------------
// 1. DRIVER SETUP - create driver object, midi ports and detection information
//-----------------------------------------------------------------------------

var midiremote_api = require('midiremote_api_v1')
var deviceDriver = midiremote_api.makeDeviceDriver('Akai', 'MPK mini mk2', 'Steinberg Media Technology GmbH')

var midiInput = deviceDriver.mPorts.makeMidiInput();
var midiOutput = deviceDriver.mPorts.makeMidiOutput();

// SySEx-ID-Response 
// [ F0 7E 7F 06 02 47 26 00 
//   19 00 22 00 22 00 00 00 
//   00 00 00 00 04 00 00 00
//   03 01 00 00 30 31 32 33
//   2C F7]

// Detection for WIN, WinRT and MAC
deviceDriver.makeDetectionUnit().detectPortPair(midiInput, midiOutput)
    .expectSysexIdentityResponse('47', '2600', '1900')

deviceDriver.mOnActivate = function (activeDevice) {
    midiOutput.sendSysexFile(activeDevice, 'akai_mpkmini_mk2.syx', 7)
}

deviceDriver.setUserGuide('akai_mpkmini_mk2.pdf')

var surface = deviceDriver.mSurface

//----------------------------------------------------------------------------------------------------------------------
// 2. SURFACE LAYOUT - create control elements and midi bindings
//----------------------------------------------------------------------------------------------------------------------

function Helper_getInnerCoordCentered(sizeOuter, sizeInner) {
    return (sizeOuter / 2 - sizeInner / 2)
}

var controlsMidiChannel = 0
var padMidiChannel = 1

var xBlindPanel = 0
var xBlindPanel2 = xBlindPanel + 1.2
var yBlindPanel = 1.8
var wBlindPanel = 1.1
var hBlindPanel = 0.7

var xBlindPanelRightSide = 11.1

var xFirstPad = xBlindPanel2 + wBlindPanel + 0.4
var yPad = 0
var padSize = 1.9

var wKnob = 1.7
var hKnob = 1.5
var xFirstKnob = 10.8

var joyStickSize = 1.75
var xJoystick = Helper_getInnerCoordCentered(xBlindPanel2 + wBlindPanel, joyStickSize)

// joystick for x- and y-axis
var joyStickXY = surface.makeJoyStickXY(xJoystick, 0, joyStickSize, joyStickSize);
joyStickXY.mX.mMidiBinding.setInputPort(midiInput).bindToPitchBend(controlsMidiChannel);
joyStickXY.mY.mMidiBinding.setInputPort(midiInput).bindToControlChange(controlsMidiChannel, 1);

// blind panels left side - ON/OFF - NOTE REPEAT
surface.makeBlindPanel(xBlindPanel, yBlindPanel, wBlindPanel, hBlindPanel) 
surface.makeBlindPanel(xBlindPanel2, yBlindPanel, wBlindPanel, hBlindPanel) 
yBlindPanel += 0.7

surface.makeBlindPanel(xBlindPanel, yBlindPanel, wBlindPanel, hBlindPanel)
surface.makeBlindPanel(xBlindPanel2, yBlindPanel, wBlindPanel, hBlindPanel)
yBlindPanel += 0.7

surface.makeBlindPanel(xBlindPanel, yBlindPanel, wBlindPanel, hBlindPanel)
surface.makeBlindPanel(xBlindPanel2, yBlindPanel, wBlindPanel, hBlindPanel)

// blind panels right side - BANK A/B - PROG SELECT
surface.makeBlindPanel(xBlindPanelRightSide, yBlindPanel, wBlindPanel, hBlindPanel)
xBlindPanelRightSide += 1.3

surface.makeBlindPanel(xBlindPanelRightSide, yBlindPanel, wBlindPanel, hBlindPanel)
xBlindPanelRightSide += 1.3

surface.makeBlindPanel(xBlindPanelRightSide, yBlindPanel, wBlindPanel, hBlindPanel)
xBlindPanelRightSide += 1.7

surface.makeBlindPanel(xBlindPanelRightSide, yBlindPanel, wBlindPanel, hBlindPanel)

// create trigger pads and knobs
var pads = []
var knobs = []
var numElements = 8

var firstPadNotePitchBankA = 0X2C
var firstPadNotePitchBankB = 0X20
var firstPadCCBankACC = 10
var firstPadCCBankBCC = 18

var firstKnobCC = 2

// create control layer zones for a shifting-combination of modes A/B + CC
var padLayerZone = surface.makeControlLayerZone('Pads')
var padControlLayerA = padLayerZone.makeControlLayer('Bank A')
var padControlLayerB = padLayerZone.makeControlLayer('Bank B')
var padControlLayerACC = padLayerZone.makeControlLayer('Bank A + CC')
var padControlLayerBCC = padLayerZone.makeControlLayer('Bank B + CC')

for (var i = 0; i < numElements; ++i) {

    var row = Math.floor(i / 4)
    var col = i % 4

    var xPads = col * 2 + xFirstPad
    var yPads = row * 2 + yPad
    
    var xKnobs = col * 1.7 + xFirstKnob
    var yKnobs = row * 1.6

    // create pads for Bank A note ON/OFF (green)
    var padOfBankA = surface.makeTriggerPad(xPads, yPads, padSize, padSize).setControlLayer(padControlLayerA)
    padOfBankA.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(padMidiChannel, firstPadNotePitchBankA + i)

    // create pads for Bank B note ON/OFF (red)
    var padOfBankB = surface.makeTriggerPad(xPads, yPads, padSize, padSize).setControlLayer(padControlLayerB)
    padOfBankB.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToNote(padMidiChannel, firstPadNotePitchBankB + i)

    // create pads for Bank A (green) with CC pressed 
    var padOfBankACC = surface.makeTriggerPad(xPads, yPads, padSize, padSize).setControlLayer(padControlLayerACC)
    padOfBankACC.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToControlChange(padMidiChannel, firstPadCCBankACC + i)

    // create pads for Bank B (red) with CC pressed 
    var padOfBankBCC = surface.makeTriggerPad(xPads, yPads, padSize, padSize).setControlLayer(padControlLayerBCC)
    padOfBankBCC.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .setOutputPort(midiOutput)
        .bindToControlChange(padMidiChannel, firstPadCCBankBCC + i)

    // 4x2 Device Control Knobs - right side
    var knob = surface.makeKnob(xKnobs, yKnobs, wKnob, hKnob)
    knob.mSurfaceValue.mMidiBinding.setInputPort(midiInput)
        .bindToControlChange(controlsMidiChannel, firstKnobCC + i)
 
    pads.push(padOfBankA)
    pads.push(padOfBankB)
    pads.push(padOfBankACC)
    pads.push(padOfBankBCC)

    knobs.push(knob)
}

// piano keys
surface.makePianoKeys(0, 4.5, 17.5, 4.5, 0, 24)

//----------------------------------------------------------------------------------------------------------------------
// 3. HOST MAPPING - create mapping pages and host bindings
//----------------------------------------------------------------------------------------------------------------------

var page = deviceDriver.mMapping.makePage('Default')

knobs.forEach(function(knob, i) {
    var qcValue = page.mHostAccess.mFocusedQuickControls.getByIndex(i)
    page.makeValueBinding(knob.mSurfaceValue, qcValue)
})
