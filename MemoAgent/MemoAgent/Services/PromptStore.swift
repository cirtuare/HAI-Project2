// PromptStore.swift
// MemoAgent — Centralised prompt registry
//
// Loads prompts.yaml from the app bundle at first access.
// All LLM system prompts are stored there; no prompt literals in Swift source.

import Foundation

// MARK: - PromptKey

enum PromptKey: String {
    // Node extraction (SmartInputModal)
    case nodeExtractionAPI       = "node_extraction_api"
    case nodeExtractionApple     = "node_extraction_apple"

    // Node insight prompts (DetailInspector)
    case singleNodePrompt        = "single_node_prompt"
    case connectedNodePrompt     = "connected_node_prompt"

    // Multi-persona chat
    case personaChatSuffix       = "persona_chat_suffix"       // template: {personaName}
    case personaCrossResponse    = "persona_cross_response"    // template: {personaName}

    // Debate specialist analysis (Round 1)
    case debateSpecialistHealth  = "debate_specialist_health"
    case debateSpecialistWork    = "debate_specialist_work"
    case debateSpecialistFinance = "debate_specialist_finance"
    case debateSpecialistHobby   = "debate_specialist_hobby"
    case debateSpecialistAcademic = "debate_specialist_academic"

    // Debate rebuttal (Round 2) — template: {domainLabel}
    case debateRebuttalTemplate  = "debate_rebuttal_template"

    // Debate synthesis (Round 3)
    case debateSynthesisApple    = "debate_synthesis_apple"
    case debateSynthesisAPI      = "debate_synthesis_api"

    // Debate: HITL synthesis with game theory (replaces Round 3 in manual debate)
    case debateSynthesisHITLApple = "debate_synthesis_hitl_apple"
    case debateSynthesisHITLAPI   = "debate_synthesis_hitl_api"

    // Debate: re-synthesis after human answers reverse questions
    case debateHumanContinue     = "debate_human_continue"

    // Node clustering (NodeManagerAgent)
    case clusterApple            = "cluster_apple"
    case clusterAPI              = "cluster_api"

    // Persona routing (PersonaRouter)
    case personaRouterApple      = "persona_router_apple"

    // Edge relationship generation
    case edgeRelationship        = "edge_relationship"

    // Misc
    case connectionTest          = "connection_test"

    // Persona system-prompt contexts (SourceSystem.PersonaType)
    case personaContextHealth    = "persona_context_health"
    case personaContextAcademic  = "persona_context_academic"
    case personaContextFinance   = "persona_context_finance"
    case personaContextHobby     = "persona_context_hobby"
    case personaContextOther     = "persona_context_other"
}

// MARK: - PromptStore

final class PromptStore {
    static let shared = PromptStore()
    private var prompts: [String: String] = [:]

    private init() {
        guard let url     = Bundle.main.url(forResource: "prompts", withExtension: "yaml"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            assertionFailure("PromptStore: prompts.yaml missing or malformed in bundle")
            return
        }
        prompts = PromptStore.parseYAML(content)
    }

    /// Returns the prompt string for the given key, or an empty string if not found.
    func prompt(for key: PromptKey) -> String {
        prompts[key.rawValue] ?? ""
    }

    /// Returns the prompt with every occurrence of `{placeholder}` replaced by `value`.
    func prompt(for key: PromptKey, replacing placeholder: String, with value: String) -> String {
        prompt(for: key).replacingOccurrences(of: "{\(placeholder)}", with: value)
    }

    // MARK: - YAML Parser

    /// Minimal YAML parser for the prompts.yaml format.
    ///
    /// Supported subset:
    /// ```yaml
    /// prompts:
    ///   some_key: |
    ///     Line one of the value.
    ///     Line two of the value.
    ///
    ///   next_key: |
    ///     Single-line value.
    /// ```
    /// Rules:
    /// - Lines beginning with `#` and empty lines are ignored at the top level.
    /// - The section header `prompts:` activates key parsing.
    /// - Keys must be at exactly 2-space indent, followed by `: |`.
    /// - Block content must be at exactly 4-space indent (or be empty).
    /// - Trailing empty lines in each block are stripped (standard `|` chomping).
    private static func parseYAML(_ content: String) -> [String: String] {
        var result: [String: String] = [:]
        let lines = content.components(separatedBy: "\n")
        var i = 0
        var inPromptsSection = false

        while i < lines.count {
            let raw = lines[i]
            let trimmed = raw.trimmingCharacters(in: .whitespaces)

            // Skip blank lines and comments at every level
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                i += 1
                continue
            }

            // Section header
            if trimmed == "prompts:" {
                inPromptsSection = true
                i += 1
                continue
            }

            guard inPromptsSection else { i += 1; continue }

            // Key line: exactly "  <key>: |"
            // Must start with 2 spaces (not 3+), and end with ": |"
            guard raw.hasPrefix("  "), !raw.hasPrefix("   "),
                  raw.hasSuffix(": |") else { i += 1; continue }

            let key = String(raw.dropFirst(2).dropLast(3)) // strip "  " prefix and ": |" suffix
            guard !key.isEmpty else { i += 1; continue }

            i += 1

            // Collect block scalar content (4-space indent or empty line)
            var blockLines: [String] = []
            while i < lines.count {
                let blockRaw = lines[i]
                if blockRaw.isEmpty {
                    blockLines.append("")
                    i += 1
                } else if blockRaw.hasPrefix("    ") {
                    blockLines.append(String(blockRaw.dropFirst(4)))
                    i += 1
                } else {
                    break  // dedented line ends the block
                }
            }

            // Strip trailing empty lines (YAML `|` default chomping behaviour)
            while blockLines.last?.isEmpty == true {
                blockLines.removeLast()
            }

            result[key] = blockLines.joined(separator: "\n")
        }

        return result
    }
}
