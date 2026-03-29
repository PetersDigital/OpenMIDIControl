package com.petersdigital.openmidicontrol

import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class MidiParserTest {

    @Test
    fun testUmpHeuristicValidation() = runBlocking {
        val channel = Channel<Pair<Long, Long>>(capacity = 100)
        // 8 bytes: Legacy CC (3 bytes) + Clock (1 byte) + Padding (4 bytes)
        // [0xB0, 0x0A, 0x7F, 0xF8, 0x00, 0x00, 0x00, 0x00]
        val payload = byteArrayOf(0xB0.toByte(), 0x0A.toByte(), 0x7F.toByte(), 0xF8.toByte(), 0x00, 0x00, 0x00, 0x00)

        // Process it. The heuristic inside processMidiPayload checks MT=1 or MT=2.
        // The first byte 0xB0 means MT=0xB. This should not be parsed as UMP.
        // It should fallback to legacy byte stream parsing.
        MidiParser.processMidiPayload(payload, 0, 8, 12345L, false, channel, 0L, emptyMap(), false)

        val parsed = channel.receive()

        // As a legacy CC message, it should inject Group 0, reconstruct the 32-bit UMP equivalent:
        // MT=2, Group=0, Status=0xB0, Data1=0x0A, Data2=0x7F
        val expectedUmp = (0x2L shl 28) or (0x0L shl 24) or (0xB0L shl 16) or (0x0AL shl 8) or 0x7FL
        assertEquals(expectedUmp, parsed.first)
        assertEquals(12345L, parsed.second)
    }

    @Test
    fun testLegacyByteStreamParsingAndFallback() = runBlocking {
        val channel = Channel<Pair<Long, Long>>(capacity = 10)
        // 3 bytes: Standard CC
        val payload = byteArrayOf(0xB0.toByte(), 0x0A.toByte(), 0x7F.toByte())

        MidiParser.processMidiPayload(payload, 0, 3, 1111L, false, channel, 0L, emptyMap(), false)

        val parsed = channel.receive()
        val expectedUmp = (0x2L shl 28) or (0x0L shl 24) or (0xB0L shl 16) or (0x0AL shl 8) or 0x7FL
        assertEquals(expectedUmp, parsed.first)
        assertEquals(1111L, parsed.second)
    }

    @Test
    fun testUmp32BitReconstructionAndGroupPreservation() = runBlocking {
        val channel = Channel<Pair<Long, Long>>(capacity = 10)
        // 4 bytes: Valid UMP MT=2, Group=3, Status=0xB1, CC=10, Val=127
        val payload = byteArrayOf(0x23.toByte(), 0xB1.toByte(), 0x0A.toByte(), 0x7F.toByte())

        MidiParser.processMidiPayload(payload, 0, 4, 2222L, false, channel, 0L, emptyMap(), false)

        val parsed = channel.receive()
        val expectedUmp = (0x2L shl 28) or (0x3L shl 24) or (0xB1L shl 16) or (0x0AL shl 8) or 0x7FL
        assertEquals(expectedUmp, parsed.first)
        assertEquals(2222L, parsed.second)
    }

    @Test
    fun testRealTimeSpamFilter() = runBlocking {
        val channel = Channel<Pair<Long, Long>>(capacity = 10)
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
        val channel = Channel<Pair<Long, Long>>(capacity = 10)
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
        val parsed = channel.receive()
        assertEquals(1600L, parsed.second)
    }
    @Test
    fun testBatchingLoopBounds() = runBlocking {
        // Exceed max size. If capacity is 2000 items (1000 pairs),
        // simulating a flood where the channel has more than the array can hold
        val maxBatchSize = 100 // Test with smaller bound for simplicity
        val channel = Channel<Pair<Long, Long>>(capacity = 200)

        // Push 150 events (exceeding the batch size of 100 Longs = 50 pairs)
        for (i in 0 until 150) {
            channel.trySend(Pair(i.toLong(), i.toLong() * 10))
        }

        val firstEvent = channel.receive()

        // Drain it
        val batch = MidiParser.drainChannelToBatch(firstEvent, channel, maxBatchSize)

        // Should cap exactly at maxBatchSize (100 Longs = 50 Pairs)
        assertEquals(maxBatchSize, batch.size)

        // The channel should still have the remaining 100 items
        var remainingCount = 0
        while (channel.tryReceive().isSuccess) {
            remainingCount++
        }

        // We sent 150. Read 1 as firstEvent. Drained 49 to fill batch. Remaining = 150 - 1 - 49 = 100.
        assertEquals(100, remainingCount)
    }
}
