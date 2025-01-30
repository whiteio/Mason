import ModuleB

public struct World {
  private let hello: Hello
  public let example: String
  public init() {
    hello = Hello()
    example = hello.example
  }
}
