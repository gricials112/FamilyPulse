# 微信第三方登录 — 开发者平台配置指南

## 前提

需要在 [微信开放平台](https://open.weixin.qq.com) 注册开发者账号并通过实名认证（企业或个人均可，个人账号部分能力受限）。

---

## 1. 创建移动应用

登录微信开放平台 → **管理中心** → **创建移动应用** → **iOS 应用**

需要填写以下信息：

| 字段 | 说明 | 配置位置 |
|------|------|----------|
| **应用名称** | 用户授权时看到的应用名，如"家安" | 微信开放平台 → 创建应用 |
| **应用简介** | 应用简短描述 | 同上 |
| **iOS Bundle ID** | `com.lwj.FamilyPulse` | Xcode → Target → General → Bundle Identifier |
| **iOS 通用链接（Universal Link）** | 如 `https://jiaan.online/wechat/` | 微信开放平台 + Apple Developer + Xcode |

### 提交审核

创建后需提交审核。审核通过后会获得：

- **AppID** — 用于客户端注册和 URL Scheme
- **AppSecret** — 用于服务器端，**请勿存入客户端代码**

---

## 2. 需要记录的关键信息

提交应用审核通过后，记录以下信息并填入代码：

| 信息 | 用途 | 填入代码位置 |
|------|------|-------------|
| **AppID**（格式: `wx1234567890abcdef`） | 客户端注册、URL Scheme | `ios/FamilyPulse/Services/AppConfiguration.swift` → `wechatAppID` |
| **Universal Link** | 授权回调跳转 | `ios/FamilyPulse/Services/AppConfiguration.swift` → `wechatUniversalLink` |
| **AppSecret** | 服务器用 code 换 access_token | 后端环境变量 |

---

## 3. 代码中各配置项详解

### 3.1 AppConfiguration

```swift
// ios/FamilyPulse/Services/AppConfiguration.swift

/// 微信开放平台申请的 AppID
static let wechatAppID = "wxYOUR_APP_ID_HERE"        // ← 替换为实际值

/// Universal Link（需与微信开放平台填写的一致）
static let wechatUniversalLink = "https://jiaan.online/wechat/"  // ← 替换为实际值
```

### 3.2 Info.plist

文件：`ios/FamilyPulse/Info.plist`

```xml
<!-- URL Scheme — 格式为 wx + AppID -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.lwj.FamilyPulse</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>wxYOUR_APP_ID_HERE</string>   <!-- ← 替换为 wx + AppID -->
        </array>
    </dict>
</array>

<!-- 声明可以拉起的第三方 App -->
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>weixin</string>
    <string>weixinULAPI</string>
    <string>weixinURLParamsAPI</string>
</array>
```

> 本项目使用 `GENERATE_INFOPLIST_FILE = YES` + 补充 `Info.plist` 的方式，以上内容已写在补充 plist 中。如果你改用完整 `Info.plist`，需将以上内容和 Xcode 自动生成的内容合并。

### 3.3 Xcode Build Settings

项目使用了 `GENERATE_INFOPLIST_FILE = YES`，同时在 `pbxproj` 中设置了 `INFOPLIST_FILE = "FamilyPulse/Info.plist"`。Xcode 会自动合并生成的 plist 和补充 plist。

如需后续修改，可在 Xcode 中：**Target → FamilyPulse → Build Settings → Info.plist File** 查看或修改。

### 3.4 Associated Domain（Universal Link）

微信授权回调依赖 Universal Link。需要在 Xcode 中配置 Associated Domain：

**Xcode → FamilyPulse Target → Signing & Capabilities → + → Associated Domains**

添加：

```
applinks:jiaan.online
```

然后在服务器根目录的 `apple-app-site-association` 文件中包含该路径（微信要求）和通配：

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TXB93638P7.com.lwj.FamilyPulse",
        "paths": ["/wechat/*"]
      }
    ]
  }
}
```

> ⚠️ **注意**：微信开放平台配置 Universal Link 时，需要填写**完整的、可访问的 URL**。申请后微信会验证，验证通过才能收到回调。

---

## 4. 微信开放平台配置总结

| 步骤 | 操作 | 状态 |
|------|------|------|
| 1 | 注册微信开放平台账号 | |
| 2 | 创建 iOS 应用，填写 Bundle ID（`com.lwj.FamilyPulse`） | |
| 3 | 填写 Universal Link（如 `https://jiaan.online/wechat/`） | |
| 4 | 提交应用审核 | |
| 5 | 审核通过后获取 AppID 和 AppSecret | |
| 6 | AppID 填入 `AppConfiguration.swift` | |
| 7 | AppSecret 配置到后端环境变量 | |
| 8 | 配置服务器 AASA 文件支持 Universal Link | |
| 9 | 在 Xcode 中开启 Associated Domains capability | |

---

## 5. 后端需要提供的 API

微信登录流程中，客户端拿到 `code` 后传给后端，后端用 `code` + `AppSecret` 向微信服务器换取 `access_token` 和 `openid`。

本项目后端已提供 `/api/auth/wechat` 端点，接受参数：

| 参数 | 类型 | 说明 |
|------|------|------|
| `code` | String | 客户端从微信 SDK 获取的临时授权码 |
| `openId` | String? | 可选，服务端未传 code 时可传 openId 直接登录 |
| `unionId` | String? | 同上 |
| `nickname` | String? | 可选，用户昵称 |
| `avatarUrl` | String? | 可选，用户头像 URL |

后端处理完后，与普通登录一样返回 `token` + `user`。

---

## 6. 常见问题

### 开发调试（无审核通过的 AppID）

- 使用微信官方测试号（需微信开放平台测试权限）
- 使用已经审核通过的其他应用的 AppID 临时测试（需配置 Universal Link）
- 或者先在 `WeChatService.sendAuthRequest()` 前加 `isWXAppInstalled` 判断，不装微信时 fallback 到其他登录方式

### Xcode 16 编译 WechatOpenSDK 常见问题

- 如果遇到 `Multiple commands produce` 错误，检查 Build Phases 中是否有多余的脚本
- 确保 `Build Settings → EXCLUDED_ARCHS` 为空
- 如果报 `Invalid WATCH_APPLICATION_IDE` 相关错误，更新 CocoaPods 到最新版

### 真机调试

- WeChat SDK 在模拟器上无法拉起微信（微信不在模拟器中），请使用真机调试
- 真机需安装微信 App
- 需使用有效的 Apple Developer 签名
