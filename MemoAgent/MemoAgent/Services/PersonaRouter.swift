// PersonaRouter.swift
// MemoAgent — Phase 3: Persona routing agent
//
// Routes a user's free-text query to one or more relevant PersonaTypes.
// Two paths:
//   1. Apple Intelligence  — @Generable guided generation (on-device, preferred)
//   2. Keyword fallback    — deterministic keyword map, always available

import Foundation
import FoundationModels

// MARK: - Generable schema

@Generable
struct RouterResult {
    @Guide(description: "Comma-separated PersonaType rawValues that are relevant to the query. Valid values: Health, Academic, Finance, Hobby. Include all that apply.")
    var personaTypeRaws: String

    @Guide(description: "One sentence in Korean explaining why these personas were chosen.")
    var reasoning: String
}

// MARK: - PersonaRouter

actor PersonaRouter {
    static let shared = PersonaRouter()
    private init() {}

    // MARK: - Public API

    /// Analyse `query` and return the PersonaTypes most relevant to it.
    /// Checks available personas against the result — returns only types that exist.
    func route(
        query: String,
        availablePersonas: [PersonaRecord]
    ) async -> [PersonaType] {
        let availableTypes = Set(availablePersonas.compactMap { $0.personaType })
        guard !availableTypes.isEmpty else { return [] }

        let candidates: [PersonaType]

        // Try Apple Intelligence first
        let model = SystemLanguageModel.default
        if case .available = model.availability {
            candidates = await routeWithAppleIntelligence(query) ?? keywordRoute(query: query)
        } else {
            candidates = keywordRoute(query: query)
        }

        // Filter to only personas the user actually has
        let filtered = candidates.filter { availableTypes.contains($0) }
        // If nothing matched after filtering, fall back to keyword route with same filter
        return filtered.isEmpty
            ? keywordRoute(query: query).filter { availableTypes.contains($0) }
            : filtered
    }

    /// Route without filtering — returns all matching types regardless of whether
    /// the user has created those personas yet. Used for persona suggestion.
    func routeAll(query: String) async -> [PersonaType] {
        let model = SystemLanguageModel.default
        if case .available = model.availability {
            return await routeWithAppleIntelligence(query) ?? keywordRoute(query: query)
        }
        return keywordRoute(query: query)
    }

    // MARK: - Apple Intelligence path

    private func routeWithAppleIntelligence(_ query: String) async -> [PersonaType]? {
        do {
            let session = LanguageModelSession(instructions: """
                You are a personal knowledge assistant that routes user queries to the correct life domain personas.
                Available personas:
                - Health (건강): health, exercise, sleep, diet, screen time, medical
                - Academic (학업): study, exams, lectures, research, assignments, reading
                - Finance (금융): money, budget, expenses, investment, savings, salary
                - Hobby (취미): hobbies, travel, photography, games, movies, music, cooking
                Choose all personas that are relevant. You MUST respond using the structured format.
                """)
            let response = try await session.respond(
                to: "Query: \(query.prefix(500))",
                generating: RouterResult.self
            )
            return parseRouterResult(response.content)
        } catch {
            return nil
        }
    }

    private func parseRouterResult(_ result: RouterResult) -> [PersonaType] {
        result.personaTypeRaws
            .components(separatedBy: ",")
            .compactMap { PersonaType(rawValue: $0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    // MARK: - Keyword fallback

    nonisolated func keywordRoute(query: String) -> [PersonaType] {
        let lower = query.lowercased()
        var scores: [PersonaType: Int] = [:]

        for (type, keywords) in Self.keywordMap {
            let hits = keywords.filter { lower.contains($0) }.count
            if hits > 0 { scores[type] = hits }
        }

        // Return types sorted by hit count (descending), minimum 1 hit
        return scores.sorted { $0.value > $1.value }.map { $0.key }
    }

    // MARK: - Keyword map

    private static let keywordMap: [PersonaType: [String]] = [
        .health: [
            "건강", "운동", "수면", "심박", "체중", "체지방", "식단", "피로", "두통", "병원",
            "의원", "약", "스크린타임", "화면시간", "디지털", "혈압", "혈당",
            "health", "sleep", "exercise", "diet", "weight", "fatigue", "screen time",
        ],
        .academic: [
            "공부", "학습", "시험", "강의", "논문", "연구", "과제", "수업", "학교",
            "독서", "책", "자격증", "공부법", "노트", "복습", "암기",
            "study", "exam", "lecture", "research", "assignment", "reading", "note",
        ],
        .finance: [
            "돈", "지출", "예산", "투자", "저축", "월급", "급여", "카드", "명세서",
            "절약", "재무", "대출", "이자", "주식", "코인", "가계부", "소비",
            "money", "budget", "expense", "investment", "savings", "salary", "spend",
        ],
        .hobby: [
            "취미", "여행", "사진", "게임", "영화", "음악", "요리", "그림", "만들기",
            "산책", "캠핑", "독서", "드라마", "유튜브", "보드게임", "뜨개질",
            "hobby", "travel", "photo", "game", "movie", "music", "cooking",
        ],
    ]
}
