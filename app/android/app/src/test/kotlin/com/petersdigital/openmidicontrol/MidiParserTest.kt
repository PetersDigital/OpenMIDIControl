// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
package com.petersdigital.openmidicontrol

import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class MidiParserTest {

    @Test
    fun testUmpHeuristicValidation() = runBlocking {
        val channel = Channel<Long>(capacity = 100)
        // 8 bytes: Legacy CC (3 bytes) + Clock (1 byte) + Padding (4 bytes)
        // [0xB0, 0x0A, 0x7F, 0xF8, 0x00, 0x00, 0x00, 0x00]
        val payload = byteArrayOf(0xB0.toByte(), 0x0A.toByte(), 0x7F.toByte(), 0xF8.toByte(), 0x00, 0x00, 0x00, 0x00)

        // Process it. The heuristic inside processMidiPayload checks MT=1 or MT=2.
        // The first byte 0xB0 means MT=0xB. This should not be parsed as UMP.
        // It should fallback to legacy byte stream parsing.
        MidiParser.processMidiPayload(payload, 0, 8, 12345L, false, channel, 0L, emptyMap(), false)

        val packed = channel.receive()

        // Unpack: upper 32 bits = UMP, lower 32 bits = timestamp
        val parsedUmp = (packed shr 32) and 0xFFFFFFFFL
        val parsedTimestamp = packed and 0xFFFFFFFFL

        // As a legacy CC message, it should inject Group 0, reconstruct the 32-bit UMP equivalent:
        // MT=2, Group=0, Status=0xB0, Data1=0x0A, Data2=0x7F
        val expectedUmp = (0x2L shl 28) or (0x0L shl 24) or (0xB0L shl 16) or (0x0AL shl 8) or 0x7FL
        assertEquals(expectedUmp, parsedUmp)
        assertEquals(12345L, parsedTimestamp)
    }

    @Test
    fun testLegacyByteStreamParsingAndFallback() = runBlocking {
        val channel = Channel<Long>(capacity = 10)
        // 3 bytes: Standard CC
        val payload = byteArrayOf(0xB0.toByte(), 0x0A.toByte(), 0x7F.toByte())

        MidiParser.processMidiPayload(payload, 0, 3, 1111L, false, channel, 0L, emptyMap(), false)

        val packed = channel.receive()
        val parsedUmp = (packed shr 32) and 0xFFFFFFFFL
        val parsedTimestamp = packed and 0xFFFFFFFFL
        val expectedUmp = (0x2L shl 28) or (0x0L shl 24) or (0xB0L shl 16) or (0x0AL shl 8) or 0x7FL
        assertEquals(expectedUmp, parsedUmp)
        assertEquals(1111L, parsedTimestamp)
    }

    @Test
    fun testUmp32BitReconstructionAndGroupPreservation() = runBlocking {
        val channel = Channel<Long>(capacity = 10)
        // 4 bytes: Valid UMP MT=2, Group=3, Status=0xB1, CC=10, Val=127
        val payload = byteArrayOf(0x23.toByte(), 0xB1.toByte(), 0x0A.toByte(), 0x7F.toByte())

        MidiParser.processMidiPayload(payload, 0, 4, 2222L, false, channel, 0L, emptyMap(), false)

        val packed = channel.receive()
        val parsedUmp = (packed shr 32) and 0xFFFFFFFFL
        val parsedTimestamp = packed and 0xFFFFFFFFL
        val expectedUmp = (0x2L shl 28) or (0x3L shl 24) or (0xB1L shl 16) or (0x0AL shl 8) or 0x7FL
        assertEquals(expectedUmp, parsedUmp)
        assertEquals(2222L, parsedTimestamp)
    }

    @Test
    fun testMultiWordUmpSkipsUnsupportedPacketsWithoutDesync() = runBlocking {
        val channel = Channel<Long>(capacity = 10)
        // First packet: MT=4 (2-word message) with payload ignored
        // Second packet: MT=2 CC message should still be parsed correctly after skip.
        val payload = byteArrayOf(
            0x40.toByte(), 0x00.toByte(), 0x00.toByte(), 0x00.toByte(),
            0x00.toByte(), 0x00.toByte(), 0x00.toByte(), 0x00.toByte(),
            0x20.toByte(), 0xB0.toByte(), 0x0A.toByte(), 0x7F.toByte()
        )

        MidiParser.processMidiPayload(payload, 0, payload.size, 3333L, false, channel, 0L, emptyMap(), false)

        val packed = channel.receive()
        val parsedUmp = (packed shr 32) and 0xFFFFFFFFL
        val parsedTimestamp = packed and 0xFFFFFFFFL
        val expectedUmp = (0x2L shl 28) or (0x0L shl 24) or (0xB0L shl 16) or (0x0AL shl 8) or 0x7FL
        assertEquals(expectedUmp, parsedUmp)
        assertEquals(3333L, parsedTimestamp)
    }

    @Test
    fun testRealTimeSpamFilter() = runBlocking {
        val channel = Channel<Long>(capacity = 10)
        // 4 bytes: UMP MT=1, Group=0, Status=0xF8 (Timing Clock), 0x00, 0x00
        val clockPayload = byteArrayOf(0x10.toByte(), 0xF8.toByte(), 0x00, 0x00)
        // 4 bytes: UMP MT=1, Group=0, Status=0xFE (Active Sensing), 0x00, 0x00
        val activeSensingPayload = byteArrayOf(0x10.toByte(), 0xFE.toByte(), 0x00, 0x00)

        MidiParser.processMidiPayload(clockPayload, 0, 4, 3333L, false, channel, 0L, emptyMap(), false)
        MidiParser.processMidiPayload(activeSensingPayload, 0, 4, 3334L, false, channel, 0L, emptyMap(), false)

        assertTrue("Channel should be empty after dropping spam messages", channel.isEmpty)
    }

    @Test
    fun testBidirectionalEchoSuppression() = runBlocking {
        val channel = Channel<Long>(capacity = 10)
        // UMP CC
        val payload = byteArrayOf(0x20.toByte(), 0xB0.toByte(), 0x0A.toByte(), 0x7F.toByte())

        // Simulate sent value at time 1000
        val lastSentTime = mapOf(0x0A to 1000L)
        val suppressionWindowNs = 500L

        // Attempt to receive Virtual MIDI at time 1200 (within suppression window 1000 + 500 = 1500)
        MidiParser.processMidiPayload(payload, 0, 4, 1200L, true, channel, suppressionWindowNs, lastSentTime, false)

        assertTrue("Channel should be empty due to bidirectional echo suppression", channel.isEmpty)

        // Attempt to receive Virtual MIDI at time 1600 (outside suppression window)
        MidiParser.processMidiPayload(payload, 0, 4, 1600L, true, channel, suppressionWindowNs, lastSentTime, false)
        val packed = channel.receive()
        val parsedTimestamp = packed and 0xFFFFFFFFL
        assertEquals(1600L, parsedTimestamp)
    }
    @Test
    fun testBatchingLoopBounds() = runBlocking {
        // Exceed max size. If capacity is 2000 items,
        // simulating a flood where the channel has more than the array can hold
        val channel = Channel<Long>(capacity = 200)

        // Push 150 packed events (each packed as Long: UMP|timestamp)
        for (i in 0 until 150) {
            val ump = i.toLong()
            val timestamp = i.toLong() * 10
            val packed = (ump shl 32) or (timestamp and 0xFFFFFFFFL)
            channel.trySend(packed)
        }

        val firstEvent = channel.receive()

        // Drain it (batch size is fixed at 2000 Longs)
        val batch = MidiParser.drainChannelToBatch(firstEvent, channel)

        // Reused fixed-size buffer contract:
        // batch[0] = used data longs, remainder is [ump, ts, ump, ts, ...]
        assertEquals(2000, batch.size)
        assertEquals(300L, batch[0])

        // The channel should be empty now
        var remainingCount = 0
        while (channel.tryReceive().isSuccess) {
            remainingCount++
        }

        // We sent 150. Read 1 as firstEvent. Drained remaining 149. Remaining = 0.
        assertEquals(0, remainingCount)
    }
}
