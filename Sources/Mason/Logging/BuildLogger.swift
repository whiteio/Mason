//
//  BuildLogger.swift
//  mason
//
//  Created by Chris White on 1/29/25.
//

import Foundation
import os

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}

enum BuildLogger {
    private static let subsystem = "com.mason.build"
    private static let logger = Logger(subsystem: subsystem, category: "Build")
    private nonisolated(unsafe) static var shouldLogToConsole: Bool = true
    static var isVerbose: Bool { shouldLogToConsole }

    static func configure(logToConsole: Bool = true) {
        shouldLogToConsole = logToConsole
    }

    private static func log(_ level: LogLevel, _ message: String, category: String, file: String = #file, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let prefix = "[\(level.rawValue)] [\(category)] [\(fileName):\(line)]"

        // Log to os_log
        switch level {
        case .debug:
            logger.debug("\(prefix) \(message)")
        case .info:
            logger.info("\(prefix) \(message)")
        case .warning:
            logger.warning("\(prefix) \(message)")
        case .error:
            logger.error("\(prefix) \(message)")
        }

        // Also log to console if enabled
        if shouldLogToConsole && level == .debug || !shouldLogToConsole && level != .debug {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            print("\(timestamp) \(prefix) \(message)")
        }
    }

    static func debug(_ message: String, category: String = "Default", file: String = #file, line: Int = #line) {
        log(.debug, message, category: category, file: file, line: line)
    }

    static func info(_ message: String, category: String = "Default", file: String = #file, line: Int = #line) {
        log(.info, message, category: category, file: file, line: line)
    }

    static func warning(_ message: String, category: String = "Default", file: String = #file, line: Int = #line) {
        log(.warning, message, category: category, file: file, line: line)
    }

    static func error(_ message: String, category: String = "Default", file: String = #file, line: Int = #line) {
        log(.error, message, category: category, file: file, line: line)
    }
}
