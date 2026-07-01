///|
fn int_type() -> @buslane.Type {
  Primitive(Int)
}

///|
test "buslane text roundtrips function call program" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let value = metadata.define_value(Value, int_type())
  let function = metadata.define_value(
    Function,
    Function([int_type()], int_type(), Empty),
  )
  let parameter = metadata.define_value(Parameter, int_type())
  let program = @buslane.Program::{
    metadata,
    terms: [
      LetRec([
        {
          id: function,
          rhs: Function({
            parameters: [parameter],
            result_type: int_type(),
            body: Ref(parameter),
          }),
        },
      ]),
      Let(value, Call(Ref(function), [Literal(Int(42L))])),
    ],
  }
  let text = CanonicalTextWriter::CanonicalTextWriter().write_program(program)
  let decoded = match parse_program_text(text) {
    Ok(decoded) => decoded
    Err(message) => abort(message + "\n" + text)
  }
  assert_true(decoded == program)
}

///|
test "buslane text roundtrips standalone type" {
  let type_ : @buslane.Type = Forall(
    [{ index: 0 }],
    Function(
      [
        Apply(Constructor({ index: 0 }), [Parameter({ index: 0 })]),
        Function([Primitive(Int)], Primitive(Bool), Empty),
      ],
      Primitive(String),
      Empty,
    ),
  )
  let text = CanonicalTextWriter::CanonicalTextWriter().write_type(type_)
  let decoded = match parse_type_text(text) {
    Ok(decoded) => decoded
    Err(message) => abort(message + "\n" + text)
  }
  assert_true(decoded == type_)
}

///|
test "buslane text roundtrips effectful function type" {
  let type_ : @buslane.Type = Function(
    [Primitive(String)],
    Primitive(Unit),
    Union([Singleton({ index: 0 }, [Primitive(Int)]), Parameter({ index: 0 })]),
  )
  let text = CanonicalTextWriter::CanonicalTextWriter().write_type(type_)
  let decoded = match parse_type_text(text) {
    Ok(decoded) => decoded
    Err(message) => abort(message + "\n" + text)
  }
  assert_true(decoded == type_)
}

///|
test "buslane text roundtrips perform and deep handler syntax" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let console = metadata.define_effect([])
  let print = metadata.define_operation(console, [int_type()], int_type())
  let result = metadata.define_value(Value, int_type())
  let final_binder = metadata.define_value(Local, int_type())
  let payload = metadata.define_value(Parameter, int_type())
  let resume_binder = metadata.define_value(
    Parameter,
    Function([int_type()], int_type(), Empty),
  )
  let program = @buslane.Program::{
    metadata,
    terms: [
      Let(
        result,
        Handle({
          body: Perform({
            operation: print,
            type_arguments: [],
            payloads: [Literal(Int(1L))],
          }),
          result_binder: final_binder,
          result_type: int_type(),
          final_body: Ref(final_binder),
          handlers: [
            {
              handled_effect: Singleton(console, []),
              operations: [
                {
                  operation: print,
                  payload_binders: [payload],
                  resume_binder,
                  body: Call(Resume(resume_binder), [Ref(payload)]),
                },
              ],
            },
          ],
        }),
      ),
    ],
  }
  let text = CanonicalTextWriter::CanonicalTextWriter().write_program(program)
  let decoded = match parse_program_text(text) {
    Ok(decoded) => decoded
    Err(message) => abort(message + "\n" + text)
  }
  assert_true(decoded == program)
}

///|
test "buslane text roundtrips construct and match" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let option_type_parameter = metadata.define_type_parameter(Type)
  let option_type = metadata.define_type([option_type_parameter])
  let some = metadata.define_data_constructor(option_type, [], [
    Parameter(option_type_parameter),
  ])
  let scrutinee = metadata.define_value(
    Value,
    Apply(Constructor(option_type), [int_type()]),
  )
  let match_binder = metadata.define_value(
    MatchBinder,
    Apply(Constructor(option_type), [int_type()]),
  )
  let payload = metadata.define_value(Parameter, int_type())
  let program = @buslane.Program::{
    metadata,
    terms: [
      Let(
        scrutinee,
        Construct({
          data_constructor: some,
          type_arguments: [int_type()],
          hidden_witnesses: [],
          payloads: [Literal(Int(1L))],
        }),
      ),
      Let(
        payload,
        Match({
          scrutinee: Ref(scrutinee),
          binder: match_binder,
          result_type: int_type(),
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
  let text = CanonicalTextWriter::CanonicalTextWriter().write_program(program)
  let decoded = match parse_program_text(text) {
    Ok(decoded) => decoded
    Err(message) => abort(message + "\n" + text)
  }
  assert_true(decoded == program)
}
