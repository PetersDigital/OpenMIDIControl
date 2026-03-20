
//-----------------------------------------------------------------------------
// 1. DRIVER SETUP - create driver object, midi ports and detection information
//-----------------------------------------------------------------------------

var midiremote_api = require('midiremote_api_v1')
var keyLabEssentialBasis = require('../keylab_essential_common')

var deviceDriver = midiremote_api.makeDeviceDriver('Arturia', 'KeyLab Essential 49', 'Steinberg Media Technologies GmbH')

var midiInputDAW = deviceDriver.mPorts.makeMidiInput()
var midiOutputDAW = deviceDriver.mPorts.makeMidiOutput()

keyLabEssentialBasis.makeActivationHandling(deviceDriver, midiOutputDAW)

var detectMacAndWinRT = deviceDriver.makeDetectionUnit()
detectMacAndWinRT.detectPortPair(midiInputDAW, midiOutputDAW)
    .expectInputNameContains('DAW')
    .expectOutputNameContains('DAW')
    .expectSysexIdentityResponse('00206B', '0200', '0552')

var detectWin = deviceDriver.makeDetectionUnit()
detectWin
    .detectPortPair(midiInputDAW, midiOutputDAW)
    .expectInputNameContains('MIDIIN2')
    .expectOutputNameContains('MIDIOUT2')
    .expectSysexIdentityResponse('00206B', '0200', '0552')

var surface = deviceDriver.mSurface

//-----------------------------------------------------------------------------
// 2. SURFACE LAYOUT - create control elements and midi bindings
//-----------------------------------------------------------------------------
keyLabEssentialBasis.makeModWheels(surface, 0.8, 17, 1.8, 6)
keyLabEssentialBasis.makeFunctionButtons(surface, 0.5, 10.5)
keyLabEssentialBasis.makeMidiMapButtons(surface, 7, 5)
keyLabEssentialBasis.makePads(surface, 11, 0, 3.5, 3.5)// Doesn't send any MIDI data????

function makeSurfaceElements() {
    var surfaceElements = {}

    keyLabEssentialBasis.makeDawCommandCenter(surface, 27, 0, midiInputDAW, midiOutputDAW, 0, 80, surfaceElements)
    keyLabEssentialBasis.makeTransport(surface, 27, 5, 2.5, 1.5, midiInputDAW, midiOutputDAW, surfaceElements)
    keyLabEssentialBasis.makeDisplaySection(surface, 37, 0, midiInputDAW, midiOutputDAW, 0, surfaceElements)
    keyLabEssentialBasis.makePagesSubpagesSwitchers(surface, 53, 0, midiInputDAW, midiOutputDAW, 0, 46, surfaceElements)
    keyLabEssentialBasis.makeChannelStrip(surface, 38, 0, 8, midiInputDAW, midiOutputDAW, surfaceElements)

    surfaceElements.pianoKeys = surface.makePianoKeys(7, 10, 81, 12, 0, 48)
    return surfaceElements
}

var surfaceElements = makeSurfaceElements()

//-----------------------------------------------------------------------------
// 3. HOST MAPPING - create mapping pages and host bindings
//-----------------------------------------------------------------------------
keyLabEssentialBasis.makeHostMapping(midiremote_api.mDefaults, deviceDriver, surfaceElements, surface, midiOutputDAW)
