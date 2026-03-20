//-----------------------------------------------------------------------------
// Cubase / Nuendo 12+ Integration for EMP-16
// written by Heaven Jie in 2023
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// 1. DRIVER SETUP - create driver object, midi ports and detection information
//-----------------------------------------------------------------------------

// get the api's entry point
var midiremote_api = require('midiremote_api_v1');

// create the device driver main object
var deviceDriver = midiremote_api.makeDeviceDriver(
  'Avatar',
  'EMP-16',
  'HXW Technology Co., Ltd'
);

// create objects representing the hardware's MIDI ports
var midiInput = deviceDriver.mPorts.makeMidiInput();
var midiOutput = deviceDriver.mPorts.makeMidiOutput();


// Windows
deviceDriver
  .makeDetectionUnit()
  .detectPortPair(midiInput, midiOutput)
  .expectInputNameContains('EMP-16')
  .expectInputNameContains('MIDIIN')
  .expectOutputNameContains('EMP-16')
  .expectOutputNameContains('MIDIOUT')
 

// Windows RT
deviceDriver
  .makeDetectionUnit()
  .detectPortPair(midiInput, midiOutput)
  .expectInputNameContains('MIDI PAD-01')
  .expectInputNameContains('Port 2')
  .expectOutputNameContains('MIDI PAD-01')
  .expectOutputNameContains('Port 2')
 

// Mac (has individual names for devices, so no identity response is needed)
deviceDriver
  .makeDetectionUnit()
  .detectPortPair(midiInput, midiOutput)
  .expectInputNameEquals('EMP-16')
  .expectOutputNameEquals('EMP-16');

deviceDriver.mOnActivate = function (activeDevice) {
	// set DAW mode
	midiOutput.sendMidi(activeDevice, [0x9f, 0x00, 0x7f]);
	midiOutput.sendMidi(activeDevice, [0xbf, 0x0e, 0x00]);
	midiOutput.sendMidi(activeDevice, [0xbf, 0x0f, 0x01]);
}

deviceDriver.setUserGuide("avatar_emp_16.pdf");

var surface = deviceDriver.mSurface
//-------------------------------------------------------------------
// surface layout - create control elements and midi bingdings
//-------------------------------------------------------------------
var knobControlLayerZone = surface.makeControlLayerZone('Control Bank')
var knobcontrolLayerControlBankA = knobControlLayerZone.makeControlLayer('Control Bank A')
var knobcontrolLayerControlBankB = knobControlLayerZone.makeControlLayer('Control Bank B')
var knobcontrolLayerControlBankC = knobControlLayerZone.makeControlLayer('Control Bank C')

var padControlLayerZone = surface.makeControlLayerZone('Control Bank')
var padcontrolLayerControlBankA = padControlLayerZone.makeControlLayer('Control Bank A')
var padcontrolLayerControlBankB = padControlLayerZone.makeControlLayer('Control Bank B')
var padcontrolLayerControlBankC = padControlLayerZone.makeControlLayer('Control Bank C')
var padcontrolLayerControlBankD = padControlLayerZone.makeControlLayer('Control Bank D')

function makeKnobStrip(knobIndex, x, y, ccNrA, ccNrB, ccNrC) {
    var knobStrip = {}
    knobStrip.knobA = surface.makeKnob(x * knobIndex + 0.5, y, 1.8, 1.8).setControlLayer(knobcontrolLayerControlBankA)
    knobStrip.knobA.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(9, ccNrA).setValueRange(0,127)//setTypeRelativeTwosComplement()//setValueRange(0,127)
    knobStrip.knobB = surface.makeKnob(x * knobIndex + 0.5, y, 1.8, 1.8).setControlLayer(knobcontrolLayerControlBankB)
    knobStrip.knobB.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(9, ccNrB).setValueRange(0,127)
    knobStrip.knobC = surface.makeKnob(x * knobIndex + 0.5, y, 1.8, 1.8).setControlLayer(knobcontrolLayerControlBankC)
    knobStrip.knobC.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(9, ccNrC).setValueRange(0,127)

    return knobStrip
}



function makeTriggerPads(padIndex, width, y, ccNrA, ccNrB, ccNrC, ccNrD) {
    var triggerPads = {}

    triggerPads.padA = surface.makeTriggerPad(width * padIndex + 9, y, width, width).setControlLayer(padcontrolLayerControlBankA)
    triggerPads.padA.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToNote(9, ccNrA)
    triggerPads.padB = surface.makeTriggerPad(width * padIndex + 9, y, width, width).setControlLayer(padcontrolLayerControlBankB)
    triggerPads.padB.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToNote(9, ccNrB)
    triggerPads.padC = surface.makeTriggerPad(width * padIndex + 9, y, width, width).setControlLayer(padcontrolLayerControlBankC)
    triggerPads.padC.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToNote(9, ccNrC)
    triggerPads.padD = surface.makeTriggerPad(width * padIndex + 9, y, width, width).setControlLayer(padcontrolLayerControlBankD)
    triggerPads.padD.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToNote(9, ccNrD)

    return triggerPads
}

function makeTapeButtons(buttonInde, x, y, ccNr) {
    var tapeButtons = {}

    tapeButtons.button = surface.makeButton(x , y * buttonInde + 6.8, 1.2, 0.8)
    tapeButtons.button.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToControlChange(9, ccNr)

    return tapeButtons
}

// make six buttons in the upper right
function makeCommButtons(buttonInde, x, y) {
    var commButtons = {}
    commButtons.button = surface.makeButton(x * buttonInde + 9.7, y, 1.2, 0.8)
    return commButtons
}

var faders = []
var numFaders = 4

for(var FadersIndex = 0; FadersIndex < numFaders; ++FadersIndex) {
    var fader = deviceDriver.mSurface.makeFader(1.6+FadersIndex * 1.6 , 6.8, 1.2, 4.6)
    fader.mSurfaceValue.mMidiBinding
        .setInputPort(midiInput).setOutputPort(midiOutput)
        .bindToControlChange (9, 12 + FadersIndex)
    faders.push(fader)
}

function makeSurfaceElements() {
    var surfaceElements = {}

    surfaceElements.knobnumStrips = 4
    surfaceElements.padnumStrips = 16
    surfaceElements.buttonnumStrips = 5
    surfaceElements.commButtonsnumStrips = 6
    
    surfaceElements.knobStrip = {}

    var x = 1.9
    var y = 0.5
    for (var i = 0; i < surfaceElements.knobnumStrips; ++i) {
        var knobIndex = i
        var ccNrA = i + 70
        var ccNrB = i + 74
        var ccNrC = i + 78
        surfaceElements.knobStrip[i] = makeKnobStrip(knobIndex, x, y, ccNrA, ccNrB, ccNrC)
    
    }

    surfaceElements.triggerPads = {}
    var width = 2.25
    var y = 8.65
    for(var i = 0; i < surfaceElements.padnumStrips; ++i) {
        var padIndex = i
       // var Nr = [36,37,38,39,40,41,42,43,44,45,46,]
        if (i > 3) {
            padIndex = i - 4
            y = 6.35
            if ( i > 7) {
                padIndex = i - 8
                y = 4.05
                if (i > 11) {
                    padIndex = i -12
                    y = 1.75
                }
            }
        }
        var ccNrA = 36 + i
        var ccNrB = 52 + i
        var ccNrC = 68 + i
        var ccNrD = 20 + i
        surfaceElements.triggerPads[i] = makeTriggerPads(padIndex, width, y, ccNrA, ccNrB, ccNrC, ccNrD)
    }

    surfaceElements.tapeButtons = {}
    x = 0.2
    y = 0.8
    for (var i = 0; i < surfaceElements.buttonnumStrips; ++i) {
        var buttonInde = i
        var ccNr = i + 59
        surfaceElements.tapeButtons[i] = makeTapeButtons(buttonInde, x, y, ccNr)
    }

    
    surfaceElements.commButtons = {}
    x = 1.5
    y = 0.7
    for (var i = 0; i < surfaceElements.commButtonsnumStrips; ++i) {
        var buttonInde = i
        surfaceElements.commButtons[i] = makeCommButtons(buttonInde, x, y)
    }

    // Ordinary bottons
    surface.makeBlindPanel(2.5, 2.8, 2.4, 1.6) //screen
    surface.makeBlindPanel(0.5, 2.9, 1.4, 1.4).setShapeCircle()
    surface.makeBlindPanel(5.4, 3.0, 1.1, 1.1)//.setShapeCircle()
    surface.makeBlindPanel(6.8, 3.0, 1.1, 1.1)//.setShapeCircle()

    surface.makeBlindPanel(3.6, 4.6, 1.2, 0.8)
    surface.makeBlindPanel(4.8, 4.6, 1.2, 0.8)
    surface.makeBlindPanel(6.0, 4.6, 1.2, 0.8)
    surface.makeBlindPanel(3.6, 5.5, 1.2, 0.8)
    surface.makeBlindPanel(4.8, 5.5, 1.2, 0.8)
    surface.makeBlindPanel(6.0, 5.5, 1.2, 0.8)

    surface.makeBlindPanel(1.2, 4.6, 1.2, 0.8)
    surface.makeBlindPanel(1.2, 5.5, 1.2, 0.8)
    surface.makeBlindPanel(0.4, 4.78, 0.8, 1.2)
    surface.makeBlindPanel(2.4, 4.78, 0.8, 1.2)

    return surfaceElements    
}

var surfaceElements = makeSurfaceElements()

//-----------------------------------------------------------------------------
// 3. HOST MAPPING - create mapping pages and host bindings
//-----------------------------------------------------------------------------

var page = deviceDriver.mMapping.makePage('Mixer Page')

var hostMixerBankZone = page.mHostAccess.mMixConsole.makeMixerBankZone()
    .excludeInputChannels()
    .excludeOutputChannels()

for(var FadersIndex = 0; FadersIndex < numFaders; ++FadersIndex) {
    var hostMixerBankChannel = hostMixerBankZone.makeMixerBankChannel()  
    var faderSurfaceValue = faders[FadersIndex].mSurfaceValue;      
    page.makeValueBinding(faderSurfaceValue, hostMixerBankChannel.mValue.mVolume)
}

for (var i = 0; i < 4; ++i) {
    page.makeValueBinding(surfaceElements.knobStrip[i].knobA.mSurfaceValue, page.mHostAccess.mFocusedQuickControls.getByIndex(i)).setValueTakeOverModeJump()
    page.makeValueBinding(surfaceElements.knobStrip[i].knobB.mSurfaceValue, page.mHostAccess.mFocusedQuickControls.getByIndex(i + 4)).setValueTakeOverModeJump()
}

page.makeValueBinding(surfaceElements.knobStrip[0].knobC.mSurfaceValue,  page.mHostAccess.mTrackSelection.mMixerChannel.mPreFilter.mHighCutFreq).setValueTakeOverModeJump()
page.makeValueBinding(surfaceElements.knobStrip[1].knobC.mSurfaceValue,  page.mHostAccess.mTrackSelection.mMixerChannel.mPreFilter.mLowCutFreq).setValueTakeOverModeJump()
page.makeValueBinding(surfaceElements.knobStrip[2].knobC.mSurfaceValue,  page.mHostAccess.mTrackSelection.mMixerChannel.mPreFilter.mGain).setValueTakeOverModeJump()
page.makeValueBinding(surfaceElements.knobStrip[3].knobC.mSurfaceValue,  page.mHostAccess.mTrackSelection.mMixerChannel.mPreFilter.mLowCutSlope).setValueTakeOverModeJump()

page.makeValueBinding(surfaceElements.tapeButtons[0].button.mSurfaceValue, page.mHostAccess.mTransport.mValue.mStart).setTypeDefault()
page.makeValueBinding(surfaceElements.tapeButtons[1].button.mSurfaceValue, page.mHostAccess.mTransport.mValue.mRecord).setTypeDefault()
page.makeValueBinding(surfaceElements.tapeButtons[2].button.mSurfaceValue, page.mHostAccess.mTransport.mValue.mCycleActive).setTypeDefault()
page.makeValueBinding(surfaceElements.tapeButtons[3].button.mSurfaceValue, page.mHostAccess.mTransport.mValue.mForward).setTypeDefault()
page.makeValueBinding(surfaceElements.tapeButtons[4].button.mSurfaceValue, page.mHostAccess.mTransport.mValue.mRewind).setTypeDefault()
