// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
package com.petersdigital.openmidicontrol

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

private class TestIncomingEventsSink : MidiParser.IncomingEventsSink {
    val events = mutableListOf<Long>()

    override fun trySend(packedEvent: Long): Boolean {
        events.add(packedEvent)
        return true
    }
}

class MidiParserTest {

    @Test
    fun testUmpHeuristicValidation() = runBlocking {
        val sink = TestIncomingEventsSink()
        // 8 bytes: Legacy CC (3 bytes) + Clock (1 byte) + Padding (4 bytes)
        // [0xB0, 0x0A, 0x7F, 0xF8, 0x00, 0x00, 0x00, 0x00]
        val payload = byteArrayOf(0xB0.toByte(), 0x0A.toByte(), 0x7F.toByte(), 0xF8.toByte(), 0x00, 0x00, 0x00, 0x00)

        // Process it. The heuristic inside processMidiPayload checks MT=1 or MT=2.
        // The first byte 0xB0 means MT=0xB. This should not be parsed as UMP.
        // It should fallback to legacy byte stream parsing.
        // Input: 12345ms in nanos
        MidiParser.processMidiPayload(payload, 0, 8, 12345_000_000L, false, sink, 0L, LongArray(128), false)

        val packed = sink.events.single()

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
        val sink = TestIncomingEventsSink()
        // 3 bytes: Standard CC
        val payload = byteArrayOf(0xB0.toByte(), 0x0A.toByte(), 0x7F.toByte())

        MidiParser.processMidiPayload(payload, 0, 3, 1111_000_000L, false, sink, 0L, LongArray(128), false)

        val packed = sink.events.single()
        val parsedUmp = (packed shr 32) and 0xFFFFFFFFL
        val parsedTimestamp = packed and 0xFFFFFFFFL
        val expectedUmp = (0x2L shl 28) or (0x0L shl 24) or (0xB0L shl 16) or (0x0AL shl 8) or 0x7FL
        assertEquals(expectedUmp, parsedUmp)
        assertEquals(1111L, parsedTimestamp)
    }

    @Test
    fun testUmp32BitReconstructionAndGroupPreservation() = runBlocking {
        val sink = TestIncomingEventsSink()
        // 4 bytes: Valid UMP MT=2, Group=3, Status=0xB1, CC=10, Val=127
        val payload = byteArrayOf(0x23.toByte(), 0xB1.toByte(), 0x0A.toByte(), 0x7F.toByte())

        MidiParser.processMidiPayload(payload, 0, 4, 2222_000_000L, false, sink, 0L, LongArray(128), false)

        val packed = sink.events.single()
        val parsedUmp = (packed shr 32) and 0xFFFFFFFFL
        val parsedTimestamp = packed and 0xFFFFFFFFL
        val expectedUmp = (0x2L shl 28) or (0x3L shl 24) or (0xB1L shl 16) or (0x0AL shl 8) or 0x7FL
        assertEquals(expectedUmp, parsedUmp)
        assertEquals(2222L, parsedTimestamp)
    }

    @Test
    fun testMultiWordUmpSkipsUnsupportedPacketsWithoutDesync() = runBlocking {
        val sink = TestIncomingEventsSink()
        // First packet: MT=4 (2-word message) with payload ignored
        // Second packet: MT=2 CC message should still be parsed correctly after skip.
        val payload = byteArrayOf(
            0x40.toByte(), 0x00.toByte(), 0x00.toByte(), 0x00.toByte(),
            0x00.toByte(), 0x00.toByte(), 0x00.toByte(), 0x00.toByte(),
            0x20.toByte(), 0xB0.toByte(), 0x0A.toByte(), 0x7F.toByte()
        )

        MidiParser.processMidiPayload(payload, 0, payload.size, 3333_000_000L, false, sink, 0L, LongArray(128), false)

        val packed = sink.events.single()
        val parsedUmp = (packed shr 32) and 0xFFFFFFFFL
        val parsedTimestamp = packed and 0xFFFFFFFFL
        val expectedUmp = (0x2L shl 28) or (0x0L shl 24) or (0xB0L shl 16) or (0x0AL shl 8) or 0x7FL
        assertEquals(expectedUmp, parsedUmp)
        assertEquals(3333L, parsedTimestamp)
    }

    @Test
    fun testRealTimeSpamFilter() = runBlocking {
        val sink = TestIncomingEventsSink()
        // 4 bytes: UMP MT=1, Group=0, Status=0xF8 (Timing Clock), 0x00, 0x00
        val clockPayload = byteArrayOf(0x10.toByte(), 0xF8.toByte(), 0x00, 0x00)
        // 4 bytes: UMP MT=1, Group=0, Status=0xFE (Active Sensing), 0x00, 0x00
        val activeSensingPayload = byteArrayOf(0x10.toByte(), 0xFE.toByte(), 0x00, 0x00)

        MidiParser.processMidiPayload(clockPayload, 0, 4, 3333L, false, sink, 0L, LongArray(128), false)
        MidiParser.processMidiPayload(activeSensingPayload, 0, 4, 3334L, false, sink, 0L, LongArray(128), false)

        assertTrue("Sink should be empty after dropping spam messages", sink.events.isEmpty())
    }

    @Test
    fun testBidirectionalEchoSuppression() = runBlocking {
        val sink = TestIncomingEventsSink()
        // UMP CC (MT=2, Group=0, Status=0xB0, CC=10, Val=127)
        val payload = byteArrayOf(0x20.toByte(), 0xB0.toByte(), 0x0A.toByte(), 0x7F.toByte())

        // Index for Status 0xB0, CC 0x0A: (((0xB0 ushr 4) - 8) shl 11) or ((0xB0 and 0x0F) shl 7) or 0x0A
        // = (3 << 11) | 0 | 10 = 6144 + 10 = 6154
        val index = 6154
        val lastSentTime = LongArray(16384).apply { this[index] = 1000L }
        val suppressionWindowNs = 500L

        // Attempt to receive Virtual MIDI at time 1200 (within suppression window 1000 + 500 = 1500)
        MidiParser.processMidiPayload(payload, 0, 4, 1200L, true, sink, suppressionWindowNs, lastSentTime, false)

        assertTrue("Sink should be empty due to bidirectional echo suppression", sink.events.isEmpty())

        // Attempt to receive Virtual MIDI at time 1600 (outside suppression window)
        // Input: 1600ms in nanos
        MidiParser.processMidiPayload(payload, 0, 4, 1600_000_000L, true, sink, suppressionWindowNs, lastSentTime, false)
        val packed = sink.events.single()
        val parsedTimestamp = packed and 0xFFFFFFFFL
        assertEquals(1600L, parsedTimestamp)
    }
    @Test
    fun testBatchingLoopBounds() = runBlocking {
        // Exceed max size. If capacity is 2000 items,
        // simulating a flood where the buffer has more than the batch array can hold
        val buffer = MidiParser.IncomingEventsBuffer(200, null)

        // Push 150 packed events (each packed as Long: UMP|timestamp)
        for (i in 0 until 150) {
            val ump = i.toLong()
            val timestamp = i.toLong() * 10
            val packed = (ump shl 32) or (timestamp and 0xFFFFFFFFL)
            buffer.trySend(packed)
        }

        val batch = LongArray(2000)

        // Drain it into the provided reusable buffer.
        buffer.drainToBatch(batch)

        // Buffer contract: batch[0] = used data longs, remainder is [ump, ts, ump, ts, ...]
        assertEquals(2000, batch.size)
        assertEquals(300L, batch[0])

        // The buffer should be empty now
        assertTrue(buffer.isEmpty())
    }
}
