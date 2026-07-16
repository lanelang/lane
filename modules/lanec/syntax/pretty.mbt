///|
fn assignment_expr_doc(
  head : Document,
  value : Expr,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  source_assignment(
    head,
    value.first_line_doc(),
    trivia.decorate_trailing(value.loc(), value.to_doc(trivia~)),
  )
}

///|
fn standalone_expr_doc(
  expression : Expr,
  trivia : SourceFormatTrivia,
) -> Document {
  trivia.decorate(expression.loc(), expression.to_doc(trivia~))
}

///|
fn bracketed_type_parameters(parameters : Array[TypeParameter]) -> Document {
  if parameters.is_empty() {
    empty
  } else {
    bracketed_comma_list(parameters.map(TypeParameter::to_doc))
  }
}

///|
fn bracketed_type_arguments(arguments : Array[Type]) -> Document {
  if arguments.is_empty() {
    empty
  } else {
    bracketed_comma_list(arguments.map(Type::to_doc))
  }
}

///|
pub impl @prettyprinter.Pretty for SourceFile with fn pretty(file : SourceFile) {
  file.to_doc()
}

///|
pub fn format_source_file_with_trivia(
  file : SourceFile,
  trivia : SourceFormatTrivia,
) -> Document {
  file.to_doc(trivia~)
}

///|
fn SourceFile::to_doc(
  self : SourceFile,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let docs = [keyword("module") + space + self.module_path.to_doc()]
  for import_ in self.imports {
    docs.push(import_.to_doc(trivia~))
  }
  if !self.declarations.is_empty() {
    docs.push(
      separate(
        hardline + hardline,
        self.declarations.map(fn(declaration) { declaration.to_doc(trivia~) }),
      ),
    )
  }
  trivia.decorate_leading(
    self.loc,
    separate(hardline + hardline, docs) + (trivia.eof)(),
  )
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
fn ImportDeclaration::to_doc(
  self : ImportDeclaration,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let doc = match self {
    Qualified(module_path~, ..) =>
      keyword("import") + space + module_path.to_doc()
    Open(module_path~, ..) =>
      keyword("import") + space + module_path.to_doc() + text(".*")
    Selective(module_path~, items~, ..) =>
      keyword("import") +
      space +
      module_path.to_doc() +
      text(".") +
      braced_comma_list(items.map(ImportItem::to_doc))
  }
  trivia.decorate(self.loc(), doc)
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
fn TopLevelDeclaration::to_doc(
  self : TopLevelDeclaration,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  match self {
    Struct(declaration) => declaration.to_doc(trivia~)
    Enum(declaration) => declaration.to_doc(trivia~)
    Effect(declaration) => declaration.to_doc(trivia~)
    ExternalType(declaration) => declaration.to_doc(trivia~)
    TypeAlias(declaration) => declaration.to_doc(trivia~)
    Function(declaration) => declaration.to_doc(trivia~)
    Let(declaration) => declaration.to_doc(trivia~)
    Offer(declaration) => declaration.to_doc(trivia~)
  }
}

///|
pub impl @prettyprinter.Pretty for ExternalTypeDeclaration with fn pretty(
  declaration : ExternalTypeDeclaration,
) {
  declaration.to_doc()
}

///|
fn ExternalTypeDeclaration::to_doc(
  self : ExternalTypeDeclaration,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let doc = public_prefix(self.is_public) +
    keyword("extern") +
    space +
    keyword("type") +
    space +
    text(self.name) +
    bracketed_type_parameters(self.type_parameters) +
    space +
    text(":") +
    space +
    self.result_kind.to_doc()
  trivia.decorate_leading(self.loc, doc)
}

///|
fn ExternalTypeKind::to_doc(self : ExternalTypeKind) -> Document {
  match self {
    Type(_) => text("Type")
    Effect(_) => text("Effect")
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
fn StructDeclaration::to_doc(
  self : StructDeclaration,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let doc = public_prefix(self.is_public) +
    keyword("struct") +
    space +
    text(self.name) +
    bracketed_type_parameters(self.type_parameters) +
    space +
    brace_block(self.members.map(fn(item) { item.to_doc(trivia~) }))
  trivia.decorate_leading(self.loc, doc)
}

///|
fn StructMember::to_doc(
  self : StructMember,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  match self {
    TypeMember(declaration) => declaration.to_doc(trivia~)
    Field(field) => field.to_doc(trivia~)
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
fn TypeMemberDeclaration::to_doc(
  self : TypeMemberDeclaration,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let doc = keyword("type") +
    space +
    text(self.name) +
    space +
    text(":") +
    space +
    self.kind.to_doc()
  trivia.decorate_leading(self.loc, doc)
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
fn EffectDeclaration::to_doc(
  self : EffectDeclaration,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let doc = public_prefix(self.is_public) +
    keyword("effect") +
    space +
    text(self.name) +
    bracketed_type_parameters(self.type_parameters) +
    space +
    brace_block(
      self.operations.map(fn(operation) { operation.to_doc(trivia~) }),
    )
  trivia.decorate_leading(self.loc, doc)
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
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let doc = text(self.name) +
    bracketed_type_parameters(self.type_parameters) +
    parenthesized_comma_list_with_suffix(
      self.payload.map(Type::to_doc),
      space + text("->") + space + self.result.to_doc(),
    )
  trivia.decorate(self.loc, doc)
}

///|
pub impl @prettyprinter.Pretty for FieldDeclaration with fn pretty(
  field : FieldDeclaration,
) {
  field.to_doc()
}

///|
fn FieldDeclaration::to_doc(
  self : FieldDeclaration,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let doc = text(self.name) + space + text(":") + space + self.type_.to_doc()
  trivia.decorate(self.loc, doc)
}

///|
pub impl @prettyprinter.Pretty for EnumDeclaration with fn pretty(
  declaration : EnumDeclaration,
) {
  declaration.to_doc()
}

///|
fn EnumDeclaration::to_doc(
  self : EnumDeclaration,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let doc = public_prefix(self.is_public) +
    keyword("enum") +
    space +
    text(self.name) +
    bracketed_type_parameters(self.type_parameters) +
    space +
    brace_block(self.variants.map(fn(variant) { variant.to_doc(trivia~) }))
  trivia.decorate(self.loc, doc)
}

///|
fn EnumVariant::to_doc(
  self : EnumVariant,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let type_parameters = bracketed_type_parameters(self.type_parameters)
  let doc = text(self.name) +
    type_parameters +
    parenthesized_comma_list(self.payload.map(Type::to_doc))
  trivia.decorate(self.loc, doc)
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
fn TypeAliasDeclaration::to_doc(
  self : TypeAliasDeclaration,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let result_kind = match self.result_kind {
    Some(kind) => space + text(":") + space + kind.to_doc()
    None => empty
  }
  let doc = public_prefix(self.is_public) +
    keyword("type") +
    space +
    text(self.name) +
    bracketed_type_parameters(self.type_parameters) +
    result_kind +
    space +
    text("=") +
    space +
    self.body.to_doc()
  trivia.decorate_leading(self.loc, doc)
}

///|
pub impl @prettyprinter.Pretty for TypeAliasBody with fn pretty(
  body : TypeAliasBody,
) {
  body.to_doc()
}

///|
fn TypeAliasBody::to_doc(self : TypeAliasBody) -> Document {
  match self {
    TypeBody(type_) => type_.to_doc()
    EffectBody(effect) => effect.to_doc()
  }
}

///|
pub impl @prettyprinter.Pretty for FunctionDeclaration with fn pretty(
  declaration : FunctionDeclaration,
) {
  declaration.to_doc()
}

///|
fn FunctionDeclaration::to_doc(
  self : FunctionDeclaration,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let suffix = space +
    text("->") +
    space +
    self.return_type.to_doc() +
    self.effect.to_annotation_doc()
  let doc = public_prefix(self.is_public) +
    keyword("fn") +
    bracketed_type_parameters(self.type_parameters) +
    space +
    text(self.name) +
    parenthesized_comma_list_with_suffix(
      self.parameters.map(Parameter::to_doc),
      suffix,
    ) +
    space +
    self.body.to_doc(trivia~)
  trivia.decorate_leading(self.loc, doc)
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
fn LetDeclaration::to_doc(
  self : LetDeclaration,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let name_doc = match self.name {
    Some(name) => space + text(name)
    None => empty
  }
  let type_doc = match self.type_annotation {
    Some(type_) => space + text(":") + space + type_.to_doc()
    None => empty
  }
  let doc = assignment_expr_doc(
    public_prefix(self.is_public) + keyword("let") + name_doc + type_doc,
    self.initializer,
    trivia~,
  )
  trivia.decorate_leading(self.loc, doc)
}

///|
pub impl @prettyprinter.Pretty for OfferDeclaration with fn pretty(
  declaration : OfferDeclaration,
) {
  declaration.to_doc()
}

///|
fn OfferDeclaration::to_doc(
  self : OfferDeclaration,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let doc = assignment_expr_doc(
    public_prefix(self.is_public) +
    keyword("offer") +
    space +
    text(self.name) +
    space +
    text(":") +
    space +
    self.type_annotation.to_doc(),
    self.initializer,
    trivia~,
  )
  trivia.decorate(self.loc, doc)
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
    Function(type_parameters~, parameters~, result~, effect~, ..) =>
      bracketed_type_parameters(type_parameters) +
      parenthesized_comma_list(parameters.map(Type::to_doc)) +
      space +
      text("->") +
      space +
      result.to_doc() +
      effect.to_annotation_doc()
  }
}

///|
fn EffectTerm::to_doc(self : EffectTerm) -> Document {
  match self {
    Empty(..) => text("{}")
    Term(type_~, ..) => type_.to_doc()
    Union(items~, ..) => braced_comma_list(items.map(Type::to_doc))
  }
}

///|
fn EffectTerm::to_annotation_doc(self : EffectTerm) -> Document {
  match self {
    Empty(..) => empty
    _ => space + text("!") + space + self.to_doc()
  }
}

///|
pub impl @prettyprinter.Pretty for Expr with fn pretty(expression : Expr) {
  expression.to_doc()
}

///|
fn Expr::to_doc(
  self : Expr,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  self.to_doc_with_precedence(0, trivia~)
}

///|
fn Expr::first_line_doc(self : Expr) -> Document {
  match self {
    FunctionLiteral(
      type_parameters~,
      parameters~,
      return_type~,
      effect~,
      body~,
      ..
    ) => {
      let head = function_literal_head_doc(
        type_parameters, parameters, return_type, effect,
      )
      head + space + body.first_line_doc()
    }
    Handler(body~, ..) => keyword("handle") + space + body.first_line_doc()
    Block(..) => char('{')
    StructLiteral(owner~, ..) => owner.to_doc() + text("::") + char('{')
    If(condition~, then_branch~, ..) =>
      keyword("if") +
      space +
      condition.to_doc() +
      space +
      then_branch.first_line_doc()
    Match(scrutinee~, ..) =>
      keyword("match") + space + scrutinee.to_doc() + space + char('{')
    Call(callee~, arguments~, ..) =>
      callee.to_doc_with_precedence(9) +
      parenthesized_comma_list(
        arguments.map(fn(argument) { argument.first_line_doc() }),
      )
    TypeApplication(callee~, arguments~, ..) =>
      callee.to_doc_with_precedence(9) + bracketed_type_arguments(arguments)
    _ => self.to_doc()
  }
}

///|
fn Expr::to_doc_with_precedence(
  self : Expr,
  context_precedence : Int,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let (precedence, doc) = match self {
    IntLiteral(value, ..) => (10, text(value))
    DoubleLiteral(value, ..) => (10, text(value))
    StringLiteral(value, ..) => (10, source_string(value))
    BoolLiteral(value, ..) => (10, text(value.to_string()))
    UnitLiteral(..) => (10, text("()"))
    Var(name, ..) => (10, text(name))
    QualifiedVariant(owner~, variant~, variant_type_arguments~, arguments~, ..) => {
      let head = owner.to_doc() +
        text("::") +
        text(variant) +
        bracketed_type_arguments(variant_type_arguments)
      let doc = head +
        parenthesized_comma_list(
          arguments.map(fn(argument) { argument.to_doc(trivia~) }),
        )
      (10, doc)
    }
    StructLiteral(owner~, fields~, ..) => {
      let head = owner.to_doc() + text("::")
      (
        10,
        head +
        braced_comma_list(fields.map(fn(field) { field.to_doc(trivia~) })),
      )
    }
    ListLiteral(items~, ..) =>
      (10, bracketed_comma_list(items.map(fn(item) { item.to_doc(trivia~) })))
    Builtin(name, ..) =>
      (10, keyword("builtin") + parenthesized_comma_list([source_string(name)]))
    Extern(name, ..) =>
      (10, keyword("extern") + parenthesized_comma_list([source_string(name)]))
    FunctionLiteral(
      type_parameters~,
      parameters~,
      return_type~,
      effect~,
      body~,
      ..
    ) =>
      (
        10,
        function_literal_head_doc(
          type_parameters, parameters, return_type, effect,
        ) +
        space +
        standalone_expr_doc(body, trivia),
      )
    EffectOperationCall(name~, type_witnesses~, arguments~, ..) =>
      (
        10,
        name.to_doc() +
        text("!") +
        bracketed_type_arguments(type_witnesses) +
        parenthesized_comma_list(
          arguments.map(fn(argument) { argument.to_doc(trivia~) }),
        ),
      )
    TypeApplication(callee~, arguments~, ..) =>
      (
        9,
        callee.to_doc_with_precedence(9, trivia~) +
        bracketed_type_arguments(arguments),
      )
    Handler(body~, handlers~, final_branch~, ..) => {
      let docs = [
        source_prefixed(
          keyword("handle"),
          body.first_line_doc(),
          body.to_doc(trivia~),
        ),
      ]
      for handler in handlers {
        docs.push(handler.to_doc(trivia~))
      }
      docs.push(final_branch.to_doc(trivia~))
      (10, separate(space, docs))
    }
    Block(items~, result~, ..) => {
      let docs = items.map(fn(item) { item.to_doc(trivia~) })
      docs.push(standalone_expr_doc(result, trivia))
      (10, brace_block(docs))
    }
    If(condition~, then_branch~, else_branch~, ..) =>
      (
        10,
        breakable_head(keyword("if"), condition.to_doc(trivia~)) +
        space +
        standalone_expr_doc(then_branch, trivia) +
        space +
        keyword("else") +
        space +
        standalone_expr_doc(else_branch, trivia),
      )
    Match(scrutinee~, arms~, ..) =>
      (
        10,
        breakable_head(keyword("match"), scrutinee.to_doc(trivia~)) +
        space +
        brace_block(arms.map(fn(arm) { arm.to_doc(trivia~) })),
      )
    Call(callee~, arguments~, ..) =>
      (
        9,
        callee.to_doc_with_precedence(9, trivia~) +
        parenthesized_comma_list(
          arguments.map(fn(argument) { argument.to_doc(trivia~) }),
        ),
      )
    Field(..) => (9, self.field_chain_doc(trivia~))
    Unary(operator~, operand~, ..) =>
      (8, operator.to_doc() + operand.to_doc_with_precedence(8, trivia~))
    Binary(operator~, left~, right~, ..) => {
      let precedence = operator.precedence()
      (
        precedence,
        group(
          left.to_doc_with_precedence(precedence, trivia~) +
          nest(
            line +
            operator.to_doc() +
            space +
            right.to_doc_with_precedence(precedence + 1, trivia~),
          ),
        ),
      )
    }
    Pipeline(..) => (1, self.pipeline_chain_doc(trivia~))
  }
  let result = if precedence < context_precedence { parens(doc) } else { doc }
  result
}

///|
fn Expr::pipeline_chain_doc(
  self : Expr,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let (root, segments) = self.pipeline_chain_parts()
  let root_doc = root.to_doc_with_precedence(1, trivia~)
  let mut inline_first_line = root_doc
  for segment in segments {
    inline_first_line = inline_first_line +
      space +
      text("|>") +
      space +
      segment.first_line_doc()
  }
  dynamic(fn(context) {
    if inline_first_line.requirement() <= context.current_remain() {
      let mut inline_doc = root_doc
      for segment in segments {
        inline_doc = inline_doc +
          space +
          text("|>") +
          space +
          segment.to_doc_with_precedence(2, trivia~)
      }
      inline_doc
    } else {
      group(
        root_doc +
        nest(
          line +
          separate(
            line,
            segments.map(fn(segment) {
              text("|>") + space + segment.to_doc_with_precedence(2, trivia~)
            }),
          ),
        ),
      )
    }
  })
}

///|
fn Expr::pipeline_chain_parts(self : Expr) -> (Expr, Array[Expr]) {
  match self {
    Pipeline(left~, right~, ..) => {
      let (root, segments) = left.pipeline_chain_parts()
      segments.push(right)
      (root, segments)
    }
    _ => (self, [])
  }
}

///|
fn Expr::field_chain_doc(
  self : Expr,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let (root, fields) = self.field_chain_parts()
  group(
    root.to_doc_with_precedence(9, trivia~) +
    nest(
      softline +
      separate(softline, fields.map(fn(field) { text(".") + text(field) })),
    ),
  )
}

///|
fn Expr::field_chain_parts(self : Expr) -> (Expr, Array[String]) {
  match self {
    Field(base~, name~, ..) => {
      let (root, fields) = base.field_chain_parts()
      fields.push(name)
      (root, fields)
    }
    _ => (self, [])
  }
}

///|
fn EffectOperationName::to_doc(self : EffectOperationName) -> Document {
  match self {
    Qualified(owner~, operation~, ..) =>
      owner.to_doc() + text("::") + text(operation)
    Unqualified(operation~, ..) => text(operation)
  }
}

///|
fn HandlerWithBlock::to_doc(
  self : HandlerWithBlock,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  keyword("with") +
  space +
  brace_block(self.arms.map(fn(arm) { arm.to_doc(trivia~) }))
}

///|
fn HandlerOperationArm::to_doc(
  self : HandlerOperationArm,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let parameters = self.payload_patterns.map(Pattern::to_doc)
  parameters.push(text(self.resume_binder))
  let binders = if self.type_binders.is_empty() {
    empty
  } else {
    bracketed_comma_list(self.type_binders.map(text))
  }
  let head = self.name.to_doc() +
    binders +
    parenthesized_comma_list(parameters) +
    space +
    text("=>")
  let doc = if self.body.breaks_after_match_arrow() {
    head +
    nest(
      hardline +
      trivia.decorate_trailing(self.body.loc(), self.body.to_doc(trivia~)),
    )
  } else {
    head +
    space +
    trivia.decorate_trailing(self.body.loc(), self.body.to_doc(trivia~))
  }
  trivia.decorate_leading(self.loc, doc)
}

///|
fn HandlerFinalBranch::to_doc(
  self : HandlerFinalBranch,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let doc = keyword("final") +
    space +
    text(self.binder) +
    space +
    standalone_expr_doc(self.body, trivia)
  trivia.decorate_leading(self.loc, doc)
}

///|
fn StructLiteralField::to_doc(
  self : StructLiteralField,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let (span, doc) = match self {
    Value(name~, value~, loc~) =>
      match value {
        Some(value) =>
          (loc, text(name) + text(":") + space + value.to_doc(trivia~))
        None => (loc, text(name))
      }
    TypeWitness(name~, witness~, loc~) =>
      (loc, text(name) + space + text("=") + space + witness.to_doc())
  }
  trivia.decorate_leading(span, doc)
}

///|
pub impl @prettyprinter.Pretty for StructLiteralField with fn pretty(
  field : StructLiteralField,
) {
  field.to_doc()
}

///|
fn LocalItem::to_doc(
  self : LocalItem,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  match self {
    Let(declaration) => declaration.to_doc(trivia~)
    PatternLet(declaration) => declaration.to_doc(trivia~)
    Function(declaration) => declaration.to_doc(trivia~)
    Offer(declaration) => declaration.to_doc(trivia~)
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
fn PatternLetDeclaration::to_doc(
  self : PatternLetDeclaration,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let type_doc = match self.type_annotation {
    Some(type_) => space + text(":") + space + type_.to_doc()
    None => empty
  }
  let doc = assignment_expr_doc(
    keyword("let") + space + self.pattern.to_doc() + type_doc,
    self.initializer,
    trivia~,
  )
  trivia.decorate_leading(self.loc, doc)
}

///|
fn function_literal_head_doc(
  type_parameters : Array[TypeParameter],
  parameters : Array[FunctionLiteralParameter],
  return_type : Type?,
  effect : EffectTerm?,
) -> Document {
  let return_doc = match return_type {
    Some(type_) => space + text("->") + space + type_.to_doc()
    None => empty
  }
  let effect_doc = match effect {
    Some(effect) => effect.to_annotation_doc()
    None => empty
  }
  keyword("fn") +
  bracketed_type_parameters(type_parameters) +
  parenthesized_comma_list(parameters.map(FunctionLiteralParameter::to_doc)) +
  return_doc +
  effect_doc
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
fn CallArgument::to_doc(
  self : CallArgument,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  match self {
    Positional(value~, ..) => value.to_doc(trivia~)
    Named(name~, value~, ..) => {
      let doc = text(name) + text("=") + value.to_doc(trivia~)
      trivia.decorate_leading(self.loc(), doc)
    }
  }
}

///|
fn CallArgument::first_line_doc(self : CallArgument) -> Document {
  match self {
    Positional(value~, ..) => value.first_line_doc()
    Named(name~, value~, ..) => text(name) + text("=") + value.first_line_doc()
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
fn MatchArm::to_doc(
  self : MatchArm,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let head = self.pattern.to_doc() + space + text("=>")
  let doc = if self.body.breaks_after_match_arrow() {
    head +
    nest(
      hardline +
      trivia.decorate_trailing(self.body.loc(), self.body.to_doc(trivia~)),
    )
  } else {
    head +
    space +
    trivia.decorate_trailing(self.body.loc(), self.body.to_doc(trivia~))
  }
  trivia.decorate_leading(self.loc, doc)
}

///|
fn Expr::breaks_after_match_arrow(self : Expr) -> Bool {
  match self {
    If(..) | Match(..) | Handler(..) => true
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
    DoubleLiteral(value, ..) => text(value)
    StringLiteral(value, ..) => source_string(value)
    BoolLiteral(value, ..) => text(value.to_string())
    QualifiedVariant(type_name~, variant~, type_binders~, arguments~, ..) => {
      let binders_doc = if type_binders.is_empty() {
        empty
      } else {
        bracketed_comma_list(type_binders.map(text))
      }
      let head = text(type_name) + text("::") + text(variant) + binders_doc
      head + parenthesized_comma_list(arguments.map(Pattern::to_doc))
    }
    UnqualifiedVariant(variant~, type_binders~, arguments~, ..) => {
      let binders_doc = if type_binders.is_empty() {
        empty
      } else {
        bracketed_comma_list(type_binders.map(text))
      }
      let head = text(variant) + binders_doc
      head + parenthesized_comma_list(arguments.map(Pattern::to_doc))
    }
    Struct(type_name~, fields~, ..) =>
      text(type_name) +
      text("::") +
      braced_comma_list(fields.map(StructPatternField::to_doc))
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
