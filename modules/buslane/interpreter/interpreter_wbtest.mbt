///|
fn int_type() -> @buslane.Type {
  Primitive(Int)
}

///|
fn string_type() -> @buslane.Type {
  Primitive(String)
}

///|
fn unit_type() -> @buslane.Type {
  Primitive(Unit)
}

///|
test "runtime reports unhandled operation" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let console = metadata.define_effect("Effect", [])
  let print = metadata.define_operation(
    "op",
    console,
    [],
    [int_type()],
    int_type(),
  )
  let error = try {
    ignore(
      evaluate_buslane_expr(
        Perform({
          operation: print,
          effect_arguments: [],
          hidden_witnesses: [],
          payloads: [Literal(Int(1L))],
        }),
        BuslaneRuntimeEnvironment(),
        BuslaneExternalRuntime(),
      ),
    )
    abort("expected unhandled operation")
  } catch {
    error => error
  }
  inspect(
    @prettyprinter.render(error, width=100),
    content="unhandled_operation operation#0",
  )
}

///|
test "runtime effect handler handles operation at host boundary" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let write = metadata.define_effect("Write", [])
  let println = metadata.define_operation(
    "println",
    write,
    [],
    [string_type()],
    unit_type(),
  )
  let output : Array[String] = []
  let runtime = BuslaneExternalRuntime::BuslaneExternalRuntime()
  runtime.add_effect_handler(println, fn(arguments) raise BuslaneRuntimeError {
    guard arguments[0].as_string() is Some(line) else {
      raise InvalidValue(message="println payload is not a string")
    }
    output.push(line)
    BuslaneRuntimeValue::unit()
  })
  let evaluated = evaluate_buslane_expr(
    Perform({
      operation: println,
      effect_arguments: [],
      hidden_witnesses: [],
      payloads: [Literal(String("hello"))],
    }),
    BuslaneRuntimeEnvironment(),
    runtime,
  )
  inspect(@prettyprinter.render(evaluated, width=80), content="unit")
  inspect(output.join("\n"), content="hello")
}

///|
test "source effect handler takes precedence over runtime effect handler" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let write = metadata.define_effect("Write", [])
  let println = metadata.define_operation(
    "println",
    write,
    [],
    [string_type()],
    unit_type(),
  )
  let final_binder = metadata.define_value("result", Local, unit_type())
  let payload = metadata.define_value("line", Parameter, string_type())
  let resume_binder = metadata.define_value(
    "resume",
    Parameter,
    Function([unit_type()], unit_type(), Empty),
  )
  let output : Array[String] = []
  let runtime = BuslaneExternalRuntime::BuslaneExternalRuntime()
  runtime.add_effect_handler(println, fn(arguments) raise BuslaneRuntimeError {
    guard arguments[0].as_string() is Some(line) else {
      raise InvalidValue(message="println payload is not a string")
    }
    output.push(line)
    BuslaneRuntimeValue::unit()
  })
  let evaluated = evaluate_buslane_expr(
    Handle({
      body: Perform({
        operation: println,
        effect_arguments: [],
        hidden_witnesses: [],
        payloads: [Literal(String("source"))],
      }),
      result_binder: final_binder,
      result_type: unit_type(),
      final_body: Ref(final_binder),
      handlers: [
        {
          handled_effect: Singleton(write, []),
          operations: [
            {
              operation: println,
              type_binders: [],
              payload_binders: [payload],
              resume_binder,
              body: Literal(Unit),
            },
          ],
        },
      ],
    }),
    BuslaneRuntimeEnvironment(),
    runtime,
  )
  inspect(@prettyprinter.render(evaluated, width=80), content="unit")
  inspect(output.join("\n"), content="")
}

///|
test "runtime effect handler registration is validated before execution" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let result = metadata.define_value("result", Value, unit_type())
  let program = @buslane.Program::{
    metadata,
    terms: [Let(result, Literal(Unit))],
  }
  let runtime = BuslaneExternalRuntime::BuslaneExternalRuntime()
  runtime.add_effect_handler({ index: 7 }, fn(_) { BuslaneRuntimeValue::unit() })
  let error = try {
    ignore(evaluate_buslane_program(program, runtime))
    abort("expected invalid runtime effect handler")
  } catch {
    error => error
  }
  inspect(
    @prettyprinter.render(error, width=100),
    content="invalid_runtime_effect_handler operation#7",
  )
}
