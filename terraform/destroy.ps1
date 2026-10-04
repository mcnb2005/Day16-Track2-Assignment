[CmdletBinding()]
param(
    [string]$AllowedSshCidr,
    [string]$AllowedSshIpv6Cidr,
    [switch]$AutoApprove
)

$ErrorActionPreference = 'Stop'
$terraformDir = $PSScriptRoot
$terraformExe = Join-Path (Split-Path $terraformDir -Parent) '.tools\terraform.exe'

if (-not (Test-Path -LiteralPath $terraformExe)) {
    throw "Terraform was not found at $terraformExe"
}
if ($AllowedSshCidr) {
    $env:TF_VAR_allowed_ssh_cidr = $AllowedSshCidr
}
if (-not $AllowedSshIpv6Cidr) {
    $publicIpv6 = (& curl.exe -6 -sS --connect-timeout 15 https://api64.ipify.org).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Could not detect the public IPv6 address.' }
    $AllowedSshIpv6Cidr = "$publicIpv6/128"
}
$env:TF_VAR_allowed_ssh_ipv6_cidr = $AllowedSshIpv6Cidr
$env:AWS_REGION = 'us-east-1'
$env:AWS_DEFAULT_REGION = 'us-east-1'
$env:AWS_USE_DUALSTACK_ENDPOINT = 'true'

Push-Location $terraformDir
try {
    $destroyArgs = @('destroy')
    if ($AutoApprove) { $destroyArgs += '-auto-approve' }
    & $terraformExe @destroyArgs
    if ($LASTEXITCODE -ne 0) { throw 'terraform destroy failed.' }
}
finally {
    Pop-Location
}
