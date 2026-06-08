import SwiftUI

struct ActivityHeatmapView: View {
    let dailyCounts: [String: Int]
    let elderName: String
    let maxDailyActions: Int

    private static let dateParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private let calendar = Calendar.current
    private let weekdaySymbols = ["一", "二", "三", "四", "五", "六", "日"]

    private var monthDays: [(day: Int, isCurrentMonth: Bool, isToday: Bool, count: Int)] {
        let today = calendar.startOfDay(for: Date())
        let year = calendar.component(.year, from: today)
        let month = calendar.component(.month, from: today)

        let comps = DateComponents(year: year, month: month, day: 1)
        guard let firstOfMonth = calendar.date(from: comps) else { return [] }
        guard let lastOfMonth = calendar.date(byAdding: .month, value: 1, to: firstOfMonth)?.addingTimeInterval(-86400) else { return [] }

        let firstWeekday = ((calendar.component(.weekday, from: firstOfMonth) - 2 + 7) % 7)
        let lastWeekday = ((calendar.component(.weekday, from: lastOfMonth) - 2 + 7) % 7)

        let totalDays = calendar.component(.day, from: lastOfMonth)
        let totalCells = firstWeekday + totalDays + (6 - lastWeekday)

        var result: [(Int, Bool, Bool, Int)] = []

        if let prevMonth = calendar.date(byAdding: .month, value: -1, to: firstOfMonth) {
            let prevMonthRange = calendar.range(of: .day, in: .month, for: prevMonth)!
            let prevMonthDays = prevMonthRange.count
            for i in 0..<firstWeekday {
                let day = prevMonthDays - firstWeekday + i + 1
                result.append((day, false, false, 0))
            }
        }

        let todayDay = calendar.component(.day, from: today)
        for day in 1...totalDays {
            let dateStr = String(format: "%04d-%02d-%02d", year, month, day)
            let count = dailyCounts[dateStr] ?? 0
            result.append((day, true, day == todayDay, count))
        }

        let trailingCount = totalCells - result.count
        for day in 1...trailingCount {
            result.append((day, false, false, 0))
        }

        return result
    }

    private var weeks: [[(day: Int, isCurrentMonth: Bool, isToday: Bool, count: Int)]] {
        let items = monthDays
        let rowCount = (items.count + 6) / 7
        return (0..<rowCount).map { row in
            let start = row * 7
            let end = min(start + 7, items.count)
            return Array(items[start..<end])
        }
    }

    private var monthTitle: String {
        let today = Date()
        let year = calendar.component(.year, from: today)
        let month = calendar.component(.month, from: today)
        return "\(year)年\(month)月"
    }

    private var monthSummary: String {
        let today = calendar.startOfDay(for: Date())
        let year = calendar.component(.year, from: today)
        let month = calendar.component(.month, from: today)
        var total = 0
        var daysWithActivity = 0
        let range = calendar.range(of: .day, in: .month, for: today)!
        for day in 1...range.count {
            let dateStr = String(format: "%04d-%02d-%02d", year, month, day)
            let c = dailyCounts[dateStr] ?? 0
            total += c
            if c > 0 { daysWithActivity += 1 }
        }
        return "完成 \(total) 次 · \(daysWithActivity) 天"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(monthTitle)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                Text(monthSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 14)

            // Weekday header
            HStack(spacing: 3) {
                ForEach(weekdaySymbols.indices, id: \.self) { i in
                    Text(weekdaySymbols[i])
                        .font(.system(size: 11, design: .rounded).weight(.medium))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 8)

            // Calendar grid
            VStack(spacing: 3) {
                ForEach(weeks.indices, id: \.self) { row in
                    HStack(spacing: 3) {
                        ForEach(weeks[row].indices, id: \.self) { col in
                            let entry = weeks[row][col]
                            dayCell(
                                isCurrentMonth: entry.isCurrentMonth,
                                isToday: entry.isToday,
                                count: entry.count
                            )
                        }
                    }
                }
            }
            .padding(.trailing, 1)

            // Legend
            HStack(spacing: 4) {
                Spacer()
                Text("少")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                legendSwatch(ratio: 0)
                legendSwatch(ratio: 0.25)
                legendSwatch(ratio: 0.5)
                legendSwatch(ratio: 0.75)
                legendSwatch(ratio: 1.0)
                Text("多")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 14)
            .padding(.bottom, 4)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func dayCell(isCurrentMonth: Bool, isToday: Bool, count: Int) -> some View {
        let ratio = maxDailyActions > 0 ? Double(count) / Double(maxDailyActions) : 0
        let hasActivity = isCurrentMonth && ratio > 0
        let fill = hasActivity ? activityColor(ratio) : Color(.systemGray5)
        RoundedRectangle(cornerRadius: 5)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isToday ? FamilyTheme.accent : .clear, lineWidth: 2.5)
            )
            .shadow(color: hasActivity ? .black.opacity(0.28) : .clear, radius: 3, x: 0, y: 2)
            .aspectRatio(1, contentMode: .fit)
            .opacity(isCurrentMonth ? 1.0 : 0.12)
    }

    private func legendSwatch(ratio: Double) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(ratio > 0 ? activityColor(ratio) : Color(.systemGray5))
            .frame(width: 12, height: 12)
            .shadow(color: ratio > 0 ? .black.opacity(0.25) : .clear, radius: 2, x: 0, y: 1)
    }

    private static let mutedAccent = Color(red: 0.28, green: 0.50, blue: 0.42)

    private func activityColor(_ ratio: Double) -> Color {
        switch ratio {
        case ..<0.01: return Color(.systemGray5)
        case ..<0.34: return Self.mutedAccent.opacity(0.25)
        case ..<0.50: return Self.mutedAccent.opacity(0.40)
        case ..<0.75: return Self.mutedAccent.opacity(0.55)
        case ..<1.0:  return Self.mutedAccent.opacity(0.70)
        default:       return Self.mutedAccent.opacity(0.88)
        }
    }
}
