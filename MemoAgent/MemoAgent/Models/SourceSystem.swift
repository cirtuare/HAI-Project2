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

    var localizedLabel: String {
        switch self {
        case .userCreated:  return "직접 입력"
        case .healthKit:    return "Apple Health"
        case .calendar:     return "캘린더"
        case .photos:       return "사진"
        case .reminders:    return "미리 알림"
        case .aiGenerated:  return "AI 생성"
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
        }
    }
}

// MARK: - PersonaType

/// Built-in persona templates. Stored as rawValue in PersonaRecord.
enum PersonaType: String, CaseIterable, Codable {
    case work     = "Work"
    case academic = "Academic"
    case medical  = "Medical"
    case finance  = "Finance"
    case personal = "Personal"

    var localizedName: String {
        switch self {
        case .work:     return "업무"
        case .academic: return "학습"
        case .medical:  return "건강"
        case .finance:  return "재무"
        case .personal: return "개인"
        }
    }

    var description: String {
        switch self {
        case .work:     return "프로젝트, 회의록, 업무 문서 관리"
        case .academic: return "논문, 강의 노트, 연구 자료 관리"
        case .medical:  return "건강 기록, 의료 정보, 운동 데이터 관리"
        case .finance:  return "투자, 지출, 재무 계획 관리"
        case .personal: return "일기, 아이디어, 개인 메모 관리"
        }
    }

    var icon: String {
        switch self {
        case .work:     return "briefcase.fill"
        case .academic: return "graduationcap.fill"
        case .medical:  return "heart.fill"
        case .finance:  return "chart.line.uptrend.xyaxis"
        case .personal: return "person.fill"
        }
    }

    var accentHex: String {
        switch self {
        case .work:     return "#06b6d4"   // cyan
        case .academic: return "#8b5cf6"   // violet
        case .medical:  return "#f43f5e"   // rose
        case .finance:  return "#22c55e"   // green
        case .personal: return "#f59e0b"   // amber
        }
    }

    /// System prompt context injected into AI calls for this persona.
    var systemPromptContext: String {
        switch self {
        case .work:
            return "You are managing a professional knowledge base. Focus on actionable insights, project context, and business value. Use concise, professional language."
        case .academic:
            return "You are managing an academic knowledge base. Focus on concepts, citations, research methodology, and learning connections. Use precise academic language."
        case .medical:
            return "You are managing a personal health knowledge base. Focus on health trends, medical information, and wellness insights. Be cautious and recommend consulting healthcare professionals."
        case .finance:
            return "You are managing a personal finance knowledge base. Focus on financial patterns, investment insights, and budget analysis. Be objective and data-driven."
        case .personal:
            return "You are managing a personal journal and idea space. Focus on emotional insights, creative connections, and personal growth. Be empathetic and reflective."
        }
    }

    /// HealthKit types relevant to this persona (comma-separated identifiers).
    var relevantHealthTypes: [String] {
        switch self {
        case .medical:
            return ["heartRate", "bloodPressureSystolic", "bloodPressureDiastolic",
                    "bloodGlucose", "sleepAnalysis", "oxygenSaturation", "bodyMass"]
        case .work:
            return ["stepCount", "sleepAnalysis", "mindfulSession", "heartRateVariabilitySDNN"]
        case .academic:
            return ["sleepAnalysis", "mindfulSession", "stepCount"]
        case .personal:
            return ["stepCount", "sleepAnalysis", "activeEnergyBurned"]
        case .finance:
            return []
        }
    }
}
