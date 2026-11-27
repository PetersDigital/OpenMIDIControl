// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
package com.petersdigital.openmidicontrol

import kotlinx.coroutines.channels.SendChannel
import java.util.concurrent.atomic.AtomicLong

object MidiParser {

    interface IncomingEventsSink {
        fun trySend(packedEvent: Long): Boolean

        fun trySendUmp(word0: Int, word1: Int, timestampNs: Long): Boolean =
            word0 ushr 28 == 0x2 && trySend((word0.toLong() shl 32) or ((timestampNs / 1_000_000L) and 0xFFFFFFFFL))
    }

    class IncomingEventsBuffer(
        capacity: Int = 2048,
        private val notifier: SendChannel<Unit>? = null
    ) : IncomingEventsSink {
        private val headPointer = AtomicLong(0)
        private val tailPointer = AtomicLong(0)
        private val ringBuffer = LongArray(capacity)
        private val timestamps = LongArray(capacity)

        override fun trySend(packedEvent: Long): Boolean =
            trySendUmp((packedEvent ushr 32).toInt(), 0, (packedEvent and 0xFFFFFFFFL) * 1_000_000L)

        @Synchronized
        override fun trySendUmp(word0: Int, word1: Int, timestampNs: Long): Boolean {
            val currentTail = tailPointer.get()
            val nextTail = (currentTail + 1) % ringBuffer.size
            if (nextTail == headPointer.get()) {
                return false
            }
            ringBuffer[currentTail.toInt()] = (word0.toLong() shl 32) or (word1.toLong() and 0xFFFFFFFFL)
            timestamps[currentTail.toInt()] = timestampNs
            tailPointer.set(nextTail)
            notifier?.trySend(Unit)
            return true
        }

        fun drainToBatch(batch: LongArray, generation: Long = 0L) {
            var writeIndex = 3
            var currentHead = headPointer.get()
            val currentTail = tailPointer.get()

            while (currentHead != currentTail && writeIndex + 2 < batch.size) {
                val packed = ringBuffer[currentHead.toInt()]
                batch[writeIndex++] = packed ushr 32
                batch[writeIndex++] = packed and 0xFFFFFFFFL
                batch[writeIndex++] = timestamps[currentHead.toInt()]
                currentHead = (currentHead + 1) % ringBuffer.size
            }

            headPointer.set(currentHead)
            batch[0] = -2L
            batch[1] = generation
            batch[2] = ((writeIndex - 3) / 3).toLong()
        }

        fun isEmpty(): Boolean = headPointer.get() == tailPointer.get()
    }

    /**
     * Parses complete UMPs or legacy voice messages from one callback.
     * A port that can split UMP packets across callbacks should retain its own decoder.
     * The sink receives both packet words and the monotonic timestamp in nanoseconds.
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
            UmpStreamDecoder().read(msg, offset, count, timestamp) { word0, word1, packetTimestamp ->
                processChannelVoice(
                    word0, word1, packetTimestamp, isVirtual, incomingEventsSink, suppressionWindowNs, lastSentTime
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

    fun processSingleUmp(
        umpInt: Int,
        timestamp: Long,
        isVirtual: Boolean,
        incomingEventsSink: IncomingEventsSink,
        suppressionWindowNs: Long,
        lastSentTime: LongArray
    ) {
        if (umpInt ushr 28 == 0x2) {
            processChannelVoice(umpInt, 0, timestamp, isVirtual, incomingEventsSink, suppressionWindowNs, lastSentTime)
        }
    }

    internal fun processChannelVoice(
        word0: Int,
        word1: Int,
        timestamp: Long,
        isVirtual: Boolean,
        sink: IncomingEventsSink,
        suppressionWindowNs: Long,
        lastSentTime: LongArray
    ) {
        if (word0 ushr 28 == 0x4) {
            sink.trySendUmp(word0, word1, timestamp)
            return
        }
        val status = (word0 ushr 16) and 0xFF
        when (status and 0xF0) {
            0x80, 0x90, 0xB0, 0xE0 -> forwardMidiEvent(
                (word0 ushr 24) and 0xF, status, (word0 ushr 8) and 0xFF, word0 and 0xFF,
                timestamp, isVirtual, sink, suppressionWindowNs, lastSentTime
            )
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
 
        incomingEventsSink.trySendUmp(umpInt.toInt(), 0, timestamp)
    }
}
