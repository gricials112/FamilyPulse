# FamilyPulse / 家安 设计方案

版本: 0.3  
日期: 2026-05-31  
目标平台: iOS 18+ 运行, iOS 26+ 启用 Liquid Glass 增强; 服务端 Spring Boot 3.5.x

## 1. 产品定位

《家安 (FamilyPulse)》是给“三明治一代”家庭使用的异步家庭健康同步墙。它不做诊断、不做治疗建议, 只解决三个低风险高频问题:

1. 老人是否完成当天关键照护动作: 早药、晚药、血压、血糖、饮水等。
2. 家庭成员是否能按日期回看照护操作历史, 并区分免费、月付、年付能力。
3. 复查、取药、陪诊等家庭任务是否有清晰分工和时间提醒。

核心原则:

- 老人端极简: 一个屏幕只出现 1-3 个大按钮, 点击后即时反馈。
- 子女端清晰: 用时间线和卡片显示“今天是否安心”, 减少微信群追问。
- 异步同步: 照护事件上传到服务端, 家庭成员拉取最新状态。
- 隐私优先: 不采集病历、处方、化验单、影像等敏感健康资料。
- 避开医疗诊断: 文案只写“记录/提醒/同步”, 不写“正常/异常/建议用药”。

## 2. iOS 26 视觉与交互方向

设计参考 iOS 26 Liquid Glass 风格, 但必须兼容较早系统:

- iOS 26+: 使用 `GlassEffectContainer`, `.glassEffect(...)`, `.buttonStyle(.glass/.glassProminent)` 形成轻透、安全、家庭感的同步墙。
- iOS 18-25: 使用 `.ultraThinMaterial`, 圆角卡片和渐变背景作为 fallback。
- 色彩: 温暖低饱和绿色/蓝色为主, 红色仅用于未完成或过期任务, 避免制造焦虑。
- 动效: 完成动作时使用按钮轻微缩放、打勾、墙面新增事件卡片; 不使用夸张庆祝动画。
- 字号: 老人模式默认大字号, 关键按钮可触区域不小于 72pt 高。
- 可访问性: 支持 Dynamic Type、VoiceOver 标签、Reduce Motion。

主要界面:

1. 老人今日页
   - 顶部: “今天 5月30日, 已完成 2/3”
   - 中部: 大按钮矩阵: “已吃早药”、“已测血压”、“已吃晚药”
   - 底部: 子女留言/下次复查简短提示
   - 点击动作: 乐观更新 -> 本地事件入队 -> 上传成功后显示“已同步给家人”

2. 家庭同步墙
   - 今日摘要: 每位老人一个安心卡
   - 时间线: “妈妈 08:12 已吃早药”、“哥哥 预约 6月5日复查”
   - 操作历史: 免费最近 10 条; 月付最近 7 天按日查看; 年付全部历史按日查看

3. 隐私与订阅
   - 病历上传、附件上传、OCR 病历夹全部移除
   - 月付 `¥6/月`: 30 秒内同步、断网补发、最近 7 天历史、自定义操作 3 个/老人
   - 年付 `¥58/年`: 10 秒内同步、断网补发、全部历史、自定义操作 20 个/老人

4. 复查看板
   - 按日期卡片展示
   - 字段: 复查对象、医院、科室、携带资料、负责家庭成员、状态
   - 支持“我来带”“改期”“完成复查”

5. 家庭管理
   - 创建家庭、邀请码加入
   - 成员角色: elder, caregiver, admin
   - 每个家庭可管理多个老人

## 3. 关键交互细节

### 3.1 一键大按钮

用例:

- 老人点击“已吃早药”
- App 立即把按钮变为完成态, 时间显示为当前本地时间
- 服务端按 `actionKey + elderId + localDate` 做幂等, 防止重复点多次产生多条完成记录
- 若订阅用户离线, 本地显示“待同步”, 恢复网络后自动补发; 免费用户不支持离线补发
- 完成后 10 秒内允许“撤销”, 撤销也作为一个事件同步

边界:

- 当天已完成再点击: 展示完成详情, 不重复创建
- 误点: 提供撤销
- 多设备同时点: 服务端保留最新有效状态和事件审计

### 3.2 操作历史与订阅

用例:

- 子女在同步墙查看最近操作历史
- 免费用户只看到最近 10 条
- 月付用户选择最近 7 天内某天, 查看当天最多 10 条记录
- 年付用户选择任意日期, 查看当天最多 10 条记录
- App 根据订阅展示同步延迟、断网补发、自定义照护操作上限

边界:

- 未订阅用户传入日期查询历史返回 402
- 月付用户查询 7 天前历史返回 402
- 年付用户可查询全部历史, 但单日最多显示 10 条

### 3.3 异步复查备忘

用例:

- 家庭成员创建复查
- 选择老人、日期、医院/科室、需要携带的药和资料
- 指派自己或其他成员
- 其他家庭成员能在同步墙看到

边界:

- 改期保留历史
- 过期未完成显示为“待确认”
- 负责人离开家庭时, 任务变为未指派

### 3.4 Widget / App Intent

首版系统入口只暴露最高价值动作:

- `LogCareActionIntent`: 从小组件/快捷指令直接记录“已吃早药/已测血压”
- `OpenFamilyWallIntent`: 打开家庭同步墙
- `CareActionEntity`: 提供老人和动作的轻量实体

Widget 数据来自 App Group 本地快照。联网同步由主 App 服务层处理; Widget 触发 intent 后写入共享队列, 主 App 激活后刷新。

## 4. 服务端架构

技术选型:

- Java 17
- Spring Boot 3.5.14
- Maven
- Spring Web MVC
- Spring Data JPA
- H2 开发/测试库, 后续可换 PostgreSQL
- Bean Validation

模块:

- `family`: 家庭、成员、邀请码
- `elder`: 被照护老人档案
- `action`: 照护动作定义、每日事件、撤销
- `subscription`: 月付/年付权益、历史范围、离线补发策略
- `appointment`: 复查任务
- `activity`: 同步墙聚合查询

首版认证策略:

- App 提供“登录”和“注册”两个入口, 账号密码认证返回 Bearer token。
- Apple 登录使用 iOS `AuthenticationServices` 获取 identity token, 服务端通过 Apple JWK 校验 issuer/audience 后创建或登录用户。
- 登录后 App 在会话内保存当前用户和 token, 后续资源接口使用 `Authorization: Bearer ...`; 未登录请求返回 401。
- 加入家庭必须有邀请码。
- 所有家庭资源查询都校验用户是否属于该家庭。
- 后续替换为 Sign in with Apple / OAuth2 时 API 资源模型不变。

本地测试账号:

- `family-admin` / `FamilyPulse@123`: 管理员, 林子晨
- `family-sister` / `FamilyPulse@123`: 照护成员, 林子悦
- `elder-mom` / `FamilyPulse@123`: 老人账号, 张素琴
- `elder-dad` / `FamilyPulse@123`: 老人账号, 林建国
- 默认家庭邀请码: `FAMILY26`, 已包含“妈妈”和“爸爸”两位老人。

## 5. iOS 架构

- SwiftUI App
- `@Observable`/`@State` 管理页面状态
- `FamilyPulseAPI` 封装 REST 请求
- `FamilyPulseServerClient` 默认连接本地 API 地址, 后续可替换为生产服务器地址
- `FamilyStore` 作为 App 级状态: 当前用户、家庭、老人、同步墙、错误态
- 病历/OCR 上传链路移除, iOS 不申请相机/相册权限
- App Intent 保持薄层, 复用 `CareActionService`

## 6. API 初稿

基础:

- `GET /api/health`
- `POST /api/auth/register`
- `POST /api/auth/login`
- `POST /api/auth/apple`
- `GET /api/families`
- `POST /api/families`
- `POST /api/families/join`
- `GET /api/families/{familyId}/overview`

老人:

- `POST /api/families/{familyId}/elders`
- `GET /api/families/{familyId}/elders`

照护动作:

- `GET /api/families/{familyId}/elders/{elderId}/actions/today`
- `POST /api/families/{familyId}/elders/{elderId}/actions/events`
- `DELETE /api/families/{familyId}/elders/{elderId}/actions/events/{eventId}`

历史:

- `GET /api/families/{familyId}/action-history?date=yyyy-MM-dd&limit=10`
- 旧病历和附件接口保留路径但返回 410 Gone

复查:

- `POST /api/families/{familyId}/appointments`
- `GET /api/families/{familyId}/appointments`
- `PATCH /api/families/{familyId}/appointments/{appointmentId}`

同步墙:

- `GET /api/families/{familyId}/activity-feed?since=...`

## 7. 首版交付范围

必须完成:

- 服务端可运行, 支持家庭、老人、照护事件、操作历史、复查任务和订阅权益。
- 服务端有集成测试覆盖核心流程。
- iOS App 可构建并在模拟器运行。
- iOS 首屏含 iOS 26 风格玻璃化同步墙/老人今日页。
- App 启动后必须登录并连接默认本地后端。
- App 有 API Client 和集中式 base URL 配置, 后续可替换为自有服务器 IP。

延期:

- 病历上传、OCR 病历夹、真实图片对象存储上传。
- 真正的推送通知 APNs。
- 多租户生产级认证。
- Watch App。
- 完整 Widget extension 发布包。

## 8. 设计完整度自评

当前方案覆盖用户画像、核心旅程、关键边界、端到端数据模型、API、iOS 状态管理、服务端模块、测试方式。首版可开发完整度: 95%。
