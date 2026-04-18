// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
package com.petersdigital.openmidicontrol

import kotlinx.coroutines.channels.Channel

object MidiParser {

    // Pre-allocated batch buffer — reused across drain cycles to eliminate allocation churn.
    // Every 8ms cycle in startBatchDispatchTimer would otherwise allocate 16KB + copyOfRange overhead (~2MB/sec GC pressure).
    private val batch = LongArray(2000)

    /**
     * Reconstructs 32-bit UMP integers or handles legacy byte streams,
     * applies bitwise filtering (dropping Real-Time spam like 0xF8/0xFE),
     * and queues the valid output pairs (UMP, Timestamp) to the given channel.
     */
    fun processMidiPayload(
        msg: ByteArray,
        offset: Int,
        count: Int,
        timestamp: Long,
        isVirtual: Boolean,
        incomingEventsChannel: Channel<Pair<Long, Long>>,
        suppressionWindowNs: Long,
        lastSentTime: Map<Int, Long>,
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

                if (messageType == 0x1) {
                    // MT 0x1: System Real-Time / System Common
                    val status = (umpInt ushr 16) and 0xFF

                    // Drop Timing Clock (0xF8) and Active Sensing (0xFE).
                    if (status == 0xF8 || status == 0xFE) {
                        i += 4
                        continue
                    }
                    // Drop other MT 1 messages for now.
                } else if (messageType == 0x2) {
                    // MT 0x2: MIDI 1.0 Channel Voice
                    val group = (umpInt ushr 24) and 0xF
                    val status = (umpInt ushr 16) and 0xFF

                    if (status in 0xB0..0xBF) { // Control Change
                        val ccNumber = (umpInt ushr 8) and 0xFF
                        val ccValue = umpInt and 0xFF

                        forwardCcEvent(group, status, ccNumber, ccValue, timestamp, isVirtual, incomingEventsChannel, suppressionWindowNs, lastSentTime)
                    }
                }
                // Silently drop other MTs.
                i += 4
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

                // Check if we have enough bytes for a CC message
                if (i + 2 < offset + count && statusByte in 0xB0..0xBF) {
                    val ccNumber = msg[i + 1].toInt() and 0xFF
                    val ccValue = msg[i + 2].toInt() and 0xFF
                    forwardCcEvent(0, statusByte, ccNumber, ccValue, timestamp, isVirtual, incomingEventsChannel, suppressionWindowNs, lastSentTime)
                    i += 3
                } else {
                    // Unhandled legacy message or incomplete buffer; just advance by 1 to recover
                    i += 1
                }
            }
        }
    }

    private fun forwardCcEvent(
        group: Int,
        status: Int,
        ccNumber: Int,
        ccValue: Int,
        timestamp: Long,
        isVirtual: Boolean,
        incomingEventsChannel: Channel<Pair<Long, Long>>,
        suppressionWindowNs: Long,
        lastSentTime: Map<Int, Long>
    ) {
        if (isVirtual) {
            // Bidirectional Feedback Loop Prevention
            val lastTime = lastSentTime[ccNumber] ?: 0L
            val timeDiff = timestamp - lastTime

            if (timeDiff < suppressionWindowNs) {
                // Ignore message from host if we recently sent *any* value for this CC.
                // This prevents delayed echoes from older values causing oscillation during rapid movement.
                return
            }
        }

        // Reconstruct the 32-bit UMP (MT=0x2 Channel Voice) using the original group and status byte
        val umpInt = (0x2L shl 28) or (group.toLong() shl 24) or (status.toLong() shl 16) or (ccNumber.toLong() shl 8) or ccValue.toLong()

        incomingEventsChannel.trySend(Pair(umpInt, timestamp))
    }

    /**
     * Drains the atomic channel into a 1D primitive LongArray for JNI dispatch.
     * Prevents object allocations on the main thread and respects array bounds.
     *
     * Uses a pre-allocated batch buffer reused across drain cycles to eliminate
     * the ~2MB/sec allocation churn that would otherwise occur at 120Hz dispatch rate.
     */
    suspend fun drainChannelToBatch(
        firstEvent: Pair<Long, Long>,
        channel: Channel<Pair<Long, Long>>
    ): LongArray {
        batch[0] = firstEvent.first
        batch[1] = firstEvent.second
        var count = 2

        // Drain any other events currently in the channel buffer without exceeding capacity
        while (count + 1 < batch.size) {
            val nextEvent = channel.tryReceive().getOrNull() ?: break
            batch[count++] = nextEvent.first
            batch[count++] = nextEvent.second
        }

        // Return exact-sized copy from reused buffer
        // If batch is fully populated, clone() avoids the double-allocation path
        return if (count == batch.size) batch.clone() else batch.copyOfRange(0, count)
    }
}
