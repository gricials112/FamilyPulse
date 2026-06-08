import SwiftUI

struct ElderOneTapHomeView: View {
    var store: FamilyStore

    private var elder: ElderStatus? {
        store.selectedElder
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let elder {
                        header(for: elder)
                        actionPanel(for: elder)
                        familyNotice
                        recentFeed
                    } else {
                        emptyState
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
            }
            .refreshable { store.refresh() }
            .navigationTitle("今日照护")
            .navigationBarTitleDisplayMode(.large)
            .task(id: store.autoRefreshIntervalSeconds) { await autoRefreshLoop() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            store.chooseDifferentElder()
                        } label: {
                            Label("切换照护对象", systemImage: "figure.wave")
                        }
                        .disabled(store.snapshot.elders.count <= 1)
                        Button {
                            store.switchMode(.family)
                        } label: {
                            Label("切回家人模式", systemImage: "person.2.fill")
                        }
                    } label: {
                        Label(store.selectedElder?.name ?? "菜单", systemImage: "line.3.horizontal")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("同步家庭数据")
                }
            }
        }
    }

    private func header(for elder: ElderStatus) -> some View {
        let completedCount = elder.actions.filter(\.isCompleted).count
        let isComplete = !elder.actions.isEmpty && completedCount == elder.actions.count

        return GlassCard(cornerRadius: 34) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("你好，\(elder.name)")
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        Text(isComplete ? "今天的状态已经告诉家人了。" : "点一下，家人就会看到。")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusPill(
                        text: "\(completedCount)/\(elder.actions.count)",
                        symbolName: isComplete ? "checkmark.circle.fill" : "clock.fill",
                        tint: isComplete ? FamilyTheme.accent : .orange
                    )
                }

                if !elder.subtitle.isEmpty {
                    Text(elder.subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: elder.actions.isEmpty ? 0 : Double(completedCount), total: Double(max(elder.actions.count, 1)))
                    .tint(FamilyTheme.accent)
            }
        }
    }

    private func actionPanel(for elder: ElderStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            FamilySectionHeader(title: "今天要记录什么？", subtitle: "只需要点一次。误点后可让家人在同步墙撤销。", symbolName: "hand.tap.fill")

            VStack(spacing: 14) {
                ForEach(elder.actions) { action in
                    Button {
                        hapticFeedback(.medium)
                        store.complete(actionKey: action.actionKey, for: elder.id)
                        if elder.actions.allSatisfy({ $0.isCompleted || $0.actionKey == action.actionKey }) {
                            hapticFeedback(.success)
                        }
                    } label: {
                        ElderActionButtonLabel(action: action)
                    }
                    .buttonStyle(ElderActionPressStyle(isCompleted: action.isCompleted))
                    .accessibilityIdentifier("elderAction-\(action.actionKey)")
                    .accessibilityLabel(action.title)
                    .accessibilityHint(action.isCompleted ? "今天已经完成" : "双击记录今天已完成")
                }
            }
        }
    }

    private func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private func hapticFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    private var familyNotice: some View {
        GlassCard(cornerRadius: 26) {
            HStack(spacing: 12) {
                SoftIcon(
                    symbolName: store.isSyncing ? "arrow.triangle.2.circlepath" : "checkmark.icloud.fill",
                    tint: store.isSyncing ? .orange : FamilyTheme.accent,
                    size: 44
                )
                .symbolEffect(.pulse, isActive: store.isSyncing)
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.statusMessage.isEmpty ? "家人会自动看到" : store.statusMessage)
                        .font(.headline)
                    Text(syncNoticeText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private var recentFeed: some View {
        VStack(alignment: .leading, spacing: 12) {
            FamilySectionHeader(title: "家人最近动态", subtitle: nil, symbolName: "person.2.fill")

            if store.snapshot.feed.isEmpty {
                EmptyStateCard(symbolName: "tray", title: "暂无动态", message: "家人登记复查或完成照护后会显示在这里。")
            } else {
                ForEach(store.snapshot.feed.prefix(3)) { item in
                    GlassCard(cornerRadius: 22) {
                        HStack(spacing: 12) {
                            SoftIcon(symbolName: item.symbolName, tint: item.tone.color, size: 40)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.headline)
                                Text(item.subtitle)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    private var syncNoticeText: String {
        let time = store.snapshot.lastUpdatedAt.formatted(date: .omitted, time: .shortened)
        var parts = [String(localized: "最后更新 \(time)")]
        if store.pendingOfflineActionCount > 0 {
            parts.append(String(localized: "待补发 \(store.pendingOfflineActionCount) 条"))
        }
        if let seconds = store.autoRefreshIntervalSeconds {
            parts.append(String(localized: "\(seconds) 秒内同步"))
        }
        return parts.joined(separator: " · ")
    }

    private func autoRefreshLoop() async {
        guard let seconds = store.autoRefreshIntervalSeconds else { return }
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
            if !Task.isCancelled {
                store.refresh(silent: true)
            }
        }
    }

    private var emptyState: some View {
        EmptyStateCard(symbolName: "figure.wave", title: "请选择照护对象", message: "当前家庭还没有选定这台手机对应的老人。")
    }
}

private struct ElderActionButtonLabel: View {
    var action: CareAction

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Image(systemName: action.symbolName)
                    .font(.system(size: 42, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.primary)
                    .frame(width: 58)
                    .opacity(action.isCompleted ? 0 : 1)
                    .scaleEffect(action.isCompleted ? 0.4 : 1)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 46, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(FamilyTheme.accent)
                    .frame(width: 58)
                    .opacity(action.isCompleted ? 1 : 0)
                    .scaleEffect(action.isCompleted ? 1 : 0.4)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(action.title)
                    .font(.title.bold())
                    .foregroundStyle(.primary)
                Text(action.isCompleted ? "已告诉家人 \(action.completedAt?.formatted(date: .omitted, time: .shortened) ?? "")" : "点一下记录给家人")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 122)
        .padding(20)
        .glassSurface(cornerRadius: 32, interactive: true)
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(FamilyTheme.accent.opacity(action.isCompleted ? 0.35 : 0), lineWidth: 1.5)
        )
    }
}

// MARK: - Subscription Promotion - Redesigned Paywall Narrative

struct SubscriptionPromotionView: View {
    var store: FamilyStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var showCelebration = false

    private let accentColor = Color(red: 0.72, green: 0.16, blue: 0.14)
    private let goldColor = Color(red: 0.82, green: 0.64, blue: 0.18)

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                ScrollView {
                    VStack(spacing: 0) {
                        // Spacer matching hero height so content doesn't overlap
                        Color.clear
                            .frame(height: 210)

                        // Intro
                        introSection

                        // Feature list (flowing, no cards)
                        featureList
                            .padding(.top, 8)

                        // Thin Chinese-style divider
                        chineseDivider

                        // Comparison
                        comparisonSection

                        chineseDivider

                        // Plans
                        planCards
                            .padding(.bottom, 8)

                        // Legal links (App Review 3.1.2(c) compliance)
                        PaywallLegalLinksAuto()
                            .padding(.bottom, 4)

                        restoreButton

                        errorText
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)

                // Hero scene floating at the top, extending edge-to-edge
                heroScene
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)

                // Close button overlaid on the image
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .background(
                            Circle()
                                .fill(.regularMaterial)
                                .frame(width: 30, height: 30)
                        )
                }
                .padding(.trailing, 16)
                .padding(.top, 8)

                if showCelebration {
                    celebrationOverlay
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: store.storeManager.purchaseSuccess) { _, success in
                    if success {
                        let jws = store.storeManager.lastTransactionJws
                        let plan = store.storeManager.lastPurchasedPlan
                        store.storeManager.clearLastTransactionJws()
                        store.storeManager.lastPurchasedPlan = nil
                        if let jws {
                            Task {
                                let ok = await store.verifyReceipt(transactionJws: jws, plan: plan)
                                if ok {
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                                        showCelebration = true
                                    }
                                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                                    dismiss()
                                }
                            }
                        }
                    }
                }
        }
    }

    // MARK: - Hero Scene (Curtain draping effect)

    private var heroScene: some View {
        ZStack(alignment: .bottom) {
            // Curtain fabric
            Image("SubscriptionBackground")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipped()

            // Top gathered shadow (where curtain attaches)
            LinearGradient(
                colors: [.black.opacity(0.3), .black.opacity(0.08), .clear],
                startPoint: .top,
                endPoint: .init(x: 0, y: 0.2)
            )

            // Vertical fold pleats
            curtainPleats

            // Bottom drape shadow
            LinearGradient(
                colors: [.clear, .black.opacity(0.1), .clear],
                startPoint: .init(x: 0, y: 0.75),
                endPoint: .bottom
            )

            // Transition to content below
            LinearGradient(
                colors: [.clear, Color(.systemBackground).opacity(0.2), Color(.systemBackground).opacity(0.5), Color(.systemBackground)],
                startPoint: .init(x: 0, y: 0.55),
                endPoint: .bottom
            )
        }
        .frame(height: 210)
        .frame(maxWidth: .infinity)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 24, bottomTrailingRadius: 24))
    }

    private var curtainPleats: some View {
        GeometryReader { geo in
            let count = 7
            let foldW = geo.size.width / CGFloat(count)
            let h = geo.size.height
            ForEach(0..<count, id: \.self) { i in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                .clear,
                                .black.opacity(0.10),
                                .black.opacity(0.20),
                                .black.opacity(0.06),
                                .clear,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: foldW)
                    .position(x: foldW * CGFloat(i) + foldW / 2, y: h / 2)
            }
        }
    }

    // MARK: - Intro Section

    private var introSection: some View {
        VStack(spacing: 6) {
            Text("让关爱不间断")
                .font(.title2.bold())
                .padding(.top, 24)
            Text("解锁更快同步、离线暂存和更多家庭管理")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 20)
    }

    // MARK: - Feature List (flowing, no card)

    private var featureList: some View {
        VStack(spacing: 0) {
            featureItem(icon: "arrow.triangle.2.circlepath", iconColor: .blue, title: "更快同步", description: "从 2 分钟缩短到 10 秒，家人即时看到老人状态")
            featureItem(icon: "wifi.slash", iconColor: .orange, title: "离线暂存", description: "老人手机断网时操作自动暂存，联网后自动补发")
            featureItem(icon: "person.2.fill", iconColor: .green, title: "多家庭管理", description: "同时管理父母、岳父母的健康数据，一个 App 全部覆盖")
        }
    }

    private func featureItem(icon: String, iconColor: Color, title: String, description: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Chinese Divider

    private var chineseDivider: some View {
        HStack(spacing: 12) {
            Color(.separator).opacity(0.15)
                .frame(height: 1)
            Image(systemName: "seal.fill")
                .font(.caption2)
                .foregroundStyle(Color(red: 0.72, green: 0.16, blue: 0.14).opacity(0.3))
            Color(.separator).opacity(0.15)
                .frame(height: 1)
        }
        .padding(.vertical, 20)
    }

    // MARK: - Free vs Premium Comparison

    private var comparisonSection: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "seal.fill")
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.72, green: 0.16, blue: 0.14))
                Text("免费 vs 订阅")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            .padding(.bottom, 12)

            HStack(spacing: 0) {
                // Free side
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.open.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("免费版")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    compRow("2 分钟同步", included: true)
                    compRow("仅限一个家庭", included: false)
                    compRow("无离线暂存", included: false)
                    compRow("10 条历史", included: false)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 120)

                // Premium side
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(.caption)
                            .foregroundStyle(Color(red: 0.82, green: 0.64, blue: 0.18))
                        Text("订阅版")
                            .font(.callout.weight(.medium))
                    }
                    compRow("10 秒同步", included: true)
                    compRow("多家庭管理", included: true)
                    compRow("离线自动补发", included: true)
                    compRow("全部历史", included: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.leading, 12)
            }
        }
    }

    private func compRow(_ text: String, included: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: included ? "checkmark" : "xmark")
                .font(.caption2.weight(.bold))
                .foregroundStyle(included ? Color.green : Color.secondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(included ? .primary : .secondary)
        }
    }

    private func comparisonRow(_ text: String, locked: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: locked ? "xmark" : "checkmark")
                .font(.caption2.weight(.bold))
                .foregroundStyle(locked ? Color.secondary : Color.green)
            Text(text)
                .font(.caption)
                .foregroundStyle(locked ? .secondary : .primary)
            Spacer()
        }
    }

    // MARK: - Plan Cards

    private var planCards: some View {
        HStack(spacing: 12) {
            planCard(.monthly, isRecommended: false)
            planCard(.yearly, isRecommended: true)
        }
    }

    private func planCard(_ plan: StoreSubscriptionPlan, isRecommended: Bool) -> some View {
        Button {
            Task { await store.storeManager.purchase(plan) }
        } label: {
            VStack(spacing: 0) {
                if isRecommended {
                    HStack(spacing: 4) {
                        Image(systemName: "seal.fill")
                            .font(.caption2)
                        Text("最划算")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(accentColor, in: Capsule())
                    .padding(.top, 8)
                } else {
                    Color.clear.frame(height: 26)
                }

                Text(plan.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .padding(.top, isRecommended ? 6 : 12)

                Text(store.storeManager.displayPrice(for: plan))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(accentColor)
                    .padding(.top, 4)

                if plan == .yearly {
                    Text("日均约 \(yearlyPerDayDisplay)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    if store.storeManager.isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                    }
                    Text("订阅")
                        .font(.footnote.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(colors: [accentColor, Color(red: 0.60, green: 0.12, blue: 0.10)], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 10)
                .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground).opacity(colorScheme == .dark ? 0.4 : 0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isRecommended ? goldColor.opacity(0.5) : Color(.separator).opacity(0.15), lineWidth: isRecommended ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(store.storeManager.isLoading)
    }

    private var yearlyPerDayDisplay: String {
        store.storeManager.dailyPriceString(for: .yearly)
    }

    // MARK: - Restore & Error

    private var restoreButton: some View {
        Button {
            Task { await store.storeManager.restorePurchases() }
        } label: {
            Text("恢复购买")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    @ViewBuilder
    private var errorText: some View {
        if let error = store.storeManager.purchaseError {
            Text(error)
                .font(.footnote)
                .foregroundStyle(.red)
        }
    }

    // MARK: - Celebration Overlay

    private var celebrationOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))

                Text("订阅成功")
                    .font(.title.bold())
                    .foregroundStyle(.white)

                HStack(spacing: 12) {
                    ForEach(0..<3) { i in
                        Image(systemName: "sparkle")
                            .font(.title2)
                            .foregroundStyle(.yellow)
                            .phaseAnimator([0.0, 1.0, 0.0]) { content, phase in
                                content
                                    .scaleEffect(phase == 0 ? 0.3 : 1.2)
                                    .opacity(phase == 0 ? 0 : 1)
                                    .rotationEffect(.degrees(phase * 360))
                            } animation: { _ in
                                .spring(response: 0.5, dampingFraction: 0.6).delay(Double(i) * 0.15)
                            }
                    }
                }
            }
        }
        .transition(.opacity)
        .zIndex(100)
    }
}

// MARK: - Feature Scene Card

private struct FeatureSceneCard: View {
    var icon: String
    var iconColor: Color
    var title: String
    var description: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .glassSurface(cornerRadius: 22, interactive: true)
    }
}

// MARK: - Action Press Animation Style

private struct ElderActionPressStyle: ButtonStyle {
    var isCompleted: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}

#Preview {
    let store = FamilyStore()
    store.userMode = .elder
    store.selectedElderId = PreviewData.momId
    store.snapshot = PreviewData.snapshot
    return ElderOneTapHomeView(store: store)
}
