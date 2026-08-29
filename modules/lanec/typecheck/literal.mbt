///|
fn SemanticChecker::check_i64_literal(
  self : SemanticChecker,
  raw : String,
  loc : SourceSpan,
) -> @checked.CheckedI64Literal {
  // Literal checking is semantic, not syntactic: the parser preserves source
  // spelling, and the checker commits to Lane's signed `I64` domain.
  if !is_decimal_integer_literal(raw) {
    return self.invalid_i64_literal(raw, loc)
  }
  try @string.parse_int64(raw, base=10) catch {
    _ => self.invalid_i64_literal(raw, loc)
  } noraise {
    value => { raw, value, }
  }
}

///|
fn SemanticChecker::invalid_i64_literal(
  self : SemanticChecker,
  raw : String,
  loc : SourceSpan,
) -> @checked.CheckedI64Literal {
  self.diagnostics.push({ kind: InvalidI64Literal(raw), loc, })
  { raw, value: 0L, }
}

///|
fn SemanticChecker::check_i32_literal(
  self : SemanticChecker,
  raw : String,
  loc : SourceSpan,
) -> @checked.CheckedI32Literal {
  if !is_decimal_integer_literal(raw) {
    return self.invalid_i32_literal(raw, loc)
  }
  try @string.parse_int64(raw, base=10) catch {
    _ => self.invalid_i32_literal(raw, loc)
  } noraise {
    value =>
      if value < -2147483648L || value > 2147483647L {
        self.invalid_i32_literal(raw, loc)
      } else {
        { raw, value: value.to_int(), }
      }
  }
}

///|
fn SemanticChecker::invalid_i32_literal(
  self : SemanticChecker,
  raw : String,
  loc : SourceSpan,
) -> @checked.CheckedI32Literal {
  self.diagnostics.push({ kind: InvalidI32Literal(raw), loc, })
  { raw, value: 0, }
}

///|
fn SemanticChecker::check_f64_literal(
  self : SemanticChecker,
  raw : String,
  loc : SourceSpan,
) -> @checked.CheckedF64Literal {
  let value = try @string.parse_double(raw) catch {
    _ => return self.invalid_f64_literal(raw, loc)
  } noraise {
    value => value
  }
  if value.is_nan() || value.is_inf() {
    return self.invalid_f64_literal(raw, loc)
  }
  if value == 0.0 && floating_significand_has_nonzero_digit(raw) {
    return self.invalid_f64_literal(raw, loc)
  }
  { raw, value, }
}

///|
fn SemanticChecker::invalid_f64_literal(
  self : SemanticChecker,
  raw : String,
  loc : SourceSpan,
) -> @checked.CheckedF64Literal {
  self.diagnostics.push({ kind: InvalidF64Literal(raw), loc, })
  { raw, value: 0.0, }
}

///|
fn SemanticChecker::check_f32_literal(
  self : SemanticChecker,
  raw : String,
  loc : SourceSpan,
) -> @checked.CheckedF32Literal {
  guard parse_f32_decimal(raw) is Some(value) else {
    return self.invalid_f32_literal(raw, loc)
  }
  { raw, value, }
}

///|
fn SemanticChecker::invalid_f32_literal(
  self : SemanticChecker,
  raw : String,
  loc : SourceSpan,
) -> @checked.CheckedF32Literal {
  self.diagnostics.push({ kind: InvalidF32Literal(raw), loc, })
  { raw, value: Float::from_double(0.0), }
}

///|
fn floating_significand_has_nonzero_digit(raw : String) -> Bool {
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
fn is_decimal_integer_literal(raw : String) -> Bool {
  let digits = match raw.view() {
    ['-', .. rest] => rest
    view => view
  }
  for view = digits, seen_digit = false {
    match view {
      ['0'..='9', .. rest] => continue rest, true
      [] => break seen_digit
      _ => break false
    }
  }
}

///|
fn SemanticChecker::check_literal(
  self : SemanticChecker,
  literal : @desugar.DesugaredLiteral,
  loc : SourceSpan,
) -> (@checked.CheckedLiteral, @types.Type) {
  match literal {
    Integer(raw, suffix~) => self.check_integer_literal(raw, suffix, loc)
    Floating(raw, suffix~) => self.check_floating_literal(raw, suffix, loc)
    String(value) => (String(value), Primitive(String))
    Char(value) => (Char(value), Primitive(Char))
    Bool(value) => (Bool(value), Primitive(Bool))
    Unit => (Unit, Primitive(Unit))
  }
}

///|
fn SemanticChecker::check_integer_literal(
  self : SemanticChecker,
  raw : String,
  suffix : @syntax.NumericLiteralSuffix?,
  loc : SourceSpan,
) -> (@checked.CheckedLiteral, @types.Type) {
  match suffix {
    None | Some(I64Suffix) =>
      (I64(self.check_i64_literal(raw, loc)), Primitive(I64))
    Some(I32Suffix) => (I32(self.check_i32_literal(raw, loc)), Primitive(I32))
    Some(F64Suffix) => (F64(self.check_f64_literal(raw, loc)), Primitive(F64))
    Some(F32Suffix) => (F32(self.check_f32_literal(raw, loc)), Primitive(F32))
  }
}

///|
fn SemanticChecker::check_floating_literal(
  self : SemanticChecker,
  raw : String,
  suffix : @syntax.NumericLiteralSuffix?,
  loc : SourceSpan,
) -> (@checked.CheckedLiteral, @types.Type) {
  match suffix {
    None | Some(F64Suffix) =>
      (F64(self.check_f64_literal(raw, loc)), Primitive(F64))
    Some(F32Suffix) => (F32(self.check_f32_literal(raw, loc)), Primitive(F32))
    Some(I64Suffix) => (I64(self.check_i64_literal(raw, loc)), Primitive(I64))
    Some(I32Suffix) => (I32(self.check_i32_literal(raw, loc)), Primitive(I32))
  }
}

///|
fn @desugar.DesugaredLiteral::numeric_literal_suffix_replacement(
  self : @desugar.DesugaredLiteral,
  expected : @types.Type,
) -> String? {
  match self {
    Integer(raw, suffix~) =>
      numeric_literal_suffix_replacement(raw, suffix, expected, false)
    Floating(raw, suffix~) =>
      numeric_literal_suffix_replacement(raw, suffix, expected, true)
    _ => None
  }
}

///|
fn numeric_literal_suffix_replacement(
  raw : String,
  suffix : @syntax.NumericLiteralSuffix?,
  expected : @types.Type,
  floating : Bool,
) -> String? {
  guard suffix is None else { return None }
  if floating {
    if expected == Primitive(F32) {
      Some(raw + "f32")
    } else {
      None
    }
  } else if expected == Primitive(I32) {
    Some(raw + "i32")
  } else {
    None
  }
}
