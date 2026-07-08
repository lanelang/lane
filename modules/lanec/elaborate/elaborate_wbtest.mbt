///|
fn expect_parse_ok(source : String) -> @syntax.SourceFile {
  let result = @parser.parse_string("module Test\n" + source)
  if !result.lexical_errors.is_empty() || !result.parse_errors.is_empty() {
    abort("expected parse success")
  }
  guard result.source is Some(file) else { abort("expected source file") }
  file
}

///|
fn elaborate_source(source : String) -> ElaborateResult {
  let file = expect_parse_ok(source)
  let resolved = @resolve.resolve_source_file(file)
  elaborate_resolved_source_file(resolved)
}

///|
fn elaborate_anf_source(source : String) -> AnfElaborateResult {
  let file = expect_parse_ok(source)
  let resolved = @resolve.resolve_source_file(file)
  elaborate_resolved_source_file_to_anf(resolved)
}

///|
priv struct CheckedSuccessSummary {
  has_source : Bool
  diagnostics : Int
} derive(Debug)

///|
fn CheckedSuccessSummary::from_result(
  result : ElaborateResult,
) -> CheckedSuccessSummary {
  {
    has_source: result.source is Some(_),
    diagnostics: result.diagnostics.length(),
  }
}

///|
test "elaborate resolved source into checked source" {
  let result = elaborate_source(
    (
      #|struct Box {
      #|  value : Int
      #|}
      #|fn identity(x : Int) -> Int {
      #|  x
      #|}
      #|let answer : Int = 42
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|elaborate_result {
      #|  checked {
      #|    struct Box#0 {
      #|      value#0 : Int
      #|    }
      #|    fn identity#0(x#2 : Int) -> Int {
      #|      x#2
      #|    }
      #|    let answer#1 : Int = 42
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "checked source success rejects unresolved and contextual boundary states" {
  let unresolved = elaborate_source(
    (
      #|let answer : Int = missing
    ),
  )
  let missing_contextual = elaborate_source(
    (
      #|struct Add[A] {
      #|  add : (A, A) -> A
      #|}
      #|fn[A] op_add(a : A, b : A, auto op : Add[A]) -> A {
      #|  op.add(a, b)
      #|}
      #|let answer : Int = 1 + 2
    ),
  )
  debug_inspect(
    [
      CheckedSuccessSummary::from_result(unresolved),
      CheckedSuccessSummary::from_result(missing_contextual),
    ],
    content=(
      #|[
      #|  { has_source: false, diagnostics: 2 },
      #|  { has_source: false, diagnostics: 1 },
      #|]
    ),
  )
}

///|
test "elaborate resolved source into anf" {
  let result = elaborate_anf_source(
    (
      #|fn identity(x : Int) -> Int {
      #|  x
      #|}
      #|let answer : Int = identity(42)
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|anf_elaborate_result {
      #|  anf {
      #|    letrec {
      #|      value#0 = fn(value#2) -> Int {
      #|        value#2
      #|      }
      #|    }
      #|    let value#1 = {
      #|      let temp#0 = value#0(42)
      #|      temp#0
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "elaborate effect handler source into anf" {
  let result = elaborate_anf_source(
    (
      #|effect Flip {
      #|  flip() -> Bool
      #|}
      #|pub fn program() -> Bool {
      #|  handle Flip::flip!() with {
      #|    Flip::flip(resume) => resume(true)
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  assert_eq(result.diagnostics.length(), 0)
  guard result.program is Some(_) else { abort("expected anf program") }
}

///|
test "elaborate builtins through contextual expected types" {
  let result = elaborate_source(
    (
      #|fn identity(value : Int) -> Int {
      #|  value
      #|}
      #|let top : Int = builtin("%top")
      #|fn direct() -> Int {
      #|  builtin("%direct")
      #|}
      #|fn use() -> Int {
      #|  let local : Int = builtin("%local")
      #|  identity(builtin("%argument"))
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|elaborate_result {
      #|  checked {
      #|    fn identity#0(value#4 : Int) -> Int {
      #|      value#4
      #|    }
      #|    let top#1 : Int = builtin("%top")
      #|    fn direct#2() -> Int {
      #|      builtin("%direct")
      #|    }
      #|    fn use#3() -> Int {
      #|      let local#5 : Int = builtin("%local")
      #|      identity#0(builtin("%argument"))
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "elaborate checked if expression" {
  let result = elaborate_source(
    (
      #|fn choose(value : Bool) -> Int {
      #|  if value { 1 } else { 2 }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|elaborate_result {
      #|  checked {
      #|    fn choose#0(value#1 : Bool) -> Int {
      #|      if value#1 {
      #|        1
      #|      } else {
      #|        2
      #|      }
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "elaborate top level offer value declarations" {
  let result = elaborate_source(
    (
      #|struct Box {
      #|  value : Int
      #|}
      #|offer box : Box = builtin("%box")
      #|fn use() -> Box {
      #|  box
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|elaborate_result {
      #|  checked {
      #|    struct Box#0 {
      #|      value#0 : Int
      #|    }
      #|    let box#0 : type#0 = builtin("%box")
      #|    fn use#1() -> type#0 {
      #|      box#0
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "elaborate pipeline expression into checked call" {
  let result = elaborate_source(
    (
      #|fn first(a : Int, b : Int) -> Int {
      #|  a
      #|}
      #|fn use() -> Int {
      #|  1 |> first(2)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|elaborate_result {
      #|  checked {
      #|    fn first#0(a#2 : Int, b#3 : Int) -> Int {
      #|      a#2
      #|    }
      #|    fn use#1() -> Int {
      #|      first#0(1, 2)
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "elaborate direct binary operator alias into checked call" {
  let result = elaborate_source(
    (
      #|fn op_add(a : Int, b : Int) -> Int {
      #|  a
      #|}
      #|fn use() -> Int {
      #|  1 + 2
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|elaborate_result {
      #|  checked {
      #|    fn op_add#0(a#2 : Int, b#3 : Int) -> Int {
      #|      a#2
      #|    }
      #|    fn use#1() -> Int {
      #|      op_add#0(1, 2)
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "elaborate direct unary operator alias into checked call" {
  let result = elaborate_source(
    (
      #|fn op_neg(value : Int) -> Int {
      #|  value
      #|}
      #|fn use() -> Int {
      #|  -1
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|elaborate_result {
      #|  checked {
      #|    fn op_neg#0(value#2 : Int) -> Int {
      #|      value#2
      #|    }
      #|    fn use#1() -> Int {
      #|      op_neg#0(1)
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "elaborate pipeline into function literal call" {
  let result = elaborate_source(
    (
      #|fn use() -> Int {
      #|  1 |> fn(value : Int) {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|elaborate_result {
      #|  checked {
      #|    fn use#0() -> Int {
      #|      fn(value#1 : Int) -> Int {
      #|        value#1
      #|      }(1)
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "elaborate lazy bool operator into thunked checked call" {
  let result = elaborate_source(
    (
      #|fn op_and(a : Bool, b : () -> Bool) -> Bool {
      #|  a
      #|}
      #|fn use(a : Bool, b : Bool) -> Bool {
      #|  a && b
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|elaborate_result {
      #|  checked {
      #|    fn op_and#0(a#2 : Bool, b#3 : () -> Bool) -> Bool {
      #|      a#2
      #|    }
      #|    fn use#1(a#4 : Bool, b#5 : Bool) -> Bool {
      #|      op_and#0(a#4, fn() -> Bool {
      #|        b#5
      #|      })
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "elaborate existential openings into checked source" {
  let result = elaborate_source(
    (
      #|struct Hide {
      #|  type T : Type
      #|  val : T
      #|}
      #|enum Packed {
      #|  hide[T](T)
      #|}
      #|fn repack_struct(h : Hide) -> Hide {
      #|  {
      #|    let Hide::{ T, val } = h
      #|    Hide::{ T = T, val: val }
      #|  }
      #|}
      #|fn repack_enum(p : Packed) -> Packed {
      #|  match p {
      #|    Packed::hide[T](value) => Packed::hide[T](value)
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|elaborate_result {
      #|  checked {
      #|    struct Hide#0 {
      #|      type T#0 : Type
      #|      val#0 : tparam#0
      #|    }
      #|    enum Packed#1 {
      #|      hide#0[T#1 : Type](tparam#1)
      #|    }
      #|    fn repack_struct#0(h#2 : type#0) -> type#0 {
      #|      {
      #|        let type#0::{
      #|          type T#0 = T#2
      #|          val#0: val#3
      #|        } = h#2
      #|        type#0::{
      #|          type T#0 = tparam#2
      #|          val#0: val#3
      #|        }
      #|      }
      #|    }
      #|    fn repack_enum#1(p#4 : type#1) -> type#1 {
      #|      match p#4 {
      #|        variant#0[tparam#3](value#5) => variant#0[tparam#3](value#5)
      #|      }
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}
