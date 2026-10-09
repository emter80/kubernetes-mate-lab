[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$certificatePath = Join-Path $PSScriptRoot "02-bootstrap\09-oidc\multipass-root-ca.crt"
$expectedSubject = "CN=multipass-root-ca"

if (-not (Test-Path -LiteralPath $certificatePath -PathType Leaf)) {
    throw "Root CA certificate not found at '$certificatePath'. Run the cluster build first."
}

$certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($certificatePath)
if ($certificate.HasPrivateKey) {
    throw "The file contains a private key. Refusing to install it as a trusted root."
}

if ($certificate.Subject -ne $expectedSubject) {
    throw "Unexpected certificate subject '$($certificate.Subject)'. Refusing to install it."
}

$existingCertificate = Get-ChildItem Cert:\CurrentUser\Root |
    Where-Object { $_.Thumbprint -eq $certificate.Thumbprint } |
    Select-Object -First 1

if ($existingCertificate) {
    Write-Host "Multipass Root CA is already trusted for the current user."
    Write-Host "Thumbprint: $($certificate.Thumbprint)"
}
else {
    Write-Host "Certificate: $($certificate.Subject)"
    Write-Host "Thumbprint:  $($certificate.Thumbprint)"
    Write-Host "Expires:     $($certificate.NotAfter)"
    Write-Host "Store:       CurrentUser\Root"
    $confirmation = Read-Host "Trust this Root CA on this Windows user account? Type YES"

    if ($confirmation -cne "YES") {
        Write-Host "Cancelled. No certificate was installed."
        exit 1
    }

    Write-Host "Windows may display its own Root CA trust warning; review and accept it to continue."
    Import-Certificate `
        -FilePath $certificatePath `
        -CertStoreLocation "Cert:\CurrentUser\Root" `
        -Confirm:$false | Out-Null

    $installedCertificate = Get-ChildItem Cert:\CurrentUser\Root |
        Where-Object { $_.Thumbprint -eq $certificate.Thumbprint } |
        Select-Object -First 1

    if (-not $installedCertificate) {
        throw "Certificate import completed without finding the certificate in CurrentUser\Root."
    }

    Write-Host "Multipass Root CA is now trusted for the current user."
}

# Root CAs left behind by earlier cluster builds (same subject, different key)
$staleCertificates = @(Get-ChildItem Cert:\CurrentUser\Root |
    Where-Object { $_.Subject -eq $expectedSubject -and $_.Thumbprint -ne $certificate.Thumbprint })

if ($staleCertificates.Count -eq 0) {
    exit 0
}

Write-Host ""
Write-Host "Found $($staleCertificates.Count) stale '$expectedSubject' certificate(s) from earlier builds:"
$staleCertificates | ForEach-Object { Write-Host "  $($_.Thumbprint)  expires $($_.NotAfter)" }
$confirmation = Read-Host "Remove them from CurrentUser\Root? Type YES"

if ($confirmation -cne "YES") {
    Write-Host "Stale certificates were left in place."
    exit 0
}

Write-Host "Windows may ask to confirm each removal from the Root store."
$staleCertificates | ForEach-Object { Remove-Item -LiteralPath $_.PSPath }
Write-Host "Removed $($staleCertificates.Count) stale certificate(s)."
