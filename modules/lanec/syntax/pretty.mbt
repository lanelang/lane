///|
fn assignment_expr_doc(
  head : Document,
  head_end_offset : Int,
  value : Expr,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let force_break = (trivia.has_leading)(value.loc())
  let value_doc = trivia.decorate_trailing(value.loc(), value.to_doc(trivia~))
  let (separator_boundary, force_separator_break) = trivia.take_boundary(
    head_end_offset,
    value.loc().start_offset,
  )
  source_assignment(
    head,
    value.first_line_doc(),
    value_doc,
    force_break~,
    separator_boundary~,
    force_separator_break~,
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
fn boundary_separated(
  left : Document,
  right : Document,
  start_offset : Int,
  end_offset : Int,
  trivia : SourceFormatTrivia,
) -> Document {
  let (boundary, force_break) = trivia.take_boundary(start_offset, end_offset)
  if force_break {
    left + hardline + boundary + hardline + right
  } else {
    left + space + right
  }
}

///|
fn bracketed_type_parameters(
  parameters : Array[TypeParameter],
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
  start_offset? : Int = -1,
  end_offset? : Int = -1,
) -> Document {
  if parameters.is_empty() {
    empty
  } else {
    let docs = parameters.map(fn(parameter) { parameter.to_doc(trivia~) })
    let (dangling, force_break) = if start_offset >= 0 && end_offset >= 0 {
      trivia.take_delimited(
        '[',
        start_offset,
        end_offset,
        child_spans=parameters.map(fn(parameter) { parameter.loc }),
      )
    } else {
      (empty, false)
    }
    bracketed_comma_list(
      docs,
      item_spans=parameters.map(fn(parameter) { parameter.loc }),
      trivia~,
      dangling~,
      force_break~,
    )
  }
}

///|
fn bracketed_type_arguments(
  arguments : Array[Type],
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
  start_offset? : Int = -1,
  end_offset? : Int = -1,
) -> Document {
  if arguments.is_empty() {
    empty
  } else {
    let docs = arguments.map(fn(argument) { argument.to_doc(trivia~) })
    let (dangling, force_break) = if start_offset >= 0 && end_offset >= 0 {
      trivia.take_delimited(
        '[',
        start_offset,
        end_offset,
        child_spans=arguments.map(Type::loc),
      )
    } else {
      (empty, false)
    }
    bracketed_comma_list(
      docs,
      item_spans=arguments.map(Type::loc),
      trivia~,
      dangling~,
      force_break~,
    )
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
  let mut doc = trivia.decorate_trailing(
    self.module_path.loc,
    keyword("module") + space + self.module_path.to_doc(),
  )
  let mut previous = self.module_path.loc
  if !self.imports.is_empty() {
    doc = doc +
      (trivia.top_level_separator)(previous, self.imports[0].loc()) +
      separate_source_items(
        self.imports.map(fn(import_) { import_.to_doc(trivia~) }),
        self.imports.map(ImportDeclaration::loc),
        trivia,
      )
    previous = self.imports[self.imports.length() - 1].loc()
  }
  if !self.declarations.is_empty() {
    doc = doc +
      (trivia.top_level_separator)(previous, self.declarations[0].loc()) +
      separate_top_level_items(
        self.declarations.map(fn(declaration) { declaration.to_doc(trivia~) }),
        self.declarations.map(TopLevelDeclaration::loc),
        trivia,
      )
  }
  trivia.decorate_leading(self.loc, doc + (trivia.eof)())
}

///|
fn separate_top_level_items(
  docs : Array[Document],
  spans : Array[SourceSpan],
  trivia : SourceFormatTrivia,
) -> Document {
  guard !docs.is_empty() else { return empty }
  let mut result = docs[0]
  for index in 1..<docs.length() {
    result = result +
      (trivia.top_level_separator)(spans[index - 1], spans[index]) +
      docs[index]
  }
  result
}

///|
fn TopLevelDeclaration::loc(self : TopLevelDeclaration) -> SourceSpan {
  match self {
    Struct(value) => value.loc
    Enum(value) => value.loc
    Effect(value) => value.loc
    ExternalType(value) => value.loc
    TypeAlias(value) => value.loc
    Function(value) => value.loc
    Let(value) => value.loc
    Offer(value) => value.loc
  }
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
    Selective(module_path~, items~, ..) => {
      let item_docs = items.map(fn(item) { item.to_doc(trivia~) })
      let start_offset = module_path.loc.end_offset
      let end_offset = self.loc().end_offset
      let (dangling, force_break) = trivia.take_delimited(
        '{',
        start_offset,
        end_offset,
        child_spans=items.map(fn(item) { item.loc }),
      )
      keyword("import") +
      space +
      module_path.to_doc() +
      text(".") +
      braced_comma_list(
        item_docs,
        item_spans=items.map(fn(item) { item.loc }),
        trivia~,
        dangling~,
        force_break~,
      )
    }
  }
  trivia.decorate(self.loc(), doc)
}

///|
pub impl @prettyprinter.Pretty for ImportItem with fn pretty(item : ImportItem) {
  item.to_doc()
}

///|
fn ImportItem::to_doc(
  self : ImportItem,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  trivia.decorate(self.loc, text(self.name))
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
fn ExternalTypeKind::loc(self : ExternalTypeKind) -> SourceSpan {
  match self {
    Type(loc~) | Effect(loc~) => loc
  }
}

///|
fn StructMember::loc(self : StructMember) -> SourceSpan {
  match self {
    TypeMember(declaration) => declaration.loc
    Field(field) => field.loc
  }
}

///|
fn LocalItem::loc(self : LocalItem) -> SourceSpan {
  match self {
    Let(declaration) => declaration.loc
    PatternLet(declaration) => declaration.loc
    Function(declaration) => declaration.loc
    Offer(declaration) => declaration.loc
    Expression(loc~, ..) => loc
  }
}

///|
fn EffectOperationName::argument_search_start(
  self : EffectOperationName,
) -> Int {
  match self {
    Qualified(owner~, ..) => owner.loc().end_offset
    Unqualified(loc~, ..) => loc.start_offset
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
  let result_kind = self.result_kind.to_doc(trivia~)
  let header = public_prefix(self.is_public) +
    keyword("extern") +
    space +
    keyword("type") +
    space +
    text(self.name) +
    bracketed_type_parameters(
      self.type_parameters,
      trivia~,
      start_offset=self.loc.start_offset,
      end_offset=self.result_kind.loc().start_offset,
    )
  let header_end = if self.type_parameters.is_empty() {
    self.loc.start_offset
  } else {
    self.type_parameters[self.type_parameters.length() - 1].loc.end_offset
  }
  let doc = boundary_separated(
      header,
      text(":"),
      header_end,
      self.result_kind.loc().start_offset,
      trivia,
    ) +
    space +
    result_kind
  trivia.decorate(self.loc, doc)
}

///|
fn ExternalTypeKind::to_doc(
  self : ExternalTypeKind,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let doc = match self {
    Type(_) => text("Type")
    Effect(_) => text("Effect")
  }
  trivia.decorate(self.loc(), doc)
}

///|
pub impl @prettyprinter.Pretty for TypeParameter with fn pretty(
  parameter : TypeParameter,
) {
  parameter.to_doc()
}

///|
fn TypeParameter::to_doc(
  self : TypeParameter,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let doc = match self.kind {
    Some(kind) =>
      text(self.name) + space + text(":") + space + kind.to_doc(trivia~)
    None => text(self.name)
  }
  trivia.decorate(self.loc, doc)
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
  let member_docs = self.members.map(fn(item) { item.to_doc(trivia~) })
  let type_parameter_end = if self.members.is_empty() {
    self.loc.end_offset
  } else {
    self.members[0].loc().start_offset
  }
  let type_parameters = bracketed_type_parameters(
    self.type_parameters,
    trivia~,
    start_offset=self.loc.start_offset,
    end_offset=type_parameter_end,
  )
  let (body_dangling, force_body_break) = trivia.take_delimited(
    '{',
    self.loc.start_offset,
    self.loc.end_offset,
    child_spans=self.members.map(StructMember::loc),
  )
  let header = public_prefix(self.is_public) +
    keyword("struct") +
    space +
    text(self.name) +
    type_parameters
  let header_end = if self.type_parameters.is_empty() {
    self.loc.start_offset
  } else {
    self.type_parameters[self.type_parameters.length() - 1].loc.end_offset
  }
  let body_end = if self.members.is_empty() {
    self.loc.end_offset
  } else {
    self.members[0].loc().start_offset
  }
  let doc = boundary_separated(
    header,
    brace_block(
      member_docs,
      item_spans=self.members.map(StructMember::loc),
      trivia~,
      dangling=body_dangling,
      force_break=force_body_break,
    ),
    header_end,
    body_end,
    trivia,
  )
  trivia.decorate(self.loc, doc)
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
  let kind = match self.kind {
    Some(kind) => space + text(":") + space + kind.to_doc(trivia~)
    None => empty
  }
  let doc = keyword("type") + space + text(self.name) + kind
  trivia.decorate(self.loc, doc)
}

///|
pub impl @prettyprinter.Pretty for Kind with fn pretty(kind : Kind) {
  kind.to_doc()
}

///|
fn Kind::to_doc(
  self : Kind,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let doc = match self {
    Type(..) => text("Type")
    Effect(..) => text("Effect")
    Function(parameters~, result~, loc~) => {
      let parameter_docs = parameters.map(fn(parameter) {
        parameter.to_doc(trivia~)
      })
      let (dangling, force_break) = trivia.take_delimited(
        '[',
        loc.start_offset,
        result.loc().start_offset,
      )
      bracketed_comma_list(parameter_docs, dangling~, force_break~) +
      space +
      text("->") +
      space +
      result.to_doc(trivia~)
    }
    Grouped(kind~, loc~) => {
      let (dangling, force_break) = trivia.take_delimited(
        '(',
        loc.start_offset,
        loc.end_offset,
      )
      if force_break {
        parenthesized_comma_list(
          [kind.to_doc(trivia~)],
          dangling~,
          force_break~,
        )
      } else {
        char('(') + kind.to_doc(trivia~) + char(')')
      }
    }
  }
  trivia.decorate(self.loc(), doc)
}

///|
fn Type::function_parameter_doc(
  self : Type,
  single_parameter : Bool,
  trivia : SourceFormatTrivia,
) -> Document {
  if single_parameter && self is Grouped(type_~, ..) {
    type_.to_doc(trivia~)
  } else {
    self.to_doc(trivia~)
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
  let operation_docs = self.operations.map(fn(operation) {
    operation.to_doc(trivia~)
  })
  let type_parameter_end = if self.operations.is_empty() {
    self.loc.end_offset
  } else {
    self.operations[0].loc.start_offset
  }
  let type_parameters = bracketed_type_parameters(
    self.type_parameters,
    trivia~,
    start_offset=self.loc.start_offset,
    end_offset=type_parameter_end,
  )
  let (body_dangling, force_body_break) = trivia.take_delimited(
    '{',
    self.loc.start_offset,
    self.loc.end_offset,
    child_spans=self.operations.map(fn(operation) { operation.loc }),
  )
  let header = public_prefix(self.is_public) +
    keyword("effect") +
    space +
    text(self.name) +
    type_parameters
  let header_end = if self.type_parameters.is_empty() {
    self.loc.start_offset
  } else {
    self.type_parameters[self.type_parameters.length() - 1].loc.end_offset
  }
  let body_end = if self.operations.is_empty() {
    self.loc.end_offset
  } else {
    self.operations[0].loc.start_offset
  }
  let doc = boundary_separated(
    header,
    brace_block(
      operation_docs,
      item_spans=self.operations.map(fn(operation) { operation.loc }),
      trivia~,
      dangling=body_dangling,
      force_break=force_body_break,
    ),
    header_end,
    body_end,
    trivia,
  )
  trivia.decorate(self.loc, doc)
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
  let payload_docs = self.payload.map(fn(type_) { type_.to_doc(trivia~) })
  let payload_start = if self.type_parameters.is_empty() {
    self.loc.start_offset
  } else {
    self.type_parameters[self.type_parameters.length() - 1].loc.end_offset
  }
  let type_parameter_end = if self.payload.is_empty() {
    self.result.loc().start_offset
  } else {
    self.payload[0].loc().start_offset
  }
  let type_parameters = bracketed_type_parameters(
    self.type_parameters,
    trivia~,
    start_offset=self.loc.start_offset,
    end_offset=type_parameter_end,
  )
  let (payload_dangling, force_payload_break) = trivia.take_delimited(
    '(',
    payload_start,
    self.result.loc().start_offset,
    child_spans=self.payload.map(Type::loc),
  )
  let result = self.result.to_doc(trivia~)
  let (arrow_boundary, force_arrow_break) = trivia.take_boundary(
    self.loc.start_offset,
    self.result.loc().start_offset,
  )
  let suffix = if force_arrow_break {
    hardline + arrow_boundary + hardline + text("->") + space + result
  } else {
    space + text("->") + space + result
  }
  let doc = text(self.name) +
    type_parameters +
    parenthesized_comma_list_with_suffix(
      payload_docs,
      suffix,
      item_spans=self.payload.map(Type::loc),
      trivia~,
      dangling=payload_dangling,
      force_break=force_payload_break,
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
  let doc = text(self.name) +
    space +
    text(":") +
    space +
    self.type_.to_doc(trivia~)
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
  let variant_docs = self.variants.map(fn(variant) { variant.to_doc(trivia~) })
  let type_parameter_end = if self.variants.is_empty() {
    self.loc.end_offset
  } else {
    self.variants[0].loc.start_offset
  }
  let type_parameters = bracketed_type_parameters(
    self.type_parameters,
    trivia~,
    start_offset=self.loc.start_offset,
    end_offset=type_parameter_end,
  )
  let (body_dangling, force_body_break) = trivia.take_delimited(
    '{',
    self.loc.start_offset,
    self.loc.end_offset,
    child_spans=self.variants.map(fn(variant) { variant.loc }),
  )
  let header = public_prefix(self.is_public) +
    keyword("enum") +
    space +
    text(self.name) +
    type_parameters
  let header_end = if self.type_parameters.is_empty() {
    self.loc.start_offset
  } else {
    self.type_parameters[self.type_parameters.length() - 1].loc.end_offset
  }
  let body_end = if self.variants.is_empty() {
    self.loc.end_offset
  } else {
    self.variants[0].loc.start_offset
  }
  let doc = boundary_separated(
    header,
    brace_block(
      variant_docs,
      item_spans=self.variants.map(fn(variant) { variant.loc }),
      trivia~,
      dangling=body_dangling,
      force_break=force_body_break,
    ),
    header_end,
    body_end,
    trivia,
  )
  trivia.decorate(self.loc, doc)
}

///|
fn EnumVariant::to_doc(
  self : EnumVariant,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let payload_docs = self.payload.map(fn(type_) { type_.to_doc(trivia~) })
  let payload_start = if self.type_parameters.is_empty() {
    self.loc.start_offset
  } else {
    self.type_parameters[self.type_parameters.length() - 1].loc.end_offset
  }
  let type_parameter_end = if self.payload.is_empty() {
    self.loc.end_offset
  } else {
    self.payload[0].loc().start_offset
  }
  let type_parameters = bracketed_type_parameters(
    self.type_parameters,
    trivia~,
    start_offset=self.loc.start_offset,
    end_offset=type_parameter_end,
  )
  let (payload_dangling, force_payload_break) = trivia.take_delimited(
    '(',
    payload_start,
    self.loc.end_offset,
    child_spans=self.payload.map(Type::loc),
  )
  let doc = text(self.name) +
    type_parameters +
    parenthesized_comma_list(
      payload_docs,
      item_spans=self.payload.map(Type::loc),
      trivia~,
      dangling=payload_dangling,
      force_break=force_payload_break,
    )
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
    Some(kind) => space + text(":") + space + kind.to_doc(trivia~)
    None => empty
  }
  let body = self.body.to_doc(trivia~)
  let header = public_prefix(self.is_public) +
    keyword("type") +
    space +
    text(self.name) +
    bracketed_type_parameters(
      self.type_parameters,
      trivia~,
      start_offset=self.loc.start_offset,
      end_offset=self.body.loc().start_offset,
    ) +
    result_kind
  let header_end = match self.result_kind {
    Some(kind) => kind.loc().end_offset
    None =>
      if self.type_parameters.is_empty() {
        self.loc.start_offset
      } else {
        self.type_parameters[self.type_parameters.length() - 1].loc.end_offset
      }
  }
  let doc = boundary_separated(
      header,
      text("="),
      header_end,
      self.body.loc().start_offset,
      trivia,
    ) +
    space +
    body
  trivia.decorate(self.loc, doc)
}

///|
pub impl @prettyprinter.Pretty for TypeAliasBody with fn pretty(
  body : TypeAliasBody,
) {
  body.to_doc()
}

///|
fn TypeAliasBody::to_doc(
  self : TypeAliasBody,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  match self {
    TypeBody(type_) => type_.to_doc(trivia~)
    EffectBody(effect) => effect.to_doc(trivia~)
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
  let parameter_docs = self.parameters.map(fn(parameter) {
    parameter.to_doc(trivia~)
  })
  let parameter_start = self.name_loc.end_offset
  let parameter_end = self.return_type.loc().start_offset
  let (parameter_dangling, force_parameter_break) = trivia.take_delimited(
    '(',
    parameter_start,
    parameter_end,
    child_spans=self.parameters.map(fn(parameter) { parameter.loc }),
  )
  let return_doc = self.return_type.to_doc(trivia~) +
    self.effect.to_annotation_doc(trivia~)
  let (arrow_boundary, force_arrow_break) = trivia.take_boundary(
    self.name_loc.end_offset,
    self.return_type.loc().start_offset,
  )
  let suffix = if force_arrow_break {
    hardline + arrow_boundary + hardline + text("->") + space + return_doc
  } else {
    space + text("->") + space + return_doc
  }
  let parameter_suffix = if force_arrow_break { empty } else { suffix }
  let trailing_suffix = if force_arrow_break { suffix } else { empty }
  let doc = public_prefix(self.is_public) +
    keyword("fn") +
    bracketed_type_parameters(
      self.type_parameters,
      trivia~,
      start_offset=self.loc.start_offset,
      end_offset=self.name_loc.start_offset,
    ) +
    space +
    text(self.name) +
    parenthesized_comma_list_with_suffix(
      parameter_docs,
      parameter_suffix,
      item_spans=self.parameters.map(fn(parameter) { parameter.loc }),
      trivia~,
      dangling=parameter_dangling,
      force_break=force_parameter_break,
    ) +
    trailing_suffix +
    space +
    self.body.to_doc(trivia~)
  trivia.decorate(self.loc, doc)
}

///|
fn Parameter::to_doc(
  self : Parameter,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let doc = parameter_modifiers(self.is_auto, self.is_offered) +
    text(self.name) +
    space +
    text(":") +
    space +
    self.type_.to_doc(trivia~)
  trivia.decorate(self.loc, doc)
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
    Some(type_) => space + text(":") + space + type_.to_doc(trivia~)
    None => empty
  }
  let head_end_offset = match self.type_annotation {
    Some(type_) => type_.loc().end_offset
    None =>
      self.name_loc
      .map(fn(loc) { loc.end_offset })
      .unwrap_or(self.loc.start_offset)
  }
  let doc = assignment_expr_doc(
    public_prefix(self.is_public) + keyword("let") + name_doc + type_doc,
    head_end_offset,
    self.initializer,
    trivia~,
  )
  trivia.decorate(self.loc, doc)
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
    self.type_annotation.to_doc(trivia~),
    self.type_annotation.loc().end_offset,
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
fn Type::to_doc(
  self : Type,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let doc = match self {
    Name(name~, ..) => text(name)
    QualifiedName(module_path~, name~, ..) =>
      module_path.to_doc() + text(".") + text(name)
    Apply(callee~, arguments~, loc~) =>
      callee.to_doc(trivia~) +
      bracketed_type_arguments(
        arguments,
        trivia~,
        start_offset=callee.loc().end_offset,
        end_offset=loc.end_offset,
      )
    TypeLambda(parameters~, body~, loc~) =>
      keyword("type") +
      bracketed_type_parameters(
        parameters,
        trivia~,
        start_offset=loc.start_offset,
        end_offset=body.loc().start_offset,
      ) +
      space +
      text("=>") +
      space +
      body.to_doc(trivia~)
    Function(type_parameters~, parameters~, result~, effect~, loc~) => {
      let single_parameter = parameters.length() == 1
      let parameter_docs = parameters.map(fn(parameter) {
        parameter.function_parameter_doc(single_parameter, trivia)
      })
      let type_parameter_end = if parameters.is_empty() {
        result.loc().start_offset
      } else {
        parameters[0].loc().start_offset
      }
      let type_parameters_doc = bracketed_type_parameters(
        type_parameters,
        trivia~,
        start_offset=loc.start_offset,
        end_offset=type_parameter_end,
      )
      let parameter_start = if type_parameters.is_empty() {
        loc.start_offset
      } else {
        type_parameters[type_parameters.length() - 1].loc.end_offset
      }
      let (parameter_dangling, force_parameter_break) = trivia.take_delimited(
        '(',
        parameter_start,
        result.loc().start_offset,
      )
      let result_doc = result.to_doc(trivia~) +
        effect.to_annotation_doc(trivia~)
      let (arrow_boundary, force_arrow_break) = trivia.take_boundary(
        loc.start_offset,
        result.loc().start_offset,
      )
      let suffix = if force_arrow_break {
        hardline + arrow_boundary + hardline + text("->") + space + result_doc
      } else {
        space + text("->") + space + result_doc
      }
      type_parameters_doc +
      parenthesized_comma_list(
        parameter_docs,
        dangling=parameter_dangling,
        force_break=force_parameter_break,
      ) +
      suffix
    }
    Grouped(type_~, loc~) => {
      let (dangling, force_break) = trivia.take_delimited(
        '(',
        loc.start_offset,
        loc.end_offset,
      )
      if force_break {
        parenthesized_comma_list(
          [type_.to_doc(trivia~)],
          dangling~,
          force_break~,
        )
      } else {
        char('(') + type_.to_doc(trivia~) + char(')')
      }
    }
  }
  trivia.decorate(self.loc(), doc)
}

///|
fn EffectTerm::to_doc(
  self : EffectTerm,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let doc = match self {
    Empty(..) => text("{}")
    Term(type_~, ..) => type_.to_doc(trivia~)
    Union(items~, loc~) => {
      let item_docs = items.map(fn(item) { item.to_doc(trivia~) })
      let (dangling, force_break) = trivia.take_delimited(
        '{',
        loc.start_offset,
        loc.end_offset,
        child_spans=items.map(Type::loc),
      )
      braced_comma_list(
        item_docs,
        item_spans=items.map(Type::loc),
        trivia~,
        dangling~,
        force_break~,
      )
    }
  }
  trivia.decorate(self.loc(), doc)
}

///|
fn EffectTerm::to_annotation_doc(
  self : EffectTerm,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  match self {
    Empty(..) => empty
    _ => space + text("!") + space + self.to_doc(trivia~)
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
    QualifiedVariant(
      owner~,
      variant~,
      variant_type_arguments~,
      arguments~,
      loc~
    ) => {
      let argument_docs = arguments.map(fn(argument) {
        argument.to_doc(trivia~)
      })
      let type_argument_end = if arguments.is_empty() {
        loc.end_offset
      } else {
        arguments[0].loc().start_offset
      }
      let type_arguments = bracketed_type_arguments(
        variant_type_arguments,
        trivia~,
        start_offset=owner.loc().end_offset,
        end_offset=type_argument_end,
      )
      let argument_start = if variant_type_arguments.is_empty() {
        owner.loc().end_offset
      } else {
        variant_type_arguments[variant_type_arguments.length() - 1].loc().end_offset
      }
      let (argument_dangling, force_argument_break) = trivia.take_delimited(
        '(',
        argument_start,
        loc.end_offset,
      )
      let head = owner.to_doc() + text("::") + text(variant) + type_arguments
      let doc = head +
        parenthesized_comma_list(
          argument_docs,
          dangling=argument_dangling,
          force_break=force_argument_break,
        )
      (10, doc)
    }
    StructLiteral(owner~, fields~, loc~) => {
      let head = owner.to_doc() + text("::")
      let field_docs = fields.map(fn(field) { field.to_doc(trivia~) })
      let field_spans = fields.map(StructLiteralField::loc)
      let (field_dangling, force_field_break) = trivia.take_delimited(
        '{',
        owner.loc().end_offset,
        loc.end_offset,
        child_spans=field_spans,
      )
      (
        10,
        head +
        struct_literal_fields_doc(
          field_docs,
          field_spans,
          trivia,
          dangling=field_dangling,
          force_break=force_field_break,
        ),
      )
    }
    ListLiteral(items~, loc~) => {
      let item_docs = items.map(fn(item) { item.to_doc(trivia~) })
      let (item_dangling, force_item_break) = trivia.take_delimited(
        '[',
        loc.start_offset,
        loc.end_offset,
        child_spans=items.map(Expr::loc),
      )
      (
        10,
        bracketed_comma_list(
          item_docs,
          item_spans=items.map(Expr::loc),
          trivia~,
          dangling=item_dangling,
          force_break=force_item_break,
        ),
      )
    }
    Builtin(name, loc~) => {
      let (dangling, force_break) = trivia.take_delimited(
        '(',
        loc.start_offset,
        loc.end_offset,
      )
      (
        10,
        keyword("builtin") +
        parenthesized_comma_list([source_string(name)], dangling~, force_break~),
      )
    }
    Extern(name, loc~) => {
      let (dangling, force_break) = trivia.take_delimited(
        '(',
        loc.start_offset,
        loc.end_offset,
      )
      (
        10,
        keyword("extern") +
        parenthesized_comma_list([source_string(name)], dangling~, force_break~),
      )
    }
    FunctionLiteral(
      type_parameters~,
      parameters~,
      return_type~,
      effect~,
      body~,
      loc~
    ) =>
      (
        10,
        function_literal_head_doc(
          type_parameters,
          parameters,
          return_type,
          effect,
          trivia~,
          start_offset=loc.start_offset,
          end_offset=body.loc().start_offset,
        ) +
        space +
        standalone_expr_doc(body, trivia),
      )
    EffectOperationCall(name~, type_witnesses~, arguments~, loc~) => {
      let argument_docs = arguments.map(fn(argument) {
        argument.to_doc(trivia~)
      })
      let type_witness_end = if arguments.is_empty() {
        loc.end_offset
      } else {
        arguments[0].loc().start_offset
      }
      let type_witness_docs = bracketed_type_arguments(
        type_witnesses,
        trivia~,
        start_offset=name.argument_search_start(),
        end_offset=type_witness_end,
      )
      let argument_start = if type_witnesses.is_empty() {
        name.argument_search_start()
      } else {
        type_witnesses[type_witnesses.length() - 1].loc().end_offset
      }
      let (argument_dangling, force_argument_break) = trivia.take_delimited(
        '(',
        argument_start,
        loc.end_offset,
      )
      (
        10,
        name.to_doc(trivia~) +
        text("!") +
        type_witness_docs +
        parenthesized_comma_list(
          argument_docs,
          dangling=argument_dangling,
          force_break=force_argument_break,
        ),
      )
    }
    TypeApplication(callee~, arguments~, loc~) =>
      (
        9,
        callee.to_doc_with_precedence(9, trivia~) +
        bracketed_type_arguments(
          arguments,
          trivia~,
          start_offset=callee.loc().end_offset,
          end_offset=loc.end_offset,
        ),
      )
    Handler(body~, handlers~, final_branch~, ..) => {
      let mut doc = source_prefixed(
        keyword("handle"),
        body.first_line_doc(),
        body.to_doc(trivia~),
      )
      let mut previous_end = body.loc().end_offset
      for handler in handlers {
        doc = boundary_separated(
          doc,
          handler.to_doc(trivia~),
          previous_end,
          handler.loc.start_offset,
          trivia,
        )
        previous_end = handler.loc.end_offset
      }
      doc = boundary_separated(
        doc,
        final_branch.to_doc(trivia~),
        previous_end,
        final_branch.loc.start_offset,
        trivia,
      )
      (10, doc)
    }
    Block(items~, result~, loc~) => {
      let docs = items.map(fn(item) { item.to_doc(trivia~) })
      docs.push(standalone_expr_doc(result, trivia))
      let item_spans = items.map(LocalItem::loc)
      item_spans.push(result.loc())
      let (dangling, force_break) = trivia.take_delimited(
        '{',
        loc.start_offset,
        loc.end_offset,
        child_spans=item_spans,
      )
      (10, brace_block(docs, item_spans~, trivia~, dangling~, force_break~))
    }
    If(condition~, then_branch~, else_branch~, ..) => {
      let then_doc = standalone_expr_doc(then_branch, trivia)
      let else_head = boundary_separated(
        then_doc,
        keyword("else"),
        then_branch.loc().end_offset,
        else_branch.loc().start_offset,
        trivia,
      )
      (
        10,
        breakable_head(keyword("if"), condition.to_doc(trivia~)) +
        space +
        else_head +
        space +
        standalone_expr_doc(else_branch, trivia),
      )
    }
    Match(scrutinee~, arms~, loc~) => {
      let arm_docs = arms.map(fn(arm) { arm.to_doc(trivia~) })
      let (dangling, force_break) = trivia.take_delimited(
        '{',
        loc.start_offset,
        loc.end_offset,
        child_spans=arms.map(fn(arm) { arm.loc }),
      )
      let arm_start = if arms.is_empty() {
        loc.end_offset
      } else {
        arms[0].loc.start_offset
      }
      let body = boundary_separated(
        breakable_head(keyword("match"), scrutinee.to_doc(trivia~)),
        brace_block(
          arm_docs,
          item_spans=arms.map(fn(arm) { arm.loc }),
          trivia~,
          dangling~,
          force_break~,
        ),
        scrutinee.loc().end_offset,
        arm_start,
        trivia,
      )
      (10, body)
    }
    Call(callee~, arguments~, loc~) => {
      let argument_docs = arguments.map(fn(argument) {
        argument.to_doc(trivia~)
      })
      let argument_start = callee.loc().end_offset
      let argument_end = loc.end_offset
      let (argument_dangling, force_argument_break) = trivia.take_delimited(
        '(',
        argument_start,
        argument_end,
        child_spans=arguments.map(CallArgument::loc),
      )
      (
        9,
        callee.to_doc_with_precedence(9, trivia~) +
        parenthesized_comma_list(
          argument_docs,
          item_spans=arguments.map(CallArgument::loc),
          trivia~,
          dangling=argument_dangling,
          force_break=force_argument_break,
        ),
      )
    }
    Field(..) => (9, self.field_chain_doc(trivia~))
    Unary(operator~, operand~, ..) => {
      let (boundary, force_break) = trivia.take_boundary(
        self.loc().start_offset,
        operand.loc().start_offset,
      )
      let operand_doc = operand.to_doc_with_precedence(8, trivia~)
      let body = if force_break {
        operator.to_doc() + space + boundary + nest(hardline + operand_doc)
      } else {
        operator.to_doc() + operand_doc
      }
      (8, body)
    }
    Binary(operator~, left~, right~, ..) => {
      let precedence = operator.precedence()
      let left_doc = left.to_doc_with_precedence(precedence, trivia~)
      let (boundary, force_break) = trivia.take_boundary(
        left.loc().end_offset,
        right.loc().start_offset,
      )
      let right_doc = right.to_doc_with_precedence(precedence + 1, trivia~)
      (
        precedence,
        if force_break {
          left_doc +
          space +
          operator.to_doc() +
          space +
          boundary +
          nest(hardline + right_doc)
        } else {
          group(left_doc + nest(line + operator.to_doc() + space + right_doc))
        },
      )
    }
    Pipeline(..) => (1, self.pipeline_chain_doc(trivia~))
    Grouped(expression~, loc~) => {
      let (dangling, force_break) = trivia.take_delimited(
        '(',
        loc.start_offset,
        loc.end_offset,
      )
      let expression_doc = expression.to_doc_with_precedence(0, trivia~)
      let grouped = if force_break {
        parenthesized_comma_list([expression_doc], dangling~, force_break~)
      } else {
        char('(') + expression_doc + char(')')
      }
      (10, grouped)
    }
  }
  let result = if precedence < context_precedence { parens(doc) } else { doc }
  trivia.decorate(self.loc(), result)
}

///|
fn Expr::pipeline_chain_doc(
  self : Expr,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let (root, segments) = self.pipeline_chain_parts()
  let root_doc = root.to_doc_with_precedence(1, trivia~)
  let displayed_segment_docs = []
  let mut previous_end = root.loc().end_offset
  for segment in segments {
    let (boundary, force_break) = trivia.take_boundary(
      previous_end,
      segment.loc().start_offset,
    )
    let segment_doc = segment.to_doc_with_precedence(2, trivia~)
    displayed_segment_docs.push(
      if force_break {
        boundary + nest(hardline + segment_doc)
      } else {
        segment_doc
      },
    )
    previous_end = segment.loc().end_offset
  }
  guard !displayed_segment_docs.is_empty() else { return root_doc }
  dynamic(fn(context) {
    let separator = if root_doc.fits_current_line(context) {
      hardline
    } else {
      space
    }
    root_doc +
    nest(
      separator +
      text("|>") +
      space +
      pipeline_segment_docs(displayed_segment_docs, 0),
    )
  })
}

///|
fn pipeline_segment_docs(segments : Array[Document], index : Int) -> Document {
  let current = segments[index]
  if index + 1 == segments.length() {
    current
  } else {
    dynamic(fn(context) {
      let separator = if current.fits_current_line(context) {
        hardline
      } else {
        space
      }
      current +
      separator +
      text("|>") +
      space +
      pipeline_segment_docs(segments, index + 1)
    })
  }
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
  if self is Field(base~, name~, loc~) {
    let boundary_start = base.loc().end_offset
    let boundary_end = loc.end_offset
    if (trivia.has_trailing)(base.loc()) {
      let base_doc = base.to_doc_with_precedence(9, trivia~)
      return base_doc + nest(hardline + text(".") + text(name))
    }
    if (trivia.has_boundary)(boundary_start, boundary_end) {
      let boundary = (trivia.boundary)(boundary_start, boundary_end)
      let base_doc = base.to_doc_with_precedence(9, trivia~)
      return base_doc +
        text(".") +
        space +
        boundary +
        nest(hardline + text(name))
    }
  }
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
fn EffectOperationName::to_doc(
  self : EffectOperationName,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  match self {
    Qualified(owner~, operation~, ..) =>
      owner.to_doc(trivia~) + text("::") + text(operation)
    Unqualified(operation~, ..) => text(operation)
  }
}

///|
fn HandlerWithBlock::to_doc(
  self : HandlerWithBlock,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let arm_docs = self.arms.map(fn(arm) { arm.to_doc(trivia~) })
  let (dangling, force_break) = trivia.take_delimited(
    '{',
    self.loc.start_offset,
    self.loc.end_offset,
    child_spans=self.arms.map(fn(arm) { arm.loc }),
  )
  let block = brace_block(
    arm_docs,
    item_spans=self.arms.map(fn(arm) { arm.loc }),
    trivia~,
    dangling~,
    force_break~,
  )
  let header_end = if self.arms.is_empty() {
    self.loc.end_offset
  } else {
    self.arms[0].loc.start_offset
  }
  boundary_separated(
    keyword("with"),
    block,
    self.loc.start_offset,
    header_end,
    trivia,
  )
}

///|
fn HandlerOperationArm::to_doc(
  self : HandlerOperationArm,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let parameters = self.payload_patterns.map(fn(pattern) {
    pattern.to_doc(trivia~)
  })
  parameters.push(text(self.resume_binder))
  let binders = if self.type_binders.is_empty() {
    empty
  } else {
    let (dangling, force_break) = trivia.take_delimited(
      '[',
      self.name.argument_search_start(),
      self.loc.end_offset,
    )
    bracketed_comma_list(self.type_binders.map(text), dangling~, force_break~)
  }
  let (parameter_dangling, force_parameter_break) = trivia.take_delimited(
    '(',
    self.name.argument_search_start(),
    self.body.loc().start_offset,
  )
  let head = self.name.to_doc(trivia~) +
    binders +
    parenthesized_comma_list(
      parameters,
      dangling=parameter_dangling,
      force_break=force_parameter_break,
    ) +
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
  trivia.decorate_trailing(self.loc, doc)
}

///|
fn StructLiteralField::to_doc(
  self : StructLiteralField,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let (span, doc) = match self {
    Value(name~, value~, loc~) =>
      match value {
        Some(value) => {
          let (boundary, force_break) = trivia.take_boundary(
            loc.start_offset,
            value.loc().start_offset,
          )
          if force_break {
            (
              loc,
              text(name) +
              text(":") +
              space +
              boundary +
              hardline +
              value.to_doc(trivia~),
            )
          } else if value is Var(value_name, ..) && value_name == name {
            (loc, text(name))
          } else {
            (loc, text(name) + text(":") + space + value.to_doc(trivia~))
          }
        }
        None => (loc, text(name))
      }
    TypeWitness(name~, witness~, loc~) =>
      (loc, text(name) + space + text("=") + space + witness.to_doc())
  }
  trivia.decorate(span, doc)
}

///|
fn struct_literal_fields_doc(
  field_docs : Array[Document],
  field_spans : Array[SourceSpan],
  trivia : SourceFormatTrivia,
  dangling? : Document = empty,
  force_break? : Bool = false,
) -> Document {
  let separators = []
  for index in 1..<field_docs.length() {
    separators.push(
      (trivia.struct_field_separator)(
        field_spans[index - 1],
        field_spans[index],
      ),
    )
  }
  delimited_list(
    char('{'),
    char('}'),
    line,
    separators,
    field_docs,
    dangling~,
    force_break~,
  )
}

///|
fn StructLiteralField::loc(self : StructLiteralField) -> SourceSpan {
  match self {
    Value(loc~, ..) | TypeWitness(loc~, ..) => loc
  }
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
    Expression(expression~, ..) =>
      trivia.decorate(expression.loc(), expression.to_doc(trivia~))
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
    Some(type_) => space + text(":") + space + type_.to_doc(trivia~)
    None => empty
  }
  let doc = assignment_expr_doc(
    keyword("let") + space + self.pattern.to_doc(trivia~) + type_doc,
    self.type_annotation
    .map(fn(type_) { type_.loc().end_offset })
    .unwrap_or(self.pattern.loc().end_offset),
    self.initializer,
    trivia~,
  )
  trivia.decorate(self.loc, doc)
}

///|
fn function_literal_head_doc(
  type_parameters : Array[TypeParameter],
  parameters : Array[FunctionLiteralParameter],
  return_type : Type?,
  effect : EffectTerm?,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
  start_offset? : Int = -1,
  end_offset? : Int = -1,
) -> Document {
  let parameter_docs = parameters.map(fn(parameter) {
    parameter.to_doc(trivia~)
  })
  let parameter_end = match return_type {
    Some(type_) => type_.loc().start_offset
    None => end_offset
  }
  let type_parameter_end = if parameters.is_empty() {
    parameter_end
  } else {
    parameters[0].loc.start_offset
  }
  let type_parameters_doc = bracketed_type_parameters(
    type_parameters,
    trivia~,
    start_offset~,
    end_offset=type_parameter_end,
  )
  let parameter_start = if type_parameters.is_empty() {
    start_offset
  } else {
    type_parameters[type_parameters.length() - 1].loc.end_offset
  }
  let (parameter_dangling, force_parameter_break) = if start_offset >= 0 &&
    parameter_end >= 0 {
    trivia.take_delimited(
      '(',
      parameter_start,
      parameter_end,
      child_spans=parameters.map(fn(parameter) { parameter.loc }),
    )
  } else {
    (empty, false)
  }
  let return_doc = match return_type {
    Some(type_) => {
      let type_doc = type_.to_doc(trivia~)
      let (arrow_boundary, force_arrow_break) = trivia.take_boundary(
        start_offset,
        type_.loc().start_offset,
      )
      if force_arrow_break {
        hardline + arrow_boundary + hardline + text("->") + space + type_doc
      } else {
        space + text("->") + space + type_doc
      }
    }
    None => empty
  }
  let effect_doc = match effect {
    Some(effect) => effect.to_annotation_doc(trivia~)
    None => empty
  }
  keyword("fn") +
  type_parameters_doc +
  parenthesized_comma_list(
    parameter_docs,
    item_spans=parameters.map(fn(parameter) { parameter.loc }),
    trivia~,
    dangling=parameter_dangling,
    force_break=force_parameter_break,
  ) +
  return_doc +
  effect_doc
}

///|
fn FunctionLiteralParameter::to_doc(
  self : FunctionLiteralParameter,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let prefix = if self.is_offered { keyword("offer") + space } else { empty }
  let doc = match self.type_annotation {
    Some(type_) =>
      prefix +
      text(self.name) +
      space +
      text(":") +
      space +
      type_.to_doc(trivia~)
    None => prefix + text(self.name)
  }
  trivia.decorate(self.loc, doc)
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
  let head = self.pattern.to_doc(trivia~) + space + text("=>")
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
fn Pattern::to_doc(
  self : Pattern,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let doc = match self {
    Wildcard(_) => text("_")
    Binding(name, ..) => text(name)
    IntLiteral(value, ..) => text(value)
    DoubleLiteral(value, ..) => text(value)
    StringLiteral(value, ..) => source_string(value)
    BoolLiteral(value, ..) => text(value.to_string())
    QualifiedVariant(type_name~, variant~, type_binders~, arguments~, loc~) => {
      let binders_doc = if type_binders.is_empty() {
        empty
      } else {
        let (dangling, force_break) = trivia.take_delimited(
          '[',
          loc.start_offset,
          loc.end_offset,
        )
        bracketed_comma_list(type_binders.map(text), dangling~, force_break~)
      }
      let head = text(type_name) + text("::") + text(variant) + binders_doc
      let argument_docs = arguments.map(fn(argument) {
        argument.to_doc(trivia~)
      })
      let (dangling, force_break) = trivia.take_delimited(
        '(',
        loc.start_offset,
        loc.end_offset,
      )
      head + parenthesized_comma_list(argument_docs, dangling~, force_break~)
    }
    UnqualifiedVariant(variant~, type_binders~, arguments~, loc~) => {
      let binders_doc = if type_binders.is_empty() {
        empty
      } else {
        let (dangling, force_break) = trivia.take_delimited(
          '[',
          loc.start_offset,
          loc.end_offset,
        )
        bracketed_comma_list(type_binders.map(text), dangling~, force_break~)
      }
      let head = text(variant) + binders_doc
      let argument_docs = arguments.map(fn(argument) {
        argument.to_doc(trivia~)
      })
      let (dangling, force_break) = trivia.take_delimited(
        '(',
        loc.start_offset,
        loc.end_offset,
      )
      head + parenthesized_comma_list(argument_docs, dangling~, force_break~)
    }
    Struct(type_name~, fields~, loc~) => {
      let field_docs = fields.map(fn(field) { field.to_doc(trivia~) })
      let (dangling, force_break) = trivia.take_delimited(
        '{',
        loc.start_offset,
        loc.end_offset,
      )
      text(type_name) +
      text("::") +
      braced_comma_list(field_docs, dangling~, force_break~)
    }
  }
  trivia.decorate(self.loc(), doc)
}

///|
fn StructPatternField::to_doc(
  self : StructPatternField,
  trivia? : SourceFormatTrivia = SourceFormatTrivia::empty(),
) -> Document {
  let (loc, doc) = match self {
    Value(name~, pattern~, loc~) =>
      match pattern {
        Some(pattern) =>
          (loc, text(name) + text(":") + space + pattern.to_doc(trivia~))
        None => (loc, text(name))
      }
    TypeBinder(name~, loc~) => (loc, text(name))
    TypeWildcard(loc~) => (loc, text("_"))
  }
  trivia.decorate(loc, doc)
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
