import CryptoKit
import Foundation

// MARK: - ModuleCache

/// Manages caching of built modules to enable incremental builds
final class ModuleCache {

  // MARK: Private

  private let fileManager: FileManager
  private let cacheDir: String
  
  // MARK: Lifecycle

  init(cacheDir: String, fileManager: FileManager = .default) {
    self.cacheDir = cacheDir
    self.fileManager = fileManager

    try? fileManager.createDirectory(
      atPath: cacheDir,
      withIntermediateDirectories: true)
  }

  // MARK: Internal

  struct ModuleKey: Hashable, Codable {
    let name: String
    let sourceHash: String
    let dependencyHashes: [String: String] // module name -> hash
    let compilerArgs: String

    var cacheFileName: String {
      // Use first 8 chars of content hash as cache key
      let data = "\(name):\(sourceHash):\(dependencyHashes):\(compilerArgs)".data(using: .utf8)!
      let contentHash: String =
        if #available(macOS 10.15, *) {
          SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        } else {
          SHA256Legacy.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        }
      return "\(name)-\(contentHash.prefix(8))"
    }
  }

  struct CachedModule: Codable {
    let key: ModuleKey
    let timestamp: Date
    let artifacts: [String] // Relative paths to cached files
  }

  /// Computes a hash of the module's source files and dependencies
  func computeModuleKey(
    name: String,
    sourceFiles: [String],
    dependencies: [String: CachedModule],
    compilerArgs: [String])
    throws -> ModuleKey
  {
    // Hash all source files together
    var sourceHash: String
    if #available(macOS 10.15, *) {
      var hasher = CryptoKit.SHA256()
      for file in sourceFiles.sorted() {
        let data = try Data(contentsOf: URL(fileURLWithPath: file))
        hasher.update(data: data)
      }
      sourceHash = hasher.finalize().compactMap { String(format: "%02x", $0) }.joined()
    } else {
      var allData = Data()
      for file in sourceFiles.sorted() {
        let data = try Data(contentsOf: URL(fileURLWithPath: file))
        allData.append(data)
      }
      sourceHash = SHA256Legacy.hash(data: allData).compactMap { String(format: "%02x", $0) }.joined()
    }

    // Include dependency hashes
    var dependencyHashes: [String: String] = [:]
    for (depName, depModule) in dependencies {
      dependencyHashes[depName] = depModule.key.sourceHash
    }

    return ModuleKey(
      name: name,
      sourceHash: sourceHash,
      dependencyHashes: dependencyHashes,
      compilerArgs: compilerArgs.joined(separator: " "))
  }

  /// Checks if a cached version of the module exists
  func hasCachedModule(key: ModuleKey) -> Bool {
    let modulePath = "\(cacheDir)/\(key.cacheFileName)"
    let metadataPath = "\(modulePath)/metadata.json"

    guard fileManager.fileExists(atPath: metadataPath) else {
      return false
    }

    do {
      let data = try Data(contentsOf: URL(fileURLWithPath: metadataPath))
      let cached = try JSONDecoder().decode(CachedModule.self, from: data)

      // Verify all cached artifacts exist
      return cached.artifacts.allSatisfy { artifact in
        fileManager.fileExists(atPath: "\(modulePath)/\(artifact)")
      }
    } catch {
      BuildLogger.warning("Failed to read cache metadata for \(key.name): \(error)")
      return false
    }
  }

  /// Saves a built module to the cache
  func cacheModule(
    key: ModuleKey,
    buildDir: String,
    artifacts: [String] // Relative paths from build dir
  )
    throws
  {
    let modulePath = "\(cacheDir)/\(key.cacheFileName)"

    // Remove any existing cache
    try? fileManager.removeItem(atPath: modulePath)
    try fileManager.createDirectory(atPath: modulePath, withIntermediateDirectories: true)

    // Copy artifacts to cache
    for artifact in artifacts {
      let srcPath = "\(buildDir)/\(artifact)"
      let dstPath = "\(modulePath)/\(artifact)"

      try fileManager.createDirectory(
        atPath: (dstPath as NSString).deletingLastPathComponent,
        withIntermediateDirectories: true)
      try fileManager.copyItem(atPath: srcPath, toPath: dstPath)
    }

    // Save metadata
    let cached = CachedModule(
      key: key,
      timestamp: Date(),
      artifacts: artifacts)
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let data = try encoder.encode(cached)
    try data.write(to: URL(fileURLWithPath: "\(modulePath)/metadata.json"))

    BuildLogger.debug("Cached module \(key.name) with \(artifacts.count) artifacts")
  }

  /// Restores a cached module to the build directory
  func restoreModule(
    key: ModuleKey,
    buildDir: String)
    throws
  {
    let modulePath = "\(cacheDir)/\(key.cacheFileName)"
    let metadataPath = "\(modulePath)/metadata.json"

    let data = try Data(contentsOf: URL(fileURLWithPath: metadataPath))
    let cached = try JSONDecoder().decode(CachedModule.self, from: data)

    // Copy artifacts from cache
    for artifact in cached.artifacts {
      let srcPath = "\(modulePath)/\(artifact)"
      let dstPath = "\(buildDir)/\(artifact)"

      try fileManager.createDirectory(
        atPath: (dstPath as NSString).deletingLastPathComponent,
        withIntermediateDirectories: true)
      try fileManager.copyItem(atPath: srcPath, toPath: dstPath)
    }

    BuildLogger.debug("Restored cached module \(key.name) with \(cached.artifacts.count) artifacts")
  }

  /// Cleans old cache entries
  func cleanCache(olderThan: TimeInterval = 60 * 60 * 24 * 7) throws {
    let contents = try fileManager.contentsOfDirectory(atPath: cacheDir)
    let cutoff = Date().addingTimeInterval(-olderThan)

    for item in contents {
      let itemPath = "\(cacheDir)/\(item)"
      let metadataPath = "\(itemPath)/metadata.json"

      guard
        let metadata = try? Data(contentsOf: URL(fileURLWithPath: metadataPath)),
        let cached = try? JSONDecoder().decode(CachedModule.self, from: metadata)
      else {
        // Invalid cache entry, remove it
        try? fileManager.removeItem(atPath: itemPath)
        continue
      }

      if cached.timestamp < cutoff {
        try fileManager.removeItem(atPath: itemPath)
        BuildLogger.debug("Removed old cache entry for \(cached.key.name)")
      }
    }
  }
}

// MARK: - SHA256Legacy

/// Legacy SHA256 implementation for older systems that don't have CryptoKit
private enum SHA256Legacy {
  static func hash(data: Data) -> [UInt8] {
    // Simple deterministic hash for older systems
    // This is not cryptographically secure but is good enough for caching
    var hash = [UInt8](repeating: 0, count: 32)
    let bytes = [UInt8](data)

    for (index, byte) in bytes.enumerated() {
      hash[index % 32] = hash[index % 32] &+ byte &+ UInt8(index)
    }

    return hash
  }
}
