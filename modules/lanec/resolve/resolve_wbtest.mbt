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
test "collect top level declaration symbols" {
  let file = expect_parse_ok(
    (
      #|struct Point {
      #|  x : Int
      #|  y : Int
      #|}
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|fn unwrap_or(value : Option[Int], fallback : Int) -> Int {
      #|  match value {
      #|    Option::none() => fallback
      #|    Option::some(x) => x
      #|  }
      #|}
      #|let origin : Point = Point::{ x: 1, y: 2 }
    ),
  )
  inspect(
    @prettyprinter.render(resolve_source_file(file), width=100),
    content=(
      #|resolved {
      #|  symbols {
      #|    types {
      #|      type#0 struct Point/0
      #|      type#1 enum Option/1
      #|    }
      #|    type_parameters {
      #|      tparam#0 A
      #|    }
      #|    type_members {}
      #|    values {
      #|      value#0 top_function unwrap_or
      #|      value#1 top_value origin
      #|      value#2 parameter value
      #|      value#3 parameter fallback
      #|      value#4 pattern_binder x
      #|    }
      #|    fields {
      #|      field#0 owner=type#0 x index=0
      #|      field#1 owner=type#0 y index=1
      #|    }
      #|    variants {
      #|      variant#0 owner=type#1 none index=0 payloads=0
      #|      variant#1 owner=type#1 some index=1 payloads=1
      #|    }
      #|  }
      #|  declarations {
      #|    struct type#0 Point {
      #|      field field#0 x : Int index=0
      #|      field field#1 y : Int index=1
      #|    }
      #|    enum type#1 Option[tparam#0 A] {
      #|      variant variant#0 none index=0 payloads=0
      #|      variant variant#1 some index=1 payloads=1(tparam#0 A)
      #|    }
      #|    fn value#0 unwrap_or(value#2 value : type#1 Option[Int], value#3 fallback : Int) -> Int {
      #|      match var value#2 value {
      #|        variant#0 Option::none => var value#3 fallback
      #|        variant#1 Option::some(bind value#4 x) => var value#4 x
      #|      }
      #|    }
      #|    let value#1 origin : type#0 Point = Point::{
      #|      x: 1
      #|      y: 2
      #|    }
      #|  }
      #|}
    ),
  )
}

///|
test "resolve effect declarations and operation symbols" {
  let file = expect_parse_ok(
    (
      #|pub effect State[S] {
      #|  get() -> S
      #|  put(S) -> Unit
      #|  choose[A](A, A) -> A
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(resolve_source_file(file), width=100),
    content=(
      #|resolved {
      #|  symbols {
      #|    types {}
      #|    type_parameters {
      #|      tparam#0 S
      #|      tparam#1 A
      #|    }
      #|    type_members {}
      #|    values {}
      #|    fields {}
      #|    variants {}
      #|    effects {
      #|      effect#0 State/1
      #|    }
      #|    operations {
      #|      operation#0 owner=effect#0 get index=0 payloads=0
      #|      operation#1 owner=effect#0 put index=1 payloads=1
      #|      operation#2 owner=effect#0 choose index=2 payloads=2
      #|    }
      #|  }
      #|  declarations {
      #|    effect effect#0 State[tparam#0 S] {
      #|      operation operation#0 get index=0 -> tparam#0 S
      #|      operation operation#1 put index=1(tparam#0 S) -> Unit
      #|      operation operation#2 choose index=2[tparam#1 A](tparam#1 A, tparam#1 A) -> tparam#1 A
      #|    }
      #|  }
      #|}
    ),
  )
}

///|
test "resolve handler operation arms and binders" {
  let file = expect_parse_ok(
    (
      #|effect Console {
      #|  read() -> String
      #|  write(String) -> Unit
      #|  choose() -> Unit
      #|}
      #|fn program() -> String ! Console {
      #|  handle Console::read!() with {
      #|    Console::write(message, resume) => resume(())
      #|    ::read(resume2) => "fallback"
      #|    choose(resume3) => resume3(())
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(resolve_source_file(file), width=100),
    content=(
      #|resolved {
      #|  symbols {
      #|    types {}
      #|    type_parameters {}
      #|    type_members {}
      #|    values {
      #|      value#0 top_function program
      #|      value#1 pattern_binder message
      #|      value#2 pattern_binder resume
      #|      value#3 pattern_binder resume2
      #|      value#4 pattern_binder resume3
      #|      value#5 pattern_binder value
      #|    }
      #|    fields {}
      #|    variants {}
      #|    effects {
      #|      effect#0 Console/0
      #|    }
      #|    operations {
      #|      operation#0 owner=effect#0 read index=0 payloads=0
      #|      operation#1 owner=effect#0 write index=1 payloads=1
      #|      operation#2 owner=effect#0 choose index=2 payloads=0
      #|    }
      #|  }
      #|  declarations {
      #|    effect effect#0 Console {
      #|      operation operation#0 read index=0 -> String
      #|      operation operation#1 write index=1(String) -> Unit
      #|      operation operation#2 choose index=2 -> Unit
      #|    }
      #|    fn value#0 program() -> String ! effect#0 Console {
      #|      {
      #|        handle effect#0 Console::read@operation#0!()
      #|        with {
      #|          effect#0 Console::write@operation#1(bind value#1 message, value#2 resume) => var value#2 resume(())
      #|          ::read@operation#0(value#3 resume2) => "fallback"
      #|          choose@operation#2(value#4 resume3) => var value#4 resume3(())
      #|        }
      #|        final value#5 value {
      #|          var value#5 value
      #|        }
      #|      }
      #|    }
      #|  }
      #|}
    ),
  )
}

///|
test "resolve unqualified variant calls after nominal member collection" {
  let file = expect_parse_ok(
    (
      #|fn wrap(value : Int) -> Option[Int] {
      #|  some(value)
      #|}
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(resolve_source_file(file), width=100),
    content=(
      #|resolved {
      #|  symbols {
      #|    types {
      #|      type#0 enum Option/1
      #|    }
      #|    type_parameters {
      #|      tparam#0 A
      #|    }
      #|    type_members {}
      #|    values {
      #|      value#0 top_function wrap
      #|      value#1 parameter value
      #|    }
      #|    fields {}
      #|    variants {
      #|      variant#0 owner=type#0 none index=0 payloads=0
      #|      variant#1 owner=type#0 some index=1 payloads=1
      #|    }
      #|  }
      #|  declarations {
      #|    fn value#0 wrap(value#1 value : Int) -> type#0 Option[Int] {
      #|      variant#1 some(var value#1 value)
      #|    }
      #|    enum type#0 Option[tparam#0 A] {
      #|      variant variant#0 none index=0 payloads=0
      #|      variant variant#1 some index=1 payloads=1(tparam#0 A)
      #|    }
      #|  }
      #|}
    ),
  )
}

///|
test "report payloadless unqualified variant call" {
  let file = expect_parse_ok(
    (
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|fn empty() -> Option[Int] {
      #|  none()
      #|}
    ),
  )
  let result = resolve_source_file_result(file)
  inspect(
    @prettyprinter.render(result.diagnostics[0]),
    content="payloadless_variant_call none",
  )
}

///|
test "resolve existential surface metadata" {
  let file = expect_parse_ok(
    (
      #|struct Hide {
      #|  type T : Type
      #|  val : T
      #|}
      #|enum Packed {
      #|  hide[T](T)
      #|}
      #|fn make(value : Int) -> Hide {
      #|  Hide::{ T = Int, val: value }
      #|}
      #|fn use(h : Hide, p : Packed) -> Int {
      #|  {
      #|    let Hide::{ T, val } = h
      #|    match p {
      #|      Packed::hide[U](x) => 1
      #|    }
      #|  }
      #|}
      #|fn ignore_hidden(h : Hide) -> Int {
      #|  {
      #|    let Hide::{ _, val } = h
      #|    1
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(resolve_source_file(file), width=100),
    content=(
      #|resolved {
      #|  symbols {
      #|    types {
      #|      type#0 struct Hide/0
      #|      type#1 enum Packed/0
      #|    }
      #|    type_parameters {
      #|      tparam#0 T
      #|      tparam#1 T
      #|      tparam#2 T
      #|      tparam#3 U
      #|      tparam#4 _
      #|    }
      #|    type_members {
      #|      tmember#0 owner=type#0 parameter=tparam#0 T index=0
      #|    }
      #|    values {
      #|      value#0 top_function make
      #|      value#1 top_function use
      #|      value#2 top_function ignore_hidden
      #|      value#3 parameter value
      #|      value#4 parameter h
      #|      value#5 parameter p
      #|      value#6 pattern_binder val
      #|      value#7 pattern_binder x
      #|      value#8 parameter h
      #|      value#9 pattern_binder val
      #|    }
      #|    fields {
      #|      field#0 owner=type#0 val index=0
      #|    }
      #|    variants {
      #|      variant#0 owner=type#1 hide index=0 payloads=1
      #|    }
      #|  }
      #|  declarations {
      #|    struct type#0 Hide {
      #|      type tmember#0 tparam#0 T : Type index=0
      #|      field field#0 val : tparam#0 T index=0
      #|    }
      #|    enum type#1 Packed {
      #|      variant variant#0 hide index=0 payloads=1[tparam#1 T](tparam#1 T)
      #|    }
      #|    fn value#0 make(value#3 value : Int) -> type#0 Hide {
      #|      Hide::{
      #|        T = Int
      #|        val: var value#3 value
      #|      }
      #|    }
      #|    fn value#1 use(value#4 h : type#0 Hide, value#5 p : type#1 Packed) -> Int {
      #|      {
      #|        let Hide{
      #|          type tparam#2 T
      #|          val: bind value#6 val
      #|        } = var value#4 h
      #|        match var value#5 p {
      #|          variant#0 Packed::hide[tparam#3 U](bind value#7 x) => 1
      #|        }
      #|      }
      #|    }
      #|    fn value#2 ignore_hidden(value#8 h : type#0 Hide) -> Int {
      #|      {
      #|        let Hide{
      #|          type tparam#4 _
      #|          val: bind value#9 val
      #|        } = var value#8 h
      #|        1
      #|      }
      #|    }
      #|  }
      #|}
    ),
  )
}

///|
test "report unresolved type and qualified variant diagnostics" {
  let file = expect_parse_ok(
    (
      #|enum Option {
      #|  none()
      #|}
      #|fn bad(value : Missing) -> Int {
      #|  Option::some(0)
      #|}
    ),
  )
  let result = resolve_source_file_result(file)
  inspect(
    @prettyprinter.render(result.diagnostics[0]),
    content="unresolved_type Missing",
  )
  inspect(
    @prettyprinter.render(result.diagnostics[1]),
    content="unresolved_variant Option::some",
  )
}

///|
test "resolve ambiguous unqualified variant calls" {
  let file = expect_parse_ok(
    (
      #|enum Left {
      #|  same(Int)
      #|}
      #|enum Right {
      #|  same(Int)
      #|}
      #|fn choose(value : Int) -> Int {
      #|  same(value)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(resolve_source_file(file), width=100),
    content=(
      #|resolved {
      #|  symbols {
      #|    types {
      #|      type#0 enum Left/0
      #|      type#1 enum Right/0
      #|    }
      #|    type_parameters {}
      #|    type_members {}
      #|    values {
      #|      value#0 top_function choose
      #|      value#1 parameter value
      #|    }
      #|    fields {}
      #|    variants {
      #|      variant#0 owner=type#0 same index=0 payloads=1
      #|      variant#1 owner=type#1 same index=0 payloads=1
      #|    }
      #|  }
      #|  declarations {
      #|    enum type#0 Left {
      #|      variant variant#0 same index=0 payloads=1(Int)
      #|    }
      #|    enum type#1 Right {
      #|      variant variant#1 same index=0 payloads=1(Int)
      #|    }
      #|    fn value#0 choose(value#1 value : Int) -> Int {
      #|      ?ambiguous same [variant#0, variant#1] same(var value#1 value)
      #|    }
      #|  }
      #|}
    ),
  )
  let result = resolve_source_file_result(file)
  inspect(
    @prettyprinter.render(result.diagnostics[0]),
    content="ambiguous_variant same [Left::same, Right::same]",
  )
}

///|
test "keep unknown calls as unresolved value calls" {
  let file = expect_parse_ok(
    (
      #|fn call_unknown(value : Int) -> Int {
      #|  missing(value)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(resolve_source_file(file), width=100),
    content=(
      #|resolved {
      #|  symbols {
      #|    types {}
      #|    type_parameters {}
      #|    type_members {}
      #|    values {
      #|      value#0 top_function call_unknown
      #|      value#1 parameter value
      #|    }
      #|    fields {}
      #|    variants {}
      #|  }
      #|  declarations {
      #|    fn value#0 call_unknown(value#1 value : Int) -> Int {
      #|      var ?missing missing(var value#1 value)
      #|    }
      #|  }
      #|}
    ),
  )
  let result = resolve_source_file_result(file)
  inspect(
    @prettyprinter.render(result.diagnostics[0]),
    content="unresolved_value missing",
  )
}

///|
test "resolve qualified field access when base type is known" {
  let file = expect_parse_ok(
    (
      #|struct Point {
      #|  x : Int
      #|  y : Int
      #|}
      #|fn get_x(point : Point) -> Int {
      #|  point.x
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(resolve_source_file(file), width=100),
    content=(
      #|resolved {
      #|  symbols {
      #|    types {
      #|      type#0 struct Point/0
      #|    }
      #|    type_parameters {}
      #|    type_members {}
      #|    values {
      #|      value#0 top_function get_x
      #|      value#1 parameter point
      #|    }
      #|    fields {
      #|      field#0 owner=type#0 x index=0
      #|      field#1 owner=type#0 y index=1
      #|    }
      #|    variants {}
      #|  }
      #|  declarations {
      #|    struct type#0 Point {
      #|      field field#0 x : Int index=0
      #|      field field#1 y : Int index=1
      #|    }
      #|    fn value#0 get_x(value#1 point : type#0 Point) -> Int {
      #|      var value#1 point.field#0 x
      #|    }
      #|  }
      #|}
    ),
  )
}

///|
test "report unresolved qualified field when base type is known" {
  let file = expect_parse_ok(
    (
      #|struct Point {
      #|  x : Int
      #|}
      #|fn get_z(point : Point) -> Int {
      #|  point.z
      #|}
    ),
  )
  let result = resolve_source_file_result(file)
  inspect(
    @prettyprinter.render(result.diagnostics[0]),
    content="unresolved_field Point.z",
  )
}

///|
test "resolve top level function bodies with complete top level values" {
  let file = expect_parse_ok(
    (
      #|struct Box {
      #|  value : Int
      #|}
      #|fn read_box() -> Int {
      #|  box.value
      #|}
      #|let box : Box = Box::{ value: 42 }
    ),
  )
  inspect(
    @prettyprinter.render(resolve_source_file_result(file), width=100),
    content=(
      #|resolve_result {
      #|  resolved {
      #|    symbols {
      #|      types {
      #|        type#0 struct Box/0
      #|      }
      #|      type_parameters {}
      #|      type_members {}
      #|      values {
      #|        value#0 top_function read_box
      #|        value#1 top_value box
      #|      }
      #|      fields {
      #|        field#0 owner=type#0 value index=0
      #|      }
      #|      variants {}
      #|    }
      #|    declarations {
      #|      struct type#0 Box {
      #|        field field#0 value : Int index=0
      #|      }
      #|      fn value#0 read_box() -> Int {
      #|        var value#1 box.field#0 value
      #|      }
      #|      let value#1 box : type#0 Box = Box::{
      #|        value: 42
      #|      }
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "resolve operator aliases through operation names" {
  let file = expect_parse_ok(
    (
      #|fn op_add(a : Int, b : Int) -> Int {
      #|  a
      #|}
      #|fn add(a : Int, b : Int) -> Int {
      #|  a + b
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(resolve_source_file(file), width=100),
    content=(
      #|resolved {
      #|  symbols {
      #|    types {}
      #|    type_parameters {}
      #|    type_members {}
      #|    values {
      #|      value#0 top_function op_add
      #|      value#1 top_function add
      #|      value#2 parameter a
      #|      value#3 parameter b
      #|      value#4 parameter a
      #|      value#5 parameter b
      #|    }
      #|    fields {}
      #|    variants {}
      #|  }
      #|  declarations {
      #|    fn value#0 op_add(value#2 a : Int, value#3 b : Int) -> Int {
      #|      var value#2 a
      #|    }
      #|    fn value#1 add(value#4 a : Int, value#5 b : Int) -> Int {
      #|      var value#4 a +[value#0] var value#5 b
      #|    }
      #|  }
      #|}
    ),
  )
}

///|
test "report unresolved operator operation name" {
  let file = expect_parse_ok(
    (
      #|fn add(a : Int, b : Int) -> Int {
      #|  a + b
      #|}
    ),
  )
  let result = resolve_source_file_result(file)
  inspect(
    @prettyprinter.render(result.diagnostics[0]),
    content="unresolved_value op_add",
  )
}
