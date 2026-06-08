import AVFoundation
import SwiftUI
import UIKit

struct SettingsView: View {
    var store: FamilyStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var newElderName = ""
    @State private var newElderNotes = ""
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var subscriptionCodeInput = ""

    // Avatar picker state
    @State private var showAvatarPicker = false
    @State private var pendingSymbol = ""
    @State private var pendingColor = ""
    @State private var showLeaveFamilyConfirmation = false
    @State private var showFamilyManagement = false

    // Profile editing state
    @State private var editingProfile = false
    @State private var editedDisplayName = ""
    @State private var editedUsername = ""

    // Password set animation
    @State private var passwordSetSuccess = false

    // QR code state
    @State private var showQRCode = false
    @State private var showQRScanner = false
    @State private var showPushSubscriptionPromotion = false

    // Card flip animation
    @State private var isFlipped = false

    private let avatarSymbols = [
        "person.crop.circle.fill",
        "figure.2.and.child.holdinghands",
        "heart.circle.fill",
        "leaf.circle.fill",
        "house.circle.fill",
        "sun.max.fill",
        "moon.stars.fill",
        "flame.fill",
        "drop.fill",
        "bolt.fill",
        "pawprint.fill",
        "crown.fill",
    ]

    private let avatarColors = ["green", "blue", "orange", "purple", "pink", "red", "teal"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    avatarCard
                    identityCard
                    membersCard
                    addElderCard
                    familyCard
                    premiumCard
                    pushNotificationCard
                    accountSecurityCard
                    privacyCard
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
            }
            .navigationTitle("家庭")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showQRCode = true
                    } label: {
                        Image(systemName: "qrcode")
                    }
                }
            }
            .sheet(isPresented: $showAvatarPicker) { avatarPickerSheet }
            .sheet(isPresented: $showFamilyManagement) { FamilyOnboardingView(store: store) }
            .sheet(isPresented: $showQRCode) {
                QRCodeSheetView(store: store, showScanner: $showQRScanner)
            }
            .sheet(isPresented: $showPushSubscriptionPromotion) {
                SubscriptionPromotionView(store: store)
            }
            .sheet(isPresented: $showQRScanner) {
                QRCodeScannerView { scanned in
                    let code = parseQRCodeUrl(scanned) ?? scanned
                    if code.hasPrefix("FP-") {
                        store.activateSubscriptionCode(code)
                    } else {
                        store.joinFamily(inviteCode: code)
                    }
                    showQRScanner = false
                }
            }
            .task {
                guard !AppRuntime.isRunningUnitTests else { return }
                await store.storeManager.loadProducts()
                // Apple 有活跃订阅但后端是 FREE，自动补发验证
                if let jws = store.storeManager.foundEntitlementJws, store.subscriptionTier == "FREE" {
                    Task { await store.verifyReceipt(transactionJws: jws) }
                }
            }
            .onChange(of: store.storeManager.purchaseSuccess) { _, success in
                if success {
                    let jws = store.storeManager.lastTransactionJws
                    let plan = store.storeManager.lastPurchasedPlan
                    store.storeManager.clearLastTransactionJws()
                    store.storeManager.lastPurchasedPlan = nil
                    if let jws {
                        Task { await store.verifyReceipt(transactionJws: jws, plan: plan) }
                    }
                }
            }
        }
    }

    // MARK: - Avatar Picker Sheet

    private var avatarPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Preview
                    VStack(spacing: 8) {
                        Text("预览")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        AvatarView(symbolName: pendingSymbol.isEmpty ? store.currentUser?.avatarSymbol ?? "person.crop.circle.fill" : pendingSymbol,
                                   colorName: pendingColor.isEmpty ? store.currentUser?.avatarColor ?? "green" : pendingColor,
                                   size: 80)
                    }
                    .padding(.top, 8)

                    // Symbol grid
                    VStack(alignment: .leading, spacing: 10) {
                        Text("选择图标")
                            .font(.headline)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                            ForEach(avatarSymbols, id: \.self) { symbol in
                                Button {
                                    pendingSymbol = symbol
                                } label: {
                                    Image(systemName: symbol)
                                        .font(.title2)
                                        .frame(width: 48, height: 48)
                                        .background(pendingSymbol == symbol ? Color.green.opacity(0.2) : Color.green.opacity(0.06))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Color grid
                    VStack(alignment: .leading, spacing: 10) {
                        Text("选择颜色")
                            .font(.headline)
                        HStack(spacing: 14) {
                            ForEach(avatarColors, id: \.self) { color in
                                Button {
                                    pendingColor = color
                                } label: {
                                    Circle()
                                        .fill(avatarColor(color))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .stroke(pendingColor == color ? Color.primary : Color.clear, lineWidth: 3)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("设置头像")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showAvatarPicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let symbol = pendingSymbol.isEmpty ? (store.currentUser?.avatarSymbol ?? "person.crop.circle.fill") : pendingSymbol
                        let color = pendingColor.isEmpty ? (store.currentUser?.avatarColor ?? "green") : pendingColor
                        store.updateAvatar(symbol: symbol, color: color)
                        showAvatarPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Cards

    // MARK: - Premium Card - Redesigned Subscription Interface

    private var warmCoral: Color {
        Color(red: 1.0, green: 0.45, blue: 0.4)
    }

    private var warmGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 1.0, green: 0.4, blue: 0.38), Color(red: 1.0, green: 0.58, blue: 0.42)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Chinese Ink-Wash Colors (from SubscriptionBackground)

    private var chineseRed: Color {
        Color(red: 0.72, green: 0.16, blue: 0.14)      // 朱红
    }

    private var chineseGold: Color {
        Color(red: 0.82, green: 0.64, blue: 0.18)      // 金色
    }

    private var chineseInk: Color {
        Color(red: 0.15, green: 0.13, blue: 0.12)      // 墨黑
    }

    private var chinesePaper: Color {
        Color(red: 0.96, green: 0.94, blue: 0.90)      // 宣纸白
    }

    private var chineseGradient: LinearGradient {
        LinearGradient(
            colors: [chineseRed, Color(red: 0.60, green: 0.12, blue: 0.10)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func flipCard() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        withAnimation(.spring(response: 0.55, dampingFraction: 0.72, blendDuration: 0.3)) {
            isFlipped.toggle()
        }
    }

    // MARK: - Premium Card (Unsubscribed: simple panel with visible legal links; Subscribed: flip card)

    @ViewBuilder
    private var premiumCard: some View {
        if store.isPremium {
            premiumFlipCard
        } else {
            simpleSubscriptionPanel
        }
    }

    /// Simple subscription panel (no flip) — shows plans, features, and legal links directly visible.
    private var simpleSubscriptionPanel: some View {
        GlassCard(cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("家安 · Premium")
                            .font(.title2.bold())
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [chineseGold, chineseRed],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        Text("更快同步 · Push 提醒 · 全部历史")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusPill(
                        text: "免费版",
                        symbolName: "crown.fill",
                        tint: .secondary
                    )
                }
                .padding(.bottom, 16)

                // Plan cards
                planCardsSection
                    .padding(.bottom, 8)

                // All features
                allFeaturesList
                    .padding(.bottom, 8)

                // Activation input
                activationInputContent
                    .padding(.bottom, 8)

                // Legal links — directly visible, never hidden behind a flip
                PaywallLegalLinksAuto()
                    .padding(.bottom, 4)

                // Footer
                Text("自动续费，随时可在 App Store 取消。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)

                if let error = store.storeManager.purchaseError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.top, 4)
                }

                // Chinese seal decoration
                HStack(spacing: 16) {
                    chineseRed.opacity(0.3)
                        .frame(height: 1)
                        .frame(maxWidth: 40)
                    Image(systemName: "seal.fill")
                        .font(.caption2)
                        .foregroundStyle(chineseRed.opacity(0.35))
                    chineseRed.opacity(0.3)
                        .frame(height: 1)
                        .frame(maxWidth: 40)
                }
                .padding(.top, 8)

                // Debug
                debugSection
            }
        }
    }

    /// Subscription flip card — only shown after subscription.
    private var premiumFlipCard: some View {
        ZStack {
            frontCardSide
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
                .opacity(isFlipped ? 0 : 1)

            backCardSide
                .rotation3DEffect(.degrees(isFlipped ? 360 : 180), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
                .opacity(isFlipped ? 1 : 0)
        }
        .frame(height: 500)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 22, y: isFlipped ? 6 : 12)
    }

    // MARK: - Card Front (Image + Subscription Info)

    private var frontCardSide: some View {
        ZStack(alignment: .bottom) {
            // Full card image background
            Image("SubscriptionBackground")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipped()

            // Overlay for text readability
            LinearGradient(
                colors: [
                    .clear,
                    .clear,
                    Color(.systemBackground).opacity(0.5),
                    Color(.systemBackground).opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                // Top status
                HStack {
                    Spacer()
                    StatusPill(
                        text: store.isPremium ? "已订阅" : "免费版",
                        symbolName: store.isPremium ? "checkmark.seal.fill" : "crown.fill",
                        tint: store.isPremium ? chineseGold : .secondary
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer(minLength: 0)

                // Center content
                VStack(spacing: 12) {
                    Text("家安 · Premium")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [chineseGold, chineseRed],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("更快同步 · Push 提醒 · 全部历史")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let expires = store.subscriptionExpiresAt {
                        Text("有效至 \(expires.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 2)
                    }
                }

                Spacer(minLength: 0)

                // Flip hint
                HStack(spacing: 5) {
                    Image(systemName: "arrow.2.squarepath")
                        .font(.caption2)
                    Text("翻转查看权益")
                        .font(.caption)
                }
                .foregroundStyle(.tertiary.opacity(0.8))
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { flipCard() }
    }

    private func subscriptionPricePill(price: String, period: String, highlighted: Bool = false) -> some View {
        HStack(spacing: 2) {
            Text(price)
                .font(.title3.weight(.bold))
            Text(period)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .foregroundStyle(highlighted ? chineseGold : .primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground).opacity(highlighted ? 0.18 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(highlighted ? chineseGold.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - Card Back (Benefits + Action)

    private var backCardSide: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Back header
            HStack {
                Image(systemName: "seal.fill")
                    .foregroundStyle(chineseRed)
                    .font(.subheadline)
                Text("全部权益")
                    .font(.headline.weight(.semibold))
                Spacer()
                Button {
                    flipCard()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.2.squarepath")
                            .font(.caption2)
                        Text("翻回正面")
                            .font(.caption)
                    }
                    .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Divider()
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            // Scrollable content
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    premiumActiveContent
                    debugSection
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    // MARK: - Premium Active State

    private var premiumActiveContent: some View {
        VStack(spacing: 12) {
            featureRow(icon: "arrow.triangle.2.circlepath", text: "同步间隔 \(store.syncDelaySeconds) 秒", unlocked: true)
            featureRow(icon: "wifi.slash", text: "离线操作自动补发", unlocked: store.canQueueOfflineActions)
            featureRow(icon: "bell.badge.fill", text: "家庭 Push 通知提醒", unlocked: store.canUsePushNotifications)
            featureRow(icon: "clock.arrow.circlepath", text: store.historyRetentionDays < 0 ? "全部操作历史" : "\(store.historyRetentionDays) 天操作历史", unlocked: true)
            featureRow(icon: "plus.square.on.square", text: "每个老人最多 \(store.maxCustomActionsPerElder) 个自定义操作", unlocked: true)
            featureRow(icon: "person.2.fill", text: "多个家庭", unlocked: true)
            if store.activationDeviceLimit > 0 {
                featureRow(icon: "qrcode", text: "订阅码设备 \(store.activationUsedCount)/\(store.activationDeviceLimit)", unlocked: true)
            }
            activationCodeContent
        }
        .padding(.top, 4)
    }

    // MARK: - Plan Cards

    private var planCardsSection: some View {
        HStack(spacing: 12) {
            planCard(.monthly)
            planCard(.yearly, isRecommended: true)
        }
    }

    private func planCard(_ plan: StoreSubscriptionPlan, isRecommended: Bool = false) -> some View {
        Button {
            Task { await store.storeManager.purchase(plan) }
        } label: {
            VStack(spacing: 0) {
                // Badge space (or "最受欢迎" tag)
                if isRecommended {
                    HStack(spacing: 4) {
                        Image(systemName: "seal.fill")
                            .font(.caption2)
                        Text("最受欢迎")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(chineseRed, in: Capsule())
                    .padding(.top, 8)
                } else {
                    Color.clear.frame(height: 26)
                }

                // Plan name
                Text(plan.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .padding(.top, isRecommended ? 6 : 12)

                // Price with region-specific display from StoreKit
                VStack(spacing: 1) {
                    Text(store.storeManager.displayPrice(for: plan))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(chineseRed)
                    if plan == .yearly {
                        Text("日均约 \(yearlyPerDayDisplay)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)

                Spacer(minLength: 0)

                // Feature list
                VStack(spacing: 5) {
                    planFeatureRow(icon: "arrow.triangle.2.circlepath", text: plan == .yearly ? "10 秒同步" : "30 秒同步")
                    planFeatureRow(icon: "bell.badge.fill", text: "Push 提醒")
                    planFeatureRow(icon: "clock.arrow.circlepath", text: plan == .yearly ? "全部历史" : "7 天历史")
                    planFeatureRow(icon: "plus.square.on.square", text: plan == .yearly ? "20 个自定义" : "4 个自定义")
                    planFeatureRow(icon: "qrcode", text: plan == .yearly ? "订阅码 4 台" : "订阅码 2 台")
                }
                .padding(.vertical, 10)

                // Subscribe button
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
                .background(chineseGradient)
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
                    .stroke(isRecommended ? chineseGold.opacity(0.5) : Color(.separator).opacity(0.15), lineWidth: isRecommended ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(store.storeManager.isLoading)
    }

    /// Show per-day cost for yearly plan
    private var yearlyPerDayDisplay: String {
        store.storeManager.dailyPriceString(for: .yearly)
    }

    private func planFeatureRow(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - All Features

    private var allFeaturesList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "seal.fill")
                    .foregroundStyle(chineseRed)
                    .font(.subheadline)
                Text("订阅权益")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            featureRow(icon: "wifi.slash", text: "断网自动暂存操作，联网后补发", unlocked: true)
            featureRow(icon: "bell.badge.fill", text: "家庭照护记录和复查新增 Push 提醒", unlocked: true)
            featureRow(icon: "person.2.fill", text: "支持管理多个家庭", unlocked: true)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(chineseRed.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Activation Code (shown when subscribed)

    private var activationCodeContent: some View {
        Group {
            if let code = store.subscriptionActivationCode, !code.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    Text("订阅码")
                        .font(.headline)
                    Text("其他端或其他设备可在有效期内输入此码激活；到期后通过此码激活的设备也会同步过期。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Text(code)
                            .font(.title3.monospacedDigit().weight(.bold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(chineseRed.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                        Button {
                            UIPasteboard.general.string = code
                            store.statusMessage = String(localized: "订阅码已复制")
                        } label: {
                            Image(systemName: "doc.on.doc.fill")
                        }
                        .buttonStyle(.bordered)
                        .tint(chineseGold)
                    }
                }
            }
        }
    }

    // MARK: - Activation Code Input

    private var activationInputContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            Text("已有订阅码？")
                .font(.headline)
            TextField("FP-XXXX-XXXX", text: $subscriptionCodeInput)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding()
                .glassSurface(cornerRadius: 18, interactive: true)
            Button {
                store.activateSubscriptionCode(subscriptionCodeInput)
                subscriptionCodeInput = ""
            } label: {
                Label("激活订阅码", systemImage: "qrcode.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(chineseRed)
            .disabled(store.isSyncing)
        }
    }

    // MARK: - Footer

    private var subscriptionFooter: some View {
        VStack(spacing: 10) {
            Text("自动续费，随时可在 App Store 取消。")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            // Legal links (App Review 3.1.2(c) compliance)
            PaywallLegalLinksAuto()

            if let error = store.storeManager.purchaseError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            // Chinese seal/stamp decoration
            HStack(spacing: 16) {
                chineseRed.opacity(0.3)
                    .frame(height: 1)
                    .frame(maxWidth: 40)
                Image(systemName: "seal.fill")
                    .font(.caption2)
                    .foregroundStyle(chineseRed.opacity(0.35))
                chineseRed.opacity(0.3)
                    .frame(height: 1)
                    .frame(maxWidth: 40)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Debug

    private var debugSection: some View {
        #if DEBUG
        Group {
            if !store.storeManager.isLoading {
                Divider()
                VStack(spacing: 6) {
                    Text("开发模式")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Button { store.debugActivatePremium() } label: {
                            Label("月付", systemImage: "hammer.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .tint(chineseRed)
                        Button { store.debugActivateYearly() } label: {
                            Label("年付", systemImage: "hammer.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .tint(chineseGold)
                        Button(role: .destructive) { store.debugActivateFree() } label: {
                            Label("免费", systemImage: "xmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
            }
        }
        #else
        EmptyView()
        #endif
    }

    private func featureRow(icon: String, text: String, unlocked: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: unlocked ? "checkmark.circle.fill" : "lock.fill")
                .foregroundStyle(unlocked ? chineseRed : .secondary)
                .font(.callout)
                .frame(width: 20)
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(unlocked ? .primary : .secondary)
            Spacer()
        }
    }

    private var pushNotificationCard: some View {
        let unlocked = store.isPremium && store.canUsePushNotifications
        return GlassCard(cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    SoftIcon(symbolName: "bell.badge.fill", tint: unlocked ? warmCoral : .secondary, size: 50)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Push 通知")
                            .font(.title3.bold())
                        Text("照护记录和复查新增后，订阅家庭成员会收到提醒")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusPill(
                        text: store.pushNotificationsEnabled ? "已开启" : (unlocked ? "可开启" : "订阅功能"),
                        symbolName: store.pushNotificationsEnabled ? "bell.fill" : (unlocked ? "bell" : "lock.fill"),
                        tint: store.pushNotificationsEnabled ? .green : (unlocked ? warmCoral : .secondary)
                    )
                }

                VStack(alignment: .leading, spacing: 9) {
                    Label("家人完成照护打卡时提醒其他订阅成员", systemImage: "checklist.checked")
                    Label("新增复查安排时提醒家庭成员", systemImage: "calendar.badge.clock")
                    Label("免费用户仍可使用 App 内同步，Push 为订阅权益", systemImage: "crown.fill")
                }
                .font(.callout)
                .foregroundStyle(.secondary)

                if !store.pushStatusMessage.isEmpty {
                    Text(store.pushStatusMessage)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(store.pushNotificationsEnabled ? .green : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14))
                }

                if unlocked {
                    Button {
                        if store.pushNotificationsEnabled {
                            store.disablePushNotifications()
                        } else {
                            store.enablePushNotifications()
                        }
                    } label: {
                        Label(
                            store.pushNotificationsEnabled ? "关闭 Push 通知" : "开启 Push 通知",
                            systemImage: store.pushNotificationsEnabled ? "bell.slash.fill" : "bell.badge.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(store.pushNotificationsEnabled ? .secondary : warmCoral)
                } else {
                    Button {
                        showPushSubscriptionPromotion = true
                    } label: {
                        Label("订阅后开启 Push 通知", systemImage: "lock.open.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(warmCoral)
                }
            }
        }
    }

    private var familyCard: some View {
        GlassCard(cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.snapshot.familyName)
                            .font(.title2.bold())
                        Text("邀请码 \(store.snapshot.inviteCode)")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "person.2.badge.gearshape.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.green)
                }

                // Family switch list
                if store.families.count > 1 {
                    Divider()
                    Text("切换家庭")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(store.families) { family in
                        Button {
                            store.selectFamily(family)
                        } label: {
                            HStack {
                                Text(family.name)
                                    .foregroundStyle(store.selectedFamily?.id == family.id ? .green : .primary)
                                Spacer()
                                if store.selectedFamily?.id == family.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Create / Join family
                Divider()
                if store.isPremium || store.families.count <= 1 {
                    HStack(spacing: 12) {
                        Button {
                            showFamilyManagement = true
                        } label: {
                            Label("管理家庭", systemImage: "person.2.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                } else {
                    Button {
                        store.statusMessage = String(localized: "升级 Premium 可管理更多家庭")
                    } label: {
                        Label("升级 Premium 管理多个家庭", systemImage: "lock.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .foregroundStyle(.secondary)
                }

                HStack {
                    Label(store.statusMessage.isEmpty ? "数据已同步" : store.statusMessage, systemImage: store.isSyncing ? "arrow.triangle.2.circlepath" : "checkmark.icloud.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("同步") {
                        store.refresh()
                    }
                    .font(.callout.weight(.semibold))
                }

                Button(role: .destructive) {
                    showLeaveFamilyConfirmation = true
                } label: {
                    Label("退出当前家庭", systemImage: "door.right.hand.open")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .alert("退出家庭", isPresented: $showLeaveFamilyConfirmation) {
                    Button("退出", role: .destructive) { store.leaveFamily() }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("退出后需要重新通过邀请码加入此家庭。确定要退出「\(store.snapshot.familyName)」吗？")
                }
                .alert("提示", isPresented: Binding(
                    get: { store.familyError != nil },
                    set: { if !$0 { store.familyError = nil } }
                )) {
                    Button("确定", role: .cancel) {}
                } message: {
                    Text(store.familyError ?? "")
                }

                Button(role: .destructive) {
                    store.signOut()
                } label: {
                    Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var avatarCard: some View {
        GlassCard(cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                Text("个人资料")
                    .font(.title3.bold())

                HStack(spacing: 16) {
                    if let user = store.currentUser {
                        AvatarView(symbolName: user.avatarSymbol ?? "person.crop.circle.fill",
                                   colorName: user.avatarColor ?? "green",
                                   size: 64)
                        VStack(alignment: .leading, spacing: 6) {
                            if editingProfile {
                                TextField("显示名称", text: $editedDisplayName)
                                    .font(.headline)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                TextField("用户名", text: $editedUsername)
                                    .font(.footnote)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                HStack(spacing: 6) {
                                    Spacer()
                                    Button("取消") {
                                        editingProfile = false
                                        withAnimation(nil) {
                                            editedDisplayName = user.displayName
                                            editedUsername = user.username ?? ""
                                        }
                                    }
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    Button("保存") {
                                        if editedDisplayName.trimmingCharacters(in: .whitespaces) != user.displayName {
                                            store.updateDisplayName(editedDisplayName)
                                        }
                                        if editedUsername.trimmingCharacters(in: .whitespaces) != (user.username ?? "") {
                                            store.updateUsername(editedUsername)
                                        }
                                        editingProfile = false
                                    }
                                    .font(.callout.weight(.semibold))
                                    .disabled(store.isSyncing)
                                }
                            } else {
                                Text(user.displayName)
                                    .font(.headline)
                                Button {
                                    editedDisplayName = user.displayName
                                    editedUsername = user.username ?? ""
                                    editingProfile = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(user.username ?? "")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                        Image(systemName: "pencil")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Spacer()
                }

                Button {
                    pendingSymbol = store.currentUser?.avatarSymbol ?? "person.crop.circle.fill"
                    pendingColor = store.currentUser?.avatarColor ?? "green"
                    showAvatarPicker = true
                } label: {
                    Label("更换头像", systemImage: "photo.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    private var accountSecurityCard: some View {
        GlassCard(cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("账号安全")
                            .font(.title3.bold())
                        Text(accountSecuritySubtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if store.currentUser?.needsRecoverySetup == true {
                        StatusPill(text: "需完善", symbolName: "exclamationmark.triangle.fill", tint: .orange)
                    } else {
                        StatusPill(text: "可找回", symbolName: "checkmark.seal.fill", tint: .green)
                    }
                }

                if let user = store.currentUser {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("自动账号")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(user.username ?? user.externalId)
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))

                    passwordSetupContent(user: user)
                    if AppConfiguration.isWeChatEnabled {
                        weChatBindingContent(user: user)
                    }
                }
            }
        }
    }

    private var accountSecuritySubtitle: String {
        if AppConfiguration.isWeChatEnabled {
            if store.currentUser?.needsRecoverySetup == true {
                return String(localized: "当前游客账号还没有密码，也未绑定微信。建议至少完成其中一项。")
            }
            return String(localized: "已设置密码或绑定微信，后续可用对应方式继续登录。")
        } else {
            if store.currentUser?.hasPassword == false {
                return String(localized: "当前游客账号还没有密码。建议设置一个密码。")
            }
            return String(localized: "已设置密码，后续可用密码继续登录。")
        }
    }

    private func passwordSetupContent(user: ServerUser) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(user.hasPassword == true ? "已设置密码" : "设置登录密码", systemImage: "lock.fill")
                    .font(.headline)
                Spacer()
                if user.hasPassword == true {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                }
            }

            VStack(spacing: 10) {
                if user.hasPassword == true {
                    SecureField("当前密码", text: $currentPassword)
                        .padding(14)
                        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                }
                SecureField("新密码（至少 8 位）", text: $newPassword)
                    .padding(14)
                    .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                SecureField("再次输入新密码", text: $confirmPassword)
                    .padding(14)
                    .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            }

            Button {
                store.setAccountPassword(
                    currentPassword: user.hasPassword == true ? currentPassword : nil,
                    newPassword: newPassword,
                    confirmPassword: confirmPassword
                )
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    passwordSetSuccess = true
                }
                currentPassword = ""
                newPassword = ""
                confirmPassword = ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        passwordSetSuccess = false
                    }
                }
            } label: {
                Label(user.hasPassword == true ? "修改密码" : "设置密码", systemImage: "key.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(store.isSyncing)
            .overlay {
                if passwordSetSuccess {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.green)
                        .overlay {
                            Image(systemName: "checkmark")
                                .font(.title.weight(.bold))
                                .foregroundStyle(.white)
                                .transition(.scale.combined(with: .opacity))
                        }
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func weChatBindingContent(user: ServerUser) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(user.hasWeChatBinding == true ? "已绑定微信" : "绑定微信", systemImage: "message.fill")
                    .font(.headline)
                Spacer()
                if user.hasWeChatBinding == true {
                    StatusPill(text: "已绑定", symbolName: "checkmark.circle.fill", tint: .green)
                }
            }

            if user.hasWeChatBinding == true {
                Text("后续可在登录页直接使用微信登录此账号。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    performWeChatBinding()
                } label: {
                    Label("绑定微信", systemImage: "message.badge.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.green)
                .disabled(store.isSyncing)
            }
        }
    }
    @MainActor
    private func performWeChatBinding() {
        guard !store.isSyncing else { return }
        Task {
            do {
                let code = try await WeChatService.shared.sendAuthRequest()
                store.bindWeChat(code: code)
            } catch WeChatLoginError.notInstalled {
                store.statusMessage = String(localized: "微信未安装，请先安装微信")
            } catch WeChatLoginError.authCancelled {
                store.statusMessage = String(localized: "微信授权已取消")
            } catch WeChatLoginError.sdkNotAvailable {
                store.statusMessage = String(localized: "微信 SDK 未集成")
            } catch {
                store.statusMessage = error.localizedDescription
            }
        }
    }

    private var identityCard: some View {
        GlassCard(cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                Text("当前身份")
                    .font(.title3.bold())

                HStack(spacing: 12) {
                    Image(systemName: store.userMode.symbolName)
                        .font(.title3)
                        .foregroundStyle(.green)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.userMode.title)
                            .font(.headline)
                        Text(store.userMode.subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                Button {
                    store.switchMode(store.userMode == .family ? .elder : .family)
                } label: {
                    Label(store.userMode == .family ? "切换到老人模式" : "切换到家人模式", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    private var membersCard: some View {
        GlassCard(cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                Text("家庭成员")
                    .font(.title3.bold())

                ForEach(store.snapshot.members) { member in
                    HStack(spacing: 12) {
                        AvatarView(symbolName: member.avatarSymbol, colorName: member.avatarColor, size: 42)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(member.displayName)
                                .font(.headline)
                            Text(roleTitle(member.role))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if member.id == store.currentUser?.id {
                            StatusPill(text: "当前", symbolName: "checkmark.circle.fill", tint: .green)
                        }
                    }
                }
            }
        }
    }

    private var addElderCard: some View {
        GlassCard(cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                Text("照护对象")
                    .font(.title3.bold())

                if !store.snapshot.elders.isEmpty {
                    ForEach(store.snapshot.elders) { elder in
                        elderRow(elder)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    store.deleteElder(elder.id)
                                } label: {
                                    Label("删除", systemImage: "trash.fill")
                                }
                            }
                    }
                    Divider()
                }

                Text("添加新照护对象")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("老人姓名", text: $newElderName)
                    .padding()
                    .glassSurface(cornerRadius: 18, interactive: true)
                TextField("慢病或备注（可选）", text: $newElderNotes)
                    .padding()
                    .glassSurface(cornerRadius: 18, interactive: true)
                Button {
                    store.addElder(name: newElderName, notes: newElderNotes.isEmpty ? nil : newElderNotes)
                    newElderName = ""
                    newElderNotes = ""
                } label: {
                    Label("添加", systemImage: "figure.2.and.child.holdinghands")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.green)
            }
        }
    }

    private var privacyCard: some View {
        GlassCard(cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    SoftIcon(symbolName: "lock.shield.fill", tint: .blue, size: 46)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("隐私与医疗边界")
                            .font(.title3.bold())
                        Text("给审核和用户都看得懂的安全承诺")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label("仅家庭成员可查看同一家庭内的记录", systemImage: "person.2.fill")
                    Label("不采集病历、处方、化验单或影像资料", systemImage: "doc.badge.ellipsis")
                    Label("不提供诊断、治疗、用药剂量或异常判断", systemImage: "cross.case.fill")
                    Label("订阅与登录均可通过系统能力恢复和管理", systemImage: "checkmark.seal.fill")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func roleTitle(_ role: String) -> String {
        switch role {
        case "ADMIN": String(localized: "管理员")
        case "ELDER": String(localized: "老人")
        default: String(localized: "照护成员")
        }
    }

    private func avatarColor(_ name: String) -> Color {
        switch name {
        case "green": .green
        case "blue": .blue
        case "orange": .orange
        case "purple": .purple
        case "pink": .pink
        case "red": .red
        case "teal": .teal
        default: .green
        }
    }

    private func elderRow(_ elder: ElderStatus) -> some View {
        HStack(spacing: 12) {
            SoftIcon(symbolName: "figure.wave", tint: FamilyTheme.accent, size: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(elder.name)
                    .font(.headline)
                Text(elder.subtitle.isEmpty ? "无备注" : elder.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.left")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(12)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - QR Code Sheet

struct QRCodeSheetView: View {
    var store: FamilyStore
    @Binding var showScanner: Bool
    @Environment(\.dismiss) private var dismiss

    private var subscriptionCode: String? {
        store.subscriptionActivationCode
    }

    private var inviteCode: String {
        store.snapshot.inviteCode
    }

    private var qrPages: [(title: String, code: String, description: String)] {
        var pages: [(String, String, String)] = []
        if !inviteCode.isEmpty {
            pages.append(("家庭邀请码", inviteCode, "扫描此码可加入家庭"))
        }
        if let code = subscriptionCode, !code.isEmpty {
            pages.append(("订阅激活码", code, "扫描此码可激活订阅"))
        }
        return pages
    }

    @State private var selectedQRPage = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if qrPages.count > 1 {
                    Picker("二维码类型", selection: $selectedQRPage) {
                        ForEach(Array(qrPages.enumerated()), id: \.offset) { index, page in
                            Text(page.title).tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                }

                Spacer(minLength: 0)

                if qrPages.indices.contains(selectedQRPage) {
                    let page = qrPages[selectedQRPage]
                    qrSection(title: page.title, code: page.code, description: page.description)
                } else if let page = qrPages.first {
                    qrSection(title: page.title, code: page.code, description: page.description)
                }

                Spacer(minLength: 0)

                Button {
                    showScanner = true
                    dismiss()
                } label: {
                    Label("扫描二维码", systemImage: "qrcode.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationTitle("二维码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.68)])
    }

    private func qrSection(title: String, code: String, description: String) -> some View {
        let url = qrCodeUrl(for: code)
        return VStack(spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            Image(uiImage: generateQRCode(from: url))
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .padding(12)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))

            Text(code)
                .font(.subheadline.monospacedDigit().weight(.bold))

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.caption2)
                Text(description)
                    .font(.caption2)
            }
            .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: 280)
        .background(Color.green.opacity(0.04), in: RoundedRectangle(cornerRadius: 24))
    }

    /// 生成可跨平台跳转的二维码 URL
    private func qrCodeUrl(for code: String) -> String {
        let base = "https://jiaan.online/qr"
        if code.hasPrefix("FP-") {
            return "\(base)?t=sub&c=\(code)"
        }
        return "\(base)?t=join&c=\(code)"
    }

    private func generateQRCode(from string: String) -> UIImage {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            return UIImage(systemName: "xmark.circle") ?? UIImage()
        }
        let data = string.data(using: .utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else {
            return UIImage(systemName: "xmark.circle") ?? UIImage()
        }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaled = output.transformed(by: transform)
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
            return UIImage(systemName: "xmark.circle") ?? UIImage()
        }
        return UIImage(cgImage: cgImage)
    }
}

/// 解析二维码 URL，提取其中的 code 参数
/// 格式: https://jiaan.online/qr?t=sub&c=FP-XXXX-XXXX 或 ?t=join&c=CODE
func parseQRCodeUrl(_ url: String) -> String? {
    guard let components = URLComponents(string: url),
          components.host == "jiaan.online",
          components.path == "/qr" else { return nil }
    return components.queryItems?.first(where: { $0.name == "c" })?.value
}

// MARK: - QR Code Scanner

struct QRCodeScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerController {
        let controller = ScannerController()
        controller.onScan = onScan
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerController, context: Context) {}
}

final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    private let sessionQueue = DispatchQueue(label: "scan.session.queue")
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let label = UILabel()
        label.text = "需要相机权限才能扫描二维码\n请在 设置 → 隐私 → 相机 中开启"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),
        ])

        checkPermission()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.sync { [weak self] in
            self?.captureSession?.stopRunning()
            self?.captureSession = nil
        }
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
    }

    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            sessionQueue.async { [weak self] in self?.setupSession() }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.sessionQueue.async { [weak self] in self?.setupSession() }
                }
            }
        default:
            break
        }
    }

    private func setupSession() {
        let session = AVCaptureSession()
        session.beginConfiguration()

        guard let captureDevice = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: captureDevice),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            return
        }
        session.addOutput(output)

        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        if output.availableMetadataObjectTypes.contains(.qr) {
            output.metadataObjectTypes = [.qr]
        }

        session.commitConfiguration()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.frame = self.view.bounds
            preview.videoGravity = .resizeAspectFill
            self.view.layer.addSublayer(preview)
            self.previewLayer = preview
        }

        captureSession = session
        session.startRunning()
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = object.stringValue else { return }
        onScan?(code)
    }
}

// MARK: - Add Custom Action Sheet
