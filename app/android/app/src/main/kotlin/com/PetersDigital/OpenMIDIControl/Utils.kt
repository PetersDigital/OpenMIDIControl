package com.PetersDigital.OpenMIDIControl

import android.util.Log

/**
 * Executes the given [block] safely, catching and logging any exceptions.
 */
inline fun safeExecute(tag: String = "OpenMIDIControl", block: () -> Unit) {
    try {
        block()
    } catch (e: Exception) {
        Log.w(tag, "Safe execute failed: ${e.message}")
    }
}
