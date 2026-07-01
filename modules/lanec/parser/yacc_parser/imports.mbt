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
  type TypeMemberDeclaration,
  type TypeParameter,
  type TopLevelDeclaration,
  type Type,
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
