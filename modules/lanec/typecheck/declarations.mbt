///|
priv struct DeclarationChecker {
  source : @resolve.ResolvedSourceFile
  diagnostics : Array[TypeCheckDiagnostic]
}

///|
/// Checks nominal declarations and returns the checked declaration environment.
pub fn typecheck_declarations(
  source : @resolve.ResolvedSourceFile,
) -> DeclarationTypeCheckResult {
  let checker = DeclarationChecker::{ source, diagnostics: [] }
  let types = []
  let type_members = []
  let fields = []
  let variants = []
  for declaration in source.declarations {
    match declaration {
      Struct(declaration) => {
        let checked = checker.check_struct(declaration)
        for type_member in checked.type_members {
          type_members.push(type_member)
        }
        for field in checked.fields {
          fields.push(field)
        }
        types.push(CheckedTypeDeclaration::Struct(checked))
      }
      Enum(declaration) => {
        let checked = checker.check_enum(declaration)
        for variant in checked.variants {
          variants.push(variant)
        }
        types.push(Enum(checked))
      }
      _ => ()
    }
  }
  {
    declarations: { types, type_members, fields, variants },
    diagnostics: checker.diagnostics,
  }
}

///|
fn DeclarationChecker::check_struct(
  self : DeclarationChecker,
  declaration : @resolve.ResolvedStructDeclaration,
) -> CheckedStructDeclaration {
  let type_members = []
  let fields = []
  for item in declaration.members {
    match item {
      TypeMember(type_member) =>
        type_members.push(self.check_type_member(type_member))
      Field(field) => fields.push(self.check_field(field))
    }
  }
  {
    symbol: declaration.symbol,
    name: declaration.name,
    type_parameters: declaration.type_parameters.map(checked_type_parameter),
    type_members,
    fields,
    loc: declaration.loc,
  }
}

///|
fn DeclarationChecker::check_type_member(
  self : DeclarationChecker,
  type_member : @resolve.ResolvedTypeMemberDeclaration,
) -> CheckedTypeMemberDeclaration {
  let kind = self.check_kind(type_member.kind)
  {
    symbol: type_member.symbol,
    type_parameter: checked_type_parameter_with_kind(
      type_member.type_parameter,
      kind,
    ),
    name: type_member.name,
    kind,
    index: type_member.index,
    loc: type_member.loc,
  }
}

///|
fn DeclarationChecker::check_field(
  self : DeclarationChecker,
  field : @resolve.ResolvedFieldDeclaration,
) -> CheckedFieldDeclaration {
  {
    symbol: field.symbol,
    is_offered: field.is_offered,
    name: field.name,
    index: field.index,
    type_: self.check_type(field.type_),
    loc: field.loc,
  }
}

///|
fn DeclarationChecker::check_enum(
  self : DeclarationChecker,
  declaration : @resolve.ResolvedEnumDeclaration,
) -> CheckedEnumDeclaration {
  let variants = []
  for variant in declaration.variants {
    variants.push(self.check_variant(variant))
  }
  {
    symbol: declaration.symbol,
    name: declaration.name,
    type_parameters: declaration.type_parameters.map(checked_type_parameter),
    variants,
    loc: declaration.loc,
  }
}

///|
fn DeclarationChecker::check_variant(
  self : DeclarationChecker,
  variant : @resolve.ResolvedEnumVariant,
) -> CheckedVariantDeclaration {
  {
    symbol: variant.symbol,
    name: variant.name,
    index: variant.index,
    type_parameters: variant.type_parameters.map(checked_type_parameter),
    payload: variant.payload.map(fn(type_) { self.check_type(type_) }),
    loc: variant.loc,
  }
}

///|
fn DeclarationChecker::check_type(
  self : DeclarationChecker,
  type_ : @resolve.ResolvedType,
) -> @types.Type {
  check_resolved_type(self.source.symbols, self.diagnostics, type_)
}

///|
fn DeclarationChecker::check_kind(
  self : DeclarationChecker,
  kind : @resolve.ResolvedKind,
) -> @types.Kind {
  match kind {
    Type(..) => Type
    Arrow(parameter~, result~, ..) =>
      Arrow(self.check_kind(parameter), self.check_kind(result))
  }
}

///|
fn check_resolved_type(
  symbols : @symbol.SymbolRegistry,
  diagnostics : Array[TypeCheckDiagnostic],
  type_ : @resolve.ResolvedType,
) -> @types.Type {
  match type_ {
    Primitive(primitive, ..) => Primitive(primitive)
    Nominal(symbol~, name~, arguments~, loc~) => {
      let checked_arguments = arguments.map(fn(argument) {
        check_resolved_type(symbols, diagnostics, argument)
      })
      check_type_arity(
        symbols,
        diagnostics,
        symbol,
        name,
        checked_arguments.length(),
        loc,
      )
      Nominal(symbol, checked_arguments)
    }
    Parameter(symbol~, ..) => Parameter(symbol)
    Function(type_parameters~, parameters~, result~, ..) => {
      let checked_parameters = parameters.map(fn(parameter) {
        check_resolved_type(symbols, diagnostics, parameter)
      })
      let checked_result = check_resolved_type(symbols, diagnostics, result)
      let function_type = @types.Type::Function(
        checked_parameters, checked_result,
      )
      if type_parameters.is_empty() {
        function_type
      } else {
        Forall(type_parameters.map(checked_type_parameter), function_type)
      }
    }
    Unresolved(name~, arguments~, loc~) => {
      for argument in arguments {
        ignore(check_resolved_type(symbols, diagnostics, argument))
      }
      diagnostics.push({ kind: UnresolvedType(name), loc })
      Error
    }
  }
}

///|
fn check_type_arity(
  symbols : @symbol.SymbolRegistry,
  diagnostics : Array[TypeCheckDiagnostic],
  symbol : TypeSymbolId,
  name : String,
  actual : Int,
  loc : SourceSpan,
) -> Unit {
  if symbols.type_metadata(symbol) is Some(metadata) && metadata.arity != actual {
    diagnostics.push({
      kind: TypeArgumentArityMismatch(name~, expected=metadata.arity, actual~),
      loc,
    })
  }
}

///|
fn checked_type_parameter(
  parameter : @resolve.ResolvedTypeParameter,
) -> @types.TypeParameter {
  checked_type_parameter_with_kind(parameter, Type)
}

///|
fn checked_type_parameter_with_kind(
  parameter : @resolve.ResolvedTypeParameter,
  kind : @types.Kind,
) -> @types.TypeParameter {
  { id: parameter.symbol, name: parameter.name, kind }
}
