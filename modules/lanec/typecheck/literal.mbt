///|
fn SemanticChecker::check_int_literal(
  self : SemanticChecker,
  raw : String,
  loc : SourceSpan,
) -> @checked.CheckedIntLiteral {
  // Literal checking is semantic, not syntactic: the parser preserves source
  // spelling, and the checker commits to Lane's current i64 `Int` domain.
  if !is_decimal_int_literal(raw) {
    return self.invalid_int_literal(raw, loc)
  }
  try @string.parse_int64(raw, base=10) catch {
    _ => self.invalid_int_literal(raw, loc)
  } noraise {
    value => { raw, value }
  }
}

///|
fn SemanticChecker::invalid_int_literal(
  self : SemanticChecker,
  raw : String,
  loc : SourceSpan,
) -> @checked.CheckedIntLiteral {
  self.diagnostics.push({ kind: InvalidIntLiteral(raw), loc })
  { raw, value: 0L }
}

///|
fn is_decimal_int_literal(raw : String) -> Bool {
  for view = raw.view(), seen_digit = false {
    match view {
      ['0'..='9', .. rest] => continue rest, true
      [] => break seen_digit
      _ => break false
    }
  }
}

///|
fn @desugar.DesugaredLiteral::type_(
  self : @desugar.DesugaredLiteral,
) -> @types.Type {
  match self {
    Int(_) => Primitive(Int)
    String(_) => Primitive(String)
    Bool(_) => Primitive(Bool)
    Unit => Primitive(Unit)
  }
}

///|
fn SemanticChecker::checked_literal(
  self : SemanticChecker,
  literal : @desugar.DesugaredLiteral,
  loc : SourceSpan,
) -> @checked.CheckedLiteral {
  match literal {
    Int(raw) => Int(self.check_int_literal(raw, loc))
    String(value) => String(value)
    Bool(value) => Bool(value)
    Unit => Unit
  }
}

///|
fn SemanticChecker::check_literal(
  self : SemanticChecker,
  literal : @desugar.DesugaredLiteral,
  expected : @types.Type,
  loc : SourceSpan,
) -> Unit {
  if literal is Int(raw) {
    ignore(self.check_int_literal(raw, loc))
  }
  self.expect_type(expected, literal.type_(), loc)
}
