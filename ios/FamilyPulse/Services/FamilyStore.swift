import Foundation
import Observation
import UIKit
import UserNotifications

extension Notification.Name {
    static let pushDeviceTokenDidChange = Notification.Name("FamilyPulsePushDeviceTokenDidChange")
    static let pushRegistrationFailed = Notification.Name("FamilyPulsePushRegistrationFailed")
    static let didReceiveSilentPush = Notification.Name("FamilyPulseDidReceiveSilentPush")
}

enum SessionPhase {
    case signedOut
    case loading
    case intro
    case needsDisplayName
    case needsFamily
    case needsElder
    case needsElderSelection
    case ready
}

@MainActor
@Observable
final class FamilyStore {
    var phase: SessionPhase = .signedOut
    var currentUser: ServerUser?
    var userMode: FamilyUserMode = .family
    var families: [ServerFamily] = []
    var selectedFamily: ServerFamily?
    var selectedElderId: UUID?
    var snapshot = FamilySnapshot(
        familyId: nil,
        familyName: "",
        inviteCode: "",
        members: [],
        elders: [],
        feed: [],
        records: [],
        appointments: [],
        lastUpdatedAt: Date()
    )
    var statusMessage = ""
    var isSyncing = false
    var loginError: String?
    var familyError: String?
    var customActions: [ServerCustomAction] = []
    var subscriptionTier: String = "FREE"
    var subscriptionExpiresAt: Date?
    var canQueueOfflineActions = false
    var canUsePushNotifications = false
    var pushNotificationsEnabled = UserDefaults.standard.bool(forKey: "pushNotificationsEnabled")
    var pushStatusMessage = ""
    var syncDelaySeconds = 0
    var maxCustomActionsPerElder = 0
    var historyRetentionDays = 90
    var historyDailyLimit = 10
    var subscriptionActivationCode: String?
    var activationDeviceLimit = 0
    var activationUsedCount = 0
    var pendingOfflineActionCount = 0
    var actionHistory: [ActivityItem] = []
    var selectedHistoryDate = Date()
    var isLoadingActionHistory = false
    var heatmapData: [ServerElderActivityHeatmap] = []
    var isLoadingHeatmap = false
    let storeManager = StoreManager()

    var isPremium: Bool {
        subscriptionTier != "FREE"
    }

    var subscriptionDisplayName: String {
        switch subscriptionTier {
        case "YEARLY": String(localized: "年付")
        case "MONTHLY", "PREMIUM": String(localized: "月付")
        default: String(localized: "免费版")
        }
    }

    var autoRefreshIntervalSeconds: Int? {
        syncDelaySeconds > 0 ? syncDelaySeconds : nil
    }

    func updateAvatar(symbol: String, color: String) {
        runFamilyTask("正在更新头像") {
            let updated = try await self.client.updateAvatar(symbol: symbol, color: color)
            self.currentUser = updated
            self.cacheCurrentUser(updated)
            try await self.reloadOverview()
        }
    }

    func updateDisplayName(_ displayName: String) {
        guard let currentUser, displayName.trimmingCharacters(in: .whitespacesAndNewlines) != currentUser.displayName else {
            statusMessage = String(localized: "名字没有变化")
            return
        }
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusMessage = String(localized: "名字不能为空")
            return
        }
        runFamilyTask("正在更新名字") {
            let updated = try await self.client.updateDisplayName(trimmed)
            self.currentUser = updated
            self.cacheCurrentUser(updated)
            try await self.reloadOverview()
        }
    }

    func updateUsername(_ username: String) {
        guard let currentUser, username != currentUser.username else {
            statusMessage = String(localized: "用户名没有变化")
            return
        }
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusMessage = String(localized: "用户名不能为空")
            return
        }
        runFamilyTask("正在更新用户名") {
            let updated = try await self.client.updateUsername(trimmed)
            self.currentUser = updated
            self.cacheCurrentUser(updated)
            try await self.reloadOverview()
        }
    }

    func loadCustomActions() {
        guard let familyId = selectedFamily?.id else { return }
        Task {
            do {
                customActions = try await client.listCustomActions(familyId: familyId)
            } catch {}
        }
    }

    func canAddCustomAction(for elder: ElderStatus) -> Bool {
        customActionCount(for: elder) < maxCustomActionsPerElder
    }

    func customActionLimitText(for elder: ElderStatus) -> String {
        if maxCustomActionsPerElder == 0 {
            return "订阅后可添加自定义操作"
        }
        return "已用 \(customActionCount(for: elder))/\(maxCustomActionsPerElder)"
    }

    private func customActionCount(for elder: ElderStatus) -> Int {
        let defaultKeys: Set<String> = ["morning_meds", "blood_pressure", "evening_meds"]
        return elder.actions.filter { !defaultKeys.contains($0.actionKey) }.count
    }

    func addCustomAction(actionKey: String, title: String, icon: String, for elderId: UUID) {
        guard let familyId = selectedFamily?.id else { return }
        if let elder = snapshot.elders.first(where: { $0.id == elderId }), !canAddCustomAction(for: elder) {
            statusMessage = customActionLimitText(for: elder)
            return
        }
        let trimmedKey = actionKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty, !trimmedTitle.isEmpty else {
            statusMessage = String(localized: "请填写操作标识和名称")
            return
        }
        runFamilyTask("正在添加操作") {
            _ = try await self.client.createCustomAction(familyId: familyId, elderId: elderId, actionKey: trimmedKey, title: trimmedTitle, icon: icon)
            try await self.reloadOverview()
            self.statusMessage = String(localized: "已添加")
        }
    }

    func updateCustomAction(actionKey: String, title: String, icon: String, for elderId: UUID) {
        guard let familyId = selectedFamily?.id else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedIcon = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            statusMessage = String(localized: "请输入操作名称")
            return
        }
        let finalIcon = trimmedIcon.isEmpty ? "heart.circle.fill" : trimmedIcon
        runFamilyTask("正在更新操作") {
            _ = try await self.client.updateCustomAction(familyId: familyId, elderId: elderId, actionKey: actionKey, title: trimmedTitle, icon: finalIcon)
            try await self.reloadOverview()
            self.statusMessage = String(localized: "已更新")
        }
    }

    func deleteCustomAction(actionKey: String, for elderId: UUID) {
        guard let familyId = selectedFamily?.id else { return }
        runFamilyTask("正在删除操作") {
            try await self.client.deleteCustomAction(familyId: familyId, elderId: elderId, actionKey: actionKey)
            try await self.reloadOverview()
            self.statusMessage = String(localized: "已删除")
        }
    }

    func setupDisplayName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusMessage = String(localized: "名字不能为空")
            return
        }
        runFamilyTask("正在设置名字") {
            let updated = try await self.client.updateDisplayName(trimmed)
            self.currentUser = updated
            self.cacheCurrentUser(updated)
            self.phase = self.determineNextPhase()
        }
    }

    func dismissIntro() {
        UserDefaults.standard.set(true, forKey: "hasCompletedIntro")
        if needsDisplayNameSetup {
            phase = .needsDisplayName
        } else {
            phase = determineNextPhase()
        }
    }

    var needsDisplayNameSetup: Bool {
        guard let user = currentUser else { return false }
        let name = user.displayName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty || name == "Apple 用户" || name.hasPrefix("游客")
    }

    /// 如果用户需要设置名字，将 phase 切换到 needsDisplayName 并返回 true
    @discardableResult
    func requireDisplayNameOrContinue() -> Bool {
        if needsDisplayNameSetup {
            phase = .needsDisplayName
            return true
        }
        return false
    }

    private func determineNextPhase() -> SessionPhase {
        if selectedFamily == nil { return .needsFamily }
        if snapshot.elders.isEmpty { return .needsElder }
        if userMode == .elder && selectedElderId == nil {
            if snapshot.elders.count == 1 {
                selectedElderId = snapshot.elders.first!.id
                return .ready
            }
            return .needsElderSelection
        }
        return .ready
    }

    @ObservationIgnored private var client = FamilyPulseServerClient(baseURL: AppConfiguration.apiBaseURL)
    @ObservationIgnored private var pushTokenObserver: NSObjectProtocol?
    @ObservationIgnored private var pushFailureObserver: NSObjectProtocol?
    @ObservationIgnored private var pushSilentObserver: NSObjectProtocol?
    @ObservationIgnored private let pushDeviceTokenKey = "pushDeviceToken"
    @ObservationIgnored private let pushEnabledKey = "pushNotificationsEnabled"

    /// Pushes current session context to App Group so the widget can read it.
    func syncWidgetSession() {
        guard let token = KeychainStore.read(key: "authToken"),
              let familyId = selectedFamily?.id,
              let elder = selectedElder else { return }
        SharedDefaults.saveSession(
            authToken: token,
            familyId: familyId.uuidString.lowercased(),
            elderId: elder.id.uuidString.lowercased(),
            elderName: elder.name
        )
    }
    @ObservationIgnored private var undoToken: UndoToken?
    @ObservationIgnored private var pendingCareActions: [PendingCareActionRequest] = []

    init() {
        guard !AppRuntime.isRunningUnitTests else { return }
        loadCachedSubscriptionStatus()
        loadPendingCareActions()
        registerPushNotificationObservers()
        tryRestoreSession()
    }

    deinit {
        if let pushTokenObserver {
            NotificationCenter.default.removeObserver(pushTokenObserver)
        }
        if let pushFailureObserver {
            NotificationCenter.default.removeObserver(pushFailureObserver)
        }
        if let pushSilentObserver {
            NotificationCenter.default.removeObserver(pushSilentObserver)
        }
        PushNotificationBridge.shared.clearSilentPushHandler()
    }

    private func tryRestoreSession() {
        guard let token = KeychainStore.read(key: "authToken"),
              let userData = KeychainStore.read(key: "currentUser"),
              let user = try? JSONDecoder().decode(ServerUser.self, from: Data(userData.utf8)) else {
            return
        }
        client.authToken = token
        currentUser = user
        phase = .loading
        statusMessage = String(localized: "恢复会话")
        Task {
            do {
                // 从服务器刷新用户信息，覆盖可能的 Keychain 缓存
                if let fresh = try? await client.fetchCurrentUser() {
                    currentUser = fresh
                    cacheCurrentUser(fresh)
                }
                families = try await client.listFamilies()
                if let firstFamily = families.first {
                    try await selectFamilyAndLoad(firstFamily)
                } else {
                    phase = .needsFamily
                }
            } catch {
                KeychainStore.delete(key: "authToken")
                KeychainStore.delete(key: "currentUser")
                client.authToken = ""
                currentUser = nil
                phase = .signedOut
            }
        }
    }

    var visibleElders: [ElderStatus] {
        if userMode == .elder, let selectedElderId {
            return snapshot.elders.filter { $0.id == selectedElderId }
        }
        guard let selectedElderId else {
            return snapshot.elders
        }
        return snapshot.elders.filter { $0.id == selectedElderId }
    }

    var selectedElder: ElderStatus? {
        if let selectedElderId {
            return snapshot.elders.first { $0.id == selectedElderId }
        }
        return snapshot.elders.first
    }

    var canUseFamilyFeatures: Bool {
        selectedFamily != nil && !snapshot.elders.isEmpty
    }

    func login(username: String, password: String, mode: FamilyUserMode) {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty, !password.isEmpty else {
            loginError = String(localized: "请输入账号和密码")
            return
        }
        userMode = mode
        phase = .loading
        isSyncing = true
        statusMessage = String(localized: "正在登录")
        Task {
            do {
                let auth = try await client.login(username: trimmedUsername, password: password)
                client.authToken = auth.token
                currentUser = auth.user
                KeychainStore.save(key: "authToken", value: auth.token)
                if let data = try? JSONEncoder().encode(auth.user) {
                    KeychainStore.save(key: "currentUser", value: String(data: data, encoding: .utf8) ?? "")
                }
                families = try await client.listFamilies()
                if let firstFamily = families.first {
                    try await selectFamilyAndLoad(firstFamily)
                } else {
                    selectedFamily = nil
                    phase = .needsFamily
                    statusMessage = String(localized: "请创建或加入家庭")
                }
            } catch let error as FamilyPulseServerClient.ApiClientError {
                phase = .signedOut
                loginError = error.errorDescription
            } catch {
                phase = .signedOut
                loginError = String(localized: "网络连接失败，请检查网络设置")
            }
            isSyncing = false
        }
    }

    func signInAsGuest(mode: FamilyUserMode) {
        userMode = mode
        phase = .loading
        isSyncing = true
        statusMessage = String(localized: "正在创建游客账号")
        Task {
            do {
                let auth = try await client.guestLogin()
                client.authToken = auth.token
                currentUser = auth.user
                KeychainStore.save(key: "authToken", value: auth.token)
                cacheCurrentUser(auth.user)
                families = try await client.listFamilies()
                if let firstFamily = families.first {
                    try await selectFamilyAndLoad(firstFamily)
                } else {
                    selectedFamily = nil
                    phase = .needsFamily
                    statusMessage = String(localized: "游客账号已创建，请创建或加入家庭")
                }
            } catch let error as FamilyPulseServerClient.ApiClientError {
                phase = .signedOut
                loginError = error.errorDescription
            } catch {
                phase = .signedOut
                loginError = String(localized: "游客登录失败，请检查网络设置")
            }
            isSyncing = false
        }
    }

    func signInWithApple(identityToken: String, displayName: String?, mode: FamilyUserMode) {
        userMode = mode
        phase = .loading
        isSyncing = true
        statusMessage = String(localized: "正在通过 Apple 登录")
        Task {
            var didAuthenticate = false
            do {
                let auth = try await client.loginWithApple(identityToken: identityToken, displayName: displayName)
                didAuthenticate = true
                client.authToken = auth.token
                currentUser = auth.user
                KeychainStore.save(key: "authToken", value: auth.token)
                cacheCurrentUser(auth.user)
                families = try await client.listFamilies()
                if let firstFamily = families.first {
                    try await selectFamilyAndLoad(firstFamily)
                } else {
                    phase = .needsFamily
                    statusMessage = String(localized: "请创建或加入家庭")
                }
            } catch let error as FamilyPulseServerClient.ApiClientError {
                phase = .signedOut
                loginError = error.errorDescription
            } catch {
                phase = .signedOut
                loginError = didAuthenticate ? String(localized: "Apple 登录成功，但同步家庭数据失败，请稍后重试") : String(localized: "Apple 登录失败，请稍后重试")
            }
            isSyncing = false
        }
    }

    func signInWithWeChat(code: String, mode: FamilyUserMode) {
        userMode = mode
        phase = .loading
        isSyncing = true
        statusMessage = String(localized: "正在通过微信登录")
        Task {
            do {
                let auth = try await client.loginWithWeChat(code: code, openId: nil, unionId: nil, nickname: nil)
                client.authToken = auth.token
                currentUser = auth.user
                KeychainStore.save(key: "authToken", value: auth.token)
                cacheCurrentUser(auth.user)
                families = try await client.listFamilies()
                if let firstFamily = families.first {
                    try await selectFamilyAndLoad(firstFamily)
                } else {
                    selectedFamily = nil
                    phase = .needsFamily
                    statusMessage = String(localized: "微信登录成功, 请创建或加入家庭")
                }
            } catch let error as FamilyPulseServerClient.ApiClientError {
                phase = .signedOut
                loginError = error.errorDescription
            } catch {
                phase = .signedOut
                loginError = String(localized: "微信登录失败，请稍后重试")
            }
            isSyncing = false
        }
    }

    func signOut() {
        if let token = PushNotificationBridge.shared.deviceToken ?? UserDefaults.standard.string(forKey: pushDeviceTokenKey),
           !client.authToken.isEmpty {
            let notificationClient = client
            Task {
                _ = try? await notificationClient.disablePushDeviceToken(token)
            }
        }
        currentUser = nil
        client.authToken = ""
        KeychainStore.delete(key: "authToken")
        KeychainStore.delete(key: "currentUser")
        userMode = .family
        families = []
        selectedFamily = nil
        selectedElderId = nil
        subscriptionTier = "FREE"
        subscriptionExpiresAt = nil
        canQueueOfflineActions = false
        canUsePushNotifications = false
        pushNotificationsEnabled = false
        pushStatusMessage = ""
        syncDelaySeconds = 0
        maxCustomActionsPerElder = 0
        historyRetentionDays = 90
        historyDailyLimit = 10
        subscriptionActivationCode = nil
        activationDeviceLimit = 0
        activationUsedCount = 0
        actionHistory = []
        pendingCareActions = []
        savePendingCareActions()
        UserDefaults.standard.removeObject(forKey: "cachedSubscriptionStatus")
        UserDefaults.standard.set(false, forKey: pushEnabledKey)
        snapshot = FamilySnapshot(
            familyId: nil,
            familyName: "",
            inviteCode: "",
            members: [],
            elders: [],
            feed: [],
            records: [],
            appointments: [],
            lastUpdatedAt: Date()
        )
        SharedDefaults.clearSession()
        phase = .signedOut
        statusMessage = String(localized: "")
    }

    func deleteAccount() async -> Bool {
        isSyncing = true
        statusMessage = String(localized: "正在删除账号")
        do {
            try await client.deleteAccount()
            // Clear all local state after successful server-side deletion
            currentUser = nil
            client.authToken = ""
            KeychainStore.delete(key: "authToken")
            KeychainStore.delete(key: "currentUser")
            userMode = .family
            families = []
            selectedFamily = nil
            selectedElderId = nil
            subscriptionTier = "FREE"
            subscriptionExpiresAt = nil
            canQueueOfflineActions = false
            canUsePushNotifications = false
            pushNotificationsEnabled = false
            pushStatusMessage = ""
            syncDelaySeconds = 0
            maxCustomActionsPerElder = 0
            historyRetentionDays = 90
            historyDailyLimit = 10
            subscriptionActivationCode = nil
            activationDeviceLimit = 0
            activationUsedCount = 0
            actionHistory = []
            pendingCareActions = []
            savePendingCareActions()
            UserDefaults.standard.removeObject(forKey: "cachedSubscriptionStatus")
            UserDefaults.standard.set(false, forKey: pushEnabledKey)
            snapshot = FamilySnapshot(
                familyId: nil,
                familyName: "",
                inviteCode: "",
                members: [],
                elders: [],
                feed: [],
                records: [],
                appointments: [],
                lastUpdatedAt: Date()
            )
            SharedDefaults.clearSession()
            phase = .signedOut
            statusMessage = String(localized: "账号已删除")
            isSyncing = false
            return true
        } catch {
            statusMessage = String(localized: "账号删除失败：\(error.localizedDescription)")
            isSyncing = false
            return false
        }
    }

    func createFamily(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            familyError = String(localized: "请输入家庭名称")
            return
        }
        isSyncing = true
        Task {
            defer { isSyncing = false }
            do {
                let family = try await self.client.createFamily(name: trimmedName)
                self.families = try await self.client.listFamilies()
                try await self.selectFamilyAndLoad(family)
            } catch let error as FamilyPulseServerClient.ApiClientError {
                familyError = error.errorDescription ?? String(localized: "创建失败")
            } catch {
                familyError = String(localized: "创建失败，请稍后重试")
            }
        }
    }

    func leaveFamily() {
        guard let familyId = selectedFamily?.id else {
            familyError = String(localized: "没有当前家庭")
            return
        }
        isSyncing = true
        Task {
            defer { isSyncing = false }
            do {
                try await self.client.leaveFamily(familyId: familyId)
                self.selectedFamily = nil
                self.selectedElderId = nil
                self.families = try await self.client.listFamilies()
                if let firstFamily = self.families.first {
                    try await self.selectFamilyAndLoad(firstFamily)
                } else {
                    self.snapshot = FamilySnapshot(
                        familyId: nil,
                        familyName: "",
                        inviteCode: "",
                        members: [],
                        elders: [],
                        feed: [],
                        records: [],
                        appointments: [],
                        lastUpdatedAt: Date()
                    )
                    self.phase = .needsFamily
                }
            } catch let error as FamilyPulseServerClient.ApiClientError {
                familyError = error.errorDescription ?? String(localized: "退出失败")
            } catch {
                familyError = String(localized: "退出失败，请稍后重试")
            }
        }
    }

    func joinFamily(inviteCode: String) {
        let trimmedCode = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else {
            familyError = String(localized: "请输入邀请码")
            return
        }
        isSyncing = true
        Task {
            defer { isSyncing = false }
            do {
                let family = try await self.client.joinFamily(inviteCode: trimmedCode)
                self.families = try await self.client.listFamilies()
                try await self.selectFamilyAndLoad(family)
            } catch let error as FamilyPulseServerClient.ApiClientError {
                familyError = error.errorDescription ?? String(localized: "邀请码无效")
            } catch {
                familyError = String(localized: "加入失败，请稍后重试")
            }
        }
    }

    func selectFamily(_ family: ServerFamily) {
        runFamilyTask("正在切换家庭") {
            self.selectedElderId = nil
            try await self.selectFamilyAndLoad(family)
        }
    }

    func selectElderIdentity(_ elderId: UUID) {
        selectedElderId = elderId
        phase = .ready
        statusMessage = String(localized: "已选择照护对象")
    }

    func chooseDifferentElder() {
        guard userMode == .elder else { return }
        phase = .needsElderSelection
    }

    func switchMode(_ mode: FamilyUserMode) {
        userMode = mode
        if mode == .elder {
            if let selectedElderId, snapshot.elders.contains(where: { $0.id == selectedElderId }) {
                phase = .ready
            } else if snapshot.elders.count == 1, let onlyElder = snapshot.elders.first {
                selectedElderId = onlyElder.id
                phase = .ready
            } else {
                phase = .needsElderSelection
            }
        } else {
            selectedElderId = nil
            phase = snapshot.elders.isEmpty ? .needsElder : .ready
        }
    }

    func skipElderOnboarding() {
        phase = .ready
        statusMessage = String(localized: "可在设置中添加老人")
    }

    func deleteElder(_ elderId: UUID) {
        guard let familyId = selectedFamily?.id else { return }
        isSyncing = true
        Task {
            defer { isSyncing = false }
            do {
                try await self.client.deleteElder(familyId: familyId, elderId: elderId)
                if selectedElderId == elderId {
                    selectedElderId = nil
                }
                try await self.reloadOverview()
            } catch let error as FamilyPulseServerClient.ApiClientError {
                familyError = error.errorDescription ?? String(localized: "删除失败")
            } catch {
                familyError = String(localized: "删除失败，请稍后重试")
            }
        }
    }

    func addElder(name: String, notes: String?) {
        guard let familyId = selectedFamily?.id else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            familyError = String(localized: "请输入老人姓名")
            return
        }
        isSyncing = true
        Task {
            defer { isSyncing = false }
            do {
                let elder = try await self.client.createElder(familyId: familyId, name: trimmedName, birthYear: nil, notes: notes)
                self.selectedElderId = elder.id
                try await self.reloadOverview()
            } catch let error as FamilyPulseServerClient.ApiClientError {
                familyError = error.errorDescription ?? String(localized: "添加失败")
            } catch {
                familyError = String(localized: "添加失败，请稍后重试")
            }
        }
    }

    func refresh(silent: Bool = false) {
        guard selectedFamily != nil else { return }
        if silent {
            print("[Push] manual silent refresh start family=\(selectedFamily?.id.uuidString ?? "nil")")
            Task {
                do {
                    try await self.reloadOverview()
                    print("[Push] manual silent refresh ok")
                } catch {
                    print("[Push] manual silent refresh failed error=\(error)")
                }
            }
            return
        }
        runFamilyTask("正在同步") {
            try await self.reloadOverview()
        }
    }

    func complete(actionKey: String, for elderId: UUID) {
        guard let familyId = selectedFamily?.id,
              let elderIndex = snapshot.elders.firstIndex(where: { $0.id == elderId }),
              let actionIndex = snapshot.elders[elderIndex].actions.firstIndex(where: { $0.actionKey == actionKey }) else {
            return
        }
        guard snapshot.elders[elderIndex].actions[actionIndex].completedAt == nil else {
            statusMessage = String(localized: "今天已经记录")
            return
        }

        let completedAt = Date()
        let previousAction = snapshot.elders[elderIndex].actions[actionIndex]
        snapshot.elders[elderIndex].actions[actionIndex].completedAt = completedAt
        snapshot.elders[elderIndex].actions[actionIndex].source = .app
        snapshot.lastUpdatedAt = completedAt
        statusMessage = String(localized: "已记录, 正在同步")

        Task {
            do {
                let event = try await client.createCareEvent(familyId: familyId, elderId: elderId, actionKey: actionKey, occurredAt: completedAt)
                undoToken = UndoToken(elderId: elderId, actionKey: actionKey, eventId: event.id, previousCompletedAt: previousAction.completedAt, previousSource: previousAction.source)
                try await reloadOverview()
                statusMessage = String(localized: "已同步")
            } catch {
                if canQueueOfflineActions {
                    enqueuePendingCareAction(familyId: familyId, elderId: elderId, actionKey: actionKey, occurredAt: completedAt)
                    statusMessage = String(localized: "已离线保存，联网后自动补发")
                    return
                }
                snapshot.elders[elderIndex].actions[actionIndex].completedAt = previousAction.completedAt
                snapshot.elders[elderIndex].actions[actionIndex].source = previousAction.source
                statusMessage = String(localized: "同步失败, 请稍后重试")
            }
        }
    }

    func syncSubscriptionStatus() {
        guard currentUser != nil else { return }
        Task { await syncSubscriptionStatusAsync() }
    }

    private func syncSubscriptionStatusAsync() async {
        guard currentUser != nil else { return }
        do {
            let status = try await client.getSubscriptionStatus()
            applySubscriptionStatus(status)
        } catch {
            print("[Subscription] Failed to sync: \(error)")
        }
    }

    func enablePushNotifications() {
        guard currentUser != nil else { return }
        guard canUsePushNotifications && isPremium else {
            pushStatusMessage = "订阅后可开启 Push 通知"
            statusMessage = pushStatusMessage
            print("[Push] enable skipped reason=not_premium tier=\(subscriptionTier) canUse=\(canUsePushNotifications)")
            return
        }
        pushStatusMessage = "正在请求系统通知权限"
        print("[Push] enable requested tier=\(subscriptionTier) cachedToken=\(PushNotificationBridge.shared.deviceToken.map(PushNotificationBridge.tokenSummary) ?? "nil")")
        PushNotificationBridge.shared.requestAuthorizationAndRegister()
        if let token = PushNotificationBridge.shared.deviceToken ?? UserDefaults.standard.string(forKey: pushDeviceTokenKey) {
            registerPushDeviceToken(token)
        }
    }

    func disablePushNotifications() {
        guard let token = PushNotificationBridge.shared.deviceToken ?? UserDefaults.standard.string(forKey: pushDeviceTokenKey) else {
            pushNotificationsEnabled = false
            UserDefaults.standard.set(false, forKey: pushEnabledKey)
            pushStatusMessage = "Push 通知已关闭"
            print("[Push] disable skipped reason=no_token")
            return
        }
        pushStatusMessage = "正在关闭 Push 通知"
        print("[Push] disable backend token=\(PushNotificationBridge.tokenSummary(token))")
        Task {
            do {
                let device = try await client.disablePushDeviceToken(token)
                pushNotificationsEnabled = device.enabled
                UserDefaults.standard.set(device.enabled, forKey: pushEnabledKey)
                PushNotificationBridge.shared.unregister()
                pushStatusMessage = "Push 通知已关闭"
                print("[Push] disable backend ok enabled=\(device.enabled) env=\(device.environment)")
            } catch let error as FamilyPulseServerClient.ApiClientError {
                pushStatusMessage = error.errorDescription ?? "关闭失败，请稍后重试"
                print("[Push] disable backend api_error=\(error.localizedDescription)")
            } catch {
                pushStatusMessage = "关闭失败，请稍后重试"
                print("[Push] disable backend error=\(error)")
            }
        }
    }

    private func registerPushDeviceToken(_ token: String) {
        guard currentUser != nil else { return }
        guard canUsePushNotifications && isPremium else {
            pushNotificationsEnabled = false
            UserDefaults.standard.set(false, forKey: pushEnabledKey)
            pushStatusMessage = "订阅后可开启 Push 通知"
            print("[Push] register backend skipped reason=not_premium token=\(PushNotificationBridge.tokenSummary(token)) tier=\(subscriptionTier) canUse=\(canUsePushNotifications)")
            return
        }
        pushStatusMessage = "正在开启 Push 通知"
        print("[Push] register backend start token=\(PushNotificationBridge.tokenSummary(token)) env=\(PushNotificationBridge.shared.environment)")
        Task {
            do {
                let device = try await client.registerPushDeviceToken(token, environment: PushNotificationBridge.shared.environment)
                pushNotificationsEnabled = device.enabled
                UserDefaults.standard.set(token, forKey: pushDeviceTokenKey)
                UserDefaults.standard.set(device.enabled, forKey: pushEnabledKey)
                pushStatusMessage = device.enabled ? "Push 通知已开启" : "Push 通知已关闭"
                print("[Push] register backend ok enabled=\(device.enabled) env=\(device.environment)")
            } catch let error as FamilyPulseServerClient.ApiClientError {
                pushNotificationsEnabled = false
                UserDefaults.standard.set(false, forKey: pushEnabledKey)
                pushStatusMessage = error.errorDescription ?? "开启失败，请稍后重试"
                print("[Push] register backend api_error=\(error.localizedDescription)")
            } catch {
                pushNotificationsEnabled = false
                UserDefaults.standard.set(false, forKey: pushEnabledKey)
                pushStatusMessage = "开启失败，请稍后重试"
                print("[Push] register backend error=\(error)")
            }
        }
    }

    @discardableResult
    func verifyReceipt(transactionJws: String, plan: StoreSubscriptionPlan? = nil) async -> Bool {
        guard currentUser != nil else { return false }
        do {
            let status = try await client.verifyReceipt(transactionJws: transactionJws)
            applySubscriptionStatus(status)
            statusMessage = String(localized: "已激活订阅")
            return true
        } catch {
            print("[Subscription] Verify receipt failed: \(error)")
            #if DEBUG
            if let plan {
                let tier = plan == .yearly ? "YEARLY" : "MONTHLY"
                do {
                    let status = try await client.purchasePremium(tier: tier)
                    applySubscriptionStatus(status)
                    statusMessage = String(localized: "已激活订阅（模拟器模式）")
                    return true
                } catch {
                    print("[Subscription] Purchase fallback also failed: \(error)")
                }
            }
            #endif
            await syncSubscriptionStatusAsync()
            return false
        }
    }

    func setAccountPassword(currentPassword: String?, newPassword: String, confirmPassword: String) {
        let finalPassword = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard finalPassword.count >= 8 else {
            statusMessage = String(localized: "密码至少需要 8 位")
            return
        }
        guard finalPassword == confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines) else {
            statusMessage = String(localized: "两次输入的密码不一致")
            return
        }
        isSyncing = true
        statusMessage = String(localized: "正在设置密码")
        Task {
            do {
                let updated = try await client.setPassword(currentPassword: currentPassword, newPassword: finalPassword)
                currentUser = updated
                cacheCurrentUser(updated)
                statusMessage = String(localized: "密码已设置，请妥善保存账号")
            } catch let error as FamilyPulseServerClient.ApiClientError {
                statusMessage = error.errorDescription ?? String(localized: "密码设置失败")
            } catch {
                statusMessage = String(localized: "密码设置失败，请稍后重试")
            }
            isSyncing = false
        }
    }

    func bindWeChat(code: String) {
        guard currentUser != nil else { return }
        isSyncing = true
        statusMessage = String(localized: "正在绑定微信")
        Task {
            do {
                let updated = try await client.bindWeChat(code: code, openId: nil, unionId: nil, nickname: nil)
                currentUser = updated
                cacheCurrentUser(updated)
                statusMessage = String(localized: "微信已绑定，后续可直接微信登录")
            } catch let error as FamilyPulseServerClient.ApiClientError {
                statusMessage = error.errorDescription ?? String(localized: "微信绑定失败")
            } catch {
                statusMessage = String(localized: "微信绑定失败，请稍后重试")
            }
            isSyncing = false
        }
    }

    func activateSubscriptionCode(_ code: String) {
        let finalCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalCode.isEmpty else {
            statusMessage = String(localized: "请输入订阅码")
            return
        }
        guard currentUser != nil else { return }
        isSyncing = true
        statusMessage = String(localized: "正在激活订阅码")
        Task {
            do {
                let status = try await client.activateSubscriptionCode(code: finalCode, deviceId: subscriptionActivationDeviceId)
                applySubscriptionStatus(status)
                statusMessage = String(localized: "订阅码已激活")
            } catch let error as FamilyPulseServerClient.ApiClientError {
                statusMessage = error.errorDescription ?? String(localized: "订阅码激活失败")
            } catch {
                statusMessage = String(localized: "订阅码激活失败，请稍后重试")
            }
            isSyncing = false
        }
    }

    func debugActivatePremium() {
        let status = FamilyPulseServerClient.SubscriptionStatus(
            tier: "MONTHLY",
            expiresAt: Calendar.current.date(byAdding: .month, value: 1, to: Date()),
            canUploadAttachments: false,
            canCreateMultipleFamilies: true,
            canQueueOfflineActions: true,
            canUsePushNotifications: true,
            syncDelaySeconds: 30,
            maxCustomActionsPerElder: 4,
            historyRetentionDays: 7,
            historyDailyLimit: 10,
            activationCode: "FP-DEBG-MON1",
            activationDeviceLimit: 2,
            activationUsedCount: 0
        )
        applySubscriptionStatus(status)
        statusMessage = String(localized: "模拟月付已激活（本地）")
    }

    func debugActivateYearly() {
        let status = FamilyPulseServerClient.SubscriptionStatus(
            tier: "YEARLY",
            expiresAt: Calendar.current.date(byAdding: .year, value: 1, to: Date()),
            canUploadAttachments: false,
            canCreateMultipleFamilies: true,
            canQueueOfflineActions: true,
            canUsePushNotifications: true,
            syncDelaySeconds: 10,
            maxCustomActionsPerElder: 20,
            historyRetentionDays: -1,
            historyDailyLimit: 10,
            activationCode: "FP-DEBG-YEAR",
            activationDeviceLimit: 4,
            activationUsedCount: 0
        )
        applySubscriptionStatus(status)
        statusMessage = String(localized: "模拟年付已激活（本地）")
    }

    func debugActivateFree() {
        let status = FamilyPulseServerClient.SubscriptionStatus(
            tier: "FREE",
            expiresAt: nil,
            canUploadAttachments: false,
            canCreateMultipleFamilies: false,
            canQueueOfflineActions: false,
            canUsePushNotifications: false,
            syncDelaySeconds: 0,
            maxCustomActionsPerElder: 0,
            historyRetentionDays: 90,
            historyDailyLimit: 10,
            activationCode: nil,
            activationDeviceLimit: 0,
            activationUsedCount: 0
        )
        applySubscriptionStatus(status)
        statusMessage = String(localized: "已切换为免费版（本地）")
    }

    func undoLastAction() {
        guard let familyId = selectedFamily?.id, let undoToken else {
            statusMessage = String(localized: "没有可撤销记录")
            return
        }
        isSyncing = true
        statusMessage = String(localized: "正在撤销")
        Task {
            do {
                _ = try await self.client.undoCareEvent(familyId: familyId, elderId: undoToken.elderId, eventId: undoToken.eventId)
                self.undoToken = nil
                try await self.reloadOverview()
                statusMessage = String(localized: "已撤销操作")
            } catch {
                statusMessage = String(localized: "撤销失败，请稍后重试")
            }
            isSyncing = false
        }
    }

    func createAppointment(
        title: String,
        scheduledAt: Date,
        hospital: String,
        department: String,
        assignedToUserId: UUID?,
        checklistText: String,
        note: String
    ) {
        guard let familyId = selectedFamily?.id, let elderId = selectedElder?.id else {
            statusMessage = String(localized: "请先选择照护对象")
            return
        }
        let finalTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalHospital = hospital.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalDepartment = department.trimmingCharacters(in: .whitespacesAndNewlines)
        let checklist = checklistText
            .split(whereSeparator: { $0 == "\n" || $0 == "," || $0 == "，" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !finalTitle.isEmpty, !finalHospital.isEmpty, !finalDepartment.isEmpty, !checklist.isEmpty else {
            statusMessage = String(localized: "请完整填写复查标题、医院、科室和携带清单")
            return
        }
        runFamilyTask("正在创建复查") {
            _ = try await self.client.createAppointment(
                familyId: familyId,
                elderId: elderId,
                title: finalTitle,
                scheduledAt: scheduledAt,
                hospital: finalHospital,
                department: finalDepartment,
                assignedToUserId: assignedToUserId,
                checklist: checklist,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            try await self.reloadOverview()
        }
    }

    func markAppointmentDone(_ appointmentId: UUID, resultNote: String) {
        guard let familyId = selectedFamily?.id,
              let index = snapshot.appointments.firstIndex(where: { $0.id == appointmentId }) else {
            return
        }
        let finalResultNote = resultNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalResultNote.isEmpty else {
            statusMessage = String(localized: "请填写复查完成留言")
            return
        }
        snapshot.appointments[index].status = .done
        snapshot.appointments[index].resultNote = finalResultNote
        statusMessage = String(localized: "已标记完成")
        runFamilyTask("正在同步复查状态") {
            _ = try await self.client.markAppointmentDone(familyId: familyId, appointmentId: appointmentId, resultNote: finalResultNote)
            try await self.reloadOverview()
        }
    }

    func loadActionHistory(date: Date? = nil) {
        guard let familyId = selectedFamily?.id else { return }
        let queryDate = isPremium ? (date ?? selectedHistoryDate) : nil
        isLoadingActionHistory = true
        Task {
            defer { isLoadingActionHistory = false }
            do {
                let items = try await client.actionHistory(familyId: familyId, date: queryDate, limit: historyDailyLimit)
                actionHistory = items.map(mapActivityItem)
            } catch let error as FamilyPulseServerClient.ApiClientError {
                actionHistory = []
                let msg = error.errorDescription ?? ""
                if isPremium, !msg.isEmpty {
                    statusMessage = msg
                } else {
                    statusMessage = String(localized: "加载失败，请稍后重试")
                }
            } catch {
                actionHistory = []
                statusMessage = String(localized: "加载失败，请稍后重试")
            }
        }
    }

    func loadHeatmap() {
        guard let familyId = selectedFamily?.id else { return }
        isLoadingHeatmap = true
        Task {
            defer { isLoadingHeatmap = false }
            do {
                heatmapData = try await client.activityHeatmap(familyId: familyId, days: 365)
            } catch {
                statusMessage = String(localized: "加载活跃度失败")
            }
        }
    }

    func loadHeatmapAsync() async {
        guard let familyId = selectedFamily?.id else { return }
        isLoadingHeatmap = true
        defer { isLoadingHeatmap = false }
        do {
            heatmapData = try await client.activityHeatmap(familyId: familyId, days: 365)
        } catch {
            statusMessage = String(localized: "加载活跃度失败")
        }
    }

    private func applySubscriptionStatus(_ status: FamilyPulseServerClient.SubscriptionStatus) {
        subscriptionTier = status.tier
        subscriptionExpiresAt = status.expiresAt
        canQueueOfflineActions = status.canQueueOfflineActions
        canUsePushNotifications = status.canUsePushNotifications
        if !canUsePushNotifications {
            pushNotificationsEnabled = false
            UserDefaults.standard.set(false, forKey: pushEnabledKey)
        }
        syncDelaySeconds = status.syncDelaySeconds
        maxCustomActionsPerElder = status.maxCustomActionsPerElder
        historyRetentionDays = status.historyRetentionDays
        historyDailyLimit = status.historyDailyLimit
        subscriptionActivationCode = status.activationCode
        activationDeviceLimit = status.activationDeviceLimit
        activationUsedCount = status.activationUsedCount
        cacheSubscriptionStatus()
    }

    private func loadCachedSubscriptionStatus() {
        guard let data = UserDefaults.standard.data(forKey: "cachedSubscriptionStatus"),
              let cached = try? JSONDecoder().decode(CachedSubscriptionStatus.self, from: data) else {
            return
        }
        subscriptionTier = cached.tier
        subscriptionExpiresAt = cached.expiresAt
        canQueueOfflineActions = cached.canQueueOfflineActions
        canUsePushNotifications = cached.canUsePushNotifications ?? (cached.tier != "FREE")
        syncDelaySeconds = cached.syncDelaySeconds
        maxCustomActionsPerElder = cached.maxCustomActionsPerElder
        historyRetentionDays = cached.historyRetentionDays
        historyDailyLimit = cached.historyDailyLimit
        subscriptionActivationCode = cached.activationCode
        activationDeviceLimit = cached.activationDeviceLimit ?? 0
        activationUsedCount = cached.activationUsedCount ?? 0
    }

    private func cacheSubscriptionStatus() {
        let cached = CachedSubscriptionStatus(
            tier: subscriptionTier,
            expiresAt: subscriptionExpiresAt,
            canQueueOfflineActions: canQueueOfflineActions,
            canUsePushNotifications: canUsePushNotifications,
            syncDelaySeconds: syncDelaySeconds,
            maxCustomActionsPerElder: maxCustomActionsPerElder,
            historyRetentionDays: historyRetentionDays,
            historyDailyLimit: historyDailyLimit,
            activationCode: subscriptionActivationCode,
            activationDeviceLimit: activationDeviceLimit,
            activationUsedCount: activationUsedCount
        )
        if let data = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(data, forKey: "cachedSubscriptionStatus")
        }
    }

    private func registerPushNotificationObservers() {
        PushNotificationBridge.shared.setSilentPushHandler { [weak self] userInfo in
            guard let self else { return .noData }
            return await self.handleSilentPush(userInfo)
        }
        pushTokenObserver = NotificationCenter.default.addObserver(
            forName: .pushDeviceTokenDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let token = notification.object as? String else { return }
            print("[Push] observer token changed token=\(PushNotificationBridge.tokenSummary(token))")
            Task { @MainActor [weak self] in
                self?.registerPushDeviceToken(token)
            }
        }
        pushFailureObserver = NotificationCenter.default.addObserver(
            forName: .pushRegistrationFailed,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let message = notification.object as? String ?? "系统通知注册失败"
            print("[Push] observer registration failed message=\(message)")
            Task { @MainActor [weak self] in
                self?.pushNotificationsEnabled = false
                self?.pushStatusMessage = message
            }
        }
        pushSilentObserver = NotificationCenter.default.addObserver(
            forName: .didReceiveSilentPush,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("[Push] legacy silent push notification received object=\(String(describing: notification.object))")
            Task { @MainActor [weak self] in
                self?.refresh(silent: true)
            }
        }
    }

    private func handleSilentPush(_ userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        print("[Push] silent sync start selectedFamily=\(selectedFamily?.id.uuidString ?? "nil") payload=\(PushNotificationBridge.payloadSummary(userInfo))")
        guard selectedFamily != nil else {
            print("[Push] silent sync skipped reason=no_selected_family")
            return .noData
        }
        do {
            try await reloadOverview()
            print("[Push] silent sync finished result=newData")
            return .newData
        } catch {
            print("[Push] silent sync failed error=\(error)")
            return .failed
        }
    }

    private func loadPendingCareActions() {
        pendingCareActions = (try? JSONDecoder().decode(
            [PendingCareActionRequest].self,
            from: UserDefaults.standard.data(forKey: "pendingCareActions") ?? Data()
        )) ?? []
        pendingOfflineActionCount = pendingCareActions.count
    }

    private func savePendingCareActions() {
        if let data = try? JSONEncoder().encode(pendingCareActions) {
            UserDefaults.standard.set(data, forKey: "pendingCareActions")
        }
        pendingOfflineActionCount = pendingCareActions.count
    }

    private func enqueuePendingCareAction(familyId: UUID, elderId: UUID, actionKey: String, occurredAt: Date) {
        pendingCareActions.append(PendingCareActionRequest(familyId: familyId, elderId: elderId, actionKey: actionKey, occurredAt: occurredAt))
        savePendingCareActions()
    }

    private func flushPendingCareActions() async {
        guard canQueueOfflineActions, !pendingCareActions.isEmpty else { return }
        var remaining: [PendingCareActionRequest] = []
        for (index, request) in pendingCareActions.enumerated() {
            do {
                _ = try await client.createCareEvent(
                    familyId: request.familyId,
                    elderId: request.elderId,
                    actionKey: request.actionKey,
                    occurredAt: request.occurredAt
                )
            } catch {
                remaining = Array(pendingCareActions[index...])
                break
            }
        }
        let flushedCount = pendingCareActions.count - remaining.count
        pendingCareActions = remaining
        savePendingCareActions()
        if flushedCount > 0 {
            statusMessage = String(localized: "已补发 \(flushedCount) 条离线记录")
        }
    }

    private func mapActivityItem(_ item: ServerActivityItem) -> ActivityItem {
        ActivityItem(
            id: item.entityId,
            title: item.title,
            subtitle: item.subtitle,
            comment: item.comment,
            elderName: item.elderName ?? "照护对象",
            actorDisplayName: item.actorDisplayName ?? "家庭成员",
            actorAvatarSymbol: item.actorAvatarSymbol ?? "person.crop.circle.fill",
            actorAvatarColor: item.actorAvatarColor ?? "green",
            symbolName: item.type == "APPOINTMENT" ? "calendar.badge.clock" : "heart.text.square.fill",
            occurredAt: item.occurredAt,
            tone: item.type == "CARE_ACTION" ? .success : .calm
        )
    }


    private func runFamilyTask(_ message: String, operation: @escaping () async throws -> Void) {
        isSyncing = true
        statusMessage = message
        Task {
            do {
                try await operation()
                statusMessage = String(localized: "已同步")
            } catch {
                statusMessage = String(localized: "同步失败, 请稍后重试")
            }
            isSyncing = false
        }
    }

    private var subscriptionActivationDeviceId: String {
        let key = "subscriptionActivationDeviceId"
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let generated = "ios-" + UUID().uuidString.lowercased()
        UserDefaults.standard.set(generated, forKey: key)
        return generated
    }

    private func cacheCurrentUser(_ user: ServerUser) {
        if let data = try? JSONEncoder().encode(user) {
            KeychainStore.save(key: "currentUser", value: String(data: data, encoding: .utf8) ?? "")
        }
    }

    private func selectFamilyAndLoad(_ family: ServerFamily) async throws {
        selectedFamily = family
        try await reloadOverview()
        if !UserDefaults.standard.bool(forKey: "hasCompletedIntro") {
            phase = .intro
        } else if needsDisplayNameSetup {
            phase = .needsDisplayName
        }
    }

    private func reloadOverview() async throws {
        guard let familyId = selectedFamily?.id else { return }
        let serverStatus = try? await client.getSubscriptionStatus()
        applySubscriptionStatus(serverStatus ?? FamilyPulseServerClient.SubscriptionStatus(tier: "FREE"))
        if !canQueueOfflineActions, !pendingCareActions.isEmpty {
            pendingCareActions = []
            savePendingCareActions()
        }
        await flushPendingCareActions()
        let overview = try await client.overview(familyId: familyId)
        snapshot = FamilySnapshot.from(server: overview)
        loadActionHistory(date: isPremium ? selectedHistoryDate : nil)
        await loadHeatmapAsync()
        if snapshot.elders.isEmpty {
            selectedElderId = nil
            phase = .needsElder
            statusMessage = String(localized: "请添加照护对象")
        } else {
            if let selectedElderId, snapshot.elders.contains(where: { $0.id == selectedElderId }) {
                self.selectedElderId = selectedElderId
            } else if userMode == .elder, snapshot.elders.count == 1, let onlyElder = snapshot.elders.first {
                selectedElderId = onlyElder.id
            } else if userMode == .elder {
                phase = .needsElderSelection
                statusMessage = String(localized: "请选择本人")
                return
            } else {
                selectedElderId = nil
            }
            phase = .ready
            statusMessage = String(localized: "已同步")
        }
        syncWidgetSession()
    }

}

// MARK: - App Group Shared Defaults (mirrored for main app writes)

enum SharedDefaults {
    private static let suite = UserDefaults(suiteName: "group.com.lwj.FamilyPulse")

    static var authToken: String? {
        get { suite?.string(forKey: "authToken") }
        set { suite?.set(newValue, forKey: "authToken") }
    }

    static var selectedElderId: String? {
        get { suite?.string(forKey: "selectedElderId") }
        set { suite?.set(newValue, forKey: "selectedElderId") }
    }

    static var familyId: String? {
        get { suite?.string(forKey: "familyId") }
        set { suite?.set(newValue, forKey: "familyId") }
    }

    static var elderName: String? {
        get { suite?.string(forKey: "elderName") }
        set { suite?.set(newValue, forKey: "elderName") }
    }

    static func saveSession(authToken: String, familyId: String, elderId: String, elderName: String) {
        self.authToken = authToken
        self.familyId = familyId
        self.selectedElderId = elderId
        self.elderName = elderName
    }

    static func clearSession() {
        authToken = nil
        familyId = nil
        selectedElderId = nil
        elderName = nil
    }
}

struct CachedSubscriptionStatus: Codable {
    var tier: String
    var expiresAt: Date?
    var canQueueOfflineActions: Bool
    var canUsePushNotifications: Bool?
    var syncDelaySeconds: Int
    var maxCustomActionsPerElder: Int
    var historyRetentionDays: Int
    var historyDailyLimit: Int
    var activationCode: String?
    var activationDeviceLimit: Int?
    var activationUsedCount: Int?
}

struct PendingCareActionRequest: Codable {
    var id = UUID()
    var familyId: UUID
    var elderId: UUID
    var actionKey: String
    var occurredAt: Date
}

struct UndoToken {
    var elderId: UUID
    var actionKey: String
    var eventId: UUID
    var previousCompletedAt: Date?
    var previousSource: ActionSource?
}

final class PushNotificationBridge {
    static let shared = PushNotificationBridge()

    private let tokenKey = "pushDeviceToken"
    private var silentPushHandler: (([AnyHashable: Any]) async -> UIBackgroundFetchResult)?

    var deviceToken: String? {
        UserDefaults.standard.string(forKey: tokenKey)
    }

    var environment: String {
        #if DEBUG
        "development"
        #else
        "production"
        #endif
    }

    private init() {}

    func setSilentPushHandler(_ handler: @escaping ([AnyHashable: Any]) async -> UIBackgroundFetchResult) {
        silentPushHandler = handler
        print("[Push] silent push handler installed")
    }

    func clearSilentPushHandler() {
        silentPushHandler = nil
        print("[Push] silent push handler cleared")
    }

    func requestAuthorizationAndRegister() {
        print("[Push] requestAuthorizationAndRegister start env=\(environment)")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if let error {
                    print("[Push] authorization failed error=\(error.localizedDescription)")
                    NotificationCenter.default.post(name: .pushRegistrationFailed, object: error.localizedDescription)
                    return
                }
                guard granted else {
                    print("[Push] authorization denied")
                    NotificationCenter.default.post(name: .pushRegistrationFailed, object: "请在系统设置中允许通知")
                    return
                }
                print("[Push] authorization granted; registering for remote notifications")
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func updateDeviceToken(_ deviceTokenData: Data) {
        let token = deviceTokenData.map { String(format: "%02.2hhx", $0) }.joined()
        UserDefaults.standard.set(token, forKey: tokenKey)
        print("[Push] device token updated token=\(Self.tokenSummary(token)) env=\(environment)")
        NotificationCenter.default.post(name: .pushDeviceTokenDidChange, object: token)
    }

    func failRegistration(_ error: Error) {
        print("[Push] registration failed error=\(error.localizedDescription)")
        NotificationCenter.default.post(name: .pushRegistrationFailed, object: error.localizedDescription)
    }

    func handleSilentPush(
        _ userInfo: [AnyHashable: Any],
        completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        DispatchQueue.main.async {
            guard let handler = self.silentPushHandler else {
                print("[Push] silent push skipped reason=no_handler payload=\(Self.payloadSummary(userInfo))")
                NotificationCenter.default.post(name: .didReceiveSilentPush, object: userInfo)
                completionHandler(.noData)
                return
            }
            Task { @MainActor in
                let result = await handler(userInfo)
                print("[Push] silent push completion result=\(Self.fetchResultName(result))")
                completionHandler(result)
            }
        }
    }

    func unregister() {
        DispatchQueue.main.async {
            print("[Push] unregisterForRemoteNotifications")
            UIApplication.shared.unregisterForRemoteNotifications()
        }
    }

    static func tokenSummary(_ tokenData: Data) -> String {
        tokenSummary(tokenData.map { String(format: "%02.2hhx", $0) }.joined())
    }

    static func tokenSummary(_ token: String) -> String {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "empty" }
        if trimmed.count <= 8 {
            return "len=\(trimmed.count):\(trimmed)"
        }
        return "len=\(trimmed.count):*\(trimmed.suffix(8))"
    }

    static func payloadSummary(_ userInfo: [AnyHashable: Any]) -> String {
        let keys = userInfo.keys.map { "\($0)" }.sorted().joined(separator: ",")
        let eventType = userInfo["eventType"] as? String ?? "nil"
        let familyId = userInfo["familyId"] as? String ?? "nil"
        let apsSummary: String
        if let aps = userInfo["aps"] as? [AnyHashable: Any] {
            let apsKeys = aps.keys.map { "\($0)" }.sorted().joined(separator: ",")
            apsSummary = "{\(apsKeys)}"
        } else {
            apsSummary = "nil"
        }
        return "keys=[\(keys)] eventType=\(eventType) familyId=\(familyId) aps=\(apsSummary)"
    }

    private static func fetchResultName(_ result: UIBackgroundFetchResult) -> String {
        switch result {
        case .newData:
            return "newData"
        case .noData:
            return "noData"
        case .failed:
            return "failed"
        @unknown default:
            return "unknown"
        }
    }
}
