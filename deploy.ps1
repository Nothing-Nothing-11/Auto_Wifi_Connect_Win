#Requires -Version 5.1
# 一键部署（Windows 任务计划程序）
$ErrorActionPreference = 'Stop'

$BASE          = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ENV_FILE      = Join-Path $BASE '.env'
$VBS_SCRIPT   = Join-Path $BASE 'run-hidden.vbs'
$TASK_NAME     = 'AutoWiFiPortalLogin'
$INTERVAL_MIN  = 2   # 巡检间隔（分钟）

function Write-Log { param([string]$Msg); Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Msg" }

# 1) 环境检查
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeCmd) {
    Write-Host '需要先安装 Node.js (>=18)。请从 https://nodejs.org 下载安装。'
    exit 1
}
$npmCmd = Get-Command npm -ErrorAction SilentlyContinue
if (-not $npmCmd) {
    Write-Host '未找到 npm，通常随 Node.js 一起安装。请从 https://nodejs.org 下载安装。'
    exit 1
}

# 2) 确保依赖
$nodeModules = Join-Path $BASE 'node_modules'
if (-not (Test-Path $nodeModules)) {
    Write-Log '安装依赖...'
    Set-Location $BASE
    & npm install
    if ($LASTEXITCODE -ne 0) { Write-Host 'npm install 失败'; exit 1 }
}

# 2.1) Playwright 已改用系统 Edge 浏览器，无需安装 Chromium

# 3) 确保 .env 存在
if (-not (Test-Path $ENV_FILE)) {
    $envExample = Join-Path $BASE '.env.example'
    if (Test-Path $envExample) {
        Copy-Item $envExample $ENV_FILE
        Write-Host "已生成 .env，请填写账号/密码/门户地址后再运行 deploy.ps1"
        Write-Host "路径：$ENV_FILE"
        exit 1
    } else {
        Write-Host '.env 不存在且缺少 .env.example，请手动创建'
        exit 1
    }
}

# 4) 读取 .env，校验必填
$envContent = Get-Content $ENV_FILE -Encoding UTF8
$portalAccount  = ($envContent | Where-Object { $_ -match '^\s*PORTAL_ACCOUNT\s*=\s*(.+)' } | ForEach-Object { $matches[1] -replace "^['""]|['""]$", '' }) | Select-Object -First 1
$portalPassword = ($envContent | Where-Object { $_ -match '^\s*PORTAL_PASSWORD\s*=\s*(.+)' } | ForEach-Object { $matches[1] -replace "^['""]|['""]$", '' }) | Select-Object -First 1

if ([string]::IsNullOrWhiteSpace($portalAccount) -or [string]::IsNullOrWhiteSpace($portalPassword)) {
    Write-Host "请在 .env 中填写 PORTAL_ACCOUNT / PORTAL_PASSWORD"
    Write-Host "路径：$ENV_FILE"
    exit 1
}

# 5) 移除旧任务（如果存在）
$existing = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
if ($existing) {
    Write-Log "移除旧计划任务：$TASK_NAME"
    Unregister-ScheduledTask -TaskName $TASK_NAME -Confirm:$false
}

# 6) 创建计划任务
#    触发器 A：用户登录时触发
#    触发器 B：一次性任务 + 每 N 分钟重复，持续 3650 天
#    注：-AtLogOn 触发器在某些 PowerShell 版本上不支持直接设置 Repetition；
#        -Daily 与 -RepetitionInterval 在部分版本存在参数集冲突，
#        因此使用 -Once + Repetition 实现周期巡检，兼容 PowerShell 5.1。
$trigger1 = New-ScheduledTaskTrigger -AtLogOn

$startTime = (Get-Date).AddMinutes(-$INTERVAL_MIN)
$trigger2 = New-ScheduledTaskTrigger `
    -Once `
    -At $startTime `
    -RepetitionInterval (New-TimeSpan -Minutes $INTERVAL_MIN) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$action = New-ScheduledTaskAction `
    -Execute 'wscript.exe' `
    -Argument "`"$VBS_SCRIPT`"" `
    -WorkingDirectory $BASE

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit ([TimeSpan]::FromMinutes(5))

Register-ScheduledTask `
    -TaskName $TASK_NAME `
    -Trigger @($trigger1, $trigger2) `
    -Action $action `
    -Settings $settings `
    -Description 'Auto WiFi Portal Login - 自动连接公司/校园网关' `
    | Out-Null

Write-Log "计划任务已注册：$TASK_NAME"
Write-Log "  触发器：用户登录 + 每 ${INTERVAL_MIN} 分钟重复"
Write-Log "  操作：wscript.exe run-hidden.vbs"
Write-Log "  工作目录：$BASE"
Write-Log "部署完成！"
Write-Log "查看日志：Get-Content '$(Join-Path $BASE 'portal-login.log')' -Tail 50"

# 7) 立即触发一次
Start-ScheduledTask -TaskName $TASK_NAME
Write-Log "已立即触发一次执行"
