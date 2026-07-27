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
