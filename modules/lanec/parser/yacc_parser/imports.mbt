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
  type PatternLetDeclaration,
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
fn[T] comma_push(items : Array[T], item : T) -> Array[T] {
  items.push(item)
  items
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
fn expression_type_name_text(expr : Expr) -> String {
  match expr {
    Var(name, ..) => name
    Field(base~, name~, ..) => {
      let base_name = expression_type_name_text(base)
      if base_name == "" {
        ""
      } else {
        base_name + "." + name
      }
    }
    _ => ""
  }
}

///|
fn type_binders_from_type_arguments(arguments : Array[Type]) -> Array[String] {
  arguments.map(type_name_text)
}

///|
fn handler_operation_head_shorthand(
  operation : String,
  type_binders : Array[String],
  loc : SourceSpan,
) -> HandlerOperationHead {
  { name: Shorthand(operation~, loc~), type_binders }
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
      let owner : Type = match owner_arguments {
        [] => Name(name~, loc~)
        arguments => Apply(callee=Name(name~, loc~), arguments~, loc~)
      }
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
  let owner = match owner_arguments {
    [] => owner_base
    arguments => Apply(callee=owner_base, arguments~, loc~)
  }
  { name: Qualified(owner~, operation~, loc~), type_binders }
}

///|
fn handler_operation_head_after_type_arguments(
  owner_or_binders : Array[Type],
  suffix : HandlerOperationAfterTypeArguments,
) -> HandlerOperationHeadAfterIdent {
  match suffix {
    OperationBinders => Unqualified(
      type_binders_from_type_arguments(owner_or_binders),
    )
    OwnerArguments(operation~, type_binders~) =>
      Qualified(owner_arguments=owner_or_binders, operation~, type_binders~)
  }
}
