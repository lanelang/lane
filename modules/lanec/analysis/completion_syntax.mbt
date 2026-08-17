///|
priv enum CompletionSpace {
  AnySpace
  ValueSpace
  PatternSpace
  TypeSpace
  EffectSpace
}

///|
priv enum CompletionContext {
  Identifier(
    prefix~ : String,
    replace~ : @basic.SourceSpan,
    space~ : CompletionSpace
  )
  ImportPath(prefix~ : String, replace~ : @basic.SourceSpan)
  ModuleQualified(
    owner~ : String,
    prefix~ : String,
    replace~ : @basic.SourceSpan
  )
  OwnerQualified(
    owner~ : @resolve.ResolvedNominalName,
    prefix~ : String,
    replace~ : @basic.SourceSpan
  )
  ReceiverSelector(
    receiver~ : String,
    prefix~ : String,
    replace~ : @basic.SourceSpan
  )
  Unsupported
}

///|
priv struct CompletionSource {
  text : String
  tokens : Array[(@lexer.Token, @basic.SourceSpan)]
  line_starts : Array[Int]
  syntax_identifiers : @syntax.SyntacticIdentifierIndex
}

///|
fn CompletionSource::from_input(
  input : @module_frontend.ParsedModuleInput,
) -> CompletionSource {
  CompletionSource::from_syntax(
    input.text,
    input.concrete,
    input.source.syntactic_identifier_index(),
  )
}

///|
fn CompletionSource::from_parsed_source(
  input : @module_frontend.ParsedSource,
) -> CompletionSource {
  CompletionSource::from_syntax(
    input.text(),
    input.concrete(),
    input.identifiers(),
  )
}

///|
fn CompletionSource::from_syntax(
  text : String,
  concrete : @lexer.ConcreteSyntax,
  syntax_identifiers : @syntax.SyntacticIdentifierIndex,
) -> CompletionSource {
  let line_starts = [0]
  for trivia in concrete.trivia {
    if trivia.kind is Newline {
      line_starts.push(trivia.span.end_offset)
    }
  }
  { text, tokens: concrete.tokens, line_starts, syntax_identifiers }
}

///|
fn completion_context(
  source : CompletionSource,
  line : Int,
  column : Int,
  trigger : CompletionTrigger,
  module_bindings : Map[Int, SemanticModuleBindingFact],
) -> CompletionContext {
  let offset = source.offset(line, column)
  let prefix_start = identifier_prefix_start(source.text, offset)
  let prefix = source.text.unsafe_substring(start=prefix_start, end=offset)
  let replace = source.span(prefix_start, offset)
  let token_count = source.token_count_before(prefix_start)
  if source.line_starts_with_import(line, token_count) {
    return ImportPath(prefix~, replace~)
  }
  if source.tokens.get(token_count - 1)
    is Some((TIGHT_COLONCOLON | COLONCOLON, _)) {
    let owner = completion_owner_components(source.tokens, token_count)
    if !owner.is_empty() {
      match resolved_completion_owner(owner, module_bindings) {
        Some(owner) => return OwnerQualified(owner~, prefix~, replace~)
        None => return Unsupported
      }
    }
  }
  if source.tokens.get(token_count - 1) is Some((DOT, _)) {
    let owner = completion_owner_components(source.tokens, token_count).join(
      ".",
    )
    if owner != "" {
      if module_owner_visible(owner, module_bindings) {
        return ModuleQualified(owner~, prefix~, replace~)
      }
      return ReceiverSelector(receiver=owner, prefix~, replace~)
    }
  }
  match trigger {
    TriggerCharacter(".") | TriggerCharacter(":") if prefix == "" => Unsupported
    _ => {
      let space = match source.syntax_identifiers.role_at(offset) {
        Some(role) => completion_space_from_syntax_role(role)
        None if prefix == "" => AnySpace
        None => return Unsupported
      }
      Identifier(prefix~, replace~, space~)
    }
  }
}

///|
fn completion_space_from_syntax_role(
  role : @syntax.SyntacticIdentifierRole,
) -> CompletionSpace {
  match role {
    TypeIdentifier => TypeSpace
    EffectIdentifier => EffectSpace
    ValueIdentifier => ValueSpace
    PatternIdentifier => PatternSpace
  }
}

///|
fn CompletionSource::offset(
  self : CompletionSource,
  line : Int,
  column : Int,
) -> Int {
  let line_index = if line > 0 { line - 1 } else { 0 }
  let line_start = self.line_starts
    .get(line_index)
    .unwrap_or(self.text.length())
  let column_offset = if column > 1 { column - 1 } else { 0 }
  minimum_int(line_start + column_offset, self.text.length())
}

///|
fn CompletionSource::span(
  self : CompletionSource,
  start_offset : Int,
  end_offset : Int,
) -> @basic.SourceSpan {
  let start = self.position(start_offset)
  let end = self.position(end_offset)
  {
    start_offset,
    end_offset,
    start_line: start.0,
    start_column: start.1,
    end_line: end.0,
    end_column: end.1,
  }
}

///|
fn CompletionSource::position(
  self : CompletionSource,
  offset : Int,
) -> (Int, Int) {
  let safe_offset = if offset < 0 {
    0
  } else {
    minimum_int(offset, self.text.length())
  }
  let mut low = 0
  let mut high = self.line_starts.length()
  while low < high {
    let middle = low + (high - low) / 2
    if self.line_starts[middle] <= safe_offset {
      low = middle + 1
    } else {
      high = middle
    }
  }
  let line_index = if low > 0 { low - 1 } else { 0 }
  (line_index + 1, safe_offset - self.line_starts[line_index] + 1)
}

///|
fn CompletionSource::token_count_before(
  self : CompletionSource,
  offset : Int,
) -> Int {
  let mut low = 0
  let mut high = self.tokens.length()
  while low < high {
    let middle = low + (high - low) / 2
    if self.tokens[middle].1.end_offset <= offset {
      low = middle + 1
    } else {
      high = middle
    }
  }
  low
}

///|
fn CompletionSource::line_starts_with_import(
  self : CompletionSource,
  line : Int,
  token_count : Int,
) -> Bool {
  guard self.line_starts.get(line - 1) is Some(line_start) else { return false }
  let mut low = 0
  let mut high = token_count
  while low < high {
    let middle = low + (high - low) / 2
    if self.tokens[middle].1.start_offset < line_start {
      low = middle + 1
    } else {
      high = middle
    }
  }
  low < token_count && self.tokens[low].0 is IMPORT
}

///|
fn completion_owner_components(
  tokens : Array[(@lexer.Token, @basic.SourceSpan)],
  token_count : Int,
) -> Array[String] {
  let mut index = token_count - 2
  let owner = []
  let mut expect_identifier = true
  while index >= 0 {
    let token = tokens[index].0
    if expect_identifier {
      guard token is IDENT(name) else { break }
      owner.insert(0, name)
      expect_identifier = false
    } else {
      guard token is DOT else { break }
      expect_identifier = true
    }
    index -= 1
  }
  owner
}

///|
fn resolved_completion_owner(
  components : Array[String],
  bindings : Map[Int, SemanticModuleBindingFact],
) -> @resolve.ResolvedNominalName? {
  guard components.length() > 1 else { return Some(Unqualified(components[0])) }
  let module_components = []
  for index in 0..<(components.length() - 1) {
    module_components.push(components[index])
  }
  let module_binding = module_components.join(".")
  for _, binding in bindings {
    if binding.name == module_binding {
      return Some(
        Qualified({ module_binding, name: components[components.length() - 1] }),
      )
    }
  }
  None
}

///|
fn module_owner_visible(
  owner : String,
  bindings : Map[Int, SemanticModuleBindingFact],
) -> Bool {
  for _, binding in bindings {
    if binding.name == owner {
      return true
    }
  }
  false
}

///|
fn identifier_prefix_start(source_text : String, offset : Int) -> Int {
  let mut index = minimum_int(offset, source_text.length())
  while index > 0 &&
        is_identifier_part(
          source_text.unsafe_substring(start=index - 1, end=index),
        ) {
    index = index - 1
  }
  index
}

///|
fn is_identifier_part(text : String) -> Bool {
  text.length() == 1 &&
  "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_".contains(
    text,
  )
}

///|
fn minimum_int(left : Int, right : Int) -> Int {
  if left < right {
    left
  } else {
    right
  }
}
