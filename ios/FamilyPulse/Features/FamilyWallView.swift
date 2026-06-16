import SwiftUI

struct FamilyWallView: View {
    var store: FamilyStore

    private var totalActionCount: Int {
        store.snapshot.elders.reduce(0) { $0 + $1.actions.count }
    }

    private var completedActionCount: Int {
        store.snapshot.elders.reduce(0) { partial, elder in
            partial + elder.actions.filter(\.isCompleted).count
        }
    }

    private var nextAppointment: Appointment? {
        store.snapshot.appointments
            .filter { $0.status == .planned }
            .sorted { $0.scheduledAt < $1.scheduledAt }
            .first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    todayHero
                    elderFilter

                    if store.visibleElders.isEmpty {
                        EmptyStateCard(
                            symbolName: "figure.2.and.child.holdinghands",
                            title: "还没有照护对象",
                            message: "在家庭页添加妈妈、爸爸或其他需要同步照护的人。"
                        )
                    } else {
                        ForEach(store.visibleElders) { elder in
                            ElderTodayCard(elder: elder, store: store)
                        }
                    }

                    syncStateCard
                    historicalSyncWall
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
            }
            .refreshable { store.refresh() }
            .navigationTitle("今日")
            .navigationBarTitleDisplayMode(.large)
            .task {
                guard !AppRuntime.isRunningUnitTests else { return }
                store.loadActionHistory(date: store.isPremium ? store.selectedHistoryDate : nil)
            }
            .task(id: store.autoRefreshIntervalSeconds) {
                guard !AppRuntime.isRunningUnitTests else { return }
                await autoRefreshLoop()
            }
            .onChange(of: store.selectedHistoryDate) { _, date in
                guard store.isPremium else { return }
                store.loadActionHistory(date: date)
            }
            .toolbar {
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

    private var todayHero: some View {
        GlassCard(cornerRadius: 34) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.snapshot.familyName.isEmpty ? "今日安心" : store.snapshot.familyName)
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        Text(Date.now.formatted(.dateTime.month().day().weekday(.wide)))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusPill(
                        text: completedActionCount == totalActionCount && totalActionCount > 0 ? "已安心" : "\(completedActionCount)/\(max(totalActionCount, 1))",
                        symbolName: completedActionCount == totalActionCount && totalActionCount > 0 ? "checkmark.circle.fill" : "clock.fill",
                        tint: completedActionCount == totalActionCount && totalActionCount > 0 ? FamilyTheme.accent : .orange
                    )
                }

                ProgressView(value: totalActionCount == 0 ? 0 : Double(completedActionCount), total: Double(max(totalActionCount, 1)))
                    .tint(FamilyTheme.accent)
                    .accessibilityLabel("今日完成进度")
                    .accessibilityValue("\(completedActionCount) 项已完成，共 \(totalActionCount) 项")

                HStack(spacing: 12) {
                    TodayMetric(title: "照护对象", value: "\(store.snapshot.elders.count)", symbolName: "figure.2.and.child.holdinghands", tint: FamilyTheme.accent)
                    TodayMetric(title: "今日完成", value: "\(completedActionCount)", symbolName: "checkmark.circle.fill", tint: .green)
                    TodayMetric(title: "待同步", value: "\(store.pendingOfflineActionCount)", symbolName: "wifi.slash", tint: store.pendingOfflineActionCount > 0 ? .orange : .secondary)
                }

                if let nextAppointment {
                    Divider()
                    HStack(spacing: 12) {
                        SoftIcon(symbolName: "calendar.badge.clock", tint: .blue, size: 44)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("下次复查")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text("\(nextAppointment.elderName) · \(nextAppointment.title)")
                                .font(.headline)
                            Text(nextAppointment.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private var elderFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                filterChip(title: "全部", isSelected: store.selectedElderId == nil) {
                    store.selectedElderId = nil
                }

                ForEach(store.snapshot.elders) { elder in
                    filterChip(title: elder.name, isSelected: store.selectedElderId == elder.id) {
                        store.selectedElderId = elder.id
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    isSelected ? FamilyTheme.accent : Color.primary.opacity(0.06),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    private var syncStateCard: some View {
        GlassCard(cornerRadius: 24) {
            HStack(spacing: 12) {
                SoftIcon(
                    symbolName: store.isSyncing ? "arrow.triangle.2.circlepath" : "checkmark.icloud.fill",
                    tint: store.isSyncing ? .orange : FamilyTheme.accent,
                    size: 42
                )
                .symbolEffect(.pulse, isActive: store.isSyncing)

                VStack(alignment: .leading, spacing: 4) {
                    Text(store.statusMessage.isEmpty ? "家庭数据已同步" : store.statusMessage)
                        .font(.headline)
                    Text(syncSubtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("撤销") {
                    store.undoLastAction()
                }
                .font(.callout.weight(.semibold))
                .buttonStyle(.borderless)
                .accessibilityLabel("撤销最近一次照护记录")
            }
        }
    }

    private var syncSubtitle: String {
        let time = store.snapshot.lastUpdatedAt.formatted(date: .omitted, time: .shortened)
        var parts = [String(localized: "最后更新 \(time)")]
        if let seconds = store.autoRefreshIntervalSeconds {
            parts.append(String(localized: "\(seconds) 秒内同步"))
        }
        if store.pendingOfflineActionCount > 0 {
            parts.append(String(localized: "待补发 \(store.pendingOfflineActionCount)"))
        }
        return parts.joined(separator: " · ")
    }

    private var historicalSyncWall: some View {
        VStack(alignment: .leading, spacing: 12) {
            FamilySectionHeader(title: "家庭动态", subtitle: syncWallPolicyText, symbolName: "list.bullet.rectangle")

            if store.isPremium {
                DatePicker(
                    "查看日期",
                    selection: Binding(
                        get: { store.selectedHistoryDate },
                        set: { store.selectedHistoryDate = $0 }
                    ),
                    in: syncWallDateRange,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .padding()
                .glassSurface(cornerRadius: 18, interactive: true)
            }

            if store.isLoadingActionHistory {
                GlassCard(cornerRadius: 22) {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("正在加载")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if store.actionHistory.isEmpty {
                EmptyStateCard(symbolName: "tray", title: "暂无动态", message: "完成照护记录或登记复查后，家人会在这里看到。")
            } else {
                ForEach(store.actionHistory.prefix(store.historyDailyLimit)) { item in
                    ActivityTimelineRow(item: item)
                }
            }
        }
    }

    private var syncWallPolicyText: String {
        switch store.subscriptionTier {
        case "YEARLY":
            String(localized: "年付可按日期查看全部历史，每天最多 10 条")
        case "MONTHLY", "PREMIUM":
            String(localized: "月付可查看最近 7 天，每天最多 10 条")
        default:
            String(localized: "免费版显示最近 10 条，不支持按日期查看")
        }
    }

    private var syncWallDateRange: ClosedRange<Date> {
        let now = Date()
        guard store.historyRetentionDays > 0 else {
            let start = Calendar.current.date(from: DateComponents(year: 2020, month: 1, day: 1)) ?? now
            return start...now
        }
        let start = Calendar.current.date(byAdding: .day, value: -(store.historyRetentionDays - 1), to: Calendar.current.startOfDay(for: now)) ?? now
        return start...now
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
}

private struct TodayMetric: View {
    var title: String
    var value: String
    var symbolName: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbolName)
                .font(.callout.weight(.bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.title3.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct ElderTodayCard: View {
    var elder: ElderStatus
    var store: FamilyStore
    @State private var showAddAction = false
    @State private var showSubscriptionPromotion = false
    @State private var cardPage = 1

    private var completedCount: Int {
        elder.actions.filter(\.isCompleted).count
    }

    private var isComplete: Bool {
        !elder.actions.isEmpty && completedCount == elder.actions.count
    }

    private var heatmapDailyCounts: [String: Int] {
        guard let elderHeatmap = store.heatmapData.first(where: { $0.elderId == elder.id }) else {
            return [:]
        }
        var dict: [String: Int] = [:]
        for entry in elderHeatmap.dailyCounts {
            dict[entry.date] = entry.count
        }
        return dict
    }

    var body: some View {
        GlassCard(cornerRadius: 32) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    SoftIcon(symbolName: isComplete ? "checkmark.circle.fill" : "figure.wave", tint: isComplete ? FamilyTheme.accent : .orange, size: 48)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(elder.name)
                            .font(.title2.bold())
                        Text(elder.subtitle.isEmpty ? "今日照护记录" : elder.subtitle)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusPill(
                        text: "\(completedCount)/\(elder.actions.count)",
                        symbolName: isComplete ? "checkmark.circle.fill" : "clock.fill",
                        tint: isComplete ? FamilyTheme.accent : .orange
                    )
                }

                // Swipeable content
                TabView(selection: $cardPage) {
                    // Page 0: Activity Heatmap (swipe right from action list)
                    ActivityHeatmapView(
                        dailyCounts: heatmapDailyCounts,
                        elderName: elder.name,
                        maxDailyActions: max(elder.actions.count, 1)
                    )
                    .tag(0)

                    // Page 1: Action buttons (default)
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(elder.actions) { action in
                                Button {
                                    if !action.isCompleted {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                    store.complete(actionKey: action.actionKey, for: elder.id)
                                } label: {
                                    CareActionCompactRow(action: action, elderName: elder.name)
                                }
                                .buttonStyle(ActionPressStyle(isCompleted: action.isCompleted))
                                .accessibilityLabel("\(elder.name)\(action.title)")
                                .accessibilityHint(action.isCompleted ? "今天已经完成" : "双击记录今天已完成")
                                .contextMenu {
                                    if action.actionKey.hasPrefix("custom_") {
                                        Button(role: .destructive) {
                                            store.deleteCustomAction(actionKey: action.actionKey, for: elder.id)
                                        } label: {
                                            Label("删除「\(action.title)」", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 320)

                // Page indicator dots — centered below the swipeable content
                HStack(spacing: 8) {
                    Circle()
                        .fill(cardPage == 0 ? FamilyTheme.accent : Color.primary.opacity(0.15))
                        .frame(width: 7, height: 7)
                    Circle()
                        .fill(cardPage == 1 ? FamilyTheme.accent : Color.primary.opacity(0.15))
                        .frame(width: 7, height: 7)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)

                Button {
                    if store.canAddCustomAction(for: elder) {
                        showAddAction = true
                    } else {
                        showSubscriptionPromotion = true
                    }
                } label: {
                    Label(store.canAddCustomAction(for: elder) ? "添加自定义照护项" : store.customActionLimitText(for: elder), systemImage: store.canAddCustomAction(for: elder) ? "plus.circle" : "lock.fill")
                        .font(.callout.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(FamilyTheme.accent)
            }
        }
        .sheet(isPresented: $showAddAction) { addActionSheet }
        .sheet(isPresented: $showSubscriptionPromotion) {
            SubscriptionPromotionView(store: store)
        }
    }

    private var addActionSheet: some View {
        AddCustomActionSheet(store: store, elderId: elder.id, isPresented: $showAddAction)
    }
}

private struct CareActionCompactRow: View {
    var action: CareAction
    var elderName: String

    var body: some View {
        HStack(spacing: 13) {
            SoftIcon(
                symbolName: action.isCompleted ? "checkmark.circle.fill" : action.symbolName,
                tint: action.isCompleted ? FamilyTheme.accent : .secondary,
                size: 44
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(action.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(action.isCompleted ? "已记录 \(action.completedAt?.formatted(date: .omitted, time: .shortened) ?? "")" : "点一下记录给家人")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: action.isCompleted ? "checkmark" : "chevron.right")
                .font(.callout.weight(.bold))
                .foregroundStyle(action.isCompleted ? FamilyTheme.accent : Color.gray.opacity(0.35))
        }
        .padding(12)
        .glassSurface(cornerRadius: 20, interactive: true)
    }
}

private struct ActivityTimelineRow: View {
    var item: ActivityItem

    var body: some View {
        GlassCard(cornerRadius: 22) {
            HStack(alignment: .top, spacing: 14) {
                AvatarView(symbolName: item.actorAvatarSymbol, colorName: item.actorAvatarColor, size: 42)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Image(systemName: item.symbolName)
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(item.tone.color)
                        Text(item.title)
                            .font(.headline)
                    }
                    Text(item.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let comment = item.comment, !comment.isEmpty {
                        Text(comment)
                            .font(.callout)
                            .foregroundStyle(.primary)
                            .padding(.top, 2)
                    }
                }
                Spacer()
                Text(item.occurredAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct AddCustomActionSheet: View {
    var store: FamilyStore
    var elderId: UUID
    @Binding var isPresented: Bool
    @State private var title = ""
    @State private var selectedIcon = "heart.circle.fill"

    private let actionIcons = [
        "heart.circle.fill", "pills.fill", "heart.text.square.fill",
        "moon.zzz.fill", "sun.max.fill", "figure.walk",
        "fork.knife", "cup.and.saucer.fill", "drop.fill",
        "thermometer.medium", "bandage.fill", "stethoscope",
        "bed.double.fill", "chair.lounge.fill", "bicycle",
        "book.fill", "pencil.and.list.clipboard",
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    FamilySectionHeader(title: "操作名称", subtitle: "建议使用老人容易理解的短句，例如「已测血糖」。", symbolName: "textformat")
                    TextField("如 已测血糖", text: $title)
                        .padding()
                        .glassSurface(cornerRadius: 18, interactive: true)

                    FamilySectionHeader(title: "选择图标", subtitle: nil, symbolName: "square.grid.3x3")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                        ForEach(actionIcons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .foregroundStyle(selectedIcon == icon ? FamilyTheme.accent : .primary)
                                    .frame(width: 52, height: 52)
                                    .background(selectedIcon == icon ? FamilyTheme.accent.opacity(0.14) : Color.primary.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("添加照护项")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        let key = "custom_\(UUID().uuidString.prefix(8))"
                        store.addCustomAction(actionKey: key, title: title, icon: selectedIcon, for: elderId)
                        isPresented = false
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct ActionPressStyle: ButtonStyle {
    var isCompleted: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
            .opacity(configuration.isPressed ? 0.86 : 1.0)
    }
}

#Preview {
    FamilyWallView(store: FamilyStore())
}
