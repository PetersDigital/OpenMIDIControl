// 	Surface:	KeyLab Essential 3
// 	Developer:	Farès MEZDOUR
// 	Version:	0.1

var KeyLabEssential_mk3_Screen = require('./MiniLab_3_Screen')
var KeyLab_Essential_mk3_Dispatch = require('./MiniLab_3_Dispatch')





function SetPage(params){
    //console.log("Screen Init")

    var string = []

    if (params.page_type === 2) {
        string = KeyLabEssential_mk3_Screen.Screen2(params)
    }
    else if (params.page_type === 3) {
        string = KeyLabEssential_mk3_Screen.Screen3(params)
    }
    else if (params.page_type === 4) {
        string = KeyLabEssential_mk3_Screen.Screen4(params)
    }
    else if (params.page_type === 5) {
        string = KeyLabEssential_mk3_Screen.Screen5(params)
    }
    else if (params.page_type === 10) {
        string = KeyLabEssential_mk3_Screen.Screen10(params)
    }



    var feedback_type = 'screen'

    KeyLab_Essential_mk3_Dispatch.SendToDevice(feedback_type, string, params.midiOutput, params.context)

}


function SetParamValue(params){

    var feedback_type = 'param'
    var string = []
    string = string.concat(params.ID + 7).concat([0x00]).concat(params.value_hw)
    console.log(string.toString())
    KeyLab_Essential_mk3_Dispatch.SendToDevice(feedback_type, string, params.midiOutput, params.context)

}



//-----------------------------------------------------------------------------
// RETURN to require ----------------------------------------------------------
//-----------------------------------------------------------------------------
module.exports = {
	SetPage,
    SetParamValue,
}
