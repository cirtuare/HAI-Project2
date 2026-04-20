// SmartInputModalView.swift
// MemoAgent — Phase 4: Smart Input Modal
//
// Full port of SmartInputModal.tsx.
// Two-column layout: left = text/file input, right = AI processing pipeline.
// Mirrors the simulated 3-step AI animation (extracting → chunking → done).

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PDFKit
import SwiftData

struct SmartInputModalView: View {
    @Environment(GraphViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            modalHeader
            Divider()
            HStack(spacing: 0) {
                inputColumn
                    .frame(maxWidth: .infinity)
                Divider()
                processingColumn
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(minWidth: 680, maxWidth: .infinity, minHeight: 460, maxHeight: .infinity)
        .background(Color(hex: "#1e293b"))  // surface-elevated
        .colorScheme(.dark)  // force dark so .primary/.secondary resolve to white-family
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.4), radius: 40, y: 12)
    }

    // ─────────────────────────────────────────────
    // MARK: Header
    // ─────────────────────────────────────────────

    private var modalHeader: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.cyan)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.cyan.opacity(0.12))
                    )
                Text("새로운 지식 추가")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
            }
            Spacer()
            Button {
                dismiss()
                vm.isAddModalPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.primary.opacity(0.07)))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // ─────────────────────────────────────────────
    // MARK: Left Column — Input
    // ─────────────────────────────────────────────

    private var inputColumn: some View {
        @Bindable var vm = vm
        return VStack(spacing: 0) {
            // Tab picker
            HStack(spacing: 0) {
                ForEach(InputTab.allCases, id: \.self) { tab in
                    tabButton(tab)
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Input area
            Group {
                switch vm.modalInputTab {
                case .text:       textInputArea
                case .file:       fileDropArea
                case .screenTime: screenTimeInputArea
                case .finance:    financeInputArea
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            // Persona picker — visible when at least one persona exists
            if !vm.personas.isEmpty {
                personaPickerRow
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
            }

            // Action button (changes based on active tab)
            Group {
                switch vm.modalInputTab {
                case .text, .file:  analyseButton
                case .screenTime:   screenTimeSaveButton
                case .finance:      financeSaveButton
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color(hex: "#0f172a").opacity(0.5))
    }

    private func tabButton(_ tab: InputTab) -> some View {
        @Bindable var vm = vm
        let isActive = vm.modalInputTab == tab
        return Button { vm.modalInputTab = tab } label: {
            Text(tab.rawValue)
                .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? Color.white.opacity(0.92) : Color.white.opacity(0.45))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isActive ? Color(hex: "#1e293b") : Color.clear)
                        .shadow(color: .black.opacity(isActive ? 0.15 : 0), radius: 4, y: 1)
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: vm.modalInputTab)
    }

    private var textInputArea: some View {
        @Bindable var vm = vm
        return VStack(spacing: 10) {
            TextField("제목을 입력하세요", text: $vm.modalTitleInput)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.92))
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )

            TextEditor(text: $vm.modalBodyInput)
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.85))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 180)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
        }
    }

    // ─────────────────────────────────────────────
    // MARK: Screen Time Tab
    // ─────────────────────────────────────────────

    private var screenTimeInputArea: some View {
        @Bindable var vm = vm
        return VStack(alignment: .leading, spacing: 10) {
            Label("iOS 스크린타임 주간 리포트를 붙여넣으세요", systemImage: "hourglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.5))

            TextEditor(text: $vm.modalScreenTimeInput)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.85))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 200)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )

            if vm.modalScreenTimeSavedCount > 0 {
                Label("\(vm.modalScreenTimeSavedCount)개의 노드가 저장되었습니다", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#1D9E75"))
            }
        }
    }

    private var screenTimeSaveButton: some View {
        @Bindable var vm = vm
        let isBusy = vm.modalScreenTimeSaving
        return Button {
            vm.commitScreenTimeReport()
        } label: {
            HStack(spacing: 8) {
                if isBusy {
                    ProgressSpinner()
                    Text("저장 중...")
                } else {
                    Image(systemName: "hourglass")
                    Text("스크린타임 저장")
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isBusy ? Color.secondary : Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(isBusy ? Color.primary.opacity(0.08) : Color(hex: "#1D9E75"))
            )
        }
        .buttonStyle(.plain)
        .disabled(isBusy || vm.modalScreenTimeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    // ─────────────────────────────────────────────
    // MARK: Finance Tab
    // ─────────────────────────────────────────────

    private var financeInputArea: some View {
        @Bindable var vm = vm
        return VStack(alignment: .leading, spacing: 10) {
            Label("카드 명세서 또는 지출 내역 텍스트를 붙여넣으세요", systemImage: "creditcard.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.5))

            TextEditor(text: $vm.modalFinanceInput)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.85))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 200)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )

            if vm.modalFinanceSavedCount > 0 {
                Label("\(vm.modalFinanceSavedCount)건의 지출 항목이 저장되었습니다", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#EF9F27"))
            }
        }
    }

    private var financeSaveButton: some View {
        @Bindable var vm = vm
        let isBusy = vm.modalFinanceSaving
        return Button {
            vm.commitFinanceStatement()
        } label: {
            HStack(spacing: 8) {
                if isBusy {
                    ProgressSpinner()
                    Text("분석 중...")
                } else {
                    Image(systemName: "creditcard.fill")
                    Text("지출 내역 저장")
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isBusy ? Color.secondary : Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(isBusy ? Color.primary.opacity(0.08) : Color(hex: "#EF9F27"))
            )
        }
        .buttonStyle(.plain)
        .disabled(isBusy || vm.modalFinanceInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @State private var isDropTargeted = false

    private var fileDropArea: some View {
        VStack(spacing: 14) {
            if let fileName = vm.modalUploadFileName {
                // File loaded state
                VStack(spacing: 10) {
                    Image(systemName: "doc.fill.badge.checkmark")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(Color.cyan)
                    Text(fileName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    Text("파일이 준비되었습니다")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.cyan.opacity(0.8))
                    Button {
                        vm.modalUploadFileName = nil
                        vm.modalUploadFileLoaded = false
                        vm.modalTitleInput = ""
                        vm.modalBodyInput = ""
                    } label: {
                        Text("다시 선택")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.white.opacity(0.07))
                            )
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Empty state
                Image(systemName: "arrow.up.doc")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(isDropTargeted ? Color.cyan : Color.white.opacity(0.3))
                Text("파일을 여기에 끌어다 놓으세요")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.65))
                Text("PDF · TXT · Markdown 지원")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.35))
                Button {
                    openFilePicker()
                } label: {
                    Text("파일 찾아보기")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.cyan)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.cyan.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .strokeBorder(Color.cyan.opacity(0.3), lineWidth: 0.5)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isDropTargeted ? Color.cyan.opacity(0.07) : Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                        )
                        .foregroundStyle(
                            isDropTargeted ? Color.cyan.opacity(0.6) : Color.white.opacity(0.12)
                        )
                )
        )
        .animation(.easeInOut(duration: 0.15), value: isDropTargeted)
        // Native drag-and-drop
        .onDrop(of: [.fileURL, .pdf, .plainText, .data], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf, .plainText, .init(filenameExtension: "md")!,
                                     .init(filenameExtension: "markdown")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "파일 선택"
        panel.message = "지식 노드로 변환할 파일을 선택하세요"
        panel.prompt = "선택"

        if panel.runModal() == .OK, let url = panel.url {
            loadFile(url: url)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async { loadFile(url: url) }
            }
            return true
        }
        return false
    }

    private func loadFile(url: URL) {
        let name = url.lastPathComponent
        var content = ""
        let ext = url.pathExtension.lowercased()

        if ext == "pdf" {
            // PDFKit — reliable text layer extraction
            if let pdf = PDFDocument(url: url) {
                var pages: [String] = []
                for i in 0..<pdf.pageCount {
                    if let page = pdf.page(at: i), let text = page.string {
                        pages.append(text)
                    }
                }
                content = pages.joined(separator: "\n\n")
            }
            if content.isEmpty {
                content = "(PDF 텍스트 추출 불가 — 이미지 기반 PDF이거나 보안이 걸려 있을 수 있습니다)"
            }
        } else {
            content = (try? String(contentsOf: url, encoding: .utf8))
                ?? (try? String(contentsOf: url, encoding: .isoLatin1))
                ?? ""
        }

        let title = url.deletingPathExtension().lastPathComponent
        vm.modalUploadFileName = name
        vm.modalUploadFileLoaded = true
        vm.modalTitleInput = title
        // Truncate to 3000 chars to keep processing reasonable
        vm.modalBodyInput = String(content.prefix(3000))
    }

    // ─────────────────────────────────────────────
    // MARK: Persona Picker Row
    // ─────────────────────────────────────────────

    private var personaPickerRow: some View {
        @Bindable var vm = vm
        return VStack(alignment: .leading, spacing: 6) {
            Text("담당 페르소나")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.35))
                .kerning(0.5)

            HStack(spacing: 6) {
                // "없음" pill
                personaPickerPill(id: nil, name: "없음", colorHex: "#64748b", icon: "person.slash")

                ForEach(vm.personas, id: \.id) { persona in
                    personaPickerPill(
                        id: persona.id,
                        name: persona.name,
                        colorHex: persona.accentColorHex,
                        icon: persona.personaType?.icon ?? "person.fill"
                    )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
    }

    private func personaPickerPill(id: String?, name: String, colorHex: String, icon: String) -> some View {
        let accent   = Color(hex: colorHex)
        let isActive = vm.modalSelectedPersonaID == id

        return Button {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                vm.modalSelectedPersonaID = isActive ? nil : id
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(isActive ? .white : accent.opacity(0.8))
                Text(name)
                    .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? .white : Color.white.opacity(0.55))
                    .lineLimit(1)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(isActive ? accent : accent.opacity(0.12))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(
                                isActive ? Color.clear : accent.opacity(0.25),
                                lineWidth: 0.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }

    private var analyseButton: some View {
        let isProcessing = vm.modalProcessStep != .idle
        return Button {
            vm.startModalAnalysis()
        } label: {
            HStack(spacing: 8) {
                if isProcessing {
                    ProgressSpinner()
                    Text("AI 분석 중...")
                } else {
                    Text("🫷 고민 전가하기")
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isProcessing ? Color.secondary : Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(isProcessing ? Color.primary.opacity(0.08) : Color.cyan)
            )
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
        .animation(.easeInOut(duration: 0.2), value: isProcessing)
    }

    // ─────────────────────────────────────────────
    // MARK: Right Column — AI Processing
    // ─────────────────────────────────────────────

    private var processingColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch vm.modalInputTab {
            case .text, .file:
                if vm.modalProcessStep == .idle {
                    idlePlaceholder
                } else {
                    processingView
                }
            case .screenTime:
                screenTimeGuidePanel
            case .finance:
                financeGuidePanel
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
        .background(Color(hex: "#020617").opacity(0.4))
    }

    private var idlePlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "network")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(Color.white.opacity(0.12))
            Text("AI 분석 결과가 여기에 표시됩니다")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.25))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var screenTimeGuidePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("스크린타임 리포트 사용 방법", systemImage: "info.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: "#1D9E75"))

            guideStep("1", "iPhone → 설정 → 스크린 타임")
            guideStep("2", "\"모든 활동 보기\" → 우측 상단 공유 버튼")
            guideStep("3", "텍스트를 복사하여 왼쪽 입력란에 붙여넣기")

            Divider().opacity(0.15)

            Text("파싱 후 건강(health) 페르소나의\n노드로 자동 저장됩니다.")
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.4))
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var financeGuidePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("지출 내역 입력 방법", systemImage: "info.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: "#EF9F27"))

            guideStep("1", "카드사 앱 → 이용 내역 → 텍스트 복사")
            guideStep("2", "또는 PDF 명세서에서 텍스트 추출")
            guideStep("3", "왼쪽 입력란에 붙여넣기 후 저장")

            Divider().opacity(0.15)

            Text("날짜·금액·가맹점명이 자동으로\n파싱되어 카테고리별로 분류됩니다.")
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.4))
                .lineSpacing(4)

            Text("지원 형식: ₩X,XXX / X,XXX원 / X원")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.25))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func guideStep(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.9))
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.white.opacity(0.1)))
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var processingView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Pipeline status bar
            VStack(alignment: .leading, spacing: 8) {
                Text("처리 현황")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
                pipelineStatusBar
            }

            Divider()

            // Discovered nodes — scrollable, fills remaining space
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if vm.modalProcessStep == .done {
                        // Show real AI-analysed nodes
                        if let errorMsg = vm.modalAIError {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.system(size: 12))
                                Text(errorMsg)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.white.opacity(0.6))
                                    .lineLimit(3)
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.orange.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(Color.orange.opacity(0.2), lineWidth: 0.5)
                                    )
                            )
                        }
                        ForEach(Array(vm.modalAnalysedNodes.enumerated()), id: \.offset) { idx, node in
                            processingNodeCard(
                                title: node.title,
                                summary: node.summary,
                                tags: node.tags,
                                isImportant: node.isImportant,
                                delay: Double(idx) * 0.25
                            )
                        }
                    } else if vm.modalProcessStep != .idle {
                        // Still analysing (.extracting or .chunking) — show a spinner
                        HStack(spacing: 10) {
                            ProgressSpinner()
                                .foregroundStyle(.cyan)
                            Text(AIProviderManager.shared.selectedProvider == .appleIntelligence
                                 ? "Apple Intelligence가 노드를 추출하고 있습니다…"
                                 : "\(AIProviderManager.shared.selectedProvider.rawValue)가 노드를 추출하고 있습니다…")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.white.opacity(0.5))
                        }
                        .padding(12)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Completion CTA — pinned to bottom
            if vm.modalProcessStep == .done {
                Divider()
                completionFooter
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: vm.modalProcessStep)
    }

    // ── Pipeline status ───────────────────────────────────────────────

    private var pipelineStatusBar: some View {
        HStack(spacing: 6) {
            pipelineBadge(label: "텍스트 추출",
                          active: vm.modalProcessStep.rawValue >= 1,
                          done:   vm.modalProcessStep.rawValue > 1)
            connectorLine(lit: vm.modalProcessStep.rawValue >= 2)
            pipelineBadge(label: "의미 단위 분할",
                          active: vm.modalProcessStep.rawValue >= 2,
                          done:   vm.modalProcessStep.rawValue > 2)
            connectorLine(lit: vm.modalProcessStep == .done)
            pipelineBadge(label: "노드 생성",
                          active: vm.modalProcessStep == .done,
                          done:   vm.modalProcessStep == .done)
        }
    }

    private func pipelineBadge(label: String, active: Bool, done: Bool) -> some View {
        HStack(spacing: 4) {
            if done {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.cyan)
            }
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(done ? Color.cyan : active ? Color.primary : Color.secondary)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(done ? Color.cyan.opacity(0.12)
                           : active ? Color.primary.opacity(0.08)
                           : Color.primary.opacity(0.04))
                .overlay(
                    Capsule()
                        .strokeBorder(
                            done ? Color.cyan.opacity(0.3) : Color.primary.opacity(0.1),
                            lineWidth: 0.5
                        )
                )
        )
        .animation(.easeInOut(duration: 0.3), value: done)
    }

    private func connectorLine(lit: Bool) -> some View {
        Rectangle()
            .fill(lit ? Color.cyan : Color.primary.opacity(0.15))
            .frame(width: 20, height: 1)
            .animation(.easeInOut(duration: 0.4), value: lit)
    }

    // ── Processing node card ──────────────────────────────────────────

    private func processingNodeCard(
        title: String,
        summary: String,
        tags: String,
        isImportant: Bool,
        delay: Double
    ) -> some View {
        let tagList = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Important star indicator
                if isImportant {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.yellow)
                }
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .lineLimit(2)
                Spacer(minLength: 0)
            }

            if !summary.isEmpty {
                Text(summary)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .lineLimit(2)
            }

            if !tagList.isEmpty {
                HStack(spacing: 4) {
                    ForEach(tagList.prefix(4), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.cyan.opacity(0.8))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.cyan.opacity(0.08))
                            )
                    }
                }
            }

            // Animated progress bar
            GeometryReader { _ in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                    ProgressBarFill(delay: delay)
                }
            }
            .frame(height: 3)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isImportant ? Color.yellow.opacity(0.04) : Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            isImportant ? Color.yellow.opacity(0.15) : Color.primary.opacity(0.08),
                            lineWidth: 0.5
                        )
                )
        )
        .transition(
            .asymmetric(
                insertion: .offset(x: -16).combined(with: .opacity),
                removal:   .opacity
            )
        )
    }

    // ── Completion footer ─────────────────────────────────────────────

    private var completionFooter: some View {
        VStack(spacing: 12) {
            HStack {
                let count = vm.modalAnalysedNodes.count
                Text("새로운 지식 노드 \(count)개가 발견되었습니다.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.7))
                Spacer()
            }

            Button {
                vm.commitModalNodes()
            } label: {
                Label("그래프에 저장하기", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Color.cyan)
                            .shadow(color: .cyan.opacity(0.3), radius: 8, y: 2)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - ProgressBarFill

/// Animates from 0 → full width after a delay, simulating chunk analysis.
private struct ProgressBarFill: View {
    let delay: Double
    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { g in
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.cyan)
                .frame(width: g.size.width * progress)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).delay(delay + 0.2)) {
                progress = 1.0
            }
        }
    }
}

// MARK: - ProgressSpinner

/// Rotating sparkle icon — replaces Framer Motion's rotating spinner.
private struct ProgressSpinner: View {
    @State private var angle: Double = 0

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: 14))
            .rotationEffect(.degrees(angle))
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    angle = 360
                }
            }
    }
}

#Preview {
    let container = try! ModelContainer(for: NodeRecord.self, EdgeRecord.self, PersonaRecord.self,
                                        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    SmartInputModalView()
        .environment(GraphViewModel(modelContext: container.mainContext))
}
