// 	Surface:	KeyLab Essential 3
// 	Developer:	Farès MEZDOUR
// 	Version:	0.1


function SendToDevice(feedback_type, msg, midiOutput, context) {
    //console.log("Message sent")

    var data_control = []

    if (feedback_type === 'screen'){
        data_control = [0x04, 0x02, 0x60]
    }
    else if (feedback_type === 'led'){
        data_control = [0x02, 0x02, 0x16]
    }
    else if (feedback_type === 'param'){
        data_control = [0x21, 0x10, 0x00]
    }

    var string = [0xf0, 0x00, 0x20, 0x6b, 0x7f, 0x42].concat(data_control).concat(msg).concat(0xf7)
    // console.log(string.toString())
    midiOutput.sendMidi(context, string)
}







//-----------------------------------------------------------------------------
// RETURN to require ----------------------------------------------------------
//-----------------------------------------------------------------------------
module.exports = {
	SendToDevice,
}
