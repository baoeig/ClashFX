//
//  Logger.swift
//  ClashX
//
//  Created by CYC on 2018/8/7.
//  Copyright © 2018年 yichengchen. All rights reserved.
//

import CocoaLumberjack
import Foundation

private struct CoreLogDecision {
    let entries: [(String, ClashLogLevel)]
    let shouldSignalFatalTunFailure: Bool
}

/// Prevents a broken core loop from turning one error into unbounded file I/O
/// and queued CocoaLumberjack work. State is protected because Starscream may
/// deliver callbacks off the main queue.
private final class CoreLogGuard {
    private let lock = NSLock()
    private let repeatWindow: TimeInterval = 1
    private let fatalSignalInterval: TimeInterval = 2
    private let maximumIdenticalEntries = 3
    private let fatalTunReadError = "batch read packet: socket operation on non-socket"

    private var currentMessage: String?
    private var currentLevel: ClashLogLevel = .info
    private var windowStartedAt = Date.distantPast
    private var emittedCount = 0
    private var suppressedCount = 0
    private var lastFatalSignalAt = Date.distantPast

    func process(message: String, level: ClashLogLevel, now: Date = Date()) -> CoreLogDecision {
        lock.lock()
        defer { lock.unlock() }

        var entries: [(String, ClashLogLevel)] = []
        let isSameWindow = currentMessage == message &&
            now.timeIntervalSince(windowStartedAt) < repeatWindow

        if isSameWindow {
            if emittedCount < maximumIdenticalEntries {
                emittedCount += 1
                entries.append((message, level))
            } else {
                suppressedCount += 1
            }
        } else {
            if let previous = currentMessage, suppressedCount > 0 {
                entries.append((
                    "[Core Log] Suppressed \(suppressedCount) repeated entries: \(previous)",
                    currentLevel
                ))
            }
            currentMessage = message
            currentLevel = level
            windowStartedAt = now
            emittedCount = 1
            suppressedCount = 0
            entries.append((message, level))
        }

        var shouldSignal = false
        if message.contains(fatalTunReadError),
           now.timeIntervalSince(lastFatalSignalAt) >= fatalSignalInterval {
            lastFatalSignalAt = now
            shouldSignal = true
        }

        return CoreLogDecision(entries: entries, shouldSignalFatalTunFailure: shouldSignal)
    }
}

class Logger {
    static let shared = Logger()
    var fileLogger: DDFileLogger = .init()
    private let coreLogGuard = CoreLogGuard()

    private init() {
        #if DEBUG
            DDLog.add(DDOSLogger.sharedInstance)
        #endif
        // default time zone is "UTC"
        let dataFormatter = DateFormatter()
        dataFormatter.setLocalizedDateFormatFromTemplate("YYYY/MM/dd HH:mm:ss:SSS")
        fileLogger.logFormatter = DDLogFileFormatterDefault(dateFormatter: dataFormatter)
        fileLogger.rollingFrequency = TimeInterval(60 * 60 * 24) // 24 hours
        fileLogger.logFileManager.maximumNumberOfLogFiles = 3
        DDLog.add(fileLogger)
        dynamicLogLevel = ConfigManager.selectLoggingApiLevel.toDDLogLevel()
    }

    private func logToFile(msg: String, level: ClashLogLevel) {
        switch level {
        case .debug, .silent:
            DDLogDebug(DDLogMessageFormat(stringLiteral: msg))
        case .error:
            DDLogError(DDLogMessageFormat(stringLiteral: msg))
        case .info:
            DDLogInfo(DDLogMessageFormat(stringLiteral: msg))
        case .warning:
            DDLogWarn(DDLogMessageFormat(stringLiteral: msg))
        case .unknow:
            DDLogWarn(DDLogMessageFormat(stringLiteral: msg))
        }
    }

    static func log(_ msg: String, level: ClashLogLevel = .info, file: String = #file, function: String = #function) {
        shared.logToFile(msg: "[\(level.rawValue)] \(file) \(function) \(msg)", level: level)
    }

    /// Returns true when the message indicates that the active TUN core should
    /// be recovered. Identical core messages are bounded before reaching the
    /// asynchronous file logger.
    @discardableResult
    static func logCore(_ msg: String, level: ClashLogLevel) -> Bool {
        let decision = shared.coreLogGuard.process(message: msg, level: level)
        for (entry, entryLevel) in decision.entries {
            shared.logToFile(
                msg: "[\(entryLevel.rawValue)] [mihomo_core] \(entry)",
                level: entryLevel
            )
        }
        return decision.shouldSignalFatalTunFailure
    }

    func logFilePath() -> String {
        return fileLogger.logFileManager.sortedLogFilePaths.first ?? ""
    }

    func logFolder() -> String {
        return fileLogger.logFileManager.logsDirectory
    }
}
