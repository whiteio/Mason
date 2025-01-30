import ArgumentParser
import Foundation

struct Mason: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "mason",
    abstract: "A build system for iOS apps",
    version: "1.0.0",
    subcommands: [Build.self, Clean.self],
    defaultSubcommand: Build.self)

  @Flag(name: .shortAndLong, help: "Enable verbose output")
  var verbose = false

  mutating func validate() throws {
    BuildLogger.configure(logToConsole: verbose)
  }
}

Mason.main()
