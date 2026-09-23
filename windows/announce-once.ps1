param([string]$Config = "$env:ProgramData\Dutflow\config.json")
$ErrorActionPreference = 'Stop'
$c = Get-Content -Raw $Config | ConvertFrom-Json
$ip = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } | Sort-Object @{Expression={ if ($_.IPAddress -match '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)') { 0 } else { 1 } }} | Select-Object -First 1 -ExpandProperty IPAddress
$ip = [string]$ip
if (-not $ip) { throw 'No usable IPv4 address found' }
$body = @{ip = $ip} | ConvertTo-Json -Compress
$tmp = [IO.Path]::GetTempFileName()
try {
  [IO.File]::WriteAllText($tmp, $body)
  & curl.exe --fail --silent --show-error --max-time 10 -X POST "$($c.url.TrimEnd('/'))/v1/announce" -H "Authorization: Bearer $($c.token)" -H 'Content-Type: application/json' --data-binary "@$tmp" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "rendezvous announce failed ($LASTEXITCODE)" }
} finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }