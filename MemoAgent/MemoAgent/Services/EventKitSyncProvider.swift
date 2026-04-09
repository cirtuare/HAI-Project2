// EventKitSyncProvider.swift
// MemoAgent V2 — Calendar and Reminders integration via EventKit

import Foundation
import EventKit
import CoreGraphics

// MARK: - EventKitSyncProvider

final class EventKitSyncProvider {
    static let shared = EventKitSyncProvider()
    private let store = EKEventStore()

    private init() {}

    // MARK: - Authorization

    /// Request full access to Calendar events.
    @discardableResult
    func requestCalendarAccess() async throws -> Bool {
        try await store.requestFullAccessToEvents()
    }

    /// Request full access to Reminders.
    @discardableResult
    func requestReminderAccess() async throws -> Bool {
        try await store.requestFullAccessToReminders()
    }

    var calendarAuthStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    var reminderAuthStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .reminder)
    }

    // MARK: - Calendar Events

    /// Fetch events in a ±15-day rolling window and convert to GraphNodes.
    func fetchCalendarNodes(for persona: PersonaRecord) -> [GraphNode] {
        guard calendarAuthStatus == .fullAccess else { return [] }

        let start = Date().addingTimeInterval(-15 * 86400)
        let end   = Date().addingTimeInterval(15 * 86400)
        let calendars = filteredCalendars(for: persona, type: .event)
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars.isEmpty ? nil : calendars)
        let events = store.events(matching: predicate)

        let formatter = ISO8601DateFormatter()
        return events.compactMap { event -> GraphNode? in
            guard !event.isAllDay || event.title != nil else { return nil }
            let dateStr = formatter.string(from: event.startDate ?? Date()).prefix(10).description
            let duration: String = {
                guard let start = event.startDate, let end = event.endDate else { return "" }
                let mins = Int(end.timeIntervalSince(start) / 60)
                return mins >= 60 ? "\(mins / 60)시간 \(mins % 60)분" : "\(mins)분"
            }()

            return GraphNode(
                id: UUID().uuidString,
                title: event.title ?? "제목 없음",
                summary: [event.location, event.notes?.prefix(80).description]
                    .compactMap { $0 }
                    .joined(separator: " · ")
                    .nilIfEmpty ?? "\(dateStr) 일정",
                type: .calendarEvent,
                date: dateStr,
                originalText: "Calendar: \(event.title ?? "") | \(dateStr) | \(duration) | \(event.location ?? "") | \(event.notes ?? "")",
                isImportant: false,
                tags: ["캘린더", event.calendar.title].filter { !$0.isEmpty },
                position: randomCanvasPosition(),
                sourceSystem: .calendar,
                externalID: event.eventIdentifier,
                personaID: persona.id
            )
        }
    }

    // MARK: - Reminders

    /// Fetch incomplete reminders and convert to GraphNodes.
    func fetchReminderNodes(for persona: PersonaRecord) async -> [GraphNode] {
        guard reminderAuthStatus == .fullAccess else { return [] }

        let calendars = filteredCalendars(for: persona, type: .reminder)
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: calendars.isEmpty ? nil : calendars
        )

        return await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                let formatter = ISO8601DateFormatter()
                let nodes: [GraphNode] = (reminders ?? []).compactMap { reminder in
                    let dateStr = reminder.dueDateComponents.map { comps -> String in
                        let cal = Calendar.current
                        let date = cal.date(from: comps) ?? Date()
                        return formatter.string(from: date).prefix(10).description
                    } ?? formatter.string(from: Date()).prefix(10).description

                    return GraphNode(
                        id: UUID().uuidString,
                        title: reminder.title ?? "미리 알림",
                        summary: reminder.notes?.prefix(120).description ?? "미완료 미리 알림",
                        type: .reminder,
                        date: dateStr,
                        originalText: "Reminder: \(reminder.title ?? "") | due: \(dateStr) | \(reminder.notes ?? "")",
                        isImportant: reminder.priority > 5,
                        tags: ["미리 알림", reminder.calendar.title].filter { !$0.isEmpty },
                        position: randomCanvasPosition(),
                        sourceSystem: .reminders,
                        externalID: reminder.calendarItemIdentifier,
                        personaID: persona.id
                    )
                }
                continuation.resume(returning: nodes)
            }
        }
    }

    // MARK: - Private

    /// Filter calendars by the persona's display name keywords.
    private func filteredCalendars(for persona: PersonaRecord, type: EKEntityType) -> [EKCalendar] {
        let all = store.calendars(for: type)
        guard let pType = persona.personaType else { return all }
        let keywords: [String]
        switch pType {
        case .work:     keywords = ["업무", "work", "회사", "미팅", "meeting"]
        case .academic: keywords = ["학교", "수업", "강의", "study", "academic"]
        case .medical:  keywords = ["건강", "병원", "의료", "health", "medical"]
        case .finance:  keywords = ["재무", "투자", "finance"]
        case .personal: keywords = []
        }
        if keywords.isEmpty { return all }
        let filtered = all.filter { cal in
            keywords.contains { cal.title.lowercased().contains($0.lowercased()) }
        }
        return filtered.isEmpty ? all : filtered
    }

    private func randomCanvasPosition() -> CGPoint {
        CGPoint(x: Double.random(in: -600...600), y: Double.random(in: -400...400))
    }
}

// MARK: - String helpers

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
