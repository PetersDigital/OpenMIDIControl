// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
package com.petersdigital.openmidicontrol

import kotlinx.coroutines.channels.SendChannel
import java.util.concurrent.atomic.AtomicLong

object MidiParser {

    interface IncomingEventsSink {
        fun trySend(packedEvent: Long): Boolean
    }

    class IncomingEventsBuffer(
        capacity: Int = 2048,
        private val notifier: SendChannel<Unit>? = null
    ) : IncomingEventsSink {
        private val headPointer = AtomicLong(0)
        private val tailPointer = AtomicLong(0)
        @Volatile private var isFull = false
        private val ringBuffer = LongArray(capacity)

        @Synchronized
        override fun trySend(packedEvent: Long): Boolean {
            val currentTail = tailPointer.get()
            val nextTail = (currentTail + 1) % ringBuffer.size
            if (nextTail == headPointer.get()) {
                isFull = true
                return false
            }
            ringBuffer[currentTail.toInt()] = packedEvent
            tailPointer.set(nextTail)
            notifier?.trySend(Unit)
            return true
        }

        fun drainToBatch(batch: LongArray) {
            var writeIndex = 1
            var usedDataLongs = 0

            var currentHead = headPointer.get()
            val currentTail = tailPointer.get()

            while (currentHead != currentTail && writeIndex + 1 < batch.size) {
                val packed = ringBuffer[currentHead.toInt()]
                batch[writeIndex++] = (packed shr 32) and 0xFFFFFFFFL
                batch[writeIndex++] = packed and 0xFFFFFFFFL
                currentHead = (currentHead + 1) % ringBuffer.size
                usedDataLongs += 2
            }

            headPointer.set(currentHead)
            batch[0] = usedDataLongs.toLong()
        }

        fun isEmpty(): Boolean = headPointer.get() == tailPointer.get()
    }

    /**
     * Reconstructs 32-bit UMP integers or handles legacy byte streams,
     * applies bitwise filtering (dropping Real-Time spam like 0xF8/0xFE),
     * and queues packed UMP+timestamp values to the given sink.
     * Packing: upper 32 bits = UMP, lower 32 bits = timestamp (lower 32 bits of nanosecond time).
     * This eliminates Pair<Long, Long> allocation churn (~5,760 bytes/sec at 50-120 events/sec).
     */
    fun processMidiPayload(
        msg: ByteArray,
        offset: Int,
        count: Int,
        timestamp: Long,
        isVirtual: Boolean,
        incomingEventsSink: IncomingEventsSink,
        suppressionWindowNs: Long,
        lastSentTime: LongArray,
        isDebug: Boolean = false,
        isUmpTransport: Boolean? = null
    ) {
        if (offset < 0 || count < 0 || offset > msg.size - count) return

        // Callers with a known transport bypass the compatibility heuristic.
        val isUmp = isUmpTransport ?: (
            count >= 4 && count % 4 == 0 && ((msg[offset].toInt() and 0xFF) ushr 4) <= 0x5
        )

        if (isUmp) {
            UmpStreamDecoder().read(msg, offset, count, timestamp) { word0, _, packetTimestamp ->
                processSingleUmp(
                    word0, packetTimestamp, isVirtual, incomingEventsSink, suppressionWindowNs, lastSentTime
                )
            }
        } else {
            // Process Legacy Byte Stream (Fallback)
            var i = offset
            while (i < offset + count) {
                val statusByte = msg[i].toInt() and 0xFF

                // Real-time messages can be 1 byte
                if (statusByte == 0xF8 || statusByte == 0xFE) {
                    i += 1
                    continue
                }

                // Check if we have enough bytes for a 3-byte message (Note, CC, Pitch Bend)
                val statusNibble = statusByte and 0xF0
                if (i + 2 < offset + count && (statusNibble == 0x80 || statusNibble == 0x90 || statusNibble == 0xB0 || statusNibble == 0xE0)) {
                    val data1 = msg[i + 1].toInt() and 0xFF
                    val data2 = msg[i + 2].toInt() and 0xFF
                    forwardMidiEvent(0, statusByte, data1, data2, timestamp, isVirtual, incomingEventsSink, suppressionWindowNs, lastSentTime)
                    i += 3
                } else {
                    // Unhandled legacy message or incomplete buffer; just advance by 1 to recover
                    i += 1
            }
        }
    }
}

    /**
     * Processes a single 32-bit UMP word.
     * Extracts message type, group, and status to forward valid MIDI 1.0 voice messages.
     */
    fun processSingleUmp(
        umpInt: Int,
        timestamp: Long,
        isVirtual: Boolean,
        incomingEventsSink: IncomingEventsSink,
        suppressionWindowNs: Long,
        lastSentTime: LongArray
    ) {
        val messageType = (umpInt ushr 28) and 0xF
        if (messageType == 0x1) {
            // MT 0x1: System Real-Time / System Common
            val status = (umpInt ushr 16) and 0xFF
            // Drop Timing Clock (0xF8) and Active Sensing (0xFE).
            if (status == 0xF8 || status == 0xFE) {
                return
            }
        } else if (messageType == 0x2) {
            // MT 0x2: MIDI 1.0 Channel Voice
            val group = (umpInt ushr 24) and 0xF
            val status = (umpInt ushr 16) and 0xFF
            val statusNibble = status and 0xF0

            if (statusNibble == 0x80 || statusNibble == 0x90 || statusNibble == 0xB0 || statusNibble == 0xE0) {
                val data1 = (umpInt ushr 8) and 0xFF
                val data2 = umpInt and 0xFF
                forwardMidiEvent(group, status, data1, data2, timestamp, isVirtual, incomingEventsSink, suppressionWindowNs, lastSentTime)
            }
        }
    }

    private fun forwardMidiEvent(
        group: Int,
        status: Int,
        data1: Int,
        data2: Int,
        timestamp: Long,
        isVirtual: Boolean,
        incomingEventsSink: IncomingEventsSink,
        suppressionWindowNs: Long,
        lastSentTime: LongArray
    ) {
        if (isVirtual) {
            // Bidirectional Feedback Loop Prevention
            if (data1 in 0..127) {
                val index = midiSendSlot(status, data1)
                if (index in lastSentTime.indices) {
                    val lastTime = lastSentTime[index]
                    val timeDiff = timestamp - lastTime

                    if (lastTime != 0L && timeDiff < suppressionWindowNs) {
                        // Ignore message from host if we recently sent *any* value for this event.
                        // This prevents delayed echoes from older values causing oscillation during rapid movement.
                        return
                    }
                }
            }
        }


        // Reconstruct the 32-bit UMP (MT=0x2 Channel Voice) using the original group and status byte.
        // Explicitly mask each component to prevent sign extension when converting to Long.
        val umpInt = ((0x2L and 0x0FL) shl 28) or 
                     ((group.toLong() and 0x0FL) shl 24) or 
                     ((status.toLong() and 0xFFL) shl 16) or 
                     ((data1.toLong() and 0xFFL) shl 8) or 
                     (data2.toLong() and 0xFFL)
 
        // Pack UMP (upper 32 bits) + timestamp in ms (lower 32 bits) into a single Long.
        // Rule: Mask both the 32-bit payload and the 32-bit timestamp with 0xFFFFFFFFL 
        // before shifting to prevent sign extension from corrupting the combined payload.
        val packed = ((umpInt and 0xFFFFFFFFL) shl 32) or ((timestamp / 1_000_000L) and 0xFFFFFFFFL)
        incomingEventsSink.trySend(packed)
    }
}
