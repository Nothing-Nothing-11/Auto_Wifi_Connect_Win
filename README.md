# Auto_Wifi_Connect_Win

Windows 平台 WiFi 门户自动登录工具。连接需要网页认证的校园/企业 WiFi 后，自动检测并登录门户，无需手动打开浏览器。

## 原理

1. **联网检测** — 多探针（neverssl.com / MSFT Connect Test / Apple Captive / 百度 / QQ）任一可达即判定已联网
2. **门户探测** — 尝试访问候选门户地址，检测是否被重定向到认证页
3. **自动登录** — 使用 Playwright 驱动系统 Edge 浏览器（headless 模式），自动填写账号密码并提交
4. **结果校验** — 登录成功后再次联网检测确认

## 运行方式

- **计划任务**（推荐）：`deploy.ps1` 注册 Windows 计划任务，开机自动运行 + 每 2 分钟巡检，完全无窗口
- **手动运行**：`powershell -File portal-login.ps1` 或直接 `node portal-login.mjs`

## 快速开始

### 1. 安装依赖

需要 [Node.js](https://nodejs.org/)（v18+）和系统已安装的 Microsoft Edge 浏览器。

```powershell
cd Auto_Wifi_Connect_Win
npm install
```

### 2. 配置

复制 `.env.example` 为 `.env`，填入你的信息：

```powershell
Copy-Item .env.example .env
notepad .env
```

```ini
# 账号与密码（必填）
PORTAL_ACCOUNT=your_account
PORTAL_PASSWORD=your_password

# 门户登录地址（逗号分隔，可写多个候选）
PORTAL_LOGIN_CANDIDATES=http://your-portal-address/login,http://backup-portal
```

> 门户地址获取方法：连接 WiFi 后用浏览器打开任意网页，被重定向到的认证页面 URL 即为门户地址。

### 3. 测试

```powershell
node portal-login.mjs
```

成功输出：`portal login OK / internet reachable.`

### 4. 部署（可选）

以管理员权限运行 PowerShell：

```powershell
.\deploy.ps1
```

卸载：

```powershell
.\undeploy.ps1
```

## 文件说明

| 文件 | 用途 |
|---|---|
| `portal-login.mjs` | Playwright 登录核心脚本 |
| `portal-login.ps1` | PowerShell 入口（联网/门户探测 + 调度 Node.js） |
| `deploy.ps1` | 注册 Windows 计划任务 |
| `undeploy.ps1` | 移除计划任务 |
| `run-hidden.vbs` | VBScript 包装器，实现无窗口执行 |
| `.env` | 个人配置（不提交到 Git） |
