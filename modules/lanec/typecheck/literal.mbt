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
fn SemanticChecker::check_double_literal(
  self : SemanticChecker,
  raw : String,
  loc : SourceSpan,
) -> @checked.CheckedDoubleLiteral {
  let value = try @string.parse_double(raw) catch {
    _ => return self.invalid_double_literal(raw, loc)
  } noraise {
    value => value
  }
  if value.is_nan() || value.is_inf() {
    return self.invalid_double_literal(raw, loc)
  }
  if value == 0.0 && double_significand_has_nonzero_digit(raw) {
    return self.invalid_double_literal(raw, loc)
  }
  { raw, value }
}

///|
fn SemanticChecker::invalid_double_literal(
  self : SemanticChecker,
  raw : String,
  loc : SourceSpan,
) -> @checked.CheckedDoubleLiteral {
  self.diagnostics.push({ kind: InvalidDoubleLiteral(raw), loc })
  { raw, value: 0.0 }
}

///|
fn double_significand_has_nonzero_digit(raw : String) -> Bool {
  for view = raw.view() {
    match view {
      ['e' | 'E', ..] => break false
      ['1'..='9', ..] => break true
      [_, .. rest] => continue rest
      [] => break false
    }
  }
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
    Double(_) => Primitive(Double)
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
    Double(raw) => Double(self.check_double_literal(raw, loc))
    String(value) => String(value)
    Bool(value) => Bool(value)
    Unit => Unit
  }
}
