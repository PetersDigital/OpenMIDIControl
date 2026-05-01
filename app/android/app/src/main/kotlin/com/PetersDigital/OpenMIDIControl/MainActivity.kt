// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
package com.petersdigital.openmidicontrol
 
import com.petersdigital.openmidicontrol.BuildConfig

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbManager
import android.media.midi.MidiDevice
import android.media.midi.MidiDeviceInfo
import android.media.midi.MidiInputPort
import android.media.midi.MidiManager
import android.content.ComponentName
import android.content.pm.PackageManager
import android.media.midi.MidiOutputPort
import android.media.midi.MidiReceiver
import android.util.Log
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import kotlinx.coroutines.channels.Channel
import java.util.concurrent.ConcurrentHashMap

class MainActivity : FlutterActivity() {
    companion object {
        var activeInstance: MainActivity? = null
    }

    private val mainScope = CoroutineScope(Dispatchers.Main + Job())

    private val CHANNEL = "com.petersdigital.openmidicontrol/midi"
    private val EVENTS_CHANNEL = "com.petersdigital.openmidicontrol/midi_events"
    private val SYSTEM_EVENT_CHANNEL = "com.petersdigital.openmidicontrol/system_events"
    private var midiManager: MidiManager? = null

    // Abstracted Host and Peripheral Backends
    private var hostMidiBackend: MidiPortBackend? = null
    private var peripheralMidiBackend: MidiPortBackend? = null

    private var eventSink: EventChannel.EventSink? = null
    private var systemEventSink: EventChannel.EventSink? = null
    private val deviceCallbacks = mutableListOf<MidiManager.DeviceCallback>()

    private val mainThreadHandler = Handler(Looper.getMainLooper())
    private var currentUsbMode = "peripheral" // Default to peripheral as per AGENTS.md priorities

    private var cachedDevicesList: List<Map<String, Any>>? = null

    // Rate-limiting and Deduplication state
    private val lastSentValue = IntArray(16384) { -1 }
    private val lastSentTime = LongArray(16384)
    private val suppressionWindowNs = 75_000_000L // 75ms
    private val rateLimitNs = 8_333_333L // ~120Hz (8.3ms)

    // Thread Separation: Multiplexer channel for incoming MIDI event batches.
    private val eventMultiplexer = Channel<LongArray>(capacity = Channel.UNLIMITED)
    private val emptyBuffers = Channel<LongArray>(capacity = 8)

    // Per-port sharded processing session state
    private class ActivePortSession(
        val backendId: String,
        val buffer: MidiParser.IncomingEventsBuffer,
        val job: Job
    )

    // Manage active sessions for hardware, virtual, and peripheral backends.
    private val activeSessions = ConcurrentHashMap<String, ActivePortSession>()
 
    init {
        emptyBuffers.trySend(LongArray(2000))
        emptyBuffers.trySend(LongArray(2000))
        emptyBuffers.trySend(LongArray(2000))
        emptyBuffers.trySend(LongArray(2000))
        emptyBuffers.trySend(LongArray(2000))
        emptyBuffers.trySend(LongArray(2000))
        emptyBuffers.trySend(LongArray(2000))
        emptyBuffers.trySend(LongArray(2000))
    }

    private var batchDispatchJob: Job? = null
    private val batchDispatchRunnable: suspend CoroutineScope.() -> Unit = {
        // Consumer coroutine: processes batches produced by sharded parsing coroutines
        for (payload in eventMultiplexer) {
            if (payload[0] > 0) {
                // Phase 1: Switch to Main Thread context for all Flutter Channel interactions.
                // withContext(Dispatchers.Main) is safer than handler.post as it suspends the worker loop
                // until the UI thread has acknowledged the message, preventing queue flooding.
                withContext(Dispatchers.Main) {
                    try {
                        eventSink?.success(payload)
                    } finally {
                        val result = emptyBuffers.trySend(payload)
                        if (result.isFailure) {
                            android.util.Log.e("MainActivity", "Failed to return buffer to pool: ${result.exceptionOrNull()}")
                        }
                    }
                }
            } else {
                val result = emptyBuffers.trySend(payload)
                if (result.isFailure) {
                    android.util.Log.e("MainActivity", "Failed to return empty buffer to pool: ${result.exceptionOrNull()}")
                }
            }
        }
    }
    private val coroutineScope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    private var lastUsbStateIsConnected = false
    private var lastUsbHostConnectedState = false
    private var lastUsbBroadcastKey: String? = null
    private var lastUsbBroadcastMs = 0L
    private val duplicateUsbBroadcastWindowMs = 1000L
    private var lastDeviceEventKey: String? = null
    private var lastDeviceEventMs = 0L
    private val duplicateDeviceEventWindowMs = 1000L
    private val legacyMsgBuffer = ByteArray(3)
    private val umpMsgBuffer = ByteArray(4)

    private fun shouldSuppressDuplicateDeviceEvent(type: String, id: String): Boolean {
        val nowMs = SystemClock.elapsedRealtime()
        val key = "$type:$id"
        val suppress = key == lastDeviceEventKey && (nowMs - lastDeviceEventMs) < duplicateDeviceEventWindowMs

        lastDeviceEventKey = key
        lastDeviceEventMs = nowMs
        return suppress
    }



    private fun shouldSuppressDuplicateUsbBroadcast(
        connected: Boolean,
        configured: Boolean,
        midi: Boolean
    ): Boolean {
        val nowMs = SystemClock.elapsedRealtime()
        val key = "$connected:$configured:$midi"
        val suppress = key == lastUsbBroadcastKey && (nowMs - lastUsbBroadcastMs) < duplicateUsbBroadcastWindowMs

        lastUsbBroadcastKey = key
        lastUsbBroadcastMs = nowMs
        return suppress
    }

    private val usbStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == "android.hardware.usb.action.USB_STATE") {
                val connected = intent.extras?.getBoolean("connected") ?: false
                val configured = intent.extras?.getBoolean("configured") ?: false
                val midi = intent.extras?.getBoolean("midi") ?: false
                val isMidiActive = intent.getBooleanExtra("midi_active", false)

                if (!connected || !isMidiActive) {
                    MidiSystemManager.setUsbHostConnected(false)
                }

                if (shouldSuppressDuplicateUsbBroadcast(connected, configured, midi)) {
                    return
                }

                val isMidiConnected = connected && configured && midi

                if (isMidiConnected) {
                    cachedDevicesList = null // Invalidate cache on USB state transition
                    if (!lastUsbStateIsConnected) {
                        lastUsbStateIsConnected = true
                        val event = mapOf(
                            "type" to "usb_state",
                            "state" to "AVAILABLE"
                        )
                        mainThreadHandler.post {
                            systemEventSink?.success(event)
                        }
                    }
                } else if (!connected) {
                    cachedDevicesList = null // Invalidate cache on USB state transition
                    if (lastUsbStateIsConnected) {
                        lastUsbStateIsConnected = false
                        val event = mapOf(
                            "type" to "usb_state",
                            "state" to "DISCONNECTED"
                        )
                        mainThreadHandler.post {
                            systemEventSink?.success(event)
                        }
                    }
                }
            }
        }
    }

    private fun isUsbPeripheral(deviceInfo: MidiDeviceInfo): Boolean {
        val properties = deviceInfo.properties
        val product = properties.getString(MidiDeviceInfo.PROPERTY_PRODUCT) ?: ""
        val name = properties.getString(MidiDeviceInfo.PROPERTY_NAME) ?: ""
        val isUsbType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            deviceInfo.type == MidiDeviceInfo.TYPE_USB
        } else {
            false
        }

        // We check if it is explicitly a USB peripheral port.
        return (product.contains("USB Peripheral Port", ignoreCase = true) ||
                name.contains("USB Peripheral Port", ignoreCase = true) ||
                name.contains("Android USB Peripheral", ignoreCase = true) ||
                product.contains("Android USB Peripheral", ignoreCase = true) ||
                (isUsbType && name.contains("OpenMIDIControl", ignoreCase = true))) &&
                deviceInfo.inputPortCount > 0 && deviceInfo.outputPortCount > 0
    }

    private fun getAvailableMidiDevices(): Array<MidiDeviceInfo>? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val merged = LinkedHashMap<Int, MidiDeviceInfo>()

            midiManager
                ?.getDevicesForTransport(MidiManager.TRANSPORT_UNIVERSAL_MIDI_PACKETS)
                ?.forEach { device ->
                    merged[device.id] = device
                }

            midiManager
                ?.getDevicesForTransport(MidiManager.TRANSPORT_MIDI_BYTE_STREAM)
                ?.forEach { device ->
                    merged[device.id] = device
                }

            merged.values.toTypedArray()
        } else {
            @Suppress("DEPRECATION")
            midiManager?.getDevices()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        activeInstance = this
        
        // Ensure we don't leak instances or keep stale callbacks on engine re-attachment
        teardownMidiDeviceCallback()

        // Subscribe to persistent MIDI events from the system manager.
        // This ensures events are captured even when the Activity is in the background or between focus shifts.
        coroutineScope.launch {
            MidiSystemManager.incomingEvents.collect { (msg, timestamp) ->
                handleIncomingPeripheralMidi(msg, 0, msg.size, timestamp)
            }
        }

        coroutineScope.launch(Dispatchers.Main) {
            MidiSystemManager.usbHostConnected.collect { connected ->
                if (connected) {
                    sendSystemEvent("usb_state", mapOf("state" to "CONNECTED"))
                }
            }
        }

        coroutineScope.launch(Dispatchers.Main) {
            MidiSystemManager.portFailures.collect { portId ->
                handlePortFailure(portId)
            }
        }

        midiManager = getSystemService(Context.MIDI_SERVICE) as MidiManager?

        val filter = IntentFilter("android.hardware.usb.action.USB_STATE")
        val stickyIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(usbStateReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(usbStateReceiver, filter)
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENTS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    startBatchDispatchTimer()
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    stopBatchDispatchTimer()
                }
            }
        )

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SYSTEM_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    systemEventSink = events
                    setupMidiDeviceCallback()

                    // Immediately evaluate the initial sticky intent if available
                    stickyIntent?.let {
                        val connected = it.extras?.getBoolean("connected") ?: false
                        val configured = it.extras?.getBoolean("configured") ?: false
                        val midi = it.extras?.getBoolean("midi") ?: false
                        val isMidiConnected = connected && configured && midi

                        if (isMidiConnected) {
                            lastUsbStateIsConnected = true
                            lastUsbHostConnectedState = false
                            val initEvent = mapOf(
                                "type" to "usb_state",
                                "state" to "AVAILABLE"
                            )
                            systemEventSink?.success(initEvent)
                        } else if (!connected) {
                            lastUsbStateIsConnected = false
                            cachedDevicesList = null
                            sendSystemEvent("usb_state", mapOf("state" to "DISCONNECTED"))

                            val initEvent = mapOf(
                                "type" to "usb_state",
                                "state" to "DISCONNECTED"
                            )
                            systemEventSink?.success(initEvent)
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    systemEventSink = null
                    teardownMidiDeviceCallback()
                }
            }
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setUsbMode" -> {
                    val mode = call.argument<String>("mode")
                    if (mode != null) {
                        currentUsbMode = mode
                        if (mode == "peripheral") {
                            // Reset host connection state to force a new heartbeat handshake
                            MidiSystemManager.setUsbHostConnected(false)
                        }
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Mode is required", null)
                    }
                }
                "resetMidiTransport" -> {
                    lastSentValue.fill(-1)
                    lastSentTime.fill(0)
                    Log.i("MainActivity", "MIDI Transport state reset (deduplication buffers cleared)")
                    result.success(true)
                }
                "getMidiDevices" -> {
                    result.success(getMidiDevices())
                }
                "isMidiSupported" -> {
                    val supported = context.packageManager.hasSystemFeature("android.software.midi")
                    result.success(supported)
                }
                "connectToDevice" -> {
                    val id = call.argument<String>("id")
                    val inputPort = call.argument<Int>("inputPort")
                    val outputPort = call.argument<Int>("outputPort")
                    if (id != null) {
                        connectToDevice(id, inputPort, outputPort, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Device ID is required", null)
                    }
                }
                "disconnectDevice" -> {
                    disconnectDevice()
                    result.success(null)
                }
                "sendMidiCC" -> {
                    val cc = call.argument<Int>("cc")
                    val value = call.argument<Int>("value")
                    val isFinal = call.argument<Boolean>("isFinal") ?: false

                    if (cc != null && value != null) {
                        if (cc !in 0..127 || value !in 0..127) {
                            result.error("INVALID_ARGUMENT", "CC and value must be in the range 0..127", null)
                        } else {
                            try {
                                val safeCc = cc and 0x7F
                                val safeValue = value and 0x7F
                                val umpInt = ((0x2 and 0x0F) shl 28) or 
                                             ((0x0 and 0x0F) shl 24) or 
                                             ((0xB0 and 0xFF) shl 16) or 
                                             (safeCc shl 8) or 
                                             safeValue
                                processMidiEvent(umpInt, isFinal, System.nanoTime())
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("SEND_FAILED", "Failed to send MIDI CC: ${e.message}", null)
                            }
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "CC and value are required", null)
                    }
                }
                "sendMidiCCBatch" -> {
                    val events = call.argument<LongArray>("events")
                    if (events != null) {
                        try {
                            for (i in 0 until events.size step 2) {
                                val umpInt = events[i].toInt()
                                val isFinal = events[i + 1] != 0L
                                // Use individual timestamp per event to maintain order and length
                                processMidiEvent(umpInt, isFinal, System.nanoTime())
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("BATCH_SEND_FAILED", "Failed to send MIDI batch: ${e.message}", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Events batch is required", null)
                    }
                }
                "vibrate" -> {
                    val patternRaw = call.argument<List<*>>("pattern")
                    val amplitudeRaw = call.argument<List<*>>("amplitude")

                    if (patternRaw != null && amplitudeRaw != null) {
                        // SECURITY: Validate bounds of vibration pattern arrays to prevent native crash
                        if (patternRaw.size != amplitudeRaw.size || patternRaw.isEmpty()) {
                            result.error("INVALID_ARGUMENTS", "Pattern and amplitude arrays must have the same non-zero length", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val pattern = patternRaw.map { (it as Number).toLong() }.toLongArray()
                            val amplitude = amplitudeRaw.map { (it as Number).toInt() }.toIntArray()
                            vibrate(pattern, amplitude)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("VIBRATE_FAILED", e.message, null)
                        }
                    } else {
                        val duration = call.argument<Number>("duration")?.toLong() ?: 50L
                        vibrate(duration)
                        result.success(null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun processMidiEvent(umpInt: Int, isFinal: Boolean, nowNs: Long) {
        val group = (umpInt ushr 24) and 0xF
        val status = (umpInt ushr 16) and 0xFF
        val data1 = (umpInt ushr 8) and 0xFF
        val data2 = umpInt and 0xFF

        if (data1 !in 0..127) return

        // Unique index per message type + channel + data1
        val index = (((status ushr 4) - 8) shl 11) or ((status and 0x0F) shl 7) or data1
        
        if (index < 0 || index >= 16384) {
            // Send immediately if out of voice message range (unlikely for MT 0x2)
            sendToBackends(umpInt, status, data1, data2, nowNs)
            return
        }

        val lastTime = lastSentTime[index]
        val timeDiff = nowNs - lastTime

        // Rate-limiting and Deduplication checks unless it's the final message
        var shouldSend = true
        if (!isFinal) {
            // Deduplication: if value hasn't changed and within suppression window, drop it
            if (lastSentValue[index] == data2 && timeDiff < suppressionWindowNs) {
                shouldSend = false
            }
            // Rate Limiting: ensure we don't send faster than ~120Hz
            else if (timeDiff < rateLimitNs) {
                shouldSend = false
            }
        }

        if (shouldSend) {
            lastSentValue[index] = data2
            lastSentTime[index] = nowNs
            sendToBackends(umpInt, status, data1, data2, nowNs)
        }
    }

    private fun sendToBackends(umpInt: Int, status: Int, data1: Int, data2: Int, timestamp: Long) {
        legacyMsgBuffer[0] = status.toByte()
        legacyMsgBuffer[1] = data1.toByte()
        legacyMsgBuffer[2] = data2.toByte()

        umpMsgBuffer[0] = (umpInt ushr 24).toByte()
        umpMsgBuffer[1] = (umpInt ushr 16).toByte()
        umpMsgBuffer[2] = (umpInt ushr 8).toByte()
        umpMsgBuffer[3] = umpInt.toByte()

        // Send to physically connected hardware (if any)
        if (hostMidiBackend != null) {
            hostMidiBackend?.send(legacyMsgBuffer, 0, legacyMsgBuffer.size, timestamp)
        }
        
        // Selective Dispatch: Avoid internal routing loops in Peripheral Mode
        if (currentUsbMode != "peripheral") {
            // Send to virtual DAW out (e.g. FL Studio Mobile) only when in Host mode
            VirtualMidiService.activeInstance?.sendToDaw(legacyMsgBuffer, 0, legacyMsgBuffer.size)
        }
        
        // Send to Host PC/Mac via USB over UMP transport
        // Use real monotonic timestamp at point of transmission for accurate
        // event timing on the Windows host (some DAWs use packet timestamps).
        val peripheral = PeripheralMidiService.activeInstance
        if (peripheral != null) {
            peripheral.sendToHost(umpMsgBuffer, 0, umpMsgBuffer.size, System.nanoTime())
        } else {
            // Only log if we expect to be connected to help debug host-reconnect issues
            if (MidiSystemManager.usbHostConnected.value) {
                Log.w("MainActivity", "Attempted to send to host but PeripheralMidiService is null")
            }
        }
    }

    private fun getMidiDevices(): List<Map<String, Any>> {
        cachedDevicesList?.let { return it }

        val devicesList = mutableListOf<Map<String, Any>>()
        val devices = getAvailableMidiDevices()

        devices?.forEach { deviceInfo ->
            val id = deviceInfo.id.toString()
            val properties = deviceInfo.properties
            val name = properties.getString(MidiDeviceInfo.PROPERTY_NAME) ?: "Unknown MIDI Device"
            val manufacturer = properties.getString(MidiDeviceInfo.PROPERTY_MANUFACTURER) ?: "Unknown Manufacturer"

            // Send all devices to Flutter; Dart will decide whether to hide our internal ports.

            val inputPorts = mutableListOf<Map<String, Any>>()
            val outputPorts = mutableListOf<Map<String, Any>>()

            deviceInfo.ports.forEach { portInfo ->
                var portName = portInfo.name
                if (portName.isNullOrEmpty()) {
                    // Try to provide intelligent fallbacks based on device name
                    if (name.contains("Minilab 3", ignoreCase = true) || name.contains("MiniLab3", ignoreCase = true)) {
                        portName = when (portInfo.portNumber) {
                            0 -> "MiniLab 3 MIDI"
                            1 -> "MiniLab 3 DIN Thru"
                            2 -> "MiniLab 3 MCU"
                            3 -> "MiniLab 3 ALV"
                            else -> "Port ${portInfo.portNumber}"
                        }
                    } else {
                        portName = "Port ${portInfo.portNumber}"
                    }
                }

                val portData = mapOf(
                    "number" to portInfo.portNumber,
                    "name" to portName
                )
                if (portInfo.type == android.media.midi.MidiDeviceInfo.PortInfo.TYPE_INPUT) {
                    inputPorts.add(portData)
                } else if (portInfo.type == android.media.midi.MidiDeviceInfo.PortInfo.TYPE_OUTPUT) {
                    outputPorts.add(portData)
                }
            }

            devicesList.add(
                mapOf(
                    "id" to id,
                    "name" to name,
                    "manufacturer" to manufacturer,
                    "inputPorts" to inputPorts,
                    "outputPorts" to outputPorts
                )
            )
        }

        cachedDevicesList = devicesList
        return devicesList
    }

    private fun vibrate(duration: Long) {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createOneShot(duration, VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(duration)
        }
    }

    private fun vibrate(pattern: LongArray, amplitudes: IntArray) {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createWaveform(pattern, amplitudes, -1))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(pattern, -1)
        }
    }

    private fun connectToDevice(id: String, inputPortNumber: Int?, outputPortNumber: Int?, result: MethodChannel.Result) {
        val devices = getAvailableMidiDevices()
        val deviceInfo = devices?.find { it.id.toString() == id }

        if (deviceInfo == null) {
            result.error("DEVICE_NOT_FOUND", "Could not find device with ID: $id", null)
            return
        }

        midiManager?.openDevice(deviceInfo, { device ->
            if (device != null) {
                var inputPort: MidiInputPort? = null
                var outputPort: MidiOutputPort? = null

                // Open output port (receives from device into Android)
                val outPortToOpen = outputPortNumber ?: if (device.info.outputPortCount > 0) 0 else -1
                if (outPortToOpen >= 0 && outPortToOpen < device.info.outputPortCount) {
                    outputPort = device.openOutputPort(outPortToOpen)
                }

                // Open input port (sends from Android to device)
                val inPortToOpen = inputPortNumber ?: if (device.info.inputPortCount > 0) 0 else -1
                if (inPortToOpen >= 0 && inPortToOpen < device.info.inputPortCount) {
                    inputPort = device.openInputPort(inPortToOpen)
                }

                hostMidiBackend = NativeAndroidMidiBackend(device, inputPort, outputPort)
                setupMidiReceiver()

                result.success(true)
            } else {
                result.error("CONNECTION_FAILED", "Failed to open device", null)
            }
        }, mainThreadHandler)
    }

    private fun disconnectDevice() {
        val backendId = hostMidiBackend?.portId
        backendId?.let { id ->
            activeSessions[id]?.job?.cancel()
            activeSessions.remove(id)
        }
        hostMidiBackend?.close()
        hostMidiBackend = null
    }

    /**
     * Handles fatal hardware or stream failures reported by backends or services.
     */
    private fun handlePortFailure(portId: String) {
        android.util.Log.e("MainActivity", "Handling fatal port failure: $portId")
        
        if (portId == "peripheral_host") {
            // Special handling for USB Peripheral (OTG) disconnects
            MidiSystemManager.setUsbHostConnected(false)
            sendSystemEvent("usb_state", mapOf("state" to "DISCONNECTED"))
        } else if (portId == "virtual_daw") {
            // Cleanup virtual session if needed
            activeSessions[portId]?.job?.cancel()
            activeSessions.remove(portId)
            sendSystemEvent("DISCONNECT", mapOf("portId" to portId))
        } else {
            // For hardware devices, if the failing port is our active one, tear it down.
            if (hostMidiBackend?.portId == portId) {
                mainThreadHandler.post {
                    disconnectDevice()
                    sendSystemEvent("DISCONNECT", mapOf("portId" to portId))
                }
            }
        }
    }

    private fun setupMidiReceiver() {
        val backend = hostMidiBackend ?: return
        val backendId = backend.portId

        val notifier = Channel<Unit>(capacity = Channel.CONFLATED)
        val portBuffer = MidiParser.IncomingEventsBuffer(1000, notifier)

        val portJob = coroutineScope.launch {
            for (notification in notifier) {
                while (!portBuffer.isEmpty()) {
                    val batch = emptyBuffers.receive()
                    portBuffer.drainToBatch(batch)
                    eventMultiplexer.send(batch)

                    // Batching yield: maintains UI smoothness (~120Hz) and prevents CPU spinning
                    delay(8)
                }
            }
        }

        activeSessions[backendId] = ActivePortSession(backendId, portBuffer, portJob)

        backend.startReceiving { msg, offset, count, timestamp ->
            MidiParser.processMidiPayload(
                msg = msg,
                offset = offset,
                count = count,
                timestamp = timestamp,
                isVirtual = false,
                incomingEventsSink = portBuffer,
                suppressionWindowNs = suppressionWindowNs,
                lastSentTime = lastSentTime,
                isDebug = BuildConfig.DEBUG
            )
        }
    }

    private fun getOrCreateVirtualSession(isVirtual: Boolean): MidiParser.IncomingEventsBuffer {
        val sessionId = if (isVirtual) "virtual_daw" else "peripheral_host"

        val session = activeSessions.computeIfAbsent(sessionId) { id ->
            val notifier = Channel<Unit>(capacity = Channel.CONFLATED)
            val portBuffer = MidiParser.IncomingEventsBuffer(1000, notifier)

            val portJob = coroutineScope.launch {
                for (notification in notifier) {
                    while (!portBuffer.isEmpty()) {
                        val batch = emptyBuffers.receive()
                        portBuffer.drainToBatch(batch)
                        eventMultiplexer.send(batch)

                        delay(8)
                    }
                }
            }
            ActivePortSession(id, portBuffer, portJob)
        }
        return session.buffer
    }

    fun handleIncomingVirtualMidi(msg: ByteArray, offset: Int, count: Int, timestamp: Long? = null) {
        if (count == 0) return
        val nowNs = timestamp ?: System.nanoTime()
        val buffer = getOrCreateVirtualSession(true)
        MidiParser.processMidiPayload(msg, offset, count, nowNs, true, buffer, suppressionWindowNs, lastSentTime, BuildConfig.DEBUG)
    }

    /**
     * Entry point for MIDI messages from the USB Peripheral service (acting as a controller).
     * Now called via the persistent MidiSystemManager flow.
     */
    internal fun handleIncomingPeripheralMidi(msg: ByteArray, offset: Int, count: Int, timestamp: Long? = null) {
        if (count == 0) return
        val nowNs = timestamp ?: System.nanoTime()
        val buffer = getOrCreateVirtualSession(false)
        MidiParser.processMidiPayload(msg, offset, count, nowNs, true, buffer, suppressionWindowNs, lastSentTime, BuildConfig.DEBUG)
    }

    private fun setupMidiDeviceCallback() {
        if (deviceCallbacks.isEmpty()) {
            val callback = object : MidiManager.DeviceCallback() {
                override fun onDeviceAdded(device: MidiDeviceInfo) {
                    val id = device.id.toString()
                    if (shouldSuppressDuplicateDeviceEvent("added", id)) {
                        return
                    }

                    cachedDevicesList = null // Invalidate cache

                    val event = mapOf(
                        "type" to "added",
                        "id" to id
                    )
                    mainThreadHandler.post {
                        systemEventSink?.success(event)
                    }
                }

                override fun onDeviceRemoved(device: MidiDeviceInfo) {
                    val id = device.id.toString()
                    if (shouldSuppressDuplicateDeviceEvent("removed", id)) {
                        return
                    }

                    cachedDevicesList = null // Invalidate cache

                    // Disconnect if the removed device ID matches the current host backend portId.
                    if (hostMidiBackend?.portId == id) {
                        mainThreadHandler.post {
                            disconnectDevice()
                            // Instantly signal disconnect to Flutter to prevent ghost states
                            sendSystemEvent("DISCONNECT", mapOf("portId" to id))
                        }
                    } else {
                        val event = mapOf(
                            "type" to "removed",
                            "id" to id
                        )
                        mainThreadHandler.post {
                            systemEventSink?.success(event)
                        }
                    }
                }
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                midiManager?.registerDeviceCallback(MidiManager.TRANSPORT_UNIVERSAL_MIDI_PACKETS, ContextCompat.getMainExecutor(this), callback)
                deviceCallbacks.add(callback)

                // Create a distinct instance for the second transport to ensure unregister succeeds for both
                val callback2 = object : MidiManager.DeviceCallback() {
                    override fun onDeviceAdded(device: MidiDeviceInfo) { callback.onDeviceAdded(device) }
                    override fun onDeviceRemoved(device: MidiDeviceInfo) { callback.onDeviceRemoved(device) }
                }
                midiManager?.registerDeviceCallback(MidiManager.TRANSPORT_MIDI_BYTE_STREAM, ContextCompat.getMainExecutor(this), callback2)
                deviceCallbacks.add(callback2)
            } else {
                @Suppress("DEPRECATION")
                midiManager?.registerDeviceCallback(callback, mainThreadHandler)
                deviceCallbacks.add(callback)
            }
        }
    }

    private fun teardownMidiDeviceCallback() {
        deviceCallbacks.forEach { callback ->
            midiManager?.unregisterDeviceCallback(callback)
        }
        deviceCallbacks.clear()
    }

    private fun sendSystemEvent(type: String, data: Map<String, Any>) {
        val event = data.toMutableMap()
        event["type"] = type
        mainThreadHandler.post {
            systemEventSink?.success(event)
        }
    }

    private fun startBatchDispatchTimer() {
        stopBatchDispatchTimer()
        batchDispatchJob = coroutineScope.launch(block = batchDispatchRunnable)
    }

    private fun stopBatchDispatchTimer() {
        batchDispatchJob?.cancel()
        batchDispatchJob = null
    }

    override fun onResume() {
        super.onResume()
        // Signal readiness to services that may have been throttled during pause
        activeInstance = this
    }

    override fun onPause() {
        // We do NOT teardown MIDI here to ensure persistent background connectivity,
        // but we invalidate the instance to prevent UI-bound callbacks from firing.
        // The core MIDI transport (Isolates/Coroutines) remains active.
        super.onPause()
    }

    override fun onDestroy() {
        coroutineScope.cancel()
        teardownMidiDeviceCallback()
        try {
            unregisterReceiver(usbStateReceiver)
        } catch (e: Exception) { }
        disconnectDevice()
        VirtualMidiService.activeInstance?.onDestroy()
        PeripheralMidiService.activeInstance?.onDestroy()
        MidiSystemManager.teardown()
        activeInstance = null
        super.onDestroy()
    }


}
