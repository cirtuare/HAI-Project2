// ScreenTimeSyncProvider.swift
// MemoAgent — Phase 2: Screen Time data source
//
// macOS does not expose DeviceActivity / FamilyControls APIs publicly,
// so we parse the user's Screen Time weekly report text directly.
//
// Supported format (iOS Screen Time → "주간 요약" 공유 텍스트):
//   총 화면 시간: 5시간 32분
//   소셜 미디어: 2시간 10분
//   엔터테인먼트: 1시간 5분
//   ...
// Also handles plain English reports.

import Foundation
import SwiftData

// MARK: - ScreenTimeEntry

struct ScreenTimeEntry {
    let category: String
    let minutes: Int
    var hours: Double { Double(minutes) / 60.0 }
}

// MARK: - ScreenTimeSyncProvider

actor ScreenTimeSyncProvider {
    static let shared = ScreenTimeSyncProvider()
    private init() {}

    // MARK: - Parse

    /// Parse a Screen Time report text and return individual category entries.
    func parse(_ text: String) -> (total: ScreenTimeEntry?, categories: [ScreenTimeEntry]) {
        var total: ScreenTimeEntry? = nil
        var categories: [ScreenTimeEntry] = []

        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in lines {
            guard let entry = parseLine(line) else { continue }
            let lowerLine = line.lowercased()
            if lowerLine.contains("총") || lowerLine.contains("total") || lowerLine.contains("합계") {
                total = entry
            } else {
                categories.append(entry)
            }
        }

        return (total, categories)
    }

    /// Convert parsed screen time data into GraphNode drafts.
    func createNodes(
        reportText: String,
        total: ScreenTimeEntry?,
        categories: [ScreenTimeEntry],
        persona: PersonaRecord
    ) -> [GraphNode] {
        guard !categories.isEmpty || total != nil else { return [] }

        let dateStr = todayDateString()
        var nodes: [GraphNode] = []

        // ── Summary node ─────────────────────────────────────────────
        let totalLabel = total.map { formatDuration($0.minutes) } ?? "기록 없음"
        let topCategories = categories.prefix(3)
            .map { "\($0.category): \(formatDuration($0.minutes))" }
            .joined(separator: ", ")
        let summaryText = topCategories.isEmpty
            ? "총 화면 시간: \(totalLabel)"
            : "총 화면 시간: \(totalLabel) | 주요: \(topCategories)"

        let summaryNode = GraphNode(
            id: UUID().uuidString,
            title: "\(dateStr) 스크린타임 요약",
            summary: summaryText,
            type: .healthMetric,
            date: dateStr,
            originalText: reportText,
            isImportant: (total?.minutes ?? 0) > 300, // > 5h flag
            tags: ["스크린타임", "화면시간", "디지털웰빙"],
            position: CGPoint(x: Double.random(in: -400...400), y: Double.random(in: -300...300)),
            sourceSystem: .screenTime,
            personaIDs: [persona.id]
        )
        nodes.append(summaryNode)

        // ── Per-category nodes (only if ≥ 3 categories) ──────────────
        if categories.count >= 3 {
            for entry in categories where entry.minutes >= 30 {
                let node = GraphNode(
                    id: UUID().uuidString,
                    title: "\(entry.category) 사용시간",
                    summary: "\(formatDuration(entry.minutes)) 사용 (전체의 \(totalLabel == "기록 없음" ? "-" : percentLabel(entry.minutes, of: total?.minutes ?? 0))%)",
                    type: .healthMetric,
                    date: dateStr,
                    originalText: "\(entry.category): \(formatDuration(entry.minutes))",
                    isImportant: false,
                    tags: ["스크린타임", entry.category],
                    position: CGPoint(x: Double.random(in: -400...400), y: Double.random(in: -300...300)),
                    sourceSystem: .screenTime,
                    personaIDs: [persona.id]
                )
                nodes.append(node)
            }
        }

        return nodes
    }

    // MARK: - EcosystemSyncService integration

    /// Save parsed nodes to SwiftData and push to ViewModel.
    func save(
        nodes: [GraphNode],
        context: ModelContext,
        viewModel: GraphViewModel
    ) async {
        guard !nodes.isEmpty else { return }
        await MainActor.run {
            viewModel.insertEcosystemNodes(nodes)
        }
    }

    // MARK: - Private helpers

    private func parseLine(_ line: String) -> ScreenTimeEntry? {
        // Patterns to match:
        // "소셜 미디어: 2시간 10분"
        // "소셜 미디어  2시간 10분"
        // "소셜 미디어 2h 10m"
        // "Social Media: 2 hours 10 minutes"

        // Split on : or tab or multiple spaces to get category vs duration parts
        _ = CharacterSet(charactersIn: ":\t")
        let parts: [String]
        if line.contains(":") {
            parts = line.components(separatedBy: ":").map { $0.trimmingCharacters(in: .whitespaces) }
        } else {
            // Try splitting on the first occurrence of a digit
            let splitIdx = line.firstIndex(where: { $0.isNumber })
            guard let idx = splitIdx else { return nil }
            let cat = String(line[..<idx]).trimmingCharacters(in: .whitespaces)
            let dur = String(line[idx...]).trimmingCharacters(in: .whitespaces)
            parts = [cat, dur]
        }

        guard parts.count >= 2 else { return nil }
        let category = parts[0].trimmingCharacters(in: .whitespaces)
        let durationStr = parts[1...].joined(separator: " ")
        guard !category.isEmpty, let minutes = parseDuration(durationStr) else { return nil }
        return ScreenTimeEntry(category: category, minutes: minutes)
    }

    private func parseDuration(_ text: String) -> Int? {
        var total = 0
        var matched = false

        // Korean: X시간 Y분
        let koreanPattern = #/(\d+)\s*시간(?:\s*(\d+)\s*분)?/#
        if let match = text.firstMatch(of: koreanPattern) {
            total += Int(match.1)! * 60
            if let mins = match.2 { total += Int(mins)! }
            matched = true
        } else if let minOnly = text.firstMatch(of: #/(\d+)\s*분/#) {
            total += Int(minOnly.1)!
            matched = true
        }

        // English: X hours Y minutes / Xh Ym
        if !matched {
            let engH = #/(\d+)\s*h(?:our)?s?/#
            let engM = #/(\d+)\s*m(?:in(?:ute)?s?)?/#
            if let h = text.firstMatch(of: engH) { total += Int(h.1)! * 60; matched = true }
            if let m = text.firstMatch(of: engM) { total += Int(m.1)!;      matched = true }
        }

        return matched ? total : nil
    }

    private func formatDuration(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m)분" }
        if m == 0 { return "\(h)시간" }
        return "\(h)시간 \(m)분"
    }

    private func percentLabel(_ part: Int, of total: Int) -> String {
        guard total > 0 else { return "0" }
        return String(Int(Double(part) / Double(total) * 100))
    }

    private func todayDateString() -> String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }
}
