﻿# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Function Start-Logman {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'I like Start Logman')]
    param(
        [Parameter(Mandatory = $true)][string]$LogmanName,
        [Parameter(Mandatory = $true)][string]$ServerName
    )
    Write-Host "Starting Data Collection $LogmanName on server $ServerName"
    logman start -s $ServerName $LogmanName
}
