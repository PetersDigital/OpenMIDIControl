// 	Surface:	KeyLab Essential 3
// 	Developer:	Farès MEZDOUR
// 	Version:	0.1


var MiniLab_3_LED = require('./MiniLab_3_LED')
var MiniLab_3_Var = require('./MiniLab_3_Var')



function _get_line_bytes(str){

    var line_bytes = []
    for (var i=0; i<str.length; i++){
        line_bytes = line_bytes.concat(str.charCodeAt(i))
        //console.log(line_bytes[i].toString(16))
    }
    return line_bytes
}

function _get_int_bytes(int){

    var bytes = int.toString(16)

    return bytes
}



// 2L //
function Screen2(params) {

    var string = []
    var data_control = [0x1F, 0x02, 0x01, 0x00]
    var data_line1 = [0x01].concat(_get_line_bytes(params.line1)).concat(0x00)
    var data_line2 = [0x02].concat(_get_line_bytes(params.line2)).concat(0x00)

    if (params.transient==true) {
        string = string.concat(data_control).concat(data_line1).concat(data_line2).concat(0x01)
    }
    else {
        string = string.concat(data_control).concat(data_line1).concat(data_line2).concat(0x00)
    }

    return string

}

// K //
function Screen3(params) {

    var string = []
    var data_control = [0x1F, 0x03, 0x02, params.hw_value, 0x00, 0x00]
    var data_line1 = [0x01].concat(_get_line_bytes(params.line1)).concat(0x00)
    var data_line2 = [0x02].concat(_get_line_bytes(params.line2)).concat(0x00)


    string = string.concat(data_control).concat(data_line1).concat(data_line2)


    return string

}

// F //
function Screen4(params) {

    var string = []
    var data_control = [0x1F, 0x04, 0x02, params.hw_value, 0x00, 0x00]
    var data_line1 = [0x01].concat(_get_line_bytes(params.line1)).concat(0x00)
    var data_line2 = [0x02].concat(_get_line_bytes(params.line2)).concat(0x00)

    string = string.concat(data_control).concat(data_line1).concat(data_line2)

    return string

}

// P //
function Screen5(params) {

    var string = []
    var data_control = [0x1F, 0x05, 0x01, params.hw_value, 0x00, 0x00]
    var data_line1 = [0x01].concat(_get_line_bytes(params.line1)).concat(0x00)
    var data_line2 = [0x02].concat(_get_line_bytes(params.line2)).concat(0x00)

    string = string.concat(data_control).concat(data_line1).concat(data_line2)

    return string

}

// Picto //
function Screen10(params) {


    var string = []
    var data_control = [0x1F, 0x07, 0x01, MiniLab_3_Var.REC_STATUS.toString(16), MiniLab_3_Var.PLAY_STATUS.toString(16), 0x01, 0x00]
    var data_line1 = [0x01].concat(_get_line_bytes(params.line1)).concat(0x00)
    var data_line2 = [0x02].concat(_get_line_bytes(params.line2)).concat(0x00)

    string = string.concat(data_control).concat(data_line1).concat(data_line2)

    return string

}






// Test //
function ScreenTest(params) {

    var debut = [0x11, 0x01]
    var text = _get_line_bytes("Test")
    //var text = [0x33, 0x33]
    var fin = [0x00, 0x00]

    var string = debut.concat(text).concat(fin)

    // for (var i=0; i<string.length; i++){
    //     console.log("" + string[i])
    // }


    return string


}


// Clear Screen ##
function ClearScreen(params) {

    var string = []
    var data_control = [0x61]

    string = string.concat(data_control)

    return string 

}

//-----------------------------------------------------------------------------
// RETURN to require ----------------------------------------------------------
//-----------------------------------------------------------------------------
module.exports = {
    Screen2,
    Screen3,
    Screen4,
    Screen5,
    Screen10,
    ClearScreen,
    ScreenTest,
    _get_int_bytes,
    _get_line_bytes,
}
