// NotificationService.swift
// MemoAgent — Phase 6: macOS UserNotifications integration
//
// Sends local notifications when the background debate agent completes.
// Call requestPermission() once at app launch, then
// sendDebateCompletionNotification(...) from DebateOrchestrator.

import Foundation
import UserNotifications

// MARK: - NotificationService

final class NotificationService: @unchecked Sendable {
    static let shared = NotificationService()
    private init() {}

    // MARK: - Permission

    /// Requests UNUserNotification authorization.
    /// Safe to call multiple times (subsequent calls are no-ops if already granted).
    func requestPermission() async {
        do {
            try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            // Permission denied or unsupported — silently ignore
        }
    }

    // MARK: - Debate completion

    /// Posts a local notification when a background debate finishes.
    /// - Parameters:
    ///   - title:   Short headline (e.g. "AI 분석 완료")
    ///   - summary: One-sentence body from the synthesis rootCause
    func sendDebateCompletionNotification(title: String = "AI 분석 완료", summary: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = summary.isEmpty ? "새로운 인사이트를 확인하세요." : summary
        content.sound = .default
        // macOS badge — increment by 1
        content.badge = 1

        let request = UNNotificationRequest(
            identifier: "debate-\(UUID().uuidString)",
            content: content,
            trigger: nil  // deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Scheduled analysis reminder

    /// Posts a notification reminding the user that a weekly insight is ready.
    func sendWeeklyInsightNotification(nodeCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = "주간 인사이트 생성됨"
        content.body  = "지난 7일간 \(nodeCount)개의 지식 블록을 분석했습니다. 그래프를 확인해보세요."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "weekly-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
