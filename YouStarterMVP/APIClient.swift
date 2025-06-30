// APIClient.swift
// YouStarterMVP
// 新規ファイル

import Foundation

/// サーバ連携用のスタブクライアント
class APIClient {
    /// プラン作成 API
    static func createGuaranteePlan(depositAmount: Int,
                                    completion: @escaping (Result<GuaranteePlan, Error>) -> Void) {
        // TODO: サーバ実装に合わせて置き換え
        let dummyPlan = GuaranteePlan(
            id: UUID().uuidString,
            depositAmount: depositAmount,
            startDate: Date(),
            streakCount: 0,
            paymentIntentID: "", // PaymentIntent ID
            state: .active
        )
        completion(.success(dummyPlan))
    }

    /// プランステータス取得 API
    static func fetchGuaranteePlan(
        completion: @escaping (Result<GuaranteePlan, Error>) -> Void
    ) {
        // TODO: サーバ実装に合わせて置き換え
        completion(.failure(NSError(domain: "APIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])))
    }

    /// ミッション完了報告 API
    static func reportGuaranteeCompletion(
        planId: String,
        date: Date,
        completion: @escaping (Result<GuaranteePlan, Error>) -> Void
    ) {
        // TODO: サーバ実装に合わせて置き換え
        completion(.failure(NSError(domain: "APIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])))
    }
}
