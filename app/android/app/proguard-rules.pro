# Copyright (c) 2026 Peters Digital
# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

# Keep Flutter and app entrypoints intact during release shrinking.
-keep class io.flutter.** { *; }
-keep class com.petersdigital.openmidicontrol.** { *; }