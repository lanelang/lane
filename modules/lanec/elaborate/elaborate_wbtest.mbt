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
fn expect_parse_module_ok(source : String) -> @syntax.SourceFile {
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
fn checked_source_for_elaborate_test(
  source : String,
) -> @checked.CheckedSourceFile {
  let file = expect_parse_ok(source)
  let resolved = @resolve.resolve_source_file(file)
  let result = @typecheck.typecheck_checked_source_file(resolved)
  guard result.source is Some(source) else {
    abort(@prettyprinter.render(result.diagnostics, width=100))
  }
  source
}

///|
fn checked_module_for_elaborate_test(
  source : String,
  imported : @module_interface.ImportedEnvironment,
) -> @typecheck.CheckedSourceTypeCheckResult {
  let file = expect_parse_module_ok(source)
  let resolved = @resolve.resolve_source_file(file)
  @typecheck.typecheck_checked_source_file_with_imported_environment(
    resolved, imported,
  )
}

///|
fn lower_first_handler_for_elaborate_test(
  source_text : String,
) -> Array[LoweredHandlerTable] {
  let source = checked_source_for_elaborate_test(source_text)
  let lowerer = BuslaneLowerer::BuslaneLowerer()
  lowerer.collect_type_headers(source)
  lowerer.collect_data_constructors(source)
  lowerer.collect_field_selectors(source)
  guard first_checked_handler_for_elaborate_test(source)
    is Some((handlers, result_type)) else {
    abort("expected checked handler")
  }
  lowerer.lower_handler_tables_for_alternatives(handlers, result_type)
}

///|
fn first_checked_handler_for_elaborate_test(
  source : @checked.CheckedSourceFile,
) -> (Array[@checked.CheckedHandlerTable], @types.Type)? {
  for declaration in source.declarations {
    if declaration is Function(declaration) {
      if first_checked_handler_expr_for_elaborate_test(declaration.body)
        is Some(handler) {
        return Some(handler)
      }
    }
  }
  None
}

///|
fn first_checked_handler_expr_for_elaborate_test(
  expression : @checked.CheckedExpr,
) -> (Array[@checked.CheckedHandlerTable], @types.Type)? {
  match expression {
    Handler(handlers~, type_~, ..) => Some((handlers, type_))
    Block(items~, result~, ..) => {
      for item in items {
        match item {
          Let(declaration) =>
            if first_checked_handler_expr_for_elaborate_test(
                declaration.initializer,
              )
              is Some(handler) {
              return Some(handler)
            }
          PatternLet(declaration) =>
            if first_checked_handler_expr_for_elaborate_test(
                declaration.initializer,
              )
              is Some(handler) {
              return Some(handler)
            }
          Function(declaration) =>
            if first_checked_handler_expr_for_elaborate_test(declaration.body)
              is Some(handler) {
              return Some(handler)
            }
        }
      }
      first_checked_handler_expr_for_elaborate_test(result)
    }
    If(condition~, then_branch~, else_branch~, ..) =>
      match first_checked_handler_expr_for_elaborate_test(condition) {
        Some(handler) => Some(handler)
        None =>
          match first_checked_handler_expr_for_elaborate_test(then_branch) {
            Some(handler) => Some(handler)
            None => first_checked_handler_expr_for_elaborate_test(else_branch)
          }
      }
    Match(scrutinee~, arms~, ..) =>
      match first_checked_handler_expr_for_elaborate_test(scrutinee) {
        Some(handler) => Some(handler)
        None => {
          for arm in arms {
            if first_checked_handler_expr_for_elaborate_test(arm.body)
              is Some(handler) {
              return Some(handler)
            }
          }
          None
        }
      }
    Call(callee~, arguments~, ..) => {
      if first_checked_handler_expr_for_elaborate_test(callee) is Some(handler) {
        return Some(handler)
      }
      for argument in arguments {
        if first_checked_handler_expr_for_elaborate_test(argument)
          is Some(handler) {
          return Some(handler)
        }
      } nobreak {
        None
      }
    }
    TypeApplication(callee~, ..) =>
      first_checked_handler_expr_for_elaborate_test(callee)
    OperationCall(arguments~, ..) | Variant(arguments~, ..) =>
      for argument in arguments {
        if first_checked_handler_expr_for_elaborate_test(argument)
          is Some(handler) {
          return Some(handler)
        }
      } nobreak {
        None
      }
    Field(base~, ..) => first_checked_handler_expr_for_elaborate_test(base)
    StructLiteral(fields~, ..) =>
      for field in fields {
        if first_checked_handler_expr_for_elaborate_test(field.value)
          is Some(handler) {
          return Some(handler)
        }
      } nobreak {
        None
      }
    Literal(..) | Value(..) | UnsafeBuiltin(..) | FunctionLiteral(..) => None
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
test "elaborate lowers handler payload binders before alternatives" {
  let tables = lower_first_handler_for_elaborate_test(
    (
      #|enum Choice {
      #|  left
      #|  right
      #|}
      #|effect Console {
      #|  write(String) -> Int
      #|  choose(Choice) -> Int
      #|}
      #|fn program() -> Int {
      #|  handle Console::write!("hi") with {
      #|    Console::write(message, resume) => 0
      #|    Console::choose(Choice::left, resume2) => 1
      #|    Console::choose(_, resume3) => 2
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(tables.length(), content="1")
  inspect(tables[0].operations.length(), content="2")
  inspect(tables[0].operations[0].payload_binders.length(), content="1")
  inspect(tables[0].operations[1].payload_binders.length(), content="1")
  inspect(
    @prettyprinter.render(tables[0].operations[0].body, width=100),
    content=(
      #|let value#2 = value#0 in
      #|0
    ),
  )
  inspect(
    @prettyprinter.render(tables[0].operations[1].body, width=100),
    content=(
      #|match value#3 as value#3 -> Int {
      #|  datacon#0() => 1
      #|  _ => 2
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
test "buslane lowering registry covers nominal and effect declarations" {
  let source = checked_source_for_elaborate_test(
    (
      #|pub struct Box {
      #|  value : Int
      #|}
      #|pub effect Console {
      #|  read() -> Int
      #|}
      #|pub fn read_int() -> Int ! Console {
      #|  Console::read!()
      #|}
    ),
  )
  let objects = lower_checked_source_files_to_buslane_objects([source])
  guard objects.objects.get(0) is Some(object) else {
    abort("expected lowered object")
  }
  assert_eq(object.metadata.types.length(), 1)
  assert_eq(object.metadata.data_constructors.length(), 1)
  assert_eq(object.metadata.effects.length(), 1)
  assert_eq(object.metadata.operations.length(), 1)
  guard object.exports.any(fn(item) {
    item.kind is Type && item.type_id is Some(_)
  }) else {
    abort("expected type export")
  }
  guard object.exports.any(fn(item) {
    item.kind is Effect && item.effect_id is Some(_)
  }) else {
    abort("expected effect export")
  }
  guard object.exports.any(fn(item) {
    item.kind is Operation && item.operation is Some(_)
  }) else {
    abort("expected operation export")
  }
}

///|
test "buslane lowering registry covers imported references" {
  let lib = checked_module_for_elaborate_test(
    (
      #|module Lib
      #|pub struct Box {
      #|  value : Int
      #|}
      #|pub effect Console {
      #|  read() -> Int
      #|}
      #|pub fn read_int() -> Int ! Console {
      #|  Console::read!()
      #|}
    ),
    { modules: [] },
  )
  if lib.diagnostics.length() != 0 {
    abort(@prettyprinter.render(lib.diagnostics, width=100))
  }
  guard lib.source is Some(_) else { abort("expected checked lib") }
  guard lib.module_interface is Some(lib_interface) else {
    abort("expected lib interface")
  }
  let imported : @module_interface.ImportedEnvironment = {
    modules: [lib_interface],
  }
  let main = checked_module_for_elaborate_test(
    (
      #|module Main
      #|pub let answer : Int = 1
    ),
    imported,
  )
  if main.diagnostics.length() != 0 {
    abort(@prettyprinter.render(main.diagnostics, width=100))
  }
  guard main.source is Some(main_source) else { abort("expected checked main") }
  let object = lower_checked_source_file_to_buslane_object_with_imports(
    main_source, imported,
  )
  guard object.imports.any(fn(item) {
    item.kind is Type && item.type_id is Some(_)
  }) else {
    abort("expected imported type")
  }
  guard object.imports.any(fn(item) {
    item.kind is FieldSelector && item.value is Some(_)
  }) else {
    abort("expected imported field selector")
  }
  guard object.imports.any(fn(item) {
    item.kind is Effect && item.effect_id is Some(_)
  }) else {
    abort("expected imported effect")
  }
  guard object.imports.any(fn(item) {
    item.kind is Operation && item.operation is Some(_)
  }) else {
    abort("expected imported operation")
  }
  guard object.imports.any(fn(item) {
    item.kind is Value && item.value is Some(_)
  }) else {
    abort("expected imported value")
  }
}

///|
test "elaborate lowers effect metadata into buslane metadata" {
  let result = elaborate_buslane_source(
    (
      #|pub effect State[S] {
      #|  get() -> S
      #|  put(S) -> Unit
      #|}
      #|let answer : Int = 1
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|buslane_elaborate_result {
      #|  buslane {
      #|    metadata {
      #|      type_parameter tparam#0 : Type
      #|      value value#0 : Int
      #|      effect effect#0[tparam#0] {
      #|        operation#0() -> tparam#0
      #|        operation#1(tparam#0) -> Unit
      #|      }
      #|    }
      #|    let value#0 = 1
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "elaborate lowers latent effects into buslane function types" {
  let result = elaborate_buslane_source(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|fn run_console(f : () -> Int ! Console) -> Int ! Console {
      #|  f()
      #|}
      #|fn[E : Effect] run_row(f : () -> Unit ! E) -> Unit ! E {
      #|  f()
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
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|buslane_elaborate_result {
      #|  buslane {
      #|    metadata {
      #|      type_parameter tparam#0 : Effect
      #|      function value#0 : (() -> Int ! effect#0) -> Int ! effect#0
      #|      function value#1 : forall [tparam#0]. (() -> Unit ! tparam#0) -> Unit ! tparam#0
      #|      parameter value#2 : () -> Int ! effect#0
      #|      parameter value#3 : () -> Unit ! tparam#0
      #|      effect effect#0 {
      #|        operation#0() -> Int
      #|      }
      #|    }
      #|    letrec {
      #|      value#0 = fn(value#2) -> Int {
      #|        value#2()
      #|      }
      #|      value#1 = fn[tparam#0] {
      #|        fn(value#3) -> Unit {
      #|          value#3()
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
test "elaborate lowers operation calls into buslane perform" {
  let result = elaborate_buslane_source(
    (
      #|effect Console {
      #|  write(String) -> Unit
      #|}
      #|effect State[S] {
      #|  get() -> S
      #|}
      #|fn write_hello() -> Unit ! Console {
      #|  Console::write!("hi")
      #|}
      #|fn read_int() -> Int ! State[Int] {
      #|  State[Int]::get!()
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
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|buslane_elaborate_result {
      #|  buslane {
      #|    metadata {
      #|      type_parameter tparam#0 : Type
      #|      function value#0 : () -> Unit ! effect#0
      #|      function value#1 : () -> Int ! effect#1[Int]
      #|      effect effect#0 {
      #|        operation#0(String) -> Unit
      #|      }
      #|      effect effect#1[tparam#0] {
      #|        operation#1() -> tparam#0
      #|      }
      #|    }
      #|    letrec {
      #|      value#0 = fn() -> Unit {
      #|        perform operation#0("hi")
      #|      }
      #|      value#1 = fn() -> Int {
      #|        perform operation#1[Int]()
      #|      }
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "elaborate lowers handlers into buslane handler tables" {
  let result = elaborate_buslane_source(
    (
      #|effect Console {
      #|  choose(Bool) -> Int
      #|}
      #|fn program() -> Int {
      #|  handle Console::choose!(true) with {
      #|    Console::choose(true, resume) => resume(10)
      #|    Console::choose(_, resume2) => 2
      #|  } final value {
      #|    value
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
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|buslane_elaborate_result {
      #|  buslane {
      #|    metadata {
      #|      function value#0 : () -> Int
      #|      match_binder value#1 : Int
      #|      parameter value#2 : Bool
      #|      parameter value#3 : (Int) -> Int
      #|      effect effect#0 {
      #|        operation#0(Bool) -> Int
      #|      }
      #|    }
      #|    letrec {
      #|      value#0 = fn() -> Int {
      #|        handle perform operation#0(true) as value#1 -> Int {
      #|          effect#0 {
      #|            operation#0(value#2) resume value#3 => match value#2 as value#2 -> Int {
      #|              true => value#3(10)
      #|              _ => 2
      #|            }
      #|          }
      #|          final => value#1
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
test "elaborate higher-kinded struct parameters into verifiable buslane" {
  let result = elaborate_buslane_source(
    (
      #|enum Option[A] {
      #|  none
      #|  some(A)
      #|}
      #|struct Mappable[F : [Type] -> Type] {
      #|  map : [A, B]((A) -> B, F[A]) -> F[B]
      #|}
      #|fn[A, B] option_map(f : (A) -> B, option : Option[A]) -> Option[B] {
      #|  match option {
      #|    Option::none => Option::none
      #|    Option::some(inner) => Option::some(f(inner))
      #|  }
      #|}
      #|let option_mappable : Mappable[Option] = Mappable::{ map: option_map }
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
test "elaborate nested patterns into verifiable buslane decision tree" {
  let result = elaborate_buslane_source(
    (
      #|enum Option[A] {
      #|  none
      #|  some(A)
      #|}
      #|struct Box[A] {
      #|  value : A
      #|}
      #|fn flatten(value : Option[Option[Int]]) -> Int {
      #|  match value {
      #|    Option::none => 0
      #|    Option::some(Option::none) => 1
      #|    Option::some(Option::some(x)) => x
      #|  }
      #|}
      #|fn boxed(value : Box[Option[Int]]) -> Int {
      #|  match value {
      #|    Box::{ value: Option::none } => 0
      #|    Box::{ value: Option::some(x) } => x
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
test "elaborate existential enum construction into verifiable buslane" {
  let result = elaborate_buslane_source(
    (
      #|enum Packed {
      #|  hide[T](T)
      #|}
      #|let packed : Packed = Packed::hide[Int](1)
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
test "elaborate existential enum repack into verifiable buslane" {
  let result = elaborate_buslane_source(
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
