package com.PetersDigital.OpenMIDIControl

import android.content.Context
import android.media.midi.MidiDevice
import android.media.midi.MidiDeviceInfo
import android.media.midi.MidiManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.petersdigital.openmidicontrol/midi"
    private var midiManager: MidiManager? = null
    private var activeDevice: MidiDevice? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        midiManager = context.getSystemService(Context.MIDI_SERVICE) as MidiManager?

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getMidiDevices" -> {
                    result.success(getMidiDevices())
                }
                "connectToDevice" -> {
                    val id = call.argument<String>("id")
                    if (id != null) {
                        connectToDevice(id, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Device ID is required", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getMidiDevices(): List<Map<String, String>> {
        val devicesList = mutableListOf<Map<String, String>>()
        val devices: Array<MidiDeviceInfo>? = midiManager?.devices

        devices?.forEach { deviceInfo ->
            val id = deviceInfo.id.toString()
            val properties = deviceInfo.properties
            val name = properties.getString(MidiDeviceInfo.PROPERTY_NAME) ?: "Unknown MIDI Device"
            val manufacturer = properties.getString(MidiDeviceInfo.PROPERTY_MANUFACTURER) ?: "Unknown Manufacturer"

            devicesList.add(
                mapOf(
                    "id" to id,
                    "name" to name,
                    "manufacturer" to manufacturer
                )
            )
        }

        return devicesList
    }

    private fun connectToDevice(id: String, result: MethodChannel.Result) {
        val devices: Array<MidiDeviceInfo>? = midiManager?.devices
        val deviceInfo = devices?.find { it.id.toString() == id }

        if (deviceInfo == null) {
            result.error("DEVICE_NOT_FOUND", "Could not find device with ID: $id", null)
            return
        }

        midiManager?.openDevice(deviceInfo, { device ->
            if (device != null) {
                activeDevice = device
                result.success(true)
            } else {
                result.error("CONNECTION_FAILED", "Failed to open device", null)
            }
        }, Handler(Looper.getMainLooper()))
    }
}
