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
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.*
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.channels.Channel

class MainActivity : FlutterActivity() {
    companion object {
        var activeInstance: MainActivity? = null
    }

    private val CHANNEL = "com.petersdigital.openmidicontrol/midi"
    private val EVENTS_CHANNEL = "com.petersdigital.openmidicontrol/midi_events"
    private var midiManager: MidiManager? = null

    // Abstracted Host and Peripheral Backends
    private var hostMidiBackend: MidiPortBackend? = null
    private var peripheralMidiBackend: MidiPortBackend? = null

    private var eventSink: EventChannel.EventSink? = null
    private var deviceCallback: MidiManager.DeviceCallback? = null

    // Rate-limiting and Deduplication state
    private val lastSentValue = ConcurrentHashMap<Int, Int>()
    private val lastSentTime = ConcurrentHashMap<Int, Long>()
    private val suppressionWindowNs = 75_000_000L // 75ms
    private val rateLimitNs = 8_333_333L // ~120Hz (8.3ms)

    // Thread Separation: Coroutine Channel for incoming MIDI events
    // We store the 32-bit UMP and its timestamp as a Pair to ensure atomic queuing.
    private val incomingEventsChannel = Channel<Pair<Long, Long>>(capacity = 1000, onBufferOverflow = BufferOverflow.DROP_OLDEST)
    private var batchDispatchJob: Job? = null
    private val coroutineScope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    private var lastUsbStateIsConnected = false

    private val usbStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == "android.hardware.usb.action.USB_STATE") {
                val connected = intent.extras?.getBoolean("connected") ?: false
                val configured = intent.extras?.getBoolean("configured") ?: false
                val midi = intent.extras?.getBoolean("midi") ?: false

                val isMidiConnected = connected && configured && midi

                if (isMidiConnected) {
                    lastUsbStateIsConnected = true
                } else if (!connected) {
                    lastUsbStateIsConnected = false
                    val event = mapOf(
                        "type" to "usb_state",
                        "state" to "DISCONNECTED"
                    )
                    Handler(Looper.getMainLooper()).post {
                        eventSink?.success(event)
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
            val umpDevices = midiManager?.getDevicesForTransport(MidiManager.TRANSPORT_UNIVERSAL_MIDI_PACKETS)?.toTypedArray()
            if (umpDevices != null && umpDevices.isNotEmpty()) {
                umpDevices
            } else {
                midiManager?.getDevicesForTransport(MidiManager.TRANSPORT_MIDI_BYTE_STREAM)?.toTypedArray()
            }
        } else {
            @Suppress("DEPRECATION")
            midiManager?.getDevices()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        activeInstance = this

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
                    setupMidiDeviceCallback()

                    // Immediately evaluate the initial sticky intent if available
                    stickyIntent?.let {
                        val connected = it.extras?.getBoolean("connected") ?: false
                        val configured = it.extras?.getBoolean("configured") ?: false
                        val midi = it.extras?.getBoolean("midi") ?: false
                        val isMidiConnected = connected && configured && midi

                        if (isMidiConnected) {
                            lastUsbStateIsConnected = true
                        } else if (!connected) {
                            lastUsbStateIsConnected = false
                            val initEvent = mapOf(
                                "type" to "usb_state",
                                "state" to "DISCONNECTED"
                            )
                            eventSink?.success(initEvent)
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    stopBatchDispatchTimer()
                    teardownMidiDeviceCallback()
                }
            }
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setUsbMode" -> {
                    // Mode is retained for future use; the Dart side calls this to signal intent.
                    // No-op until peripheral/host mode switching logic is re-implemented.
                    val mode = call.argument<String>("mode")
                    if (mode != null) {
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Mode is required", null)
                    }
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
                        try {
                            processMidiCcEvent(cc, value, isFinal, System.nanoTime())
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SEND_FAILED", "Failed to send MIDI CC: ${e.message}", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "CC and value are required", null)
                    }
                }
                "sendMidiCCBatch" -> {
                    val events = call.argument<List<Map<String, Any>>>("events")
                    if (events != null) {
                        try {
                            val nowNs = System.nanoTime()
                            for (event in events) {
                                val cc = event["cc"] as? Int
                                val value = event["value"] as? Int
                                val isFinal = event["isFinal"] as? Boolean ?: false

                                if (cc != null && value != null) {
                                    processMidiCcEvent(cc, value, isFinal, nowNs)
                                }
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("BATCH_SEND_FAILED", "Failed to send MIDI CC batch: ${e.message}", null)
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

    private fun processMidiCcEvent(cc: Int, value: Int, isFinal: Boolean, nowNs: Long) {
        val lastTime = lastSentTime[cc] ?: 0L
        val timeDiff = nowNs - lastTime

        // Rate-limiting and Deduplication checks unless it's the final message
        var shouldSend = true
        if (!isFinal) {
            // Deduplication: if value hasn't changed and within suppression window, drop it
            if (lastSentValue[cc] == value && timeDiff < suppressionWindowNs) {
                shouldSend = false
            }
            // Rate Limiting: ensure we don't send faster than ~120Hz
            else if (timeDiff < rateLimitNs) {
                shouldSend = false
            }
        }

        if (shouldSend) {
            lastSentValue[cc] = value
            lastSentTime[cc] = nowNs

            val legacyMsg = byteArrayOf(0xB0.toByte(), cc.toByte(), value.toByte())
            val umpMsg = buildUmpCcPacket(cc, value)

            // Send to physically connected hardware (if any)
            hostMidiBackend?.send(legacyMsg, 0, legacyMsg.size, nowNs)
            // Send to virtual DAW out (e.g. FL Studio Mobile)
            VirtualMidiService.activeInstance?.sendToDaw(legacyMsg, 0, legacyMsg.size)
            // Send to Host PC/Mac via USB over UMP transport
            PeripheralMidiService.activeInstance?.sendToHost(umpMsg, 0, umpMsg.size, nowNs)
        }
    }

    private fun getMidiDevices(): List<Map<String, Any>> {
        val devicesList = mutableListOf<Map<String, Any>>()
        val devices = getAvailableMidiDevices()

        devices?.forEach { deviceInfo ->
            if (isUsbPeripheral(deviceInfo)) {
                return@forEach
            }

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
        }, Handler(Looper.getMainLooper()))
    }

    private fun disconnectDevice() {
        hostMidiBackend?.close()
        hostMidiBackend = null
    }

    private fun setupMidiReceiver() {
        hostMidiBackend?.startReceiving { msg, offset, count, timestamp ->
            MidiParser.processMidiPayload(msg, offset, count, timestamp, false, incomingEventsChannel, suppressionWindowNs, lastSentTime, BuildConfig.DEBUG)
        }
    }

    fun handleIncomingVirtualMidi(msg: ByteArray, offset: Int, count: Int, timestamp: Long? = null) {
        if (count == 0) return
        val nowNs = timestamp ?: System.nanoTime()
        MidiParser.processMidiPayload(msg, offset, count, nowNs, true, incomingEventsChannel, suppressionWindowNs, lastSentTime, BuildConfig.DEBUG)
    }

    private fun setupMidiDeviceCallback() {
        if (deviceCallback == null) {
            deviceCallback = object : MidiManager.DeviceCallback() {
                override fun onDeviceAdded(device: MidiDeviceInfo) {
                    val event = mapOf(
                        "type" to "added",
                        "id" to device.id.toString()
                    )
                    Handler(Looper.getMainLooper()).post {
                        eventSink?.success(event)
                    }
                }

                override fun onDeviceRemoved(device: MidiDeviceInfo) {
                    // Disconnect if the removed device ID matches the current host backend portId.
                    if (hostMidiBackend?.portId == device.id.toString()) {
                        disconnectDevice()
                    }
                    val event = mapOf(
                        "type" to "removed",
                        "id" to device.id.toString()
                    )
                    Handler(Looper.getMainLooper()).post {
                        eventSink?.success(event)
                    }
                }
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                midiManager?.registerDeviceCallback(MidiManager.TRANSPORT_UNIVERSAL_MIDI_PACKETS, ContextCompat.getMainExecutor(this), deviceCallback!!)
                midiManager?.registerDeviceCallback(MidiManager.TRANSPORT_MIDI_BYTE_STREAM, ContextCompat.getMainExecutor(this), deviceCallback!!)
            } else {
                @Suppress("DEPRECATION")
                midiManager?.registerDeviceCallback(deviceCallback, Handler(Looper.getMainLooper()))
            }
        }
    }

    private fun teardownMidiDeviceCallback() {
        deviceCallback?.let {
            // Single call removes callback from all transports (UMP + byte-stream).
            midiManager?.unregisterDeviceCallback(it)
            deviceCallback = null
        }
    }

    private fun startBatchDispatchTimer() {
        stopBatchDispatchTimer()
        batchDispatchJob = coroutineScope.launch {
            // Using a for-loop on the channel ensures proper coroutine suspension when it's empty,
            // avoiding busy-wait loops and pinning the CPU.
            for (firstEvent in incomingEventsChannel) {

                // Use the static parser to safely drain the channel into a bounded batch
                val payload = MidiParser.drainChannelToBatch(firstEvent, incomingEventsChannel)

                if (payload.isNotEmpty()) {
                    Handler(Looper.getMainLooper()).post {
                        eventSink?.success(payload)
                    }
                }

                // Batching yield: maintains UI smoothness (~120Hz) and prevents CPU spinning
                delay(8)
            }
        }
    }

    private fun stopBatchDispatchTimer() {
        batchDispatchJob?.cancel()
        batchDispatchJob = null
    }

    override fun onDestroy() {
        coroutineScope.cancel()
        teardownMidiDeviceCallback()
        try {
            unregisterReceiver(usbStateReceiver)
        } catch (e: Exception) { }
        disconnectDevice()
        activeInstance = null
        super.onDestroy()
    }
}
