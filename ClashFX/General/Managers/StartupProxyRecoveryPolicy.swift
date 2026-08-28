//
//  StartupProxyRecoveryPolicy.swift
//  ClashFX
//

import Foundation

struct StartupProxyRecoveryObservation {
    let wantsSystemProxy: Bool
    let proxyPaused: Bool
    let enhancedModeActive: Bool
    let initialConfigLoaded: Bool
    let coreRunning: Bool
    let httpPort: Int
    let socksPort: Int
    let helperReady: Bool
    let primaryInterfaceReady: Bool
}

enum StartupProxyRecoveryDecision: Equatable {
    case stop
    case waitForConfig
    case waitForCore
    case waitForHelper
    case waitForNetwork
    case verifyAndApply
}

enum StartupProxyRecoveryPolicy {
    static func decide(_ observation: StartupProxyRecoveryObservation) -> StartupProxyRecoveryDecision {
        guard observation.wantsSystemProxy,
              !observation.proxyPaused,
              !observation.enhancedModeActive else {
            return .stop
        }
        guard observation.initialConfigLoaded,
              observation.httpPort > 0,
              observation.socksPort > 0 else {
            return .waitForConfig
        }
        guard observation.coreRunning else { return .waitForCore }
        guard observation.helperReady else { return .waitForHelper }
        guard observation.primaryInterfaceReady else { return .waitForNetwork }
        return .verifyAndApply
    }
}

enum RuntimeDataPlaneProbeOutcome {
    case healthy
    case confirmedCoreFailure
    case baselineUnavailable
}

enum RuntimeDataPlaneFailurePolicy {
    static func nextFailureCount(
        current: Int,
        outcome: RuntimeDataPlaneProbeOutcome
    ) -> Int {
        switch outcome {
        case .healthy:
            return 0
        case .confirmedCoreFailure:
            return current + 1
        case .baselineUnavailable:
            // An unavailable independent baseline is inconclusive. Preserve the
            // prior evidence but neither forgive it nor count a new failure.
            return current
        }
    }
}

enum WakeRecoveryRetryPolicy {
    static func delay(
        baseDelay: TimeInterval,
        maximumAttempts: Int,
        attemptsLeft: Int
    ) -> TimeInterval {
        let completedAttempts = max(0, maximumAttempts - attemptsLeft)
        return min(baseDelay * pow(2, Double(completedAttempts)), 8)
    }
}

enum PortPreferencePolicy {
    static func editableText(configuredPort: Int) -> String {
        configuredPort > 0 ? String(configuredPort) : ""
    }

    static func configuredPort(from input: String) -> Int? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        guard let port = Int(trimmed), (1 ... 65_535).contains(port) else {
            return nil
        }
        return port
    }

    static func runtimeFallback(
        configuredPort: Int,
        runtimePort: Int
    ) -> (configured: Int, runtime: Int)? {
        guard configuredPort > 0,
              runtimePort > 0,
              configuredPort != runtimePort else { return nil }
        return (configuredPort, runtimePort)
    }
}
