///|
test "typecheck checked source preserves existential struct pattern let" {
  let result = expect_checked_source_result(
    (
      #|struct Hide {
      #|  type T : Type
      #|  val : T
      #|}
      #|fn repack(h : Hide) -> Hide {
      #|  {
      #|    let Hide::{ T, val } = h
      #|    Hide::{ T = T, val: val }
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|checked_source_typecheck_result {
      #|  checked {
      #|    struct Hide#0 {
      #|      type T#0 : Type
      #|      val#0 : tparam#0
      #|    }
      #|    fn repack#0(h#1 : type#0) -> type#0 {
      #|      {
      #|        let type#0::{
      #|          type T#0 = T#1
      #|          val#0: val#2
      #|        } = h#1
      #|        type#0::{
      #|          type T#0 = tparam#1
      #|          val#0: val#2
      #|        }
      #|      }
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck checked source preserves existential enum match pattern" {
  let result = expect_checked_source_result(
    (
      #|enum Packed {
      #|  hide[T](T)
      #|}
      #|fn repack(p : Packed) -> Packed {
      #|  match p {
      #|    Packed::hide[T](value) => Packed::hide[T](value)
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|checked_source_typecheck_result {
      #|  checked {
      #|    enum Packed#0 {
      #|      hide#0[T#0 : Type](tparam#0)
      #|    }
      #|    fn repack#0(p#1 : type#0) -> type#0 {
      #|      match p#1 {
      #|        variant#0[tparam#1](value#2) => variant#0[tparam#1](value#2)
      #|      }
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck accepts single-variant enum pattern let" {
  let result = expect_typecheck_result(
    (
      #|enum Id[A] {
      #|  id(A)
      #|}
      #|fn unwrap(value : Id[I64]) -> I64 {
      #|  {
      #|    let id(x) = value
      #|    x
      #|  }
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
}

///|
test "typecheck uses pattern let annotation as initializer expected type" {
  let result = expect_typecheck_result(
    (
      #|fn use() -> I64 {
      #|  {
      #|    let _ : F64 = builtin("%f64_inf")
      #|    42
      #|  }
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
}

///|
test "typecheck checked source preserves existential enum pattern let" {
  let result = expect_checked_source_result(
    (
      #|enum Packed {
      #|  hide[T](T)
      #|}
      #|fn repack(p : Packed) -> Packed {
      #|  {
      #|    let hide[T](value) = p
      #|    Packed::hide[T](value)
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|checked_source_typecheck_result {
      #|  checked {
      #|    enum Packed#0 {
      #|      hide#0[T#0 : Type](tparam#0)
      #|    }
      #|    fn repack#0(p#1 : type#0) -> type#0 {
      #|      {
      #|        let variant#0[tparam#1](value#2) = p#1
      #|        variant#0[tparam#1](value#2)
      #|      }
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck rejects multi-variant enum pattern let" {
  let result = expect_typecheck_result(
    (
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|fn bad(value : Option[I64]) -> I64 {
      #|  {
      #|    let some(x) = value
      #|    x
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[refutable_pattern_let type#0[I64] @ 8:9-8:16]
    ),
  )
}

///|
test "typecheck rejects literal pattern let as refutable" {
  let result = expect_typecheck_result(
    (
      #|fn bad(value : I64) -> I64 {
      #|  {
      #|    let 1 = value
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[refutable_pattern_let I64 @ 4:9-4:10]
    ),
  )
}

///|
test "typecheck rejects nested refutable pattern let" {
  let result = expect_typecheck_result(
    (
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|struct Box {
      #|  value : Option[I64]
      #|}
      #|fn bad(box : Box) -> I64 {
      #|  {
      #|    let Box::{ value: some(x) } = box
      #|    x
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[refutable_pattern_let type#0[I64] @ 11:23-11:30]
    ),
  )
}

///|
test "typecheck unqualified enum variant construction" {
  let result = expect_typecheck_result(
    (
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|fn wrap(value : I64) -> Option[I64] {
      #|  some(value)
      #|}
      #|fn empty() -> Option[I64] {
      #|  none()
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {
      #|      enum Option#0[A#0 : Type] {
      #|        none#0
      #|        some#1(tparam#0)
      #|      }
      #|    }
      #|    type_members {}
      #|    fields {}
      #|    variants {
      #|      none#0
      #|      some#1(tparam#0)
      #|    }
      #|  }
      #|  checked_values {
      #|    fn wrap#0 : (I64) -> type#0[I64]
      #|    fn empty#1 : () -> type#0[I64]
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck reports unresolved variant generic arguments" {
  let result = expect_typecheck_result(
    (
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|fn use() -> Bool {
      #|  {
      #|    let value = Option::none()
      #|    true
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[generic_argument_inference_failed generic arguments missing A @ 8:17-8:31]
    ),
  )
}

///|
test "typecheck reports enum variant payload mismatch" {
  let result = expect_typecheck_result(
    (
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|fn bad() -> Option[I64] {
      #|  Option[I64]::some(true)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[type_mismatch expected=I64 actual=Bool @ 7:21-7:25]
    ),
  )
}

///|
test "typecheck reports enum variant arity mismatch" {
  let result = expect_typecheck_result(
    (
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|fn bad() -> Option[I64] {
      #|  some()
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[
      #|  application_arity_mismatch variant arity @ 7:3-7:9,
      #|  type_mismatch expected=type#0[I64] actual=type#0 @ 7:3-7:9
      #|]
    ),
  )
}

///|
test "typecheck reports ambiguous unqualified enum variant" {
  let file = expect_parse_ok(
    (
      #|enum Left {
      #|  same(I64)
      #|}
      #|enum Right {
      #|  same(I64)
      #|}
      #|fn bad() -> Left {
      #|  same(1)
      #|}
    ),
  )
  let resolution = @resolve.resolve_source_file_result(file)
  debug_inspect(
    resolution.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: AmbiguousUnqualifiedVariant(
      #|      name="same",
      #|      candidates=[
      #|        { owner: "Left", variant: "same" },
      #|        { owner: "Right", variant: "same" },
      #|      ],
      #|    ),
      #|    loc: {
      #|      start_offset: 86,
      #|      end_offset: 90,
      #|      start_line: 9,
      #|      start_column: 3,
      #|      end_line: 9,
      #|      end_column: 7,
      #|    },
      #|  },
      #|]
    ),
  )
  guard typecheck_source_file(resolution.source)
    is Err(InvalidInputMetadata([InvalidVariantReference(..)])) else {
    fail("expected ambiguous variant to be rejected as invalid input metadata")
  }
}

///|
test "typecheck exhaustive enum match" {
  let result = expect_typecheck_result(
    (
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|fn unwrap(value : Option[I64], fallback : I64) -> I64 {
      #|  match value {
      #|    Option::none() => fallback
      #|    Option::some(x) => x
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {
      #|      enum Option#0[A#0 : Type] {
      #|        none#0
      #|        some#1(tparam#0)
      #|      }
      #|    }
      #|    type_members {}
      #|    fields {}
      #|    variants {
      #|      none#0
      #|      some#1(tparam#0)
      #|    }
      #|  }
      #|  checked_values {
      #|    fn unwrap#0 : (type#0[I64], I64) -> I64
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "pattern completeness does not treat type errors as uninhabited" {
  let declarations : CheckedDeclarationEnvironment = {
    types: [],
    type_members: [],
    fields: [],
    variants: [],
    effects: [],
    operations: [],
  }
  assert_true(complete_constructor_signatures(declarations, Error) is None)
}

///|
test "typecheck unqualified enum variant patterns from expected type" {
  let result = expect_typecheck_result(
    (
      #|enum Left {
      #|  same(I64)
      #|}
      #|enum Right {
      #|  same(Bool)
      #|}
      #|fn left(value : Left) -> I64 {
      #|  match value {
      #|    same(x) => x
      #|  }
      #|}
      #|fn right(value : Right) -> I64 {
      #|  match value {
      #|    same(_) => 1
      #|  }
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "typecheck unqualified enum variant patterns in adjacent match arms" {
  let result = expect_typecheck_result(
    (
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|fn unwrap(value : Option[I64], fallback : I64) -> I64 {
      #|  match value {
      #|    none() => fallback
      #|    some(x) => x
      #|  }
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "typecheck rejects unqualified enum variant without enum expected type" {
  let result = expect_typecheck_result(
    (
      #|fn bad(value : I64) -> I64 {
      #|  match value {
      #|    some(x) => x
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[
      #|  unqualified_variant_pattern_needs_expected_enum some @ 4:5-4:12,
      #|  internal_typecheck_failure resolved value `x` is absent from the type scope @ 4:16-4:17,
      #|  internal_typecheck_failure checked match arm @ 4:16-4:17
      #|]
    ),
  )
}

///|
test "typecheck reports non-exhaustive bool match" {
  let result = expect_typecheck_result(
    (
      #|fn bad(value : Bool) -> I64 {
      #|  match value {
      #|    true => 1
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[non_exhaustive_match Bool missing=`false` @ 3:3-5:4]
    ),
  )
}

///|
test "typecheck accepts exhaustive nested enum patterns" {
  let result = expect_typecheck_result(
    (
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|fn use(value : Option[Option[I64]]) -> I64 {
      #|  match value {
      #|    Option::none() => 0
      #|    Option::some(Option::none()) => 1
      #|    Option::some(Option::some(x)) => x
      #|  }
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "typecheck reports non-exhaustive nested enum patterns" {
  let result = expect_typecheck_result(
    (
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|fn bad(value : Option[Option[I64]]) -> I64 {
      #|  match value {
      #|    Option::none() => 0
      #|    Option::some(Option::none()) => 1
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[non_exhaustive_match type#0[type#0[I64]] missing=`some(some(_))` @ 7:3-10:4]
    ),
  )
}

///|
test "typecheck abbreviates missing witnesses at the expansion budget" {
  let result = expect_typecheck_result(
    (
      #|enum Chain {
      #|  done()
      #|  more(Chain)
      #|}
      #|fn bad(value : Chain) -> I64 {
      #|  match value {
      #|    Chain::done() => 0
      #|    Chain::more(Chain::done()) => 1
      #|    Chain::more(Chain::more(Chain::done())) => 2
      #|    Chain::more(Chain::more(Chain::more(Chain::done()))) => 3
      #|    Chain::more(Chain::more(Chain::more(Chain::more(Chain::done())))) => 4
      #|    Chain::more(Chain::more(Chain::more(Chain::more(Chain::more(Chain::done()))))) => 5
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[non_exhaustive_match type#0 missing=`more(more(more(more(more(more(_))))))` @ 7:3-14:4]
    ),
  )
}

///|
test "typecheck coverage decisions do not depend on witness expansion" {
  let result = expect_typecheck_result(
    (
      #|enum Chain {
      #|  done()
      #|  more(Chain)
      #|}
      #|fn bad(value : Chain) -> I64 {
      #|  match value {
      #|    Chain::done() => 0
      #|    Chain::more(Chain::done()) => 1
      #|    Chain::more(Chain::more(Chain::done())) => 2
      #|    Chain::more(Chain::more(Chain::more(Chain::done()))) => 3
      #|    Chain::more(Chain::more(Chain::more(Chain::more(Chain::done())))) => 4
      #|    Chain::more(Chain::more(Chain::more(Chain::more(Chain::more(Chain::done()))))) => 5
      #|    Chain::more(Chain::more(Chain::more(Chain::more(Chain::more(Chain::more(_)))))) => 6
      #|    Chain::more(Chain::more(Chain::more(Chain::more(Chain::more(Chain::more(Chain::done())))))) => 7
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[unreachable_match_arm @ 15:5-15:101]
    ),
  )
}

///|
test "typecheck reports unreachable nested enum pattern" {
  let result = expect_typecheck_result(
    (
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|fn bad(value : Option[Option[I64]]) -> I64 {
      #|  match value {
      #|    Option::some(Option::none()) => 1
      #|    Option::some(Option::none()) => 2
      #|    Option::some(Option::some(x)) => x
      #|    Option::none() => 0
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[unreachable_match_arm @ 9:5-9:38]
    ),
  )
}

///|
test "typecheck accepts exhaustive nested struct field patterns" {
  let result = expect_typecheck_result(
    (
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|struct Box[A] {
      #|  value : A
      #|}
      #|fn use(value : Box[Option[I64]]) -> I64 {
      #|  match value {
      #|    Box::{ value: Option::none() } => 0
      #|    Box::{ value: Option::some(x) } => x
      #|  }
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "typecheck reports unreachable match arm" {
  let result = expect_typecheck_result(
    (
      #|fn bad(value : Bool) -> I64 {
      #|  match value {
      #|    _ => 1
      #|    true => 2
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[unreachable_match_arm @ 5:5-5:14]
    ),
  )
}

///|
test "typecheck compares int patterns by checked value" {
  let result = expect_typecheck_result(
    (
      #|fn bad(value : I64) -> I64 {
      #|  match value {
      #|    1 => 1
      #|    01 => 2
      #|    _ => 0
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[unreachable_match_arm @ 5:5-5:12]
    ),
  )
}

///|
test "typecheck reports duplicate pattern binder" {
  let result = expect_typecheck_result(
    (
      #|enum Pair {
      #|  pair(I64, I64)
      #|}
      #|fn bad(value : Pair) -> I64 {
      #|  match value {
      #|    Pair::pair(x, x) => x
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[duplicate_pattern_binder x @ 7:19-7:20]
    ),
  )
}

///|
test "typecheck reports missing struct pattern field" {
  let result = expect_typecheck_result(
    (
      #|struct Point {
      #|  x : I64
      #|  y : I64
      #|}
      #|fn bad(point : Point) -> I64 {
      #|  match point {
      #|    Point::{ x } => x
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[missing_field y @ 8:5-8:17, non_exhaustive_match type#0 missing=`Point::{ x: _, y: _ }` @ 7:3-9:4]
    ),
  )
}

///|
test "typecheck produces checked struct pattern fields in declaration order" {
  let pattern = expect_first_checked_match_pattern(
    (
      #|struct Point {
      #|  x : I64
      #|  y : I64
      #|}
      #|fn use(point : Point) -> I64 {
      #|  match point {
      #|    Point::{ y, x } => x
      #|  }
      #|}
    ),
    "use",
  )
  inspect(
    @prettyprinter.render(pattern, width=100),
    content=(
      #|type#0::{
      #|  x#0: x#3
      #|  y#1: y#2
      #|}
    ),
  )
}
