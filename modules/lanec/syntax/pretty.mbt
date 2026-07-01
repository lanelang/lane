///|
fn keyword(value : String) -> Document {
  text(value)
}

///|
fn comma_space() -> Document {
  text(",") + space
}

///|
fn comma_line() -> Document {
  text(",") + line
}

///|
fn comma_list(docs : Array[Document]) -> Document {
  separate(comma_line(), docs)
}

///|
fn join_comma(docs : Array[Document]) -> Document {
  separate(comma_space(), docs)
}

///|
fn bracketed_type_parameters(parameters : Array[TypeParameter]) -> Document {
  if parameters.is_empty() {
    empty
  } else {
    brackets(join_comma(parameters.map(TypeParameter::to_doc)))
  }
}

///|
fn bracketed_type_arguments(arguments : Array[Type]) -> Document {
  if arguments.is_empty() {
    empty
  } else {
    brackets(join_comma(arguments.map(Type::to_doc)))
  }
}

///|
fn parenthesized(docs : Array[Document]) -> Document {
  group(parens(nest(softline + comma_list(docs)) + softline))
}

///|
fn brace_block(docs : Array[Document]) -> Document {
  if docs.is_empty() {
    surround(char('{'), char('}'), empty)
  } else {
    surround(
      char('{'),
      hardline + char('}'),
      nest(hardline + separate(hardline, docs)),
    )
  }
}

///|
fn brace_comma_block(docs : Array[Document]) -> Document {
  if docs.is_empty() {
    surround(char('{'), char('}'), empty)
  } else {
    surround(
      char('{'),
      hardline + char('}'),
      nest(hardline + separate(comma_line(), docs)),
    )
  }
}

///|
fn source_string(value : String) -> Document {
  text(value.escape())
}

///|
pub impl @prettyprinter.Pretty for SourceFile with fn pretty(file : SourceFile) {
  let docs = [keyword("module") + space + file.module_path.to_doc()]
  for import_ in file.imports {
    docs.push(import_.to_doc())
  }
  if !file.declarations.is_empty() {
    docs.push(
      separate(
        hardline + hardline,
        file.declarations.map(TopLevelDeclaration::to_doc),
      ),
    )
  }
  separate(hardline + hardline, docs)
}

///|
pub impl @prettyprinter.Pretty for ModulePath with fn pretty(path : ModulePath) {
  path.to_doc()
}

///|
fn ModulePath::to_doc(self : ModulePath) -> Document {
  text(self.components.join("."))
}

///|
pub impl @prettyprinter.Pretty for ImportDeclaration with fn pretty(
  declaration : ImportDeclaration,
) {
  declaration.to_doc()
}

///|
fn ImportDeclaration::to_doc(self : ImportDeclaration) -> Document {
  match self {
    Qualified(module_path~, ..) =>
      keyword("import") + space + module_path.to_doc()
    Open(module_path~, ..) =>
      keyword("import") + space + module_path.to_doc() + text(".*")
    Selective(module_path~, items~, ..) =>
      keyword("import") +
      space +
      module_path.to_doc() +
      text("::") +
      surround(char('{'), char('}'), join_comma(items.map(ImportItem::to_doc)))
  }
}

///|
pub impl @prettyprinter.Pretty for ImportItem with fn pretty(item : ImportItem) {
  item.to_doc()
}

///|
fn ImportItem::to_doc(self : ImportItem) -> Document {
  text(self.name)
}

///|
fn public_prefix(is_public : Bool) -> Document {
  if is_public {
    keyword("pub") + space
  } else {
    empty
  }
}

///|
pub impl @prettyprinter.Pretty for TopLevelDeclaration with fn pretty(
  declaration : TopLevelDeclaration,
) {
  declaration.to_doc()
}

///|
fn TopLevelDeclaration::to_doc(self : TopLevelDeclaration) -> Document {
  match self {
    Struct(declaration) => declaration.to_doc()
    Enum(declaration) => declaration.to_doc()
    Effect(declaration) => declaration.to_doc()
    TypeAlias(declaration) => declaration.to_doc()
    Function(declaration) => declaration.to_doc()
    Let(declaration) => declaration.to_doc()
    Offer(declaration) => declaration.to_doc()
  }
}

///|
pub impl @prettyprinter.Pretty for TypeParameter with fn pretty(
  parameter : TypeParameter,
) {
  parameter.to_doc()
}

///|
fn TypeParameter::to_doc(self : TypeParameter) -> Document {
  match self.kind {
    Some(kind) => text(self.name) + space + text(":") + space + kind.to_doc()
    None => text(self.name)
  }
}

///|
pub impl @prettyprinter.Pretty for StructDeclaration with fn pretty(
  declaration : StructDeclaration,
) {
  declaration.to_doc()
}

///|
fn StructDeclaration::to_doc(self : StructDeclaration) -> Document {
  public_prefix(self.is_public) +
  keyword("struct") +
  space +
  text(self.name) +
  bracketed_type_parameters(self.type_parameters) +
  space +
  brace_block(self.members.map(StructMember::to_doc))
}

///|
fn StructMember::to_doc(self : StructMember) -> Document {
  match self {
    TypeMember(declaration) => declaration.to_doc()
    Field(field) => field.to_doc()
  }
}

///|
pub impl @prettyprinter.Pretty for StructMember with fn pretty(
  struct_member : StructMember,
) {
  struct_member.to_doc()
}

///|
pub impl @prettyprinter.Pretty for TypeMemberDeclaration with fn pretty(
  declaration : TypeMemberDeclaration,
) {
  declaration.to_doc()
}

///|
fn TypeMemberDeclaration::to_doc(self : TypeMemberDeclaration) -> Document {
  keyword("type") +
  space +
  text(self.name) +
  space +
  text(":") +
  space +
  self.kind.to_doc()
}

///|
pub impl @prettyprinter.Pretty for Kind with fn pretty(kind : Kind) {
  kind.to_doc()
}

///|
fn Kind::to_doc(self : Kind) -> Document {
  match self {
    Type(..) => text("Type")
    Effect(..) => text("Effect")
    Function(parameters~, result~, ..) =>
      brackets(join_comma(parameters.map(Kind::to_doc))) +
      space +
      text("->") +
      space +
      result.to_doc()
  }
}

///|
pub impl @prettyprinter.Pretty for EffectDeclaration with fn pretty(
  declaration : EffectDeclaration,
) {
  declaration.to_doc()
}

///|
fn EffectDeclaration::to_doc(self : EffectDeclaration) -> Document {
  public_prefix(self.is_public) +
  keyword("effect") +
  space +
  text(self.name) +
  bracketed_type_parameters(self.type_parameters) +
  space +
  brace_block(self.operations.map(EffectOperationDeclaration::to_doc))
}

///|
pub impl @prettyprinter.Pretty for EffectOperationDeclaration with fn pretty(
  declaration : EffectOperationDeclaration,
) {
  declaration.to_doc()
}

///|
fn EffectOperationDeclaration::to_doc(
  self : EffectOperationDeclaration,
) -> Document {
  text(self.name) +
  bracketed_type_parameters(self.type_parameters) +
  parenthesized(self.payload.map(Type::to_doc)) +
  space +
  text("->") +
  space +
  self.result.to_doc()
}

///|
pub impl @prettyprinter.Pretty for FieldDeclaration with fn pretty(
  field : FieldDeclaration,
) {
  field.to_doc()
}

///|
fn FieldDeclaration::to_doc(self : FieldDeclaration) -> Document {
  let prefix = if self.is_offered { keyword("offer") + space } else { empty }
  prefix + text(self.name) + space + text(":") + space + self.type_.to_doc()
}

///|
pub impl @prettyprinter.Pretty for EnumDeclaration with fn pretty(
  declaration : EnumDeclaration,
) {
  declaration.to_doc()
}

///|
fn EnumDeclaration::to_doc(self : EnumDeclaration) -> Document {
  public_prefix(self.is_public) +
  keyword("enum") +
  space +
  text(self.name) +
  bracketed_type_parameters(self.type_parameters) +
  space +
  brace_block(self.variants.map(EnumVariant::to_doc))
}

///|
fn EnumVariant::to_doc(self : EnumVariant) -> Document {
  let type_parameters = bracketed_type_parameters(self.type_parameters)
  if self.payload.is_empty() {
    text(self.name) + type_parameters
  } else {
    text(self.name) +
    type_parameters +
    parenthesized(self.payload.map(Type::to_doc))
  }
}

///|
pub impl @prettyprinter.Pretty for EnumVariant with fn pretty(
  variant : EnumVariant,
) {
  variant.to_doc()
}

///|
pub impl @prettyprinter.Pretty for TypeAliasDeclaration with fn pretty(
  declaration : TypeAliasDeclaration,
) {
  declaration.to_doc()
}

///|
fn TypeAliasDeclaration::to_doc(self : TypeAliasDeclaration) -> Document {
  public_prefix(self.is_public) +
  keyword("type") +
  space +
  text(self.name) +
  bracketed_type_parameters(self.type_parameters) +
  space +
  text("=") +
  space +
  self.body.to_doc()
}

///|
pub impl @prettyprinter.Pretty for FunctionDeclaration with fn pretty(
  declaration : FunctionDeclaration,
) {
  declaration.to_doc()
}

///|
fn FunctionDeclaration::to_doc(self : FunctionDeclaration) -> Document {
  public_prefix(self.is_public) +
  keyword("fn") +
  bracketed_type_parameters(self.type_parameters) +
  space +
  text(self.name) +
  parenthesized(self.parameters.map(Parameter::to_doc)) +
  space +
  text("->") +
  space +
  self.return_type.to_doc() +
  space +
  self.body.to_doc()
}

///|
fn Parameter::to_doc(self : Parameter) -> Document {
  parameter_modifiers(self.is_auto, self.is_offered) +
  text(self.name) +
  space +
  text(":") +
  space +
  self.type_.to_doc()
}

///|
pub impl @prettyprinter.Pretty for Parameter with fn pretty(
  parameter : Parameter,
) {
  parameter.to_doc()
}

///|
pub impl @prettyprinter.Pretty for LetDeclaration with fn pretty(
  declaration : LetDeclaration,
) {
  declaration.to_doc()
}

///|
fn LetDeclaration::to_doc(self : LetDeclaration) -> Document {
  let name_doc = match self.name {
    Some(name) => space + text(name)
    None => empty
  }
  let type_doc = match self.type_annotation {
    Some(type_) => space + text(":") + space + type_.to_doc()
    None => empty
  }
  public_prefix(self.is_public) +
  keyword("let") +
  name_doc +
  type_doc +
  space +
  text("=") +
  space +
  self.initializer.to_doc()
}

///|
pub impl @prettyprinter.Pretty for OfferDeclaration with fn pretty(
  declaration : OfferDeclaration,
) {
  declaration.to_doc()
}

///|
fn OfferDeclaration::to_doc(self : OfferDeclaration) -> Document {
  public_prefix(self.is_public) +
  keyword("offer") +
  space +
  text(self.name) +
  space +
  text(":") +
  space +
  self.type_annotation.to_doc() +
  space +
  text("=") +
  space +
  self.initializer.to_doc()
}

///|
pub impl @prettyprinter.Pretty for Type with fn pretty(type_ : Type) {
  type_.to_doc()
}

///|
fn Type::to_doc(self : Type) -> Document {
  match self {
    Name(name~, ..) => text(name)
    QualifiedName(module_path~, name~, ..) =>
      module_path.to_doc() + text(".") + text(name)
    Apply(callee~, arguments~, ..) =>
      callee.to_doc() + bracketed_type_arguments(arguments)
    TypeLambda(parameters~, body~, ..) =>
      keyword("type") +
      bracketed_type_parameters(parameters) +
      space +
      text("=>") +
      space +
      body.to_doc()
    Function(type_parameters~, parameters~, result~, ..) =>
      bracketed_type_parameters(type_parameters) +
      parenthesized(parameters.map(Type::to_doc)) +
      space +
      text("->") +
      space +
      result.to_doc()
  }
}

///|
pub impl @prettyprinter.Pretty for Expr with fn pretty(expression : Expr) {
  expression.to_doc()
}

///|
fn Expr::to_doc(self : Expr) -> Document {
  self.to_doc_with_precedence(0)
}

///|
fn Expr::to_doc_with_precedence(
  self : Expr,
  context_precedence : Int,
) -> Document {
  let (precedence, doc) = match self {
    IntLiteral(value, ..) => (10, text(value))
    StringLiteral(value, ..) => (10, source_string(value))
    BoolLiteral(value, ..) => (10, text(value.to_string()))
    UnitLiteral(..) => (10, text("()"))
    Var(name, ..) => (10, text(name))
    QualifiedVariant(
      type_name~,
      type_arguments~,
      variant~,
      variant_type_arguments~,
      arguments~,
      ..
    ) => {
      let head = text(type_name) +
        bracketed_type_arguments(type_arguments) +
        text("::") +
        text(variant) +
        bracketed_type_arguments(variant_type_arguments)
      let doc = if arguments.is_empty() {
        head
      } else {
        head + parenthesized(arguments.map(Expr::to_doc))
      }
      (10, doc)
    }
    StructLiteral(type_name~, type_arguments~, fields~, ..) => {
      let head = text(type_name) +
        bracketed_type_arguments(type_arguments) +
        text("::")
      (10, head + brace_comma_block(fields.map(StructLiteralField::to_doc)))
    }
    Builtin(name, ..) =>
      (10, keyword("builtin") + parenthesized([source_string(name)]))
    FunctionLiteral(type_parameters~, parameters~, return_type~, body~, ..) => {
      let return_doc = match return_type {
        Some(type_) => space + text("->") + space + type_.to_doc()
        None => empty
      }
      (
        10,
        keyword("fn") +
        bracketed_type_parameters(type_parameters) +
        space +
        parenthesized(parameters.map(FunctionLiteralParameter::to_doc)) +
        return_doc +
        space +
        body.to_doc(),
      )
    }
    Block(items~, result~, ..) => {
      let docs = items.map(LocalItem::to_doc)
      docs.push(result.to_doc())
      (10, brace_block(docs))
    }
    If(condition~, then_branch~, else_branch~, ..) =>
      (
        10,
        keyword("if") +
        space +
        condition.to_doc() +
        space +
        then_branch.to_doc() +
        space +
        keyword("else") +
        space +
        else_branch.to_doc(),
      )
    Match(scrutinee~, arms~, ..) =>
      (
        10,
        keyword("match") +
        space +
        scrutinee.to_doc() +
        space +
        brace_block(arms.map(MatchArm::to_doc)),
      )
    Call(callee~, arguments~, ..) =>
      (
        9,
        callee.to_doc_with_precedence(9) +
        parenthesized(arguments.map(CallArgument::to_doc)),
      )
    Field(base~, name~, ..) =>
      (9, base.to_doc_with_precedence(9) + text(".") + text(name))
    Unary(operator~, operand~, ..) =>
      (8, operator.to_doc() + operand.to_doc_with_precedence(8))
    Binary(operator~, left~, right~, ..) => {
      let precedence = operator.precedence()
      (
        precedence,
        left.to_doc_with_precedence(precedence) +
        space +
        operator.to_doc() +
        space +
        right.to_doc_with_precedence(precedence + 1),
      )
    }
    Pipeline(left~, right~, ..) =>
      (
        1,
        left.to_doc_with_precedence(1) +
        space +
        text("|>") +
        space +
        right.to_doc_with_precedence(2),
      )
  }
  if precedence < context_precedence {
    parens(doc)
  } else {
    doc
  }
}

///|
fn StructLiteralField::to_doc(self : StructLiteralField) -> Document {
  match self {
    Value(name~, value~, ..) =>
      match value {
        Some(value) => text(name) + text(":") + space + value.to_doc()
        None => text(name)
      }
    TypeWitness(name~, witness~, ..) =>
      text(name) + space + text("=") + space + witness.to_doc()
  }
}

///|
pub impl @prettyprinter.Pretty for StructLiteralField with fn pretty(
  field : StructLiteralField,
) {
  field.to_doc()
}

///|
fn LocalItem::to_doc(self : LocalItem) -> Document {
  match self {
    Let(declaration) => declaration.to_doc()
    PatternLet(declaration) => declaration.to_doc()
    Function(declaration) => declaration.to_doc()
    Offer(declaration) => declaration.to_doc()
  }
}

///|
pub impl @prettyprinter.Pretty for LocalItem with fn pretty(item : LocalItem) {
  item.to_doc()
}

///|
pub impl @prettyprinter.Pretty for PatternLetDeclaration with fn pretty(
  declaration : PatternLetDeclaration,
) {
  declaration.to_doc()
}

///|
fn PatternLetDeclaration::to_doc(self : PatternLetDeclaration) -> Document {
  keyword("let") +
  space +
  self.pattern.to_doc() +
  space +
  text("=") +
  space +
  self.initializer.to_doc()
}

///|
fn FunctionLiteralParameter::to_doc(
  self : FunctionLiteralParameter,
) -> Document {
  let prefix = if self.is_offered { keyword("offer") + space } else { empty }
  match self.type_annotation {
    Some(type_) =>
      prefix + text(self.name) + space + text(":") + space + type_.to_doc()
    None => prefix + text(self.name)
  }
}

///|
pub impl @prettyprinter.Pretty for FunctionLiteralParameter with fn pretty(
  parameter : FunctionLiteralParameter,
) {
  parameter.to_doc()
}

///|
fn CallArgument::to_doc(self : CallArgument) -> Document {
  match self {
    Positional(expression) => expression.to_doc()
    Named(name~, value~, ..) => text(name) + text("=") + value.to_doc()
  }
}

///|
pub impl @prettyprinter.Pretty for CallArgument with fn pretty(
  argument : CallArgument,
) {
  argument.to_doc()
}

///|
fn parameter_modifiers(is_auto : Bool, is_offered : Bool) -> Document {
  let docs = []
  if is_auto {
    docs.push(keyword("auto"))
  }
  if is_offered {
    docs.push(keyword("offer"))
  }
  if docs.is_empty() {
    empty
  } else {
    separate(space, docs) + space
  }
}

///|
fn MatchArm::to_doc(self : MatchArm) -> Document {
  let head = self.pattern.to_doc() + space + text("=>")
  if self.body.breaks_after_match_arrow() {
    head + nest(hardline + self.body.to_doc())
  } else {
    head + space + self.body.to_doc()
  }
}

///|
fn Expr::breaks_after_match_arrow(self : Expr) -> Bool {
  match self {
    If(..) | Match(..) => true
    _ => false
  }
}

///|
pub impl @prettyprinter.Pretty for MatchArm with fn pretty(arm : MatchArm) {
  arm.to_doc()
}

///|
pub impl @prettyprinter.Pretty for Pattern with fn pretty(pattern : Pattern) {
  pattern.to_doc()
}

///|
fn Pattern::to_doc(self : Pattern) -> Document {
  match self {
    Wildcard(_) => text("_")
    Binding(name, ..) => text(name)
    IntLiteral(value, ..) => text(value)
    StringLiteral(value, ..) => source_string(value)
    BoolLiteral(value, ..) => text(value.to_string())
    QualifiedVariant(type_name~, variant~, type_binders~, arguments~, ..) => {
      let binders_doc = if type_binders.is_empty() {
        empty
      } else {
        brackets(join_comma(type_binders.map(text)))
      }
      let head = text(type_name) + text("::") + text(variant) + binders_doc
      if arguments.is_empty() {
        head
      } else {
        head + parenthesized(arguments.map(Pattern::to_doc))
      }
    }
    ShorthandVariant(variant~, type_binders~, arguments~, ..) => {
      let binders_doc = if type_binders.is_empty() {
        empty
      } else {
        brackets(join_comma(type_binders.map(text)))
      }
      let head = text("::") + text(variant) + binders_doc
      if arguments.is_empty() {
        head
      } else {
        head + parenthesized(arguments.map(Pattern::to_doc))
      }
    }
    Struct(type_name~, fields~, ..) =>
      text(type_name) +
      text("::") +
      brace_comma_block(fields.map(StructPatternField::to_doc))
  }
}

///|
fn StructPatternField::to_doc(self : StructPatternField) -> Document {
  match self {
    Value(name~, pattern~, ..) =>
      match pattern {
        Some(pattern) => text(name) + text(":") + space + pattern.to_doc()
        None => text(name)
      }
    TypeBinder(name~, ..) => text(name)
    TypeWildcard(..) => text("_")
  }
}

///|
pub impl @prettyprinter.Pretty for StructPatternField with fn pretty(
  field : StructPatternField,
) {
  field.to_doc()
}

///|
fn UnaryOperator::to_doc(self : UnaryOperator) -> Document {
  match self {
    Neg => text("-")
    Not => text("!")
  }
}

///|
pub impl @prettyprinter.Pretty for UnaryOperator with fn pretty(
  operator : UnaryOperator,
) {
  operator.to_doc()
}

///|
fn BinaryOperator::to_doc(self : BinaryOperator) -> Document {
  match self {
    Add => text("+")
    Sub => text("-")
    Mul => text("*")
    Div => text("/")
    Rem => text("%")
    Equal => text("==")
    NotEqual => text("!=")
    Less => text("<")
    LessEqual => text("<=")
    Greater => text(">")
    GreaterEqual => text(">=")
    And => text("&&")
    Or => text("||")
  }
}

///|
pub impl @prettyprinter.Pretty for BinaryOperator with fn pretty(
  operator : BinaryOperator,
) {
  operator.to_doc()
}
