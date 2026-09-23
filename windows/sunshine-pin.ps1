[CmdletBinding(DefaultParameterSetName='Pin')]
param(
 [Parameter(Mandatory=$true,ParameterSetName='Pin')][ValidatePattern('^\d{4}$')][string]$Pin,
 [Parameter(Mandatory=$true,ParameterSetName='Check')][switch]$Check
)
$ErrorActionPreference = 'Stop'
$credential = Import-Clixml -LiteralPath "$env:USERPROFILE\.ssh\dutflow-sunshine.xml"
$basic = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($credential.UserName + ':' + $credential.GetNetworkCredential().Password))
$config = 'header = "Authorization: Basic ' + $basic + '"'
$tmp = [IO.Path]::GetTempFileName()
try {
    $path = 'apps'; $method = 'GET'; $extra = @()
    if (-not $Check) {
        $path = 'pin'; $method = 'POST'
        [IO.File]::WriteAllText($tmp, (@{pin=$Pin;name='dutflow-arch'} | ConvertTo-Json -Compress))
        $extra = @('--data-binary', "@$tmp")
    }
    # Credentials go via stdin, never command line. Self-signed TLS only on loopback.
    $response = $config | & curl.exe --config - --fail --silent --show-error --insecure --max-time 15 -X $method "https://127.0.0.1:47990/api/$path" -H 'Content-Type: application/json' @extra
    if ($LASTEXITCODE -ne 0) { throw 'Sunshine API authentication/request failed' }
    $result = ($response -join "`n") | ConvertFrom-Json
    if ($Check) { Write-Output 'Sunshine authentication OK' }
    elseif ($result.status -eq $true) { Write-Output 'Sunshine PIN accepted' }
    else { throw 'Sunshine rejected PIN; check that Moonlight pairing is pending' }
} finally { [IO.File]::Delete($tmp) }