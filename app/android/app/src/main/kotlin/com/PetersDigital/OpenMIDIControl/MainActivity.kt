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
    // We store the 32-bit UMP and its timestamp as a Pair to ensure atomic queuing.
    private val incomingEventsChannel = Channel<Pair<Long, Long>>(capacity = 1000, onBufferOverflow = BufferOverflow.DROP_OLDEST)
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

    private fun connectToUsbPeripheral() {
        val devices = getAvailableMidiDevices()

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

    private fun processMidiPayload(msg: ByteArray, offset: Int, count: Int, timestamp: Long, isVirtual: Boolean) {
        // SECURITY: Defense-in-depth bounds checking to prevent DoS via malformed MIDI packets
        if (offset < 0 || count < 0 || offset + count > msg.size) return

        // Check for UMP alignment and validate Message Type (MT) to prevent false positives
        val isUmp = if (count >= 4 && count % 4 == 0) {
            val firstUmpWord = ((msg[offset].toInt() and 0xFF) shl 24) or
                               ((msg[offset + 1].toInt() and 0xFF) shl 16) or
                               ((msg[offset + 2].toInt() and 0xFF) shl 8) or
                               (msg[offset + 3].toInt() and 0xFF)
            val firstMessageType = (firstUmpWord ushr 28) and 0xF
            firstMessageType == 0x1 || firstMessageType == 0x2
        } else false

        if (isUmp) {
            // Process UMP (32-bit Integers)
            for (i in offset until offset + count step 4) {
                // Reconstruct 32-bit integer (Big-Endian)
                val byte1 = msg[i].toInt() and 0xFF
                val byte2 = msg[i + 1].toInt() and 0xFF
                val byte3 = msg[i + 2].toInt() and 0xFF
                val byte4 = msg[i + 3].toInt() and 0xFF

                val umpInt = (byte1 shl 24) or (byte2 shl 16) or (byte3 shl 8) or byte4

                // Extract Message Type (MT) from bits 31-28
                val messageType = (umpInt ushr 28) and 0xF

                if (messageType == 0x1) {
                    // MT 0x1: System Real-Time
                    // Status byte is bits 23-16 (byte2 in Big-Endian layout of a 32-bit UMP containing an 8-bit message)
                    // Actually, for MT 1, the UMP format places the status byte in byte1 (bits 23-16 of the 32 bit word after MT and Group).
                    // Let's rely on standard UMP format: MT (4 bits), Group (4 bits), Status (8 bits).
                    // So Status is byte2 (bits 23-16 of the 32-bit word).
                    val status = (umpInt ushr 16) and 0xFF

                    if (status == 0xF8 || status == 0xFE) {
                        // Drop Timing Clock (0xF8) and Active Sensing (0xFE)
                        continue
                    }
                    // Drop other MT 1 messages for now
                } else if (messageType == 0x2) {
                    // MT 0x2: MIDI 1.0 Channel Voice
                    // Format: MT(4), Group(4), Status(8), Data1(8), Data2(8)
                    // Status is byte2, Data1 is byte3, Data2 is byte4
                    val group = (umpInt ushr 24) and 0xF
                    val status = (umpInt ushr 16) and 0xFF

                    if (status in 0xB0..0xBF) { // Control Change
                        val ccNumber = (umpInt ushr 8) and 0xFF
                        val ccValue = umpInt and 0xFF

                        forwardCcEvent(group, status, ccNumber, ccValue, timestamp, isVirtual)
                    }
                }
                // Silently drop other MTs
            }
        } else {
            // Process Legacy Byte Stream (Fallback)
            // Handle potentially batched legacy messages by iterating (simplistic approach for standard 3-byte CCs)
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
                    forwardCcEvent(0, statusByte, ccNumber, ccValue, timestamp, isVirtual)
                    i += 3
                } else {
                    // Unhandled legacy message or incomplete buffer; just advance by 1 to recover
                    i += 1
                }
            }
        }
    }

    private fun forwardCcEvent(group: Int, status: Int, ccNumber: Int, ccValue: Int, timestamp: Long, isVirtual: Boolean) {
        if (BuildConfig.DEBUG) {
            val typeStr = if (isVirtual) " (VIRTUAL)" else ""
            android.util.Log.d("OpenMIDIControl", "MIDI IN$typeStr: CC $ccNumber Value: $ccValue Ch: ${(status and 0x0F) + 1}")
        }

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

    private fun setupMidiReceiver() {
        hostMidiBackend?.startReceiving { msg, offset, count, timestamp ->
            processMidiPayload(msg, offset, count, timestamp, isVirtual = false)
        }
    }

    fun handleIncomingVirtualMidi(msg: ByteArray, offset: Int, count: Int, timestamp: Long? = null) {
        if (count == 0) return
        val nowNs = timestamp ?: System.nanoTime()
        processMidiPayload(msg, offset, count, nowNs, isVirtual = true)
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
                // Use primitive array batching to avoid Object allocation on the Main thread
                val batch = LongArray(2000)
                batch[0] = firstEvent.first
                batch[1] = firstEvent.second
                var count = 2

                // Drain any other events currently in the channel buffer
                while (count + 1 < batch.size) {
                    val nextEvent = incomingEventsChannel.tryReceive().getOrNull() ?: break
                    batch[count++] = nextEvent.first
                    batch[count++] = nextEvent.second
                }

                if (count > 0) {
                    // Create an exact-sized copy of the payload to dispatch
                    val payload = batch.copyOfRange(0, count)
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
        disconnectUsbPeripheral()
        activeInstance = null
        super.onDestroy()
    }
}
