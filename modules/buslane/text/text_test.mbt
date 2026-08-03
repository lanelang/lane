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
      #|    external type type#0 = "Fd"#1 {};
      #|    type_parameter tparam#0 = "A"#0 : Type;
      #|    external effect effect#0 = "VectorOp"#2[tparam#0] {};
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
      #|    value value#0 = "value"#0 value : F64;
      #|  }
      #|  let value#0 = f64(0x3ff4000000000000)
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
      #|    value value#0 = "value"#0 value : I32;
      #|  }
      #|  let value#0 = i32(-2147483648)
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
      #|    value value#0 = "value"#0 value : Char;
      #|  }
      #|  let value#0 = char(128512)
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
    "buslane { metadata {} let value#0 = \{literal} }"
  }
  debug_inspect(
    [
      for
        literal in [
          "9223372036854775808", "i32(2147483648)", "f32(0x000000000)", "f64(0x00000000000000000)",
          "char(-1)", "char(55296)", "char(57343)", "char(1114112)",
        ] => parse_program_text(program_with_literal(literal))
    ],
    content=(
      #|[
      #|  Err("invalid i64 literal `9223372036854775808`"),
      #|  Err("invalid i32 literal `2147483648`"),
      #|  Err("invalid f32 bit pattern `0x000000000`"),
      #|  Err("invalid f64 bit pattern `0x00000000000000000`"),
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
  assert_eq(text, "(Byte) -> Bytes")
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

///|
test "buslane text disambiguates a latent effect on nested arrows" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let inner = metadata.define_effect("Inner", [])
  let outer = metadata.define_effect("Outer", [])
  let nested : @buslane.Type = Function(
    [Primitive(I64)],
    Function([Primitive(Bool)], Primitive(Unit), Singleton(inner, [])),
    Singleton(outer, []),
  )
  let writer = CanonicalTextWriter::CanonicalTextWriter()
  // Without the parentheses each `!` could attach to either arrow.
  assert_eq(
    writer.write_type(nested),
    "(I64) -> ((Bool) -> Unit ! effect#0) ! effect#1",
  )
  assert_eq(parse_type_text(writer.write_type(nested)), Ok(nested))
  // A parenthesized type that no arrow follows is still that type, which is
  // the reading the shared parenthesis production has to preserve.
  assert_eq(parse_type_text("(I64)"), Ok(Primitive(I64)))
  assert_eq(
    parse_type_text("(I64) -> Unit"),
    Ok(Function([Primitive(I64)], Primitive(Unit), Empty)),
  )
}

///|
test "buslane text roundtrips flavors, hidden witnesses, and handlers" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let element = metadata.define_type_parameter("T", Type)
  let hidden = metadata.define_type_parameter("H", Type)
  let residual = metadata.define_type_parameter("R", Effect, flavor=External)
  let box = metadata.define_type("Box", [element])
  let con = metadata.define_data_constructor("Box", box, [hidden], [
    Parameter(hidden),
  ])
  let _fd = metadata.define_type("Fd", [], flavor=External)
  let state = metadata.define_effect("State", [element])
  let op = metadata.define_operation(
    "get",
    state,
    [hidden],
    [Parameter(hidden)],
    Parameter(element),
  )
  let _host = metadata.define_effect("Host", [], flavor=External)
  let box_i64 : @buslane.Type = Apply(Constructor(box), [
    TypeArgument(Primitive(I64)),
  ])
  let main = metadata.define_value(
    "main",
    Function,
    Function([], Primitive(I64), Empty),
  )
  let stored = metadata.define_value("stored", Local, box_i64)
  let matched = metadata.define_value("matched", MatchBinder, box_i64)
  let payload = metadata.define_value("payload", MatchBinder, Primitive(I64))
  let result = metadata.define_value("result", MatchBinder, Primitive(I64))
  let op_payload = metadata.define_value("op", MatchBinder, Primitive(I64))
  let resume_binder = metadata.define_value(
    "resume",
    MatchBinder,
    Function([Primitive(I64)], Primitive(I64), Empty),
  )
  let polymorphic = metadata.define_value(
    "polymorphic",
    Function,
    Forall([residual], Function([], Primitive(Unit), Parameter(residual))),
  )
  let program : @buslane.Program = {
    metadata,
    terms: [
      Let(
        main,
        Function({
          parameters: [],
          result_type: Primitive(I64),
          body: Let(
            stored,
            Construct({
              data_constructor: con,
              type_arguments: [TypeArgument(Primitive(I64))],
              hidden_witnesses: [TypeArgument(Primitive(I64))],
              payloads: [Literal(I64(1))],
            }),
            Handle({
              body: Match({
                scrutinee: Ref(stored),
                binder: matched,
                result_type: Primitive(I64),
                alternatives: [
                  {
                    alt_constructor: DataCon(con),
                    type_binders: [hidden],
                    value_binders: [payload],
                    body: Ref(payload),
                  },
                  {
                    alt_constructor: Literal(I64(2)),
                    type_binders: [],
                    value_binders: [],
                    body: Literal(I32(3)),
                  },
                  {
                    alt_constructor: Default,
                    type_binders: [],
                    value_binders: [],
                    body: Perform({
                      operation: op,
                      effect_arguments: [TypeArgument(Primitive(I64))],
                      hidden_witnesses: [TypeArgument(Primitive(Bool))],
                      payloads: [Literal(Bool(true))],
                    }),
                  },
                ],
              }),
              result_binder: result,
              result_type: Primitive(I64),
              final_body: Ref(result),
              handlers: [
                {
                  handled_effect: Singleton(state, [
                    TypeArgument(Primitive(I64)),
                  ]),
                  operations: [
                    {
                      operation: op,
                      type_binders: [hidden],
                      payload_binders: [op_payload],
                      resume_binder,
                      body: Call(Resume(resume_binder), [Ref(op_payload)]),
                    },
                  ],
                },
              ],
            }),
          ),
        }),
      ),
      LetRec([
        {
          id: polymorphic,
          rhs: TypeLambda(
            [residual],
            Function({
              parameters: [],
              result_type: Primitive(Unit),
              body: Literal(Unit),
            }),
          ),
        },
      ]),
    ],
  }
  let text = CanonicalTextWriter::CanonicalTextWriter().write_program(program)
  let decoded = match parse_program_text(text) {
    Ok(decoded) => decoded
    Err(message) => abort(message + "\n" + text)
  }
  assert_program_equal(decoded, program)
}
