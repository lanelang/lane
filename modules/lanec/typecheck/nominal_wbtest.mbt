///|
fn synthesize_named_let_initializer(
  source : String,
  name : String,
) -> (CheckedExpressionSynthesis, Array[TypeCheckDiagnostic]) {
  let checker = semantic_checker_for_test_source(source)
  for declaration in checker.source.declarations {
    match declaration {
      Let(declaration) =>
        if declaration.name == name {
          let checked = checker.synthesize_checked_expr(
            checker.root_scope(),
            declaration.initializer,
          )
          return (checked, checker.diagnostics)
        } else {
          checker.check_top_level_let(declaration)
        }
      _ => ()
    }
  }
  abort("expected named let")
}

///|
test "typecheck generic struct construction and field access" {
  let result = expect_typecheck_result(
    (
      #|struct Box[A] {
      #|  value : A
      #|}
      #|fn use() -> I64 {
      #|  {
      #|    let box = Box[I64]::{ value: 1 }
      #|    box.value
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
      #|      struct Box#0[A#0 : Type] {
      #|        value#0 : tparam#0
      #|      }
      #|    }
      #|    type_members {}
      #|    fields {
      #|      value#0 : tparam#0
      #|    }
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn use#0 : () -> I64
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck field access through a higher-order type alias" {
  let result = expect_typecheck_result(
    (
      #|struct Inner {
      #|  value : I64
      #|}
      #|struct Wrapper[F : [Type] -> Type] {
      #|  inner : F[Inner]
      #|}
      #|type Id : [Type] -> Type = type[A] => A
      #|fn get(w : Wrapper[Id]) -> I64 {
      #|  w.inner.value
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
}

///|
test "typecheck pattern coverage through a higher-order type alias" {
  let result = expect_typecheck_result(
    (
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|struct Wrapper[F : [Type] -> Type] {
      #|  inner : F[I64]
      #|}
      #|type Maybe : [Type] -> Type = type[A] => Option[A]
      #|fn unwrap(w : Wrapper[Maybe]) -> I64 {
      #|  match w.inner {
      #|    Option::none() => 0
      #|    Option::some(value) => value
      #|  }
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
}

///|
test "typecheck infers struct literal generic arguments from fields" {
  let result = expect_typecheck_result(
    (
      #|struct Box[A] {
      #|  value : A
      #|}
      #|fn use() -> I64 {
      #|  {
      #|    let box = Box::{ value: 1 }
      #|    box.value
      #|  }
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
}

///|
test "typecheck infers struct literal generic arguments from expected type" {
  let result = expect_typecheck_result(
    (
      #|struct Lens[S, A] {
      #|  get : (S) -> A
      #|  set : (S, A) -> S
      #|}
      #|struct Pool {
      #|  size : I64
      #|}
      #|struct Database {
      #|  pool : Pool
      #|}
      #|let lens : Lens[Database, Pool] = Lens::{
      #|  get: fn (database) {
      #|    database.pool
      #|  },
      #|  set: fn (_database, pool) {
      #|    Database::{ pool }
      #|  }
      #|}
      #|fn use() -> I64 {
      #|  lens.get(Database::{ pool: Pool::{ size: 42 } }).size
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
}

///|
test "typecheck reports missing struct literal generic arguments" {
  let result = expect_typecheck_result(
    (
      #|struct Lens[S, A] {
      #|  get : (S) -> A
      #|  set : (S, A) -> S
      #|}
      #|struct Pool {
      #|  size : I64
      #|}
      #|struct Database {
      #|  pool : Pool
      #|}
      #|fn use() -> I64 {
      #|  let _lens = Lens::{
      #|    get: fn (database) {
      #|      database.pool
      #|    },
      #|    set: fn (_database, pool) {
      #|      Database::{ pool }
      #|    }
      #|  }
      #|  0
      #|}
    ),
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: GenericArgumentInferenceFailed(
      #|      label="struct literal generic arguments",
      #|      failure=MissingGenericArguments(
      #|        parameters=[
      #|          { id: { index: 0 }, name: "S", kind: Type },
      #|          { id: { index: 1 }, name: "A", kind: Type },
      #|        ],
      #|      ),
      #|    ),
      #|    loc: {
      #|      start_offset: 166,
      #|      end_offset: 292,
      #|      start_line: 13,
      #|      start_column: 15,
      #|      end_line: 20,
      #|      end_column: 4,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "typecheck existential struct witnesses in declaration order" {
  let result = expect_checked_source_result(
    (
      #|struct Hide {
      #|  type A
      #|  type B
      #|  first : A
      #|  second : B
      #|}
      #|let hidden : Hide = Hide::{ B = Bool, A = I64, second: true, first: 1 }
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|checked_source_typecheck_result {
      #|  checked {
      #|    struct Hide#0 {
      #|      type A#0 : Type
      #|      type B#1 : Type
      #|      first#0 : tparam#0
      #|      second#1 : tparam#1
      #|    }
      #|    let hidden#0 : type#0 = {
      #|      let _struct_field_second#1 : Bool = true
      #|      let _struct_field_first#2 : I64 = 1
      #|      type#0::{
      #|        type A#0 = I64
      #|        type B#1 = Bool
      #|        first#0: _struct_field_first#2
      #|        second#1: _struct_field_second#1
      #|      }
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "silent handler measurement does not consume generated local identities" {
  let result = expect_checked_source_result(
    (
      #|struct Pair {
      #|  first : I64
      #|  second : Bool
      #|}
      #|effect Prompt {
      #|  ask() -> Unit
      #|}
      #|fn make() -> Pair {
      #|  handle Prompt::ask!() with {
      #|    Prompt::ask(_resume) => Pair::{ second: true, first: 1 }
      #|  } final _value {
      #|    Pair::{ first: 0, second: false }
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|checked_source_typecheck_result {
      #|  checked {
      #|    struct Pair#0 {
      #|      first#0 : I64
      #|      second#1 : Bool
      #|    }
      #|    effect Prompt#0 {
      #|      ask#0 -> Unit
      #|    }
      #|    fn make#0() -> type#0 {
      #|      {
      #|        handle operation#0!()
      #|        with effect#0 {
      #|          operation#0(_resume#1) => {
      #|            let _struct_field_second#3 : Bool = true
      #|            let _struct_field_first#4 : I64 = 1
      #|            type#0::{
      #|              first#0: _struct_field_first#4
      #|              second#1: _struct_field_second#3
      #|            }
      #|          }
      #|        }
      #|        final _value#2 {
      #|          type#0::{
      #|            first#0: 0
      #|            second#1: false
      #|          }
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
test "value use analysis excludes struct sequencing temporaries" {
  let file = expect_parse_ok(
    (
      #|struct Pair {
      #|  first : I64
      #|  second : Bool
      #|}
      #|fn make(number : I64, flag : Bool) -> Pair {
      #|  let pair = Pair::{ second: flag, first: number }
      #|  pair
      #|}
    ),
  )
  let resolution = @resolve.resolve_source_file_result(file)
  if !resolution.diagnostics.is_empty() {
    abort(@prettyprinter.render(resolution.diagnostics, width=100))
  }
  let result = typecheck_checked_source_file(resolution.source)
  guard result.source is Some(source) else {
    abort(@prettyprinter.render(result.diagnostics, width=100))
  }
  let registry = resolution.source.symbols
  let analysis = source.value_use_analysis(registry)
  debug_inspect(
    analysis,
    content=(
      #|{
      #|  binders: [
      #|    {
      #|      symbol: { index: 1 },
      #|      name: "number",
      #|      loc: {
      #|        start_offset: 66,
      #|        end_offset: 72,
      #|        start_line: 6,
      #|        start_column: 9,
      #|        end_line: 6,
      #|        end_column: 15,
      #|      },
      #|      kind: FunctionParameter,
      #|    },
      #|    {
      #|      symbol: { index: 2 },
      #|      name: "flag",
      #|      loc: {
      #|        start_offset: 80,
      #|        end_offset: 84,
      #|        start_line: 6,
      #|        start_column: 23,
      #|        end_line: 6,
      #|        end_column: 27,
      #|      },
      #|      kind: FunctionParameter,
      #|    },
      #|    {
      #|      symbol: { index: 3 },
      #|      name: "pair",
      #|      loc: {
      #|        start_offset: 109,
      #|        end_offset: 113,
      #|        start_line: 7,
      #|        start_column: 7,
      #|        end_line: 7,
      #|        end_column: 11,
      #|      },
      #|      kind: LocalLet,
      #|    },
      #|  ],
      #|  references: [
      #|    {
      #|      target: { index: 2 },
      #|      origin_binder: Some({ index: 3 }),
      #|      loc: {
      #|        start_offset: 132,
      #|        end_offset: 136,
      #|        start_line: 7,
      #|        start_column: 30,
      #|        end_line: 7,
      #|        end_column: 34,
      #|      },
      #|    },
      #|    {
      #|      target: { index: 1 },
      #|      origin_binder: Some({ index: 3 }),
      #|      loc: {
      #|        start_offset: 145,
      #|        end_offset: 151,
      #|        start_line: 7,
      #|        start_column: 43,
      #|        end_line: 7,
      #|        end_column: 49,
      #|      },
      #|    },
      #|    {
      #|      target: { index: 3 },
      #|      origin_binder: None,
      #|      loc: {
      #|        start_offset: 156,
      #|        end_offset: 160,
      #|        start_line: 8,
      #|        start_column: 3,
      #|        end_line: 8,
      #|        end_column: 7,
      #|      },
      #|    },
      #|  ],
      #|}
    ),
  )
}

///|
test "typecheck reports missing existential struct type witness" {
  let result = expect_typecheck_result(
    (
      #|struct Hide {
      #|  type T : Type
      #|  val : T
      #|}
      #|let hidden : Hide = Hide::{ val: 1 }
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[missing_type_member T @ 6:21-6:37]
    ),
  )
}

///|
test "typecheck rejects incomplete existential struct witnesses before checked AST" {
  let cases = [
    (
      #|struct Hide {
      #|  type T : Type
      #|  value : T
      #|}
      #|let hidden : Hide = Hide::{ value: 1 }
    ),
    (
      #|struct Hide {
      #|  type T : Type
      #|  value : T
      #|}
      #|let hidden : Hide = Hide::{ T = I64, T = Bool, value: 1 }
    ),
    (
      #|struct Hide {
      #|  type T : Type
      #|  value : T
      #|}
      #|let hidden : Hide = Hide::{ T = I64, Unknown = Bool, value: 1 }
    ),
    (
      #|struct Hide {
      #|  type T : Type
      #|  value : T
      #|}
      #|let hidden : Hide = Hide::{ unknown: true }
    ),
  ]
  let results = []
  for source in cases {
    let (checked, diagnostics) = synthesize_named_let_initializer(
      source, "hidden",
    )
    results.push(
      (
        checked.expression is None,
        @prettyprinter.render(diagnostics, width=100),
      ),
    )
  }
  debug_inspect(
    results,
    content=(
      #|[
      #|  (true, "[missing_type_member T @ 6:21-6:39]"),
      #|  (true, "[duplicate_type_member T @ 6:38-6:46]"),
      #|  (true, "[unknown_type_member Unknown @ 6:38-6:52]"),
      #|  (
      #|    true,
      #|    "[\n  missing_type_member T @ 6:21-6:44,\n  unknown_field unknown @ 6:29-6:42,\n  missing_field value @ 6:21-6:44\n]",
      #|  ),
      #|]
    ),
  )
}

///|
test "typecheck reports field access on non-struct value" {
  let result = expect_typecheck_result(
    (
      #|fn bad() -> I64 {
      #|  1.value
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[not_a_struct I64 @ 3:3-3:10]
    ),
  )
}

///|
test "typecheck qualified enum variant construction" {
  let result = expect_typecheck_result(
    (
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|fn wrap(value : I64) -> Option[I64] {
      #|  Option::some(value)
      #|}
      #|fn empty() -> Option[I64] {
      #|  Option::none()
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
test "typecheck existential enum variant construction with explicit witness" {
  let result = expect_checked_source_result(
    (
      #|enum Packed {
      #|  hide[T](T)
      #|}
      #|let packed : Packed = Packed::hide[I64](1)
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
      #|    let packed#0 : type#0 = variant#0[I64](1)
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck existential enum variant construction infers witness" {
  let result = expect_checked_source_result(
    (
      #|enum Packed {
      #|  hide[T](T)
      #|}
      #|let packed : Packed = Packed::hide(1)
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
      #|    let packed#0 : type#0 = variant#0[I64](1)
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck existential enum pattern opens witness" {
  let pattern = expect_first_checked_match_pattern(
    (
      #|enum Packed {
      #|  hide[T](T)
      #|}
      #|fn use(p : Packed) -> I64 {
      #|  match p {
      #|    Packed::hide[T](value) => 1
      #|  }
      #|}
    ),
    "use",
  )
  inspect(
    @prettyprinter.render(pattern, width=100),
    content=(
      #|variant#0[tparam#1](value#2)
    ),
  )
}

///|
test "typecheck existential enum pattern checks payload under opened witness" {
  let result = expect_typecheck_result(
    (
      #|enum Packed {
      #|  hide[T](T)
      #|}
      #|fn bad(p : Packed) -> I64 {
      #|  match p {
      #|    Packed::hide[T](value) => value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[hidden_type_escape tparam#1 @ 7:31-7:36]
    ),
  )
}

///|
test "typecheck existential struct pattern opens type binder" {
  let pattern = expect_first_checked_match_pattern(
    (
      #|struct Hide {
      #|  type T : Type
      #|  val : T
      #|}
      #|fn use(h : Hide) -> I64 {
      #|  match h {
      #|    Hide::{ T, val } => 1
      #|  }
      #|}
    ),
    "use",
  )
  inspect(
    @prettyprinter.render(pattern, width=100),
    content=(
      #|type#0::{
      #|  type T#0 = T#1
      #|  val#0: val#2
      #|}
    ),
  )
}

///|
test "typecheck existential struct pattern opens wildcard witness" {
  let pattern = expect_first_checked_match_pattern(
    (
      #|struct Hide {
      #|  type T : Type
      #|  val : T
      #|}
      #|fn use(h : Hide) -> I64 {
      #|  match h {
      #|    Hide::{ _, val } => 1
      #|  }
      #|}
    ),
    "use",
  )
  inspect(
    @prettyprinter.render(pattern, width=100),
    content=(
      #|type#0::{
      #|  type tmember#0 = _
      #|  val#0: val#2
      #|}
    ),
  )
}

///|
test "typecheck existential struct pattern assigns multiple wildcards by order" {
  let pattern = expect_first_checked_match_pattern(
    (
      #|struct PairHide {
      #|  type A : Type
      #|  type B : Type
      #|  left : A
      #|  right : B
      #|}
      #|fn use(h : PairHide) -> I64 {
      #|  match h {
      #|    PairHide::{ _, _, left, right } => 1
      #|  }
      #|}
    ),
    "use",
  )
  inspect(
    @prettyprinter.render(pattern, width=100),
    content=(
      #|type#0::{
      #|  type tmember#0 = _
      #|  type tmember#1 = _
      #|  left#0: left#2
      #|  right#1: right#3
      #|}
    ),
  )
}

///|
test "typecheck existential struct pattern checks field under opened witness" {
  let result = expect_typecheck_result(
    (
      #|struct Hide {
      #|  type T : Type
      #|  val : T
      #|}
      #|fn bad(h : Hide) -> I64 {
      #|  match h {
      #|    Hide::{ T, val } => val
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[hidden_type_escape tparam#1 @ 8:25-8:28]
    ),
  )
}

///|
test "typecheck rejects escaped existential struct binder from block result" {
  let result = expect_typecheck_result(
    (
      #|struct Hide {
      #|  type T : Type
      #|  val : T
      #|}
      #|fn bad(h : Hide) -> I64 {
      #|  {
      #|    let escaped = {
      #|      let Hide::{ T, val } = h
      #|      val
      #|    }
      #|    1
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[hidden_type_escape tparam#1 @ 10:7-10:10]
    ),
  )
}

///|
test "typecheck allows repacking existential struct before leaving block" {
  let result = expect_typecheck_result(
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
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
}

///|
test "typecheck rejects escaped existential enum binder from match result" {
  let result = expect_typecheck_result(
    (
      #|enum Packed {
      #|  hide[T](T)
      #|}
      #|fn bad(p : Packed) -> I64 {
      #|  {
      #|    let escaped = match p {
      #|      Packed::hide[T](value) => value
      #|    }
      #|    1
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[hidden_type_escape tparam#1 @ 8:33-8:38]
    ),
  )
}

///|
test "typecheck allows repacking existential enum before leaving match arm" {
  let result = expect_typecheck_result(
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
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
}

///|
test "typecheck propagates expected function type into existential match arm" {
  let result = expect_typecheck_result(
    (
      #|struct Hide {
      #|  type T
      #|  val : T
      #|}
      #|fn use(h : Hide) -> (I64) -> I64 {
      #|  match h {
      #|    Hide::{ T, val } => fn(x) { x }
      #|  }
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "typecheck reports hidden escape inside contextually checked function" {
  let result = expect_typecheck_result(
    (
      #|enum Packed {
      #|  hide[T](T)
      #|}
      #|fn bad(p : Packed) -> () -> I64 {
      #|  match p {
      #|    Packed::hide[T](value) => fn() { value }
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[hidden_type_escape tparam#1 @ 7:38-7:43]
    ),
  )
}

///|
test "typecheck rejects escaped existential enum binder from pattern let" {
  let result = expect_typecheck_result(
    (
      #|enum Packed {
      #|  hide[T](T)
      #|}
      #|fn bad(p : Packed) -> I64 {
      #|  {
      #|    let escaped = {
      #|      let hide[T](value) = p
      #|      value
      #|    }
      #|    1
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[hidden_type_escape tparam#1 @ 9:7-9:12]
    ),
  )
}

///|
test "typecheck reports type mismatch" {
  let result = expect_typecheck_result(
    (
      #|fn bad() -> I64 {
      #|  true
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[type_mismatch expected=I64 actual=Bool @ 3:3-3:7]
    ),
  )
}

///|
test "typecheck struct literal punning and required fields" {
  let result = expect_typecheck_result(
    (
      #|struct Point {
      #|  x : I64
      #|  y : I64
      #|}
      #|fn bad(x : I64) -> Point {
      #|  Point::{ x }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[missing_field y @ 7:3-7:15]
    ),
  )
}

///|
test "typecheck reports missing leading struct field" {
  let result = expect_typecheck_result(
    (
      #|struct Pair {
      #|  first : I64
      #|  second : Bool
      #|}
      #|fn bad() -> Pair {
      #|  Pair::{ second: true }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[missing_field first @ 7:3-7:25]
    ),
  )
}

///|
test "typecheck reports nominal type arity mismatch" {
  let result = expect_declaration_typecheck_result(
    (
      #|struct Box[A] {
      #|  value : A
      #|}
      #|struct Bad {
      #|  broken : Box[I64, Bool]
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[type_arity_mismatch Box expected=1 actual=2 @ 6:12-6:26]
    ),
  )
}

///|
test "typecheck keeps unresolved type as error type" {
  let file = expect_parse_ok(
    (
      #|struct Bad {
      #|  missing : Missing
      #|}
    ),
  )
  let resolution = @resolve.resolve_source_file_result(file)
  debug_inspect(
    resolution.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: UnresolvedType("Missing"),
      #|    loc: {
      #|      start_offset: 37,
      #|      end_offset: 44,
      #|      start_line: 3,
      #|      start_column: 13,
      #|      end_line: 3,
      #|      end_column: 20,
      #|    },
      #|  },
      #|]
    ),
  )
  let result = typecheck_declarations(resolution.source)
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|declaration_typecheck_result {
      #|  checked_declarations {
      #|    types {
      #|      struct Bad#0 {
      #|        missing#0 : <error>
      #|      }
      #|    }
      #|    type_members {}
      #|    fields {
      #|      missing#0 : <error>
      #|    }
      #|    variants {}
      #|  }
      #|  diagnostics {
      #|    unresolved_type Missing @ 3:13-3:20
      #|  }
      #|}
    ),
  )
}
