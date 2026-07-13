$ErrorActionPreference = "Stop"

function Complete-WindowsUpdateStep {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [int]$ExitCode = 0
    )

    if ($ExitCode -ne 0 -and $env:WINDOWS_UPDATE_STRICT -eq "true") {
        throw $Message
    }

    if ($ExitCode -ne 0) {
        Write-Warning $Message
    } else {
        Write-Host $Message
    }

    exit 0
}

if ($env:ENABLE_WINDOWS_UPDATE -ne "true") {
    Write-Host "Windows Update during template build disabled."
    exit 0
}

Write-Host "Starting Windows Update scan. This may take a long time."

try {
    Set-Service -Name wuauserv -StartupType Manual -ErrorAction SilentlyContinue
    Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    Start-Service -Name bits -ErrorAction SilentlyContinue

    $session = New-Object -ComObject Microsoft.Update.Session
    $searcher = $session.CreateUpdateSearcher()
    $result = $searcher.Search("IsInstalled=0 and Type='Software'")

    if ($result.Updates.Count -eq 0) {
        Complete-WindowsUpdateStep -Message "No Windows Updates available."
    }

    $updates = New-Object -ComObject Microsoft.Update.UpdateColl
    foreach ($update in $result.Updates) {
        if (-not $update.EulaAccepted) {
            $update.AcceptEula()
        }
        [void]$updates.Add($update)
    }

    $downloader = $session.CreateUpdateDownloader()
    $downloader.Updates = $updates
    [void]$downloader.Download()

    $installer = $session.CreateUpdateInstaller()
    $installer.Updates = $updates
    $installResult = $installer.Install()

    Write-Host "Windows Update completed with result code $($installResult.ResultCode). Reboot required: $($installResult.RebootRequired)."

    if ($installResult.RebootRequired) {
        Write-Warning "Windows Updates requested a reboot. Skipping automatic reboot in this Packer pass; rebuild the template again if more updates are needed."
    }

    Complete-WindowsUpdateStep -Message "Windows Update step completed."
} catch {
    $message = "Windows Update step failed: $($_.Exception.Message). Continuing because WINDOWS_UPDATE_STRICT is not true."

    if (Get-Command UsoClient.exe -ErrorAction SilentlyContinue) {
        Write-Warning "Trying non-blocking UsoClient scan/start fallback."
        try {
            Start-Process -FilePath "UsoClient.exe" -ArgumentList "StartScan" -WindowStyle Hidden -ErrorAction SilentlyContinue
            Start-Process -FilePath "UsoClient.exe" -ArgumentList "StartDownload" -WindowStyle Hidden -ErrorAction SilentlyContinue
            Start-Process -FilePath "UsoClient.exe" -ArgumentList "StartInstall" -WindowStyle Hidden -ErrorAction SilentlyContinue
        } catch {
            Write-Warning "UsoClient fallback also failed: $($_.Exception.Message)."
        }
    }

    Complete-WindowsUpdateStep -Message $message -ExitCode 1
}
