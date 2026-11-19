#Requires -Version 5.1
# 一键卸载（Windows 任务计划程序）
$ErrorActionPreference = 'Stop'

$TASK_NAME = 'AutoWiFiPortalLogin'

$existing = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
if ($existing) {
    # 先停止正在运行的任务
    if ($existing.State -eq 'Running') {
        Stop-ScheduledTask -TaskName $TASK_NAME
        Write-Host "已停止任务：$TASK_NAME"
    }
    Unregister-ScheduledTask -TaskName $TASK_NAME -Confirm:$false
    Write-Host "已移除计划任务：$TASK_NAME"
} else {
    Write-Host "计划任务不存在：$TASK_NAME，无需卸载"
}
