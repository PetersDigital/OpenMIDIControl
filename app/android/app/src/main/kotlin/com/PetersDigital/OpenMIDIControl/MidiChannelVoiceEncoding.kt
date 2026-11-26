// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
package com.petersdigital.openmidicontrol

internal object MidiChannelVoiceEncoding {
    fun supportsMidi2Controller(word0: Int): Boolean {
        val controller = (word0 ushr 8) and 0xFF
        return when ((word0 ushr 16) and 0xF0) {
            0xE0 -> (word0 and 0xFFFF) == 0
            0xB0 -> (word0 and 0xFF) == 0 && controller in 64..119 && controller !in 96..101
            else -> false
        }
    }

    // Keep the group and channel. Byte-stream destinations strip the UMP header later.
    fun toMidi1Controller(word0: Int, word1: Int): Int {
        val header = (word0 and 0x0FFF0000) or 0x20000000
        return if ((word0 ushr 16) and 0xF0 == 0xE0) {
            val bend = word1 ushr 18
            header or ((bend and 0x7F) shl 8) or (bend ushr 7)
        } else {
            header or (word0 and 0x0000FF00) or (word1 ushr 25)
        }
    }

    fun writeWord(word: Int, buffer: ByteArray, offset: Int = 0) {
        buffer[offset] = (word ushr 24).toByte()
        buffer[offset + 1] = (word ushr 16).toByte()
        buffer[offset + 2] = (word ushr 8).toByte()
        buffer[offset + 3] = word.toByte()
    }
}
