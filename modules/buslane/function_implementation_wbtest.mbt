///|
fn nullary_int_function_type(effect : Effect) -> Type {
  Function([], Primitive(Int), effect)
}

///|
fn constant_int_function() -> Expr {
  Function({
    parameters: [],
    result_type: Primitive(Int),
    body: Literal(Int(0L)),
  })
}

///|
test "verify buslane rejects forall function implementation with mismatched binder kind" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let expected_parameter = metadata.define_type_parameter("A", Type)
  let actual_parameter = metadata.define_type_parameter("E", Effect)
  let function = metadata.define_value(
    "function",
    Function,
    Forall([expected_parameter], Function([], Primitive(Int), Empty)),
  )
  let program = Program::{
    metadata,
    terms: [
      LetRec([
        {
          id: function,
          rhs: TypeLambda(
            [actual_parameter],
            Function({
              parameters: [],
              result_type: Primitive(Int),
              body: Literal(Int(0L)),
            }),
          ),
        },
      ]),
    ],
  }
  inspect(
    @prettyprinter.render(verify_program(program), width=100),
    content=(
      #|verify_result {
      #|  type_mismatch {
      #|    expected forall [tparam#0]. () -> Int
      #|    actual forall [tparam#1]. () -> Int
      #|  }
      #|}
    ),
  )
}

///|
test "verify buslane compares nested forall binder kinds in function implementations" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let expected_parameter = metadata.define_type_parameter("A", Type)
  let actual_parameter = metadata.define_type_parameter("E", Effect)
  let expected_argument = Type::Forall(
    [expected_parameter],
    Function([], Primitive(Int), Empty),
  )
  let actual_argument = Type::Forall(
    [actual_parameter],
    Function([], Primitive(Int), Empty),
  )
  let function = metadata.define_value(
    "function",
    Function,
    Function([expected_argument], Primitive(Int), Empty),
  )
  let parameter = metadata.define_value("parameter", Parameter, actual_argument)
  let program = Program::{
    metadata,
    terms: [
      LetRec([
        {
          id: function,
          rhs: Function({
            parameters: [parameter],
            result_type: Primitive(Int),
            body: Literal(Int(0L)),
          }),
        },
      ]),
    ],
  }
  inspect(
    @prettyprinter.render(verify_program(program), width=100),
    content=(
      #|verify_result {
      #|  type_mismatch {
      #|    expected (forall [tparam#0]. () -> Int) -> Int
      #|    actual (forall [tparam#1]. () -> Int) -> Int
      #|  }
      #|}
    ),
  )
}

///|
test "verify buslane widens a direct non-recursive function implementation" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let read = metadata.define_effect("Read", [])
  let function = metadata.define_value(
    "function",
    Function,
    nullary_int_function_type(Singleton(read, [])),
  )
  let program = Program::{
    metadata,
    terms: [Let(function, constant_int_function())],
  }
  inspect(
    @prettyprinter.render(verify_program(program), width=100),
    content=(
      #|verify_result {}
    ),
  )
}

///|
test "verify buslane keeps direct function-valued value bindings exact" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let read = metadata.define_effect("Read", [])
  let value = metadata.define_value(
    "value",
    Value,
    nullary_int_function_type(Singleton(read, [])),
  )
  let program = Program::{
    metadata,
    terms: [Let(value, constant_int_function())],
  }
  inspect(
    @prettyprinter.render(verify_program(program), width=100),
    content=(
      #|verify_result {
      #|  type_mismatch {
      #|    expected () -> Int ! effect#0
      #|    actual () -> Int
      #|  }
      #|}
    ),
  )
}

///|
test "verify buslane keeps function references exact in non-recursive bindings" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let read = metadata.define_effect("Read", [])
  let narrow = metadata.define_value(
    "narrow",
    External,
    nullary_int_function_type(Empty),
  )
  let wide = metadata.define_value(
    "wide",
    Function,
    nullary_int_function_type(Singleton(read, [])),
  )
  let program = Program::{
    metadata,
    terms: [External(narrow), Let(wide, Ref(narrow))],
  }
  inspect(
    @prettyprinter.render(verify_program(program), width=100),
    content=(
      #|verify_result {
      #|  type_mismatch {
      #|    expected () -> Int ! effect#0
      #|    actual () -> Int
      #|  }
      #|}
    ),
  )
}

///|
test "verify buslane widens a direct local function implementation" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let read = metadata.define_effect("Read", [])
  let local_function = metadata.define_value(
    "local_function",
    Local,
    nullary_int_function_type(Singleton(read, [])),
  )
  let result = metadata.define_value("result", Value, Primitive(Int))
  let program = Program::{
    metadata,
    terms: [
      Let(
        result,
        LetRec(
          [{ id: local_function, rhs: constant_int_function() }],
          Literal(Int(0L)),
        ),
      ),
    ],
  }
  inspect(
    @prettyprinter.render(verify_program(program), width=100),
    content=(
      #|verify_result {}
    ),
  )
}
