///|
/// Round-trip is a property of the notation, not of a sample. A renderer and a
/// parser agree only if every AST constructor survives every position it can
/// occupy, so the tables below are that matrix: one representative per
/// constructor, one embedding per grammar position, and the tests take the
/// cross product. A construct that reads back as a different tree is as much a
/// failure as one that does not read back at all.
fn round_trip_failures(failures : Array[String], subject : String) -> Unit {
  if failures.length() > 0 {
    abort(
      "\{subject}: \{failures.length()} round-trip failures\n" +
      failures.join("\n"),
    )
  }
}

///|
fn writer() -> CanonicalTextWriter {
  CanonicalTextWriter()
}

///|
test "buslane text round-trips metadata allocator state" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  metadata.name_allocator = Fresh(@buslane.BuslaneUnique::from_int(7).unwrap())
  let program : @buslane.Program = { metadata, terms: [] }
  let text = writer().write_program(program)
  let decoded = match parse_program_text(text) {
    Ok(decoded) => decoded
    Err(message) => abort(message + "\n" + text)
  }
  assert_program_equal(decoded, program)

  metadata.name_allocator = Fresh(
    @buslane.BuslaneUnique::from_int(0x7FFFFFFF).unwrap(),
  )
  ignore(metadata.define_value("last", Value, Primitive(Unit)))
  let exhausted : @buslane.Program = { metadata, terms: [] }
  let exhausted_text = writer().write_program(exhausted)
  let exhausted_decoded = match parse_program_text(exhausted_text) {
    Ok(decoded) => decoded
    Err(message) => abort(message + "\n" + exhausted_text)
  }
  assert_program_equal(exhausted_decoded, exhausted)
}

// -- types ------------------------------------------------------------------

///|
/// Every `Type` constructor, including the shapes whose child lists are empty.
/// An empty binder list and an empty argument list are values the AST admits,
/// so the text language owes them a spelling.
fn type_forms() -> Array[(String, @buslane.Type)] {
  [
    ("primitive", Primitive(I64)),
    ("parameter", Parameter({ index: 7 })),
    ("constructor", Constructor({ index: 7 })),
    ("apply", Apply(Constructor({ index: 7 }), [TypeArgument(Primitive(Bool))])),
    (
      "apply of an effect",
      Apply(Constructor({ index: 7 }), [EffectArgument(Builtin(Io))]),
    ),
    ("apply without arguments", Apply(Constructor({ index: 7 }), [])),
    ("type lambda", TypeLambda([{ index: 7 }], Parameter({ index: 7 }))),
    ("type lambda without parameters", TypeLambda([], Primitive(Bool))),
    ("function", Function([Primitive(I64)], Primitive(Bool), Empty)),
    ("function without parameters", Function([], Primitive(Bool), Empty)),
    (
      "function with a latent effect",
      Function([Primitive(I64)], Primitive(Bool), Builtin(Io)),
    ),
    ("forall", Forall([{ index: 7 }], Parameter({ index: 7 }))),
    ("forall without parameters", Forall([], Primitive(Bool))),
  ]
}

///|
/// Every position the grammar lets a type occupy.
fn type_contexts() -> Array[(String, (@buslane.Type) -> @buslane.Type)] {
  [
    ("on its own", hole => hole),
    (
      "as an application callee",
      hole => Apply(hole, [TypeArgument(Primitive(I64))]),
    ),
    (
      "as a type argument",
      hole => Apply(Constructor({ index: 1 }), [TypeArgument(hole)]),
    ),
    (
      "as a function parameter",
      hole => Function([hole], Primitive(Unit), Empty),
    ),
    ("as a function result", hole => Function([Primitive(I64)], hole, Empty)),
    (
      "as a function result under a latent effect",
      hole => Function([Primitive(I64)], hole, Builtin(Io)),
    ),
    ("as a forall body", hole => Forall([{ index: 1 }], hole)),
    ("as a type lambda body", hole => TypeLambda([{ index: 1 }], hole)),
    (
      "as an effect's type argument",
      hole => {
        Function(
          [],
          Primitive(Unit),
          Singleton({ index: 1 }, [TypeArgument(hole)]),
        )
      },
    ),
  ]
}

///|
test "buslane text round-trips every type constructor in every position" {
  let failures = []
  for form in type_forms() {
    for context in type_contexts() {
      let (form_label, form_type) = form
      let (context_label, embed) = context
      let subject = embed(form_type)
      let text = writer().write_type(subject)
      match parse_type_text(text) {
        Err(message) =>
          failures.push(
            "\{form_label} \{context_label}: \{message} in `\{text}`",
          )
        Ok(decoded) =>
          if decoded != subject {
            failures.push(
              "\{form_label} \{context_label}: `\{text}` reads back as another type",
            )
          }
      }
    }
  }
  round_trip_failures(failures, "types")
}

// -- effects ----------------------------------------------------------------

///|
fn effect_forms() -> Array[(String, @buslane.Effect)] {
  [
    ("empty", Empty),
    ("io", Builtin(Io)),
    ("panic", Builtin(Panic)),
    ("singleton", Singleton({ index: 7 }, [])),
    (
      "singleton with arguments",
      Singleton({ index: 7 }, [TypeArgument(Primitive(I64))]),
    ),
    ("parameter", Parameter({ index: 7 })),
    ("union", Union([Builtin(Io), Parameter({ index: 7 })])),
    ("union of one", Union([Builtin(Io)])),
    ("nested union", Union([Union([Builtin(Io)]), Empty])),
  ]
}

///|
/// `Union([])` is absent above because it is not a Buslane effect: a union is
/// a row of members and the empty row is `Empty`, so the notation has one
/// spelling for it and the verifier rejects the other encoding.
test "buslane text spells one empty effect row" {
  let empty_union : @buslane.Effect = Union([])
  let written = writer().write_type(Function([], Primitive(Unit), empty_union))
  assert_eq(written, "() -> Unit ! {}")
  assert_eq(parse_type_text(written), Ok(Function([], Primitive(Unit), Empty)))
}

///|
/// An effect only ever appears inside a type, so each context returns the type
/// that carries it.
fn effect_contexts() -> Array[(String, (@buslane.Effect) -> @buslane.Type)] {
  [
    ("as a latent effect", hole => Function([], Primitive(Unit), hole)),
    (
      "as a union member",
      hole => Function([], Primitive(Unit), Union([hole, Builtin(Io)])),
    ),
    (
      "as an effect argument",
      hole => Apply(Constructor({ index: 1 }), [EffectArgument(hole)]),
    ),
    (
      "as an effect's effect argument",
      hole => {
        Function(
          [],
          Primitive(Unit),
          Singleton({ index: 1 }, [EffectArgument(hole)]),
        )
      },
    ),
  ]
}

///|
test "buslane text round-trips every effect constructor in every position" {
  let failures = []
  for form in effect_forms() {
    for context in effect_contexts() {
      let (form_label, form_effect) = form
      let (context_label, embed) = context
      let subject = embed(form_effect)
      let text = writer().write_type(subject)
      match parse_type_text(text) {
        Err(message) =>
          failures.push(
            "\{form_label} \{context_label}: \{message} in `\{text}`",
          )
        Ok(decoded) =>
          if decoded != subject {
            failures.push(
              "\{form_label} \{context_label}: `\{text}` reads back as another type",
            )
          }
      }
    }
  }
  round_trip_failures(failures, "effects")
}

// -- expressions ------------------------------------------------------------

///|
fn expr_forms() -> Array[(String, @buslane.Expr)] {
  [
    ("ref", Ref({ index: 7 })),
    ("literal", Literal(I64(7))),
    (
      "function",
      Function({
        parameters: [{ index: 7 }],
        result_type: Primitive(I64),
        body: Ref({ index: 7 }),
      }),
    ),
    ("call", Call(Ref({ index: 7 }), [Literal(I64(1))])),
    ("call without arguments", Call(Ref({ index: 7 }), [])),
    ("type lambda", TypeLambda([{ index: 7 }], Literal(Unit))),
    ("type lambda without parameters", TypeLambda([], Literal(Unit))),
    (
      "type application",
      TypeApply(Ref({ index: 7 }), [TypeArgument(Primitive(I64))]),
    ),
    ("type application without arguments", TypeApply(Ref({ index: 7 }), [])),
    (
      "construct",
      Construct({
        data_constructor: { index: 7 },
        type_arguments: [TypeArgument(Primitive(I64))],
        hidden_witnesses: [],
        payloads: [Literal(I64(1))],
      }),
    ),
    (
      "construct with hidden witnesses",
      Construct({
        data_constructor: { index: 7 },
        type_arguments: [TypeArgument(Primitive(I64))],
        hidden_witnesses: [TypeArgument(Primitive(Bool))],
        payloads: [Literal(I64(1))],
      }),
    ),
    (
      "construct without arguments",
      Construct({
        data_constructor: { index: 7 },
        type_arguments: [],
        hidden_witnesses: [],
        payloads: [],
      }),
    ),
    ("let", Let({ index: 7 }, Literal(I64(1)), Ref({ index: 7 }))),
    (
      "letrec",
      LetRec([{ id: { index: 7 }, rhs: Literal(I64(1)) }], Ref({ index: 7 })),
    ),
    ("letrec without bindings", LetRec([], Literal(Unit))),
    (
      "match",
      Match({
        scrutinee: Literal(I64(1)),
        binder: { index: 7 },
        result_type: Primitive(I64),
        alternatives: [
          {
            alt_constructor: DataCon({ index: 7 }),
            type_binders: [{ index: 7 }],
            value_binders: [{ index: 8 }],
            body: Ref({ index: 8 }),
          },
          {
            alt_constructor: Literal(I64(2)),
            type_binders: [],
            value_binders: [],
            body: Literal(I64(3)),
          },
          {
            alt_constructor: Default,
            type_binders: [],
            value_binders: [],
            body: Literal(I64(4)),
          },
        ],
      }),
    ),
    (
      "match without alternatives",
      Match({
        scrutinee: Literal(I64(1)),
        binder: { index: 7 },
        result_type: Primitive(I64),
        alternatives: [],
      }),
    ),
    (
      "perform",
      Perform({
        operation: { index: 7 },
        effect_arguments: [TypeArgument(Primitive(I64))],
        hidden_witnesses: [TypeArgument(Primitive(Bool))],
        payloads: [Literal(I64(1))],
      }),
    ),
    (
      "perform without arguments",
      Perform({
        operation: { index: 7 },
        effect_arguments: [],
        hidden_witnesses: [],
        payloads: [],
      }),
    ),
    (
      "handle",
      Handle({
        body: Literal(I64(1)),
        result_binder: { index: 7 },
        result_type: Primitive(I64),
        final_body: Ref({ index: 7 }),
        handlers: [
          {
            handled_effect: Singleton({ index: 7 }, []),
            operations: [
              {
                operation: { index: 7 },
                type_binders: [{ index: 7 }],
                payload_binders: [{ index: 8 }],
                resume_binder: { index: 9 },
                body: Call(Resume({ index: 9 }), [Ref({ index: 8 })]),
              },
            ],
          },
        ],
      }),
    ),
    (
      "handle without handlers",
      Handle({
        body: Literal(I64(1)),
        result_binder: { index: 7 },
        result_type: Primitive(I64),
        final_body: Ref({ index: 7 }),
        handlers: [],
      }),
    ),
    ("resume", Resume({ index: 7 })),
  ]
}

///|
fn expr_contexts() -> Array[(String, (@buslane.Expr) -> @buslane.Expr)] {
  [
    ("on its own", hole => hole),
    ("as a call callee", hole => Call(hole, [Literal(I64(1))])),
    ("as a call argument", hole => Call(Ref({ index: 1 }), [hole])),
    (
      "as a type application callee",
      hole => TypeApply(hole, [TypeArgument(Primitive(I64))]),
    ),
    ("as a let initializer", hole => Let({ index: 1 }, hole, Literal(Unit))),
    ("as a let body", hole => Let({ index: 1 }, Literal(Unit), hole)),
    (
      "as a letrec binding",
      hole => LetRec([{ id: { index: 1 }, rhs: hole }], Literal(Unit)),
    ),
    (
      "as a letrec body",
      hole => LetRec([{ id: { index: 1 }, rhs: Literal(Unit) }], hole),
    ),
    (
      "as a function body",
      hole => {
        Function({ parameters: [], result_type: Primitive(I64), body: hole })
      },
    ),
    ("as a type lambda body", hole => TypeLambda([{ index: 1 }], hole)),
    (
      "as a match scrutinee",
      hole => {
        Match({
          scrutinee: hole,
          binder: { index: 1 },
          result_type: Primitive(I64),
          alternatives: [],
        })
      },
    ),
    (
      "as a match alternative body",
      hole => {
        Match({
          scrutinee: Literal(Unit),
          binder: { index: 1 },
          result_type: Primitive(I64),
          alternatives: [
            {
              alt_constructor: Default,
              type_binders: [],
              value_binders: [],
              body: hole,
            },
          ],
        })
      },
    ),
    (
      "as a construct payload",
      hole => {
        Construct({
          data_constructor: { index: 1 },
          type_arguments: [],
          hidden_witnesses: [],
          payloads: [hole],
        })
      },
    ),
    (
      "as a perform payload",
      hole => {
        Perform({
          operation: { index: 1 },
          effect_arguments: [],
          hidden_witnesses: [],
          payloads: [hole],
        })
      },
    ),
    (
      "as a handle body",
      hole => {
        Handle({
          body: hole,
          result_binder: { index: 1 },
          result_type: Primitive(I64),
          final_body: Literal(Unit),
          handlers: [],
        })
      },
    ),
    (
      "as a handle final body",
      hole => {
        Handle({
          body: Literal(Unit),
          result_binder: { index: 1 },
          result_type: Primitive(I64),
          final_body: hole,
          handlers: [],
        })
      },
    ),
    (
      "as an operation alternative body",
      hole => {
        Handle({
          body: Literal(Unit),
          result_binder: { index: 1 },
          result_type: Primitive(I64),
          final_body: Literal(Unit),
          handlers: [
            {
              handled_effect: Singleton({ index: 1 }, []),
              operations: [
                {
                  operation: { index: 1 },
                  type_binders: [],
                  payload_binders: [],
                  resume_binder: { index: 2 },
                  body: hole,
                },
              ],
            },
          ],
        })
      },
    ),
  ]
}

///|
/// An expression is only reachable through a program, so each subject becomes
/// the right-hand side of a top-level binding. The metadata stays empty: this
/// is a test of the notation, not of what the verifier makes of it.
fn expr_program(expr : @buslane.Expr) -> @buslane.Program {
  { metadata: MetadataRegistry(), terms: [Let({ index: 0 }, expr)] }
}

///|
test "buslane text round-trips every expression constructor in every position" {
  let failures = []
  for form in expr_forms() {
    for context in expr_contexts() {
      let (form_label, form_expr) = form
      let (context_label, embed) = context
      let subject = expr_program(embed(form_expr))
      let text = writer().write_program(subject)
      match parse_program_text(text) {
        Err(message) =>
          failures.push(
            "\{form_label} \{context_label}: \{message} in `\{text}`",
          )
        Ok(decoded) =>
          if decoded != subject {
            failures.push(
              "\{form_label} \{context_label}: `\{text}` reads back as another program",
            )
          }
      }
    }
  }
  round_trip_failures(failures, "expressions")
}

///|
/// Alternative bodies and following patterns need an explicit boundary. Without
/// the canonical semicolon, the unit pattern below can be consumed as a call on
/// the preceding reference instead of beginning the second alternative.
test "buslane text keeps a unit alternative after a postfix-capable body" {
  let subject = expr_program(
    Match({
      scrutinee: Literal(Unit),
      binder: { index: 1 },
      result_type: Primitive(Unit),
      alternatives: [
        {
          alt_constructor: Default,
          type_binders: [],
          value_binders: [],
          body: Ref({ index: 1 }),
        },
        {
          alt_constructor: Literal(Unit),
          type_binders: [],
          value_binders: [],
          body: Literal(Unit),
        },
      ],
    }),
  )
  let text = writer().write_program(subject)
  assert_eq(parse_program_text(text), Ok(subject))
}

// -- literals and arbitrary text --------------------------------------------

///|
/// Every `Literal` constructor, with the payloads whose spelling is most
/// likely to be lost: the extremes of each integer width, every float value
/// class, and text carrying the delimiters of the notation itself.
fn literal_forms() -> Array[(String, @buslane.Literal)] {
  [
    ("unit", Unit),
    ("true", Bool(true)),
    ("false", Bool(false)),
    ("i64", I64(7L)),
    ("i64 min", I64(-9223372036854775807L - 1L)),
    ("i64 max", I64(9223372036854775807L)),
    ("i32 min", I32(-2147483647 - 1)),
    ("i32 max", I32(2147483647)),
    ("char", Char(0x1F600)),
    ("char nul", Char(0)),
    ("f64", F64(1.25)),
    ("f64 negative zero", F64(-0.0)),
    ("f64 infinity", F64(0x7ff0000000000000UL.reinterpret_as_double())),
    ("f32", F32(1.25)),
    ("f32 negative zero", F32((-0.0 : Float))),
    ("string", String("plain")),
    ("string, empty", String("")),
    ("string with a quote", String("a\"b")),
    ("string with a backslash", String("a\\b")),
    ("string with a newline", String("a\nb")),
    ("string with a carriage return", String("a\rb")),
    ("string with a tab", String("a\tb")),
    ("string with every escape", String("\\\"\n\r\t")),
    ("string with non-ascii text", String("日本語 🌊")),
  ]
}

///|
test "buslane text round-trips every literal as an expression and a pattern" {
  let failures = []
  for form in literal_forms() {
    let (label, literal) = form
    let subjects : Array[(String, @buslane.Expr)] = [
      ("as an expression", Literal(literal)),
      (
        "as an alternative",
        Match({
          scrutinee: Literal(Unit),
          binder: { index: 1 },
          result_type: Primitive(I64),
          alternatives: [
            {
              alt_constructor: Literal(literal),
              type_binders: [],
              value_binders: [],
              body: Literal(Unit),
            },
          ],
        }),
      ),
    ]
    for subject in subjects {
      let (position, expr) = subject
      let program = expr_program(expr)
      let text = writer().write_program(program)
      match parse_program_text(text) {
        Err(message) =>
          failures.push("\{label} \{position}: \{message} in `\{text}`")
        Ok(decoded) =>
          if decoded != program {
            failures.push(
              "\{label} \{position}: `\{text}` reads back as another program",
            )
          }
      }
    }
  }
  round_trip_failures(failures, "literals")
}

///|
/// NaN is absent from the table above because the AST cannot state the
/// property for it: `Literal` derives its equality from `Double`, and no NaN
/// equals itself. The notation still has to carry the payload, so the property
/// is stated where it is observable, on the bit pattern.
test "buslane text round-trips a NaN payload bit for bit" {
  let payload = 0x7ff8000000000001UL.reinterpret_as_double()
  let program = expr_program(Literal(F64(payload)))
  let text = writer().write_program(program)
  let decoded = match parse_program_text(text) {
    Ok(decoded) => decoded
    Err(message) => abort(message + "\n" + text)
  }
  guard decoded.terms is [Let(_, Literal(F64(read_back)))] else {
    abort("expected a single F64 binding, got\n" + text)
  }
  assert_eq(read_back.reinterpret_as_uint64(), payload.reinterpret_as_uint64())
}

///|
/// The effect a handler names sits in the one effect position that no type
/// contains, so it gets its own pass over the same forms.
test "buslane text round-trips every effect a handler can name" {
  let failures = []
  for form in effect_forms() {
    let (label, handled_effect) = form
    let program = expr_program(
      Handle({
        body: Literal(Unit),
        result_binder: { index: 1 },
        result_type: Primitive(I64),
        final_body: Literal(Unit),
        handlers: [{ handled_effect, operations: [] }],
      }),
    )
    let text = writer().write_program(program)
    match parse_program_text(text) {
      Err(message) => failures.push("\{label}: \{message} in `\{text}`")
      Ok(decoded) =>
        if decoded != program {
          failures.push("\{label}: `\{text}` reads back as another program")
        }
    }
  }
  round_trip_failures(failures, "handled effects")
}

///|
/// A name's occurrence is arbitrary text — generated binders carry characters
/// no identifier syntax admits — so every declaration that prints one has to
/// quote it the way the lexer reads it back.
test "buslane text round-trips awkward names in every declaration" {
  let occurrence = "a\"b\\c\nd\te"
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let parameter = metadata.define_type_parameter(occurrence, Type)
  let owner = metadata.define_type(occurrence, [parameter])
  let _con = metadata.define_data_constructor(occurrence, owner, [], [
    Parameter(parameter),
  ])
  let effect = metadata.define_effect(occurrence, [parameter])
  let _op = metadata.define_operation(
    occurrence,
    effect,
    [],
    [Parameter(parameter)],
    Primitive(Unit),
  )
  let _value = metadata.define_value(occurrence, Value, Primitive(Unit))
  let program : @buslane.Program = { metadata, terms: [] }
  let text = writer().write_program(program)
  let decoded = match parse_program_text(text) {
    Ok(decoded) => decoded
    Err(message) => abort(message + "\n" + text)
  }
  assert_program_equal(decoded, program)
}
