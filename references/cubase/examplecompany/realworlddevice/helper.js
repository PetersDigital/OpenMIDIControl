
function make_Sysex_displayActivateLayoutByIndex(layoutIndex) {
    return [0xf0, 0x00, 0x20, 0x29, 0x02, 0x0a, 0x01,
        0x01, layoutIndex,
    0xf7]
}

function make_Sysex_displayActivateLayoutKnob() {
    return make_Sysex_displayActivateLayoutByIndex(0x01)
}

function make_Sysex_displaySetTextOfColumn(columnIndex, textFieldIndex, textString) {
    var data = [0xf0, 0x00, 0x20, 0x29, 0x02, 0x0a, 0x01,
        0x02, columnIndex, 0x01, textFieldIndex]

    for(var i = 0; i < textString.length; ++i)
        data.push(textString.charCodeAt(i))

    data.push(0)
    data.push(0xf7)

    return data
}

function make_Sysex_setDisplayValueOfColumn(columnIndex, objectIndex, value) {
    return [0xf0, 0x00, 0x20, 0x29, 0x02, 0x0a, 0x01,
        0x02, columnIndex, 0x03, objectIndex, value, 0xf7]
}

function make_Sysex_setDisplayColorOfColumn(columnIndex, objectIndex, r, g, b) {
    return [0xf0, 0x00, 0x20, 0x29, 0x02, 0x0a, 0x01,
        0x02, columnIndex, 0x04, objectIndex, r, g, b, 0xf7]
}

function make_Sysex_setLEDColor(ledIndex, r, g, b) {
    return [0xf0, 0x00, 0x20, 0x29, 0x02, 0x0a, 0x01,
        0x03, ledIndex, 0x01, r, g, b,
    0xf7]
}

/**
 * @param {MR_ActiveDevice} activeDevice
 * @param {MR_DeviceMidiOutput} outPort
 */
function resetDisplay(activeDevice, outPort) {
    outPort.sendMidi(activeDevice, make_Sysex_displayActivateLayoutKnob())
    for(var i = 0; i < 8; ++i) {
        for(var k = 0; k < 3; ++k) {
            outPort.sendMidi(activeDevice, make_Sysex_displaySetTextOfColumn(i, k, ""))
            outPort.sendMidi(activeDevice, make_Sysex_setDisplayColorOfColumn(i, k, 127, 127, 127))
        }
    }
}

module.exports = {
    sysex: {
        displayActivateLayoutByIndex: make_Sysex_displayActivateLayoutByIndex,
        displayActivateLayoutKnob: make_Sysex_displayActivateLayoutKnob,
        displaySetTextOfColumn: make_Sysex_displaySetTextOfColumn,
        setDisplayValueOfColumn: make_Sysex_setDisplayValueOfColumn,
        setDisplayColorOfColumn: make_Sysex_setDisplayColorOfColumn,
        setLEDColor: make_Sysex_setLEDColor
    },
    display: {
        reset: resetDisplay
    }
}
