#Requires -RunAsAdministrator
param(
 [string]$Url,
 [string]$Token,
 [string]$SshUser = $env:USERNAME,
 [string]$ConfigFile = "$PSScriptRoot\config.local.json"
)
$ErrorActionPreference='Stop'
# Prefer a private config file, so secrets do not appear in shell history or argv.
if (-not $Url -and -not $Token) {
    $private = Get-Content -LiteralPath $ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $Url = [string]$private.url
    $Token = [string]$private.token
    if (-not $PSBoundParameters.ContainsKey('SshUser') -and $private.ssh_user) {
        $SshUser = [string]$private.ssh_user
    }
}
if (-not $Url -or -not $Token -or $Token -eq 'REPLACE_WITH_SERVER_TOKEN') {
    throw 'Configure url/token in windows/config.local.json before installing.'
}
$uri = [Uri]$Url
if (-not $uri.IsAbsoluteUri -or $uri.Scheme -ne 'https') {
    throw 'The rendezvous URL must use HTTPS.'
}
$root="$env:ProgramData\Dutflow"; New-Item -ItemType Directory -Force $root | Out-Null
Copy-Item "$PSScriptRoot\announce-once.ps1", "$PSScriptRoot\announce-loop.ps1", "$PSScriptRoot\sunshine-pin.ps1" $root -Force
@{url=$Url.TrimEnd('/'); token=$Token; ssh_user=$SshUser} | ConvertTo-Json | Set-Content -Encoding utf8 "$root\config.json"
New-NetFirewallRule -DisplayName 'dutflow OpenSSH (Private)' -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow -Profile Private -ErrorAction SilentlyContinue | Out-Null
Set-Service sshd -StartupType Automatic; Start-Service sshd
$action=New-ScheduledTaskAction -Execute powershell.exe -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$root\announce-loop.ps1`""
$trigger=New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -TaskName DutflowAnnounce -Action $action -Trigger $trigger -Principal (New-ScheduledTaskPrincipal -UserId SYSTEM -RunLevel Highest) -Force | Out-Null
Start-ScheduledTask DutflowAnnounce
Write-Host "Installed. Verify with: Get-ScheduledTask DutflowAnnounce"