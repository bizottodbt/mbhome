$ErrorActionPreference = "Stop"

if ($env:ENABLE_CLOUDBASE_INIT -ne "true") {
    Write-Host "Cloudbase-Init installation disabled."
    exit 0
}

if ([string]::IsNullOrWhiteSpace($env:CLOUDBASE_INIT_MSI_URL)) {
    throw "ENABLE_CLOUDBASE_INIT is true, but CLOUDBASE_INIT_MSI_URL is empty."
}

$downloadPath = Join-Path $env:TEMP "CloudbaseInitSetup.msi"

Write-Host "Downloading Cloudbase-Init from $env:CLOUDBASE_INIT_MSI_URL."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $env:CLOUDBASE_INIT_MSI_URL -OutFile $downloadPath -UseBasicParsing

Write-Host "Installing Cloudbase-Init."
$arguments = @(
    "/i", "`"$downloadPath`"",
    "/qn",
    "/norestart"
)
$process = Start-Process -FilePath "msiexec.exe" -ArgumentList $arguments -Wait -PassThru
if ($process.ExitCode -notin 0, 3010) {
    throw "Cloudbase-Init installer failed with exit code $($process.ExitCode)."
}

$configDir = "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf"
$configPath = Join-Path $configDir "cloudbase-init.conf"
$unattendConfigPath = Join-Path $configDir "cloudbase-init-unattend.conf"

if (Test-Path $configDir) {
    $config = @"
[DEFAULT]
username=Administrator
groups=Administrators
inject_user_password=true
first_logon_behaviour=no
config_drive_raw_hhd=true
config_drive_cdrom=true
bsdtar_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\bin\bsdtar.exe
mtools_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\bin\
metadata_services=cloudbaseinit.metadata.services.nocloudservice.NoCloudConfigDriveService,cloudbaseinit.metadata.services.configdrive.ConfigDriveService
plugins=cloudbaseinit.plugins.common.mtu.MTUPlugin,cloudbaseinit.plugins.windows.ntpclient.NTPClientPlugin,cloudbaseinit.plugins.common.sethostname.SetHostNamePlugin,cloudbaseinit.plugins.windows.createuser.CreateUserPlugin,cloudbaseinit.plugins.common.networkconfig.NetworkConfigPlugin,cloudbaseinit.plugins.common.userdata.UserDataPlugin,cloudbaseinit.plugins.windows.licensing.WindowsLicensingPlugin,cloudbaseinit.plugins.common.localscripts.LocalScriptsPlugin
allow_reboot=true
stop_service_on_exit=false
"@
    Set-Content -Path $configPath -Value $config -Encoding ASCII
    Set-Content -Path $unattendConfigPath -Value $config -Encoding ASCII
}

Write-Host "Cloudbase-Init installed."
