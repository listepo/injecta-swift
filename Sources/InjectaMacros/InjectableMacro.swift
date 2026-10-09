import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// `@Injectable`: a `Needs` protocol with one requirement per injected label, an initializer that
/// reads them from any container conforming to it, and the label list for `injectaGraph`.
public struct InjectableMacro: ExtensionMacro {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    let (model, problems) = InjectableReader.read(declaration)
    context.report(problems)
    guard let model else { return [] }
    let access = model.access
    // A global-actor type's statics are isolated; the graph is read from anywhere.
    let nonisolated = model.globalActor == nil ? "" : "nonisolated "
    let requirements = model.dependencies
      .map { "  var \($0.label): \(storable($0.type)) { get }" }
      .joined(separator: "\n")
    let edges = model.dependencies.filter { !$0.deferred }.map { "\"\($0.label)\"" }
    let deferred = model.dependencies.filter(\.deferred).map { "\"\($0.label)\"" }
    let arguments = model.dependencies.map { passed($0) }.joined(separator: ", ")
    let initializer = model.kind == .class ? "convenience init" : "init"
    // A `@Sendable` factory cannot capture `some Needs` (the protocol is not Sendable). The
    // source is the container, which is Sendable when it builds a Sendable factory.
    let generic = model.dependencies.contains(where: \.sendableFactory)
      ? "<Source: Needs & Sendable>" : ""
    let needsType = generic.isEmpty ? "some Needs" : "Source"
    let conformance = protocols.isEmpty ? "" : ": Injecta.Injectable"
    let source: DeclSyntax = """
      extension \(raw: type.trimmedDescription)\(raw: conformance) {
        /// What the container must provide to build `\(raw: model.typeName)`. A container conforms
        /// through `@Container`; a missing entry is a "does not conform to `Needs`" error.
        \(raw: access)protocol Needs {
      \(raw: requirements)
        }

        \(raw: access)\(raw: nonisolated)static let injectaDependencies: [String] = [\(raw: edges.joined(separator: ", "))]

        \(raw: access)\(raw: nonisolated)static let injectaDeferred: [String] = [\(raw: deferred.joined(separator: ", "))]

        \(raw: access)\(raw: initializer)\(raw: generic)(injecting needs: \(raw: needsType)) {
          self.init(\(raw: arguments))
        }
      }
      """
    guard let extensionDecl = source.as(ExtensionDeclSyntax.self) else { return [] }
    return [extensionDecl]
  }
}

/// The argument passed to the user's initializer. A deferred dependency reads the entry later.
private func passed(_ dependency: Dependency) -> String {
  let label = dependency.label
  switch dependency.wrap {
  case .direct:
    return "\(label): needs.\(label)"
  case .lazy:
    return "\(label): Injecta.Lazy { needs.\(label) }"
  case .factory:
    let body = dependency.sendableFactory ? "@Sendable in needs.\(label)" : "needs.\(label)"
    return "\(label): { \(body) }"
  }
}

/// `@Inject` only marks an initializer for `@Injectable`; it generates nothing.
public struct InjectMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] { [] }
}
