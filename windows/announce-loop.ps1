param([string]$Config = "$env:ProgramData\Dutflow\config.json")
$ErrorActionPreference = 'Stop'
while ($true) { try { & "$PSScriptRoot\announce-once.ps1" -Config $Config } catch { Write-EventLog -LogName Application -Source Dutflow -EntryType Warning -EventId 1 -Message $_.Exception.Message -ErrorAction SilentlyContinue }; Start-Sleep -Seconds 30 }
