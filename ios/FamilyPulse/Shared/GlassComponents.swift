import Combine
import SwiftUI

enum FamilyTheme {
    static let accent = Color(red: 0.10, green: 0.62, blue: 0.39)
    static let sage = Color(red: 0.47, green: 0.67, blue: 0.55)
    static let mint = Color(red: 0.86, green: 0.96, blue: 0.91)
    static let warm = Color(red: 1.0, green: 0.87, blue: 0.68)
    static let coral = Color(red: 0.95, green: 0.42, blue: 0.34)
    static let cardRadius: CGFloat = 28
    static let controlRadius: CGFloat = 20
}

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var breathingPhase = false
    private let timer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if colorScheme == .dark {
                darkGradient
            } else {
                lightGradient
            }
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 4)) {
                breathingPhase.toggle()
            }
        }
        .ignoresSafeArea()
    }

    private var lightGradient: some View {
        ZStack {
            Color(.systemGroupedBackground)
            LinearGradient(
                colors: breathingPhase
                    ? [
                        Color(red: 0.90, green: 0.97, blue: 0.93),
                        Color(red: 0.96, green: 0.98, blue: 1.0),
                        Color(red: 1.0, green: 0.96, blue: 0.88)
                    ]
                    : [
                        Color(red: 0.88, green: 0.96, blue: 0.92),
                        Color(red: 0.95, green: 0.98, blue: 0.99),
                        Color(red: 1.0, green: 0.97, blue: 0.91)
                    ],
                startPoint: breathingPhase ? .top : .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.82)
        }
    }

    private var darkGradient: some View {
        ZStack {
            Color(.systemBackground)
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.11, blue: 0.09),
                    Color(red: 0.10, green: 0.12, blue: 0.16),
                    Color(red: 0.16, green: 0.12, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 28
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(18)
            .glassSurface(cornerRadius: cornerRadius)
    }
}

struct StatusPill: View {
    var text: String
    var symbolName: String
    var tint: Color

    var body: some View {
        Label(text, systemImage: symbolName)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .glassSurface(cornerRadius: 18, interactive: false)
            .accessibilityLabel(text)
    }
}

struct AvatarView: View {
    var symbolName: String
    var colorName: String
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: size * 0.48, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint, in: Circle())
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.65), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }

    private var tint: Color {
        switch colorName {
        case "blue": .blue
        case "orange": .orange
        case "purple": .purple
        case "pink": .pink
        default: .green
        }
    }
}

struct GlassSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat
    var interactive: Bool
    @Environment(\.colorScheme) private var colorScheme

    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .background(
                material,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.65), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.06), radius: interactive ? 14 : 10, y: interactive ? 8 : 5)
    }

    private var material: AnyShapeStyle {
        if interactive {
            return AnyShapeStyle(.thinMaterial)
        }
        return AnyShapeStyle(.regularMaterial)
    }
}

struct FamilySectionHeader: View {
    var title: String
    var subtitle: String?
    var symbolName: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    if let symbolName {
                        Image(systemName: symbolName)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(FamilyTheme.accent)
                    }
                    Text(title)
                        .font(.title3.bold())
                }
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }
}

struct BrandMark: View {
    var size: CGFloat = 58

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [FamilyTheme.accent, FamilyTheme.sage],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: size * 0.48, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: FamilyTheme.accent.opacity(0.22), radius: 14, y: 7)
        .accessibilityHidden(true)
    }
}

struct EmptyStateCard: View {
    var symbolName: String
    var title: String
    var message: String

    var body: some View {
        GlassCard(cornerRadius: 24) {
            VStack(spacing: 10) {
                Image(systemName: symbolName)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }
}

struct SoftIcon: View {
    var symbolName: String
    var tint: Color = FamilyTheme.accent
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: size * 0.45, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
            .accessibilityHidden(true)
    }
}

extension View {
    func glassSurface(cornerRadius: CGFloat, interactive: Bool = false) -> some View {
        modifier(GlassSurfaceModifier(cornerRadius: cornerRadius, interactive: interactive))
    }
}

extension ActivityTone {
    var color: Color {
        switch self {
        case .calm: .blue
        case .success: .green
        case .warning: .orange
        }
    }
}

extension AppointmentStatus {
    var title: String {
        switch self {
        case .planned: String(localized: "待复查")
        case .done: String(localized: "已完成")
        case .canceled: String(localized: "已取消")
        }
    }

    var color: Color {
        switch self {
        case .planned: .blue
        case .done: .green
        case .canceled: .secondary
        }
    }
}
