// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
package com.petersdigital.openmidicontrol

/**
 * Frames network-byte-order UMP from a single, ordered port stream.
 * Create a new decoder when opening a port so partial packets cannot survive reconnect.
 */
internal class UmpStreamDecoder {
    private var word = 0
    private var byteCount = 0
    private var packetWords = 0
    private var wordsRead = 0
    private var firstWord = 0
    private var secondWord = 0
    private var packetTimestamp = 0L

    fun read(
        bytes: ByteArray,
        offset: Int,
        count: Int,
        timestamp: Long,
        onChannelVoice: (word0: Int, word1: Int, timestamp: Long) -> Unit
    ) {
        if (offset < 0 || count < 0 || offset > bytes.size - count) return

        for (index in offset until offset + count) {
            if (wordsRead == 0 && byteCount == 0) {
                packetTimestamp = timestamp
            }
            word = (word shl 8) or (bytes[index].toInt() and 0xFF)
            byteCount++
            if (byteCount < 4) continue

            when (wordsRead) {
                0 -> {
                    firstWord = word
                    secondWord = 0
                    packetWords = WORD_COUNTS[word ushr 28]
                }
                1 -> secondWord = word
            }
            wordsRead++
            word = 0
            byteCount = 0
            if (wordsRead == packetWords) {
                wordsRead = 0
                when (firstWord ushr 28) {
                    0x2, 0x4 -> onChannelVoice(firstWord, secondWord, packetTimestamp)
                }
            }
        }
    }

    private companion object {
        // M2-104, Table 4. Reserved types also have a defined packet length.
        val WORD_COUNTS = intArrayOf(1, 1, 1, 2, 2, 4, 1, 1, 2, 2, 2, 3, 3, 4, 4, 4)
    }
}
