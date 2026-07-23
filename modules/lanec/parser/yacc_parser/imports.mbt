///|
using @basic {type SourceSpan}

///|
using @syntax {
  type EnumDeclaration,
  type EnumVariant,
  type EffectDeclaration,
  type EffectOperationDeclaration,
  type EffectOperationName,
  type EffectTerm,
  type ExternalTypeDeclaration,
  type ExternalTypeKind,
  type Expr,
  type FieldDeclaration,
  type FunctionDeclaration,
  type FunctionLiteralParameter,
  type GenericArgument,
  type HandlerFinalBranch,
  type HandlerOperationArm,
  type HandlerWithBlock,
  type ImportDeclaration,
  type ImportItem,
  type Kind,
  type LetDeclaration,
  type LocalItem,
  type MatchArm,
  type ModulePath,
  type CallArgument,
  type Parameter,
  type ParameterModifiers,
  type Pattern,
  type SourceFile,
  type StructDeclaration,
  type StructLiteralField,
  type StructMember,
  type StructPatternField,
  type TypeAliasDeclaration,
  type TypeAliasBody,
  type TypeBinder,
  type TypeMemberDeclaration,
  type TypeParameter,
  type TopLevelDeclaration,
  type Type,
}

///|
priv struct Identifier {
  name : String
  loc : SourceSpan
}

///|
priv struct NominalTypeName {
  name : String
  loc : SourceSpan
}

///|
priv struct ReturnAnnotation {
  return_type : Type?
  effect : EffectTerm?
}

///|
priv struct OwnerExpression {
  expr : Expr
  owner : Type
}

///|
priv struct HandlerOperationArmParameters {
  payload_patterns : Array[Pattern]
  resume_binder : String
  resume_loc : SourceSpan
}

///|
priv struct HandlerOperationHead {
  name : EffectOperationName
  type_binders : Array[TypeBinder]
}

///|
priv struct GenericArgumentList {
  arguments : Array[GenericArgument]
  loc : SourceSpan
}

///|
fn span(loc : (SourceSpan, SourceSpan)) -> SourceSpan {
  SourceSpan::join(loc.0, loc.1)
}

///|
fn make_external_type(
  is_public : Bool,
  identifier : Identifier,
  type_parameters : Array[TypeParameter],
  result_kind : ExternalTypeKind,
  loc : SourceSpan,
) -> ExternalTypeDeclaration {
  {
    is_public,
    name: identifier.name,
    name_loc: identifier.loc,
    type_parameters,
    result_kind,
    loc,
  }
}

///|
fn with_public_loc(
  declaration : TopLevelDeclaration,
  loc : SourceSpan,
) -> TopLevelDeclaration {
  match declaration {
    Struct(value) => Struct({ ..value, loc, })
    Enum(value) => Enum({ ..value, loc, })
    Effect(value) => Effect({ ..value, loc, })
    ExternalType(value) => ExternalType({ ..value, loc, })
    TypeAlias(value) => TypeAlias({ ..value, loc, })
    Function(value) => Function({ ..value, loc, })
    Let(value) => Let({ ..value, loc, })
  }
}

///|
fn[T] comma_push(items : Array[T], item : T) -> Array[T] {
  items.push(item)
  items
}

///|
fn local_let_item(
  pattern : Pattern,
  type_annotation : Type?,
  initializer : Expr,
  loc : SourceSpan,
) -> LocalItem {
  match pattern {
    Binding(name, loc=name_loc) =>
      Let({
        is_public: false,
        is_offered: false,
        name,
        name_loc,
        type_annotation,
        initializer,
        loc,
      })
    _ => PatternLet({ pattern, type_annotation, initializer, loc })
  }
}

///|
fn effect_or_empty(effect : EffectTerm?, result : Type) -> EffectTerm {
  match effect {
    Some(effect) => effect
    None => Empty(loc=result.loc())
  }
}

///|
fn extend_qualified_type_name(
  type_ : Type,
  name : String,
  loc : SourceSpan,
) -> Type {
  match type_ {
    QualifiedName(module_path~, name=previous_name, ..) => {
      let components = module_path.components.copy()
      components.push(previous_name)
      QualifiedName(module_path={ components, loc }, name~, loc~)
    }
    _ => type_
  }
}

///|
fn type_name_text(type_ : Type) -> String {
  match type_ {
    Name(name~, ..) => name
    QualifiedName(module_path~, name~, ..) =>
      module_path.components.join(".") + "." + name
    _ => ""
  }
}

///|
fn apply_type_arguments(
  callee : Type,
  arguments : Array[GenericArgument],
  loc : SourceSpan,
) -> Type {
  if arguments.is_empty() {
    callee
  } else {
    Apply(callee~, arguments~, loc~)
  }
}

///|
fn extend_owner_type_name(
  owner : Type,
  name : String,
  loc : SourceSpan,
) -> Type {
  match owner {
    Name(name=previous_name, ..) =>
      QualifiedName(
        module_path={ components: [previous_name], loc },
        name~,
        loc~,
      )
    QualifiedName(..) => extend_qualified_type_name(owner, name, loc)
    _ => abort("expected nominal owner type")
  }
}

///|
fn owner_expression_field(
  expression : OwnerExpression,
  name : String,
  name_loc : SourceSpan,
  loc : SourceSpan,
) -> OwnerExpression {
  {
    expr: Field(base=expression.expr, name~, name_loc~, loc~),
    owner: extend_owner_type_name(expression.owner, name, loc),
  }
}

///|
fn owner_expression_with_arguments(
  expression : OwnerExpression,
  arguments : Array[GenericArgument],
  loc : SourceSpan,
) -> OwnerExpression {
  {
    expr: TypeApplication(callee=expression.expr, arguments~, loc~),
    owner: apply_type_arguments(expression.owner, arguments, loc),
  }
}

///|
fn effect_set(items : Array[Type], loc : SourceSpan) -> EffectTerm {
  if items.is_empty() {
    Empty(loc~)
  } else {
    Union(items~, loc~)
  }
}

///|
fn unqualified_handler_operation_head(
  identifier : Identifier,
  type_binders : Array[TypeBinder],
) -> HandlerOperationHead {
  {
    name: Unqualified(operation=identifier.name, operation_loc=identifier.loc),
    type_binders,
  }
}

///|
fn handler_operation_head_from_qualified(
  owner_base : Type,
  owner_arguments : GenericArgumentList?,
  operation : Identifier,
  type_binders : Array[TypeBinder],
) -> HandlerOperationHead {
  let owner = apply_handler_operation_owner_arguments(
    owner_base, owner_arguments,
  )
  {
    name: Qualified(
      owner~,
      operation=operation.name,
      operation_loc=operation.loc,
    ),
    type_binders,
  }
}

///|
fn apply_handler_operation_owner_arguments(
  owner : Type,
  arguments : GenericArgumentList?,
) -> Type {
  match arguments {
    None => owner
    Some(arguments) =>
      apply_type_arguments(
        owner,
        arguments.arguments,
        SourceSpan::join(owner.loc(), arguments.loc),
      )
  }
}
