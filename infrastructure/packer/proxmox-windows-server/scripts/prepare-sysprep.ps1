$ErrorActionPreference = "Stop"

Write-Host "Preparing Windows template for Sysprep."

if ($env:DISABLE_INSECURE_WINRM_AFTER_BUILD -eq "true") {
    Write-Host "Disabling temporary Basic/unencrypted WinRM settings."
    winrm set winrm/config/service/auth '@{Basic="false"}'
    winrm set winrm/config/service '@{AllowUnencrypted="false"}'
}

Write-Host "Cleaning temporary files."
foreach ($tempPath in @($env:TEMP, "C:\Windows\Temp")) {
    if (-not (Test-Path $tempPath)) {
        continue
    }

    Get-ChildItem -Path $tempPath -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike "packer-*" } |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "Clearing common Windows setup logs from temporary build state."
wevtutil el | ForEach-Object {
    try {
        wevtutil cl $_ 2>$null
    } catch {
        Write-Host "Could not clear event log $_."
    }
}

$sysprep = "$env:SystemRoot\System32\Sysprep\Sysprep.exe"
$arguments = "/generalize /oobe /quit /quiet"

if ($env:ENABLE_CLOUDBASE_INIT -eq "true") {
    $cloudbaseUnattend = "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\Unattend.xml"
    if (Test-Path $cloudbaseUnattend) {
        $arguments = "$arguments /unattend:`"$cloudbaseUnattend`""
    }
}

Write-Host "Starting Sysprep with arguments: $arguments"
$process = Start-Process -FilePath $sysprep -ArgumentList $arguments -Wait -PassThru
if ($process.ExitCode -ne 0) {
    throw "Sysprep failed with exit code $($process.ExitCode)."
}

Write-Host "Sysprep completed. Packer will stop the VM and convert it to a template."
