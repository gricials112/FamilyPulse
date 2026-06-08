# App Review Fix — Guideline 3.1.2(c)

> Business - Payments - Subscriptions — Missing Terms of Use (EULA) & Privacy Policy

---

## 1. 审核问题说明

Apple App Review 拒绝理由：

> The submission did not include all the required information for apps offering auto-renewable subscriptions.
> The following information needs to be included within the app: a functional link to the Terms of Use (EULA) and a functional link to the privacy policy.
> The following information needs to be included in the App Store metadata: a functional link to the Terms of Use (EULA).

**合规要求：**
- App 内所有订阅购买流程必须显示可点击的 Terms of Use (EULA) 链接
- App 内必须显示可点击的 Privacy Policy 链接
- App Store Connect 元数据必须包含 Terms of Use (EULA) 链接

---

## 2. 本次代码修改位置

### 新增文件

| 文件 | 说明 |
|------|------|
| `ios/FamilyPulse/Shared/PaywallLegalLinks.swift` | 可复用的法律链接组件，包含中文版、英文版、自动本地化版、SafariViewController 版 |

### 修改文件

| 文件 | 修改内容 |
|------|---------|
| `ios/FamilyPulse/Features/ElderOneTapHomeView.swift` | 在 `SubscriptionPromotionView` 的 planCards 和 restoreButton 之间插入了 `PaywallLegalLinksAuto()` |
| `ios/FamilyPulse/Features/SettingsView.swift` | 在 `subscriptionFooter` 中 Auto-renewal 文字下方插入了 `PaywallLegalLinksAuto()` |

### 未修改的部分

- ❌ Bundle ID、Team、Signing、Capabilities、App Group → 未修改
- ❌ 推送、蓝牙、已有内购商品 ID → 未修改
- ❌ 现有 UI 风格 → 未破坏
- ❌ StoreKit 商品 ID（`com.lwj.FamilyPulse.premium.monthly.v2` / `com.lwj.FamilyPulse.premium.yearly.v2`）→ 未修改
- ❌ Restore Purchase / 恢复购买按钮 → 未删除

---

## 3. App 内可看到 Terms / Privacy 链接的位置

### 位置 1: 订阅推广页（SubscriptionPromotionView）

- **触发方式**：在 Push 通知卡片点击「订阅后开启 Push 通知」或在家庭墙点击受限功能
- **具体位置**：planCards（月付/年付卡片）下方，恢复购买按钮上方
- **内容**：「使用条款（EULA） · 隐私政策」

### 位置 2: 设置页 Premium 卡片背面

- **触发方式**：设置 → Premium 卡片 → 翻转查看权益
- **具体位置**：订阅方案卡片下方，「自动续费，随时可在 App Store 取消。」文字下方
- **内容**：「使用条款（EULA） · 隐私政策」

### 满足的合规要求

- ✅ 两个链接在购买按钮附近可见
- ✅ 使用 SwiftUI `Link`，点击后通过系统 Safari 打开（真实可点击链接）
- ✅ 不需登录即可看到（Settings 页不需要登录）
- ✅ 不藏在设置页深处（就在订阅卡片内）
- ✅ 支持中英文自动本地化

---

## 4. App Store Connect 需要修改的字段

### App Store Description（App 描述）

在 App Store 描述末尾添加以下内容：

```
Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://jiaan.online/privacy.html
```

### Privacy Policy URL（隐私政策链接）

在 App Store Connect → App → App Information → Privacy Policy URL 中填写：

```
https://jiaan.online/privacy.html
```

### Terms of Use (EULA) URL（使用条款链接）

在 App Store Connect → App → App Information → Terms of Use (EULA) URL 中填写：

```
https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```

### App Review Contact Information（审核联系信息）

确保以下信息正确：
- 联系人姓名
- 联系电话
- 联系邮箱
- 备注（选填）

---

## 5. App Review 回复模板

```
Hello App Review Team,

We have updated the app and App Store metadata to include the required subscription information.

Within the app, the Terms of Use (EULA) and Privacy Policy links are now available on the subscription purchase screen before the user subscribes.

Terms of Use (EULA):
https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

Privacy Policy:
https://jiaan.online/privacy.html

We have also added the Terms of Use link to the App Store description and updated the Privacy Policy URL in App Store Connect.

Thank you.
```

---

## 6. 自检清单

| 检查项 | 状态 |
|--------|------|
| 1. 项目可以正常 build | ✅ |
| 2. 所有订阅入口都能看到 Terms / Privacy | ✅ (SettingsView + SubscriptionPromotionView) |
| 3. 两个链接都能正常打开 | ✅ (SwiftUI Link → Safari) |
| 4. 小屏 iPhone 下不会被遮挡 | ✅ (footnote + caption2 字号) |
| 5. 深色模式下文字可读 | ✅ (使用 `.secondary` / `.tertiary` 语义色) |
| 6. 不影响现有订阅购买逻辑 | ✅ (仅添加文字链接，不修改购买流程) |
| 7. 不改动 StoreKit 商品 ID | ✅ |
| 8. 不改动已有价格展示逻辑 | ✅ |
| 9. 不删除 Restore Purchase 入口 | ✅ |

---

## 7. 上线 Checklist

- [ ] 在 App Store Connect 更新 App 描述，添加 Terms / Privacy 链接
- [ ] 在 App Store Connect → App Information 填写 Privacy Policy URL
- [ ] 在 App Store Connect → App Information 填写 Terms of Use (EULA) URL
- [ ] 重新上传 build（版本号建议 +1 以避免同版本被拒）
- [ ] 使用上面第 5 节的回复模板回复 App Review
