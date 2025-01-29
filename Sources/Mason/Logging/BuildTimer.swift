//
//  BuildTimer.swift
//  mason
//
//  Created by Chris White on 1/29/25.
//

import Foundation

actor BuildTimer {

  // MARK: Internal

  static func start(_ phase: String) async {
    await shared.startTimer(phase)
  }

  static func end(_ phase: String) async {
    await shared.endTimer(phase)
  }

  static func reset() async {
    await shared.resetTimers()
  }

  static func summarize() async {
    await shared.summarizeTimers()
  }

  // MARK: Private

  private static let shared = BuildTimer()

  private var timers: [String: CFAbsoluteTime] = [:]
  private var measurements: [(String, TimeInterval)] = []

  private func startTimer(_ phase: String) {
    timers[phase] = CFAbsoluteTimeGetCurrent()
    // Only log start in verbose mode
    if BuildLogger.isVerbose {
      BuildLogger.debug("Starting phase: \(phase)", category: "BuildTimer")
    }
  }

  private func endTimer(_ phase: String) {
    guard let startTime = timers[phase] else {
      BuildLogger.warning("Attempted to end timer for unknown phase: \(phase)", category: "BuildTimer")
      return
    }

    let duration = CFAbsoluteTimeGetCurrent() - startTime
    measurements.append((phase, duration))
    timers.removeValue(forKey: phase)

    // Only log individual completions in verbose mode
    if BuildLogger.isVerbose {
      BuildLogger.info("\(phase) completed in \(String(format: "%.2f", duration))s", category: "BuildTimer")
    }
  }

  private func resetTimers() {
    timers.removeAll()
    measurements.removeAll()
  }

  private func summarizeTimers() {
    guard !measurements.isEmpty else { return }

    let totalTime = measurements.reduce(0.0) { $0 + $1.1 }
    var summary = "\nBuild Summary:"
    summary += "\n-------------"

    // Sort phases by duration for better readability
    let sortedMeasurements = measurements.sorted { $0.1 > $1.1 }

    for (phase, duration) in sortedMeasurements {
      let percentage = (duration / totalTime) * 100
      summary += "\n\(phase): \(String(format: "%.2f", duration))s (\(String(format: "%.1f", percentage))%)"
    }

    summary += "\n-------------"
    summary += "\nTotal Build Time: \(String(format: "%.2f", totalTime))s"

    // Always show summary, regardless of verbose mode
    print(summary)
  }
}
