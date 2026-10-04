[CmdletBinding()]
param(
    [string]$AllowedSshCidr,
    [string]$AllowedSshIpv6Cidr,
    [switch]$AutoApprove
)

$ErrorActionPreference = 'Stop'
$terraformDir = $PSScriptRoot
$terraformExe = Join-Path (Split-Path $terraformDir -Parent) '.tools\terraform.exe'
$awsExe = Join-Path $env:LOCALAPPDATA 'Programs\Amazon\AWSCLIV2\aws.exe'

if (-not (Test-Path -LiteralPath $terraformExe)) {
    throw "Terraform was not found at $terraformExe"
}
if (-not (Test-Path -LiteralPath $awsExe)) {
    $awsCommand = Get-Command aws -ErrorAction SilentlyContinue
    if (-not $awsCommand) {
        throw 'AWS CLI was not found. Install it and run aws configure first.'
    }
    $awsExe = $awsCommand.Source
}

Write-Host 'Verifying the active AWS identity...'
$env:AWS_REGION = 'us-east-1'
$env:AWS_DEFAULT_REGION = 'us-east-1'
$env:AWS_USE_DUALSTACK_ENDPOINT = 'true'
& $awsExe sts get-caller-identity --region us-east-1 --endpoint-url https://sts.us-east-1.api.aws
if ($LASTEXITCODE -ne 0) {
    throw 'AWS authentication failed. Run aws configure, then retry.'
}

if ($AllowedSshCidr -and $AllowedSshCidr -notmatch '^(?:\d{1,3}\.){3}\d{1,3}/32$') {
    throw "AllowedSshCidr must be one IPv4 address ending in /32; got: $AllowedSshCidr"
}
if ($AllowedSshCidr) {
    $env:TF_VAR_allowed_ssh_cidr = $AllowedSshCidr
}
if (-not $AllowedSshIpv6Cidr) {
    Write-Host 'Detecting the current public IPv6 address for the bastion SSH rule...'
    $publicIpv6 = (& curl.exe -6 -sS --connect-timeout 15 https://api64.ipify.org).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Could not detect the public IPv6 address.' }
    $AllowedSshIpv6Cidr = "$publicIpv6/128"
}
if ($AllowedSshIpv6Cidr -notmatch '^[0-9a-fA-F:]+/128$') {
    throw "AllowedSshIpv6Cidr must be one IPv6 address ending in /128; got: $AllowedSshIpv6Cidr"
}
$env:TF_VAR_allowed_ssh_ipv6_cidr = $AllowedSshIpv6Cidr
Write-Host "SSH over IPv6 will be allowed only from $AllowedSshIpv6Cidr"

Push-Location $terraformDir
try {
    if (-not (Test-Path -LiteralPath 'lab-key') -or -not (Test-Path -LiteralPath 'lab-key.pub')) {
        Write-Host 'Generating the lab SSH key pair...'
        & ssh-keygen -t rsa -b 4096 -f lab-key -N '""'
        if ($LASTEXITCODE -ne 0) { throw 'ssh-keygen failed.' }
    }

    & $terraformExe init
    if ($LASTEXITCODE -ne 0) { throw 'terraform init failed.' }
    & $terraformExe validate
    if ($LASTEXITCODE -ne 0) { throw 'terraform validate failed.' }

    $applyArgs = @('apply')
    if ($AutoApprove) { $applyArgs += '-auto-approve' }
    & $terraformExe @applyArgs
    if ($LASTEXITCODE -ne 0) { throw 'terraform apply failed.' }

    Write-Host "`nDeployment complete. Use the ssh_command output to connect."
    & $terraformExe output -raw ssh_command
    Write-Host
}
finally {
    Pop-Location
}
