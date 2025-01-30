//
//  ParallelBuildTracker.swift
//  mason
//
//  Created by Chris White on 1/29/25.
//

import Foundation

actor ParallelBuildTracker {
  
  // MARK: Private

  private var currentlyBuilding: Set<String> = []
  private var maxConcurrent = 0
  private var buildTimes: [String: (start: TimeInterval, end: TimeInterval)] = [:]

  // MARK: Internal

  func moduleStarted(_ module: String) {
    let now = Date().timeIntervalSince1970
    currentlyBuilding.insert(module)
    buildTimes[module] = (start: now, end: 0)
    maxConcurrent = max(maxConcurrent, currentlyBuilding.count)

    BuildLogger.info("Started building \(module) (Currently building: \(currentlyBuilding.count) modules)")
  }

  func moduleFinished(_ module: String) {
    let now = Date().timeIntervalSince1970
    currentlyBuilding.remove(module)
    buildTimes[module]?.end = now

    BuildLogger.info("Finished building \(module) (Remaining: \(currentlyBuilding.count) modules)")
  }

  func logLevelStatistics(_ level: Int) {
    var totalTime: TimeInterval = 0
    var maxTime: TimeInterval = 0
    var moduleCount = 0

    for (_, times) in buildTimes where times.end != 0 {
      let duration = times.end - times.start
      totalTime += duration
      maxTime = max(maxTime, duration)
      moduleCount += 1
    }

    let averageTime = moduleCount > 0 ? totalTime / Double(moduleCount) : 0

    BuildLogger.info("""
      Level \(level) build statistics:
      - Modules built: \(moduleCount)
      - Maximum concurrent builds: \(maxConcurrent)
      - Average build time: \(String(format: "%.2f", averageTime))s
      - Maximum build time: \(String(format: "%.2f", maxTime))s
      - Total wall clock time: \(String(format: "%.2f", maxTime))s
      - Time saved via parallelization: \(String(format: "%.2f", totalTime - maxTime))s
      """)

    // Clear times for next level
    buildTimes.removeAll()
    maxConcurrent = 0
  }

  func logFinalStatistics() {
    BuildLogger.info("Build complete!")
  }
}
