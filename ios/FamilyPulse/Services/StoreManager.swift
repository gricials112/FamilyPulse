import StoreKit
import Foundation

enum StoreSubscriptionPlan: String, CaseIterable, Identifiable {
    case monthly = "MONTHLY"
    case yearly = "YEARLY"

    var id: String { rawValue }

    var productId: String {
        switch self {
        case .monthly: "com.lwj.FamilyPulse.premium.monthly.v2"
        case .yearly: "com.lwj.FamilyPulse.premium.yearly.v2"
        }
    }

    var title: String {
        switch self {
        case .monthly: String(localized: "月付")
        case .yearly: String(localized: "年付")
        }
    }

    var fallbackPrice: String {
        let currencyCode = Locale.current.currency?.identifier ?? "USD"
        let amount: Decimal = self == .monthly ? 6 : 58
        return amount.formatted(.currency(code: currencyCode).precision(.fractionLength(0)))
    }

    var subtitle: String {
        switch self {
        case .monthly: String(localized: "30 秒内同步，Push 提醒，最近 7 天操作历史，订阅码可激活 2 台设备")
        case .yearly: String(localized: "10 秒内同步，Push 提醒，全部操作历史，订阅码可激活 4 台设备")
        }
    }
}

@MainActor
@Observable
final class StoreManager {
    private(set) var productsById: [String: Product] = [:]
    private(set) var isPurchased = false
    private(set) var isLoading = false
    var purchaseError: String?
    var purchaseSuccess = false
    var lastTransactionJws: String?
    var lastPurchasedPlan: StoreSubscriptionPlan?
    private(set) var foundEntitlementJws: String?

    var premiumProduct: Product? {
        productsById[StoreSubscriptionPlan.monthly.productId]
    }

    var standardDisplayPrice: String? {
        displayPrice(for: .monthly)
    }

    var introductoryDisplayPrice: String? {
        productsById[StoreSubscriptionPlan.monthly.productId]?.subscription?.introductoryOffer?.displayPrice
    }

    func displayPrice(for plan: StoreSubscriptionPlan) -> String {
        productsById[plan.productId]?.displayPrice ?? plan.fallbackPrice
    }

    /// 根据 StoreKit 原始价格和地区化格式显示日均价（仅年付有意义）
    func dailyPriceString(for plan: StoreSubscriptionPlan) -> String {
        guard plan == .yearly else { return "" }
        if let product = productsById[plan.productId] {
            let dailyAmount = product.price / 365
            if #available(iOS 17.4, *) {
                return dailyAmount.formatted(product.priceFormatStyle.precision(.fractionLength(2)))
            } else {
                let currencyCode = Locale.current.currency?.identifier ?? "USD"
                return dailyAmount.formatted(.currency(code: currencyCode).precision(.fractionLength(2)))
            }
        }
        // 无法获取 StoreKit 价格时，用设备地区货币格式化估算价格
        let dailyAmount = Decimal(58) / 365
        let currencyCode = Locale.current.currency?.identifier ?? "USD"
        return dailyAmount.formatted(.currency(code: currencyCode).precision(.fractionLength(2)))
    }

    func purchase() async {
        await purchase(.monthly)
    }

    private let productIds = StoreSubscriptionPlan.allCases.map(\.productId)
    private var transactionTask: Task<Void, Never>?

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        // Listen for subscription renewals and other incoming transactions
        if transactionTask == nil {
            transactionTask = Task { [weak self] in
                for await result in Transaction.updates {
                    await MainActor.run {
                        self?.handleTransactionUpdate(result)
                    }
                }
            }
        }
        print("[StoreKit] Requesting productIds: \(productIds)")
        // StoreKit 2 API
        do {
            let products = try await Product.products(for: productIds)
            print("[StoreKit] StoreKit 2 loaded \(products.count) products: \(products.map(\.id))")
            if products.isEmpty {
                purchaseError = String(localized: "商品数据为空，请检查 StoreKit 配置")
            }
            productsById = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
            await checkSubscriptionStatus()
        } catch {
            print("[StoreKit] StoreKit 2 error: \(error)")
            purchaseError = String(localized: "商品加载失败: \(error.localizedDescription)")
        }
    }

    func purchase(_ plan: StoreSubscriptionPlan) async {
        if productsById[plan.productId] == nil {
            isLoading = true
            purchaseError = nil
            do {
                let products = try await Product.products(for: productIds)
                productsById = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
            } catch {
                purchaseError = String(localized: "商品信息加载失败")
                isLoading = false
                return
            }
            isLoading = false
        }

        guard let product = productsById[plan.productId] else {
            purchaseError = String(localized: "商品信息未加载，请确保项目 Scheme 已配置 StoreKit 配置文件")
            return
        }
        isLoading = true
        purchaseError = nil
        purchaseSuccess = false
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let jwsString = verification.jwsRepresentation
                if case .verified(let transaction) = verification {
                    lastTransactionJws = jwsString
                    lastPurchasedPlan = plan
                    await transaction.finish()
                    isPurchased = true
                    purchaseSuccess = true
                } else {
                    purchaseError = String(localized: "交易验证失败")
                }
            case .pending:
                purchaseError = String(localized: "等待处理中")
            case .userCancelled:
                purchaseError = nil
            @unknown default:
                purchaseError = String(localized: "未知错误")
            }
        } catch {
            purchaseError = String(localized: "购买失败: \(error.localizedDescription)")
        }
        isLoading = false
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            if let jws = await findVerifiedEntitlementJws() {
                lastTransactionJws = jws
                isPurchased = true
                purchaseSuccess = true
            } else {
                isPurchased = false
            }
        } catch {
            purchaseError = String(localized: "恢复失败: \(error.localizedDescription)")
        }
    }

    private func findVerifiedEntitlementJws() async -> String? {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               productIds.contains(transaction.productID) {
                return result.jwsRepresentation
            }
        }
        return nil
    }

    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) {
        guard case .verified(let transaction) = result else { return }
        guard productIds.contains(transaction.productID) else { return }
        isPurchased = true
        lastTransactionJws = result.jwsRepresentation
        purchaseSuccess = true
    }

    func clearLastTransactionJws() {
        lastTransactionJws = nil
        lastPurchasedPlan = nil
    }

    private func checkSubscriptionStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               productIds.contains(transaction.productID) {
                isPurchased = true
                foundEntitlementJws = result.jwsRepresentation
                return
            }
        }
        isPurchased = false
        foundEntitlementJws = nil
    }
}
