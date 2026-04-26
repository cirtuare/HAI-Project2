// FinanceSyncProvider.swift
// MemoAgent — Phase 2: Finance data source
//
// Apple Pay / Wallet APIs are not publicly accessible.
// Users paste their card statement text or PDF-extracted text here.
//
// Parsing strategy:
//   1. Regex scan for Korean amount patterns (₩X,XXX or X,XXX원)
//   2. Detect date on same/preceding line
//   3. Remaining text on the line = merchant/note
//   4. Category inferred from merchant keyword list
//
// Output: [FinanceEntry] + summary [GraphNode] for the finance persona.

import Foundation
import SwiftData

// MARK: - FinanceSyncProvider

actor FinanceSyncProvider {
    static let shared = FinanceSyncProvider()
    private init() {}

    // MARK: - Parse

    /// Parse a card statement or expense text into FinanceEntry objects.
    func parse(_ text: String, source: FinanceEntrySource = .text) -> [FinanceEntry] {
        var entries: [FinanceEntry] = []
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in lines {
            guard let entry = parseLine(line, source: source) else { continue }
            entries.append(entry)
        }
        return entries
    }

    /// Create GraphNodes summarising the parsed finance entries.
    func createNodes(
        entries: [FinanceEntry],
        rawText: String,
        persona: PersonaRecord
    ) -> [GraphNode] {
        guard !entries.isEmpty else { return [] }

        let dateStr = todayDateString()
        let totalExpense = entries.filter { $0.isExpense }.reduce(0.0) { $0 + abs($1.amount) }
        let totalIncome  = entries.filter { $0.isIncome  }.reduce(0.0) { $0 + $1.amount }

        // Category breakdown
        var byCategory: [String: Double] = [:]
        for e in entries where e.isExpense {
            byCategory[e.category, default: 0] += abs(e.amount)
        }
        let topCategories = byCategory.sorted { $0.value > $1.value }.prefix(3)
            .map { "\($0.key): \(formatAmount($0.value))" }
            .joined(separator: " · ")

        let summaryLine = totalIncome > 0
            ? "지출 \(formatAmount(totalExpense)) / 수입 \(formatAmount(totalIncome))"
            : "총 지출 \(formatAmount(totalExpense))"

        let summaryNode = GraphNode(
            id: UUID().uuidString,
            title: "\(dateStr) 지출 요약 (\(entries.count)건)",
            summary: "\(summaryLine)\(topCategories.isEmpty ? "" : " | " + topCategories)",
            type: .memo,
            date: dateStr,
            originalText: rawText,
            isImportant: totalExpense > 500_000,
            tags: ["지출", "금융", "가계부"],
            position: CGPoint(x: Double.random(in: -400...400), y: Double.random(in: -300...300)),
            sourceSystem: .finance,
            personaIDs: [persona.id]
        )

        return [summaryNode]
    }

    /// Persist FinanceEntry objects to SwiftData and push summary nodes to ViewModel.
    func save(
        entries: [FinanceEntry],
        nodes: [GraphNode],
        context: ModelContext,
        viewModel: GraphViewModel
    ) async {
        // Insert FinanceEntry records
        for entry in entries {
            context.insert(entry)
        }
        do { try context.save() } catch {
            print("[FinanceSyncProvider] Failed to save entries: \(error)")
        }

        // Push graph nodes to ViewModel
        guard !nodes.isEmpty else { return }
        await MainActor.run {
            viewModel.insertEcosystemNodes(nodes)
        }
    }

    // MARK: - Private helpers

    private func parseLine(_ line: String, source: FinanceEntrySource) -> FinanceEntry? {
        // Amount patterns:
        //   ₩1,234,567   or   1,234,567원   or   1,234,567 원
        let amountPatterns: [Regex<(Substring, Substring)>] = [
            #/(?:₩|\$)([0-9,]+)/#,
            #/([0-9,]+)\s*원/#,
        ]

        var amountStr: String? = nil
        var rawAmount: Double = 0

        for pattern in amountPatterns {
            if let match = line.firstMatch(of: pattern) {
                amountStr = String(match.1).replacingOccurrences(of: ",", with: "")
                rawAmount = Double(amountStr ?? "0") ?? 0
                break
            }
        }

        guard rawAmount > 0 else { return nil }

        // Determine sign: keywords that hint at income
        let isIncome = containsIncomeKeyword(line)
        let amount = isIncome ? rawAmount : -rawAmount

        // Date extraction
        let date = extractDate(from: line) ?? Date()

        // Merchant / note: remove amount + date tokens, use remainder
        var note = line
        if let str = amountStr {
            note = note.replacingOccurrences(of: str + "원", with: "")
                       .replacingOccurrences(of: "₩" + str, with: "")
                       .replacingOccurrences(of: str, with: "")
        }
        note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if note.count > 60 { note = String(note.prefix(60)) }

        // Category inference
        let category = inferCategory(from: line)

        return FinanceEntry(
            amount: amount,
            category: category,
            note: note.isEmpty ? line : note,
            date: date,
            source: source
        )
    }

    private func extractDate(from line: String) -> Date? {
        // Matches: 2024.01.15 / 2024-01-15 / 01/15 / 1월 15일
        let patterns: [(Regex<AnyRegexOutput>, String)] = [
            (try! Regex(#"\d{4}[.\-]\d{1,2}[.\-]\d{1,2}"#), "yyyy.MM.dd"),
            (try! Regex(#"\d{1,2}[./]\d{1,2}"#),             "MM/dd"),
            (try! Regex(#"\d{1,2}월\s*\d{1,2}일"#),          "MM월dd일"),
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")

        for (pattern, format) in patterns {
            if let match = line.firstMatch(of: pattern) {
                formatter.dateFormat = format
                let raw = String(match.0).replacingOccurrences(of: "-", with: ".")
                if let d = formatter.date(from: raw) { return d }
            }
        }
        return nil
    }

    private func inferCategory(from text: String) -> String {
        let lower = text.lowercased()
        let map: [(String, [String])] = [
            ("식비",     ["카페", "커피", "음식", "식당", "배달", "편의점", "마트", "스타벅스", "맥도날드", "롯데리아", "burger", "coffee", "food"]),
            ("교통",     ["택시", "버스", "지하철", "주유", "카카오택시", "uber", "transport", "transit"]),
            ("쇼핑",     ["쿠팡", "네이버쇼핑", "아마존", "무신사", "올리브영", "shop", "market", "mall"]),
            ("구독",     ["넷플릭스", "유튜브", "스포티파이", "애플", "google", "netflix", "spotify", "subscription"]),
            ("의료",     ["병원", "약국", "의원", "치과", "클리닉", "hospital", "pharmacy"]),
            ("교육",     ["학원", "강의", "책", "교재", "udemy", "inflearn", "education"]),
            ("여가",     ["영화", "게임", "여행", "헬스", "gym", "movie", "travel"]),
        ]

        for (category, keywords) in map {
            if keywords.contains(where: { lower.contains($0) }) {
                return category
            }
        }
        return "기타"
    }

    private func containsIncomeKeyword(_ text: String) -> Bool {
        let keywords = ["입금", "수입", "급여", "월급", "환급", "income", "salary", "deposit"]
        let lower = text.lowercased()
        return keywords.contains { lower.contains($0) }
    }

    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return (formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))") + "원"
    }

    private func todayDateString() -> String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }
}
