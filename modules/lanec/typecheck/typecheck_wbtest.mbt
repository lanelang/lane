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
    source,
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
fn expect_first_checked_match_pattern(
  source : String,
  name : String,
) -> @checked.CheckedPattern {
  let file = expect_parse_ok(source)
  let resolved = @resolve.resolve_source_file(file)
  let declaration_result = typecheck_declarations(resolved)
  let source = @desugar.desugar_source_file(resolved)
  let checker = SemanticChecker::{
    source,
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
      #|  none
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
      #|  type F : Type -> Type
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
      #|        type F#0 : Type -> Type
      #|        val#0 : tparam#0
      #|      }
      #|      enum Packed#1 {
      #|        hide#0[T#1 : Type](tparam#1)
      #|      }
      #|    }
      #|    type_members {
      #|      type F#0 : Type -> Type
      #|    }
      #|    fields {
      #|      val#0 : tparam#0
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
test "typecheck prelude primitive operation fragment" {
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
    abort("expected checked prelude fragment")
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
    content="invalid_int_literal 9223372036854775808 @ 1:17-1:36",
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
      #|    cannot_infer missing contextual offer @ 7:24-7:25
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
      #|    cannot_infer ambiguous contextual offer @ 9:24-9:25
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
    content="unresolved_value second @ 1:19-1:25",
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
    content="unresolved_value local @ 3:18-3:23",
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
    content="type_mismatch expected=Int actual=Bool @ 5:7-5:8",
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
    content="cannot_infer generic function arity @ 1:26-3:2",
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
    content="cannot_infer generic function arity @ 1:27-3:2",
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
    content="cannot_infer type arguments @ 6:22-6:23",
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
      #|missing_type_member T @ 5:29-5:37
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
    content="not_a_struct Int @ 2:5-2:10",
  )
}

///|
test "typecheck qualified enum variant construction" {
  let result = expect_typecheck_result(
    (
      #|enum Option[A] {
      #|  none
      #|  some(A)
      #|}
      #|fn wrap(value : Int) -> Option[Int] {
      #|  Option::some(value)
      #|}
      #|fn empty() -> Option[Int] {
      #|  Option::none
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
    content="type_mismatch expected=Int actual=tparam#1 @ 6:31-6:36",
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
    content="type_mismatch expected=Int actual=tparam#1 @ 7:25-7:28",
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
    content="hidden_type_escape tparam#1 @ 9:7-9:10",
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
    content="hidden_type_escape tparam#1 @ 7:33-7:38",
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
      #|  none
      #|  some(A)
      #|}
      #|fn wrap(value : Int) -> Option[Int] {
      #|  some(value)
      #|}
      #|fn empty() -> Option[Int] {
      #|  none
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
      #|  none
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
    content="cannot_infer type arguments @ 7:17-7:21",
  )
}

///|
test "typecheck reports enum variant payload mismatch" {
  let result = expect_typecheck_result(
    (
      #|enum Option[A] {
      #|  none
      #|  some(A)
      #|}
      #|fn bad() -> Option[Int] {
      #|  some(true)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0]),
    content="type_mismatch expected=Int actual=Bool @ 6:8-6:12",
  )
}

///|
test "typecheck reports enum variant arity mismatch" {
  let result = expect_typecheck_result(
    (
      #|enum Option[A] {
      #|  none
      #|  some(A)
      #|}
      #|fn bad() -> Option[Int] {
      #|  some()
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics[0]),
    content="cannot_infer variant arity @ 6:8-6:9",
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
    content="cannot_infer ambiguous variant reference same @ 8:9-8:10",
  )
}

///|
test "typecheck exhaustive enum match" {
  let result = expect_typecheck_result(
    (
      #|enum Option[A] {
      #|  none
      #|  some(A)
      #|}
      #|fn unwrap(value : Option[Int], fallback : Int) -> Int {
      #|  match value {
      #|    Option::none => fallback
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
    content="non_exhaustive_match Bool @ 2:15-4:4",
  )
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
    content="unreachable_match_arm @ 4:13-4:14",
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
    content="unreachable_match_arm @ 4:11-4:12",
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
    content="duplicate_pattern_binder x @ 6:19-6:20",
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
    content="missing_field y @ 7:16-7:17",
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
    content="type_mismatch expected=Int actual=Bool @ 2:3-2:7",
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
    content="missing_field y @ 6:14-6:15",
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
    content="type_arity_mismatch Box expected=1 actual=2 @ 5:16-5:26",
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
      #|    unresolved_type Missing @ 2:13-2:20
      #|  }
      #|}
    ),
  )
}
