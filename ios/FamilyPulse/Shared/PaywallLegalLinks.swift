import SwiftUI
import SafariServices

// MARK: - PaywallLegalLinks

/// A reusable legal-links footer for subscription / paywall screens.
///
/// Displays clickable links for **Terms of Use (EULA)** and **Privacy Policy**
/// in a compact HStack, using `.footnote` font and `.secondary` tint.
///
/// Usage:
/// ```swift
/// PaywallLegalLinks()
///     .padding(.top, 8)
/// ```
struct PaywallLegalLinks: View {
    // MARK: - URLs
    private let eulaURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private let privacyURL = URL(string: "https://jiaan.online/privacy.html")!

    var body: some View {
        HStack(spacing: 6) {
            Link(destination: eulaURL) {
                Text("使用条款（EULA）")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .underline(pattern: .solid, color: .secondary.opacity(0.4))
            }
            .accessibilityLabel("Terms of Use (EULA)")

            Text("·")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Link(destination: privacyURL) {
                Text("隐私政策")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .underline(pattern: .solid, color: .secondary.opacity(0.4))
            }
            .accessibilityLabel("Privacy Policy")
        }
        .multilineTextAlignment(.center)
    }
}

// MARK: - English Variant

/// English-language variant of `PaywallLegalLinks`.
struct PaywallLegalLinksEnglish: View {
    private let eulaURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private let privacyURL = URL(string: "https://jiaan.online/privacy.html")!

    var body: some View {
        HStack(spacing: 6) {
            Link(destination: eulaURL) {
                Text("Terms of Use (EULA)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .underline(pattern: .solid, color: .secondary.opacity(0.4))
            }
            .accessibilityLabel("Terms of Use (EULA)")

            Text("·")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Link(destination: privacyURL) {
                Text("Privacy Policy")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .underline(pattern: .solid, color: .secondary.opacity(0.4))
            }
            .accessibilityLabel("Privacy Policy")
        }
        .multilineTextAlignment(.center)
    }
}

// MARK: - Auto-localized Variant

/// Automatically picks Chinese or English labels based on the user's preferred language.
struct PaywallLegalLinksAuto: View {
    @Environment(\.locale) private var locale

    private let eulaURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private let privacyURL = URL(string: "https://jiaan.online/privacy.html")!

    private var isChinese: Bool {
        let lang = locale.language.languageCode?.identifier ?? "en"
        return lang == "zh" || lang == "zh-Hans" || lang == "zh-Hant"
    }

    var body: some View {
        HStack(spacing: 6) {
            Link(destination: eulaURL) {
                Text(isChinese ? "使用条款（EULA）" : "Terms of Use (EULA)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .underline(pattern: .solid, color: .secondary.opacity(0.4))
            }
            .accessibilityLabel("Terms of Use (EULA)")

            Text("·")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Link(destination: privacyURL) {
                Text(isChinese ? "隐私政策" : "Privacy Policy")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .underline(pattern: .solid, color: .secondary.opacity(0.4))
            }
            .accessibilityLabel("Privacy Policy")
        }
        .multilineTextAlignment(.center)
    }
}

// MARK: - Alternative: SafariViewController-based (for Deployment Target < iOS 15)

/// Falls back to `SFSafariViewController` when `Link` is not available (iOS < 14).
/// Can also be used if you prefer `SFSafariViewController` behaviour for all versions.
struct PaywallLegalLinksSafari: View {
    @State private var activeURL: IdentifiableURL?

    private let eulaURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private let privacyURL = URL(string: "https://jiaan.online/privacy.html")!

    var body: some View {
        HStack(spacing: 6) {
            Button {
                activeURL = IdentifiableURL(url: eulaURL)
            } label: {
                Text("使用条款（EULA）")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .underline(pattern: .solid, color: .secondary.opacity(0.4))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Terms of Use (EULA)")

            Text("·")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Button {
                activeURL = IdentifiableURL(url: privacyURL)
            } label: {
                Text("隐私政策")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .underline(pattern: .solid, color: .secondary.opacity(0.4))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Privacy Policy")
        }
        .multilineTextAlignment(.center)
        .sheet(item: $activeURL) { identifiable in
            SafariView(url: identifiable.url)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Helper Models

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Previews

#Preview("Chinese (Auto)") {
    PaywallLegalLinksAuto()
        .environment(\.locale, Locale(identifier: "zh-Hans"))
}

#Preview("English (Auto)") {
    PaywallLegalLinksAuto()
        .environment(\.locale, Locale(identifier: "en"))
}

#Preview("Chinese (Static)") {
    PaywallLegalLinks()
}

#Preview("English (Static)") {
    PaywallLegalLinksEnglish()
}
