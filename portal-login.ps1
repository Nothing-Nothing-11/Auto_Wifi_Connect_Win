#Requires -Version 5.1
# auto_wifi/portal-login.ps1 —— Windows 版联网探测 + 调度 Playwright 登录
$ErrorActionPreference = 'Stop'

$PROJ = Split-Path -Parent $MyInvocation.MyCommand.Definition

$NODE_SCRIPT = Join-Path $PROJ 'portal-login.mjs'
$LOG         = Join-Path $PROJ 'portal-login.log'

# ── 轻量日志函数 ──────────────────────────────────────────────────────────────
function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "$ts $Message" | Add-Content -LiteralPath $LOG -Encoding UTF8
}

# DEBUG 环境变量可打开详细输出
if ($env:DEBUG -eq '1') {
    $VerbosePreference = 'Continue'
}

# ── 在线探针：任一成功即视为已联网 ────────────────────────────────────────────
function Test-Online {
    $probes = @(
        @{ Url = 'http://neverssl.com/';                                    Type = 'status'; Pattern = '^(200|301|302)$' },
        @{ Url = 'http://www.msftconnecttest.com/connecttest.txt';         Type = 'body';   Pattern = 'Microsoft Connect Test' },
        @{ Url = 'http://captive.apple.com/hotspot-detect.html';            Type = 'body';   Pattern = 'Success' },
        @{ Url = 'https://www.qq.com';                                      Type = 'status'; Pattern = '^(200|301|302)$' },
        @{ Url = 'https://www.baidu.com';                                   Type = 'status'; Pattern = '^(200|301|302)$' }
    )
    foreach ($p in $probes) {
        try {
            $resp = Invoke-WebRequest -Uri $p.Url -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            if ($p.Type -eq 'status') {
                if ($resp.StatusCode -match $p.Pattern) { return $true }
            } else {
                if ($resp.Content -match $p.Pattern) { return $true }
            }
        } catch {
            # 忽略，换下一个探针
        }
    }
    return $false
}

# ── 门户探测（5 秒）───────────────────────────────────────────────────────────
function Test-Portal {
    try {
        $resp = Invoke-WebRequest -Uri 'http://114.114.114.114:90/' -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        return ($resp.StatusCode -match '^(200|301|302|303|307)$')
    } catch {
        return $false
    }
}

# ── 主流程 ────────────────────────────────────────────────────────────────────
if (Test-Online) {
    # 已联网，静默退出
    exit 0
}

if (Test-Portal) {
    Write-Log 'start login'
    try {
        $nodeOutput = & node $NODE_SCRIPT 2>&1
        $nodeOutput | ForEach-Object { Add-Content -LiteralPath $LOG -Value $_ -Encoding UTF8 }
    } catch {
        Write-Log "node error: $_"
    }
    Start-Sleep -Seconds 2
    if (Test-Online) {
        Write-Log 'login ok'
        exit 0
    } else {
        Write-Log 'login fail'
        exit 2
    }
}

# 无门户（可能 Wi-Fi 未连）→ 静默退出
exit 0
