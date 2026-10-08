import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// The parts of an entry the accessor and peer roles share.
private struct EntryShape {
  var name: String
  var type: String
  var access: String
  /// The expression that builds the value: `Type(injecting: self)` or `self.makeName(a: self.a)`.
  var build: String
  var isFunction: Bool

  init?(_ declaration: some SyntaxProtocol) {
    if let variable = declaration.as(VariableDeclSyntax.self) {
      guard let binding = variable.bindings.first,
        let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
        let type = binding.typeAnnotation?.type
      else { return nil }
      name = identifier.text
      self.type = type.trimmedDescription
      access = variable.modifiers.accessPrefix
      build = "\(self.type)(injecting: self)"
      isFunction = false
    } else if let function = declaration.as(FunctionDeclSyntax.self) {
      let functionName = function.name.text
      guard functionName.hasPrefix("make"), functionName.count > 4,
        let returnType = function.signature.returnClause?.type
      else { return nil }
      name = lowerFirst(functionName.dropFirst(4))
      type = returnType.trimmedDescription
      access = function.modifiers.accessPrefix
      let arguments = function.signature.parameterClause.parameters.map {
        "\($0.firstName.text): self.\($0.firstName.text)"
      }
      build = "self.\(functionName)(\(arguments.joined(separator: ", ")))"
      isFunction = true
    } else {
      return nil
    }
  }

  var singletonGetter: String { "_injecta_\(name).get { \(build) }" }
  var transientGetter: String {
    "if let make = _injectaOverrides.\(name) { return make() }\nreturn \(build)"
  }
  var storage: DeclSyntax { "private let _injecta_\(raw: name) = Injecta.Once<\(raw: storable(type))>()" }
}

/// `@Singleton`: a getter over a `Once` cell, and the cell.
public struct SingletonMacro: AccessorMacro, PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingAccessorsOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [AccessorDeclSyntax] {
    guard declaration.is(VariableDeclSyntax.self), let shape = EntryShape(declaration) else { return [] }
    return ["get { \(raw: shape.singletonGetter) }"]
  }

  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let shape = EntryShape(declaration), !shape.isFunction else { return [] }
    return [shape.storage]
  }
}

/// `@Transient`: a getter that builds a new value on every access (or calls the override).
public struct TransientMacro: AccessorMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingAccessorsOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [AccessorDeclSyntax] {
    guard declaration.is(VariableDeclSyntax.self), let shape = EntryShape(declaration) else { return [] }
    return ["get {\n\(raw: shape.transientGetter)\n}"]
  }
}

/// `@Provides`: the entry `name` for a `make<Name>` function, cached per container unless
/// `.transient`.
public struct ProvidesMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let shape = EntryShape(declaration), shape.isFunction else { return [] }
    let type = storable(shape.type)
    if Provision(node) == .transient {
      return ["\(raw: shape.access)var \(raw: shape.name): \(raw: type) {\n\(raw: shape.transientGetter)\n}"]
    }
    return [shape.storage, "\(raw: shape.access)var \(raw: shape.name): \(raw: type) { \(raw: shape.singletonGetter) }"]
  }
}

/// `@Forward`: `parent.<name>`.
public struct ForwardMacro: AccessorMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingAccessorsOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [AccessorDeclSyntax] {
    guard let variable = declaration.as(VariableDeclSyntax.self),
      let name = variable.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier
    else { return [] }
    return ["get { parent.\(raw: name.text) }"]
  }
}
