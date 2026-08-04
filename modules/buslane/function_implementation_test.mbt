///|
fn nullary_int_function_type(effect : Effect) -> Type {
  Function([], Primitive(I64), effect)
}

///|
fn constant_int_function() -> Expr {
  Function({
    parameters: [],
    result_type: Primitive(I64),
    body: Literal(I64(0L)),
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
    Forall([expected_parameter], Function([], Primitive(I64), Empty)),
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
              result_type: Primitive(I64),
              body: Literal(I64(0L)),
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
      #|    expected forall [tparam#0]. () -> I64
      #|    actual forall [tparam#1]. () -> I64
      #|  } at term value#0 / type_lambda
      #|}
    ),
  )
}

///|
test "verify buslane exact binding compares forall binder kinds" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let expected_parameter = metadata.define_type_parameter("A", Type)
  let actual_parameter = metadata.define_type_parameter("E", Effect)
  let expected_type = Type::Forall(
    [expected_parameter],
    Function([], Primitive(I64), Empty),
  )
  let actual_type = Type::Forall(
    [actual_parameter],
    Function([], Primitive(I64), Empty),
  )
  let initializer = metadata.define_value("initializer", External, actual_type)
  let binding = metadata.define_value("binding", Value, expected_type)
  let program = Program::{
    metadata,
    terms: [External(initializer), Let(binding, Ref(initializer))],
  }
  inspect(
    @prettyprinter.render(verify_program(program), width=100),
    content=(
      #|verify_result {
      #|  type_mismatch {
      #|    expected forall [tparam#0]. () -> I64
      #|    actual forall [tparam#1]. () -> I64
      #|  } at term value#1 / ref value#0
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
    Function([], Primitive(I64), Empty),
  )
  let actual_argument = Type::Forall(
    [actual_parameter],
    Function([], Primitive(I64), Empty),
  )
  let function = metadata.define_value(
    "function",
    Function,
    Function([expected_argument], Primitive(I64), Empty),
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
            result_type: Primitive(I64),
            body: Literal(I64(0L)),
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
      #|    expected (forall [tparam#0]. () -> I64) -> I64
      #|    actual (forall [tparam#1]. () -> I64) -> I64
      #|  } at term value#0 / fn
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
      #|    expected () -> I64 ! effect#0
      #|    actual () -> I64
      #|  } at term value#0 / fn
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
      #|    expected () -> I64 ! effect#0
      #|    actual () -> I64
      #|  } at term value#1 / ref value#0
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
  let result = metadata.define_value("result", Value, Primitive(I64))
  let program = Program::{
    metadata,
    terms: [
      Let(
        result,
        LetRec(
          [{ id: local_function, rhs: constant_int_function() }],
          Literal(I64(0L)),
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
