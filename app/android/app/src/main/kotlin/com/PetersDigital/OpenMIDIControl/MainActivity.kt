package com.PetersDigital.OpenMIDIControl

import com.PetersDigital.OpenMIDIControl.BuildConfig

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
    private val incomingEventsChannel = Channel<Map<String, Any>>(capacity = 1000, onBufferOverflow = BufferOverflow.DROP_OLDEST)
    private var batchDispatchJob: Job? = null
    private val coroutineScope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    private var currentUsbMode = "peripheral"
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
                    if (currentUsbMode == "peripheral") {
                        connectToUsbPeripheral()
                    }
                } else if (!connected) {
                    lastUsbStateIsConnected = false
                    disconnectUsbPeripheral()
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

    private fun connectToUsbPeripheral() {
        val devices: Array<MidiDeviceInfo>? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            midiManager?.getDevicesForTransport(MidiManager.TRANSPORT_MIDI_BYTE_STREAM)?.toTypedArray()
        } else {
            @Suppress("DEPRECATION")
            midiManager?.getDevices()
        }

        val peripheralInfo = devices?.find { isUsbPeripheral(it) }

        if (peripheralInfo != null) {
            midiManager?.openDevice(peripheralInfo, { device ->
                if (device != null) {
                    var inputPort: MidiInputPort? = null
                    var outputPort: MidiOutputPort? = null

                    try {
                        if (device.info.inputPortCount > 0) {
                            inputPort = device.openInputPort(0)
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("OpenMIDIControl", "Failed to open peripheral input port: ${e.message}")
                    }

                    try {
                        if (device.info.outputPortCount > 0) {
                            outputPort = device.openOutputPort(0)
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("OpenMIDIControl", "Failed to open peripheral output port: ${e.message}")
                    }

                    if (inputPort != null && outputPort != null) {
                        peripheralMidiBackend = NativeAndroidMidiBackend(device, inputPort, outputPort)
                        setupPeripheralMidiReceiver()

                        val event = mapOf(
                            "type" to "usb_state",
                            "state" to "AVAILABLE"
                        )
                        Handler(Looper.getMainLooper()).post {
                            eventSink?.success(event)
                        }
                        android.util.Log.d("OpenMIDIControl", "Connected to USB Peripheral Port natively")
                    } else {
                         // Failed to fully open ports, rollback
                         inputPort?.close()
                         outputPort?.close()
                         device.close()
                         disconnectUsbPeripheral()
                    }
                } else {
                     android.util.Log.e("OpenMIDIControl", "Failed to open USB Peripheral device")
                }
            }, Handler(Looper.getMainLooper()))
        } else {
            android.util.Log.w("OpenMIDIControl", "No USB Peripheral device found")
        }
    }


    private fun disconnectUsbPeripheral() {
        peripheralMidiBackend?.close()
        peripheralMidiBackend = null
    }

    private fun setupPeripheralMidiReceiver() {
        peripheralMidiBackend?.startReceiving { msg, offset, count, timestamp ->
            if (count < 3) return@startReceiving
            handleIncomingVirtualMidi(msg, offset, count, timestamp)
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
                            if (currentUsbMode == "peripheral") {
                                connectToUsbPeripheral()
                            }
                        } else if (!connected) {
                            lastUsbStateIsConnected = false
                            disconnectUsbPeripheral()
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
                    val mode = call.argument<String>("mode")
                    if (mode != null) {
                        currentUsbMode = mode
                        if (currentUsbMode == "host") {
                            disconnectUsbPeripheral()
                        } else if (currentUsbMode == "peripheral" && lastUsbStateIsConnected) {
                            // Turn on peripheral mode if plugged in
                            connectToUsbPeripheral()
                        }
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
                        val nowNs = System.nanoTime()
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

                            try {
                                if (BuildConfig.DEBUG) {
                                    android.util.Log.d("OpenMIDIControl", "MIDI OUT: CC $cc Value: $value")
                                }
                                val msg = byteArrayOf(0xB0.toByte(), cc.toByte(), value.toByte())
                                // Send to physically connected hardware (if any)
                                hostMidiBackend?.send(msg, 0, msg.size, nowNs)
                                // Send to virtual DAW out (e.g. FL Studio Mobile)
                                VirtualMidiService.activeInstance?.sendToDaw(msg, 0, msg.size)
                                // Send to Host PC/Mac via USB
                                // We send directly to the actively opened physical hardware input port.
                                // Do not use VirtualMidiService to attempt to reach the host PC.
                                peripheralMidiBackend?.send(msg, 0, msg.size, nowNs)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("SEND_FAILED", "Failed to send MIDI CC: ${e.message}", null)
                            }
                        } else {
                            result.success(true) // Acknowledge without sending
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "CC and value are required", null)
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

    private fun getMidiDevices(): List<Map<String, Any>> {
        val devicesList = mutableListOf<Map<String, Any>>()
        val devices: Array<MidiDeviceInfo>? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            midiManager?.getDevicesForTransport(MidiManager.TRANSPORT_MIDI_BYTE_STREAM)?.toTypedArray()
        } else {
            @Suppress("DEPRECATION")
            midiManager?.getDevices()
        }

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
        val devices: Array<MidiDeviceInfo>? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            midiManager?.getDevicesForTransport(MidiManager.TRANSPORT_MIDI_BYTE_STREAM)?.toTypedArray()
        } else {
            @Suppress("DEPRECATION")
            midiManager?.getDevices()
        }
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
            // SECURITY: Defense-in-depth bounds checking to prevent DoS via malformed MIDI packets
            if (offset < 0 || count < 0 || offset + count > msg.size) return@startReceiving

            // Check if it's a Control Change message on Channel 1 (0xB0)
            // msg[0] contains the status byte. Masking with 0xFF handles signed bytes in Kotlin
            val statusByte = msg[offset].toInt() and 0xFF
            // Do NOT send Active Sensing (0xFE) or Timing Clock (0xF8) to the Flutter UI
            if (statusByte == 0xFE || statusByte == 0xF8) {
                return@startReceiving // Skip adding to the Flutter queue
            }
            if (count < 3) return@startReceiving

            if (statusByte == 0xB0) {
                val ccNumber = msg[offset + 1].toInt() and 0xFF
                val ccValue = msg[offset + 2].toInt() and 0xFF

                if (BuildConfig.DEBUG) {
                    android.util.Log.d("OpenMIDIControl", "MIDI IN: CC $ccNumber Value: $ccValue")
                }

                val event = mapOf(
                    "type" to "cc",
                    "cc" to ccNumber,
                    "value" to ccValue,
                    "timestamp" to timestamp
                )

                incomingEventsChannel.trySend(event)
            }
        }
    }

    fun handleIncomingVirtualMidi(msg: ByteArray, offset: Int, count: Int, timestamp: Long? = null) {
        if (count == 0) return

        // SECURITY: Defense-in-depth bounds checking to prevent DoS via malformed virtual MIDI packets
        if (offset < 0 || count < 0 || offset + count > msg.size) return

        // Check if it's a Control Change message on Channel 1 (0xB0)
        val statusByte = msg[offset].toInt() and 0xFF
        // Do NOT send Active Sensing (0xFE) or Timing Clock (0xF8) to the Flutter UI
        if (statusByte == 0xFE || statusByte == 0xF8) {
            return // Skip adding to the Flutter queue
        }
        if (count < 3) return

        if (statusByte == 0xB0) {
            val ccNumber = msg[offset + 1].toInt() and 0xFF
            val ccValue = msg[offset + 2].toInt() and 0xFF

            if (BuildConfig.DEBUG) {
                android.util.Log.d("OpenMIDIControl", "MIDI IN (VIRTUAL): CC $ccNumber Value: $ccValue")
            }

            // Bidirectional Feedback Loop Prevention
            val lastTime = lastSentTime[ccNumber] ?: 0L
            val nowNs = timestamp ?: System.nanoTime()
            val timeDiff = nowNs - lastTime

            if (timeDiff < suppressionWindowNs) {
                // Ignore message from host if we recently sent *any* value for this CC.
                // This prevents delayed echoes from older values causing oscillation during rapid movement.
                return
            }

            val event = mapOf(
                "type" to "cc",
                "cc" to ccNumber,
                "value" to ccValue,
                "timestamp" to nowNs
            )

            incomingEventsChannel.trySend(event)
        }
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
                midiManager?.registerDeviceCallback(MidiManager.TRANSPORT_MIDI_BYTE_STREAM, ContextCompat.getMainExecutor(this), deviceCallback!!)
            } else {
                @Suppress("DEPRECATION")
                midiManager?.registerDeviceCallback(deviceCallback, Handler(Looper.getMainLooper()))
            }
        }
    }

    private fun teardownMidiDeviceCallback() {
        deviceCallback?.let {
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
                val batch = mutableListOf<Map<String, Any>>()
                batch.add(firstEvent)

                // Drain any other events currently in the channel buffer to process them as a batch
                while (true) {
                    val event = incomingEventsChannel.tryReceive().getOrNull() ?: break
                    batch.add(event)
                }

                if (batch.isNotEmpty()) {
                    Handler(Looper.getMainLooper()).post {
                        eventSink?.success(mapOf("type" to "batch", "events" to batch))
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
        disconnectUsbPeripheral()
        activeInstance = null
        super.onDestroy()
    }
}
