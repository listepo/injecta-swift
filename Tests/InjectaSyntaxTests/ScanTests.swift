import InjectaSyntax
import SwiftParser
import Testing

private func scan(_ files: [String: String]) -> TargetScan {
  var scan = TargetScan()
  for (name, source) in files.sorted(by: { $0.key < $1.key }) {
    scan.add(Parser.parse(source: source), file: name)
  }
  return scan
}

@Test func aMissingEntryOfAnAutoWiredTypeInAnotherFileIsReportedAtTheEntry() {
  let result = scan([
    "Store.swift": """
      @Injectable
      final class SettingsStore {
        init(client: any SettingsClient, cwd: String) {}
      }
      """,
    "Graph.swift": """
      @Container
      final class AppGraph {
        let cwd: String
        @Transient var settings: SettingsStore
      }
      """,
  ])
  let lines = result.diagnostics()
  #expect(lines.count == 1)
  #expect(lines[0].isError)
  #expect(lines[0].line.hasPrefix("Graph.swift:4:"))
  #expect(lines[0].line.contains("'settings' needs 'client'"))
}

@Test func aCycleThroughAutoWiredTypesIsReported() {
  let result = scan([
    "A.swift": "@Injectable struct A { let b: B }\n@Injectable struct B { let a: A }",
    "Graph.swift": "@Container final class G {\n  @Transient var a: A\n  @Transient var b: B\n}",
  ])
  #expect(result.diagnostics().map(\.line).contains { $0.contains("dependency cycle: a -> b -> a") })
}

@Test func problemsTheMacroAlreadyReportsAreNotRepeated() {
  let result = scan([
    "Graph.swift": """
      @Container final class G {
        @Provides func makeA(missing: Int) -> Int { missing }
      }
      """
  ])
  #expect(result.diagnostics().isEmpty)
}

@Test func aSoundTargetHasNoDiagnostics() {
  let result = scan([
    "All.swift": """
      @Injectable struct Repo { let db: Database }
      @Injectable final class Database { init(config: Config) {} }
      @Container final class G {
        let config: Config
        @Singleton var db: Database
        @Transient var repo: Repo
      }
      """
  ])
  #expect(result.diagnostics().isEmpty)
  #expect(result.needs(of: "Database") == ["config"])
  #expect(result.needs(of: "App.Repo") == ["db"])
}

@Test func conformancesAreGeneratedOncePerAutoWiredTypeWithTheContainersIsolation() {
  let result = scan([
    "Graph.swift": """
      @MainActor @Container final class UI {
        @Singleton var settings: SettingsStore
        @Transient var other: SettingsStore
        @Provides func makeCore() -> any Core { LiveCore() }
      }
      @Container final class Plain {
        @Transient var repo: Repo
      }
      """
  ])
  #expect(result.conformances() == [
    "extension UI: @MainActor SettingsStore.Needs {}",
    "extension Plain: Repo.Needs {}",
  ])
}
