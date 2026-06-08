# FamilyPulse / 家安

《家安》是轻度家庭照护同步工具, 包含 Go 服务端和 SwiftUI iOS App。

> **已部署:** `http://39.104.72.10:8081` `https://jiaan.online`

## 本地运行

### 服务端

```bash
cd /Users/keria/Documents/Xcode/FamilyPulse/backend
docker compose up --build
# 或只运行 Go 进程:
# DB_PASSWORD=familypulse_dev docker compose up -d postgres
# go run ./cmd/familypulse
```

- 默认地址: `http://127.0.0.1:8081`
- 健康检查: `GET /api/health`
- 数据库: PostgreSQL。服务端不再依赖 Redis/MinIO 缓存或对象存储。
- 本地 Compose: `/Users/keria/Documents/Xcode/FamilyPulse/backend/docker-compose.yml`

### iOS

打开:

```bash
open /Users/keria/Documents/Xcode/FamilyPulse/ios/FamilyPulse.xcodeproj
```

默认连接本地后端的位置:

`/Users/keria/Documents/Xcode/FamilyPulse/ios/FamilyPulse/Services/AppConfiguration.swift`

后期换服务器 IP 时只改这里的 `apiBaseURL`。

## 测试账号

默认启动服务端会种子化以下账号:

| 账号 | 密码 | 角色 | 姓名 |
| --- | --- | --- | --- |
| `family-admin` | `FamilyPulse@123` | 管理员 | 林子晨 |
| `family-sister` | `FamilyPulse@123` | 照护成员 | 林子悦 |
| `elder-mom` | `FamilyPulse@123` | 老人 | 张素琴 |
| `elder-dad` | `FamilyPulse@123` | 老人 | 林建国 |

默认家庭邀请码: `FAMILY26`, 内置“妈妈”和“爸爸”两位老人。

## 微信登录示例

登录页已取消账号直接注册，新增用户默认通过“微信登录”进入。当前未接入真实微信 SDK，App 会按所选身份发送示例资料:

| 身份 | code | openId | 昵称 |
| --- | --- | --- | --- |
| 我是家人 | `wx_mock_family` | `wx_mock_openid_family_admin` | 微信家人林子晨 |
| 我是老人 | `wx_mock_elder` | `wx_mock_openid_elder_mom` | 微信老人张素琴 |

服务端接口: `POST /api/auth/wechat`。示例用户会自动加入默认家庭，便于本地演示。

## 订阅历史限制

- 免费版: 操作历史只显示最近 10 条，不支持按日期回看。
- 月付: `¥6/月`，同步延迟 30 秒以内，支持断网补发，可按日期查看最近 7 天操作历史，每天最多显示 10 条。
- 年付: `¥58/年`，同步延迟 10 秒以内，支持断网补发，可按日期查看全部操作历史，每天最多显示 10 条。
- 病历上传、附件上传和 OCR 病历夹已因隐私原因移除；服务端相关接口返回 410。

## 已验证

- 服务端: `cd /Users/keria/Documents/Xcode/FamilyPulse/backend && make coverage` 通过，总语句覆盖率要求 >= 90%。
- iOS: Xcode Debug Simulator test 通过。
- 模拟器端到端: 已用本地后端登录测试账号, 验证家人端同步墙、照护动作、复查登记、复查完成留言、老人端选择本人和一键大按钮。

## Apple 登录配置

iOS 已接入 `AuthenticationServices` 和 Sign in with Apple entitlement。服务端通过 Apple JWK 校验 identity token:

```properties
familypulse.apple.client-id=com.lwj.FamilyPulse
```

正式发布前需要在 Apple Developer 后台为 bundle id `com.lwj.FamilyPulse` 开启 Sign in with Apple。

## 截图

- `/Users/keria/Documents/Xcode/FamilyPulse/docs/screenshots/01-login.jpg`
- `/Users/keria/Documents/Xcode/FamilyPulse/docs/screenshots/02-family-wall-feed.jpg`
- `/Users/keria/Documents/Xcode/FamilyPulse/docs/screenshots/03-appointment-done.jpg`
- `/Users/keria/Documents/Xcode/FamilyPulse/docs/screenshots/04-elder-mode.jpg`
