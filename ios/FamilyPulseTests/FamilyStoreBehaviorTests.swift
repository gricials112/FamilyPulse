import XCTest

extension SessionPhase: Equatable {}

@MainActor
final class FamilyStoreBehaviorTests: XCTestCase {
    func testInitialUnitTestStateDoesNotRestorePersistedSession() {
        let store = FamilyStore()

        XCTAssertEqual(store.phase, .signedOut)
        XCTAssertNil(store.currentUser)
        XCTAssertEqual(store.subscriptionDisplayName, "免费版")
        XCTAssertFalse(store.isPremium)
        XCTAssertNil(store.autoRefreshIntervalSeconds)
    }

    func testVisibleEldersAndSelectedElderRespectModeAndSelection() {
        let store = makeReadyStore()

        XCTAssertEqual(store.visibleElders.map(\.name), ["妈妈", "爸爸"])
        XCTAssertEqual(store.selectedElder?.name, "妈妈")

        store.selectedElderId = PreviewData.dadId
        XCTAssertEqual(store.visibleElders.map(\.name), ["爸爸"])
        XCTAssertEqual(store.selectedElder?.name, "爸爸")

        store.userMode = .elder
        store.selectedElderId = PreviewData.momId
        XCTAssertEqual(store.visibleElders.map(\.name), ["妈妈"])
    }

    func testSwitchModeChoosesExpectedPhaseAndElderSelection() {
        let store = makeReadyStore()

        store.switchMode(.elder)
        XCTAssertEqual(store.phase, .needsElderSelection)

        store.snapshot.elders = [PreviewData.snapshot.elders[0]]
        store.selectedElderId = nil
        store.switchMode(.elder)
        XCTAssertEqual(store.phase, .ready)
        XCTAssertEqual(store.selectedElderId, PreviewData.momId)

        store.switchMode(.family)
        XCTAssertEqual(store.phase, .ready)
        XCTAssertNil(store.selectedElderId)

        store.snapshot.elders = []
        store.switchMode(.family)
        XCTAssertEqual(store.phase, .needsElder)
    }

    func testValidationPathsSetUserFacingMessagesWithoutNetworkCalls() {
        let store = makeReadyStore()

        store.login(username: "   ", password: "", mode: .family)
        XCTAssertEqual(store.loginError, "请输入账号和密码")

        store.maxCustomActionsPerElder = 0
        store.addCustomAction(actionKey: " custom ", title: " 自定义 ", icon: "heart.circle.fill", for: PreviewData.momId)
        XCTAssertEqual(store.statusMessage, "订阅后可添加自定义操作")

        store.maxCustomActionsPerElder = 10
        store.addCustomAction(actionKey: "   ", title: " 自定义 ", icon: "heart.circle.fill", for: PreviewData.momId)
        XCTAssertEqual(store.statusMessage, "请填写操作标识和名称")

        store.createAppointment(
            title: " ",
            scheduledAt: Date(),
            hospital: "市医院",
            department: "内分泌科",
            assignedToUserId: nil,
            checklistText: "带记录",
            note: ""
        )
        XCTAssertEqual(store.statusMessage, "请完整填写复查标题、医院、科室和携带清单")
    }

    func testAlreadyCompletedCareActionDoesNotStartSync() {
        let store = makeReadyStore()
        store.snapshot.elders[0].actions[0].completedAt = Date()

        store.complete(actionKey: store.snapshot.elders[0].actions[0].actionKey, for: PreviewData.momId)

        XCTAssertEqual(store.statusMessage, "今天已经记录")
    }

    func testSignOutClearsSessionAndFamilyState() {
        let store = makeReadyStore()
        store.subscriptionTier = "YEARLY"
        store.canQueueOfflineActions = true
        store.syncDelaySeconds = 10
        store.pendingOfflineActionCount = 2
        store.actionHistory = PreviewData.snapshot.feed

        store.signOut()

        XCTAssertEqual(store.phase, .signedOut)
        XCTAssertNil(store.currentUser)
        XCTAssertEqual(store.families.count, 0)
        XCTAssertNil(store.selectedFamily)
        XCTAssertNil(store.selectedElderId)
        XCTAssertEqual(store.subscriptionTier, "FREE")
        XCTAssertFalse(store.canQueueOfflineActions)
        XCTAssertEqual(store.syncDelaySeconds, 0)
        XCTAssertEqual(store.pendingOfflineActionCount, 0)
        XCTAssertTrue(store.actionHistory.isEmpty)
        XCTAssertTrue(store.snapshot.elders.isEmpty)
    }

    func testStoreSubscriptionPlanMetadata() {
        XCTAssertEqual(StoreSubscriptionPlan.monthly.productId, "com.lwj.FamilyPulse.premium.monthly.v2")
        XCTAssertEqual(StoreSubscriptionPlan.yearly.productId, "com.lwj.FamilyPulse.premium.yearly.v2")
        XCTAssertEqual(StoreSubscriptionPlan.monthly.title, "月付")
        XCTAssertEqual(StoreSubscriptionPlan.yearly.title, "年付")
        // fallbackPrice 现在是 locale-aware，随设备地区显示对应货币符号
        XCTAssertFalse(StoreSubscriptionPlan.monthly.fallbackPrice.isEmpty)
        XCTAssertFalse(StoreSubscriptionPlan.yearly.fallbackPrice.isEmpty)
        XCTAssertTrue(StoreSubscriptionPlan.yearly.fallbackPrice.contains("58") || StoreSubscriptionPlan.yearly.fallbackPrice.contains("58.00"))
        // 不应包含硬编码的 ¥
        XCTAssertFalse(StoreSubscriptionPlan.monthly.fallbackPrice.contains("¥6"))
        XCTAssertFalse(StoreSubscriptionPlan.yearly.fallbackPrice.contains("¥58"))
        XCTAssertTrue(StoreSubscriptionPlan.monthly.subtitle.contains("30 秒"))
        XCTAssertTrue(StoreSubscriptionPlan.yearly.subtitle.contains("全部操作历史"))
    }

    private func makeReadyStore() -> FamilyStore {
        let family = ServerFamily(
            id: PreviewData.snapshot.familyId!,
            name: PreviewData.snapshot.familyName,
            inviteCode: PreviewData.snapshot.inviteCode,
            role: "ADMIN"
        )
        let store = FamilyStore()
        store.currentUser = ServerUser(
            id: UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA")!,
            externalId: "password:alice",
            username: "alice",
            displayName: "Alice",
            avatarSymbol: "person.crop.circle.fill",
            avatarColor: "green",
            subscriptionTier: "YEARLY"
        )
        store.families = [family]
        store.selectedFamily = family
        store.snapshot = PreviewData.snapshot
        store.phase = .ready
        store.subscriptionTier = "YEARLY"
        store.maxCustomActionsPerElder = 20
        return store
    }
}
