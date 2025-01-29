//
//  FileOperationActor.swift
//  mason
//
//  Created by Chris White on 1/29/25.
//

import Foundation

actor FileOperationActor {

  // MARK: Lifecycle

  init(fileManager: FileManager = .default) {
    self.fileManager = fileManager
  }

  // MARK: Internal

  func createDirectory(atPath path: String) throws {
    try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
  }

  func findSwiftFiles(in directory: String) throws -> [String] {
    BuildLogger.info("Finding swift files in directory: \(directory)")

    let url = URL(fileURLWithPath: directory)
    let enumerator = fileManager.enumerator(
      at: url,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles])

    var swiftFiles: [String] = []

    while let fileURL = enumerator?.nextObject() as? URL {
      if fileURL.pathExtension == "swift" {
        swiftFiles.append(fileURL.path)
      }
    }

    BuildLogger.debug("Found Swift files: \(swiftFiles)")

    guard !swiftFiles.isEmpty else {
      throw BuildError.compilationFailed("No Swift files found in \(directory)")
    }

    return swiftFiles
  }

  func writeFile(_ content: String, toPath path: String) throws {
    try content.write(toFile: path, atomically: true, encoding: .utf8)
  }

  // MARK: Private

  private let fileManager: FileManager

}
