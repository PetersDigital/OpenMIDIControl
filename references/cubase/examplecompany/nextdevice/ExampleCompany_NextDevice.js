//-----------------------------------------------------------------------------
// 1. DRIVER SETUP - create driver object, midi ports and detection information
//-----------------------------------------------------------------------------

// 1. get the api's entry point
var midiremote_api = require('midiremote_api_v1')

// 2. create the device driver main object
var deviceDriver = midiremote_api.makeDeviceDriver('ExampleCompany', 'NextDevice', 'Steinberg Media Technologies GmbH')

// 3. create objects representing the hardware's MIDI ports
var midiInput = deviceDriver.mPorts.makeMidiInput()
var midiOutput = deviceDriver.mPorts.makeMidiOutput()

// 4. define all possible namings the devices MIDI ports could have
// NOTE: Windows and MacOS handle port naming differently
deviceDriver.makeDetectionUnit().detectPortPair(midiInput, midiOutput)
    .expectInputNameEquals('NextDevice IN')
    .expectOutputNameEquals('NextDevice OUT')
    
deviceDriver.makeDetectionUnit().detectPortPair(midiInput, midiOutput)
    .expectInputNameEquals('NextDevice (MIDI IN)')
    .expectOutputNameEquals('NextDevice (MIDI OUT)')


//-----------------------------------------------------------------------------
// 2. SURFACE LAYOUT - create control elements and midi bindings
//-----------------------------------------------------------------------------

var knobs = []
var faders = []
var buttons = []

var numChannels = 8

for(var channelIndex = 0; channelIndex < numChannels; ++channelIndex) {
    
    var knob = deviceDriver.mSurface.makeKnob(channelIndex * 2, 0, 2, 2)
    
    knob.mSurfaceValue.mMidiBinding
        .setInputPort(midiInput).setOutputPort(midiOutput)
        .bindToControlChange (0, 21 + channelIndex)
    
    knobs.push(knob)

    var fader = deviceDriver.mSurface.makeFader(channelIndex * 2 + 0.5, 2, 1, 6)
    
    fader.mSurfaceValue.mMidiBinding
        .setInputPort(midiInput).setOutputPort(midiOutput)
        .bindToControlChange (0, 29 + channelIndex)

    faders.push(fader)

    var button = deviceDriver.mSurface.makeButton(channelIndex * 2, 8, 2, 1)

    button.mSurfaceValue.mMidiBinding
        .setInputPort(midiInput).setOutputPort(midiOutput)
        .bindToControlChange (0, 37 + channelIndex)

    buttons.push(button)
}

//-----------------------------------------------------------------------------
// 3. HOST MAPPING - create mapping pages and host bindings
//-----------------------------------------------------------------------------

var page = deviceDriver.mMapping.makePage('Example Mixer Page')

var hostMixerBankZone = page.mHostAccess.mMixConsole.makeMixerBankZone()
    .excludeInputChannels()
    .excludeOutputChannels()

for(var channelIndex = 0; channelIndex < numChannels; ++channelIndex) {
    var hostMixerBankChannel = hostMixerBankZone.makeMixerBankChannel()

    var knobSurfaceValue = knobs[channelIndex].mSurfaceValue;
    var faderSurfaceValue = faders[channelIndex].mSurfaceValue;
    var buttonSurfaceValue = buttons[channelIndex].mSurfaceValue;

    page.makeValueBinding(knobSurfaceValue, hostMixerBankChannel.mValue.mPan)
    page.makeValueBinding(faderSurfaceValue, hostMixerBankChannel.mValue.mVolume)
    page.makeValueBinding(buttonSurfaceValue, hostMixerBankChannel.mValue.mSelected)
}
