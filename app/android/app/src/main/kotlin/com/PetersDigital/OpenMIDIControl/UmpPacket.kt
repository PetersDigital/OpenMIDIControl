// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
package com.petersdigital.openmidicontrol

fun buildUmpCcPacket(cc: Int, value: Int, group: Int = 0, status: Int = 0xB0): ByteArray {
    require(cc in 0..0x7F) { "CC number must be 0..127" }
    require(value in 0..0x7F) { "CC value must be 0..127" }
    require(group in 0..0x0F) { "UMP group must be 0..15" }
    require(status in 0xB0..0xBF) { "Status must be a Control Change status byte" }

    val ump = (0x2 shl 28) or (group shl 24) or (status shl 16) or (cc shl 8) or value
    return byteArrayOf(
        (ump ushr 24).toByte(),
        (ump ushr 16).toByte(),
        (ump ushr 8).toByte(),
        ump.toByte(),
    )
}
