
//-----------------------------------------------------------------------------
// 2. SURFACE LAYOUT - create control elements and midi bindings

//const { sysex } = require("Public/examplecompany/realworlddevice/helper")

//-----------------------------------------------------------------------------

var MiniLab_3_Connection = require('./MiniLab_3_Connection')
var MiniLab_3_LED = require('./MiniLab_3_LED')
var MiniLab_3_Pages = require('./MiniLab_3_Pages')
var MiniLab_3_Var = require('./MiniLab_3_Var')


// GLOBAL VARIABLE//

var g_knob_1_param = ""
var g_knob_2_param = ""
var g_knob_3_param = ""
var g_knob_4_param = ""
var g_knob_5_param = ""
var g_knob_6_param = ""
var g_knob_7_param = ""
var g_knob_8_param = ""

var g_fader_1_param = ""
var g_fader_2_param = ""
var g_fader_3_param = ""
var g_fader_4_param = ""

var g_knob_1_value = 0
var g_knob_2_value = 0
var g_knob_3_value = 0
var g_knob_4_value = 0
var g_knob_5_value = 0
var g_knob_6_value = 0
var g_knob_7_value = 0
var g_knob_8_value = 0

var g_fader_1_value = 0
var g_fader_2_value = 0
var g_fader_3_value = 0
var g_fader_4_value = 0

// HW values

var g_knob_1_hw_value = 0
var g_knob_2_hw_value = 0
var g_knob_3_hw_value = 0
var g_knob_4_hw_value = 0
var g_knob_5_hw_value = 0
var g_knob_6_hw_value = 0
var g_knob_7_hw_value = 0
var g_knob_8_hw_value = 0

var g_fader_1_hw_value = 0
var g_fader_2_hw_value = 0
var g_fader_3_hw_value = 0
var g_fader_4_hw_value = 0

//var TRACK_NAME = ""
//var g_timeline = ""
var g_timeline_is_displayed = false



var buttonsW = 3
var buttonsH = 2
var functOffset = 73

function makeModWheels(surface, x, y, w, h) {
	surface.makePitchBend(x + 2, y, w, h) // dummy pitch bend
	surface.makeModWheel(x + 6, y, w, h) // mod wheel

	//console.log("Mowheel created")
}

function makeFunctionButtons(surface, x, y) {
	surface.makeBlindPanel(x + 2, y, buttonsW, buttonsH) // Shift
	surface.makeBlindPanel(x + 2 + 4, y, buttonsW, buttonsH) // Hold
	surface.makeBlindPanel(x + 2, y + 3, buttonsW, buttonsH) // Oct-
	surface.makeBlindPanel(x + 2 + 4, y + 3, buttonsW, buttonsH) // Oct+


	//console.log("Buttons created")
}


function makePads(surface, x, y, w, h, midiInput, midiOutput, surfaceElements) {
    var transport = {}

	var PadBank = surface.makeControlLayerZone('Pad 1 Item')
	var BankA = PadBank.makeControlLayer('Bank_A')
	var BankB = PadBank.makeControlLayer('Bank_B')
	var BankT = PadBank.makeControlLayer('Bank_T')

	var Pad_bank = {
		zone: PadBank,
		Bank_A: {
			layer: BankA,
			pad1: surface.makeTriggerPad(x, y, w, h).setControlLayer(BankA),
			pad2: surface.makeTriggerPad(x + 6, y, w, h).setControlLayer(BankA),
			pad3: surface.makeTriggerPad(x + 12, y, w, h).setControlLayer(BankA),
			pad4: surface.makeTriggerPad(x + 18, y, w, h).setControlLayer(BankA),
			pad5: surface.makeTriggerPad(x + 24, y, w, h).setControlLayer(BankA),
			pad6: surface.makeTriggerPad(x + 30, y, w, h).setControlLayer(BankA),
			pad7: surface.makeTriggerPad(x + 36, y, w, h).setControlLayer(BankA),
			pad8: surface.makeTriggerPad(x + 42, y, w, h).setControlLayer(BankA),
		},
		Bank_B: {
			layer: BankB,
			pad1: surface.makeTriggerPad(x, y, w, h).setControlLayer(BankB),
			pad2: surface.makeTriggerPad(x + 6, y, w, h).setControlLayer(BankB),
			pad3: surface.makeTriggerPad(x + 12, y, w, h).setControlLayer(BankB),
			pad4: surface.makeTriggerPad(x + 18, y, w, h).setControlLayer(BankB),
			pad5: surface.makeTriggerPad(x + 24, y, w, h).setControlLayer(BankB),
			pad6: surface.makeTriggerPad(x + 30, y, w, h).setControlLayer(BankB),
			pad7: surface.makeTriggerPad(x + 36, y, w, h).setControlLayer(BankB),
			pad8: surface.makeTriggerPad(x + 42, y, w, h).setControlLayer(BankB),
		},
		Bank_T: {
			layer: BankT,
			btn_Loop: surface.makeButton(x + 18, y, w, h).setControlLayer(BankT),
			btn_Stop: surface.makeButton(x + 24, y, w, h).setControlLayer(BankT),
			btn_Play: surface.makeButton(x + 30, y, w, h).setControlLayer(BankT),
			btn_Record: surface.makeButton(x + 36, y, w, h).setControlLayer(BankT),
			btn_Tap_Tempo: surface.makeButton(x + 42, y, w, h).setControlLayer(BankT),
		}
	}

	Pad_bank.Bank_A.pad1.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToNote(9, 36)//.setValueRange(0,127) ??
	Pad_bank.Bank_B.pad1.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToNote(9, 44)

	Pad_bank.Bank_A.pad2.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToNote(9, 37)
	Pad_bank.Bank_B.pad2.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToNote(9, 45)

	Pad_bank.Bank_A.pad3.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToNote(9, 38)
	Pad_bank.Bank_B.pad3.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToNote(9, 46)

	Pad_bank.Bank_A.pad4.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToNote(9, 39)
	Pad_bank.Bank_B.pad4.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToNote(9, 47)

	Pad_bank.Bank_A.pad5.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToNote(9, 40)
	Pad_bank.Bank_B.pad5.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToNote(9, 48)

	Pad_bank.Bank_A.pad6.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToNote(9, 41)
	Pad_bank.Bank_B.pad6.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToNote(9, 49)

	Pad_bank.Bank_A.pad7.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToNote(9, 42)
	Pad_bank.Bank_B.pad7.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToNote(9, 50)

	Pad_bank.Bank_A.pad8.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToNote(9, 43)
	Pad_bank.Bank_B.pad8.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToNote(9, 51)

	Pad_bank.Bank_T.btn_Loop.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToControlChange(0, 105)
	Pad_bank.Bank_T.btn_Stop.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToControlChange(0, 106)
	Pad_bank.Bank_T.btn_Play.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToControlChange(0, 107)
	Pad_bank.Bank_T.btn_Record.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToControlChange(0, 108)
	Pad_bank.Bank_T.btn_Tap_Tempo.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToControlChange(0, 109)


	surfaceElements.Pad_bank_A = Pad_bank.Bank_A
	surfaceElements.Pad_bank_B = Pad_bank.Bank_B
	surfaceElements.Pad_bank_T = Pad_bank.Bank_T

	// for (var i = 0; i < 8; ++i) {

    //     if (i === 3){
    //         transport.btn_Loop = surface.makeButton(x + (i * 6), y, w, h)
	//         transport.btn_Loop.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToControlChange(0, 105)
    //     }
    //     else if (i === 4){
    //         transport.btn_Stop = surface.makeButton(x + (i * 6), y, w, h)
	//         transport.btn_Stop.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToControlChange(0, 106)
    //     }
    //     else if (i === 5){
    //         transport.btn_Play = surface.makeButton(x + (i * 6), y, w, h)
	//         transport.btn_Play.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToControlChange(0, 107)
    //     }
    //     else if (i === 6){
    //         transport.btn_Record = surface.makeButton(x + (i * 6), y, w, h)
	//         transport.btn_Record.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToControlChange(0, 108)
    //     }
    //     else if (i === 7){
    //         transport.btn_Tap_Tempo = surface.makeButton(x + (i * 6), y, w, h)
	//         transport.btn_Tap_Tempo.mSurfaceValue.mMidiBinding.setInputPort(midiInput).setOutputPort(midiOutput).bindToControlChange(0, 109)
    //     }
    //     else {
	// 	    surface.makeBlindPanel(x + (i * 6), y, w, h) // 1, 2, 3
    //     }

	// }

    // surfaceElements.transport = transport

	//console.log("Pads created")
}

//----------------------------------------------------------------------------------------------------------------------
/**
 * @param {number} x
 * @param {number} y
 * @param {MR_DeviceMidiInput} midiInput
 * @param {MR_DeviceMidiOutput} midiOutput
 * @returns {Object}
 */
function makeDisplaySection(surface, x, y, midiInput, midiOutput, surfaceElements) { 
	surfaceElements.knobStripBlindPanel = surface.makeBlindPanel(x -1 , y, 7, 12)
    surfaceElements.screen = surface.makeBlindPanel(x , y + 2, 5, 3)


	surfaceElements.aiKnob = surface.makePushEncoder(x , y + 7, 5, 5)
	surfaceElements.aiKnob.mEncoderValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(0, 28)

	surfaceElements.aiKnob.mPushValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(0, 118)
	surfaceElements.varKnobIncr = surface.makeCustomValueVariable('VarKnobIncr')
	surfaceElements.varKnobDecr = surface.makeCustomValueVariable('VarKnobDecr')

	surfaceElements.aiKnob.mShiftValue = surface.makeCustomValueVariable('KnobShift')
	surfaceElements.aiKnob.mShiftValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(0, 29)
	surfaceElements.ShiftvarKnobIncr = surface.makeCustomValueVariable('ShiftVarKnobIncr')
	surfaceElements.ShiftvarKnobDecr = surface.makeCustomValueVariable('ShiftVarKnobDecr')

	surfaceElements.aiKnob.mShiftPushValue = surface.makeCustomValueVariable('KnobShiftPush')
	surfaceElements.aiKnob.mShiftPushValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(0, 119)

	


	//console.log("Display Section created")
}

//----------------------------------------------------------------------------------------------------------------------
/**
 * @param {number} faderIndex
 * @param {number} x
 * @param {number} y
 * @param {number} w
 * @param {number} h
 * @param {MR_DeviceMidiInput} midiInput
 * @param {MR_DeviceMidiOutput} midiOutput
 * @returns {Object}
 */
function makeFaderStrip(surface, faderIndex, x, y, w, h, midiInput, midiOutput) {
	var faderStrip = {}

	faderStrip.fader = surface.makeFader(x + 4 * faderIndex, y + 3.25, w, h).setTypeVertical()
    if (faderIndex === 0){
	    faderStrip.fader.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(0, 14)
    }
    else if (faderIndex === 1){
	    faderStrip.fader.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(0, 15)
    }
    else if (faderIndex === 2){
	    faderStrip.fader.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(0, 30)
    }
    else if (faderIndex === 3){
	    faderStrip.fader.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(0, 31)
    }

	return faderStrip
}


function makeFaders(surface, x, y, stripSize, midiInput, midiOutput, surfaceElements){
    surfaceElements.numStrips = stripSize

    surfaceElements.faderStrips = {}

    for (var i = 0; i < surfaceElements.numStrips; ++i) {
        surfaceElements.faderStrips[i] = makeFaderStrip(surface, i, x, y, 3, 8, midiInput, midiOutput)
    }
    
}


/**
 * @param {number} knobIndex
 * @param {number} x
 * @param {number} y
 * @param {number} w
 * @param {number} h
 * @param {MR_DeviceMidiInput} midiInput
 * @param {MR_DeviceMidiOutput} midiOutput
 * @returns {Object}
 */
function makeKnobStrip(surface, knobIndex, x, y, w, h, midiInput, midiOutput) {
	var knobStrip = {}

	knobStrip.knob = surface.makeKnob(x + 6 * (knobIndex%4), y + 6*Math.floor(knobIndex/4), w, h)
    if (knobIndex === 0){
	    knobStrip.knob.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(0, 86)
    }
    else if (knobIndex === 1){
	    knobStrip.knob.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(0, 87)
    }
    else if (knobIndex === 2){
	    knobStrip.knob.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(0, 89)
    }
    else if (knobIndex === 3){
	    knobStrip.knob.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(0, 90)
    }
    else if (knobIndex === 4){
	    knobStrip.knob.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(0, 110)
    }
    else if (knobIndex === 5){
	    knobStrip.knob.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(0, 111)
    }
    else if (knobIndex === 6){
	    knobStrip.knob.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(0, 116)
    }
    else if (knobIndex === 7){
	    knobStrip.knob.mSurfaceValue.mMidiBinding.setInputPort(midiInput).bindToControlChange(0, 117)
    }

	return knobStrip
}

function makeKnobs(surface, x, y, stripSize, midiInput, midiOutput, surfaceElements){
    surfaceElements.numStrips = stripSize

    surfaceElements.knobStrips = {}

    for (var i = 0; i < surfaceElements.numStrips; ++i) {
        surfaceElements.knobStrips[i] = makeKnobStrip(surface, i, x, y, 5, 5, midiInput, midiOutput)
    }
}   



//-----------------------------------------------------------------------------
// 3. HOST MAPPING - create mapping pages and host bindings
//-----------------------------------------------------------------------------

function MIDIDetection(midiInput, surface) {

	var varValForCheckingChangeComingFromInput_MEncoder = surface.makeCustomValueVariable('varValForCheckingChangeComingFromInput_MEncoder')
		varValForCheckingChangeComingFromInput_MEncoder.mMidiBinding
			.setInputPort(midiInput)
			.bindToControlChange(0, 28)

		varValForCheckingChangeComingFromInput_MEncoder.mOnProcessValueChange = function(activeDevice, value, diff) {
			activeDevice.setState('Input_MEncoder', 'TRUE')

			activeDevice.setState('Input_K1', 'FALSE')
			activeDevice.setState('Input_K2', 'FALSE')
			activeDevice.setState('Input_K3', 'FALSE')
			activeDevice.setState('Input_K4', 'FALSE')
			activeDevice.setState('Input_K5', 'FALSE')
			activeDevice.setState('Input_K6', 'FALSE')
			activeDevice.setState('Input_K7', 'FALSE')
			activeDevice.setState('Input_K8', 'FALSE')

			activeDevice.setState('Input_F1', 'FALSE')
			activeDevice.setState('Input_F2', 'FALSE')
			activeDevice.setState('Input_F3', 'FALSE')
			activeDevice.setState('Input_F4', 'FALSE')

	}
	
	
	var varValForCheckingChangeComingFromInput_K1 = surface.makeCustomValueVariable('varValForCheckingChangeComingFromInput_K1')
		varValForCheckingChangeComingFromInput_K1.mMidiBinding
			.setInputPort(midiInput)
			.bindToControlChange(0, 86)

		varValForCheckingChangeComingFromInput_K1.mOnProcessValueChange = function(activeDevice, value, diff) {
			activeDevice.setState('Input_K1', 'TRUE')
			g_knob_1_hw_value = Math.floor (value * 127.9999)

	}

	var varValForCheckingChangeComingFromInput_K2 = surface.makeCustomValueVariable('varValForCheckingChangeComingFromInput_K2')
		varValForCheckingChangeComingFromInput_K2.mMidiBinding
			.setInputPort(midiInput)
			.bindToControlChange(0, 87)

		varValForCheckingChangeComingFromInput_K2.mOnProcessValueChange = function(activeDevice, value, diff) {
			activeDevice.setState('Input_K2', 'TRUE')
			g_knob_2_hw_value = Math.floor (value * 127.9999)

	}

	var varValForCheckingChangeComingFromInput_K3 = surface.makeCustomValueVariable('varValForCheckingChangeComingFromInput_K3')
		varValForCheckingChangeComingFromInput_K3.mMidiBinding
			.setInputPort(midiInput)
			.bindToControlChange(0, 89)

		varValForCheckingChangeComingFromInput_K3.mOnProcessValueChange = function(activeDevice, value, diff) {
			activeDevice.setState('Input_K3', 'TRUE')
			g_knob_3_hw_value = Math.floor (value * 127.9999)
	}

	var varValForCheckingChangeComingFromInput_K4 = surface.makeCustomValueVariable('varValForCheckingChangeComingFromInput_K4')
		varValForCheckingChangeComingFromInput_K4.mMidiBinding
			.setInputPort(midiInput)
			.bindToControlChange(0, 90)

		varValForCheckingChangeComingFromInput_K4.mOnProcessValueChange = function(activeDevice, value, diff) {
			activeDevice.setState('Input_K4', 'TRUE')
			g_knob_4_hw_value = Math.floor (value * 127.9999)
	}

	var varValForCheckingChangeComingFromInput_K5 = surface.makeCustomValueVariable('varValForCheckingChangeComingFromInput_K5')
		varValForCheckingChangeComingFromInput_K5.mMidiBinding
			.setInputPort(midiInput)
			.bindToControlChange(0, 110)

		varValForCheckingChangeComingFromInput_K5.mOnProcessValueChange = function(activeDevice, value, diff) {
			activeDevice.setState('Input_K5', 'TRUE')
			g_knob_5_hw_value = Math.floor (value * 127.9999)
	}

	var varValForCheckingChangeComingFromInput_K6 = surface.makeCustomValueVariable('varValForCheckingChangeComingFromInput_K6')
		varValForCheckingChangeComingFromInput_K6.mMidiBinding
			.setInputPort(midiInput)
			.bindToControlChange(0, 111)

		varValForCheckingChangeComingFromInput_K6.mOnProcessValueChange = function(activeDevice, value, diff) {
			activeDevice.setState('Input_K6', 'TRUE')
			g_knob_6_hw_value = Math.floor (value * 127.9999)
	}

	var varValForCheckingChangeComingFromInput_K7 = surface.makeCustomValueVariable('varValForCheckingChangeComingFromInput_K7')
		varValForCheckingChangeComingFromInput_K7.mMidiBinding
			.setInputPort(midiInput)
			.bindToControlChange(0, 116)

		varValForCheckingChangeComingFromInput_K7.mOnProcessValueChange = function(activeDevice, value, diff) {
			activeDevice.setState('Input_K7', 'TRUE')
			g_knob_7_hw_value = Math.floor (value * 127.9999)
	}

	var varValForCheckingChangeComingFromInput_K8 = surface.makeCustomValueVariable('varValForCheckingChangeComingFromInput_K8')
		varValForCheckingChangeComingFromInput_K8.mMidiBinding
			.setInputPort(midiInput)
			.bindToControlChange(0, 117)

		varValForCheckingChangeComingFromInput_K8.mOnProcessValueChange = function(activeDevice, value, diff) {
			activeDevice.setState('Input_K8', 'TRUE')
			g_knob_8_hw_value = Math.floor (value * 127.9999)
	}

	var varValForCheckingChangeComingFromInput_F1 = surface.makeCustomValueVariable('varValForCheckingChangeComingFromInput_F1')
		varValForCheckingChangeComingFromInput_F1.mMidiBinding
			.setInputPort(midiInput)
			.bindToControlChange(0, 14)

		varValForCheckingChangeComingFromInput_F1.mOnProcessValueChange = function(activeDevice, value, diff) {
			activeDevice.setState('Input_F1', 'TRUE')
			g_fader_1_hw_value = Math.floor (value * 127.9999)
	}

	var varValForCheckingChangeComingFromInput_F2 = surface.makeCustomValueVariable('varValForCheckingChangeComingFromInput_F2')
		varValForCheckingChangeComingFromInput_F2.mMidiBinding
			.setInputPort(midiInput)
			.bindToControlChange(0, 15)

		varValForCheckingChangeComingFromInput_F2.mOnProcessValueChange = function(activeDevice, value, diff) {
			activeDevice.setState('Input_F2', 'TRUE')
			g_fader_2_hw_value = Math.floor (value * 127.9999)
	}

	var varValForCheckingChangeComingFromInput_F3 = surface.makeCustomValueVariable('varValForCheckingChangeComingFromInput_F3')
		varValForCheckingChangeComingFromInput_F3.mMidiBinding
			.setInputPort(midiInput)
			.bindToControlChange(0, 30)

		varValForCheckingChangeComingFromInput_F3.mOnProcessValueChange = function(activeDevice, value, diff) {
			activeDevice.setState('Input_F3', 'TRUE')
			g_fader_3_hw_value = Math.floor (value * 127.9999)
	}

	var varValForCheckingChangeComingFromInput_F4 = surface.makeCustomValueVariable('varValForCheckingChangeComingFromInput_F4')
		varValForCheckingChangeComingFromInput_F4.mMidiBinding
			.setInputPort(midiInput)
			.bindToControlChange(0, 31)

		varValForCheckingChangeComingFromInput_F4.mOnProcessValueChange = function(activeDevice, value, diff) {
			activeDevice.setState('Input_F4', 'TRUE')
			g_fader_4_hw_value = Math.floor (value * 127.9999)
	}


}

//----------------------------------------------------------------------------------------------------------------------
function makeDefaultPage(name, deviceDriver, surfaceElements, surface, midiOutput) {
	/** @type {MR_FactoryMappingPage} */
	var page = deviceDriver.mMapping.makePage(name)

	page.makeValueBinding(surfaceElements.Pad_bank_T.btn_Loop.mSurfaceValue, page.mHostAccess.mTransport.mValue.mCycleActive).setTypeToggle()
	page.makeValueBinding(surfaceElements.Pad_bank_T.btn_Stop.mSurfaceValue, page.mHostAccess.mTransport.mValue.mStop)
	page.makeValueBinding(surfaceElements.Pad_bank_T.btn_Play.mSurfaceValue, page.mHostAccess.mTransport.mValue.mStart).setTypeToggle()
	page.makeValueBinding(surfaceElements.Pad_bank_T.btn_Record.mSurfaceValue, page.mHostAccess.mTransport.mValue.mRecord).setTypeToggle()
	page.makeCommandBinding(surfaceElements.Pad_bank_T.btn_Tap_Tempo.mSurfaceValue, 'Project', 'Beat Calculator')

	
	// page.makeValueBinding(surfaceElements.Pad_bank_B.pad1.mSurfaceValue, page.mHostAccess.mTrackSelection.mMixerChannel.mValue.mMute).setTypeToggle()
	// page.makeValueBinding(surfaceElements.Pad_bank_B.pad2.mSurfaceValue, page.mHostAccess.mTrackSelection.mMixerChannel.mValue.mSolo).setTypeToggle()
	// page.makeValueBinding(surfaceElements.Pad_bank_B.pad3.mSurfaceValue, page.mHostAccess.mTrackSelection.mMixerChannel.mValue.mEditorOpen).setTypeToggle()
	// page.makeCommandBinding(surfaceElements.Pad_bank_B.pad4.mSurfaceValue, 'Window Zones', 'Show/Hide Left Zone')
	// page.makeCommandBinding(surfaceElements.Pad_bank_B.pad5.mSurfaceValue, 'Window Zones', 'Show/Hide Lower Zone')
	// page.makeCommandBinding(surfaceElements.Pad_bank_B.pad6.mSurfaceValue, 'Window Zones', 'Show/Hide Right Zone')
	// page.makeCommandBinding(surfaceElements.Pad_bank_B.pad7.mSurfaceValue, 'Edit', 'Duplicate')
	// page.makeCommandBinding(surfaceElements.Pad_bank_B.pad8.mSurfaceValue, 'AddTrack', 'Instrument')


	

	// SLIDERS 1-4 //

	page.makeValueBinding(surfaceElements.faderStrips[0].fader.mSurfaceValue, page.mHostAccess.mMixConsole.makeMixerBankZone().makeMixerBankChannel().mValue.mVolume).setValueTakeOverModeScaled();
	page.makeValueBinding(surfaceElements.faderStrips[1].fader.mSurfaceValue, page.mHostAccess.mTrackSelection.mMixerChannel.mSends.getByIndex(0).mLevel).setValueTakeOverModeScaled();
	page.makeValueBinding(surfaceElements.faderStrips[2].fader.mSurfaceValue, page.mHostAccess.mTrackSelection.mMixerChannel.mSends.getByIndex(1).mLevel).setValueTakeOverModeScaled();
	page.makeValueBinding(surfaceElements.faderStrips[3].fader.mSurfaceValue, page.mHostAccess.mMixConsole.makeMixerBankZone().makeMixerBankChannel().mValue.mPan).setValueTakeOverModeScaled();


	// MAIN ENCODER //

	page.mHostAccess.mTrackSelection.mMixerChannel.mOnTitleChange = function (context, activeMapping, objectTitle){
		//console.log('TitleChange : ' + activeMapping + ' ' + objectTitle)

		MiniLab_3_Var.TRACK_NAME = objectTitle

		//console.log("Old : " + MiniLab_3_Var.OLD_TRACK_NAME + " New : " + MiniLab_3_Var.TRACK_NAME)
		if (MiniLab_3_Var.OLD_TRACK_NAME !== MiniLab_3_Var.TRACK_NAME){

			MiniLab_3_Var.OLD_TRACK_NAME = MiniLab_3_Var.TRACK_NAME

			var screenID = 2
			var line1 = "Tracks"
			var line2 = MiniLab_3_Var.TRACK_NAME
		
			if (MiniLab_3_Var.TRACK_NAME === "") {
				line1 = "Select a track"
				line2 = ""
				screenID = 10
			}

			// var MEncoderInput = context.getState('Input_MEncoder')
			// context.setState ('Input_MEncoder', 'FALSE')

			// if (MEncoderInput === 'TRUE'){

			// 	MiniLab_3_Pages.SetPage({page_type : 10,
			// 		line1 : MiniLab_3_Var.TRACK_NAME,
			// 		line2 : "",
			// 		hw_value : 0,
			// 		midiOutput,
			// 		context})
			// 	}

			MiniLab_3_Pages.SetPage({page_type : screenID,
				line1 : line1,
				line2 : line2,
				hw_value : 0,
				midiOutput,
				context})
		
			}

	}





	surfaceElements.aiKnob.mEncoderValue.mOnProcessValueChange = function (context, value){
		if (value < 0.5)
		{
			surfaceElements.varKnobDecr.setProcessValue(context, 1.)
			surfaceElements.varKnobDecr.setProcessValue(context, 0.)
		}
		else if (value > 0.5)
		{
			surfaceElements.varKnobIncr.setProcessValue(context, 1.)
			surfaceElements.varKnobIncr.setProcessValue(context, 0.)
		}
	}

	page.makeActionBinding(surfaceElements.varKnobDecr, page.mHostAccess.mTrackSelection.mAction.mPrevTrack)
	page.makeActionBinding(surfaceElements.varKnobIncr, page.mHostAccess.mTrackSelection.mAction.mNextTrack)
	page.makeValueBinding(surfaceElements.aiKnob.mPushValue, page.mHostAccess.mTrackSelection.mMixerChannel.mValue.mInstrumentOpen).setTypeToggle()



	surfaceElements.aiKnob.mShiftValue.mOnProcessValueChange = function (context, value){
		//console.log(value.toString())
		if (value < 0.5)
		{
			surfaceElements.ShiftvarKnobDecr.setProcessValue(context, 1.)
			g_timeline_is_displayed = true
			
		}
		else if (value > 0.5)
		{
			surfaceElements.ShiftvarKnobIncr.setProcessValue(context, 1.)
			g_timeline_is_displayed = true

		}
	}

	// page.mHostAccess.mTransport.mTimeDisplay.mPrimary.mTransportLocator.mOnChange = function (context, activeMapping, time, format) {

	// 	//console.log('Transport time: ' + time + ', format: ' + format)
	// 	MiniLab_3_Var.TIMELINE = time

	// 	if (g_timeline_is_displayed === true) {

	// 		MiniLab_3_Pages.SetPage({page_type : 10,
	// 			line1 : MiniLab_3_Var.TRACK_NAME,
	// 			//line2 : MiniLab_3_Var.TIMELINE,
	// 			line2 : "",
	// 			hw_value : 0,
	// 			midiOutput,
	// 			context})

	// 		g_timeline_is_displayed = false
	// 		}

	
	// }

	page.makeCommandBinding(surfaceElements.ShiftvarKnobDecr, 'Transport', 'Step Back Bar')
	page.makeCommandBinding(surfaceElements.ShiftvarKnobIncr, 'Transport', 'Step Bar')

	return page
}

//----------------------------------------------------------------------------------------------------------------------
function makeSubPage(/** @type {MR_SubPageArea} */subPageArea, name) {
	var subPage = subPageArea.makeSubPage(name)
	var msgText = 'sub page ' + name + ' activated'
	subPage.mOnActivate = function (activeDevice) {
		//console.log(msgText)
	}
	return subPage
}

//----------------------------------------------------------------------------------------------------------------------

//----------------------------------------------------------------------------------------------------------------------
/**
 * 
 * @param {MR_HostDefaults} hostDefaults 
 * @param {MR_DeviceDriver} deviceDriver 
 * @param {Object} surfaceElements 
 * @returns 
 */
function makePageDevice(hostDefaults, deviceDriver, surfaceElements, surface, midiOutput) {
	var page = makeDefaultPage('Device', deviceDriver, surfaceElements, surface, midiOutput)



	//#FUNCTIONS#//


	page.makeActionBinding(surfaceElements.aiKnob.mShiftPushValue, deviceDriver.mAction.mNextPage)

	// ENCODERS 1-8 //

	var knobSubPageArea = page.makeSubPageArea('knobSubPageArea')
	var subPageListQCs = []

	var numQCsSubPages = hostDefaults.getNumberOfQuickControls() / 8
	for (var subPageIdx = 0; subPageIdx < numQCsSubPages; ++subPageIdx) {
        var nameSubPage = 'Quick Control ' + (subPageIdx + 1).toString() + '-' + (subPageIdx + 8).toString()
        var subPageQC = makeSubPage(knobSubPageArea, nameSubPage)
        subPageListQCs.push(subPageQC)
	}

    function bindChannelBankItem(index) {

    	var focusQC = page.mHostAccess.mFocusedQuickControls
    	var knobValue = surfaceElements.knobStrips[index].knob.mSurfaceValue

    	for (var subPageIdx = 0; subPageIdx < numQCsSubPages; ++subPageIdx) {
    		var subPage = subPageListQCs[subPageIdx]
    		var qcknobIndex = index + (subPageIdx * 8)
    		page.makeValueBinding(knobValue, focusQC.getByIndex(qcknobIndex)).setSubPage(subPage)
    	}
    }

    for (var i = 0; i < 8; ++i) {
    	bindChannelBankItem(i)
    }



	return page

}

//----------------------------------------------------------------------------------------------------------------------
/**
 * 
 * @param {MR_HostDefaults} hostDefaults 
 * @param {MR_DeviceDriver} deviceDriver 
 * @param {Object} surfaceElements 
 * @returns 
 */
function makePageMixer(hostDefaults, deviceDriver, surfaceElements, surface, midiOutput) {
	var page = makeDefaultPage('Mixer', deviceDriver, surfaceElements, surface, midiOutput)


	//#FUNCTIONS#//

	page.makeActionBinding(surfaceElements.aiKnob.mShiftPushValue, deviceDriver.mAction.mPrevPage)


	// ENCODERS 1-8 //

	var hostMixerBankZoneTracks = page.mHostAccess.mMixConsole.makeMixerBankZone().excludeInputChannels().excludeOutputChannels();

	function makeChannelStripMapping(stripIndex, channelBankItem) {
		   var knobValue = surfaceElements.knobStrips[stripIndex].knob.mSurfaceValue;
		   page.makeValueBinding(knobValue, channelBankItem.mValue.mVolume)
	}


	for (var i = 0; i < 8; ++i) {
		   var channelBankItem = hostMixerBankZoneTracks.makeMixerBankChannel();
		   makeChannelStripMapping(i, channelBankItem);
	}






	return page

}

//----------------------------------------------------------------------------------------------------------------------
/**
 * @param {MR_HostDefaults} hostDefaults
 * @param {MR_DeviceDriver} deviceDriver
 * @param {Object} surfaceElements
 */
function makeHostMapping(hostDefaults, deviceDriver, surfaceElements, surface, midiOutput) {

	var pageDevice = makePageDevice(hostDefaults, deviceDriver, surfaceElements, surface, midiOutput)
	pageDevice.mOnActivate = function (context) {
		//console.log('DEVICE MODE')
		
		MiniLab_3_Pages.SetPage({page_type : 10,
								line1 : "Device",
								line2 : "Mode",
								hw_value : 0,
								midiOutput,
								context})
							
	}
	
	var pageMixer = makePageMixer(hostDefaults, deviceDriver, surfaceElements, surface, midiOutput)
	pageMixer.mOnActivate = function (context) {
		//console.log('Mixer MODE')
		
		MiniLab_3_Pages.SetPage({page_type : 10,
								line1 : "Mixer",
								line2 : "Mode",
								hw_value : 0,
								midiOutput,
								context})
							
	}
	 

	// var pageEqOfSelectedTrack = makePageEqOfSelectedTrack(deviceDriver, surfaceElements)
	// pageEqOfSelectedTrack.mOnActivate = function (context) {
	// 	onActivatePageDefault(context, deviceDriver, surfaceElements, surface, midiOutput)
	// 	console.log('from script: Arturia KeyLab Essential page "EQ of Selected Track" activated')
	// }
}

//----------------------------------------------------------------------------------------------------------------------
// 4. Feedback to the HW controller
//----------------------------------------------------------------------------------------------------------------------

function makeLEDFeedback(surfaceElements, midiOutput){
	MiniLab_3_LED.LEDReturn(surfaceElements, midiOutput)
}

function makeScreenFeedback(page, surfaceElements, context, midiOutput){
	if (page === 'Mixer' ){

	}
	else if (page === 'Device' ){

	}

}

function makeSurfaceFeedback(surfaceElements, midiOutput){
	//console.log("Feedbacks")
	makeLEDFeedback(surfaceElements, midiOutput)
	//makeScreenFeedback(surfaceElements, midiOutput)

	

	// ITEMS

	//# KNOB 1 #//

	surfaceElements.knobStrips[0].knob.mSurfaceValue.mOnTitleChange = function (context, objectTitle, valueTitle) {
		//console.log('mOnTitleValueChange : ' + valueTitle.toString())
		context.setState('Knob1Param', valueTitle)
		g_knob_1_param = context.getState('Knob1Param')
    }

	surfaceElements.knobStrips[0].knob.mSurfaceValue.mOnDisplayValueChange = function (context, value, unit) {
		//console.log('mOnDisplayValueChange : ' + value.toString())
		context.setState('Knob1Value', value)
		g_knob_1_value = context.getState('Knob1Value')

		var K1Input = context.getState('Input_K1')
		context.setState ('Input_K1', 'FALSE')

		if (K1Input === 'TRUE') {

			MiniLab_3_Pages.SetPage({page_type : 3, 
									line1 : g_knob_1_param, 
									line2 : g_knob_1_value,  
									hw_value : g_knob_1_hw_value, 
									midiOutput,
									context})
		}
    }

	surfaceElements.knobStrips[0].knob.mSurfaceValue.mOnProcessValueChange = function (context, value) {
		//console.log('mOnProcessValueChange : ' + value.toString())
		var K1Input = context.getState('Input_K1')

		value_hw = Math.round(value*127)

		if (K1Input === 'FALSE') {
			MiniLab_3_Pages.SetParamValue({ID : 0, value_hw, midiOutput, context})

		}
	}

	//# KNOB 2 #//

	surfaceElements.knobStrips[1].knob.mSurfaceValue.mOnTitleChange = function (context, objectTitle, valueTitle) {
		context.setState('Knob2Param', valueTitle)
		g_knob_2_param = context.getState('Knob2Param')
    }

	surfaceElements.knobStrips[1].knob.mSurfaceValue.mOnDisplayValueChange = function (context, value, unit) {
		context.setState('Knob2Value', value)
		g_knob_2_value = context.getState('Knob2Value')

		var K2Input = context.getState('Input_K2')
		context.setState ('Input_K2', 'FALSE')

		if (K2Input === 'TRUE') {

			MiniLab_3_Pages.SetPage({page_type : 3, 
									line1 : g_knob_2_param, 
									line2 : g_knob_2_value,  
									hw_value : g_knob_2_hw_value, 
									midiOutput,
									context})
		}

    }

	
	surfaceElements.knobStrips[1].knob.mSurfaceValue.mOnProcessValueChange = function (context, value) {
		var K2Input = context.getState('Input_K2')

		value_hw = Math.round(value*127)

		if (K2Input === 'FALSE') {
			MiniLab_3_Pages.SetParamValue({ID : 1, value_hw, midiOutput, context})

		}
	}

	//# KNOB 3 #//

	surfaceElements.knobStrips[2].knob.mSurfaceValue.mOnTitleChange = function (context, objectTitle, valueTitle) {
		context.setState('Knob3Param', valueTitle)
		g_knob_3_param = context.getState('Knob3Param')
    }

	surfaceElements.knobStrips[2].knob.mSurfaceValue.mOnDisplayValueChange = function (context, value, unit) {
		context.setState('Knob3Value', value)
		g_knob_3_value = context.getState('Knob3Value')

		var K3Input = context.getState('Input_K3')
		context.setState ('Input_K3', 'FALSE')

		if (K3Input === 'TRUE') {

			MiniLab_3_Pages.SetPage({page_type : 3, 
									line1 : g_knob_3_param, 
									line2 : g_knob_3_value,  
									hw_value : g_knob_3_hw_value, 
									midiOutput,
									context})
		}

    }

	surfaceElements.knobStrips[2].knob.mSurfaceValue.mOnProcessValueChange = function (context, value) {
		var K3Input = context.getState('Input_K3')


		value_hw = Math.round(value*127)

		if (K3Input === 'FALSE') {

			MiniLab_3_Pages.SetParamValue({ID : 2, value_hw, midiOutput, context})

		}
	}

	//# KNOB 4 #//

	surfaceElements.knobStrips[3].knob.mSurfaceValue.mOnTitleChange = function (context, objectTitle, valueTitle) {
		context.setState('Knob4Param', valueTitle)
		g_knob_4_param = context.getState('Knob4Param')
    }

	surfaceElements.knobStrips[3].knob.mSurfaceValue.mOnDisplayValueChange = function (context, value, unit) {
		context.setState('Knob4Value', value)
		g_knob_4_value = context.getState('Knob4Value')

		var K4Input = context.getState('Input_K4')
		context.setState ('Input_K4', 'FALSE')

		if (K4Input === 'TRUE') {

			MiniLab_3_Pages.SetPage({page_type : 3, 
									line1 : g_knob_4_param, 
									line2 : g_knob_4_value,  
									hw_value : g_knob_4_hw_value, 
									midiOutput,
									context})
		}

    }

	surfaceElements.knobStrips[3].knob.mSurfaceValue.mOnProcessValueChange = function (context, value) {
		var K3Input = context.getState('Input_K3')

		value_hw = Math.round(value*127)

		if (K3Input === 'FALSE') {

			MiniLab_3_Pages.SetParamValue({ID : 3, value_hw, midiOutput, context})

		}
	}

	//# KNOB 5 #//

	surfaceElements.knobStrips[4].knob.mSurfaceValue.mOnTitleChange = function (context, objectTitle, valueTitle) {
		context.setState('Knob5Param', valueTitle)
		g_knob_5_param = context.getState('Knob5Param')
    }

	surfaceElements.knobStrips[4].knob.mSurfaceValue.mOnDisplayValueChange = function (context, value, unit) {
		context.setState('Knob5Value', value)
		g_knob_5_value = context.getState('Knob5Value')

		var K5Input = context.getState('Input_K5')
		context.setState ('Input_K5', 'FALSE')

		if (K5Input === 'TRUE') {

			MiniLab_3_Pages.SetPage({page_type : 3, 
									line1 : g_knob_5_param, 
									line2 : g_knob_5_value,  
									hw_value : g_knob_5_hw_value, 
									midiOutput,
									context})
		}

    }

	surfaceElements.knobStrips[4].knob.mSurfaceValue.mOnProcessValueChange = function (context, value) {
		var K5Input = context.getState('Input_K5')

		value_hw = Math.round(value*127)

		if (K5Input === 'FALSE') {

			MiniLab_3_Pages.SetParamValue({ID : 4, value_hw, midiOutput, context})

		}
	}

	//# KNOB 6 #//

	surfaceElements.knobStrips[5].knob.mSurfaceValue.mOnTitleChange = function (context, objectTitle, valueTitle) {
		context.setState('Knob6Param', valueTitle)
		g_knob_6_param = context.getState('Knob6Param')
    }

	surfaceElements.knobStrips[5].knob.mSurfaceValue.mOnDisplayValueChange = function (context, value, unit) {
		context.setState('Knob6Value', value)
		g_knob_6_value = context.getState('Knob6Value')

		var K6Input = context.getState('Input_K6')
		context.setState ('Input_K6', 'FALSE')

		if (K6Input === 'TRUE') {

			MiniLab_3_Pages.SetPage({page_type : 3, 
									line1 : g_knob_6_param, 
									line2 : g_knob_6_value,  
									hw_value : g_knob_6_hw_value, 
									midiOutput,
									context})
		}
    }

	surfaceElements.knobStrips[5].knob.mSurfaceValue.mOnProcessValueChange = function (context, value) {
		var K6Input = context.getState('Input_K6')

		value_hw = Math.round(value*127)

		if (K6Input === 'FALSE') {

			MiniLab_3_Pages.SetParamValue({ID : 5, value_hw, midiOutput, context})

		}
	}

	//# KNOB 7 #//

	surfaceElements.knobStrips[6].knob.mSurfaceValue.mOnTitleChange = function (context, objectTitle, valueTitle) {
		context.setState('Knob7Param', valueTitle)
		g_knob_7_param = context.getState('Knob7Param')
    }


	surfaceElements.knobStrips[6].knob.mSurfaceValue.mOnDisplayValueChange = function (context, value, unit) {
		context.setState('Knob7Value', value)
		g_knob_7_value = context.getState('Knob7Value')

		var K7Input = context.getState('Input_K7')
		context.setState ('Input_K7', 'FALSE')

		if (K7Input === 'TRUE') {

			MiniLab_3_Pages.SetPage({page_type : 3, 
									line1 : g_knob_7_param, 
									line2 : g_knob_7_value,  
									hw_value : g_knob_7_hw_value, 
									midiOutput,
									context})
		}

    }

	surfaceElements.knobStrips[6].knob.mSurfaceValue.mOnProcessValueChange = function (context, value) {
		var K7Input = context.getState('Input_K7')

		value_hw = Math.round(value*127)

		if (K7Input === 'FALSE') {

			MiniLab_3_Pages.SetParamValue({ID : 6, value_hw, midiOutput, context})

		}
	}

	//# KNOB 8 #//

	surfaceElements.knobStrips[7].knob.mSurfaceValue.mOnTitleChange = function (context, objectTitle, valueTitle) {
		context.setState('Knob8Param', valueTitle)
		g_knob_8_param = context.getState('Knob8Param')
    }

	surfaceElements.knobStrips[7].knob.mSurfaceValue.mOnDisplayValueChange = function (context, value, unit) {
		context.setState('Knob8Value', value)
		g_knob_8_value = context.getState('Knob8Value')

		var K8Input = context.getState('Input_K8')
		context.setState ('Input_K8', 'FALSE')

		if (K8Input === 'TRUE') {

			MiniLab_3_Pages.SetPage({page_type : 3, 
									line1 : g_knob_8_param, 
									line2 : g_knob_8_value,  
									hw_value : g_knob_8_hw_value, 
									midiOutput,
									context})
		}

    }

	surfaceElements.knobStrips[7].knob.mSurfaceValue.mOnProcessValueChange = function (context, value) {
		var K8Input = context.getState('Input_K8')

		value_hw = Math.round(value*127)

		if (K8Input === 'FALSE') {

			MiniLab_3_Pages.SetParamValue({ID : 7, value_hw, midiOutput, context})

		}
	}


	//# FADER 1 #//

	surfaceElements.faderStrips[0].fader.mSurfaceValue.mOnTitleChange = function (context, objectTitle, valueTitle) {
		context.setState('Fader1Param', valueTitle)
		g_fader_1_param = context.getState('Fader1Param')
    }
	
	surfaceElements.faderStrips[0].fader.mSurfaceValue.mOnDisplayValueChange = function (context, value, unit) {
		context.setState('Fader1Value', value)
		g_fader_1_value = context.getState('Fader1Value')

		var F1Input = context.getState('Input_F1')
		context.setState ('Input_F1', 'FALSE')

		if (F1Input === 'TRUE') {

			MiniLab_3_Pages.SetPage({page_type : 4, 
									line1 : g_fader_1_param, 
									line2 : g_fader_1_value,  
									hw_value : g_fader_1_hw_value, 
									midiOutput,
									context})
		}

    }

	//# FADER 2 #//

	surfaceElements.faderStrips[1].fader.mSurfaceValue.mOnTitleChange = function (context, objectTitle, valueTitle) {
		context.setState('Fader2Param', valueTitle)
		g_fader_2_param = context.getState('Fader2Param')
    }

	surfaceElements.faderStrips[1].fader.mSurfaceValue.mOnDisplayValueChange = function (context, value, unit) {
		context.setState('Fader2Value', value)
		g_fader_2_value = context.getState('Fader2Value')

		var F2Input = context.getState('Input_F2')
		context.setState ('Input_F2', 'FALSE')

		if (F2Input === 'TRUE') {

			MiniLab_3_Pages.SetPage({page_type : 4, 
									line1 : g_fader_2_param, 
									line2 : g_fader_2_value,  
									hw_value : g_fader_2_hw_value, 
									midiOutput,
									context})
		}

    }

	//# FADER 3 #//

	surfaceElements.faderStrips[2].fader.mSurfaceValue.mOnTitleChange = function (context, objectTitle, valueTitle) {
		context.setState('Fader3Param', valueTitle)
		g_fader_3_param = context.getState('Fader3Param')
    }

	surfaceElements.faderStrips[2].fader.mSurfaceValue.mOnDisplayValueChange = function (context, value, unit) {
		context.setState('Fader3Value', value)
		g_fader_3_value = context.getState('Fader3Value')

		var F3Input = context.getState('Input_F3')
		context.setState ('Input_F3', 'FALSE')

		if (F3Input === 'TRUE') {

			MiniLab_3_Pages.SetPage({page_type : 4, 
									line1 : g_fader_3_param, 
									line2 : g_fader_3_value,  
									hw_value : g_fader_3_hw_value, 
									midiOutput,
									context})
		}

    }

	//# FADER 4 #//

	surfaceElements.faderStrips[3].fader.mSurfaceValue.mOnTitleChange = function (context, objectTitle, valueTitle) {
		context.setState('Fader4Param', valueTitle)
		g_fader_4_param = context.getState('Fader4Param')
    }

	surfaceElements.faderStrips[3].fader.mSurfaceValue.mOnDisplayValueChange = function (context, value, unit) {
		context.setState('Fader4Value', value)
		g_fader_4_value = context.getState('Fader4Value')

		var F4Input = context.getState('Input_F4')
		context.setState ('Input_F4', 'FALSE')

		if (F4Input === 'TRUE') {

			MiniLab_3_Pages.SetPage({page_type : 4, 
									line1 : g_fader_4_param, 
									line2 : g_fader_4_value,  
									hw_value : g_fader_4_hw_value, 
									midiOutput,
									context})
		}

    }




}


//----------------------------------------------------------------------------------------------------------------------
// 4. Feedback to the HW controller
//----------------------------------------------------------------------------------------------------------------------
/**
 * 
 * @param {MR_DeviceDriver} deviceDriver
 * @param {MR_DeviceMidiOutput} midiOutput
 */
 function deviceSetup(deviceDriver, midiOutput, midiInput) {
	
	deviceDriver.mOnActivate = function (context) {
		//console.log("INIT")
		MiniLab_3_Connection.DAWConnect(midiOutput, context)
		MiniLab_3_Connection.ProgramRequest(midiOutput, context)
		MiniLab_3_LED.LEDinit(midiOutput, context)
		MiniLab_3_Pages.SetPage({page_type : 10, line1 : "MiniLab 3", line2 : "Cubase", hw_value : 0, midiOutput, context})

	}

	deviceDriver.mOnDeactivate = function (context) {
		//console.log("DEINIT")
		MiniLab_3_Pages.SetPage({page_type : 10, line1 : "MiniLab 3", line2 : "Disconnected", hw_value : 0, midiOutput, context})
		MiniLab_3_Connection.DAWDisonnect(midiOutput, context)

	}

	// midiInput.mOnSysex = function (context, message){

	// 	if (message.toString().charAt(28) === '8') {
	// 		MiniLab_3_Var.PROGRAM = message.toString().charAt(30)
	// 	}
	// 	console.log(MiniLab_3_Var.PROGRAM)
	// }
	
}




//-----------------------------------------------------------------------------
// RETURN to require ----------------------------------------------------------
//-----------------------------------------------------------------------------
module.exports = {
	makeModWheels,
	makeFunctionButtons,
	makePads,
	makeDisplaySection,
    makeFaders,
    makeKnobs,
	makeHostMapping,
	deviceSetup,
	makeLEDFeedback,
	makeScreenFeedback,
	makeSurfaceFeedback,
	MIDIDetection,
}
