// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

package com.petersdigital.openmidicontrol

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.yield
import org.junit.Assert.assertEquals
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class MidiSystemManagerTest {

    @Test
    fun testPortFailureReporting() = runTest {
        val testPortId = "test_hardware_port"
        
        // Start collecting in a separate coroutine before emitting
        val deferred = async {
            MidiSystemManager.portFailures.first()
        }
        
        // Yield to allow the collector to start
        yield()
        
        // Report a failure
        MidiSystemManager.onPortFailure(testPortId)
        
        // Collect the emitted failure
        val reportedId = deferred.await()
        
        assertEquals(testPortId, reportedId)
    }

    @Test
    fun testUsbHostConnectivityState() = runTest {
        // Initial state should be false (or whatever the default is, let's force it)
        MidiSystemManager.setUsbHostConnected(false)
        assertEquals(false, MidiSystemManager.usbHostConnected.value)
        
        MidiSystemManager.setUsbHostConnected(true)
        assertEquals(true, MidiSystemManager.usbHostConnected.value)
        
        MidiSystemManager.setUsbHostConnected(false)
        assertEquals(false, MidiSystemManager.usbHostConnected.value)
    }
}
