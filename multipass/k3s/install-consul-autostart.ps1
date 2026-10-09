[CmdletBinding()]
param(
    [switch]$Uninstall
)

# Adds (or removes with -Uninstall) a shortcut in the current user's Startup folder that runs
# start-consul.ps1 hidden at logon. No administrator rights needed; visible in Task Manager > Startup apps.
$ErrorActionPreference = "Stop"

$shortcutPath = Join-Path ([Environment]::GetFolderPath("Startup")) "Consul (mate-lab).lnk"

if ($Uninstall) {
    if (Test-Path -LiteralPath $shortcutPath) {
        Remove-Item -LiteralPath $shortcutPath
        Write-Host "Removed Consul autostart: $shortcutPath"
    }
    else {
        Write-Host "Consul autostart is not installed."
    }
    exit 0
}

$startScript = Join-Path $PSScriptRoot "start-consul.ps1"
if (-not (Test-Path -LiteralPath $startScript -PathType Leaf)) {
    throw "start-consul.ps1 not found next to this script: $startScript"
}

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = Join-Path $PSHOME "powershell.exe"
$shortcut.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$startScript`""
$shortcut.WorkingDirectory = $PSScriptRoot
$shortcut.WindowStyle = 7
$shortcut.Description = "Start local Consul server for kubernetes-mate-lab"
$shortcut.Save()

Write-Host "Consul autostart installed: $shortcutPath"
Write-Host "It runs $startScript at logon; remove it with: install-consul-autostart.ps1 -Uninstall"
