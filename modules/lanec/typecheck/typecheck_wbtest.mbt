///|
fn expect_parse_ok(source : String) -> @syntax.SourceFile {
  let result = @parser.parse_string("module Test\n" + source)
  if !result.lexical_errors.is_empty() || !result.parse_errors.is_empty() {
    abort("expected parse success: " + parse_error_summary(result.parse_errors))
  }
  guard result.source is Some(file) else { abort("expected source file") }
  file
}

///|
fn parse_error_summary(errors : Array[@parser.ParseError]) -> String {
  if errors.is_empty() {
    return "no parse errors"
  }
  let error = errors[0]
  match error.kind {
    UnexpectedToken(actual, expected) =>
      "unexpected " +
      actual.label +
      " expected " +
      expected.map(fn(item) { item.label }).join(",")
    UnexpectedEndOfInput(expected) =>
      "unexpected eof expected " +
      expected.map(fn(item) { item.label }).join(",")
  }
}

///|
fn expect_declaration_typecheck_result(
  source : String,
) -> DeclarationTypeCheckResult {
  let file = expect_parse_ok(source)
  let resolved = @resolve.resolve_source_file(file)
  typecheck_declarations(resolved)
}

///|
fn expect_typecheck_result(source : String) -> TypeCheckResult {
  let file = expect_parse_ok(source)
  let resolved = @resolve.resolve_source_file(file)
  typecheck_source_file(resolved)
}

///|
fn expect_checked_source_result(
  source : String,
) -> CheckedSourceTypeCheckResult {
  let file = expect_parse_ok(source)
  let resolved = @resolve.resolve_source_file(file)
  typecheck_checked_source_file(resolved)
}

///|
fn checked_function_effect(
  result : TypeCheckResult,
  name : String,
) -> @types.Effect {
  for value in result.values.values {
    if value is Function(declaration) && declaration.name == name {
      guard declaration.type_ is Function(_, _, effect) else {
        abort("expected function type")
      }
      return effect
    }
  }
  abort("expected function " + name)
}

///|
fn expect_checked_let_initializer(
  source : String,
  name : String,
  expected : @types.Type,
) -> @checked.CheckedExpr {
  let file = expect_parse_ok(source)
  let resolved = @resolve.resolve_source_file(file)
  let declaration_result = typecheck_declarations(resolved)
  let source = @desugar.desugar_source_file(resolved)
  let checker = SemanticChecker::{
    resolved_source: resolved,
    source,
    imported_environment: empty_imported_environment(),
    declarations: declaration_result.declarations,
    diagnostics: declaration_result.diagnostics.copy(),
    values: [],
    value_types: [],
    ordered_value_types: [],
    offers: [],
    ordered_offers: [],
  }
  checker.collect_top_level_value_types()
  for declaration in source.declarations {
    match declaration {
      Let(declaration) =>
        if declaration.name == Some(name) {
          let checked = checker.check_checked_expr(
            checker.root_scope(),
            declaration.initializer,
            expected,
          )
          guard checked.expression is Some(expression) else {
            abort(@prettyprinter.render(checker.diagnostics, width=100))
          }
          return expression
        } else {
          checker.check_top_level_let(declaration)
        }
      Offer(declaration) => checker.check_top_level_offer(declaration)
      _ => ()
    }
  }
  abort("expected named let")
}

///|
fn expect_first_handler_resume_callee_type(source : String) -> @types.Type {
  let result = expect_checked_source_result(source)
  guard result.source is Some(source_file) else {
    abort(@prettyprinter.render(result.diagnostics, width=100))
  }
  for declaration in source_file.declarations {
    if declaration is Function(declaration) {
      if find_first_handler_resume_callee_type(declaration.body) is Some(type_) {
        return type_
      }
    }
  }
  abort("expected handler resume call")
}

///|
fn find_first_handler_resume_callee_type(
  expression : @checked.CheckedExpr,
) -> @types.Type? {
  match expression {
    Handler(handlers~, ..) =>
      for handler in handlers {
        for operation in handler.operations {
          if operation.body is Some(body) {
            if find_first_handler_resume_callee_type(body) is Some(type_) {
              return Some(type_)
            }
          }
        }
      } nobreak {
        None
      }
    Call(callee~, arguments~, ..) => {
      if callee is Value(type_~, ..) {
        return Some(type_)
      }
      if find_first_handler_resume_callee_type(callee) is Some(type_) {
        return Some(type_)
      }
      for argument in arguments {
        if find_first_handler_resume_callee_type(argument) is Some(type_) {
          return Some(type_)
        }
      } nobreak {
        None
      }
    }
    Block(items~, result~, ..) => {
      for item in items {
        match item {
          Let(declaration) =>
            if find_first_handler_resume_callee_type(declaration.initializer)
              is Some(type_) {
              return Some(type_)
            }
          PatternLet(declaration) =>
            if find_first_handler_resume_callee_type(declaration.initializer)
              is Some(type_) {
              return Some(type_)
            }
          Function(declaration) =>
            if find_first_handler_resume_callee_type(declaration.body)
              is Some(type_) {
              return Some(type_)
            }
        }
      }
      find_first_handler_resume_callee_type(result)
    }
    If(condition~, then_branch~, else_branch~, ..) =>
      match find_first_handler_resume_callee_type(condition) {
        Some(type_) => Some(type_)
        None =>
          match find_first_handler_resume_callee_type(then_branch) {
            Some(type_) => Some(type_)
            None => find_first_handler_resume_callee_type(else_branch)
          }
      }
    Match(scrutinee~, arms~, ..) =>
      match find_first_handler_resume_callee_type(scrutinee) {
        Some(type_) => Some(type_)
        None => {
          for arm in arms {
            if find_first_handler_resume_callee_type(arm.body) is Some(type_) {
              return Some(type_)
            }
          }
          None
        }
      }
    TypeApplication(callee~, ..) =>
      find_first_handler_resume_callee_type(callee)
    OperationCall(arguments~, ..) | Variant(arguments~, ..) =>
      for argument in arguments {
        if find_first_handler_resume_callee_type(argument) is Some(type_) {
          return Some(type_)
        }
      } nobreak {
        None
      }
    Field(base~, ..) => find_first_handler_resume_callee_type(base)
    StructLiteral(fields~, ..) =>
      for field in fields {
        if find_first_handler_resume_callee_type(field.value) is Some(type_) {
          return Some(type_)
        }
      } nobreak {
        None
      }
    Literal(..) | Value(..) | UnsafeBuiltin(..) | FunctionLiteral(..) => None
  }
}

///|
fn expect_first_checked_match_pattern(
  source : String,
  name : String,
) -> @checked.CheckedPattern {
  let file = expect_parse_ok(source)
  let resolved = @resolve.resolve_source_file(file)
  let declaration_result = typecheck_declarations(resolved)
  let source = @desugar.desugar_source_file(resolved)
  let checker = SemanticChecker::{
    resolved_source: resolved,
    source,
    imported_environment: empty_imported_environment(),
    declarations: declaration_result.declarations,
    diagnostics: declaration_result.diagnostics.copy(),
    values: [],
    value_types: [],
    ordered_value_types: [],
    offers: [],
    ordered_offers: [],
  }
  checker.collect_top_level_value_types()
  for declaration in source.declarations {
    if declaration is Function(declaration) && declaration.name == name {
      let scope = checker.root_scope()
      for parameter in declaration.parameters {
        scope.bind(parameter.symbol, checker.check_type(parameter.type_))
      }
      let body = match declaration.body {
        Block(items=[], result~, ..) => result
        _ => declaration.body
      }
      guard body is Match(scrutinee~, arms~, ..) else {
        abort("expected match body")
      }
      guard !arms.is_empty() else { abort("expected match arm") }
      let scrutinee_type = checker.synthesize_expr(scope, scrutinee)
      let arm_scope = scope.copy()
      return checker.check_match_pattern(
        arm_scope,
        arms[0].pattern,
        scrutinee_type,
      )
    }
  }
  abort("expected function")
}

///|
test "typecheck custom type declaration environment" {
  let result = expect_declaration_typecheck_result(
    (
      #|struct Box[A] {
      #|  value : A
      #|}
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|struct Uses {
      #|  boxed : Box[Int]
      #|  option : Option[String]
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|declaration_typecheck_result {
      #|  checked_declarations {
      #|    types {
      #|      struct Box#0[A#0 : Type] {
      #|        value#0 : tparam#0
      #|      }
      #|      enum Option#1[A#1 : Type] {
      #|        none#0
      #|        some#1(tparam#1)
      #|      }
      #|      struct Uses#2 {
      #|        boxed#1 : type#0[Int]
      #|        option#2 : type#1[String]
      #|      }
      #|    }
      #|    type_members {}
      #|    fields {
      #|      value#0 : tparam#0
      #|      boxed#1 : type#0[Int]
      #|      option#2 : type#1[String]
      #|    }
      #|    variants {
      #|      none#0
      #|      some#1(tparam#1)
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck preserves existential declaration metadata" {
  let result = expect_declaration_typecheck_result(
    (
      #|struct HideF {
      #|  type F : [Type] -> Type
      #|  val : F[Int]
      #|}
      #|enum Packed {
      #|  hide[T](T)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|declaration_typecheck_result {
      #|  checked_declarations {
      #|    types {
      #|      struct HideF#0 {
      #|        type F#0 : [Type] -> Type
      #|        val#0 : tparam#0[Int]
      #|      }
      #|      enum Packed#1 {
      #|        hide#0[T#1 : Type](tparam#1)
      #|      }
      #|    }
      #|    type_members {
      #|      type F#0 : [Type] -> Type
      #|    }
      #|    fields {
      #|      val#0 : tparam#0[Int]
      #|    }
      #|    variants {
      #|      hide#0[T#1 : Type](tparam#1)
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck effect declaration environment and public interface" {
  let result = expect_declaration_typecheck_result(
    (
      #|pub effect State[S] {
      #|  get() -> S
      #|  put(S) -> Unit
      #|}
      #|effect Console {
      #|  write(String) -> Unit
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|declaration_typecheck_result {
      #|  checked_declarations {
      #|    types {}
      #|    type_members {}
      #|    fields {}
      #|    variants {}
      #|    effects {
      #|      effect effect#0 State[S#0 : Type] {
      #|        operation operation#0 get -> tparam#0
      #|        operation operation#1 put(tparam#0) -> Unit
      #|      }
      #|      effect effect#1 Console {
      #|        operation operation#2 write(String) -> Unit
      #|      }
      #|    }
      #|    operations {
      #|      operation operation#0 get -> tparam#0
      #|      operation operation#1 put(tparam#0) -> Unit
      #|      operation operation#2 write(String) -> Unit
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
  let checked = expect_checked_source_result(
    (
      #|pub effect State[S] {
      #|  get() -> S
      #|  put(S) -> Unit
      #|}
      #|effect Console {
      #|  write(String) -> Unit
      #|}
    ),
  )
  guard checked.module_interface is Some(interface) else {
    abort("expected module interface")
  }
  inspect(
    module_interface_effect_signatures(interface),
    content="State[1]{get/0->tparam#0,put/1->Unit}",
  )
}

///|
fn module_interface_effect_signatures(
  interface : @module_interface.ModuleInterface,
) -> String {
  interface.effects
  .map(fn(effect) {
    let operations = effect.operations
      .map(fn(operation) {
        let result = @prettyprinter.render(operation.result.pretty(), width=100)
        "\{operation.name}/\{operation.payload.length()}->\{result}"
      })
      .join(",")
    "\{effect.name}[\{effect.type_parameters.length()}]{\{operations}}"
  })
  .join(";")
}

///|
test "typecheck builds checked builtin from direct expected type" {
  let expression = expect_checked_let_initializer(
    (
      #|let host_value : Int = builtin("%host_value")
    ),
    "host_value",
    Primitive(Int),
  )
  inspect(
    @prettyprinter.render(expression),
    content=(
      #|builtin("%host_value") : Int
    ),
  )
}

///|
test "typecheck builds checked builtin call from expected result" {
  let expression = expect_checked_let_initializer(
    (
      #|let sum : Int = builtin("%i64_add")(1, 2)
    ),
    "sum",
    Primitive(Int),
  )
  inspect(
    @prettyprinter.render(expression),
    content=(
      #|builtin("%i64_add")(1, 2) : Int
    ),
  )
}

///|
test "typecheck builtin primitive operation fragment" {
  let result = expect_checked_source_result(
    (
      #|struct Add[T] {
      #|  add : (T, T) -> T
      #|}
      #|
      #|fn[T] op_add(a : T, b : T, auto op : Add[T]) -> T {
      #|  op.add(a, b)
      #|}
      #|
      #|fn int_add(a : Int, b : Int) -> Int {
      #|  builtin("%i64_add")(a, b)
      #|}
      #|
      #|offer int_add_ops : Add[Int] = Add::{ add: int_add }
      #|
      #|let sum : Int = op_add(1, 2)
    ),
  )
  inspect(result.diagnostics.length(), content="0")
  guard result.source is Some(_) else {
    abort("expected checked builtin fragment")
  }
}

///|
test "typecheck parses checked int literal as i64 value" {
  let expression = expect_checked_let_initializer(
    (
      #|let answer : Int = 042
    ),
    "answer",
    Primitive(Int),
  )
  guard expression is Literal(literal=Int(literal), ..) else {
    abort("expected checked int literal")
  }
  @test.assert_eq(literal.raw, "042")
  @test.assert_eq(literal.value, 42L)
}

///|
test "typecheck reports out of range int literal" {
  let result = expect_typecheck_result(
    (
      #|let bad : Int = 9223372036854775808
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0]),
    content=(
      #|invalid_int_literal 9223372036854775808 @ 2:17-2:36
    ),
  )
}

///|
test "typecheck inserts contextual auto argument" {
  let expression = expect_checked_let_initializer(
    (
      #|struct Add[A] {
      #|  add : (A, A) -> A
      #|}
      #|fn[A] op_add(a : A, b : A, auto op : Add[A]) -> A {
      #|  op.add(a, b)
      #|}
      #|offer int_add_ops : Add[Int] = builtin("%int_add_ops")
      #|let answer : Int = 1 + 2
    ),
    "answer",
    Primitive(Int),
  )
  inspect(
    @prettyprinter.render(expression, width=100),
    content=(
      #|op_add#0[Int](1, 2, int_add_ops#1) : Int
    ),
  )
}

///|
test "typecheck accepts explicit named contextual argument" {
  let expression = expect_checked_let_initializer(
    (
      #|struct Add[A] {
      #|  add : (A, A) -> A
      #|}
      #|fn[A] op_add(a : A, b : A, auto op : Add[A]) -> A {
      #|  op.add(a, b)
      #|}
      #|let custom_add : Add[Int] = builtin("%custom_add")
      #|let answer : Int = op_add(1, 2, op=custom_add)
    ),
    "answer",
    Primitive(Int),
  )
  inspect(
    @prettyprinter.render(expression, width=100),
    content=(
      #|op_add#0[Int](1, 2, custom_add#1) : Int
    ),
  )
}

///|
test "typecheck offer value declaration supplies contextual argument" {
  let expression = expect_checked_let_initializer(
    (
      #|struct Add[A] {
      #|  add : (A, A) -> A
      #|}
      #|fn[A] op_add(a : A, b : A, auto op : Add[A]) -> A {
      #|  op.add(a, b)
      #|}
      #|offer int_add_ops : Add[Int] = builtin("%int_add_ops")
      #|let answer : Int = 1 + 2
    ),
    "answer",
    Primitive(Int),
  )
  inspect(
    @prettyprinter.render(expression, width=100),
    content=(
      #|op_add#0[Int](1, 2, int_add_ops#1) : Int
    ),
  )
}

///|
test "typecheck auto offer parameter is visible in function body" {
  let result = expect_typecheck_result(
    (
      #|struct Add[A] {
      #|  add : (A, A) -> A
      #|}
      #|fn[A] op_add(a : A, b : A, auto op : Add[A]) -> A {
      #|  op.add(a, b)
      #|}
      #|fn[A] twice(x : A, auto offer op : Add[A]) -> A {
      #|  x + x
      #|}
      #|offer int_add_ops : Add[Int] = builtin("%int_add_ops")
      #|let answer : Int = twice(1)
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {
      #|      struct Add#0[A#0 : Type] {
      #|        add#0 : (tparam#0, tparam#0) -> tparam#0
      #|      }
      #|    }
      #|    type_members {}
      #|    fields {
      #|      add#0 : (tparam#0, tparam#0) -> tparam#0
      #|    }
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn op_add#0 : forall [tparam#1 A : Type]. (tparam#1, tparam#1, type#0[tparam#1]) -> tparam#1
      #|    fn twice#1 : forall [tparam#2 A : Type]. (tparam#2, type#0[tparam#2]) -> tparam#2
      #|    let int_add_ops#2 : type#0[Int]
      #|    let answer#3 : Int
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck forwards offered struct fields" {
  let expression = expect_checked_let_initializer(
    (
      #|struct Equal[A] {
      #|  equal : (A, A) -> Bool
      #|}
      #|struct Compare[A] {
      #|  offer equal_impl : Equal[A]
      #|}
      #|fn[A] op_equal(a : A, b : A, auto op : Equal[A]) -> Bool {
      #|  op.equal(a, b)
      #|}
      #|offer int_compare_ops : Compare[Int] = builtin("%int_compare_ops")
      #|let answer : Bool = 1 == 2
    ),
    "answer",
    Primitive(Bool),
  )
  inspect(
    @prettyprinter.render(expression, width=100),
    content=(
      #|op_equal#0[Int](1, 2, int_compare_ops#1.equal_impl#1) : Bool
    ),
  )
}

///|
test "typecheck local offer value declaration supplies contextual argument" {
  let expression = expect_checked_let_initializer(
    (
      #|struct Add[A] {
      #|  add : (A, A) -> A
      #|}
      #|fn[A] op_add(a : A, b : A, auto op : Add[A]) -> A {
      #|  op.add(a, b)
      #|}
      #|let answer : Int = {
      #|  offer int_add_ops : Add[Int] = builtin("%int_add_ops")
      #|  1 + 2
      #|}
    ),
    "answer",
    Primitive(Int),
  )
  inspect(
    @prettyprinter.render(expression, width=100),
    content=(
      #|{
      #|  let int_add_ops#5 : type#0[Int] = builtin("%int_add_ops")
      #|  op_add#0[Int](1, 2, int_add_ops#5)
      #|} : Int
    ),
  )
}

///|
test "typecheck reports missing contextual offer" {
  let result = expect_typecheck_result(
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
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {
      #|      struct Add#0[A#0 : Type] {
      #|        add#0 : (tparam#0, tparam#0) -> tparam#0
      #|      }
      #|    }
      #|    type_members {}
      #|    fields {
      #|      add#0 : (tparam#0, tparam#0) -> tparam#0
      #|    }
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn op_add#0 : forall [tparam#1 A : Type]. (tparam#1, tparam#1, type#0[tparam#1]) -> tparam#1
      #|    let answer#1 : Int
      #|  }
      #|  diagnostics {
      #|    cannot_infer missing contextual offer @ 8:24-8:25
      #|  }
      #|}
    ),
  )
}

///|
test "typecheck reports ambiguous contextual offer" {
  let result = expect_typecheck_result(
    (
      #|struct Add[A] {
      #|  add : (A, A) -> A
      #|}
      #|fn[A] op_add(a : A, b : A, auto op : Add[A]) -> A {
      #|  op.add(a, b)
      #|}
      #|offer add_a : Add[Int] = builtin("%add_a")
      #|offer add_b : Add[Int] = builtin("%add_b")
      #|let answer : Int = 1 + 2
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {
      #|      struct Add#0[A#0 : Type] {
      #|        add#0 : (tparam#0, tparam#0) -> tparam#0
      #|      }
      #|    }
      #|    type_members {}
      #|    fields {
      #|      add#0 : (tparam#0, tparam#0) -> tparam#0
      #|    }
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn op_add#0 : forall [tparam#1 A : Type]. (tparam#1, tparam#1, type#0[tparam#1]) -> tparam#1
      #|    let add_a#1 : type#0[Int]
      #|    let add_b#2 : type#0[Int]
      #|    let answer#3 : Int
      #|  }
      #|  diagnostics {
      #|    cannot_infer ambiguous contextual offer @ 10:24-10:25
      #|  }
      #|}
    ),
  )
}

///|
test "typecheck top level values and direct calls" {
  let result = expect_typecheck_result(
    (
      #|fn id(value : Int) -> Int {
      #|  value
      #|}
      #|let answer : Int = id(42)
      #|fn use_answer() -> Int {
      #|  answer
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {}
      #|    type_members {}
      #|    fields {}
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn id#0 : (Int) -> Int
      #|    fn use_answer#2 : () -> Int
      #|    let answer#1 : Int
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck top level functions recurse and values stay ordered" {
  let result = expect_typecheck_result(
    (
      #|fn first(value : Int) -> Int {
      #|  second(value)
      #|}
      #|let base : Int = 1
      #|fn second(value : Int) -> Int {
      #|  first(value)
      #|}
      #|let copied : Int = base
      #|fn use() -> Int {
      #|  copied
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {}
      #|    type_members {}
      #|    fields {}
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn first#0 : (Int) -> Int
      #|    fn second#2 : (Int) -> Int
      #|    fn use#4 : () -> Int
      #|    let base#1 : Int
      #|    let copied#3 : Int
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck reports forward top level value use" {
  let result = expect_typecheck_result(
    (
      #|let first : Int = second
      #|let second : Int = 1
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0]),
    content=(
      #|unresolved_value second @ 2:19-2:25
    ),
  )
}

///|
test "typecheck top level function bodies see later top level values" {
  let result = expect_typecheck_result(
    (
      #|struct Box {
      #|  value : Int
      #|}
      #|fn read_answer() -> Int {
      #|  answer
      #|}
      #|fn read_box() -> Int {
      #|  box.value
      #|}
      #|let answer : Int = 42
      #|let box : Box = Box::{ value: answer }
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {
      #|      struct Box#0 {
      #|        value#0 : Int
      #|      }
      #|    }
      #|    type_members {}
      #|    fields {
      #|      value#0 : Int
      #|    }
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn read_answer#0 : () -> Int
      #|    fn read_box#1 : () -> Int
      #|    let answer#2 : Int
      #|    let box#3 : type#0
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck local bindings are sequential and local functions see prior scope" {
  let result = expect_typecheck_result(
    (
      #|fn use() -> Int {
      #|  {
      #|    let base = 1
      #|    fn local(value : Int) -> Int {
      #|      base
      #|    }
      #|    local(2)
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {}
      #|    type_members {}
      #|    fields {}
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn use#0 : () -> Int
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck local function can call itself after declaration" {
  let result = expect_typecheck_result(
    (
      #|fn use() -> Int {
      #|  {
      #|    fn loop(value : Int) -> Int {
      #|      loop(value)
      #|    }
      #|    loop(1)
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {}
      #|    type_members {}
      #|    fields {}
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn use#0 : () -> Int
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck reports local function forward reference" {
  let result = expect_typecheck_result(
    (
      #|fn use() -> Int {
      #|  {
      #|    let result = local(1)
      #|    fn local(value : Int) -> Int {
      #|      value
      #|    }
      #|    result
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0]),
    content=(
      #|unresolved_value local @ 4:18-4:23
    ),
  )
}

///|
test "typecheck local generic function after declaration" {
  let result = expect_typecheck_result(
    (
      #|fn use() -> Int {
      #|  {
      #|    fn[A] id(value : A) -> A {
      #|      value
      #|    }
      #|    id(1)
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {}
      #|    type_members {}
      #|    fields {}
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn use#0 : () -> Int
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck direct binary operator alias" {
  let result = expect_typecheck_result(
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
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {}
      #|    type_members {}
      #|    fields {}
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn op_add#0 : (Int, Int) -> Int
      #|    fn use#1 : () -> Int
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck direct binary operator result mismatch" {
  let result = expect_typecheck_result(
    (
      #|fn op_add(a : Int, b : Int) -> Bool {
      #|  true
      #|}
      #|fn use() -> Int {
      #|  1 + 2
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0]),
    content=(
      #|type_mismatch expected=Int actual=Bool @ 6:7-6:8
    ),
  )
}

///|
test "typecheck direct unary operator alias" {
  let result = expect_typecheck_result(
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
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {}
      #|    type_members {}
      #|    fields {}
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn op_neg#0 : (Int) -> Int
      #|    fn use#1 : () -> Int
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck function literal parameters from expected function type" {
  let result = expect_typecheck_result(
    (
      #|fn apply(callback : (Int) -> Int) -> Int {
      #|  callback(1)
      #|}
      #|fn use() -> Int {
      #|  apply(fn(value) {
      #|    value
      #|  })
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {}
      #|    type_members {}
      #|    fields {}
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn apply#0 : ((Int) -> Int) -> Int
      #|    fn use#1 : () -> Int
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck checked function literal parameters from expected function type" {
  let result = expect_checked_source_result(
    (
      #|let id : (Int) -> Int = fn(value) {
      #|  value
      #|}
      #|fn use() -> Int {
      #|  id(1)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|checked_source_typecheck_result {
      #|  checked {
      #|    let id#0 : (Int) -> Int = fn(value#2 : Int) -> Int {
      #|      value#2
      #|    }
      #|    fn use#1() -> Int {
      #|      id#0(1)
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck pipeline expression as first argument call" {
  let result = expect_typecheck_result(
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
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {}
      #|    type_members {}
      #|    fields {}
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn first#0 : (Int, Int) -> Int
      #|    fn use#1 : () -> Int
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck pipeline expression into function literal" {
  let result = expect_typecheck_result(
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
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {}
      #|    type_members {}
      #|    fields {}
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn use#0 : () -> Int
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck generic function literal parameters from expected forall type" {
  let result = expect_typecheck_result(
    (
      #|let id : [A](A) -> A = fn[A](value) {
      #|  value
      #|}
      #|fn use() -> Int {
      #|  id(1)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {}
      #|    type_members {}
      #|    fields {}
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn use#1 : () -> Int
      #|    let id#0 : forall [tparam#0 A : Type]. (tparam#0) -> tparam#0
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck checked generic function literal parameters from expected forall type" {
  let result = expect_checked_source_result(
    (
      #|let id : [A](A) -> A = fn[A](value) {
      #|  value
      #|}
      #|fn use() -> Int {
      #|  id(1)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|checked_source_typecheck_result {
      #|  checked {
      #|    let id#0 : forall [tparam#0 A : Type]. (tparam#0) -> tparam#0 = fn[A#1 : Type](value#2 : tparam#1) -> tparam#1 {
      #|      value#2
      #|    }
      #|    fn use#1() -> Int {
      #|      id#0[Int](1)
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck reports generic function literal arity mismatch" {
  let result = expect_typecheck_result(
    (
      #|let id : [A](A) -> A = fn(value) {
      #|  value
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0]),
    content=(
      #|cannot_infer generic function arity @ 2:26-4:2
    ),
  )
}

///|
test "typecheck reports generic literal against non-generic function type" {
  let result = expect_typecheck_result(
    (
      #|let id : (Int) -> Int = fn[A](value : A) -> A {
      #|  value
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0]),
    content=(
      #|cannot_infer generic function arity @ 2:27-4:2
    ),
  )
}

///|
test "typecheck synthesizes direct generic call from argument type" {
  let result = expect_typecheck_result(
    (
      #|fn[A] id(value : A) -> A {
      #|  value
      #|}
      #|fn use() -> Int {
      #|  id(1)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {}
      #|    type_members {}
      #|    fields {}
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn id#0 : forall [tparam#0 A : Type]. (tparam#0) -> tparam#0
      #|    fn use#1 : () -> Int
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck generic call uses expected result type" {
  let result = expect_typecheck_result(
    (
      #|fn[A] make() -> A {
      #|  builtin("%make")
      #|}
      #|fn use() -> Int {
      #|  make()
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {}
      #|    type_members {}
      #|    fields {}
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn make#0 : forall [tparam#0 A : Type]. () -> tparam#0
      #|    fn use#1 : () -> Int
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck generic call drives function literal argument" {
  let result = expect_typecheck_result(
    (
      #|fn[A] apply(callback : (A) -> A, value : A) -> A {
      #|  callback(value)
      #|}
      #|fn use() -> Int {
      #|  apply(fn(value) {
      #|    value
      #|  }, 1)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {}
      #|    type_members {}
      #|    fields {}
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn apply#0 : forall [tparam#0 A : Type]. ((tparam#0) -> tparam#0, tparam#0) -> tparam#0
      #|    fn use#1 : () -> Int
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck polymorphic function parameter instantiation" {
  let result = expect_typecheck_result(
    (
      #|fn[B] apply(f : [A](A) -> A, x : B) -> B {
      #|  f(x)
      #|}
      #|fn[A] id(value : A) -> A {
      #|  value
      #|}
      #|fn use() -> Int {
      #|  apply(id, 1)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {}
      #|    type_members {}
      #|    fields {}
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn apply#0 : forall [
      #|      tparam#0 B : Type
      #|    ]. (forall [tparam#1 A : Type]. (tparam#1) -> tparam#1, tparam#0) -> tparam#0
      #|    fn id#1 : forall [tparam#2 A : Type]. (tparam#2) -> tparam#2
      #|    fn use#2 : () -> Int
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck reports unresolved generic type arguments" {
  let result = expect_typecheck_result(
    (
      #|fn[A] make() -> A {
      #|  builtin("%make")
      #|}
      #|fn use() -> Bool {
      #|  {
      #|    let value = make()
      #|    true
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0]),
    content=(
      #|cannot_infer type arguments @ 7:22-7:23
    ),
  )
}

///|
test "typecheck generic struct construction and field access" {
  let result = expect_typecheck_result(
    (
      #|struct Box[A] {
      #|  value : A
      #|}
      #|fn use() -> Int {
      #|  {
      #|    let box = Box[Int]::{ value: 1 }
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
      #|    fn use#0 : () -> Int
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck existential struct construction with type witness" {
  let result = expect_checked_source_result(
    (
      #|struct Hide {
      #|  type T : Type
      #|  val : T
      #|}
      #|let hidden : Hide = Hide::{ T = Int, val: 1 }
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
      #|    let hidden#0 : type#0 = type#0::{
      #|      type T#0 = Int
      #|      val#0: 1
      #|    }
      #|  }
      #|  diagnostics {}
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
    @prettyprinter.render(result.diagnostics[0]),
    content=(
      #|missing_type_member T @ 6:29-6:37
    ),
  )
}

///|
test "typecheck reports field access on non-struct value" {
  let result = expect_typecheck_result(
    (
      #|fn bad() -> Int {
      #|  1.value
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0]),
    content=(
      #|not_a_struct Int @ 3:5-3:10
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
      #|fn wrap(value : Int) -> Option[Int] {
      #|  Option::some(value)
      #|}
      #|fn empty() -> Option[Int] {
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
      #|    fn wrap#0 : (Int) -> type#0[Int]
      #|    fn empty#1 : () -> type#0[Int]
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
      #|let packed : Packed = Packed::hide[Int](1)
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
      #|    let packed#0 : type#0 = variant#0[Int](1)
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
      #|    let packed#0 : type#0 = variant#0[Int](1)
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
      #|fn use(p : Packed) -> Int {
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
      #|fn bad(p : Packed) -> Int {
      #|  match p {
      #|    Packed::hide[T](value) => value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0], width=100),
    content=(
      #|type_mismatch expected=Int actual=tparam#1 @ 7:31-7:36
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
      #|fn use(h : Hide) -> Int {
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
      #|fn use(h : Hide) -> Int {
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
      #|fn use(h : PairHide) -> Int {
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
      #|fn bad(h : Hide) -> Int {
      #|  match h {
      #|    Hide::{ T, val } => val
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0], width=100),
    content=(
      #|type_mismatch expected=Int actual=tparam#1 @ 8:25-8:28
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
      #|fn bad(h : Hide) -> Int {
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
    @prettyprinter.render(result.diagnostics[0], width=100),
    content=(
      #|hidden_type_escape tparam#1 @ 10:7-10:10
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
      #|fn bad(p : Packed) -> Int {
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
    @prettyprinter.render(result.diagnostics[0], width=100),
    content=(
      #|hidden_type_escape tparam#1 @ 8:33-8:38
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
test "typecheck expands transparent type alias beta applications" {
  let result = expect_typecheck_result(
    (
      #|type Id[A] = A
      #|let answer : Id[Int] = 42
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
  guard result.values.values[0] is Let(value) else {
    abort("expected checked let")
  }
  inspect(@prettyprinter.render(value.type_, width=100), content="Int")
}

///|
test "typecheck accepts higher-kinded alias parameter" {
  let result = expect_typecheck_result(
    (
      #|struct Box[A] {
      #|  value : A
      #|}
      #|type ApplyInt[F : [Type] -> Type] = F[Int]
      #|fn get(box : ApplyInt[Box]) -> Int {
      #|  box.value
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
}

///|
test "typecheck accepts higher-kinded struct literal type argument" {
  let result = expect_typecheck_result(
    (
      #|enum Option[T] {
      #|  some(T)
      #|  none()
      #|}
      #|fn[T, R] map_option(val : Option[T], f : (T) -> R) -> Option[R] {
      #|  match val {
      #|    Option::some(v) => Option::some(f(v))
      #|    Option::none() => Option::none()
      #|  }
      #|}
      #|struct Mappable[U : [Type] -> Type] {
      #|  map : [A, B](U[A], (A) -> B) -> U[B]
      #|}
      #|let option_mappable : Mappable[Option] = Mappable[Option]::{
      #|  map: map_option
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
}

///|
test "typecheck reports kind mismatch for higher-kinded struct literal type argument" {
  let result = expect_typecheck_result(
    (
      #|enum Option[T] {
      #|  some(T)
      #|  none()
      #|}
      #|fn[T, R] map_option(val : Option[T], f : (T) -> R) -> Option[R] {
      #|  match val {
      #|    Option::some(v) => Option::some(f(v))
      #|    Option::none() => Option::none()
      #|  }
      #|}
      #|struct Mappable[U : [Type] -> Type] {
      #|  map : [A, B](U[A], (A) -> B) -> U[B]
      #|}
      #|let bad : Mappable[Option] = Mappable[Int]::{
      #|  map: map_option
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0].kind, width=100),
    content="kind_mismatch expected=[Type] -> Type actual=Type",
  )
}

///|
test "typecheck accepts higher-kinded qualified variant type argument" {
  let result = expect_typecheck_result(
    (
      #|enum Option[T] {
      #|  some(T)
      #|  none()
      #|}
      #|enum Box[F : [Type] -> Type] {
      #|  wrap(F[Int])
      #|}
      #|let boxed : Box[Option] = Box[Option]::wrap(Option::some(1))
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
}

///|
test "typecheck reports kind mismatch for higher-kinded qualified variant type argument" {
  let result = expect_typecheck_result(
    (
      #|enum Option[T] {
      #|  some(T)
      #|  none()
      #|}
      #|enum Box[F : [Type] -> Type] {
      #|  wrap(F[Int])
      #|}
      #|let boxed : Box[Option] = Box[Int]::wrap(Option::some(1))
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0].kind, width=100),
    content="kind_mismatch expected=[Type] -> Type actual=Type",
  )
}

///|
test "typecheck defaults unannotated alias header parameter kind to Type" {
  let result = expect_typecheck_result(
    (
      #|type ApplyInt[F] = F[Int]
      #|let answer : ApplyInt[Int] = 42
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0].kind, width=100),
    content="kind_mismatch expected=[] -> Type actual=Type",
  )
}

///|
test "typecheck reports duplicate type alias header parameter" {
  let result = expect_typecheck_result(
    (
      #|type Bad[A, A] = A
      #|let answer : Int = 42
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0].kind, width=100),
    content="duplicate_type_parameter A",
  )
}

///|
test "typecheck reports type alias cycle" {
  let result = expect_typecheck_result(
    (
      #|type A = B
      #|type B = A
      #|let answer : A = 42
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0].kind, width=100),
    content="type_alias_cycle A",
  )
}

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
test "typecheck unqualified enum variant construction" {
  let result = expect_typecheck_result(
    (
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|fn wrap(value : Int) -> Option[Int] {
      #|  some(value)
      #|}
      #|fn empty() -> Option[Int] {
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
      #|    fn wrap#0 : (Int) -> type#0[Int]
      #|    fn empty#1 : () -> type#0[Int]
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck reports unresolved variant type arguments" {
  let result = expect_typecheck_result(
    (
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|fn use() -> Bool {
      #|  {
      #|    let value = none
      #|    true
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0]),
    content=(
      #|cannot_infer type arguments @ 8:17-8:21
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
      #|fn bad() -> Option[Int] {
      #|  some(true)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0]),
    content=(
      #|type_mismatch expected=Int actual=Bool @ 7:8-7:12
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
      #|fn bad() -> Option[Int] {
      #|  some()
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0]),
    content=(
      #|cannot_infer variant arity @ 7:8-7:9
    ),
  )
}

///|
test "typecheck reports ambiguous unqualified enum variant" {
  let result = expect_typecheck_result(
    (
      #|enum Left {
      #|  same(Int)
      #|}
      #|enum Right {
      #|  same(Int)
      #|}
      #|fn bad() -> Left {
      #|  same(1)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0]),
    content=(
      #|cannot_infer ambiguous variant reference same @ 9:9-9:10
    ),
  )
}

///|
test "typecheck exhaustive enum match" {
  let result = expect_typecheck_result(
    (
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|fn unwrap(value : Option[Int], fallback : Int) -> Int {
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
      #|    fn unwrap#0 : (type#0[Int], Int) -> Int
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck unqualified enum variant patterns from expected type" {
  let result = expect_typecheck_result(
    (
      #|enum Left {
      #|  same(Int)
      #|}
      #|enum Right {
      #|  same(Bool)
      #|}
      #|fn left(value : Left) -> Int {
      #|  match value {
      #|    same(x) => x
      #|  }
      #|}
      #|fn right(value : Right) -> Int {
      #|  match value {
      #|    same(_) => 1
      #|  }
      #|}
    ),
  )
  inspect(result.diagnostics.length(), content="0")
}

///|
test "typecheck unqualified enum variant patterns in adjacent match arms" {
  let result = expect_typecheck_result(
    (
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|fn unwrap(value : Option[Int], fallback : Int) -> Int {
      #|  match value {
      #|    none() => fallback
      #|    some(x) => x
      #|  }
      #|}
    ),
  )
  inspect(result.diagnostics.length(), content="0")
}

///|
test "typecheck rejects unqualified enum variant without enum expected type" {
  let result = expect_typecheck_result(
    (
      #|fn bad(value : Int) -> Int {
      #|  match value {
      #|    some(x) => x
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0]),
    content=(
      #|cannot_infer unqualified variant pattern requires enum expected type some @ 4:11-4:12
    ),
  )
}

///|
test "typecheck reports non-exhaustive bool match" {
  let result = expect_typecheck_result(
    (
      #|fn bad(value : Bool) -> Int {
      #|  match value {
      #|    true => 1
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0]),
    content=(
      #|non_exhaustive_match Bool @ 3:15-5:4
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
      #|fn use(value : Option[Option[Int]]) -> Int {
      #|  match value {
      #|    Option::none() => 0
      #|    Option::some(Option::none()) => 1
      #|    Option::some(Option::some(x)) => x
      #|  }
      #|}
    ),
  )
  inspect(result.diagnostics.length(), content="0")
}

///|
test "typecheck reports non-exhaustive nested enum patterns" {
  let result = expect_typecheck_result(
    (
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|fn bad(value : Option[Option[Int]]) -> Int {
      #|  match value {
      #|    Option::none() => 0
      #|    Option::some(Option::none()) => 1
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0]),
    content=(
      #|non_exhaustive_match type#0[type#0[Int]] @ 7:15-10:4
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
      #|fn bad(value : Option[Option[Int]]) -> Int {
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
    @prettyprinter.render(result.diagnostics[0]),
    content=(
      #|unreachable_match_arm @ 9:5-9:38
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
      #|fn use(value : Box[Option[Int]]) -> Int {
      #|  match value {
      #|    Box::{ value: Option::none() } => 0
      #|    Box::{ value: Option::some(x) } => x
      #|  }
      #|}
    ),
  )
  inspect(result.diagnostics.length(), content="0")
}

///|
test "typecheck reports unreachable match arm" {
  let result = expect_typecheck_result(
    (
      #|fn bad(value : Bool) -> Int {
      #|  match value {
      #|    _ => 1
      #|    true => 2
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0]),
    content=(
      #|unreachable_match_arm @ 5:13-5:14
    ),
  )
}

///|
test "typecheck compares int patterns by checked value" {
  let result = expect_typecheck_result(
    (
      #|fn bad(value : Int) -> Int {
      #|  match value {
      #|    1 => 1
      #|    01 => 2
      #|    _ => 0
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0]),
    content=(
      #|unreachable_match_arm @ 5:11-5:12
    ),
  )
}

///|
test "typecheck reports duplicate pattern binder" {
  let result = expect_typecheck_result(
    (
      #|enum Pair {
      #|  pair(Int, Int)
      #|}
      #|fn bad(value : Pair) -> Int {
      #|  match value {
      #|    Pair::pair(x, x) => x
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0]),
    content=(
      #|duplicate_pattern_binder x @ 7:19-7:20
    ),
  )
}

///|
test "typecheck reports missing struct pattern field" {
  let result = expect_typecheck_result(
    (
      #|struct Point {
      #|  x : Int
      #|  y : Int
      #|}
      #|fn bad(point : Point) -> Int {
      #|  match point {
      #|    Point::{ x } => x
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0]),
    content=(
      #|missing_field y @ 8:16-8:17
    ),
  )
}

///|
test "typecheck produces checked struct pattern fields in declaration order" {
  let pattern = expect_first_checked_match_pattern(
    (
      #|struct Point {
      #|  x : Int
      #|  y : Int
      #|}
      #|fn use(point : Point) -> Int {
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

///|
test "typecheck reports type mismatch" {
  let result = expect_typecheck_result(
    (
      #|fn bad() -> Int {
      #|  true
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0]),
    content=(
      #|type_mismatch expected=Int actual=Bool @ 3:3-3:7
    ),
  )
}

///|
test "typecheck struct literal punning and required fields" {
  let result = expect_typecheck_result(
    (
      #|struct Point {
      #|  x : Int
      #|  y : Int
      #|}
      #|fn bad(x : Int) -> Point {
      #|  Point::{ x }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0]),
    content=(
      #|missing_field y @ 7:14-7:15
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
      #|  broken : Box[Int, Bool]
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0]),
    content=(
      #|type_arity_mismatch Box expected=1 actual=2 @ 6:16-6:26
    ),
  )
}

///|
test "typecheck keeps unresolved type as error type" {
  let result = expect_declaration_typecheck_result(
    (
      #|struct Bad {
      #|  missing : Missing
      #|}
    ),
  )
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

///|
test "typecheck accepts annotated effect operation call" {
  let result = expect_checked_source_result(
    (
      #|effect Console {
      #|  write(String) -> Unit
      #|}
      #|fn write_hello() -> Unit ! Console {
      #|  Console::write!("hi")
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|checked_source_typecheck_result {
      #|  checked {
      #|    effect Console#0 {
      #|      write#0(String) -> Unit
      #|    }
      #|    fn write_hello#0() -> Unit {
      #|      operation#0!("hi")
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck accepts explicit effect operation type witnesses and handler binders" {
  let result = expect_checked_source_result(
    (
      #|effect Prompt {
      #|  choose[A](A, A) -> A
      #|}
      #|fn program() -> Int {
      #|  handle Prompt::choose![Int](40, 41) with {
      #|    Prompt::choose[T](left, right, resume) => resume(left)
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|checked_source_typecheck_result {
      #|  checked {
      #|    effect Prompt#0 {
      #|      choose#0[A#0 : Type](tparam#0, tparam#0) -> tparam#0
      #|    }
      #|    fn program#0() -> Int {
      #|      {
      #|        handle operation#0![Int](40, 41)
      #|        with effect#0 {
      #|          operation#0[T#1 : Type](left#1, right#2, resume#3) => resume#3(left#1)
      #|        }
      #|        final value#4 {
      #|          value#4
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
test "typecheck infers effect operation type witnesses from payloads" {
  let result = expect_checked_source_result(
    (
      #|effect Prompt {
      #|  choose[A](A, A) -> A
      #|}
      #|fn choose_int() -> Int ! Prompt {
      #|  Prompt::choose!(1, 2)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|checked_source_typecheck_result {
      #|  checked {
      #|    effect Prompt#0 {
      #|      choose#0[A#0 : Type](tparam#0, tparam#0) -> tparam#0
      #|    }
      #|    fn choose_int#0() -> Int {
      #|      operation#0![Int](1, 2)
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck rejects effect operation type witness arity mismatch" {
  let result = expect_typecheck_result(
    (
      #|effect Prompt {
      #|  choose[A](A, A) -> A
      #|}
      #|fn bad() -> Int ! Prompt {
      #|  Prompt::choose![Int, Bool](1, 2)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[
      #|  cannot_infer effect operation type arguments @ 6:18-6:35,
      #|  cannot_infer effect operation type arguments @ 6:18-6:35,
      #|  effect_mismatch expected=effect#0 actual={} @ 6:3-7:2
      #|]
    ),
  )
}

///|
test "typecheck rejects operation call in pure function" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  write(String) -> Unit
      #|}
      #|fn bad() -> Unit {
      #|  Console::write!("hi")
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0].kind, width=100),
    content=(
      #|effect_mismatch expected={} actual=effect#0
    ),
  )
}

///|
test "typecheck rejects pure body with non-empty effect annotation" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  write(String) -> Unit
      #|}
      #|fn bad() -> Unit ! Console {
      #|  ()
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[effect_mismatch expected=effect#0 actual={} @ 6:3-7:2]
    ),
  )
}

///|
test "typecheck propagates effectful named function call" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|fn read_int() -> Int ! Console {
      #|  Console::read!()
      #|}
      #|fn caller() -> Int ! Console {
      #|  read_int()
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
}

///|
test "typecheck rejects effectful function call in pure function" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|fn read_int() -> Int ! Console {
      #|  Console::read!()
      #|}
      #|fn caller() -> Int {
      #|  read_int()
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[effect_mismatch expected={} actual=effect#0 @ 9:3-10:2]
    ),
  )
}

///|
test "typecheck handler removes effect propagated through function call" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|fn read_int() -> Int ! Console {
      #|  Console::read!()
      #|}
      #|fn program() -> Int {
      #|  handle read_int() with {
      #|    Console::read(resume) => resume(41)
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
}

///|
test "typecheck propagates latent effect from function parameter call" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|fn call_read(f : () -> Int ! Console) -> Int ! Console {
      #|  f()
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
}

///|
test "typecheck checks operation payload type" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  write(String) -> Unit
      #|}
      #|fn bad() -> Unit ! Console {
      #|  Console::write!(1)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0].kind, width=100),
    content=(
      #|type_mismatch expected=String actual=Int
    ),
  )
}

///|
test "typecheck checks operation payload arity" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  write(String) -> Unit
      #|}
      #|fn bad() -> Unit ! Console {
      #|  Console::write!()
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0].kind, width=100),
    content=(
      #|cannot_infer effect operation arity
    ),
  )
}

///|
test "typecheck checks handler operation tables" {
  let result = expect_checked_source_result(
    (
      #|enum Choice {
      #|  left()
      #|  right()
      #|}
      #|effect Console {
      #|  read() -> Int
      #|  write(String) -> Unit
      #|  choose(Choice) -> Unit
      #|}
      #|fn program() -> Int {
      #|  handle Console::read!() with {
      #|    Console::read(resume) => 0
      #|    Console::write(message, resume2) => resume2(())
      #|    Console::choose(Choice::left(), resume3) => resume3(())
      #|    Console::choose(Choice::right(), resume4) => resume4(())
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|checked_source_typecheck_result {
      #|  checked {
      #|    enum Choice#0 {
      #|      left#0
      #|      right#1
      #|    }
      #|    effect Console#0 {
      #|      read#0 -> Int
      #|      write#1(String) -> Unit
      #|      choose#2(type#0) -> Unit
      #|    }
      #|    fn program#0() -> Int {
      #|      {
      #|        handle operation#0!()
      #|        with effect#0 {
      #|          operation#0(resume#1) => 0
      #|          operation#1(message#2, resume2#3) => resume2#3(())
      #|          operation#2(variant#0(), resume3#4) => resume3#4(())
      #|          operation#2(variant#1(), resume4#5) => resume4#5(())
      #|        }
      #|        final value#6 {
      #|          value#6
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
test "typecheck assigns resume binder function type" {
  let type_ = expect_first_handler_resume_callee_type(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|effect State {
      #|  get() -> Int
      #|}
      #|fn program() -> Int ! State {
      #|  handle Console::read!() with {
      #|    Console::read(resume) => resume(0)
      #|  } final value {
      #|    State::get!()
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(type_, width=100),
    content=(
      #|(Int) -> Int ! effect#1
    ),
  )
}

///|
test "typecheck rejects handler resume argument mismatch" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|fn program() -> Int {
      #|  handle Console::read!() with {
      #|    Console::read(resume) => resume("bad")
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[type_mismatch expected=Int actual=String @ 7:37-7:42]
    ),
  )
}

///|
test "typecheck rejects handler arm result mismatch" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|fn program() -> String {
      #|  handle Console::read!() with {
      #|    Console::read(resume) => 0
      #|  } final value {
      #|    "done"
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[type_mismatch expected=String actual=Int @ 7:30-7:31]
    ),
  )
}

///|
test "typecheck removes handled effect from handler residual effect" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|fn program() -> Int {
      #|  handle Console::read!() with {
      #|    Console::read(resume) => 0
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
}

///|
test "typecheck rejects handler for absent closed effect" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|fn program() -> Int {
      #|  handle 0 with {
      #|    Console::read(resume) => 0
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[effect_mismatch expected=effect#0 actual={} @ 6:12-10:4]
    ),
  )
}

///|
test "typecheck preserves unhandled residual effect" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|effect State {
      #|  get() -> Int
      #|}
      #|fn program() -> Int {
      #|  handle Console::read!() with {
      #|    Console::read(resume) => 0
      #|  } final value {
      #|    State::get!()
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[effect_mismatch expected={} actual=effect#1 @ 9:3-14:2]
    ),
  )
}

///|
test "typecheck preserves handler arm direct effects" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|effect State {
      #|  get() -> Int
      #|}
      #|fn program() -> Int {
      #|  handle Console::read!() with {
      #|    Console::read(resume) => State::get!()
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[effect_mismatch expected={} actual=effect#1 @ 9:3-14:2]
    ),
  )
}

///|
test "typecheck rejects mixed handler effects" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|effect State {
      #|  get() -> Int
      #|}
      #|fn program() -> Int {
      #|  handle Console::read!() with {
      #|    Console::read(resume) => 0
      #|    State::get(resume2) => 1
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[mixed_handler_effects @ 11:5-11:29]
    ),
  )
}

///|
test "typecheck rejects duplicate handled effects" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|fn program() -> Int {
      #|  handle Console::read!() with {
      #|    Console::read(resume) => 0
      #|  } with {
      #|    Console::read(resume2) => 1
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[duplicate_handled_effect effect#0 @ 9:5-10:4]
    ),
  )
}

///|
test "typecheck rejects missing handler operation coverage" {
  let result = expect_typecheck_result(
    (
      #|enum Choice {
      #|  left()
      #|  right()
      #|}
      #|effect Console {
      #|  read() -> Int
      #|  choose(Choice) -> Unit
      #|}
      #|fn program() -> Int {
      #|  handle Console::read!() with {
      #|    Console::read(resume) => 0
      #|    Console::choose(Choice::left(), resume2) => resume2(())
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[missing_handler_operation operation#1 @ 12:5-14:4]
    ),
  )
}

///|
test "typecheck rejects redundant handler operation arms" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  write(String) -> Unit
      #|}
      #|fn program() -> Int {
      #|  handle Console::write!("hi") with {
      #|    Console::write(_, resume) => resume(())
      #|    Console::write(message, resume2) => resume2(())
      #|  } final value {
      #|    0
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[unreachable_match_arm @ 8:5-8:52]
    ),
  )
}

///|
test "typecheck represents effect row variables" {
  let result = expect_typecheck_result(
    (
      #|fn[E : Effect] run(f : () -> Unit ! E) -> Unit ! E {
      #|  f()
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
}

///|
test "typecheck expands effect set alias in function annotations" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|effect Log {
      #|  write(String) -> Unit
      #|}
      #|type UI = { Console, Log }
      #|fn program() -> Unit ! UI {
      #|  let ignored : Int = Console::read!()
      #|  Log::write!("ok")
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
  inspect(
    @prettyprinter.render(checked_function_effect(result, "program"), width=100),
    content=(
      #|{
      #|  effect#0,
      #|  effect#1
      #|}
    ),
  )
}

///|
test "typecheck applies generic effect set alias" {
  let result = expect_typecheck_result(
    (
      #|effect Coroutine {
      #|  pause() -> Unit
      #|}
      #|effect Log {
      #|  write(String) -> Unit
      #|}
      #|type Task[E : Effect] = { Coroutine, E }
      #|fn program() -> Unit ! Task[Log] {
      #|  let ignored : Unit = Coroutine::pause!()
      #|  Log::write!("ok")
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
  inspect(
    @prettyprinter.render(checked_function_effect(result, "program"), width=100),
    content=(
      #|{
      #|  effect#0,
      #|  effect#1
      #|}
    ),
  )
}

///|
test "typecheck normalizes expanded effect set alias" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|effect Log {
      #|  write(String) -> Unit
      #|}
      #|type Read = { Console }
      #|type UI = { Log, Read, Console }
      #|fn program() -> Unit ! UI {
      #|  let ignored : Int = Console::read!()
      #|  Log::write!("ok")
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
  inspect(
    @prettyprinter.render(checked_function_effect(result, "program"), width=100),
    content=(
      #|{
      #|  effect#1,
      #|  effect#0
      #|}
    ),
  )
}

///|
test "typecheck reports effect alias cycle" {
  let result = expect_typecheck_result(
    (
      #|type A = { B }
      #|type B = { A }
      #|fn program() -> Unit ! A {
      #|  ()
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0].kind, width=100),
    content="type_alias_cycle A",
  )
}

///|
test "typecheck rejects type-kind alias in effect position" {
  let result = expect_typecheck_result(
    (
      #|type Answer = Int
      #|fn program() -> Unit ! Answer {
      #|  ()
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0].kind, width=100),
    content="kind_mismatch expected=Effect actual=Type",
  )
}

///|
test "typecheck rejects type argument for effect alias parameter" {
  let result = expect_typecheck_result(
    (
      #|effect Coroutine {
      #|  yield() -> Unit
      #|}
      #|type Task[E : Effect] = { Coroutine, E }
      #|fn program() -> Unit ! Task[Int] {
      #|  ()
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0].kind, width=100),
    content="kind_mismatch expected=Effect actual=Type",
  )
}
