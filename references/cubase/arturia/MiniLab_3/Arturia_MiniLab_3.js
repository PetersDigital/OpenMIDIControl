//-----------------------------------------------------------------------------
// 1. DRIVER SETUP - create driver object, midi ports and detection information
//-----------------------------------------------------------------------------

// get the api's entry point
var midiremote_api = require('midiremote_api_v1')

var MiniLab_3_Basis = require('./MiniLab_3_Process')

// Create the device driver main object
var deviceDriver = midiremote_api.makeDeviceDriver('Arturia', 'MiniLab 3', 'Arturia')

// Create objects representing the hardware's MIDI ports
var midiInput = deviceDriver.mPorts.makeMidiInput()
var midiOutput = deviceDriver.mPorts.makeMidiOutput()




// Define all possible namings the devices MIDI ports could have
// WINDOWSOS and MACOS handle port name differently
deviceDriver.makeDetectionUnit().detectPortPair(midiInput,midiOutput)
    //.expectInputNameEquals('Minilab3 MIDI')
    //.expectOutputNameEquals('Minilab3 MIDI')
    .expectSysexIdentityResponse('00206B','0200','0404')


var surface = deviceDriver.mSurface


//-----------------------------------------------------------------------------
// 2. SURFACE LAYOUT - create control elements and midi bindings
//-----------------------------------------------------------------------------




function makeSurfaceElements() {
    var surfaceElements = {}

    MiniLab_3_Basis.makeModWheels(surface, 0, 7, 3, 10)
    MiniLab_3_Basis.makeFunctionButtons(surface, 0, 1)
    MiniLab_3_Basis.makePads(surface, 12, 12, 5, 5, midiInput, midiOutput, surfaceElements)
    // MiniLab_3_Basis.makeTransport(surface, 40, 0, midiInput, midiOutput, surfaceElements)
    MiniLab_3_Basis.makeDisplaySection(surface, 12, 0, midiInput, midiOutput, surfaceElements)
    // MiniLab_3_Basis.makeChannelStrip(surface, 85, 0, 9, midiInput, midiOutput, surfaceElements)
    MiniLab_3_Basis.makeKnobs(surface, 18, 1, 8, midiInput, midiOutput, surfaceElements)
    MiniLab_3_Basis.makeFaders(surface, 43, 0, 4, midiInput, midiOutput, surfaceElements)
    surfaceElements.pianoKeys = surface.makePianoKeys(0, 18, 60, 15, 0, 24)

    return surfaceElements
}

var surfaceElements = makeSurfaceElements()
MiniLab_3_Basis.deviceSetup(deviceDriver, midiOutput, midiInput)



// //-----------------------------------------------------------------------------
// // 3. HOST MAPPING - create mapping pages and host bindings
// //-----------------------------------------------------------------------------
MiniLab_3_Basis.makeHostMapping(midiremote_api.mDefaults, deviceDriver, surfaceElements, surface, midiOutput)


// //----------------------------------------------------------------------------------------------------------------------
// // 4. Feedback to the HW controller
// //----------------------------------------------------------------------------------------------------------------------
MiniLab_3_Basis.makeSurfaceFeedback(surfaceElements, midiOutput)
MiniLab_3_Basis.MIDIDetection(midiInput, surface)