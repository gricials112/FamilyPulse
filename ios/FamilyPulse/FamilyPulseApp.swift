import SwiftUI
import UserNotifications

// MARK: - App Delegate

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("[Push] App launched; notification delegate installed")
        UNUserNotificationCenter.current().delegate = self
        if AppConfiguration.isWeChatEnabled {
            WeChatService.shared.register()
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("[Push] didRegisterForRemoteNotifications token=\(PushNotificationBridge.tokenSummary(deviceToken))")
        PushNotificationBridge.shared.updateDeviceToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[Push] didFailToRegisterForRemoteNotifications error=\(error.localizedDescription)")
        PushNotificationBridge.shared.failRegistration(error)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("[Push] didReceiveRemoteNotification payload=\(PushNotificationBridge.payloadSummary(userInfo))")
        PushNotificationBridge.shared.handleSilentPush(userInfo, completionHandler: completionHandler)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("[Push] willPresent notification id=\(notification.request.identifier) payload=\(PushNotificationBridge.payloadSummary(notification.request.content.userInfo))")
        completionHandler([.banner, .sound, .badge])
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        application.applicationIconBadgeNumber = 0
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        if AppConfiguration.isWeChatEnabled {
            return WeChatService.shared.handleOpenURL(url)
        }
        return false
    }

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        if AppConfiguration.isWeChatEnabled, WeChatService.shared.handleUniversalLink(userActivity) {
            return true
        }
        if let url = userActivity.webpageURL {
            handleQRDeepLink(url)
        }
        return true
    }

    private func handleQRDeepLink(_ url: URL) {
        guard url.host == "jiaan.online", url.path == "/qr" else { return }
        NotificationCenter.default.post(name: .qrCodeDeepLink, object: url)
    }
}


// MARK: - App

@main
struct FamilyPulseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var store = FamilyStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .onOpenURL { url in
                    if AppConfiguration.isWeChatEnabled {
                        _ = WeChatService.shared.handleOpenURL(url)
                    }
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    if AppConfiguration.isWeChatEnabled,
                       WeChatService.shared.handleUniversalLink(userActivity) {
                        return
                    }
                    if let url = userActivity.webpageURL {
                        handleQRDeepLink(url)
                    }
                }
        }
    }

    private func handleQRDeepLink(_ url: URL) {
        guard url.host == "jiaan.online", url.path == "/qr" else { return }
        NotificationCenter.default.post(name: .qrCodeDeepLink, object: url)
    }
}
