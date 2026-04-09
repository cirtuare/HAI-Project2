// EcosystemPermissionsView.swift
// MemoAgent V2 — Apple ecosystem permission management panel

import SwiftUI
import HealthKit
import EventKit
import Photos

struct EcosystemPermissionsView: View {
    @Environment(GraphViewModel.self) private var vm

    @State private var healthStatus: PermissionStatus = .unknown
    @State private var calendarStatus: PermissionStatus = .unknown
    @State private var reminderStatus: PermissionStatus = .unknown
    @State private var photoStatus: PermissionStatus = .unknown
    @State private var requestingSource: EcosystemSource? = nil
    @State private var syncMessage: String? = nil

    enum PermissionStatus {
        case unknown, granted, denied, restricted

        var icon: String {
            switch self {
            case .unknown:    return "questionmark.circle"
            case .granted:    return "checkmark.circle.fill"
            case .denied:     return "xmark.circle.fill"
            case .restricted: return "lock.circle.fill"
            }
        }
        var color: Color {
            switch self {
            case .unknown:    return .secondary
            case .granted:    return .green
            case .denied:     return Color(hex: "#f43f5e")
            case .restricted: return .orange
            }
        }
    }

    enum EcosystemSource: String {
        case health, calendar, reminders, photos
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader
            permissionsGrid
            if vm.activePersona != nil {
                syncButton
            } else {
                Text("페르소나를 먼저 선택하면 동기화가 활성화됩니다.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.3))
            }
            if let msg = syncMessage {
                Text(msg)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.cyan.opacity(0.8))
                    .transition(.opacity)
            }
        }
        .onAppear { refreshStatuses() }
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "apps.iphone")
                    .font(.system(size: 11))
                    .foregroundStyle(.cyan)
                Text("APPLE 생태계 연동")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .textCase(.uppercase)
            }
            Text("선택한 Apple 앱 데이터를 로컬에서 읽어 지식 노드로 변환합니다.\n데이터는 기기 밖으로 전송되지 않습니다.")
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.3))
        }
    }

    // MARK: - Permissions Grid

    private var permissionsGrid: some View {
        VStack(spacing: 8) {
            permissionRow(
                source: .health,
                title: "Apple Health",
                icon: "heart.fill",
                description: "심박수, 수면, 걸음 수 등",
                status: healthStatus,
                available: HKHealthStore.isHealthDataAvailable()
            )
            permissionRow(
                source: .calendar,
                title: "캘린더",
                icon: "calendar",
                description: "이벤트를 캘린더 노드로 변환",
                status: calendarStatus,
                available: true
            )
            permissionRow(
                source: .reminders,
                title: "미리 알림",
                icon: "checklist",
                description: "미완료 항목을 노드로 변환",
                status: reminderStatus,
                available: true
            )
            permissionRow(
                source: .photos,
                title: "사진 (메타데이터만)",
                icon: "photo.fill",
                description: "날짜·위치 메타데이터만 읽음, 이미지 저장 없음",
                status: photoStatus,
                available: true
            )
        }
    }

    private func permissionRow(
        source: EcosystemSource,
        title: String,
        icon: String,
        description: String,
        status: PermissionStatus,
        available: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(available ? Color.cyan : Color.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(available ? Color.white.opacity(0.85) : Color.white.opacity(0.3))
                Text(available ? description : "이 기기에서 지원되지 않습니다")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.3))
            }

            Spacer()

            if available {
                if status == .granted {
                    Image(systemName: status.icon)
                        .foregroundStyle(status.color)
                        .font(.system(size: 14))
                } else {
                    let isRequesting = requestingSource == source
                    Button {
                        requestPermission(for: source)
                    } label: {
                        Group {
                            if isRequesting {
                                ProgressView().scaleEffect(0.65).tint(.cyan)
                            } else {
                                Text("허용")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.cyan)
                            }
                        }
                        .frame(width: 44)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.cyan.opacity(0.1))
                                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .strokeBorder(Color.cyan.opacity(0.3), lineWidth: 0.5))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isRequesting)
                }
            } else {
                Image(systemName: "minus.circle")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5))
        )
    }

    // MARK: - Sync Button

    private var syncButton: some View {
        Button {
            vm.triggerEcosystemSync()
            syncMessage = "동기화 시작됨..."
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { syncMessage = nil }
            }
        } label: {
            HStack(spacing: 8) {
                if vm.isSyncing {
                    ProgressView().scaleEffect(0.65).tint(.cyan)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(vm.isSyncing ? "동기화 중..." : "지금 동기화")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.cyan)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.cyan.opacity(0.1))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Color.cyan.opacity(0.3), lineWidth: 0.5))
            )
        }
        .buttonStyle(.plain)
        .disabled(vm.isSyncing)
    }

    // MARK: - Permission Requests

    private func requestPermission(for source: EcosystemSource) {
        requestingSource = source
        Task {
            defer { requestingSource = nil }
            switch source {
            case .health:
                if let persona = vm.activePersona {
                    try? await HealthKitSyncProvider.shared.requestAuthorization(for: persona)
                }
            case .calendar:
                try? await EventKitSyncProvider.shared.requestCalendarAccess()
            case .reminders:
                try? await EventKitSyncProvider.shared.requestReminderAccess()
            case .photos:
                await PhotoKitSyncProvider.shared.requestAuthorization()
            }
            await MainActor.run { refreshStatuses() }
        }
    }

    private func refreshStatuses() {
        // HealthKit
        if HKHealthStore.isHealthDataAvailable() {
            let status = HKHealthStore().authorizationStatus(for: HKQuantityType(.stepCount))
            healthStatus = status == .sharingAuthorized ? .granted : .unknown
        } else {
            healthStatus = .restricted
        }
        // Calendar
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:         calendarStatus = .granted
        case .denied, .restricted: calendarStatus = .denied
        default:                  calendarStatus = .unknown
        }
        // Reminders
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess:         reminderStatus = .granted
        case .denied, .restricted: reminderStatus = .denied
        default:                  reminderStatus = .unknown
        }
        // Photos
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited: photoStatus = .granted
        case .denied, .restricted:  photoStatus = .denied
        default:                    photoStatus = .unknown
        }
    }
}
