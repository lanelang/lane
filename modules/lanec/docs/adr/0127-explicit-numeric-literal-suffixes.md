---
status: accepted
---

# Explicit numeric literal suffixes

Lane gives every numeric literal a type determined solely by its own source
spelling. Lowercase, lexically attached `i32`, `i64`, `f32`, and `f64`
suffixes select one of the four numeric primitive types explicitly;
unsuffixed integer-shaped and floating-shaped literals are always `I64` and
`F64`, respectively. This replaces expected-type-directed literal elaboration
with one rule shared by expressions, patterns, and generic inference, while
preserving explicit conversions for already typed numeric values.

## Source forms

The canonical suffixed forms are:

```lane
42i32
42i64
1f32
100.3f32
100.3f64
1.25e-3f64
```

Suffixes are lowercase and immediately adjacent to the numeral. `I32`,
`42_i32`, `42 i32`, and `1.0F32` are not alternative spellings. The suffix
set is closed; Byte, Char, user-defined types, and compiler-recognized literal
interfaces do not gain suffixes.

An integer-shaped numeral may use a floating suffix, so `1f32` directly
constructs the F32 value one. A fractional or exponent-shaped numeral cannot
use an integer suffix, so `1.5i32` and `1e3i64` are invalid. This change does
not expand the numeral body grammar: `.5f32` and `1.f32` remain invalid, and
numeric separators such as `1_000i32` remain outside the language.

An alphanumeric tail lexically attached to a numeral is treated as an attempted
numeric suffix. Any tail outside the closed suffix set produces an unknown
numeric literal suffix diagnostic rather than being interpreted as a separate
identifier.

## Fixed literal types

Suffixes are hard type commitments. Contextual expectations and generic
inference cannot change them:

```lane
let narrow : I32 = 42i32
let wide : I64 = 42i32 // type mismatch

fn identity[T](value : T) -> T { value }

let first = identity(42) // T = I64
let second = identity(42i32) // T = I32
let third : I32 = identity(42) // type mismatch
```

Unsuffixed literals are equally fixed. An integer-shaped literal is always
I64, and a floating-shaped literal is always F64, even when an adjacent
annotation, parameter, result, field, collection element, scrutinee, or generic
constraint expects I32 or F32. Code must write the applicable suffix:

```lane
let count : I32 = 42i32
let ratio : F32 = 1.5f32
take_i32(42i32)
```

Expression literals and literal patterns follow the same rule. An I32
scrutinee therefore uses an I32 pattern such as `42i32`; an unsuffixed `42`
pattern has type I64 and does not adapt to the scrutinee.

Numeric operators receive already typed operands and introduce no exception.
Consequently, `1i32 + 2` and `1f32 + 2.0` are type errors, while
`1i32 + 2i32` and `1f32 + 2f32` are well typed. The language does not insert
numeric widening, narrowing, rounding, or truncation conversions.

## Negation and ranges

The suffix belongs to the numeral; a leading `-` remains unary negation. An
immediately negated integer literal is checked as one mathematical signed value
so the complete range remains expressible:

```lane
-2147483648i32
-9223372036854775808i64
```

The corresponding positive magnitudes are out of range, and parentheses end
the special form, so both `2147483648i32` and `-(2147483648i32)` are invalid.
Integer range diagnostics are determined by the literal's fixed type.

Floating literal spelling denotes an exact decimal mathematical value. The
checker rounds that value directly once to the selected IEEE binary32 or
binary64 type using round-to-nearest, ties-to-even. F32 literal semantics never
pass through an F64 value, preventing double rounding. A finite nonzero decimal
that rounds to infinity or signed zero is rejected; authored positive and
negative zero remain legal and preserve their sign. NaN and infinity retain
their existing explicit constant forms and are not literal spellings.

## Compiler and tooling contract

Syntax and resolved forms preserve the authored numeral body and optional
suffix. The formatter preserves the numeral body rather than re-rendering its
numeric value and emits the suffix in its canonical lowercase spelling.

Typechecking is the single owner of suffix interpretation, range validation,
and target-width floating rounding. It produces the existing concrete I32,
I64, F32, or F64 checked literal. The suffix does not survive the checked
boundary: Buslane, artifacts, LoisVM, runtime imports, and execution backends
continue to consume only the concrete literal type and value or IEEE bits.
Consequently, this source feature requires no persisted-schema or runtime ABI
change.

An unknown suffix receives a dedicated syntax diagnostic. A fixed literal whose
type conflicts with an expected type receives the ordinary type mismatch. When
an unsuffixed I64 or F64 literal directly conflicts with I32 or F32, diagnostics
also provide a machine-applicable replacement with `i32` or `f32`. The same
suggestion is not offered for a non-literal value; such values continue to need
an explicit conversion.

## Compatibility

This is an intentional source-breaking change with no warning-only transition.
Existing I32 and F32 literals that relied on contextual expectations must add
suffixes. Keeping both elaboration models during a migration window is rejected
because compiler versions would assign different types to the same literal
spelling.

This ADR supersedes only the expected-type-directed numeric literal rules in
ADR 0124 and ADR 0125. Those ADRs continue to own their other
String, Char, primitive naming, numeric operation, representation, persistence,
and host ABI decisions. The type-system and language-surface context documents
must be updated with this fixed-spelling rule at the same time.

## Required verification

- Parser and formatter black-box round trips cover every suffix, integer-shaped
  floating literals, fractional and exponent forms, negative literals, and
  preservation of authored numeral bodies.
- Invalid uppercase, separated, unknown, integer-on-floating, unsupported
  numeral-body, and numeric-separator forms produce stable diagnostics without
  parser aborts.
- Expressions, patterns, annotations, call arguments, results, nominal fields,
  collections, generic calls, and overloaded numeric operators all preserve
  the spelling-selected type without contextual reinterpretation.
- Both signed minima are accepted only through immediate negation; positive and
  parenthesized out-of-range magnitudes are rejected.
- Integer overflow and target-width floating overflow, underflow, signed-zero,
  rounding-boundary, and double-rounding counterexamples have black-box tests.
- Checked literals erase suffix provenance and lower through the existing
  Buslane, artifact, LoisVM interpreter, and Wasm paths without schema or ABI
  changes.
- Migration diagnostics distinguish literal suffix suggestions from explicit
  conversions required for non-literal numeric values.

## Considered options

Expected-type-directed elaboration was rejected because identical literal
spelling acquired different types in different contexts and complicated local
generic reasoning. Inferring I32 from small integer magnitude was rejected
because a value edit could silently change its type. Implicit numeric conversion
was rejected because narrowing and floating demotion have observable semantics.
An extensible `FromLiteral` interface was rejected because the current language
has a closed numeric primitive set and does not need dictionary resolution or a
defaulting subsystem merely to type literals. Providing suffixes only for I32
and F32 was rejected because a symmetric four-suffix vocabulary remains
explicit in generic code and independent of future default choices.
