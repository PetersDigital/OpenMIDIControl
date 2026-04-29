// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
package com.petersdigital.openmidicontrol

import kotlinx.coroutines.channels.SendChannel

object MidiParser {

    interface IncomingEventsSink {
        fun trySend(packedEvent: Long): Boolean
    }

    class IncomingEventsBuffer(
        capacity: Int = 1000,
        private val notifier: SendChannel<Unit>? = null
    ) : IncomingEventsSink {
        private val bufferSize = capacity + 1
        private val buffer = LongArray(bufferSize)
        private var head = 0
        private var tail = 0

        private fun next(index: Int): Int = if (index + 1 == bufferSize) 0 else index + 1

        @Synchronized
        override fun trySend(packedEvent: Long): Boolean {
            val nextTail = next(tail)
            if (nextTail == head) {
                // Buffer full: drop oldest element and retain newest.
                head = next(head)
            }
            buffer[tail] = packedEvent
            tail = nextTail
            notifier?.trySend(Unit)
            return true
        }

        @Synchronized
        fun drainToBatch(batch: LongArray) {
            var writeIndex = 1
            var usedDataLongs = 0

            while (head != tail && writeIndex + 1 < batch.size) {
                val packed = buffer[head]
                batch[writeIndex++] = (packed shr 32) and 0xFFFFFFFFL
                batch[writeIndex++] = packed and 0xFFFFFFFFL
                head = next(head)
                usedDataLongs += 2
            }

            batch[0] = usedDataLongs.toLong()
        }

        @Synchronized
        fun isEmpty(): Boolean = head == tail
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
        isDebug: Boolean = false
    ) {
        // SECURITY: Defense-in-depth bounds checking to prevent DoS via malformed MIDI packets
        if (offset < 0 || count < 0 || offset + count > msg.size) return

        // Check for UMP alignment and validate Message Type (MT) to prevent false positives
        val isUmp = if (count >= 4 && count % 4 == 0) {
            val firstUmpWord = ((msg[offset].toInt() and 0xFF) shl 24) or
                               ((msg[offset + 1].toInt() and 0xFF) shl 16) or
                               ((msg[offset + 2].toInt() and 0xFF) shl 8) or
                               (msg[offset + 3].toInt() and 0xFF)
            val firstMessageType = (firstUmpWord ushr 28) and 0xF
            firstMessageType in 0x0..0x5
        } else false

        if (isUmp) {
            // Process each 32-bit UMP word independently to avoid misalignment churn.
            var i = offset
            while (i + 3 < offset + count) {
                val byte1 = msg[i].toInt() and 0xFF
                val byte2 = msg[i + 1].toInt() and 0xFF
                val byte3 = msg[i + 2].toInt() and 0xFF
                val byte4 = msg[i + 3].toInt() and 0xFF

                val umpInt = (byte1 shl 24) or (byte2 shl 16) or (byte3 shl 8) or byte4
                val messageType = (umpInt ushr 28) and 0xF
                val wordCount = when (messageType) {
                    0x0, 0x1, 0x2 -> 1
                    0x3, 0x4 -> 2
                    0x5 -> 4
                    0x6, 0x7 -> 1
                    0x8, 0x9 -> 2
                    0xA, 0xB -> 3
                    0xC, 0xD, 0xE, 0xF -> 4
                    else -> 1
                }

                if (messageType == 0x1) {
                    // MT 0x1: System Real-Time / System Common
                    val status = (umpInt ushr 16) and 0xFF

                    // Drop Timing Clock (0xF8) and Active Sensing (0xFE).
                    if (status == 0xF8 || status == 0xFE) {
                        // Continue to next packet
                    } else {
                        // Drop other MT 1 messages for now.
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
                // Silently drop other MTs or unrecognized words.
                i += wordCount * 4
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
                val index = (((status ushr 4) - 8) shl 11) or ((status and 0x0F) shl 7) or data1
                if (index in 0 until 16384) {
                    val lastTime = lastSentTime[index]
                    val timeDiff = timestamp - lastTime

                    if (timeDiff < suppressionWindowNs) {
                        // Ignore message from host if we recently sent *any* value for this event.
                        // This prevents delayed echoes from older values causing oscillation during rapid movement.
                        return
                    }
                }
            }
        }


        // Reconstruct the 32-bit UMP (MT=0x2 Channel Voice) using the original group and status byte
        val umpInt = (0x2L shl 28) or (group.toLong() shl 24) or (status.toLong() shl 16) or (data1.toLong() shl 8) or data2.toLong()

        // Pack UMP (upper 32 bits) + timestamp in ms (lower 32 bits) into a single Long
        // Eliminates Pair<Long, Long> allocation (~48 bytes) per event (~5,760 bytes/sec at 120 events/sec)
        // Store lower 32 bits of timestamp in milliseconds to extend wrap-around to ~49 days
        val packed = (umpInt shl 32) or ((timestamp / 1_000_000L) and 0xFFFFFFFFL)
        incomingEventsSink.trySend(packed)
    }
}
