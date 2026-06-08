import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Timeline Provider

struct ElderActionsProvider: AppIntentTimelineProvider {
    typealias Entry = ElderActionsEntry
    typealias Intent = ElderActionsWidgetConfigurationIntent

    func placeholder(in context: Context) -> ElderActionsEntry {
        let actions = [
            WidgetCareAction(id: "morning_meds", title: "已吃早药", symbolName: "pills.fill", isCompleted: true),
            WidgetCareAction(id: "blood_pressure", title: "已测血压", symbolName: "heart.text.square.fill", isCompleted: false),
            WidgetCareAction(id: "evening_meds", title: "已吃晚药", symbolName: "moon.zzz.fill", isCompleted: false),
        ]
        return ElderActionsEntry(
            date: Date(),
            actions: actions,
            allActions: actions,
            pageIndex: 0,
            totalPages: 1,
            elderName: "妈妈",
            isAuthenticated: true,
            isPremium: false
        )
    }

    func snapshot(for configuration: Intent, in context: Context) async -> ElderActionsEntry {
        await WidgetDataManager().fetchTimeline()
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<ElderActionsEntry> {
        let entries = await WidgetDataManager().fetchAllPages()
        let refreshInterval: TimeInterval = entries.first?.isPremium == true ? 30 : 900
        let nextUpdate = Date().addingTimeInterval(refreshInterval)
        return Timeline(entries: entries, policy: .after(nextUpdate))
    }
}

// MARK: - Widget Configuration

struct ElderActionsWidget: Widget {
    let kind: String = "com.lwj.FamilyPulse.ElderActionsWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ElderActionsWidgetConfigurationIntent.self,
            provider: ElderActionsProvider()
        ) { entry in
            ElderActionsWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("老人快捷操作")
        .description("一键记录吃药、测血压等日常照护操作")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Widget Configuration Intent

struct ElderActionsWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "老人快捷操作"
    static var description = IntentDescription("选择要显示的老人操作按钮")

    // No configurable parameters — uses current elderly person from app
}

// MARK: - Widget View

struct ElderActionsWidgetView: View {
    let entry: ElderActionsEntry

    var body: some View {
        if entry.isAuthenticated && !entry.allActions.isEmpty {
            actionsContent
        } else {
            unauthenticatedContent
        }
    }

    // MARK: Authenticated: Show action buttons

    private var actionsContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Label(entry.elderName, systemImage: "hand.tap.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                let doneCount = entry.allActions.filter(\.isCompleted).count
                Text("\(doneCount)/\(entry.allActions.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.secondary.opacity(0.12), in: Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 6)

            // Action buttons (current page)
            ForEach(entry.actions) { action in
                actionButton(action)
            }

            Spacer(minLength: 0)

            // Page dots
            if entry.totalPages > 1 {
                HStack(spacing: 5) {
                    Spacer()
                    ForEach(0..<entry.totalPages, id: \.self) { i in
                        Circle()
                            .fill(i == entry.pageIndex ? Color.primary : Color.primary.opacity(0.2))
                            .frame(width: 5, height: 5)
                    }
                    Spacer()
                }
                .padding(.bottom, 8)
            }
        }
        .padding(.vertical, 12)
    }

    private func actionButton(_ action: WidgetCareAction) -> some View {
        let intent = CompleteCareActionIntent(actionKey: action.id, elderId: WidgetSharedDefaults.selectedElderId ?? "")

        return Button(intent: intent) {
            HStack(spacing: 12) {
                ZStack {
                    Image(systemName: action.symbolName)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 40)
                        .opacity(action.isCompleted ? 0 : 1)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.green)
                        .frame(width: 40)
                        .opacity(action.isCompleted ? 1 : 0)
                }

                Text(action.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer()

                if action.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                action.isCompleted
                    ? Color.green.opacity(0.06)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.green.opacity(action.isCompleted ? 0.15 : 0), lineWidth: 1)
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 1)
        }
        .buttonStyle(.plain)
        .disabled(action.isCompleted)
        .widgetLabel {
            Text(action.title)
        }
    }

    // MARK: Unauthenticated: Prompt to open app

    private var unauthenticatedContent: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "hand.tap.fill")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text("打开家安 App 开始使用")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("快捷记录每日照护操作")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview(as: .systemLarge) {
    ElderActionsWidget()
} timeline: {
    let actions = [
        WidgetCareAction(id: "morning_meds", title: "已吃早药", symbolName: "pills.fill", isCompleted: true),
        WidgetCareAction(id: "blood_pressure", title: "已测血压", symbolName: "heart.text.square.fill", isCompleted: false),
        WidgetCareAction(id: "evening_meds", title: "已吃晚药", symbolName: "moon.zzz.fill", isCompleted: false),
        WidgetCareAction(id: "walk", title: "已散步", symbolName: "figure.walk", isCompleted: false),
        WidgetCareAction(id: "water", title: "已喝水", symbolName: "drop.fill", isCompleted: false),
    ]
    ElderActionsEntry(
        date: Date(),
        actions: Array(actions[0..<4]),
        allActions: actions,
        pageIndex: 0,
        totalPages: 2,
        elderName: "妈妈",
        isAuthenticated: true,
        isPremium: false
    )
}
