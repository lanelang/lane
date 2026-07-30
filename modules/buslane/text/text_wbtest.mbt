///|
fn i64_type() -> @buslane.Type {
  Primitive(I64)
}

///|
fn f64_type() -> @buslane.Type {
  Primitive(F64)
}

///|
fn assert_program_equal(
  actual : @buslane.Program,
  expected : @buslane.Program,
) -> Unit {
  if actual != expected {
    abort(
      "expected equal buslane programs\nactual:\n" +
      @prettyprinter.render(actual, width=100) +
      "\nexpected:\n" +
      @prettyprinter.render(expected, width=100),
    )
  }
}

///|
fn assert_type_equal(actual : @buslane.Type, expected : @buslane.Type) -> Unit {
  if actual != expected {
    abort(
      "expected equal buslane types\nactual:\n" +
      @prettyprinter.render(actual, width=100) +
      "\nexpected:\n" +
      @prettyprinter.render(expected, width=100),
    )
  }
}

///|
test "buslane text roundtrips function call program" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let value = metadata.define_value("value", Value, i64_type())
  let function = metadata.define_value(
    "value",
    Function,
    Function([i64_type()], i64_type(), Empty),
  )
  let parameter = metadata.define_value("value", Parameter, i64_type())
  let program = @buslane.Program::{
    metadata,
    terms: [
      LetRec([
        {
          id: function,
          rhs: Function({
            parameters: [parameter],
            result_type: i64_type(),
            body: Ref(parameter),
          }),
        },
      ]),
      Let(value, Call(Ref(function), [Literal(I64(42L))])),
    ],
  }
  let text = CanonicalTextWriter::CanonicalTextWriter().write_program(program)
  let decoded = match parse_program_text(text) {
    Ok(decoded) => decoded
    Err(message) => abort(message + "\n" + text)
  }
  assert_program_equal(decoded, program)
}

///|
test "buslane text roundtrips external metadata flavors" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let type_parameter = metadata.define_type_parameter("A", Type)
  let fd_type = metadata.define_type("Fd", [], flavor=External)
  let vector_op = metadata.define_effect(
    "VectorOp",
    [type_parameter],
    flavor=External,
  )
  let program = @buslane.Program::{ metadata, terms: [] }
  let text = CanonicalTextWriter::CanonicalTextWriter().write_program(program)
  inspect(
    text,
    content=(
      #|buslane {
      #|  metadata {
      #|    external type type#0 name "Fd" unique 1 parameters [] constructors [];
      #|    type_parameter tparam#0 name "A" unique 0 : Type;
      #|    external effect effect#0 name "VectorOp" unique 2 parameters [tparam#0] operations [];
      #|  }
      #|}
    ),
  )
  let decoded = match parse_program_text(text) {
    Ok(decoded) => decoded
    Err(message) => abort(message + "\n" + text)
  }
  assert_program_equal(decoded, program)
  debug_inspect(
    (
      decoded.metadata.type_info(fd_type).map(info => info.flavor),
      decoded.metadata.effect_info(vector_op).map(info => info.flavor),
    ),
    content="(Some(External), Some(External))",
  )
}

///|
test "buslane text roundtrips standalone type" {
  let type_ : @buslane.Type = Forall(
    [{ index: 0 }],
    Function(
      [
        Apply(Constructor({ index: 0 }), [TypeArgument(Parameter({ index: 0 }))]),
        Function([Primitive(I64)], Primitive(Bool), Empty),
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
  assert_type_equal(decoded, type_)
}

///|
test "buslane text roundtrips F64 primitive and literal" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let value = metadata.define_value("value", Value, f64_type())
  let program = @buslane.Program::{
    metadata,
    terms: [Let(value, Literal(F64(1.25)))],
  }
  let text = CanonicalTextWriter::CanonicalTextWriter().write_program(program)
  inspect(
    text,
    content=(
      #|buslane {
      #|  metadata {
      #|    value value#0 name "value" unique 0 value : F64;
      #|  }
      #|  let value#0 = f64(1.25);
      #|}
    ),
  )
  let decoded = match parse_program_text(text) {
    Ok(decoded) => decoded
    Err(message) => abort(message + "\n" + text)
  }
  assert_program_equal(decoded, program)
}

///|
test "buslane text roundtrips I32 primitive and literal" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let value = metadata.define_value("value", Value, Primitive(I32))
  let program = @buslane.Program::{
    metadata,
    terms: [Let(value, Literal(I32(-2147483647 - 1)))],
  }
  let text = CanonicalTextWriter::CanonicalTextWriter().write_program(program)
  inspect(
    text,
    content=(
      #|buslane {
      #|  metadata {
      #|    value value#0 name "value" unique 0 value : I32;
      #|  }
      #|  let value#0 = i32(-2147483648);
      #|}
    ),
  )
  let decoded = match parse_program_text(text) {
    Ok(decoded) => decoded
    Err(message) => abort(message + "\n" + text)
  }
  assert_program_equal(decoded, program)
}

///|
test "buslane text roundtrips Char primitive and literal" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let value = metadata.define_value("value", Value, Primitive(Char))
  let program = @buslane.Program::{
    metadata,
    terms: [Let(value, Literal(Char(0x1F600)))],
  }
  let text = CanonicalTextWriter::CanonicalTextWriter().write_program(program)
  inspect(
    text,
    content=(
      #|buslane {
      #|  metadata {
      #|    value value#0 name "value" unique 0 value : Char;
      #|  }
      #|  let value#0 = char(128512);
      #|}
    ),
  )
  let decoded = match parse_program_text(text) {
    Ok(decoded) => decoded
    Err(message) => abort(message + "\n" + text)
  }
  assert_program_equal(decoded, program)
}

///|
test "buslane text rejects invalid numeric and Char literals" {
  let program_with_literal = fn(literal : String) {
    "buslane { metadata {} let value#0 = \{literal}; }"
  }
  debug_inspect(
    [
      for
        literal in [
          "i64(9223372036854775808)", "i32(2147483648)", "f32(3.5e38)", "f64(1e999999)",
          "char(-1)", "char(55296)", "char(57343)", "char(1114112)",
        ] => parse_program_text(program_with_literal(literal))
    ],
    content=(
      #|[
      #|  Err("invalid i64 literal `9223372036854775808`"),
      #|  Err("invalid i32 literal `2147483648`"),
      #|  Err("invalid f32 literal `3.5e38`"),
      #|  Err("invalid f64 literal `1e999999`"),
      #|  Err("Char literal `-1` is not a Unicode scalar value"),
      #|  Err("Char literal `55296` is not a Unicode scalar value"),
      #|  Err("Char literal `57343` is not a Unicode scalar value"),
      #|  Err("Char literal `1114112` is not a Unicode scalar value"),
      #|]
    ),
  )
}

///|
test "buslane text roundtrips Byte and Bytes primitives" {
  let type_ : @buslane.Type = Function(
    [Primitive(Byte)],
    Primitive(Bytes),
    Empty,
  )
  let text = CanonicalTextWriter::CanonicalTextWriter().write_type(type_)
  assert_eq(text, "fn_type([Byte], Bytes)")
  let decoded = match parse_type_text(text) {
    Ok(decoded) => decoded
    Err(message) => abort(message + "\n" + text)
  }
  assert_type_equal(decoded, type_)
}

///|
test "buslane text roundtrips effectful function type" {
  let type_ : @buslane.Type = Function(
    [Primitive(String)],
    Primitive(Unit),
    Union([
      Io,
      Singleton({ index: 0 }, [TypeArgument(Primitive(I64))]),
      Parameter({ index: 0 }),
    ]),
  )
  let text = CanonicalTextWriter::CanonicalTextWriter().write_type(type_)
  let decoded = match parse_type_text(text) {
    Ok(decoded) => decoded
    Err(message) => abort(message + "\n" + text)
  }
  assert_type_equal(decoded, type_)
}

///|
test "buslane text roundtrips perform and deep handler syntax" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let console = metadata.define_effect("Effect", [])
  let print = metadata.define_operation(
    "op",
    console,
    [],
    [i64_type()],
    i64_type(),
  )
  let result = metadata.define_value("value", Value, i64_type())
  let final_binder = metadata.define_value("value", Local, i64_type())
  let payload = metadata.define_value("value", Parameter, i64_type())
  let resume_binder = metadata.define_value(
    "value",
    Parameter,
    Function([i64_type()], i64_type(), Empty),
  )
  let program = @buslane.Program::{
    metadata,
    terms: [
      Let(
        result,
        Handle({
          body: Perform({
            operation: print,
            effect_arguments: [],
            hidden_witnesses: [],
            payloads: [Literal(I64(1L))],
          }),
          result_binder: final_binder,
          result_type: i64_type(),
          final_body: Ref(final_binder),
          handlers: [
            {
              handled_effect: Singleton(console, []),
              operations: [
                {
                  operation: print,
                  type_binders: [],
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
  assert_program_equal(decoded, program)
}

///|
test "buslane text roundtrips polymorphic operation witnesses" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let operation_type_parameter = metadata.define_type_parameter("T", Type)
  let prompt = metadata.define_effect("Prompt", [])
  let choose = metadata.define_operation(
    "choose",
    prompt,
    [operation_type_parameter],
    [Parameter(operation_type_parameter), Parameter(operation_type_parameter)],
    Parameter(operation_type_parameter),
  )
  let result = metadata.define_value("result", Value, i64_type())
  let final_binder = metadata.define_value("value", Local, i64_type())
  let arm_type_binder = metadata.define_type_parameter("T", Type)
  let left = metadata.define_value(
    "left",
    Parameter,
    Parameter(arm_type_binder),
  )
  let right = metadata.define_value(
    "right",
    Parameter,
    Parameter(arm_type_binder),
  )
  let resume_binder = metadata.define_value(
    "resume",
    Parameter,
    Function([Parameter(arm_type_binder)], i64_type(), Empty),
  )
  let program = @buslane.Program::{
    metadata,
    terms: [
      Let(
        result,
        Handle({
          body: Perform({
            operation: choose,
            effect_arguments: [],
            hidden_witnesses: [TypeArgument(i64_type())],
            payloads: [Literal(I64(40L)), Literal(I64(41L))],
          }),
          result_binder: final_binder,
          result_type: i64_type(),
          final_body: Ref(final_binder),
          handlers: [
            {
              handled_effect: Singleton(prompt, []),
              operations: [
                {
                  operation: choose,
                  type_binders: [arm_type_binder],
                  payload_binders: [left, right],
                  resume_binder,
                  body: Call(Resume(resume_binder), [Ref(left)]),
                },
              ],
            },
          ],
        }),
      ),
    ],
  }
  debug_inspect(@buslane.verify_program(program), content="{ diagnostics: [] }")
  let text = CanonicalTextWriter::CanonicalTextWriter().write_program(program)
  let decoded = match parse_program_text(text) {
    Ok(decoded) => decoded
    Err(message) => abort(message + "\n" + text)
  }
  assert_program_equal(decoded, program)
  debug_inspect(@buslane.verify_program(decoded), content="{ diagnostics: [] }")
}

///|
test "buslane text roundtrips construct and match" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let option_type_parameter = metadata.define_type_parameter("T", Type)
  let option_type = metadata.define_type("Type", [option_type_parameter])
  let some = metadata.define_data_constructor("Con", option_type, [], [
    Parameter(option_type_parameter),
  ])
  let scrutinee = metadata.define_value(
    "value",
    Value,
    Apply(Constructor(option_type), [TypeArgument(i64_type())]),
  )
  let match_binder = metadata.define_value(
    "value",
    MatchBinder,
    Apply(Constructor(option_type), [TypeArgument(i64_type())]),
  )
  let payload = metadata.define_value("value", Parameter, i64_type())
  let program = @buslane.Program::{
    metadata,
    terms: [
      Let(
        scrutinee,
        Construct({
          data_constructor: some,
          type_arguments: [TypeArgument(i64_type())],
          hidden_witnesses: [],
          payloads: [Literal(I64(1L))],
        }),
      ),
      Let(
        payload,
        Match({
          scrutinee: Ref(scrutinee),
          binder: match_binder,
          result_type: i64_type(),
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
  assert_program_equal(decoded, program)
}
