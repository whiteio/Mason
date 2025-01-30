import Testing
@testable import ModuleB

@Suite("ModuleB Tests")
final class ModuleBTests {
  @Test("Basic test example")
  func testExample() throws {
    assert(true)
  }

  @Test("Math test example")
  func testMath() throws {
    assert(2 + 2 == 4)
  }

  @Test("String test example")
  func testString() throws {
    let str = "Hello"
    assert(str.count == 5)
  }
}
