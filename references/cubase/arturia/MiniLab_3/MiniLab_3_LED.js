// 	Surface:	KeyLab Essential 3
// 	Developer:	Farès MEZDOUR
// 	Version:	0.1


var MiniLab_3_Dispatch = require('./MiniLab_3_Dispatch')
var MiniLab_3_Var = require('./MiniLab_3_Var')
var MiniLab_3_Pages = require('./MiniLab_3_Pages')



function LEDinit(midiOutput, context){
    //console.log("LED Init")

    midiOutput.sendMidi(context, [0xf0, 0x00, 0x20, 0x6b, 0x7f, 0x42, 0x02, 0x02, 0x16, 0x57, 0x14, 0x05, 0x00, 0xf7])
    midiOutput.sendMidi(context, [0xf0, 0x00, 0x20, 0x6b, 0x7f, 0x42, 0x02, 0x02, 0x16, 0x58, 0x14, 0x14, 0x14, 0xf7])
    midiOutput.sendMidi(context, [0xf0, 0x00, 0x20, 0x6b, 0x7f, 0x42, 0x02, 0x02, 0x16, 0x59, 0x00, 0x14, 0x00, 0xf7])
    midiOutput.sendMidi(context, [0xf0, 0x00, 0x20, 0x6b, 0x7f, 0x42, 0x02, 0x02, 0x16, 0x5a, 0x14, 0x00, 0x00, 0xf7])
    midiOutput.sendMidi(context, [0xf0, 0x00, 0x20, 0x6b, 0x7f, 0x42, 0x02, 0x02, 0x16, 0x5b, 0x14, 0x14, 0x14, 0xf7])

    midiOutput.sendMidi(context, [0xf0, 0x00, 0x20, 0x6b, 0x7f, 0x42, 0x02, 0x02, 0x16, 0x44, 0x14, 0x14, 0x14, 0xf7])
    midiOutput.sendMidi(context, [0xf0, 0x00, 0x20, 0x6b, 0x7f, 0x42, 0x02, 0x02, 0x16, 0x45, 0x14, 0x14, 0x14, 0xf7])
    midiOutput.sendMidi(context, [0xf0, 0x00, 0x20, 0x6b, 0x7f, 0x42, 0x02, 0x02, 0x16, 0x46, 0x14, 0x14, 0x14, 0xf7])
    midiOutput.sendMidi(context, [0xf0, 0x00, 0x20, 0x6b, 0x7f, 0x42, 0x02, 0x02, 0x16, 0x47, 0x14, 0x14, 0x14, 0xf7])
    midiOutput.sendMidi(context, [0xf0, 0x00, 0x20, 0x6b, 0x7f, 0x42, 0x02, 0x02, 0x16, 0x48, 0x14, 0x14, 0x14, 0xf7])
    midiOutput.sendMidi(context, [0xf0, 0x00, 0x20, 0x6b, 0x7f, 0x42, 0x02, 0x02, 0x16, 0x49, 0x14, 0x14, 0x14, 0xf7])
    midiOutput.sendMidi(context, [0xf0, 0x00, 0x20, 0x6b, 0x7f, 0x42, 0x02, 0x02, 0x16, 0x4a, 0x14, 0x14, 0x14, 0xf7])
    midiOutput.sendMidi(context, [0xf0, 0x00, 0x20, 0x6b, 0x7f, 0x42, 0x02, 0x02, 0x16, 0x4b, 0x14, 0x14, 0x14, 0xf7])


}


function LEDReturn(surfaceElements, midiOutput){

    StopReturn(surfaceElements.Pad_bank_T.btn_Stop, midiOutput)
    PlayReturn(surfaceElements.Pad_bank_T.btn_Play, midiOutput)
    RecordReturn(surfaceElements.Pad_bank_T.btn_Record, midiOutput)
    TapReturn(surfaceElements.Pad_bank_T.btn_Tap_Tempo, midiOutput)
    LoopReturn(surfaceElements.Pad_bank_T.btn_Loop, midiOutput)

    PadAReturn(surfaceElements.Pad_bank_A, midiOutput)
    PadBReturn(surfaceElements.Pad_bank_B, midiOutput)
}


function StopReturn(button, midiOutput){
    button.mSurfaceValue.mOnProcessValueChange = function (context, newValue) {
        // console.log("Stop value : " + newValue)

        if (newValue == 1){
            MiniLab_3_Dispatch.SendToDevice('led',[0x58, 0x7f, 0x7f, 0x7f], midiOutput, context)
        }
        else{
            MiniLab_3_Dispatch.SendToDevice('led',[0x58, 0x14, 0x14, 0x14], midiOutput, context)
        }
    }
}

function PlayReturn(button, midiOutput){
    button.mSurfaceValue.mOnProcessValueChange = function (context, newValue) {
        //console.log("Play value : " + newValue)

        if (newValue == 1){
            MiniLab_3_Dispatch.SendToDevice('led',[0x59, 0x00, 0x7f, 0x00], midiOutput, context)
            MiniLab_3_Var.PLAY_STATUS = 2
        }
        else{
            MiniLab_3_Dispatch.SendToDevice('led',[0x59, 0x00, 0x14, 0x00], midiOutput, context)
            MiniLab_3_Var.PLAY_STATUS = 0
        }


        if (MiniLab_3_Var.OLD_TRACK_NAME !== MiniLab_3_Var.TRACK_NAME){
        
            var screenID = 2
            var line1 = "Tracks"
            var line2 = MiniLab_3_Var.TRACK_NAME

            if (MiniLab_3_Var.TRACK_NAME === "") {
                line2 = MiniLab_3_Var.TRACK_NAME
                line1 = "Select a track"
                screenID = 10
            }
        
            MiniLab_3_Pages.SetPage({page_type : screenID,
                line1 : line1,
                line2 : line2,
                hw_value : 0,
                midiOutput,
                context})
        }

    }
}

function RecordReturn(button, midiOutput){
    button.mSurfaceValue.mOnProcessValueChange = function (context, newValue) {
        //console.log("Rec value : " + newValue)

        if (newValue == 1){
            MiniLab_3_Dispatch.SendToDevice('led',[0x5a, 0x7f, 0x00, 0x00], midiOutput, context)
            MiniLab_3_Var.REC_STATUS = 3
        }
        else{
            MiniLab_3_Dispatch.SendToDevice('led',[0x5a, 0x14, 0x00, 0x00], midiOutput, context)
            MiniLab_3_Var.REC_STATUS = 0
        }

        if (MiniLab_3_Var.OLD_TRACK_NAME !== MiniLab_3_Var.TRACK_NAME){
        
            var screenID = 2
            var line1 = "Tracks"
            var line2 = MiniLab_3_Var.TRACK_NAME

            if (MiniLab_3_Var.TRACK_NAME === "") {
                line2 = MiniLab_3_Var.TRACK_NAME
                line1 = "Select a track"
                screenID = 10
            }
        
            MiniLab_3_Pages.SetPage({page_type : screenID,
                line1 : line1,
                line2 : line2,
                hw_value : 0,
                midiOutput,
                context})
        }

    }
}

function TapReturn(button, midiOutput){
    button.mSurfaceValue.mOnProcessValueChange = function (context, newValue) {
        //console.log("Tap value : " + newValue)

        if (newValue == 1){
            MiniLab_3_Dispatch.SendToDevice('led',[0x5b, 0x7f, 0x7f, 0x7f], midiOutput, context)
        }
        else{
            MiniLab_3_Dispatch.SendToDevice('led',[0x5b, 0x14, 0x14, 0x14], midiOutput, context)
        }
    }
}

function LoopReturn(button, midiOutput){
    button.mSurfaceValue.mOnProcessValueChange = function (context, newValue) {
        //console.log("Loop value : " + newValue)

        if (newValue == 1){
            MiniLab_3_Dispatch.SendToDevice('led',[0x57, 0x7f, 0x32, 0x00], midiOutput, context)
        }
        else{
            MiniLab_3_Dispatch.SendToDevice('led',[0x57, 0x14, 0x05, 0x00], midiOutput, context)
        }
    }
}


function PadAReturn(bank, midiOutput){

    bank.pad1.mSurfaceValue.mOnProcessValueChange = function (context, newValue){

        if (newValue > 0){
            MiniLab_3_Dispatch.SendToDevice('led',[0x34, 0x7f, 0x7f, 0x7f], midiOutput, context)
        }
        else{
            MiniLab_3_Dispatch.SendToDevice('led',[0x34, 0x14, 0x14, 0x14], midiOutput, context)
        }
    }

    bank.pad2.mSurfaceValue.mOnProcessValueChange = function (context, newValue){

        if (newValue > 0){
            MiniLab_3_Dispatch.SendToDevice('led',[0x35, 0x7f, 0x7f, 0x7f], midiOutput, context)
        }
        else{
            MiniLab_3_Dispatch.SendToDevice('led',[0x35, 0x14, 0x14, 0x14], midiOutput, context)
        }
    }

    bank.pad3.mSurfaceValue.mOnProcessValueChange = function (context, newValue){

        if (newValue > 0){
            MiniLab_3_Dispatch.SendToDevice('led',[0x36, 0x7f, 0x7f, 0x7f], midiOutput, context)
        }
        else{
            MiniLab_3_Dispatch.SendToDevice('led',[0x36, 0x14, 0x14, 0x14], midiOutput, context)
        }
    }

    bank.pad4.mSurfaceValue.mOnProcessValueChange = function (context, newValue){

        if (newValue > 0){
            MiniLab_3_Dispatch.SendToDevice('led',[0x37, 0x7f, 0x7f, 0x7f], midiOutput, context)
        }
        else{
            MiniLab_3_Dispatch.SendToDevice('led',[0x37, 0x14, 0x14, 0x14], midiOutput, context)
        }
    }

    bank.pad5.mSurfaceValue.mOnProcessValueChange = function (context, newValue){

        if (newValue > 0){
            MiniLab_3_Dispatch.SendToDevice('led',[0x38, 0x7f, 0x7f, 0x7f], midiOutput, context)
        }
        else{
            MiniLab_3_Dispatch.SendToDevice('led',[0x38, 0x14, 0x14, 0x14], midiOutput, context)
        }
    }

    bank.pad6.mSurfaceValue.mOnProcessValueChange = function (context, newValue){

        if (newValue > 0){
            MiniLab_3_Dispatch.SendToDevice('led',[0x39, 0x7f, 0x7f, 0x7f], midiOutput, context)
        }
        else{
            MiniLab_3_Dispatch.SendToDevice('led',[0x39, 0x14, 0x14, 0x14], midiOutput, context)
        }
    }

    bank.pad7.mSurfaceValue.mOnProcessValueChange = function (context, newValue){

        if (newValue > 0){
            MiniLab_3_Dispatch.SendToDevice('led',[0x3A, 0x7f, 0x7f, 0x7f], midiOutput, context)
        }
        else{
            MiniLab_3_Dispatch.SendToDevice('led',[0x3A, 0x14, 0x14, 0x14], midiOutput, context)
        }
    }

    bank.pad8.mSurfaceValue.mOnProcessValueChange = function (context, newValue){

        if (newValue > 0){
            MiniLab_3_Dispatch.SendToDevice('led',[0x3B, 0x7f, 0x7f, 0x7f], midiOutput, context)
        }
        else{
            MiniLab_3_Dispatch.SendToDevice('led',[0x3B, 0x14, 0x14, 0x14], midiOutput, context)
        }
    }
}

function PadBReturn(bank, midiOutput){

    bank.pad1.mSurfaceValue.mOnProcessValueChange = function (context, newValue){

        if (newValue > 0){
            MiniLab_3_Dispatch.SendToDevice('led',[0x44, 0x7f, 0x7f, 0x7f], midiOutput, context)
        }
        else{
            MiniLab_3_Dispatch.SendToDevice('led',[0x44, 0x14, 0x14, 0x14], midiOutput, context)
        }
    }

    bank.pad2.mSurfaceValue.mOnProcessValueChange = function (context, newValue){

        if (newValue > 0){
            MiniLab_3_Dispatch.SendToDevice('led',[0x45, 0x7f, 0x7f, 0x7f], midiOutput, context)
        }
        else{
            MiniLab_3_Dispatch.SendToDevice('led',[0x45, 0x14, 0x14, 0x14], midiOutput, context)
        }
    }

    bank.pad3.mSurfaceValue.mOnProcessValueChange = function (context, newValue){

        if (newValue > 0){
            MiniLab_3_Dispatch.SendToDevice('led',[0x46, 0x7f, 0x7f, 0x7f], midiOutput, context)
        }
        else{
            MiniLab_3_Dispatch.SendToDevice('led',[0x46, 0x14, 0x14, 0x14], midiOutput, context)
        }
    }

    bank.pad4.mSurfaceValue.mOnProcessValueChange = function (context, newValue){

        if (newValue > 0){
            MiniLab_3_Dispatch.SendToDevice('led',[0x47, 0x7f, 0x7f, 0x7f], midiOutput, context)
        }
        else{
            MiniLab_3_Dispatch.SendToDevice('led',[0x47, 0x14, 0x14, 0x14], midiOutput, context)
        }
    }

    bank.pad5.mSurfaceValue.mOnProcessValueChange = function (context, newValue){

        if (newValue > 0){
            MiniLab_3_Dispatch.SendToDevice('led',[0x48, 0x7f, 0x7f, 0x7f], midiOutput, context)
        }
        else{
            MiniLab_3_Dispatch.SendToDevice('led',[0x48, 0x14, 0x14, 0x14], midiOutput, context)
        }
    }

    bank.pad6.mSurfaceValue.mOnProcessValueChange = function (context, newValue){

        if (newValue > 0){
            MiniLab_3_Dispatch.SendToDevice('led',[0x49, 0x7f, 0x7f, 0x7f], midiOutput, context)
        }
        else{
            MiniLab_3_Dispatch.SendToDevice('led',[0x49, 0x14, 0x14, 0x14], midiOutput, context)
        }
    }

    bank.pad7.mSurfaceValue.mOnProcessValueChange = function (context, newValue){

        if (newValue > 0){
            MiniLab_3_Dispatch.SendToDevice('led',[0x4A, 0x7f, 0x7f, 0x7f], midiOutput, context)
        }
        else{
            MiniLab_3_Dispatch.SendToDevice('led',[0x4A, 0x14, 0x14, 0x14], midiOutput, context)
        }
    }

    bank.pad8.mSurfaceValue.mOnProcessValueChange = function (context, newValue){

        if (newValue > 0){
            MiniLab_3_Dispatch.SendToDevice('led',[0x4B, 0x7f, 0x7f, 0x7f], midiOutput, context)
        }
        else{
            MiniLab_3_Dispatch.SendToDevice('led',[0x4B, 0x14, 0x14, 0x14], midiOutput, context)
        }
    }
}

//-----------------------------------------------------------------------------
// RETURN to require ----------------------------------------------------------
//-----------------------------------------------------------------------------
module.exports = {
	LEDinit,
    LEDReturn,
}
