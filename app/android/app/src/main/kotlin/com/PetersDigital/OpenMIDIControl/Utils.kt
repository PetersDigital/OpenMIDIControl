// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
package com.petersdigital.openmidicontrol

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
