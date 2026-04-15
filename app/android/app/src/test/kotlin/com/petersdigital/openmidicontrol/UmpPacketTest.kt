// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
package com.petersdigital.openmidicontrol

import org.junit.Assert.assertArrayEquals
import org.junit.Test

class UmpPacketTest {

    @Test
    fun testBuildUmpCcPacketProducesValidUmpBytes() {
        val packet = buildUmpCcPacket(cc = 1, value = 64)
        assertArrayEquals(
            byteArrayOf(0x20.toByte(), 0xB0.toByte(), 0x01.toByte(), 0x40.toByte()),
            packet
        )
    }
}
