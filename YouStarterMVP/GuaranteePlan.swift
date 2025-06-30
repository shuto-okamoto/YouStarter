// GuaranteePlan.swift
// YouStarterMVP
// 新規ファイル

import Foundation

/// 30日連続保証プランのモデル
struct GuaranteePlan: Codable {
    let id: String
    let depositAmount: Int
    let startDate: Date
    let streakCount: Int
    let paymentIntentID: String
    let state: PlanState
}

enum PlanState: String, Codable {
    case active
    case refunded
    case captured
}
