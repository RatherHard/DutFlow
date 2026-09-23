#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
Enable boot-time background operation using the existing deployment.
Run as Administrator. Does not change credentials, SSH keys, or firewall rules.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Join-Path $env:ProgramData 'Dutflow'
$taskName = 'DutflowAnnounce'
$loop = Join-Path $root 'announce-loop.ps1'
$configPath = Join-Path $root 'config.json'

# Preflight before changing services or replacing the task.
foreach ($path in @($loop, (Join-Path $root 'announce-once.ps1'), $configPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required deployment file is missing: $path"
    }
}
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
if (-not $config.url -or -not $config.token) {
    throw 'Existing config.json must contain url and token. Configuration was not changed.'
}
foreach ($name in @('sshd', 'SunshineService')) {
    $null = Get-Service -Name $name -ErrorAction Stop
}

$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) {
    $backup = Join-Path $root ("DutflowAnnounce-backup-{0}.xml" -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
    Export-ScheduledTask -TaskName $taskName | Set-Content -LiteralPath $backup -Encoding Unicode
    Write-Host "Previous task definition saved to: $backup"
}

foreach ($name in @('sshd', 'SunshineService')) {
    Set-Service -Name $name -StartupType Automatic
    Start-Service -Name $name
}

$action = New-ScheduledTaskAction `
    -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$loop`"" `
    -WorkingDirectory $root
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RestartCount 999 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -MultipleInstances IgnoreNew

if ($existing) { Stop-ScheduledTask -TaskName $taskName }
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
    -Principal $principal -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName $taskName
Start-Sleep -Seconds 3

$task = Get-ScheduledTask -TaskName $taskName
if ($task.State -ne 'Running') {
    $info = Get-ScheduledTaskInfo -TaskName $taskName
    throw "Task did not stay running. State=$($task.State), LastTaskResult=$($info.LastTaskResult)"
}
Write-Host 'SUCCESS: SYSTEM startup task is running in the background.'
Write-Host 'No login required; no time limit; battery operation enabled.'
Write-Host 'Existing credentials and config.json were not modified.'
Get-Service -Name sshd, SunshineService | Format-Table Name, Status, StartType
$task | Select-Object TaskName, State | Format-Table
$task.Principal | Select-Object UserId, LogonType, RunLevel | Format-List
$task.Settings | Select-Object ExecutionTimeLimit, DisallowStartIfOnBatteries, StopIfGoingOnBatteries | Format-List
Write-Host 'When convenient, reboot Windows and verify dutflow ip / dutflow ssh hostname from Arch.'
Write-Host 'This script does not reboot the machine or claim reboot validation.'