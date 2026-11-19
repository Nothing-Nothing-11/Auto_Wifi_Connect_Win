' run-hidden.vbs —— 无窗口后台运行 portal-login.ps1
Set WshShell = CreateObject("WScript.Shell")

Dim scriptDir
scriptDir = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\") - 1)

Dim quote
quote = Chr(34)   ' 一个双引号字符

Dim cmd
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File " & quote & scriptDir & "\portal-login.ps1" & quote

WshShell.Run cmd, 0, False
Set WshShell = Nothing
