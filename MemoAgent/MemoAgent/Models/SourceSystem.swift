// SourceSystem.swift
// MemoAgent V2 — Source classification for knowledge nodes

import Foundation

// MARK: - SourceSystem

/// Identifies which system created or imported a node.
enum SourceSystem: String, Codable, Hashable, CaseIterable {
    case userCreated = "userCreated"
    case healthKit   = "healthKit"
    case calendar    = "calendar"
    case photos      = "photos"
    case reminders   = "reminders"
    case aiGenerated = "aiGenerated"
    case screenTime  = "screenTime"
    case finance     = "finance"

    nonisolated var localizedLabel: String {
        switch self {
        case .userCreated:  return "직접 입력"
        case .healthKit:    return "Apple Health"
        case .calendar:     return "캘린더"
        case .photos:       return "사진"
        case .reminders:    return "미리 알림"
        case .aiGenerated:  return "AI 생성"
        case .screenTime:   return "스크린타임"
        case .finance:      return "금융"
        }
    }

    var systemImage: String {
        switch self {
        case .userCreated:  return "person.fill"
        case .healthKit:    return "heart.fill"
        case .calendar:     return "calendar"
        case .photos:       return "photo.fill"
        case .reminders:    return "checklist"
        case .aiGenerated:  return "sparkles"
        case .screenTime:   return "hourglass"
        case .finance:      return "creditcard.fill"
        }
    }
}

// MARK: - PersonaType

/// Built-in persona templates. Stored as rawValue in PersonaRecord.
enum PersonaType: String, CaseIterable, Codable {
    case health   = "Health"
    case academic = "Academic"
    case finance  = "Finance"
    case hobby    = "Hobby"
    case other    = "Other"

    // MARK: - Deprecated raw values (kept for migration, do not use in new code)
    // "Work"    → removed; "Medical" → "Health"; "Personal" → "Hobby"

    var localizedName: String {
        switch self {
        case .health:   return "건강"
        case .academic: return "학업"
        case .finance:  return "금융"
        case .hobby:    return "취미"
        case .other:    return "기타"
        }
    }

    var description: String {
        switch self {
        case .health:   return "건강 기록, 운동, 수면, 스크린타임 관리"
        case .academic: return "논문, 강의 노트, 연구 자료 관리"
        case .finance:  return "지출, 예산, 재무 계획 관리"
        case .hobby:    return "일기, 사진, 창작, 취미 활동 기록"
        case .other:    return "분류하기 어려운 기타 주제 관리"
        }
    }

    var icon: String {
        switch self {
        case .health:   return "heart.fill"
        case .academic: return "graduationcap.fill"
        case .finance:  return "creditcard.fill"
        case .hobby:    return "paintpalette.fill"
        case .other:    return "ellipsis.circle.fill"
        }
    }

    var accentHex: String {
        switch self {
        case .health:   return "#1D9E75"   // teal
        case .academic: return "#7F77DD"   // purple
        case .finance:  return "#EF9F27"   // amber
        case .hobby:    return "#D85A30"   // coral
        case .other:    return "#64748b"   // slate
        }
    }

    /// System prompt context injected into AI calls for this persona.
    var systemPromptContext: String {
        switch self {
        case .health:
            return "You are managing a personal health knowledge base. Focus on health trends, wellness insights, sleep patterns, exercise data, and screen time habits. Be cautious and recommend consulting healthcare professionals when appropriate."
        case .academic:
            return "You are managing an academic knowledge base. Focus on concepts, citations, research methodology, and learning connections. Use precise academic language."
        case .finance:
            return "You are managing a personal finance knowledge base. Focus on spending patterns, budget analysis, and financial insights. Be objective and data-driven."
        case .hobby:
            return "You are managing a personal hobby and lifestyle space. Focus on creative connections, memorable experiences, personal growth, and leisure activities. Be empathetic and reflective."
        case .other:
            return "You are managing a general-purpose knowledge base. Adapt your tone and focus to the content provided, helping the user organize and connect information across diverse topics."
        }
    }

    /// HealthKit types relevant to this persona.
    var relevantHealthTypes: [String] {
        switch self {
        case .health:
            return ["heartRate", "bloodPressureSystolic", "bloodPressureDiastolic",
                    "bloodGlucose", "sleepAnalysis", "oxygenSaturation", "bodyMass",
                    "stepCount", "activeEnergyBurned", "heartRateVariabilitySDNN"]
        case .academic:
            return ["sleepAnalysis", "mindfulSession", "stepCount"]
        case .hobby:
            return ["stepCount", "sleepAnalysis", "activeEnergyBurned"]
        case .finance, .other:
            return []
        }
    }
}
