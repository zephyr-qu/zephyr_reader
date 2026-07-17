---
id: M1
phase: Q2
slug: wifi-transfer-server-code
severity: medium
original_id: q2-001
---

# WiFi 传书 HTTP 服务器 — 已禁用但含完整未认证文件上传实现

## 文件

`lib/core/network/wifi_transfer_service.dart`

## 描述

`WifiTransferService` 实现了一个完整的 HTTP 文件上传服务器，绑定到 `InternetAddress.loopbackIPv4`（127.0.0.1）。该服务器：

- 处理 `GET /`（提供 Web 界面）
- 处理 `POST /upload`（multipart 文件上传）
- 处理 `GET /api/status`（状态查询）

目前服务器在 `start()` 方法中被 `// ponytail: wifi 传书暂屏蔽` 注释禁用——方法体为空。但如果未来开发者移除该注释，服务器将暴露给所有本地进程。

## 安全问题

1. **无认证/授权**：上传和状态 API 没有任何认证机制。任何能够连接到 localhost 端口的进程都可以上传文件。
2. **无 CSRF 防护**：上传端点没有 CSRF token 或 Origin 检查。
3. **仅基于扩展名的文件类型验证**：只检查扩展名是否为 `txt` 或 `epub`，不验证文件内容。
4. **无大小限制**：上传的文件大小没有限制，可能导致拒绝服务攻击。

## 风险场景

如果启用（移除 `ponytail` 屏蔽注释），同一设备上的恶意应用可以：
- 通过 `POST /upload` 上传任意 `.txt` 或 `.epub` 文件
- 上传大量数据耗尽存储空间
- 提交恶意制作的内容（从其他渠道读回时可能触发漏洞）

## 缓解措施

- 保持禁用状态
- 如果将来启用，需添加：
  - 认证机制（token 验证）
  - 文件大小限制
  - 内容类型验证（不止扩展名）
  - CSRF 防护

PoC-Status: theoretical
Protocol: http
Auth-Required: no
Auth-Roles-Required: anonymous
