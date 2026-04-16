// FinanceEntry.swift
// MemoAgent — Phase 1: Finance data model
//
// Stores a single expense or income entry parsed from user input,
// card statement PDF, or plain text paste.
// Apple Pay / Wallet APIs are not publicly accessible,
// so manual input and PDF parsing are the supported sources.

import Foundation
import SwiftData

// MARK: - FinanceEntry

@Model
final class FinanceEntry {
    @Attribute(.unique) var id: String
    var amount: Double          // positive = income, negative = expense
    var category: String        // e.g. "식비", "교통", "쇼핑"
    var note: String
    var date: Date
    var sourceRaw: String       // FinanceEntrySource.rawValue

    init(
        id: String = UUID().uuidString,
        amount: Double,
        category: String = "",
        note: String = "",
        date: Date = Date(),
        source: FinanceEntrySource = .manual
    ) {
        self.id = id
        self.amount = amount
        self.category = category
        self.note = note
        self.date = date
        self.sourceRaw = source.rawValue
    }

    var source: FinanceEntrySource {
        FinanceEntrySource(rawValue: sourceRaw) ?? .manual
    }

    var isExpense: Bool { amount < 0 }
    var isIncome:  Bool { amount > 0 }
}

// MARK: - FinanceEntrySource

enum FinanceEntrySource: String, Codable, CaseIterable {
    case manual = "manual"
    case pdf    = "pdf"
    case text   = "text"

    var localizedLabel: String {
        switch self {
        case .manual: return "직접 입력"
        case .pdf:    return "PDF 명세서"
        case .text:   return "텍스트 붙여넣기"
        }
    }
}
