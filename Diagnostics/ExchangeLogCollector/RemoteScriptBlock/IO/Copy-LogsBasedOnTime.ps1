﻿# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

. $PSScriptRoot\Copy-BulkItems.ps1
Function Copy-LogsBasedOnTime {
    param(
        [Parameter(Mandatory = $false)][string]$LogPath,
        [Parameter(Mandatory = $true)][string]$CopyToThisLocation
    )
    Write-Verbose("Function Enter: Copy-LogsBasedOnTime")
    Write-Verbose("Passed: [string]LogPath: {0} | [string]CopyToThisLocation: {1}" -f $LogPath, $CopyToThisLocation)

    if ([string]::IsNullOrEmpty($LogPath)) {
        Write-Verbose("Failed to provide a valid log path to copy.")
        return
    }

    New-Item -ItemType Directory -Path $CopyToThisLocation -Force | Out-Null

    Function NoFilesInLocation {
        param(
            [Parameter(Mandatory = $true)][string]$CopyFromLocation,
            [Parameter(Mandatory = $true)][string]$CopyToLocation
        )
        Write-Host "It doesn't look like you have any data in this location $CopyFromLocation." -ForegroundColor "Yellow"
        #Going to place a file in this location so we know what happened
        $tempFile = $CopyToLocation + "\NoFilesDetected.txt"
        New-Item $tempFile -ItemType File -Value $LogPath | Out-Null
        Start-Sleep 1
    }

    $copyFromDate = [DateTime]::Now - $PassedInfo.TimeSpan
    Write-Verbose("Copy From Date: {0}" -f $copyFromDate)
    $skipCopy = $false
    if (!(Test-Path $LogPath)) {
        #if the directory isn't there, we need to handle it
        NoFilesInLocation -CopyFromLocation $LogPath -CopyToLocation $CopyToThisLocation
        Write-Verbose("Function Exit: Copy-LogsBasedOnTime")
        return
    }
    #We are not copying files recurse so we need to not include possible directories or we will throw an error
    $files = Get-ChildItem $LogPath | Sort-Object LastWriteTime -Descending | Where-Object { $_.LastWriteTime -ge $copyFromDate -and $_.Mode -notlike "d*" }
    #if we don't have any logs, we want to attempt to copy something

    if ($null -eq $files) {
        <#
                There are a few different reasons to get here
                1. We don't have any files in the timeframe request in the directory that we are looking at
                2. We have sub directories that we need to look into and look at those files (Only if we don't have files in the currently location so we aren't pulling files like the index files from message tracking)
            #>
        Write-Verbose("Copy-LogsBasedOnTime: Failed to find any logs in the directory provided, need to do a deeper look to find some logs that we want.")
        $allFiles = Get-ChildItem $LogPath | Sort-Object LastWriteTime -Descending
        Write-Verbose("Displaying all items in the directory: {0}" -f $LogPath)
        foreach ($file in $allFiles) {
            Write-Verbose("File Name: {0} Last Write Time: {1}" -f $file.Name, $file.LastWriteTime)
        }

        #Let's see if we have any files in this location while having directories
        $directories = $allFiles | Where-Object { $_.Mode -like "d*" }
        $filesInDirectory = $allFiles | Where-Object { $_.Mode -notlike "d*" }

        if (($null -ne $directories) -and
            ($null -ne $filesInDirectory)) {
            #This means we should be looking in the sub directories not the current directory so let's re-do that logic to try to find files in that timeframe.
            foreach ($dir in $directories) {
                $newLogPath = $dir.FullName
                $newCopyToThisLocation = "{0}\{1}" -f $CopyToThisLocation, $dir.Name
                New-Item -ItemType Directory -Path $newCopyToThisLocation -Force | Out-Null
                $files = Get-ChildItem $newLogPath | Sort-Object LastWriteTime -Descending | Where-Object { $_.LastWriteTime -ge $copyFromDate -and $_.Mode -notlike "d*" }

                if ($null -eq $files) {
                    NoFilesInLocation -CopyFromLocation $newLogPath -CopyToLocation $newCopyToThisLocation
                } else {
                    Write-Verbose("Found {0} number of files at the location {1}" -f $files.Count, $newLogPath)
                    $filesFullPath = @()
                    $files | ForEach-Object { $filesFullPath += $_.VersionInfo.FileName }
                    Copy-BulkItems -CopyToLocation $newCopyToThisLocation -ItemsToCopyLocation $filesFullPath
                    Invoke-ZipFolder -Folder $newCopyToThisLocation
                }
            }
            Write-Verbose("Function Exit: Copy-LogsBasedOnTime")
            return
        }

        #If we get here, we want to find the latest file that isn't a directory.
        $files = $allFiles | Where-Object { $_.Mode -notlike "d*" } | Select-Object -First 1

        #If we are still null, we want to let them know
        if ($null -eq $files) {
            $skipCopy = $true
            NoFilesInLocation -CopyFromLocation $LogPath -CopyToLocation $CopyToThisLocation
        }
    }
    Write-Verbose("Found {0} number of files at the location {1}" -f $Files.Count, $LogPath)
    #ResetFiles to full path
    $filesFullPath = @()
    $files | ForEach-Object { $filesFullPath += $_.VersionInfo.FileName }

    if (-not ($skipCopy)) {
        Copy-BulkItems -CopyToLocation $CopyToThisLocation -ItemsToCopyLocation $filesFullPath
        Invoke-ZipFolder -Folder $CopyToThisLocation
    }
    Write-Verbose("Function Exit: Copy-LogsBasedOnTime")
}
