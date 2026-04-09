// HealthKitSyncProvider.swift
// MemoAgent V2 — HealthKit integration (macOS 13+, Apple Silicon required)

import Foundation
import HealthKit
import CoreGraphics

// MARK: - HealthKitSyncProvider

final class HealthKitSyncProvider {
    static let shared = HealthKitSyncProvider()
    private let store = HKHealthStore()

    private init() {}

    // MARK: - Availability

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    /// Request read-only authorization for types relevant to the given persona.
    func requestAuthorization(for persona: PersonaRecord) async throws {
        guard isAvailable else { return }
        let types = readTypes(for: persona)
        guard !types.isEmpty else { return }
        try await store.requestAuthorization(toShare: [], read: types)
    }

    /// Returns true when the app has at least read access to one health type.
    var authorizationStatus: HKAuthorizationStatus {
        guard isAvailable else { return .notDetermined }
        return store.authorizationStatus(for: HKQuantityType(.stepCount))
    }

    // MARK: - Fetch

    /// Fetch recent health samples and convert them to GraphNode drafts.
    /// Uses an anchor to pull only new samples since the last sync.
    func fetchNodes(for persona: PersonaRecord) async -> [GraphNode] {
        guard isAvailable else { return [] }
        let types = readTypes(for: persona)
        var result: [GraphNode] = []
        await withTaskGroup(of: [GraphNode].self) { group in
            for type in types {
                group.addTask { [weak self] in
                    await self?.fetchNodes(for: type, persona: persona) ?? []
                }
            }
            for await nodes in group { result.append(contentsOf: nodes) }
        }
        return result
    }

    // MARK: - Private

    private func fetchNodes(for sampleType: HKSampleType, persona: PersonaRecord) async -> [GraphNode] {
        let anchorKey = "healthkit.anchor.\(sampleType.identifier)"
        let storedData = UserDefaults.standard.data(forKey: anchorKey)
        let anchor: HKQueryAnchor? = storedData.flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0) }

        return await withCheckedContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: sampleType,
                predicate: nil,
                anchor: anchor,
                limit: 50
            ) { [weak self] _, samples, _, newAnchor, error in
                guard error == nil, let samples else {
                    continuation.resume(returning: [])
                    return
                }
                // Persist new anchor
                if let newAnchor,
                   let data = try? NSKeyedArchiver.archivedData(withRootObject: newAnchor, requiringSecureCoding: true) {
                    UserDefaults.standard.set(data, forKey: anchorKey)
                }
                let nodes = self?.convert(samples: samples, personaID: persona.id) ?? []
                continuation.resume(returning: nodes)
            }
            store.execute(query)
        }
    }

    private func convert(samples: [HKSample], personaID: String) -> [GraphNode] {
        let formatter = ISO8601DateFormatter()
        return samples.compactMap { sample -> GraphNode? in
            let dateStr = formatter.string(from: sample.startDate).prefix(10).description

            if let quantity = sample as? HKQuantitySample {
                let (value, unit) = formattedValue(for: quantity)
                return GraphNode(
                    id: UUID().uuidString,
                    title: "\(quantity.quantityType.displayName): \(value) \(unit)",
                    summary: "\(dateStr)에 기록된 \(quantity.quantityType.displayName) 데이터입니다.",
                    type: .healthMetric,
                    date: dateStr,
                    originalText: "\(quantity.quantityType.identifier): \(value) \(unit) at \(dateStr)",
                    isImportant: false,
                    tags: ["건강", quantity.quantityType.displayName],
                    position: randomCanvasPosition(),
                    sourceSystem: .healthKit,
                    externalID: sample.uuid.uuidString,
                    personaID: personaID
                )
            } else if let category = sample as? HKCategorySample,
                      category.categoryType == HKCategoryType(.sleepAnalysis) {
                let durationHours = sample.endDate.timeIntervalSince(sample.startDate) / 3600
                let durationStr = String(format: "%.1f시간", durationHours)
                return GraphNode(
                    id: UUID().uuidString,
                    title: "수면 기록: \(durationStr) (\(dateStr))",
                    summary: "\(dateStr)에 \(durationStr) 수면이 기록되었습니다.",
                    type: .healthMetric,
                    date: dateStr,
                    originalText: "Sleep: \(durationStr) from \(sample.startDate) to \(sample.endDate)",
                    isImportant: false,
                    tags: ["건강", "수면"],
                    position: randomCanvasPosition(),
                    sourceSystem: .healthKit,
                    externalID: sample.uuid.uuidString,
                    personaID: personaID
                )
            }
            return nil
        }
    }

    private func formattedValue(for sample: HKQuantitySample) -> (String, String) {
        let type = sample.quantityType
        switch type {
        case HKQuantityType(.stepCount):
            let val = Int(sample.quantity.doubleValue(for: .count()))
            return ("\(val)", "걸음")
        case HKQuantityType(.heartRate):
            let val = Int(sample.quantity.doubleValue(for: HKUnit(from: "count/min")))
            return ("\(val)", "bpm")
        case HKQuantityType(.activeEnergyBurned):
            let val = Int(sample.quantity.doubleValue(for: .kilocalorie()))
            return ("\(val)", "kcal")
        case HKQuantityType(.bodyMass):
            let val = String(format: "%.1f", sample.quantity.doubleValue(for: .gramUnit(with: .kilo)))
            return (val, "kg")
        case HKQuantityType(.bloodGlucose):
            let val = String(format: "%.1f", sample.quantity.doubleValue(for: HKUnit(from: "mg/dL")))
            return (val, "mg/dL")
        default:
            let val = String(format: "%.1f", sample.quantity.doubleValue(for: .count()))
            return (val, "")
        }
    }

    private func readTypes(for persona: PersonaRecord) -> Set<HKSampleType> {
        let identifiers = persona.personaType?.relevantHealthTypes ?? PersonaType.personal.relevantHealthTypes
        var types = Set<HKSampleType>()
        for id in identifiers {
            switch id {
            case "heartRate":
                types.insert(HKQuantityType(.heartRate))
            case "stepCount":
                types.insert(HKQuantityType(.stepCount))
            case "bloodPressureSystolic":
                types.insert(HKQuantityType(.bloodPressureSystolic))
            case "bloodPressureDiastolic":
                types.insert(HKQuantityType(.bloodPressureDiastolic))
            case "bloodGlucose":
                types.insert(HKQuantityType(.bloodGlucose))
            case "sleepAnalysis":
                types.insert(HKCategoryType(.sleepAnalysis))
            case "activeEnergyBurned":
                types.insert(HKQuantityType(.activeEnergyBurned))
            case "bodyMass":
                types.insert(HKQuantityType(.bodyMass))
            case "mindfulSession":
                types.insert(HKCategoryType(.mindfulSession))
            case "heartRateVariabilitySDNN":
                types.insert(HKQuantityType(.heartRateVariabilitySDNN))
            case "oxygenSaturation":
                types.insert(HKQuantityType(.oxygenSaturation))
            default:
                break
            }
        }
        return types
    }

    private func randomCanvasPosition() -> CGPoint {
        CGPoint(x: Double.random(in: -600...600), y: Double.random(in: -400...400))
    }
}

// MARK: - HKQuantityType display name helper

private extension HKQuantityType {
    var displayName: String {
        switch self {
        case HKQuantityType(.stepCount):              return "걸음 수"
        case HKQuantityType(.heartRate):              return "심박수"
        case HKQuantityType(.activeEnergyBurned):     return "활동 칼로리"
        case HKQuantityType(.bodyMass):               return "체중"
        case HKQuantityType(.bloodGlucose):           return "혈당"
        case HKQuantityType(.bloodPressureSystolic):  return "수축기 혈압"
        case HKQuantityType(.bloodPressureDiastolic): return "이완기 혈압"
        case HKQuantityType(.heartRateVariabilitySDNN): return "심박수 변동성"
        case HKQuantityType(.oxygenSaturation):       return "산소 포화도"
        default: return identifier
        }
    }
}
