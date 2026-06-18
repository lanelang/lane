///|
fn expect_parse_ok(source : String) -> @syntax.SourceFile {
  let result = @parser.parse_string(source)
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
fn elaborate_buslane_source(source : String) -> BuslaneElaborateResult {
  let file = expect_parse_ok(source)
  let resolved = @resolve.resolve_source_file(file)
  elaborate_resolved_source_file_to_buslane(resolved)
}

///|
fn elaborate_anf_source(source : String) -> AnfElaborateResult {
  let file = expect_parse_ok(source)
  let resolved = @resolve.resolve_source_file(file)
  elaborate_resolved_source_file_to_anf(resolved)
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
test "elaborate resolved source into buslane core" {
  let result = elaborate_buslane_source(
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
      #|buslane_elaborate_result {
      #|  buslane {
      #|    metadata {
      #|      function value#0 : (Int) -> Int
      #|      value value#1 : Int
      #|      parameter value#2 : Int
      #|    }
      #|    letrec {
      #|      value#0 = fn(value#2) -> Int {
      #|        value#2
      #|      }
      #|    }
      #|    let value#1 = value#0(42)
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "elaborate generic enum variant into verifiable buslane" {
  let result = elaborate_buslane_source(
    (
      #|enum Option[A] {
      #|  none
      #|  some(A)
      #|}
      #|let answer : Option[Int] = Option::some(1)
    ),
  )
  guard result.program is Some(program) else {
    abort("expected buslane program")
  }
  inspect(
    @prettyprinter.render(@buslane.verify_program(program), width=100),
    content=(
      #|verify_result {}
    ),
  )
}

///|
test "elaborate type aliases into alias-free buslane types" {
  let result = elaborate_buslane_source(
    (
      #|struct Box[A] {
      #|  value : A
      #|}
      #|type Boxed = type[A] => Box[A]
      #|let answer : Boxed[Int] = Box::{ value: 1 }
    ),
  )
  guard result.program is Some(program) else {
    abort("expected buslane program")
  }
  inspect(
    @prettyprinter.render(@buslane.verify_program(program), width=100),
    content=(
      #|verify_result {}
    ),
  )
  let answer_type = program.metadata.values[program.metadata.values.length() - 1].type_
  inspect(@prettyprinter.render(answer_type, width=100), content="type#0[Int]")
}

///|
test "elaborate struct field access into buslane selector" {
  let result = elaborate_buslane_source(
    (
      #|struct Point {
      #|  x : Int
      #|  y : Int
      #|}
      #|let answer : Int = Point::{ x: 1, y: 2 }.x
    ),
  )
  guard result.program is Some(program) else {
    abort("expected buslane program")
  }
  inspect(
    @prettyprinter.render(@buslane.verify_program(program), width=100),
    content=(
      #|verify_result {}
    ),
  )
}

///|
test "elaborate pattern binders before match arm bodies" {
  let result = elaborate_buslane_source(
    (
      #|struct Point {
      #|  x : Int
      #|  y : Int
      #|}
      #|enum Option[A] {
      #|  none
      #|  some(A)
      #|}
      #|fn choose(value : Option[Int], fallback : Int) -> Int {
      #|  match value {
      #|    Option::none => fallback
      #|    Option::some(x) => x
      #|  }
      #|}
      #|fn first(point : Point) -> Int {
      #|  match point {
      #|    Point::{ x, y } => x
      #|  }
      #|}
      #|let answer : Int = choose(Option::some(1), first(Point::{ x: 2, y: 3 }))
    ),
  )
  guard result.program is Some(program) else {
    abort("expected buslane program")
  }
  inspect(
    @prettyprinter.render(@buslane.verify_program(program), width=100),
    content=(
      #|verify_result {}
    ),
  )
}

///|
test "elaborate local recursive function into verifiable buslane" {
  let result = elaborate_buslane_source(
    (
      #|fn use(value : Int) -> Int {
      #|  fn loop(current : Int) -> Int {
      #|    loop(current)
      #|  }
      #|  loop(value)
      #|}
    ),
  )
  guard result.program is Some(program) else {
    abort("expected buslane program")
  }
  inspect(
    @prettyprinter.render(@buslane.verify_program(program), width=100),
    content=(
      #|verify_result {}
    ),
  )
}

///|
test "elaborate existential struct construction into verifiable buslane" {
  let result = elaborate_buslane_source(
    (
      #|struct Hide {
      #|  type T : Type
      #|  val : T
      #|}
      #|let packed : Hide = Hide::{ T = Int, val: 1 }
    ),
  )
  guard result.program is Some(program) else {
    abort("expected buslane program")
  }
  inspect(
    @prettyprinter.render(@buslane.verify_program(program), width=100),
    content=(
      #|verify_result {}
    ),
  )
}

///|
test "elaborate existential struct repack into verifiable buslane" {
  let result = elaborate_buslane_source(
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
  guard result.program is Some(program) else {
    abort("expected buslane program")
  }
  inspect(
    @prettyprinter.render(@buslane.verify_program(program), width=100),
    content=(
      #|verify_result {}
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
      #|  buslane_anf_program {
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
