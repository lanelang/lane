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
  type OfferDeclaration,
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
  type_binders : Array[String]
}

///|
priv enum HandlerOperationHeadAfterIdent {
  Unqualified(Array[String])
  Qualified(
    owner_arguments~ : Array[Type],
    operation~ : String,
    type_binders~ : Array[String]
  )
}

///|
priv enum HandlerOperationAfterTypeArguments {
  OperationBinders
  OwnerArguments(operation~ : String, type_binders~ : Array[String])
}

///|
fn span(loc : (SourceSpan, SourceSpan)) -> SourceSpan {
  SourceSpan::join(loc.0, loc.1)
}

///|
fn make_external_type(
  is_public : Bool,
  name : String,
  type_parameters : Array[TypeParameter],
  result_kind : ExternalTypeKind,
  loc : SourceSpan,
) -> ExternalTypeDeclaration {
  { is_public, name, type_parameters, result_kind, loc }
}

///|
fn external_type_kind(name : String, loc : SourceSpan) -> ExternalTypeKind {
  if name == "Effect" {
    Effect(loc~)
  } else {
    Type(loc~)
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
        name: Some(name),
        name_loc: Some(name_loc),
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
  arguments : Array[Type],
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
  loc : SourceSpan,
) -> OwnerExpression {
  {
    expr: Field(base=expression.expr, name~, loc~),
    owner: extend_owner_type_name(expression.owner, name, loc),
  }
}

///|
fn owner_expression_with_arguments(
  expression : OwnerExpression,
  arguments : Array[Type],
  loc : SourceSpan,
) -> OwnerExpression {
  {
    expr: TypeApplication(callee=expression.expr, arguments~, loc~),
    owner: apply_type_arguments(expression.owner, arguments, loc),
  }
}

///|
fn type_binders_from_type_arguments(arguments : Array[Type]) -> Array[String] {
  arguments.map(type_name_text)
}

///|
fn handler_operation_head_from_ident(
  name : String,
  suffix : HandlerOperationHeadAfterIdent,
  loc : SourceSpan,
) -> HandlerOperationHead {
  match suffix {
    Unqualified(type_binders) =>
      { name: Unqualified(operation=name, loc~), type_binders }
    Qualified(owner_arguments~, operation~, type_binders~) => {
      let owner = apply_type_arguments(Name(name~, loc~), owner_arguments, loc)
      { name: Qualified(owner~, operation~, loc~), type_binders }
    }
  }
}

///|
fn handler_operation_head_from_qualified(
  owner_base : Type,
  owner_arguments : Array[Type],
  operation : String,
  type_binders : Array[String],
  loc : SourceSpan,
) -> HandlerOperationHead {
  let owner = apply_type_arguments(owner_base, owner_arguments, loc)
  { name: Qualified(owner~, operation~, loc~), type_binders }
}

///|
fn handler_operation_head_after_type_arguments(
  owner_or_binders : Array[Type],
  suffix : HandlerOperationAfterTypeArguments,
) -> HandlerOperationHeadAfterIdent {
  match suffix {
    OperationBinders =>
      Unqualified(type_binders_from_type_arguments(owner_or_binders))
    OwnerArguments(operation~, type_binders~) =>
      Qualified(owner_arguments=owner_or_binders, operation~, type_binders~)
  }
}
