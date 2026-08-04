///|
test "explicit suffix determines numeric literal types" {
  let outcome = check_source(
    (
      #|module Main
      #|
      #|pub fn integer() -> I32 {
      #|  let value = 42i32
      #|  value
      #|}
      #|
      #|pub fn floating() -> F32 {
      #|  let value = 1.5f32
      #|  value
      #|}
      #|
      #|pub fn wide_integer() -> I64 { 42i64 }
      #|pub fn whole_float() -> F32 { 1f32 }
      #|pub fn wide_float() -> F64 { 1.5f64 }
    ),
  )
  guard outcome is Succeeded(_) else { abort("\{Repr(outcome)}") }
}

///|
test "suffix-selected types survive nominal generic call and pattern contexts" {
  let outcome = check_source(
    (
      #|module Main
      #|
      #|pub struct Numbers {
      #|  narrow : I32
      #|  ratio : F32
      #|}
      #|
      #|fn[T] identity(value : T) -> T { value }
      #|
      #|fn classify_narrow(value : I32) -> Bool {
      #|  match value {
      #|    42i32 => true
      #|    _ => false
      #|  }
      #|}
      #|
      #|fn classify_ratio(value : F32) -> Bool {
      #|  match value {
      #|    1f32 => true
      #|    _ => false
      #|  }
      #|}
      #|
      #|fn classify_negative_ratio(value : F32) -> Bool {
      #|  match value {
      #|    -1.5f32 => true
      #|    _ => false
      #|  }
      #|}
      #|
      #|fn classify_negative_wide(value : F64) -> Bool {
      #|  match value {
      #|    -1.5f64 => true
      #|    _ => false
      #|  }
      #|}
      #|
      #|pub fn answer() -> Numbers {
      #|  let narrow = identity(42i32)
      #|  let ratio = identity(1.5f32)
      #|  let _ = classify_narrow(narrow)
      #|  let _ = classify_ratio(ratio)
      #|  let _ = classify_negative_ratio(-1.5f32)
      #|  let _ = classify_negative_wide(-1.5f64)
      #|  Numbers::{ narrow, ratio }
      #|}
    ),
  )
  guard outcome is Succeeded(_) else { abort("\{Repr(outcome)}") }
}

///|
test "unsuffixed literal does not adapt to an expected narrow type" {
  let outcome = check_source(
    (
      #|module Main
      #|
      #|pub fn answer() -> I32 {
      #|  42
      #|}
    ),
  )
  guard outcome is Failed(failure) else {
    abort("expected the unsuffixed I64 literal to be rejected")
  }
  guard failure.diagnostics() is [diagnostic] else {
    abort("expected one numeric literal mismatch")
  }
  assert_eq(diagnostic.message, "type mismatch")
  guard diagnostic.suggestions
    is [
      {
        message: "write this literal as `42i32`",
        edits: [{ span, replacement: "42i32" }],
        applicability: MachineApplicable,
      },
    ] else {
    abort("expected one machine-applicable i32 suffix replacement")
  }
  assert_eq(Some(span), diagnostic.span)
}

///|
test "unsuffixed floating literal suggests an F32 suffix" {
  let outcome = check_source(
    (
      #|module Main
      #|
      #|pub fn answer() -> F32 {
      #|  1.5
      #|}
    ),
  )
  guard outcome is Failed(failure) else {
    abort("expected the unsuffixed F64 literal to be rejected")
  }
  assert_true(
    failure.diagnostics()
    is [
      {
        suggestions: [
          {
            edits: [{ replacement: "1.5f32", .. }],
            applicability: MachineApplicable,
            ..,
          },
        ],
        ..,
      },
    ],
  )
}

///|
test "generic result mismatch does not pretend a conversion is a suffix edit" {
  let outcome = check_source(
    (
      #|module Main
      #|
      #|fn[T] identity(value : T) -> T { value }
      #|
      #|pub fn answer() -> I32 {
      #|  identity(42)
      #|}
    ),
  )
  guard outcome is Failed(failure) else {
    abort("expected the inferred I64 result to be rejected")
  }
  guard failure.diagnostics() is [diagnostic] else {
    abort("expected one generic result mismatch")
  }
  assert_eq(diagnostic.message, "type mismatch")
  assert_eq(diagnostic.suggestions, [])
}

///|
test "unsuffixed numeric pattern does not adapt to its scrutinee" {
  let outcome = check_source(
    (
      #|module Main
      #|
      #|pub fn answer(value : I32) -> Bool {
      #|  match value {
      #|    42 => true
      #|    _ => false
      #|  }
      #|}
    ),
  )
  guard outcome is Failed(failure) else {
    abort("expected the unsuffixed I64 pattern to be rejected")
  }
  guard failure.diagnostics() is [diagnostic] else {
    abort("expected one numeric pattern mismatch")
  }
  assert_true(
    diagnostic.suggestions
    is [
      {
        edits: [{ replacement: "42i32", .. }],
        applicability: MachineApplicable,
        ..,
      },
    ],
  )
}

///|
test "immediate negation admits both signed integer minima" {
  let outcome = check_source(
    (
      #|module Main
      #|
      #|pub fn minimum_i32() -> I32 { -2147483648i32 }
      #|pub fn minimum_i64() -> I64 { -9223372036854775808i64 }
    ),
  )
  assert_true(outcome is Succeeded(_))
}

///|
test "positive and parenthesized signed-minimum magnitudes are invalid" {
  for
    case in [
      ("2147483648i32", "I32", "%i32_neg"),
      ("-(2147483648i32)", "I32", "%i32_neg"),
      ("9223372036854775808i64", "I64", "%i64_neg"),
      ("-(9223372036854775808i64)", "I64", "%i64_neg"),
    ] {
    let (expression, return_type, neg_intrinsic) = case
    let outcome = check_source(
      "module Main\nlet op_neg : (" +
      return_type +
      ") -> " +
      return_type +
      " = builtin(\"" +
      neg_intrinsic +
      "\")\npub fn answer() -> " +
      return_type +
      " { " +
      expression +
      " }",
    )
    guard outcome is Failed(failure) else {
      abort("expected out-of-range literal to fail: " + expression)
    }
    if !failure
      .diagnostics()
      .any(fn(diagnostic) {
        diagnostic.code == Some("E3034") || diagnostic.code == Some("E3009")
      }) {
      abort(
        "expected a range diagnostic for \{expression}: \{Repr(failure.diagnostics())}",
      )
    }
  }
}

///|
test "F32 suffix rejects overflow and nonzero underflow" {
  for spelling in ["3.5e38f32", "7e-46f32"] {
    let outcome = check_source(
      "module Main\npub fn answer() -> F32 { " + spelling + " }",
    )
    guard outcome is Failed(failure) else {
      abort("expected invalid F32 literal to fail: " + spelling)
    }
    assert_true(
      failure
      .diagnostics()
      .any(fn(diagnostic) { diagnostic.code == Some("E3035") }),
    )
  }
}
