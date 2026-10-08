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
    let labels = model.dependencies.map { "\"\($0.label)\"" }.joined(separator: ", ")
    let arguments = model.dependencies.map { "\($0.label): needs.\($0.label)" }
      .joined(separator: ", ")
    let initializer = model.kind == .class ? "convenience init" : "init"
    let conformance = protocols.isEmpty ? "" : ": Injecta.Injectable"
    let source: DeclSyntax = """
      extension \(raw: type.trimmedDescription)\(raw: conformance) {
        /// What the container must provide to build `\(raw: model.typeName)`. A container conforms
        /// through `@Container`; a missing entry is a "does not conform to `Needs`" error.
        \(raw: access)protocol Needs {
      \(raw: requirements)
        }

        \(raw: access)\(raw: nonisolated)static let injectaDependencies: [String] = [\(raw: labels)]

        \(raw: access)\(raw: initializer)(injecting needs: some Needs) {
          self.init(\(raw: arguments))
        }
      }
      """
    guard let extensionDecl = source.as(ExtensionDeclSyntax.self) else { return [] }
    return [extensionDecl]
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
