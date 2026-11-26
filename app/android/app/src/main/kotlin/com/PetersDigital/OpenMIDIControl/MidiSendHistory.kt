// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

package com.petersdigital.openmidicontrol

private const val MIDI_SEND_SLOT_COUNT = 16_384

internal fun midiSendSlot(status: Int, data1: Int): Int {
    val messageType = status ushr 4
    // Pitch bend has one address per channel. Its first byte is part of the value.
    val address = if (messageType == 0xE) 0 else data1
    return ((messageType - 8) shl 11) or ((status and 0x0F) shl 7) or address
}

internal class MidiSendHistory(
    private val suppressionWindowNs: Long,
    private val rateLimitNs: Long,
) {
    private val lastSentValue = IntArray(MIDI_SEND_SLOT_COUNT) { -1 }
    val lastSentTime = LongArray(MIDI_SEND_SLOT_COUNT)

    fun clear() {
        lastSentValue.fill(-1)
        lastSentTime.fill(0)
    }

    fun shouldSend(
        status: Int,
        data1: Int,
        data2: Int,
        isFinal: Boolean,
        nowNs: Long,
    ): Boolean {
        if (data1 !in 0..127) return false
        val index = midiSendSlot(status, data1)
        if (index !in lastSentTime.indices) return true

        val value = if ((status and 0xF0) == 0xE0) (data2 shl 7) or data1 else data2
        val previousValue = lastSentValue[index]
        if (!isFinal && previousValue >= 0) {
            val elapsed = nowNs - lastSentTime[index]
            if (elapsed < rateLimitNs ||
                (value == previousValue && elapsed < suppressionWindowNs)
            ) {
                return false
            }
        }

        lastSentValue[index] = value
        lastSentTime[index] = nowNs
        return true
    }
}
