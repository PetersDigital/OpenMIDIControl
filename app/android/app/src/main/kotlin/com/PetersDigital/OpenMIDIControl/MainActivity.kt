package com.PetersDigital.OpenMIDIControl

import android.content.Context
import android.media.midi.MidiDevice
import android.media.midi.MidiDeviceInfo
import android.media.midi.MidiInputPort
import android.media.midi.MidiManager
import android.media.midi.MidiOutputPort
import android.media.midi.MidiReceiver
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        var activeInstance: MainActivity? = null
    }

    private val CHANNEL = "com.petersdigital.openmidicontrol/midi"
    private val EVENTS_CHANNEL = "com.petersdigital.openmidicontrol/midi_events"
    private var midiManager: MidiManager? = null
    private var activeDevice: MidiDevice? = null
    private var inputPort: MidiInputPort? = null
    private var outputPort: MidiOutputPort? = null
    private var midiReceiver: MidiReceiver? = null
    private var eventSink: EventChannel.EventSink? = null
    private var deviceCallback: MidiManager.DeviceCallback? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        activeInstance = this

        midiManager = context.getSystemService(Context.MIDI_SERVICE) as MidiManager?

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENTS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    setupMidiDeviceCallback()
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    teardownMidiDeviceCallback()
                }
            }
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
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

                    if (cc != null && value != null) {
                        try {
                            val msg = byteArrayOf(0xB0.toByte(), cc.toByte(), value.toByte())
                            android.util.Log.d("OpenMIDIControl", "MIDI OUT: CC $cc Value: $value")
                            // Send to physically connected hardware (if any)
                            inputPort?.send(msg, 0, msg.size)
                            // Send to virtual DAW out (e.g. FL Studio Mobile)
                            VirtualMidiService.activeInstance?.sendToDaw(msg, 0, msg.size)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SEND_FAILED", "Failed to send MIDI CC: ${e.message}", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "CC and value are required", null)
                    }
                }
                "vibrate" -> {
                    val patternRaw = call.argument<List<*>>("pattern")
                    val amplitudeRaw = call.argument<List<*>>("amplitude")

                    if (patternRaw != null && amplitudeRaw != null) {
                        val pattern = patternRaw.map { (it as Number).toLong() }.toLongArray()
                        val amplitude = amplitudeRaw.map { (it as Number).toInt() }.toIntArray()
                        vibrate(pattern, amplitude)
                        result.success(null)
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
        val devices: Array<MidiDeviceInfo>? = midiManager?.devices

        devices?.forEach { deviceInfo ->
            val id = deviceInfo.id.toString()
            val properties = deviceInfo.properties
            val name = properties.getString(MidiDeviceInfo.PROPERTY_NAME) ?: "Unknown MIDI Device"
            val manufacturer = properties.getString(MidiDeviceInfo.PROPERTY_MANUFACTURER) ?: "Unknown Manufacturer"

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
        val devices: Array<MidiDeviceInfo>? = midiManager?.devices
        val deviceInfo = devices?.find { it.id.toString() == id }

        if (deviceInfo == null) {
            result.error("DEVICE_NOT_FOUND", "Could not find device with ID: $id", null)
            return
        }

        midiManager?.openDevice(deviceInfo, { device ->
            if (device != null) {
                activeDevice = device

                // Open output port (receives from device into Android)
                val outPortToOpen = outputPortNumber ?: if (device.info.outputPortCount > 0) 0 else -1
                if (outPortToOpen >= 0 && outPortToOpen < device.info.outputPortCount) {
                    outputPort = device.openOutputPort(outPortToOpen)
                    setupMidiReceiver()
                }

                // Open input port (sends from Android to device)
                val inPortToOpen = inputPortNumber ?: if (device.info.inputPortCount > 0) 0 else -1
                if (inPortToOpen >= 0 && inPortToOpen < device.info.inputPortCount) {
                    inputPort = device.openInputPort(inPortToOpen)
                }

                result.success(true)
            } else {
                result.error("CONNECTION_FAILED", "Failed to open device", null)
            }
        }, Handler(Looper.getMainLooper()))
    }

    private fun disconnectDevice() {
        try {
            outputPort?.disconnect(midiReceiver)
            midiReceiver = null
        } catch (e: Exception) { }
        try {
            outputPort?.close()
            outputPort = null
        } catch (e: Exception) { }
        try {
            inputPort?.close()
            inputPort = null
        } catch (e: Exception) { }
        try {
            activeDevice?.close()
            activeDevice = null
        } catch (e: Exception) { }
    }

    private fun setupMidiReceiver() {
        if (midiReceiver == null) {
            midiReceiver = object : MidiReceiver() {
                override fun onSend(msg: ByteArray?, offset: Int, count: Int, timestamp: Long) {
                    if (msg == null || count < 3) return

                    // Check if it's a Control Change message on Channel 1 (0xB0)
                    // msg[0] contains the status byte. Masking with 0xFF handles signed bytes in Kotlin
                    val statusByte = msg[offset].toInt() and 0xFF
                    if (statusByte == 0xB0) {
                        val ccNumber = msg[offset + 1].toInt() and 0xFF
                        val ccValue = msg[offset + 2].toInt() and 0xFF

                    android.util.Log.d("OpenMIDIControl", "MIDI IN: CC $ccNumber Value: $ccValue")

                        val event = mapOf(
                            "type" to "cc",
                            "cc" to ccNumber,
                            "value" to ccValue
                        )

                        Handler(Looper.getMainLooper()).post {
                            eventSink?.success(event)
                        }
                    }
                }
            }
            outputPort?.connect(midiReceiver)
        }
    }

    fun handleIncomingVirtualMidi(msg: ByteArray, offset: Int, count: Int) {
        if (count < 3) return

        // Check if it's a Control Change message on Channel 1 (0xB0)
        val statusByte = msg[offset].toInt() and 0xFF
        if (statusByte == 0xB0) {
            val ccNumber = msg[offset + 1].toInt() and 0xFF
            val ccValue = msg[offset + 2].toInt() and 0xFF

            android.util.Log.d("OpenMIDIControl", "MIDI IN: CC $ccNumber Value: $ccValue")

            val event = mapOf(
                "type" to "cc",
                "cc" to ccNumber,
                "value" to ccValue
            )

            Handler(Looper.getMainLooper()).post {
                eventSink?.success(event)
            }
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
                    if (activeDevice?.info?.id == device.id) {
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
            midiManager?.registerDeviceCallback(deviceCallback, Handler(Looper.getMainLooper()))
        }
    }

    private fun teardownMidiDeviceCallback() {
        deviceCallback?.let {
            midiManager?.unregisterDeviceCallback(it)
            deviceCallback = null
        }
    }

    override fun onDestroy() {
        teardownMidiDeviceCallback()
        disconnectDevice()
        activeInstance = null
        super.onDestroy()
    }
}
