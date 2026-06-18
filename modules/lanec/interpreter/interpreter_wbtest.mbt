///|
using @basic {type SourceSpan}

///|
using @symbol {type SymbolRegistry}

///|
fn loc() -> SourceSpan {
  SourceSpan::dummy()
}

///|
fn expect_anf_program(source : String) -> @anf.AnfProgram {
  let parse_result = @parser.parse_string(source)
  if !parse_result.lexical_errors.is_empty() ||
    !parse_result.parse_errors.is_empty() {
    abort("expected parse success")
  }
  guard parse_result.source is Some(file) else { abort("expected source") }
  let resolved = @resolve.resolve_source_file(file)
  let checked = @typecheck.typecheck_checked_source_file(resolved)
  guard checked.source is Some(source) else {
    abort(@prettyprinter.render(checked.diagnostics, width=100))
  }
  @anf.lower_checked_source_file_to_anf(source)
}

///|
fn expect_buslane_program(source : String) -> @buslane.Program {
  let parse_result = @parser.parse_string(source)
  if !parse_result.lexical_errors.is_empty() ||
    !parse_result.parse_errors.is_empty() {
    abort("expected parse success")
  }
  guard parse_result.source is Some(file) else { abort("expected source") }
  let resolved = @resolve.resolve_source_file(file)
  let checked = @typecheck.typecheck_checked_source_file(resolved)
  guard checked.source is Some(source) else {
    abort(@prettyprinter.render(checked.diagnostics, width=100))
  }
  @elaborate.lower_checked_source_file_to_buslane(source)
}

///|
fn expect_top_level_value(
  program : @anf.AnfProgram,
  name : String,
) -> ValueSymbolId {
  for declaration in program.declarations {
    if declaration is Let(declaration) && declaration.name == Some(name) {
      return declaration.symbol
    }
  }
  abort("expected top-level value \{name}")
}

///|
fn expect_last_buslane_let(program : @buslane.Program) -> @buslane.ValueId {
  for index = program.terms.length() - 1; index >= 0; index = index - 1 {
    if program.terms[index] is Let(id, _) {
      return id
    }
  }
  abort("expected Buslane top-level let")
}

///|
fn answer_builtins() -> BuiltinRuntime {
  let runtime = BuiltinRuntime::BuiltinRuntime()
  runtime.add_handler((name, type_, arguments) => {
    guard name == "%answer" else { raise MissingBuiltin(name~, type_~) }
    guard arguments.is_empty() else {
      raise BuiltinFailure(name~, message="expected no arguments")
    }
    Int(42L)
  })
  runtime
}

///|
test "pretty runtime nominal values erase existential witnesses" {
  let registry = SymbolRegistry::SymbolRegistry()
  let box = registry.define_type("Box", Struct, 0, loc())
  let value_field = registry.define_field(box, "value", 0, loc())
  let value = RuntimeValue::Struct(symbol=box, fields=[
    { symbol: value_field, name: "value", value: Int(42L) },
  ])
  inspect(
    @prettyprinter.render(value, width=80),
    content=(
      #|struct_value type#0 {
      #|  field field#0 value {
      #|    int 42
      #|  }
      #|}
    ),
  )
}

///|
test "lookup prefers latest runtime binding" {
  let registry = SymbolRegistry::SymbolRegistry()
  let symbol = registry.define_value("answer", LocalBinding, loc())
  let environment = RuntimeEnvironment::RuntimeEnvironment()
  environment.bind_value(symbol, Int(1L))
  environment.bind_value(symbol, Int(2L))
  inspect(
    @prettyprinter.render(environment.lookup_value(symbol), width=80),
    content="int 2",
  )
}

///|
test "builtin runtime delegates to handlers" {
  let runtime = BuiltinRuntime::BuiltinRuntime()
  runtime.add_handler((name, type_, arguments) => {
    guard name == "%answer" else { raise MissingBuiltin(name~, type_~) }
    guard arguments.is_empty() else {
      raise BuiltinFailure(name~, message="expected no arguments")
    }
    Int(42L)
  })
  inspect(
    @prettyprinter.render(
      runtime.invoke("%answer", Primitive(Unit), []),
      width=80,
    ),
    content="int 42",
  )
}

///|
test "pretty runtime errors" {
  inspect(
    @prettyprinter.render(InvalidRuntimeValue(message="not callable")),
    content="invalid_runtime_value \"not callable\"",
  )
}

///|
test "evaluate source generic call and unsafe builtin" {
  let program = expect_anf_program(
    (
      #|fn[A] id(value : A) -> A {
      #|  value
      #|}
      #|let answer : Int = id(builtin("%answer"))
    ),
  )
  let answer = expect_top_level_value(program, "answer")
  let runtime = evaluate_anf_program(program, answer_builtins())
  inspect(
    @prettyprinter.render(runtime.lookup_value(answer), width=80),
    content="int 42",
  )
}

///|
test "evaluate existential struct package without runtime witnesses" {
  let program = expect_anf_program(
    (
      #|struct Hide {
      #|  type T : Type
      #|  val : T
      #|}
      #|let packed : Hide = Hide::{ T = Int, val: builtin("%answer") }
    ),
  )
  let packed = expect_top_level_value(program, "packed")
  let runtime = evaluate_anf_program(program, answer_builtins())
  inspect(
    @prettyprinter.render(runtime.lookup_value(packed), width=80),
    content=(
      #|struct_value type#0 {
      #|  field field#0 val {
      #|    int 42
      #|  }
      #|}
    ),
  )
}

///|
test "evaluate existential enum match and repack" {
  let program = expect_anf_program(
    (
      #|enum Packed {
      #|  hide[T](T)
      #|}
      #|fn repack(p : Packed) -> Packed {
      #|  match p {
      #|    Packed::hide[T](value) => Packed::hide[T](value)
      #|  }
      #|}
      #|let packed : Packed = repack(Packed::hide[Int](builtin("%answer")))
    ),
  )
  let packed = expect_top_level_value(program, "packed")
  let runtime = evaluate_anf_program(program, answer_builtins())
  inspect(
    @prettyprinter.render(runtime.lookup_value(packed), width=80),
    content=(
      #|variant_value variant#0 {
      #|  int 42
      #|}
    ),
  )
}

///|
test "evaluate existential struct pattern opening and repack" {
  let program = expect_anf_program(
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
      #|let packed : Hide = repack(Hide::{ T = Int, val: builtin("%answer") })
    ),
  )
  let packed = expect_top_level_value(program, "packed")
  let runtime = evaluate_anf_program(program, answer_builtins())
  inspect(
    @prettyprinter.render(runtime.lookup_value(packed), width=80),
    content=(
      #|struct_value type#0 {
      #|  field field#0 val {
      #|    int 42
      #|  }
      #|}
    ),
  )
}

///|
test "evaluate buslane external call" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let external = metadata.define_value(External, Function([], Primitive(Int)))
  let result = metadata.define_value(Value, Primitive(Int))
  let program = @buslane.Program::{
    metadata,
    terms: [External(external), Let(result, Call(Ref(external), []))],
  }
  let runtime = @buslane_interpreter.BuslaneExternalRuntime()
  runtime.add_resolver((id, _type) => {
    if id != external {
      abort("unexpected Buslane external")
    }
    @buslane_interpreter.BuslaneRuntimeValue::native_function(arguments => {
      if !arguments.is_empty() {
        abort("unexpected Buslane external arguments")
      }
      @buslane_interpreter.BuslaneRuntimeValue::int(42L)
    })
  })
  let evaluated = @buslane_interpreter.evaluate_buslane_program(
    program, runtime,
  )
  inspect(
    @prettyprinter.render(evaluated.lookup(result), width=80),
    content="int 42",
  )
}

///|
test "evaluate buslane nominal data match" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let option_parameter = metadata.define_type_parameter(Type)
  let option_type = metadata.define_type([option_parameter])
  let some = metadata.define_data_constructor(option_type, [], [
    Parameter(option_parameter),
  ])
  let option_int = @buslane.Type::Apply(Constructor(option_type), [
    Primitive(Int),
  ])
  let scrutinee = metadata.define_value(Value, option_int)
  let result = metadata.define_value(Value, Primitive(Int))
  let binder = metadata.define_value(MatchBinder, option_int)
  let payload = metadata.define_value(MatchBinder, Primitive(Int))
  let program = @buslane.Program::{
    metadata,
    terms: [
      Let(
        scrutinee,
        Construct({
          data_constructor: some,
          type_arguments: [Primitive(Int)],
          hidden_witnesses: [],
          payloads: [Literal(Int(7L))],
        }),
      ),
      Let(
        result,
        Match({
          scrutinee: Ref(scrutinee),
          binder,
          result_type: Primitive(Int),
          alternatives: [
            {
              alt_constructor: DataCon(some),
              type_binders: [],
              value_binders: [payload],
              body: Ref(payload),
            },
          ],
        }),
      ),
    ],
  }
  let evaluated = @buslane_interpreter.evaluate_buslane_program(
    program,
    BuslaneExternalRuntime(),
  )
  inspect(
    @prettyprinter.render(evaluated.lookup(result), width=80),
    content="int 7",
  )
}

///|
test "evaluate source field access through buslane selector" {
  let program = expect_buslane_program(
    (
      #|struct Point {
      #|  x : Int
      #|  y : Int
      #|}
      #|let answer : Int = Point::{ x: 1, y: 2 }.x
    ),
  )
  let answer = expect_last_buslane_let(program)
  let evaluated = @buslane_interpreter.evaluate_buslane_program(
    program,
    BuslaneExternalRuntime(),
  )
  inspect(
    @prettyprinter.render(evaluated.lookup(answer), width=80),
    content="int 1",
  )
}
