// 	Surface:	KeyLab Essential 3
// 	Developer:	Farès MEZDOUR
// 	Version:	0.1


function DAWConnect(midiOutput, context){
    //console.log("DAW Connected")
    midiOutput.sendMidi(context, [0xf0, 0x00, 0x20, 0x6b, 0x7f, 0x42, 0x02, 0x02, 0x40, 0x6a, 0x21, 0xf7])

}



function DAWDisonnect(midiOutput, context){
    //console.log("DAW Disconnected")
    midiOutput.sendMidi(context, [0xf0, 0x00, 0x20, 0x6b, 0x7f, 0x42, 0x02, 0x02, 0x40, 0x6a, 0x20, 0xf7])

}

function ProgramRequest(midiOutput, context){
    //console.log("Program Request")
    midiOutput.sendMidi(context, [0xf0, 0x00, 0x20, 0x6b, 0x7f, 0x42, 0x01, 0x00, 0x60, 0x01, 0x00, 0xf7])
}



function ArturiaConnect(midiOutput, context){
    midiOutput.sendMidi(context, [0xf0, 0x00, 0x20, 0x6b, 0x7f, 0x42, 0x02, 0x02, 0x40, 0x6a, 0x11, 0xf7])

}



function ArturiaDisonnect(midiOutput, context){
    midiOutput.sendMidi(context, [0xf0, 0x00, 0x20, 0x6b, 0x7f, 0x42, 0x02, 0x02, 0x40, 0x6a, 0x10, 0xf7])

}


//-----------------------------------------------------------------------------
// RETURN to require ----------------------------------------------------------
//-----------------------------------------------------------------------------
module.exports = {
	DAWConnect,
    DAWDisonnect,
    ProgramRequest,
    ArturiaConnect,
    ArturiaDisonnect,
}
