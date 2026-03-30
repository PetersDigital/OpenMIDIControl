# Copyright (c) 2026 Peters Digital
# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
$runIds = gh api repos/PetersDigital/OpenMIDIControl/actions/runs --paginate `
  --jq ".workflow_runs[].id"

$runIds | ForEach-Object -Parallel {
    Write-Host "Deleting run $_"
    gh api repos/PetersDigital/OpenMIDIControl/actions/runs/$_ -X DELETE
} -ThrottleLimit 10