import Combine
import SwiftUI

struct ContentView: View {
    var store: FamilyStore
    @State private var selectedTab: AppTab = .wall

    var body: some View {
        ZStack {
            AppBackground()

            switch store.phase {
            case .signedOut:
                LoginView(store: store)
            case .loading:
                LoadingView(message: store.statusMessage)
            case .intro:
                IntroOnboardingView(store: store)
            case .needsDisplayName:
                DisplayNameSetupView(store: store)
            case .needsFamily:
                FamilyOnboardingView(store: store)
            case .needsElder:
                ElderOnboardingView(store: store)
            case .needsElderSelection:
                ElderIdentitySelectionView(store: store)
            case .ready:
                if store.userMode == .elder {
                    ElderOneTapHomeView(store: store)
                } else {
                    mainTabs
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .qrCodeDeepLink)) { notification in
            handleQRDeepLink(notification.object as? URL)
        }
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            FamilyWallView(store: store)
                .tabItem { Label(AppTab.wall.title, systemImage: AppTab.wall.symbolName) }
                .tag(AppTab.wall)

            AppointmentsView(store: store)
                .tabItem { Label(AppTab.appointments.title, systemImage: AppTab.appointments.symbolName) }
                .tag(AppTab.appointments)

            SettingsView(store: store)
                .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.symbolName) }
                .tag(AppTab.settings)
        }
        .tint(FamilyTheme.accent)
    }

    private func handleQRDeepLink(_ url: URL?) {
        guard let url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let code = components.queryItems?.first(where: { $0.name == "c" })?.value ?? ""
        let type = components.queryItems?.first(where: { $0.name == "t" })?.value ?? ""
        guard !code.isEmpty else { return }

        if type == "sub", code.hasPrefix("FP-") {
            store.activateSubscriptionCode(code)
        } else if type == "join" {
            store.joinFamily(inviteCode: code)
        }
    }
}

extension Notification.Name {
    static let qrCodeDeepLink = Notification.Name("com.lwj.FamilyPulse.qrDeepLink")
}

private struct LoadingView: View {
    var message: String

    var body: some View {
        VStack(spacing: 18) {
            ProgressView()
                .controlSize(.large)
            Text(message.isEmpty ? "正在加载" : message)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .glassSurface(cornerRadius: 28)
    }
}

#Preview {
    ContentView(store: FamilyStore())
}
