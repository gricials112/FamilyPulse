# FamilyPulse / 家安 功能需求文档

版本: 0.3  
日期: 2026-05-31

## 1. 角色

### 1.1 Elder 老人

- 主要操作: 点击今日动作大按钮, 查看家人留言和下次复查。
- 能力假设: 可识别大字按钮, 不需要理解复杂列表。
- 不承担家庭配置、复查指派。

### 1.2 Caregiver 子女/兄弟姐妹

- 主要操作: 查看同步墙和操作历史, 创建/认领复查, 帮老人补录事件。
- 需要知道“今天是否已吃药/测量”, 不需要诊断。

### 1.3 Admin 家庭管理员

- 主要操作: 创建家庭, 邀请成员, 管理老人档案和成员角色。

## 2. 数据实体

### 2.1 User

- `id`: UUID
- `displayName`: String
- `createdAt`: Instant

### 2.2 Family

- `id`: UUID
- `name`: String
- `inviteCode`: String
- `createdAt`: Instant

### 2.3 Membership

- `id`: UUID
- `familyId`: UUID
- `userId`: UUID
- `role`: ADMIN | CAREGIVER | ELDER
- `createdAt`: Instant

### 2.4 ElderProfile

- `id`: UUID
- `familyId`: UUID
- `name`: String
- `birthYear`: Int?
- `notes`: String?
- `createdAt`: Instant

### 2.5 CareActionDefinition

- `actionKey`: String, 如 `morning_meds`
- `title`: String, 如 `已吃早药`
- `icon`: String, SF Symbol 名称
- `sortOrder`: Int
- `defaultEnabled`: Boolean

### 2.6 CareActionEvent

- `id`: UUID
- `familyId`: UUID
- `elderId`: UUID
- `actionKey`: String
- `status`: DONE | UNDONE
- `eventDate`: LocalDate
- `eventTime`: OffsetDateTime
- `source`: APP | WIDGET | CAREGIVER
- `note`: String?
- `createdByUserId`: UUID

规则:

- 同一 `elderId + actionKey + eventDate` 的当前状态由最新事件决定。
- DONE 后再 DONE 不产生重复当前态, 但可保留审计事件。

### 2.7 MedicalRecord（已移除）

- 因处方、化验单、影像等病历资料涉及敏感个人隐私，App 不再提供病历上传、附件上传或 OCR 病历夹。
- 服务端保留旧表和 DTO 仅用于兼容历史迁移；病历创建、列表、附件上传/下载接口均返回 410 Gone。

### 2.8 Appointment

- `id`: UUID
- `familyId`: UUID
- `elderId`: UUID
- `title`: String
- `scheduledAt`: OffsetDateTime
- `hospital`: String?
- `department`: String?
- `assignedToUserId`: UUID?
- `checklist`: String[]
- `status`: PLANNED | DONE | CANCELED
- `createdAt`: Instant

## 3. 功能需求

### FR-1 创建家庭

作为 Admin, 我可以创建家庭, 得到邀请码, 以便邀请兄弟姐妹。

验收:

- 创建后返回 familyId、inviteCode。
- 创建者自动成为 ADMIN。
- 家庭名不能为空。

### FR-1A 登录与家庭选择

作为家庭成员, 我必须先登录到服务端, 再选择创建或加入家庭。

验收:

- App 启动后先显示登录页。
- 登录页必须选择“我是老人”或“我是家人”。
- 登录页必须提供“微信登录”作为独立登录方式。
- 账号直接注册入口关闭；账号密码登录仅保留给已有测试账号和运维兼容场景。
- 微信登录提交 `code/openId/unionId/nickname`, 服务端按微信身份创建或匹配用户并返回 token。
- 当前没有真实微信资料时，App 使用示例资料 `wx_mock_family` / `wx_mock_elder` 完成本地演示。
- 登录提交 `username/password`, 服务端校验密码并返回 token。
- Apple 登录提交 iOS identity token, 服务端校验 Apple token 后返回 token。
- 登录成功后拉取该用户已加入的家庭列表。
- 如果没有家庭, App 引导创建家庭或用邀请码加入。
- 选择“我是老人”后, 如果家庭里有多位老人, 必须选择当前使用手机的老人。
- 选择“我是家人”后, 进入完整同步墙、操作历史、复查看板和设置页。
- 后续所有接口使用 `Authorization: Bearer ...` 访问。
- 未登录请求家庭资源返回 401。

### FR-2 邀请加入家庭

作为 Caregiver, 我可以用邀请码加入家庭。

验收:

- 邀请码有效则建立 membership。
- 重复加入不创建重复 membership。
- 无效邀请码返回 404/400。

### FR-3 添加老人档案

作为家庭成员, 我可以添加老人档案。

验收:

- 名称必填。
- 创建后同步墙能出现该老人。
- 同一个家庭可以添加多个老人。
- App 提供老人筛选/选择: “全部 / 妈妈 / 爸爸 ...”。
- 老人端模式可以选择当前使用手机的老人, 只显示该老人的今日大按钮。

### FR-3A 选择家人身份

作为 Caregiver, 我可以看到家庭成员列表并识别当前登录身份。

验收:

- 同步墙或设置页展示家庭成员。
- App 标记“当前我是谁”。
- 后续指派复查任务时可以选择家庭成员作为负责人。

### FR-4 今日照护大按钮

作为 Elder, 我可以点击“已吃早药/已测血压”等按钮。

验收:

- 点击后按钮立即完成态。
- 服务端创建事件。
- 今日查询返回每个动作的 completed、completedAt、source。
- 10 秒内可撤销, 撤销后状态恢复未完成。

### FR-5 家庭同步墙

作为 Caregiver, 我可以查看家庭当天照护状态和最新事件。

验收:

- 返回每位老人的今日动作摘要。
- 返回按时间倒序排列的 activity feed。
- 每条动态展示操作人头像、姓名、照护对象、事件类型和留言。
- 新增照护事件后同步墙数据可刷新看到。

### FR-6 病历上传移除

作为用户，我不希望 App 采集或上传病历、处方、化验单、影像等敏感健康资料。

验收:

- iOS 不提供病历上传入口，不申请相机/相册隐私权限。
- OCR 解析和病历上传客户端代码移除。
- 服务端病历创建/列表接口返回 410 Gone。
- 服务端附件上传/列表/下载接口返回 410 Gone。
- 概览和同步墙不再返回病历动态。

### FR-7 异步复查备忘

作为 Caregiver, 我可以创建、认领、完成复查任务。

验收:

- 支持创建标题、时间、医院、科室、清单、负责人。
- 创建复查时必须完整登记医院、科室和携带清单, 否则拒绝保存。
- 支持登记留言和完成留言。
- 复查看板展示复查对象、登记人、负责人、留言、携带清单和状态。

### FR-8 订阅历史回看

作为家庭成员，我能在免费版查看最近操作；月付/年付后可按日期回看更多操作历史。

验收:

- 免费版操作历史只返回最近 10 条，不支持按日期查询。
- 月付订阅价格为 `¥6/月`，同步延迟 30 秒以内，支持断网补发，可按日期查看最近 7 天操作历史，每天最多 10 条。
- 年付订阅价格为 `¥58/年`，同步延迟 10 秒以内，支持断网补发，可按日期查看全部操作历史，每天最多 10 条。
- 未订阅用户不支持老人断网状态补发；订阅用户支持离线暂存并在联网后补发。
- 额外订阅差异: 免费不可新增自定义照护操作，月付每位老人最多 3 个，年付每位老人最多 20 个。
- 设置页展示订阅价格、同步延迟、断网补发、操作历史和自定义操作限制。
- 支持查询未来复查。
- 支持状态改为 DONE/CANCELED。

### FR-8 iOS 26 体验

作为用户, 我希望 App 看起来像新的系统 App, 同时老人容易使用。

验收:

- iOS 26 上玻璃化卡片和按钮使用原生 Liquid Glass API。
- 较早系统使用 material fallback。
- 所有核心按钮有 accessibility label。
- 老人模式关键按钮高度不小于 72pt。

### FR-9 默认本地后端连接

作为开发者, 我可以让 App 默认连接本地后端, 后续替换为自有服务器 IP。

验收:

- App 启动先登录, 登录后请求家庭列表。
- API base URL 在 `AppConfiguration` 统一配置。
- 默认地址为本地后端, UI 不展示调试字样或技术地址。

## 4. 非功能需求

- NFR-1 隐私: 服务端接口必须按家庭 membership 校验资源访问。
- NFR-2 可靠性: 照护事件 API 要幂等处理同日同动作重复点击。
- NFR-3 响应: 同步墙查询在 H2 开发环境下小数据量 < 300ms。
- NFR-4 可测试: 服务端核心流程用集成测试覆盖; iOS 至少完成编译和模拟器 smoke test。
- NFR-5 可替换: 认证和存储可在后续替换, 不影响 API 资源模型。
- NFR-6 无医疗建议: 文案不含诊断、剂量建议、异常判断。

## 5. 用户旅程

### Journey A: 新家庭首次使用

1. 子女创建家庭“爸妈健康同步”。
2. App 显示邀请码。
3. 子女添加“妈妈”档案。
4. 老人端进入今日页, 点击“已吃早药”。
5. 子女端同步墙看到事件。

### Journey B: 按日期查看操作历史

1. 子女进入同步墙的“操作历史”区域。
2. 免费版只能看到最近 10 条。
3. 月付用户选择最近 7 天内某一天，查看当天最多 10 条固定记录。
4. 年付用户选择任意日期，查看当天最多 10 条固定记录。
5. 如果老人离线点击照护动作，订阅用户联网后自动补发，历史中显示真实发生时间。

### Journey C: 复查分工

1. 女儿创建“内分泌科复查”。
2. 指派自己, 清单写“带血糖记录、上次化验单、二甲双胍”。
3. 儿子在同步墙看到已安排。
4. 复查后标记 DONE。

## 6. 首版完成定义

- 文档: 设计方案、功能需求、P0/P1 审查均落盘。
- 服务端: Maven test 通过, API 可被 curl 调用。
- iOS: Xcode build 通过, 模拟器可启动, 首页核心交互可用。
- 证据: README 记录运行命令和测试结果。
