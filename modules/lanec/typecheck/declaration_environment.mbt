///|
fn CheckedDeclarationEnvironment::checked_struct(
  self : CheckedDeclarationEnvironment,
  symbol : TypeSymbolId,
) -> CheckedStructDeclaration? {
  for declaration in self.types {
    if declaration is Struct(declaration) && declaration.symbol == symbol {
      return Some(declaration)
    }
  }
  None
}

///|
fn CheckedDeclarationEnvironment::checked_enum(
  self : CheckedDeclarationEnvironment,
  symbol : TypeSymbolId,
) -> CheckedEnumDeclaration? {
  for declaration in self.types {
    if declaration is Enum(declaration) && declaration.symbol == symbol {
      return Some(declaration)
    }
  }
  None
}

///|
fn CheckedDeclarationEnvironment::checked_effect(
  self : CheckedDeclarationEnvironment,
  symbol : EffectSymbolId,
) -> CheckedEffectDeclaration? {
  for declaration in self.effects {
    if declaration.symbol == symbol {
      return Some(declaration)
    }
  }
  None
}

///|
fn CheckedDeclarationEnvironment::checked_operation(
  self : CheckedDeclarationEnvironment,
  symbol : OperationSymbolId,
) -> CheckedEffectOperationDeclaration? {
  for declaration in self.operations {
    if declaration.symbol == symbol {
      return Some(declaration)
    }
  }
  None
}

///|
fn CheckedDeclarationEnvironment::field_type(
  self : CheckedDeclarationEnvironment,
  diagnostics : Array[TypeCheckDiagnostic],
  base_type : @types.Type,
  field : FieldSymbolId,
  name : String,
  loc : SourceSpan,
) -> @types.Type {
  match base_type.decompose_nominal() {
    Some((owner, arguments)) => {
      guard self.checked_struct(owner) is Some(declaration) else {
        diagnostics.push({ kind: NotAStruct(base_type), loc })
        return Error
      }
      guard declaration.field(field) is Some(field_declaration) else {
        diagnostics.push({ kind: UnknownField(name~), loc })
        return Error
      }
      field_declaration.type_.substitute(
        declaration.nominal_substitution(arguments),
      )
    }
    None =>
      if base_type is Error {
        Error
      } else {
        diagnostics.push({ kind: NotAStruct(base_type), loc })
        Error
      }
  }
}

///|
fn CheckedStructDeclaration::field(
  self : CheckedStructDeclaration,
  symbol : FieldSymbolId,
) -> CheckedFieldDeclaration? {
  for field in self.fields {
    if field.symbol == symbol {
      return Some(field)
    }
  }
  None
}

///|
fn CheckedStructDeclaration::type_member(
  self : CheckedStructDeclaration,
  symbol : TypeMemberSymbolId,
) -> CheckedTypeMemberDeclaration? {
  for type_member in self.type_members {
    if type_member.symbol == symbol {
      return Some(type_member)
    }
  }
  None
}

///|
fn CheckedStructDeclaration::type_member_named(
  self : CheckedStructDeclaration,
  name : String,
) -> CheckedTypeMemberDeclaration? {
  for type_member in self.type_members {
    if type_member.name == name {
      return Some(type_member)
    }
  }
  None
}

///|
fn CheckedEnumDeclaration::variant(
  self : CheckedEnumDeclaration,
  symbol : VariantSymbolId,
) -> CheckedVariantDeclaration? {
  for variant in self.variants {
    if variant.symbol == symbol {
      return Some(variant)
    }
  }
  None
}

///|
fn CheckedStructDeclaration::nominal_substitution(
  self : CheckedStructDeclaration,
  arguments : Array[@types.GenericArgument],
) -> @types.TypeSubstitution {
  let substitution = @types.TypeSubstitution::TypeSubstitution()
  let length = if self.type_parameters.length() < arguments.length() {
    self.type_parameters.length()
  } else {
    arguments.length()
  }
  for index in 0..<length {
    substitution.insert_argument(
      self.type_parameters[index].id,
      arguments[index],
    )
  }
  substitution
}

///|
fn CheckedStructDeclaration::existential_substitution(
  self : CheckedStructDeclaration,
  witnesses : Array[@checked.CheckedStructTypeWitness],
) -> @types.TypeSubstitution {
  let substitution = @types.TypeSubstitution::TypeSubstitution()
  for witness in witnesses {
    if self.type_member(witness.symbol) is Some(type_member) {
      substitution.insert(type_member.type_parameter.id, witness.type_)
    }
  }
  substitution
}
