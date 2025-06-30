// IAPManager.swift
// YouStarterMVP

import Foundation
import StoreKit

/// IAP購入成功の通知名
extension Notification.Name {
    static let iapPurchaseSuccess = Notification.Name("iapPurchaseSuccess")
    static let iapPurchaseFailure = Notification.Name("iapPurchaseFailure")
}

/// 製品ID列挙
enum ProductID: String, CaseIterable {
    case token1000          = "com.yourapp.token.1000" // 1000円分の覚悟クレジット
    case token5000          = "com.yourapp.token.5000" // 5000円分の覚悟クレジット
    case token10000         = "com.yourapp.token.10000" // 10000円分の覚悟クレジット
    case profileSubscription  = "com.yourapp.profile.subscription"
    case continuePurchase     = "com.youstarter.continue"  // コンティニューペナルティ用
}

/// アプリ内課金の管理クラス
final class IAPManager: NSObject {
    static let shared = IAPManager()

    private(set) var products: [SKProduct] = []
    private var productsRequest: SKProductsRequest?

    // UserDefaultsキー
    private let tokenBalanceKey = "userTokenBalance"

    private override init() {
        super.init()
    }

    deinit {
        SKPaymentQueue.default().remove(self)
    }

    /// 起動時に呼び出して製品情報取得を開始
    func start() {
        SKPaymentQueue.default().add(self)
        requestProducts()
    }

    private func requestProducts() {
        let ids = Set(ProductID.allCases.map { $0.rawValue })
        productsRequest?.cancel()
        productsRequest = SKProductsRequest(productIdentifiers: ids)
        productsRequest?.delegate = self
        productsRequest?.start()
    }

    /// 指定製品を購入
    func purchase(_ productID: ProductID) {
        guard SKPaymentQueue.canMakePayments() else {
            print("IAP: 購入不可設定です。設定を確認してください。")
            return
        }
        guard let product = products.first(where: { $0.productIdentifier == productID.rawValue }) else {
            print("IAP: 製品情報がありません: \(productID.rawValue)")
            return
        }
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }

    /// コンティニュー（消耗型IAP）を購入
    func purchaseContinue() {
        purchase(.continuePurchase)
    }

    /// 購入復元
    func restorePurchases() {
        SKPaymentQueue.default().restoreCompletedTransactions()
    }

    /// プロフィールサブスク登録判定
    func isSubscribedToProfile() -> Bool {
        return UserDefaults.standard.bool(forKey: ProductID.profileSubscription.rawValue)
    }

    /// トークン残高を取得
    func getTokenBalance() -> Int {
        return UserDefaults.standard.integer(forKey: tokenBalanceKey)
    }

    /// トークンを追加
    func addTokens(amount: Int) {
        let currentBalance = getTokenBalance()
        UserDefaults.standard.set(currentBalance + amount, forKey: tokenBalanceKey)
        print("IAP: 覚悟クレジット追加 → 残高: \(getTokenBalance())")
    }

    /// トークンを消費
    func deductTokens(amount: Int) -> Bool {
        let currentBalance = getTokenBalance()
        guard currentBalance >= amount else {
            print("IAP: 覚悟クレジット残高不足")
            return false
        }
        UserDefaults.standard.set(currentBalance - amount, forKey: tokenBalanceKey)
        print("IAP: 覚悟クレジット消費 → 残高: \(getTokenBalance())")
        return true
    }

    /// 最後に購入した保証プランID
    func lastPurchasedProductID() -> String? {
        let defaults = UserDefaults.standard
        for id in [ProductID.token1000, .token5000, .token10000] {
            if defaults.bool(forKey: id.rawValue) {
               return id.rawValue
            }
        }
        return nil
    }

    /// コンティニュー購入時に期限をリセット
    private func resetContinueDeadline() {
        let newDeadline = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        UserDefaults.standard.set(newDeadline, forKey: "nextPlayDeadline")
        print("IAP: 次回再生期限をリセット → \(newDeadline)")
    }
}

// MARK: - SKProductsRequestDelegate & SKPaymentTransactionObserver
extension IAPManager: SKProductsRequestDelegate, SKPaymentTransactionObserver {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        DispatchQueue.main.async {
            self.products = response.products
            print("IAP: 製品情報取得 完了 → \(self.products.map { $0.productIdentifier })")
        }
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        print("IAP: 製品情報取得失敗: \(error.localizedDescription)")
    }

    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            handle(transaction: transaction)
        }
    }

    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        print("IAP: 復元完了")
    }

    private func handle(transaction: SKPaymentTransaction) {
        let id = transaction.payment.productIdentifier
        switch transaction.transactionState {
        case .purchased:
            SKPaymentQueue.default().finishTransaction(transaction)
            print("IAP: 購入 成功 → \(id)")
            
            if id == ProductID.token1000.rawValue {
                addTokens(amount: 1000)
            } else if id == ProductID.token5000.rawValue {
                addTokens(amount: 5000)
            } else if id == ProductID.token10000.rawValue {
                addTokens(amount: 10000)
            } else if id == ProductID.continuePurchase.rawValue {
                resetContinueDeadline()
                UserDefaults.standard.set(true, forKey: id)
            } else if id == ProductID.profileSubscription.rawValue {
                UserDefaults.standard.set(true, forKey: id)
            }
            NotificationCenter.default.post(name: .iapPurchaseSuccess, object: nil)
        case .restored:
            UserDefaults.standard.set(true, forKey: id)
            SKPaymentQueue.default().finishTransaction(transaction)
            print("IAP: 復元 成功 → \(id)")
        case .failed:
            SKPaymentQueue.default().finishTransaction(transaction)
            if let error = transaction.error {
                print("IAP: 購入失敗: \(error.localizedDescription)")
            }
            NotificationCenter.default.post(name: .iapPurchaseFailure, object: nil)
        default:
            break
        }
    }
}
