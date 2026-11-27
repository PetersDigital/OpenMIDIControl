// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
package com.petersdigital.openmidicontrol

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MidiChannelVoiceEncodingTest {
    @Test
    fun nativePacketsRetainLowBitsInNetworkByteOrder() {
        val packet = ByteArray(8)
        MidiChannelVoiceEncoding.writeWord(0x43E80000, packet)
        for (lowBits in 1..2) {
            MidiChannelVoiceEncoding.writeWord(0x80000000.toInt() or lowBits, packet, 4)
            assertArrayEquals(
                byteArrayOf(0x43, 0xE8.toByte(), 0, 0, 0x80.toByte(), 0, 0, lowBits.toByte()),
                packet
            )
        }
    }

    @Test
    fun fallbackRetainsPitchBendCenterAndLegacyByteOrder() {
        val word0 = 0x43E80000
        assertEquals(0x23E80000, MidiChannelVoiceEncoding.toMidi1Controller(word0, 0))
        assertEquals(0x23E80040, MidiChannelVoiceEncoding.toMidi1Controller(word0, 0x80000001.toInt()))
        assertEquals(0x23E87F7F, MidiChannelVoiceEncoding.toMidi1Controller(word0, -1))
    }

    @Test
    fun fallbackConvertsOrdinaryCcAndProtectsControllerSequences() {
        val word0 = 0x40B04A00
        assertTrue(MidiChannelVoiceEncoding.supportsMidi2Controller(word0))
        assertEquals(0x20B04A40, MidiChannelVoiceEncoding.toMidi1Controller(word0, 0x80000001.toInt()))
        assertEquals(0x20B04A7F, MidiChannelVoiceEncoding.toMidi1Controller(word0, -1))
        for (cc in intArrayOf(0, 6, 32, 38, 96, 101, 120, 127)) {
            assertFalse(MidiChannelVoiceEncoding.supportsMidi2Controller(0x40B00000 or (cc shl 8)))
        }
    }
}
