///|
priv struct BuslaneLoweringTestResult {
  program : @buslane.Program?
  diagnostics : Array[@typecheck.TypeCheckDiagnostic]
}

///|
fn elaborate_buslane_source(source : String) -> BuslaneLoweringTestResult {
  let file = expect_parse_ok(source)
  let resolution = @resolve.resolve_source_file_result(file)
  if !resolution.diagnostics.is_empty() {
    abort(@prettyprinter.render(resolution.diagnostics, width=100))
  }
  let resolved = resolution.source
  let result = @typecheck.typecheck_checked_source_file(resolved)
  let program = match result.source {
    Some(source) => Some(lower_checked_source_file_to_buslane(source))
    None => None
  }
  { program, diagnostics: result.diagnostics }
}

///|
impl @prettyprinter.Pretty for BuslaneLoweringTestResult with fn pretty(
  result : BuslaneLoweringTestResult,
) {
  let program = match result.program {
    Some(program) => program.pretty()
    None => @prettyprinter.text("<no buslane program>")
  }
  @prettyprinter.text("buslane_elaborate_result") +
  @prettyprinter.space +
  @pretty.braced_block([
    program,
    @pretty.section(
      "diagnostics",
      result.diagnostics.map(@typecheck.TypeCheckDiagnostic::pretty),
    ),
  ])
}

///|
fn expect_parse_ok(source : String) -> @syntax.SourceFile {
  let result = @parser.parse_string("module Test\n" + source)
  if !result.lexical_errors().is_empty() || !result.parse_errors().is_empty() {
    abort("expected parse success")
  }
  guard result.syntax() is Some(file) else { abort("expected source file") }
  file
}

///|
fn expect_parse_module_ok(source : String) -> @syntax.SourceFile {
  let result = @parser.parse_string(source)
  if !result.lexical_errors().is_empty() || !result.parse_errors().is_empty() {
    abort("expected parse success")
  }
  guard result.syntax() is Some(file) else { abort("expected source file") }
  file
}

///|

///|
fn checked_source_for_elaborate_test(
  source : String,
) -> @checked.CheckedSourceFile {
  let file = expect_parse_ok(source)
  let resolution = @resolve.resolve_source_file_result(file)
  if !resolution.diagnostics.is_empty() {
    abort(@prettyprinter.render(resolution.diagnostics, width=100))
  }
  let resolved = resolution.source
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
  let resolution = @resolve.resolve_source_file_result(file)
  if !resolution.diagnostics.is_empty() {
    abort(@prettyprinter.render(resolution.diagnostics, width=100))
  }
  let resolved = resolution.source
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
priv struct BuslaneLoweringShape {
  types : Int
  effects : Int
  operations : Int
  values : Int
  data_constructors : Int
  mut top_lets : Int
  mut top_let_recs : Int
  mut top_externals : Int
  mut calls : Int
  mut type_lambdas : Int
  mut type_applications : Int
  mut constructs : Int
  mut construct_hidden_witnesses : Int
  mut matches : Int
  mut performs : Int
  mut perform_effect_arguments : Int
  mut perform_hidden_witnesses : Int
  mut handles : Int
  mut resumes : Int
} derive(Debug)

///|
fn BuslaneLoweringShape::from_program(
  program : @buslane.Program,
) -> BuslaneLoweringShape {
  let shape = {
    types: program.metadata.types.length(),
    effects: program.metadata.effects.length(),
    operations: program.metadata.operations.length(),
    values: program.metadata.values.length(),
    data_constructors: program.metadata.data_constructors.length(),
    top_lets: 0,
    top_let_recs: 0,
    top_externals: 0,
    calls: 0,
    type_lambdas: 0,
    type_applications: 0,
    constructs: 0,
    construct_hidden_witnesses: 0,
    matches: 0,
    performs: 0,
    perform_effect_arguments: 0,
    perform_hidden_witnesses: 0,
    handles: 0,
    resumes: 0,
  }
  shape.add_terms(program.terms)
  shape
}

///|
fn BuslaneLoweringShape::add_terms(
  self : BuslaneLoweringShape,
  terms : Array[@buslane.TopTerm],
) -> Unit {
  for term in terms {
    match term {
      Let(_, body) => {
        self.top_lets += 1
        self.add_expr(body)
      }
      LetRec(bindings) => {
        self.top_let_recs += 1
        for binding in bindings {
          self.add_expr(binding.rhs)
        }
      }
      External(_) => self.top_externals += 1
    }
  }
}

///|
fn BuslaneLoweringShape::add_expr(
  self : BuslaneLoweringShape,
  expression : @buslane.Expr,
) -> Unit {
  match expression {
    Ref(_) | Literal(_) | Resume(_) => ()
    Function(function) => self.add_expr(function.body)
    Call(callee, arguments) => {
      self.calls += 1
      self.add_expr(callee)
      for argument in arguments {
        self.add_expr(argument)
      }
    }
    TypeLambda(_, body) => {
      self.type_lambdas += 1
      self.add_expr(body)
    }
    TypeApply(callee, _) => {
      self.type_applications += 1
      self.add_expr(callee)
    }
    Construct(construct) => {
      self.constructs += 1
      self.construct_hidden_witnesses += construct.hidden_witnesses.length()
      for payload in construct.payloads {
        self.add_expr(payload)
      }
    }
    Let(_, initializer, body) => {
      self.add_expr(initializer)
      self.add_expr(body)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        self.add_expr(binding.rhs)
      }
      self.add_expr(body)
    }
    Match(match_) => {
      self.matches += 1
      self.add_expr(match_.scrutinee)
      for alternative in match_.alternatives {
        self.add_expr(alternative.body)
      }
    }
    Perform(perform) => {
      self.performs += 1
      self.perform_effect_arguments += perform.effect_arguments.length()
      self.perform_hidden_witnesses += perform.hidden_witnesses.length()
      for payload in perform.payloads {
        self.add_expr(payload)
      }
    }
    Handle(handle) => {
      self.handles += 1
      self.add_expr(handle.body)
      self.add_expr(handle.final_body)
      for table in handle.handlers {
        for operation in table.operations {
          self.add_expr(operation.body)
          self.resumes += 1
        }
      }
    }
  }
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
        if first_checked_handler_expr_for_elaborate_test(argument.value)
          is Some(handler) {
          return Some(handler)
        }
      } nobreak {
        None
      }
    }
    GenericApplication(callee~, ..) =>
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
    Literal(..)
    | Value(..)
    | CompilerIntrinsic(..)
    | ExternBinding(..)
    | FunctionLiteral(..) => None
  }
}

///|
test "pre-buslane lowering contract covers source-only forms and witnesses" {
  let result = elaborate_buslane_source(
    (
      #|struct Add[A] {
      #|  add : (A, A) -> A
      #|}
      #|fn[A] op_add(a : A, b : A, auto op : Add[A]) -> A {
      #|  op.add(a, b)
      #|}
      #|offer int_add_ops : Add[Int] = Add::{ add: fn(a : Int, b : Int) -> Int { builtin("%i64_add")(a, b) } }
      #|let external_int : () -> Int = extern("%external_int")
      #|struct Box[A] {
      #|  value : A
      #|}
      #|struct Cell {
      #|  value : Int
      #|}
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|enum Packed {
      #|  hide[A](A)
      #|}
      #|effect Prompt {
      #|  choose[A](A, A) -> A
      #|}
      #|type PromptOnly = { Prompt }
      #|fn[A] id(value : A) -> A {
      #|  value
      #|}
      #|fn use_prompt() -> Int ! PromptOnly {
      #|  Prompt::choose![Int](1, 2)
      #|}
      #|let packed : Packed = Packed::hide[Int](1)
      #|fn answer() -> Int {
      #|  handle {
      #|    let Cell::{ value } = Cell::{ value: 1 + 2 }
      #|    let piped : Int = value |> id[Int]
      #|    let chosen : Int = Prompt::choose![Int](piped, 4)
      #|    if true {
      #|      match Option::some(chosen) {
      #|        Option::some(result) => Box[Int]::{ value: result }.value
      #|        Option::none() => 0
      #|      }
      #|    } else {
      #|      external_int()
      #|    }
      #|  } with {
      #|    Prompt::choose[T](left, right, resume) => resume(left)
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  guard result.program is Some(program) else {
    abort(@prettyprinter.render(result.diagnostics, width=100))
  }
  debug_inspect(@buslane.verify_program(program), content="{ diagnostics: [] }")
  debug_inspect(
    BuslaneLoweringShape::from_program(program),
    content=(
      #|{
      #|  types: 5,
      #|  effects: 1,
      #|  operations: 1,
      #|  values: 42,
      #|  data_constructors: 6,
      #|  top_lets: 6,
      #|  top_let_recs: 1,
      #|  top_externals: 2,
      #|  calls: 8,
      #|  type_lambdas: 4,
      #|  type_applications: 4,
      #|  constructs: 5,
      #|  construct_hidden_witnesses: 1,
      #|  matches: 6,
      #|  performs: 2,
      #|  perform_effect_arguments: 0,
      #|  perform_hidden_witnesses: 2,
      #|  handles: 1,
      #|  resumes: 1,
      #|}
    ),
  )
}

///|
test "elaborate lowers handler payload binders before alternatives" {
  let tables = lower_first_handler_for_elaborate_test(
    (
      #|enum Choice {
      #|  left()
      #|  right()
      #|}
      #|effect Console {
      #|  write(String) -> Int
      #|  choose(Choice) -> Int
      #|}
      #|fn program() -> Int {
      #|  handle Console::write!("hi") with {
      #|    Console::write(message, resume) => 0
      #|    Console::choose(Choice::left(), resume2) => 1
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
      #|      function identity#0 : (Int) -> Int
      #|      value answer#1 : Int
      #|      parameter x#2 : Int
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
      #|  none()
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
  if !lib.diagnostics.is_empty() {
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
  if !main.diagnostics.is_empty() {
    abort(@prettyprinter.render(main.diagnostics, width=100))
  }
  guard main.source is Some(main_source) else { abort("expected checked main") }
  let object = lower_checked_source_file_to_buslane_object_with_imports(
    main_source,
    { direct: imported, available: imported },
  )
  guard object is Ok(object) else { abort("expected imported lowering") }
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
      #|      type_parameter S#0 : Type
      #|      value answer#4 : Int
      #|      effect State#1[tparam#0] {
      #|        get#2() -> tparam#0
      #|        put#3(tparam#0) -> Unit
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
      #|      type_parameter E#3 : Effect
      #|      function run_console#2 : (() -> Int ! effect#0) -> Int ! effect#0
      #|      function run_row#4 : forall [tparam#0]. (() -> Unit ! tparam#0) -> Unit ! tparam#0
      #|      parameter f#5 : () -> Int ! effect#0
      #|      parameter f#6 : () -> Unit ! tparam#0
      #|      effect Console#0 {
      #|        read#1() -> Int
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
      #|      type_parameter S#1 : Type
      #|      function write_hello#5 : () -> Unit ! effect#0
      #|      function read_int#6 : () -> Int ! effect#1[Int]
      #|      effect Console#0 {
      #|        write#3(String) -> Unit
      #|      }
      #|      effect State#2[tparam#0] {
      #|        get#4() -> tparam#0
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
      #|      function program#2 : () -> Int
      #|      match_binder value#3 : Int
      #|      parameter payload#4 : Bool
      #|      parameter resume#5 : (Int) -> Int
      #|      effect Console#0 {
      #|        choose#1(Bool) -> Int
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
      #|  none()
      #|  some(A)
      #|}
      #|struct Mappable[F : [Type] -> Type] {
      #|  map : [A, B]((A) -> B, F[A]) -> F[B]
      #|}
      #|fn[A, B] option_map(f : (A) -> B, option : Option[A]) -> Option[B] {
      #|  match option {
      #|    Option::none() => Option::none()
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
      #|  none()
      #|  some(A)
      #|}
      #|fn choose(value : Option[Int], fallback : Int) -> Int {
      #|  match value {
      #|    Option::none() => fallback
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
      #|  none()
      #|  some(A)
      #|}
      #|struct Box[A] {
      #|  value : A
      #|}
      #|fn flatten(value : Option[Option[Int]]) -> Int {
      #|  match value {
      #|    Option::none() => 0
      #|    Option::some(Option::none()) => 1
      #|    Option::some(Option::some(x)) => x
      #|  }
      #|}
      #|fn boxed(value : Box[Option[Int]]) -> Int {
      #|  match value {
      #|    Box::{ value: Option::none() } => 0
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
