#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
$key = (Get-Content -Raw "$env:ProgramData\Dutflow\arch-authorized.pub").Trim()
if ($key -notmatch '^ssh-ed25519 [A-Za-z0-9+/=]+(?: .*)?$') { throw 'Invalid public key' }
$path = "$env:ProgramData\ssh\administrators_authorized_keys"
$existing = ''
if (Test-Path $path) {
    Copy-Item $path "$path.dutflow-$(Get-Date -Format yyyyMMddHHmmss).bak"
    $existing = [IO.File]::ReadAllText($path)
}
if (-not ($existing.Split("`n") | Where-Object { $_.Trim() -eq $key })) {
    [IO.File]::WriteAllText($path, $existing.TrimEnd()+"`r`n"+$key+"`r`n")
}
& icacls.exe $path /inheritance:r /grant:r '*S-1-5-18:F' '*S-1-5-32-544:F'
if ($LASTEXITCODE -ne 0) { throw 'Cannot secure authorized keys' }
Write-Host 'Arch key installed. Existing keys retained.'
Write-Host 'Enter existing Sunshine web UI credentials, NOT Windows credentials.'
$credential = Get-Credential
if (-not $credential) { throw 'Credential entry cancelled' }
New-Item -ItemType Directory -Force "$env:USERPROFILE\.ssh" | Out-Null
$credential | Export-Clixml -LiteralPath "$env:USERPROFILE\.ssh\dutflow-sunshine.xml"
& "$env:ProgramData\Dutflow\sunshine-pin.ps1" -Check