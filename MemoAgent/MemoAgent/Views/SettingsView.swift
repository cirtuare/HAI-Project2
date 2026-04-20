// SettingsView.swift
// MemoAgent — AI Provider Settings
//
// Supports: Apple Intelligence, Claude API, Google AI Studio, OpenAI
// API keys are stored per-provider in macOS Keychain.

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(GraphViewModel.self) private var vm

    enum SettingsTab { case ai, ecosystem }
    @State private var activeTab: SettingsTab = .ai

    @State private var selectedProvider: AIProvider = AIProviderManager.shared.selectedProvider
    // Per-provider key inputs
    @State private var keys: [AIProvider: String] = [:]
    // Per-provider save/test state
    @State private var savedProvider: AIProvider? = nil
    @State private var testingProvider: AIProvider? = nil
    @State private var testResults: [AIProvider: TestResult] = [:]

    private enum TestResult {
        case success(String)
        case failure(String)
        var isSuccess: Bool { if case .success = self { return true }; return false }
        var label: String {
            switch self { case .success(let s): return "✓ \(s)"; case .failure(let f): return "✗ \(f)" }
        }
        var color: Color { isSuccess ? .green : Color(hex: "#f43f5e") }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            // Tab selector
            HStack(spacing: 0) {
                tabButton("AI 설정", tab: .ai, icon: "cpu")
                tabButton("Apple 연동", tab: .ecosystem, icon: "apps.iphone")
            }
            .padding(4)
            .background(Color.white.opacity(0.04))
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if activeTab == .ai {
                        providerSection
                        if selectedProvider.requiresAPIKey {
                            Divider()
                            apiKeySection(for: selectedProvider)
                        }
                    } else {
                        EcosystemPermissionsView()
                            .environment(vm)
                    }
                }
                .padding(24)
            }
        }
        .frame(minWidth: 420, maxWidth: 580)
        .background(Color(hex: "#0f172a"))
        .colorScheme(.dark)
        .onAppear { loadStoredKeys() }
    }

    private func tabButton(_ label: String, tab: SettingsTab, icon: String) -> some View {
        let isActive = activeTab == tab
        return Button { activeTab = tab } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11))
                Text(label).font(.system(size: 12, weight: isActive ? .semibold : .regular))
            }
            .foregroundStyle(isActive ? Color.white.opacity(0.9) : Color.white.opacity(0.4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isActive ? Color.white.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }

    // MARK: Header

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "cpu")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.cyan)
                    .frame(width: 30, height: 30)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.cyan.opacity(0.12)))
                Text("AI 설정")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: Provider Cards

    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AI 제공자")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.4))
                .textCase(.uppercase)

            VStack(spacing: 6) {
                ForEach(AIProvider.allCases, id: \.self) { provider in
                    providerCard(provider)
                }
            }
        }
    }

    private func providerCard(_ provider: AIProvider) -> some View {
        let isSelected = selectedProvider == provider
        let hasKey = !(keys[provider] ?? "").isEmpty
        return Button {
            selectedProvider = provider
            AIProviderManager.shared.selectedProvider = provider
            testResults.removeValue(forKey: provider)
        } label: {
            HStack(spacing: 12) {
                // Radio
                ZStack {
                    Circle().strokeBorder(isSelected ? Color.cyan : Color.white.opacity(0.2), lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    if isSelected {
                        Circle().fill(Color.cyan).frame(width: 10, height: 10)
                    }
                }
                // Icon
                Image(systemName: provider.systemImage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? Color.cyan : Color.white.opacity(0.4))
                    .frame(width: 20)
                // Labels
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.rawValue)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.92) : Color.white.opacity(0.55))
                    Text(provider.description)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
                Spacer()
                // Key status badge
                if provider.requiresAPIKey {
                    Text(hasKey ? "키 설정됨" : "키 필요")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(hasKey ? Color.green.opacity(0.8) : Color.white.opacity(0.25))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(hasKey ? Color.green.opacity(0.1) : Color.white.opacity(0.05)))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.cyan.opacity(0.07) : Color.white.opacity(0.03))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(isSelected ? Color.cyan.opacity(0.4) : Color.white.opacity(0.07),
                                      lineWidth: isSelected ? 1 : 0.5))
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: API Key Section

    private func apiKeySection(for provider: AIProvider) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: provider.systemImage)
                        .font(.system(size: 11))
                        .foregroundStyle(.cyan)
                    Text("\(provider.rawValue) API 키")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .textCase(.uppercase)
                }
                Text(keyPlaceholderHint(for: provider))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.3))
            }

            // Input + Save
            HStack(spacing: 10) {
                SecureField(keyPlaceholder(for: provider), text: bindingKey(for: provider))
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                    )

                let isSaved = savedProvider == provider
                Button {
                    AIProviderManager.shared.saveAPIKey(keys[provider] ?? "", for: provider)
                    savedProvider = provider
                    testResults.removeValue(forKey: provider)
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        if savedProvider == provider { savedProvider = nil }
                    }
                } label: {
                    Text(isSaved ? "저장됨" : "저장")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSaved ? Color.green : .white)
                        .frame(width: 56).padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(isSaved ? Color.green.opacity(0.2) : Color.cyan))
                }
                .buttonStyle(.plain)
                .disabled((keys[provider] ?? "").isEmpty)
            }

            // Test row
            HStack(spacing: 12) {
                let isTesting = testingProvider == provider
                Button { runTest(for: provider) } label: {
                    HStack(spacing: 6) {
                        if isTesting { ProgressView().scaleEffect(0.65).tint(.cyan) }
                        else { Image(systemName: "bolt.fill").font(.system(size: 10)) }
                        Text(isTesting ? "테스트 중…" : "연결 테스트")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.cyan.opacity(0.1))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.cyan.opacity(0.3), lineWidth: 0.5)))
                }
                .buttonStyle(.plain)
                .disabled(isTesting || (keys[provider] ?? "").isEmpty)

                if let result = testResults[provider] {
                    HStack(spacing: 5) {
                        Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(result.color)
                        Text(result.label)
                            .font(.system(size: 11))
                            .foregroundStyle(result.color)
                    }
                    .transition(.opacity)
                }
            }

            // Model tag
            HStack(spacing: 6) {
                Image(systemName: "info.circle").font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.2))
                Text("모델: \(provider.modelName)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.25))
            }
        }
    }

    // MARK: Actions

    private func loadStoredKeys() {
        for provider in AIProvider.allCases where provider.requiresAPIKey {
            keys[provider] = AIProviderManager.shared.loadAPIKey(for: provider) ?? ""
        }
    }

    private func runTest(for provider: AIProvider) {
        // Save current key before testing
        AIProviderManager.shared.saveAPIKey(keys[provider] ?? "", for: provider)
        testingProvider = provider
        testResults.removeValue(forKey: provider)
        Task {
            defer { testingProvider = nil }
            do {
                // Temporarily override provider for test call
                let prev = AIProviderManager.shared.selectedProvider
                AIProviderManager.shared.selectedProvider = provider
                let reply = try await AIProviderManager.shared.callAI(
                    system: "You are a helpful assistant.",
                    userMessage: "Reply with exactly the word: OK",
                    maxTokens: 10
                )
                AIProviderManager.shared.selectedProvider = prev
                await MainActor.run {
                    withAnimation {
                        testResults[provider] = .success(reply.uppercased().contains("OK") ? "연결 성공" : "응답 수신")
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation { testResults[provider] = .failure(error.localizedDescription) }
                }
            }
        }
    }

    // MARK: Helpers

    private func bindingKey(for provider: AIProvider) -> Binding<String> {
        Binding(get: { keys[provider] ?? "" },
                set: { keys[provider] = $0 })
    }

    private func keyPlaceholder(for provider: AIProvider) -> String {
        switch provider {
        case .claudeAPI: return "sk-ant-api03-…"
        case .googleAI:  return "AIza…"
        case .openAI:    return "sk-proj-…"
        default:         return ""
        }
    }

    private func keyPlaceholderHint(for provider: AIProvider) -> String {
        "API 키는 macOS Keychain에 암호화되어 저장됩니다."
    }
}

#Preview {
    SettingsView().frame(width: 520)
}
