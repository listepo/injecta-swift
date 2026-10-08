import InjectaMacros
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

let macros: [String: Macro.Type] = [
  "Injectable": InjectableMacro.self,
  "Inject": InjectMacro.self,
  "Container": ContainerMacro.self,
  "Singleton": SingletonMacro.self,
  "Transient": TransientMacro.self,
  "Forward": ForwardMacro.self,
  "Provides": ProvidesMacro.self,
]

final class InjectableMacroTests: XCTestCase {
  func testAStructUsesItsMemberwiseInitializerWithoutDefaultedProperties() {
    assertExpansion(
      """
      @Injectable
      public struct Repo {
        let db: Database
        var retries = 3
      }
      """,
      """
        public struct Repo {
          let db: Database
          var retries = 3
        }

        extension Repo: Injecta.Injectable {
          /// What the container must provide to build `Repo`. A container conforms
          /// through `@Container`; a missing entry is a "does not conform to `Needs`" error.
          public protocol Needs {
            var db: Database { get }
          }

          public static let injectaDependencies: [String] = ["db"]

          public init(injecting needs: some Needs) {
            self.init(db: needs.db)
          }
        }
        """)
  }

  func testAMainActorClassUsesTheMarkedInitializerAndANonisolatedLabelList() {
    assertExpansion(
      """
      @MainActor @Injectable
      final class Store {
        @Inject init(client: any Client, cwd: String, locale: Locale = .current) {}
        init() {}
      }
      """,
      """
        @MainActor
        final class Store {
          init(client: any Client, cwd: String, locale: Locale = .current) {}
          init() {}
        }

        extension Store: Injecta.Injectable {
          /// What the container must provide to build `Store`. A container conforms
          /// through `@Container`; a missing entry is a "does not conform to `Needs`" error.
          protocol Needs {
            var client: any Client { get }
            var cwd: String { get }
          }

          nonisolated static let injectaDependencies: [String] = ["client", "cwd"]

          convenience init(injecting needs: some Needs) {
            self.init(client: needs.client, cwd: needs.cwd)
          }
        }
        """)
  }

  func testTwoUnmarkedInitializersAreAnError() {
    assertMacroExpansion(
      """
      @Injectable
      final class Store {
        init(a: Int) {}
        init(b: Int) {}
      }
      """,
      expandedSource: """
        final class Store {
          init(a: Int) {}
          init(b: Int) {}
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "this type has 2 initializers; mark the one the container calls with @Inject",
          line: 2, column: 19)
      ],
      macros: macros, indentationWidth: .spaces(2))
  }

  func testAThrowingInitializerAndAnUnlabeledParameterAreErrors() {
    assertMacroExpansion(
      """
      @Injectable
      struct Client {
        init(_ url: String) throws {}
      }
      """,
      expandedSource: """
        struct Client {
          init(_ url: String) throws {}
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "an injected initializer cannot be async or throw: build the value first and pass it to the container's init as an input",
          line: 3, column: 23),
        DiagnosticSpec(
          message: "an injected parameter needs an argument label: the label is the container entry it is read from",
          line: 3, column: 8),
      ],
      macros: macros, indentationWidth: .spaces(2))
  }
}
