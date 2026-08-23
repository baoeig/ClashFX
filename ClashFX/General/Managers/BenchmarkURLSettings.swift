//
//  BenchmarkURLSettings.swift
//  ClashFX
//

import Foundation

enum BenchmarkURLSettings {
    static let defaultURL = "http://cp.cloudflare.com/generate_204"
    static let supersededBuiltInDefaultURL = "https://cp.cloudflare.com/generate_204"

    static func normalizedURL(_ rawValue: String, defaultURL: String = BenchmarkURLSettings.defaultURL) -> String? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return defaultURL }
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host?.isEmpty == false
        else {
            return nil
        }
        return value
    }

    static func shouldRestoreSupersededBuiltInDefault(
        savedURL: String,
        restorationCompleted: Bool
    ) -> Bool {
        return !restorationCompleted && savedURL == supersededBuiltInDefaultURL
    }
}
