import Foundation

/// One Agent panel turn: understand, then gate. Execute is a separate call after confirmation.
nonisolated struct AgentTurn: Equatable, Sendable {
    var understand: AgentUnderstandResult
    var evaluation: AgentEvaluation?
    var isOfflineMode: Bool

    var presentation: AgentPresentation {
        if case .needsClarification = understand {
            return .confirmStructured
        }
        return evaluation?.presentation ?? .panel
    }
}

nonisolated struct AgentSession: Sendable {
    var understander: AgentUnderstander
    var coordinator: AgentActionCoordinator
    var isOfflineMode: Bool

    static func make(
        settings: LLMProviderSettings = .disabled,
        calendar: Calendar,
        httpClient: (any HTTPPerforming)? = nil
    ) -> AgentSession {
        AgentSession(
            understander: AgentUnderstander(provider: settings.makeProvider(client: httpClient)),
            coordinator: AgentActionCoordinator(calendar: calendar),
            isOfflineMode: settings.isEnabled == false
        )
    }

    /// Natural-language path: text / speech transcription / OCR text.
    func turn(input: AgentInput, ledger: Ledger, now: Date) async -> AgentTurn {
        let understand = await understander.understand(input: input, ledger: ledger, now: now)
        return assemble(understand: understand, ledger: ledger, now: now)
    }

    /// Locally assembled intent (clarification form, settle button, query chip). No model call.
    func turn(intent: AgentIntent, ledger: Ledger, now: Date) -> AgentTurn {
        assemble(understand: .intent(intent), ledger: ledger, now: now)
    }

    func execute(
        intent: AgentIntent,
        ledger: Ledger,
        now: Date,
        confirmation: AgentConfirmation
    ) throws -> AgentExecution {
        try coordinator.execute(
            intent: intent,
            ledger: ledger,
            now: now,
            confirmation: confirmation
        )
    }

    private func assemble(
        understand: AgentUnderstandResult,
        ledger: Ledger,
        now: Date
    ) -> AgentTurn {
        let evaluation: AgentEvaluation?
        if case .intent(let intent) = understand {
            evaluation = coordinator.evaluate(intent: intent, ledger: ledger, now: now)
        } else {
            evaluation = nil
        }
        return AgentTurn(
            understand: understand,
            evaluation: evaluation,
            isOfflineMode: isOfflineMode
        )
    }
}
