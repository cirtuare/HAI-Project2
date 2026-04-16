// PersonaEditSheet.swift
// MemoAgent — Task 2: Persona add / edit sheet

import SwiftUI
import SwiftData

// MARK: - PersonaEditSheet

/// Sheet used for both adding a new persona and renaming an existing one.
///
/// - **Add mode** (`editing == nil`): Shows a 2×2 PersonaType picker.
///   The user selects a type; an optional custom name can override the default.
/// - **Edit mode** (`editing != nil`): Shows only the name text field.
///   PersonaType is fixed for existing personas.
struct PersonaEditSheet: View {
    @Environment(GraphViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    /// When nil the sheet is in "add" mode; otherwise "edit" mode.
    var editing: PersonaRecord?

    // ── State ──────────────────────────────────────────────────────
    @State private var selectedType: PersonaType? = nil
    @State private var customName: String = ""
    @FocusState private var nameFieldFocused: Bool

    // ── Derived ────────────────────────────────────────────────────
    private var isEditMode: Bool { editing != nil }

    private var resolvedName: String {
        let trimmed = customName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { return trimmed }
        return selectedType?.localizedName ?? ""
    }

    private var canConfirm: Bool {
        if isEditMode {
            return !customName.trimmingCharacters(in: .whitespaces).isEmpty
        } else {
            return selectedType != nil
        }
    }

    // ── Body ───────────────────────────────────────────────────────
    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(isEditMode ? "페르소나 이름 변경" : "페르소나 추가")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider().opacity(0.4)

            ScrollView {
                VStack(spacing: 20) {
                    if !isEditMode {
                        typePickerSection
                    }
                    nameFieldSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }

            Divider().opacity(0.4)

            // Action buttons
            HStack(spacing: 10) {
                Button("취소") { dismiss() }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.secondary.opacity(0.1))
                    )

                Spacer()

                Button(isEditMode ? "변경" : "추가") {
                    commit()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(canConfirm ? .white : Color.white.opacity(0.35))
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(canConfirm
                              ? accentColor
                              : accentColor.opacity(0.25))
                )
                .disabled(!canConfirm)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 380)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear { setup() }
    }

    // ── Sub-views ──────────────────────────────────────────────────

    private var typePickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("유형 선택")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .kerning(0.5)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(PersonaType.allCases, id: \.self) { type in
                    typeCell(type)
                }
            }
        }
    }

    private func typeCell(_ type: PersonaType) -> some View {
        let accent = Color(hex: type.accentHex)
        let isSelected = selectedType == type
        let alreadyExists = vm.personas.contains { $0.personaType == type }

        return Button {
            if !alreadyExists {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                    selectedType = type
                }
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? accent : accent.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: type.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : accent)
                }
                Text(type.localizedName)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                Text(type.description)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.secondary.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.1) : Color.secondary.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                isSelected ? accent.opacity(0.6) : Color.clear,
                                lineWidth: 1.5
                            )
                    )
            )
            .opacity(alreadyExists && !isSelected ? 0.4 : 1.0)
            .overlay(
                // "이미 추가됨" badge
                alreadyExists && !isSelected
                    ? Text("추가됨")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.secondary.opacity(0.5)))
                        .padding(6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    : nil
            )
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!alreadyExists)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private var nameFieldSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isEditMode ? "새 이름" : "이름 (선택 사항)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .kerning(0.5)

            HStack(spacing: 8) {
                if isEditMode, let type = editing?.personaType {
                    Image(systemName: type.icon)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: type.accentHex))
                        .frame(width: 18)
                }

                TextField(
                    isEditMode
                        ? (editing?.name ?? "")
                        : (selectedType.map { "기본: \($0.localizedName)" } ?? "이름 입력"),
                    text: $customName
                )
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($nameFieldFocused)
                .onSubmit { if canConfirm { commit() } }

                if !customName.isEmpty {
                    Button {
                        customName = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                nameFieldFocused
                                    ? accentColor.opacity(0.5)
                                    : Color.secondary.opacity(0.2),
                                lineWidth: 1
                            )
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: nameFieldFocused)
        }
    }

    // ── Helpers ────────────────────────────────────────────────────

    private var accentColor: Color {
        if isEditMode, let type = editing?.personaType {
            return Color(hex: type.accentHex)
        }
        return selectedType.map { Color(hex: $0.accentHex) } ?? Color.cyan
    }

    private func setup() {
        if let persona = editing {
            customName = persona.name
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                nameFieldFocused = true
            }
        }
    }

    private func commit() {
        if let persona = editing {
            // Edit mode — rename only
            let newName = customName.trimmingCharacters(in: .whitespaces)
            guard !newName.isEmpty else { return }
            vm.updatePersonaName(id: persona.id, name: newName)
        } else {
            // Add mode — create new PersonaRecord
            guard let type = selectedType else { return }
            let record = PersonaRecord.make(from: type)
            if !customName.trimmingCharacters(in: .whitespaces).isEmpty {
                record.name = customName.trimmingCharacters(in: .whitespaces)
            }
            vm.createPersona(record)
        }
        dismiss()
    }
}

#Preview {
    let container = try! ModelContainer(for: NodeRecord.self, EdgeRecord.self, PersonaRecord.self,
                                        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    PersonaEditSheet()
        .environment(GraphViewModel(modelContext: container.mainContext))
}
