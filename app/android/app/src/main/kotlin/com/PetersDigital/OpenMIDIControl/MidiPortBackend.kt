// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
package com.petersdigital.openmidicontrol

interface MidiPortBackend {
    val portId: String
    val deviceName: String
    fun send(msg: ByteArray, offset: Int, count: Int, timestamp: Long)
    fun startReceiving(onMessageReceived: (ByteArray, Int, Int, Long) -> Unit)
    fun close()
}
