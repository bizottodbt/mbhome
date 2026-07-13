$ErrorActionPreference = "Stop"

Write-Host "Checking for attached VirtIO/QEMU guest tools media."

if ($env:VIRTIO_WIN_ISO_ATTACHED -ne "true") {
    Write-Host "No virtio-win ISO configured; skipping QEMU guest tools installation."
    exit 0
}

$cdroms = Get-CimInstance Win32_LogicalDisk -Filter "DriveType = 5" |
    Where-Object { $_.DeviceID }

$guestTools = $null
$guestAgentMsi = $null

foreach ($cdrom in $cdroms) {
    $root = "$($cdrom.DeviceID)\"
    $candidateTools = Join-Path $root "virtio-win-guest-tools.exe"
    $candidateAgent = Join-Path $root "guest-agent\qemu-ga-x86_64.msi"

    if (Test-Path $candidateTools) {
        $guestTools = $candidateTools
        break
    }

    if (Test-Path $candidateAgent) {
        $guestAgentMsi = $candidateAgent
    }
}

if ($guestTools) {
    Write-Host "Installing virtio-win guest tools from $guestTools."
    $process = Start-Process -FilePath $guestTools -ArgumentList "/quiet", "/norestart" -Wait -PassThru
    if ($process.ExitCode -notin 0, 3010) {
        throw "virtio-win guest tools installer failed with exit code $($process.ExitCode)."
    }
    exit 0
}

if ($guestAgentMsi) {
    Write-Host "Installing QEMU guest agent from $guestAgentMsi."
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "`"$guestAgentMsi`"", "/qn", "/norestart" -Wait -PassThru
    if ($process.ExitCode -notin 0, 3010) {
        throw "QEMU guest agent installer failed with exit code $($process.ExitCode)."
    }
    exit 0
}

Write-Host "No virtio-win guest tools installer found on attached CD-ROM media; skipping."
