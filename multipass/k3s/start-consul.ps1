[CmdletBinding()]
param(
    [string]$DataDir = (Join-Path $env:USERPROFILE ".consul\data")
)

# Starts a local single-node Consul server (Terraform state + topsecret/ KV) bound to 127.0.0.1:8500.
$ErrorActionPreference = "Stop"

if (Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort 8500 -State Listen -ErrorAction SilentlyContinue) {
    Write-Host "Consul is already listening on 127.0.0.1:8500."
    exit 0
}

$consul = (Get-Command consul -ErrorAction Stop).Source
$baseDir = Split-Path $DataDir -Parent
$logFile = Join-Path $baseDir "consul.log"
$configFile = Join-Path $baseDir "consul.hcl"
New-Item -ItemType Directory -Force -Path $DataDir | Out-Null

# The default raft WAL log store needs directory fsync, which Windows denies; use BoltDB instead
Set-Content -LiteralPath $configFile -Encoding ASCII -Value 'raft_logstore { backend = "boltdb" }'

Start-Process -FilePath $consul -WindowStyle Hidden -ArgumentList @(
    "agent", "-server", "-bootstrap-expect=1", "-ui",
    "-bind=127.0.0.1", "-client=127.0.0.1",
    "-data-dir=`"$DataDir`"", "-log-file=`"$logFile`"",
    "-config-file=`"$configFile`""
)

for ($i = 0; $i -lt 30; $i++) {
    try {
        $leader = Invoke-RestMethod -Uri "http://127.0.0.1:8500/v1/status/leader" -TimeoutSec 2
        if ($leader) {
            Write-Host "Consul server leader: $leader (data: $DataDir)"
            exit 0
        }
    }
    catch { }
    Start-Sleep -Seconds 1
}

throw "Consul did not elect a leader within 30 seconds; see $logFile"
