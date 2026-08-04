///|
/// Which errors a program produces, for tests whose subject is the rule
/// rather than the path the verifier took to reach it.
fn diagnostic_kinds(result : VerifyResult) -> Array[VerifyDiagnosticKind] {
  result.diagnostics().map(diagnostic => diagnostic.kind)
}

///|
fn i64_type() -> Type {
  Primitive(I64)
}

///|
fn bool_type() -> Type {
  Primitive(Bool)
}

///|
fn assert_type_equal(
  metadata : MetadataRegistry,
  actual : Type,
  expected : Type,
) -> Unit raise TypeNormalizationError {
  if !metadata.types_definitionally_equal(actual, expected) {
    abort(
      "expected equal buslane types\nactual:\n" +
      @prettyprinter.render(actual, width=100) +
      "\nexpected:\n" +
      @prettyprinter.render(expected, width=100),
    )
  }
}

///|
fn assert_effect_equal(
  metadata : MetadataRegistry,
  actual : Effect,
  expected : Effect,
) -> Unit raise TypeNormalizationError {
  if !metadata.effects_definitionally_equal(actual, expected) {
    abort(
      "expected equal buslane effects\nactual:\n" +
      @prettyprinter.render(actual, width=100) +
      "\nexpected:\n" +
      @prettyprinter.render(expected, width=100),
    )
  }
}

///|
test "verify buslane rejects invalid Char literals" {
  for value in [-1, 0xD800, 0xDFFF, 0x110000] {
    let metadata = MetadataRegistry::MetadataRegistry()
    let target = metadata.define_value("target", Value, Primitive(Char))
    let program : Program = {
      metadata,
      terms: [Let(target, Literal(Char(value)))],
    }
    assert_eq(
      @prettyprinter.render(verify_program(program), width=100),
      "verify_result {\n  invalid_char_literal \{value} at term \"target\"#0 (value#0) / literal\n}",
    )
  }
}

///|
test "verify buslane rejects duplicate metadata name uniques" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let type_parameter = metadata.define_type_parameter("T", Type)
  let type_id = metadata.define_type("Type", [type_parameter])
  let data_constructor = metadata.define_data_constructor(
    "constructor",
    type_id,
    [],
    [],
  )
  let value_id = metadata.define_value("value", Value, Primitive(Unit))
  let effect = metadata.define_effect("Effect", [])
  let operation = metadata.define_operation(
    "operation",
    effect,
    [],
    [],
    Primitive(Unit),
  )
  let type_info = metadata.type_info(type_id).unwrap()
  let unique = type_info.name.unique
  let duplicate = fn(name : BuslaneName) { { ..name, unique, } }
  let type_parameter_info = metadata
    .type_parameter_info(type_parameter)
    .unwrap()
  metadata.type_parameters[type_parameter.index] = {
    ..type_parameter_info,
    name: duplicate(type_parameter_info.name),
  }
  let data_constructor_info = metadata
    .data_constructor_info(data_constructor)
    .unwrap()
  metadata.data_constructors[data_constructor.index] = {
    ..data_constructor_info,
    name: duplicate(data_constructor_info.name),
  }
  let value_info = metadata.value_info(value_id).unwrap()
  metadata.values[value_id.index] = {
    ..value_info,
    name: duplicate(value_info.name),
  }
  let effect_info = metadata.effect_info(effect).unwrap()
  metadata.effects[effect.index] = {
    ..effect_info,
    name: duplicate(effect_info.name),
  }
  let operation_info = metadata.operation_info(operation).unwrap()
  metadata.operations[operation.index] = {
    ..operation_info,
    name: duplicate(operation_info.name),
  }
  debug_inspect(
    diagnostic_kinds(verify_program({ metadata, terms: [] })),
    content=(
      #|[
      #|  InvalidMetadataIdentity(DuplicateUnique({ value: 1 })),
      #|  InvalidMetadataIdentity(DuplicateUnique({ value: 1 })),
      #|  InvalidMetadataIdentity(DuplicateUnique({ value: 1 })),
      #|  InvalidMetadataIdentity(DuplicateUnique({ value: 1 })),
      #|  InvalidMetadataIdentity(DuplicateUnique({ value: 1 })),
      #|]
    ),
  )
}

///|
test "verify buslane rejects invalid metadata allocator states" {
  let premature_exhaustion = MetadataRegistry::MetadataRegistry()
  premature_exhaustion.name_allocator = Exhausted
  let repeated = MetadataRegistry::MetadataRegistry()
  ignore(repeated.define_value("value", Value, Primitive(Unit)))
  repeated.name_allocator = Fresh(BuslaneUnique::from_int(0).unwrap())
  debug_inspect(
    [
      diagnostic_kinds(
        verify_program({ metadata: premature_exhaustion, terms: [] }),
      ),
      diagnostic_kinds(verify_program({ metadata: repeated, terms: [] })),
    ],
    content=(
      #|[
      #|  [InvalidMetadataIdentity(AllocatorExhaustedBeforeMaximum(maximum_unique=None))],
      #|  [InvalidMetadataIdentity(NextUniqueNotFresh(next={ value: 0 }, maximum={ value: 0 }))],
      #|]
    ),
  )
}

///|
test "buslane unique rejects a negative value" {
  assert_eq(BuslaneUnique::from_int(-1), None)
}

///|
test "maximum metadata allocator exhausts without overflow" {
  let metadata = MetadataRegistry::MetadataRegistry()
  metadata.name_allocator = Fresh(BuslaneUnique::from_int(0x7FFFFFFF).unwrap())
  let value = metadata.define_value("last", Value, Primitive(Unit))
  assert_eq(metadata.value_info(value).unwrap().name.unique.value, 0x7FFFFFFF)
  assert_true(verify_program({ metadata, terms: [] }).is_ok())
  let before = metadata.snapshot()
  try metadata.define_value("overflow", Value, Primitive(Unit)) catch {
    MetadataNameExhausted => ()
  } noraise {
    _ => fail("expected metadata name allocation to be exhausted")
  }
  assert_eq(metadata, before)
}

///|
test "every metadata definition preserves an exhausted registry" {
  let definitions : Array[
    (MetadataRegistry) -> Unit raise MetadataAllocationError,
  ] = [
    metadata => ignore(metadata.define_type_parameter("T", Type)),
    metadata => ignore(metadata.define_type("Type", [])),
    metadata => {
      ignore(
        metadata.define_data_constructor("constructor", { index: 0 }, [], []),
      )
    },
    metadata => ignore(metadata.define_effect("Effect", [])),
    metadata => {
      ignore(
        metadata.define_operation(
          "operation",
          { index: 0 },
          [],
          [],
          Primitive(Unit),
        ),
      )
    },
    metadata => ignore(metadata.define_value("value", Value, Primitive(Unit))),
  ]
  for definition in definitions {
    let metadata = MetadataRegistry::MetadataRegistry()
    metadata.name_allocator = Exhausted
    let before = metadata.snapshot()
    try definition(metadata) catch {
      MetadataNameExhausted => ()
    } noraise {
      _ => fail("expected metadata name allocation to be exhausted")
    }
    assert_eq(metadata, before)
  }
}

///|
test "buslane metadata owns nominal data shape" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let option_param = metadata.define_type_parameter("T", Type)
  let option_type = metadata.define_type("Type", [option_param])
  let none = metadata.define_data_constructor("Con", option_type, [], [])
  let some = metadata.define_data_constructor("Con", option_type, [], [
    Parameter(option_param),
  ])
  inspect(
    @prettyprinter.render(metadata, width=100),
    content=(
      #|metadata {
      #|  next_unique#4;
      #|  type type#0 = "Type"#1[tparam#0] {datacon#0, datacon#1};
      #|  type_parameter tparam#0 = "T"#0 : Type;
      #|  datacon datacon#0 = "Con"#2() : type#0;
      #|  datacon datacon#1 = "Con"#3(tparam#0) : type#0;
      #|}
    ),
  )
  debug_inspect(
    [
      metadata.data_constructor_info(none).unwrap(),
      metadata.data_constructor_info(some).unwrap(),
    ],
    content=(
      #|[
      #|  {
      #|    name: {
      #|      name_space: DataConstructorName,
      #|      occurrence: "Con",
      #|      unique: { value: 2 },
      #|    },
      #|    owner: { index: 0 },
      #|    hidden_type_parameters: [],
      #|    payload_types: [],
      #|  },
      #|  {
      #|    name: {
      #|      name_space: DataConstructorName,
      #|      occurrence: "Con",
      #|      unique: { value: 3 },
      #|    },
      #|    owner: { index: 0 },
      #|    hidden_type_parameters: [],
      #|    payload_types: [Parameter({ index: 0 })],
      #|  },
      #|]
    ),
  )
}

///|
test "buslane metadata owns effect operation shape" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let state_param = metadata.define_type_parameter("T", Type)
  let row_param = metadata.define_type_parameter("E", Effect)
  let state = metadata.define_effect("Effect", [state_param])
  let get = metadata.define_operation(
    "op",
    state,
    [],
    [],
    Parameter(state_param),
  )
  let put = metadata.define_operation(
    "op",
    state,
    [],
    [Parameter(state_param)],
    Primitive(Unit),
  )
  inspect(
    @prettyprinter.render(metadata, width=100),
    content=(
      #|metadata {
      #|  next_unique#5;
      #|  type_parameter tparam#0 = "T"#0 : Type;
      #|  type_parameter tparam#1 = "E"#1 : Effect;
      #|  effect effect#0 = "Effect"#2[tparam#0] {operation#0, operation#1};
      #|  operation operation#0 = "op"#3() -> tparam#0 : effect#0;
      #|  operation operation#1 = "op"#4(tparam#0) -> Unit : effect#0;
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(
      Effect::Union([
        Singleton(state, [TypeArgument(i64_type())]),
        Parameter(row_param),
      ]),
      width=100,
    ),
    content="{effect#0[I64], tparam#1}",
  )
  debug_inspect(
    metadata.effect_info(state).unwrap(),
    content=(
      #|{
      #|  name: { name_space: EffectName, occurrence: "Effect", unique: { value: 2 } },
      #|  flavor: Algebraic,
      #|  parameters: [{ index: 0 }],
      #|  operations: [{ index: 0 }, { index: 1 }],
      #|}
    ),
  )
  debug_inspect(
    [
      metadata.operation_info(get).unwrap(),
      metadata.operation_info(put).unwrap(),
    ],
    content=(
      #|[
      #|  {
      #|    name: { name_space: OperationName, occurrence: "op", unique: { value: 3 } },
      #|    owner: { index: 0 },
      #|    hidden_type_parameters: [],
      #|    payload_types: [],
      #|    result_type: Parameter({ index: 0 }),
      #|  },
      #|  {
      #|    name: { name_space: OperationName, occurrence: "op", unique: { value: 4 } },
      #|    owner: { index: 0 },
      #|    hidden_type_parameters: [],
      #|    payload_types: [Parameter({ index: 0 })],
      #|    result_type: Primitive(Unit),
      #|  },
      #|]
    ),
  )
}

///|
test "buslane forall equality is alpha equivalent" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let left_param = metadata.define_type_parameter("A", Type)
  let right_param = metadata.define_type_parameter("B", Type)
  let left = Type::Forall([left_param], Parameter(left_param))
  let right = Type::Forall([right_param], Parameter(right_param))
  assert_type_equal(metadata, left, right)
  assert_false(left == right)
}

///|
test "buslane type equality beta normalizes type lambdas" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let parameter = metadata.define_type_parameter("A", Type)
  let lambda = Type::TypeLambda([parameter], Parameter(parameter))
  assert_type_equal(
    metadata,
    Apply(lambda, [TypeArgument(i64_type())]),
    i64_type(),
  )
}

///|
test "buslane function latent effects participate in type equality and substitution" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let left_param = metadata.define_type_parameter("A", Type)
  let right_param = metadata.define_type_parameter("B", Type)
  let effect_parameter = metadata.define_type_parameter("T", Type)
  let effect_id = metadata.define_effect("Effect", [effect_parameter])
  let left = Type::Forall(
    [left_param],
    Function(
      [],
      Parameter(left_param),
      Singleton(effect_id, [TypeArgument(Parameter(left_param))]),
    ),
  )
  let right = Type::Forall(
    [right_param],
    Function(
      [],
      Parameter(right_param),
      Singleton(effect_id, [TypeArgument(Parameter(right_param))]),
    ),
  )
  assert_type_equal(metadata, left, right)
  let left_effect_param = metadata.define_type_parameter("E", Effect)
  let right_effect_param = metadata.define_type_parameter("F", Effect)
  let left_row : Type = Forall(
    [left_effect_param],
    Function([], i64_type(), Parameter(left_effect_param)),
  )
  let right_row : Type = Forall(
    [right_effect_param],
    Function([], i64_type(), Parameter(right_effect_param)),
  )
  assert_type_equal(metadata, left_row, right_row)
  let substitution = TypeSubstitution::TypeSubstitution()
  substitution.insert(left_param, i64_type())
  let effectful : Type = Function(
    [],
    Parameter(left_param),
    Singleton(effect_id, [TypeArgument(Parameter(left_param))]),
  )
  inspect(
    @prettyprinter.render(effectful.substitute(substitution), width=100),
    content="() -> I64 ! effect#0[I64]",
  )
}

///|
test "buslane substitution is simultaneous and capture avoiding" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let element = metadata.define_type_parameter("Element", Type)
  let result = metadata.define_type_parameter("Result", Type)
  let substitution = TypeSubstitution::from_arguments(
    metadata,
    [element, result],
    [
      TypeArgument(i64_type()),
      TypeArgument(Function([Parameter(element)], Parameter(element), Empty)),
    ],
  )
  assert_eq(
    Type::Parameter(result).try_substitute(substitution),
    Function([Parameter(element)], Parameter(element), Empty),
  )
  assert_eq(
    Type::Forall([element], Function([], Parameter(element), Empty)).try_substitute(
      substitution,
    ),
    Forall([element], Function([], Parameter(element), Empty)),
  )
}

///|
test "buslane substitution overlay shadows without mutating its base" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let parameter = metadata.define_type_parameter("T", Type)
  let base = TypeSubstitution::from_arguments(metadata, [parameter], [
    TypeArgument(i64_type()),
  ])
  let shadowing = TypeSubstitution::from_arguments(metadata, [parameter], [
    TypeArgument(bool_type()),
  ])
  assert_eq(Type::Parameter(parameter).try_substitute(base), i64_type())
  assert_eq(
    Type::Parameter(parameter).try_substitute(base.overlay(shadowing)),
    bool_type(),
  )
  assert_eq(Type::Parameter(parameter).try_substitute(base), i64_type())
}

///|
test "buslane substitution reports argument kind mismatches" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_type_parameter("E", Effect)
  try
    TypeSubstitution::from_arguments(metadata, [effect], [
      TypeArgument(i64_type()),
    ])
  catch {
    error =>
      debug_inspect(
        error,
        content="ExpectedEffectArgument(parameter={ index: 0 })",
      )
  } noraise {
    _ => fail("expected an effect argument mismatch")
  }
  let type_ = metadata.define_type_parameter("T", Type)
  let malformed = TypeSubstitution::TypeSubstitution()
  malformed.insert_effect(type_, Empty)
  try Type::Parameter(type_).try_substitute(malformed) catch {
    error =>
      debug_inspect(
        error,
        content="ExpectedTypeArgument(parameter={ index: 1 })",
      )
  } noraise {
    _ => fail("expected a type argument mismatch")
  }
}

///|
test "panic buslane substitution rejects argument kind mismatches" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let type_ = metadata.define_type_parameter("T", Type)
  let malformed = TypeSubstitution::TypeSubstitution()
  malformed.insert_effect(type_, Empty)
  Type::Parameter(type_).substitute(malformed) |> ignore
}

///|
test "buslane canonical effect equality ignores ordering and duplicates" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let console_parameter = metadata.define_type_parameter("T", Type)
  let console = metadata.define_effect("Console", [console_parameter])
  let state = metadata.define_effect("State", [])
  let row = metadata.define_type_parameter("E", Effect)
  let left = Effect::Union([
    Singleton(state, []),
    Empty,
    Singleton(console, [TypeArgument(i64_type())]),
    Singleton(state, []),
    Parameter(row),
  ])
  let right = Effect::Union([
    Parameter(row),
    Singleton(console, [TypeArgument(i64_type())]),
    Singleton(state, []),
  ])
  assert_effect_equal(metadata, left, right)
  inspect(
    @prettyprinter.render(metadata.canonicalize_effect(left), width=100),
    content="{effect#1, effect#0[I64], tparam#1}",
  )
}

///|
test "buslane effect containment is independent from equality" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let first = metadata.define_effect("First", [])
  let second = metadata.define_effect("Second", [])
  let narrow = Effect::Singleton(first, [])
  let wide = Effect::Union([Singleton(first, []), Singleton(second, [])])
  assert_true(metadata.effect_is_subeffect_of(Empty, narrow))
  assert_true(metadata.effect_is_subeffect_of(narrow, wide))
  assert_false(metadata.effect_is_subeffect_of(wide, narrow))
  assert_false(narrow == wide)
}

///|
test "buslane preserves the built-in Io effect atom" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let row = metadata.define_type_parameter("E", Effect)
  let effect = Effect::Union([Io, Empty, Parameter(row), Io])
  inspect(
    @prettyprinter.render(metadata.canonicalize_effect(effect), width=100),
    content="{Io, tparam#0}",
  )
  let substitution = TypeSubstitution::TypeSubstitution()
  substitution.insert_effect(row, Io)
  debug_inspect(
    metadata.canonicalize_effect(effect.substitute(substitution)),
    content="Io",
  )
  assert_false(Effect::Io == Empty)
}

///|
test "verify buslane reports malformed effect terms" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let ordinary_parameter = metadata.define_type_parameter("T", Type)
  let bad_function = metadata.define_value(
    "value",
    Value,
    Forall(
      [ordinary_parameter],
      Function(
        [],
        i64_type(),
        Union([Singleton({ index: 9 }, []), Parameter(ordinary_parameter)]),
      ),
    ),
  )
  let result = metadata.define_value("value", Value, i64_type())
  let program = Program::{
    metadata,
    terms: [
      Let(
        result,
        Perform({
          operation: { index: 8 },
          effect_arguments: [],
          hidden_witnesses: [],
          payloads: [],
        }),
      ),
    ],
  }
  ignore(bad_function)
  inspect(
    @prettyprinter.render(verify_program(program), width=100),
    content=(
      #|verify_result {
      #|  unknown_effect effect#9 at value "value"#1 (value#0)
      #|  kind_mismatch {
      #|    expected Effect
      #|    actual Type
      #|  } at value "value"#1 (value#0)
      #|  unknown_operation operation#8 at term "value"#2 (value#1) / perform operation#8
      #|  type_mismatch {
      #|    expected I64
      #|    actual Unit
      #|  } at term "value"#2 (value#1) / perform operation#8
      #|}
    ),
  )
}

///|
test "verify buslane reports unhandled perform effect" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let console = metadata.define_effect("Effect", [])
  let print = metadata.define_operation(
    "op",
    console,
    [],
    [i64_type()],
    i64_type(),
  )
  let result = metadata.define_value("value", Value, i64_type())
  let program = Program::{
    metadata,
    terms: [
      Let(
        result,
        Perform({
          operation: print,
          effect_arguments: [],
          hidden_witnesses: [],
          payloads: [Literal(I64(1L))],
        }),
      ),
    ],
  }
  inspect(
    @prettyprinter.render(verify_program(program), width=100),
    content=(
      #|verify_result {
      #|  effect_mismatch {
      #|    expected {}
      #|    actual effect#0
      #|  } at term "value"#2 (value#0)
      #|}
    ),
  )
}

///|
test "verify buslane handler removes handled perform effect" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let console = metadata.define_effect("Effect", [])
  let print = metadata.define_operation(
    "op",
    console,
    [],
    [i64_type()],
    i64_type(),
  )
  let result = metadata.define_value("value", Value, i64_type())
  let final_binder = metadata.define_value("value", MatchBinder, i64_type())
  let payload = metadata.define_value("value", MatchBinder, i64_type())
  let resume_binder = metadata.define_value(
    "value",
    MatchBinder,
    Function([i64_type()], i64_type(), Empty),
  )
  let program = Program::{
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
                  body: Ref(payload),
                },
              ],
            },
          ],
        }),
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

///|
test "verify buslane handler preserves open residual effect row" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let row = metadata.define_type_parameter("E", Effect)
  let console = metadata.define_effect("Effect", [])
  let print = metadata.define_operation(
    "op",
    console,
    [],
    [i64_type()],
    i64_type(),
  )
  let external = metadata.define_value(
    "value",
    External,
    Forall([row], Function([], i64_type(), Parameter(row))),
  )
  let function = metadata.define_value(
    "value",
    Function,
    Forall([row], Function([], i64_type(), Parameter(row))),
  )
  let final_binder = metadata.define_value("value", MatchBinder, i64_type())
  let payload = metadata.define_value("value", MatchBinder, i64_type())
  let resume_binder = metadata.define_value(
    "value",
    MatchBinder,
    Function([i64_type()], i64_type(), Parameter(row)),
  )
  let program = Program::{
    metadata,
    terms: [
      External(external),
      LetRec([
        {
          id: function,
          rhs: TypeLambda(
            [row],
            Function({
              parameters: [],
              result_type: i64_type(),
              body: Handle({
                body: Call(
                  TypeApply(Ref(external), [EffectArgument(Parameter(row))]),
                  [],
                ),
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
                        body: Ref(payload),
                      },
                    ],
                  },
                ],
              }),
            }),
          ),
        },
      ]),
    ],
  }
  inspect(
    @prettyprinter.render(verify_program(program), width=100),
    content=(
      #|verify_result {}
    ),
  )
}

///|
test "verify buslane reports invalid perform payload and resume types" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let console = metadata.define_effect("Effect", [])
  let print = metadata.define_operation(
    "op",
    console,
    [],
    [i64_type()],
    i64_type(),
  )
  let result = metadata.define_value("value", Value, i64_type())
  let final_binder = metadata.define_value("value", MatchBinder, i64_type())
  let payload = metadata.define_value("value", MatchBinder, bool_type())
  let resume_binder = metadata.define_value(
    "value",
    MatchBinder,
    Function([bool_type()], i64_type(), Empty),
  )
  let program = Program::{
    metadata,
    terms: [
      Let(
        result,
        Handle({
          body: Perform({
            operation: print,
            effect_arguments: [],
            hidden_witnesses: [],
            payloads: [Literal(Bool(true))],
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
                  body: Literal(I64(1L)),
                },
              ],
            },
          ],
        }),
      ),
    ],
  }
  inspect(
    @prettyprinter.render(verify_program(program), width=100),
    content=(
      #|verify_result {
      #|  type_mismatch {
      #|    expected I64
      #|    actual Bool
      #|  } at term "value"#2 (value#0) / handle / handled body / perform operation#0 / perform payload 0 / literal
      #|  type_mismatch {
      #|    expected I64
      #|    actual Bool
      #|  } at term "value"#2 (value#0) / handle / handler 0 / operation alternative 0
      #|  type_mismatch {
      #|    expected I64
      #|    actual Bool
      #|  } at term "value"#2 (value#0) / handle / handler 0 / operation alternative 0
      #|}
    ),
  )
}

///|
test "verify buslane reports perform payload arity mismatch" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let console = metadata.define_effect("Effect", [])
  let print = metadata.define_operation(
    "op",
    console,
    [],
    [i64_type()],
    i64_type(),
  )
  let result = metadata.define_value("value", Value, i64_type())
  let program = Program::{
    metadata,
    terms: [
      Let(
        result,
        Perform({
          operation: print,
          effect_arguments: [],
          hidden_witnesses: [],
          payloads: [],
        }),
      ),
    ],
  }
  inspect(
    @prettyprinter.render(verify_program(program), width=100),
    content=(
      #|verify_result {
      #|  arity_mismatch {
      #|    expected 1
      #|    actual 0
      #|  } at term "value"#2 (value#0) / perform operation#0
      #|  effect_mismatch {
      #|    expected {}
      #|    actual effect#0
      #|  } at term "value"#2 (value#0)
      #|}
    ),
  )
}

///|
test "verify buslane reports operation ownership and resume arity errors" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let console = metadata.define_effect("Effect", [])
  let state = metadata.define_effect("Effect", [])
  let print = metadata.define_operation(
    "op",
    console,
    [],
    [i64_type()],
    i64_type(),
  )
  let result = metadata.define_value("value", Value, i64_type())
  let final_binder = metadata.define_value("value", MatchBinder, i64_type())
  let resume_binder = metadata.define_value(
    "value",
    MatchBinder,
    Function([], i64_type(), Empty),
  )
  let program = Program::{
    metadata,
    terms: [
      Let(
        result,
        Handle({
          body: Literal(I64(1L)),
          result_binder: final_binder,
          result_type: i64_type(),
          final_body: Ref(final_binder),
          handlers: [
            {
              handled_effect: Singleton(state, []),
              operations: [
                {
                  operation: print,
                  type_binders: [],
                  payload_binders: [],
                  resume_binder,
                  body: Literal(I64(1L)),
                },
              ],
            },
          ],
        }),
      ),
    ],
  }
  inspect(
    @prettyprinter.render(verify_program(program), width=100),
    content=(
      #|verify_result {
      #|  effect_mismatch {
      #|    expected effect#1
      #|    actual {}
      #|  } at term "value"#3 (value#0) / handle
      #|  effect_mismatch {
      #|    expected effect#1
      #|    actual effect#0
      #|  } at term "value"#3 (value#0) / handle / handler 0 / operation alternative 0
      #|  arity_mismatch {
      #|    expected 1
      #|    actual 0
      #|  } at term "value"#3 (value#0) / handle / handler 0 / operation alternative 0
      #|  arity_mismatch {
      #|    expected 1
      #|    actual 0
      #|  } at term "value"#3 (value#0) / handle / handler 0 / operation alternative 0
      #|}
    ),
  )
}

///|
test "pretty buslane expression tree core" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let value = metadata.define_value("value", Value, i64_type())
  let function = metadata.define_value(
    "value",
    Function,
    Function([i64_type()], i64_type(), Empty),
  )
  let parameter = metadata.define_value("value", Parameter, i64_type())
  let program = Program::{
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
  inspect(
    @prettyprinter.render(program, width=100),
    content=(
      #|buslane {
      #|  metadata {
      #|    next_unique#3;
      #|    value value#0 = "value"#0 value : I64;
      #|    value value#1 = "value"#1 function : (I64) -> I64;
      #|    value value#2 = "value"#2 parameter : I64;
      #|  }
      #|  letrec {
      #|    value#1 = fn(value#2) -> I64 {
      #|      value#2
      #|    }
      #|  }
      #|  let value#0 = value#1(42)
      #|}
    ),
  )
}

///|
test "pretty buslane construct and one-level match" {
  let metadata = MetadataRegistry::MetadataRegistry()
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
  let payload = metadata.define_value("value", MatchBinder, i64_type())
  let program = Program::{
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
  inspect(
    @prettyprinter.render(program.terms[1], width=100),
    content=(
      #|let value#2 = match value#0 as value#1 -> I64 {
      #|  datacon#0(value#2) => value#2;
      #|}
    ),
  )
}

///|
test "verify buslane function call program" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let value = metadata.define_value("value", Value, i64_type())
  let function = metadata.define_value(
    "value",
    Function,
    Function([i64_type()], i64_type(), Empty),
  )
  let parameter = metadata.define_value("value", Parameter, i64_type())
  let program = Program::{
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
  inspect(
    @prettyprinter.render(verify_program(program), width=100),
    content=(
      #|verify_result {}
    ),
  )
}

///|
test "verify buslane generic function parameter scope" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let parameter_type = metadata.define_type_parameter("T", Type)
  let function = metadata.define_value(
    "value",
    Function,
    Forall(
      [parameter_type],
      Function([Parameter(parameter_type)], Parameter(parameter_type), Empty),
    ),
  )
  let parameter = metadata.define_value(
    "value",
    Parameter,
    Parameter(parameter_type),
  )
  let program = Program::{
    metadata,
    terms: [
      LetRec([
        {
          id: function,
          rhs: TypeLambda(
            [parameter_type],
            Function({
              parameters: [parameter],
              result_type: Parameter(parameter_type),
              body: Ref(parameter),
            }),
          ),
        },
      ]),
    ],
  }
  inspect(
    @prettyprinter.render(verify_program(program), width=100),
    content=(
      #|verify_result {}
    ),
  )
}

///|
test "verify buslane skips kind-invalid substitution bindings" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let type_parameter = metadata.define_type_parameter("T", Type)
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let type_polymorphic = metadata.define_value(
    "value",
    External,
    Forall([type_parameter], Parameter(type_parameter)),
  )
  let effect_polymorphic = metadata.define_value(
    "value",
    External,
    Forall(
      [effect_parameter],
      Function([], i64_type(), Parameter(effect_parameter)),
    ),
  )
  let type_result = metadata.define_value("value", Value, i64_type())
  let effect_result = metadata.define_value(
    "value",
    Value,
    Function([], i64_type(), Empty),
  )
  let program = Program::{
    metadata,
    terms: [
      External(type_polymorphic),
      External(effect_polymorphic),
      Let(
        type_result,
        TypeApply(Ref(type_polymorphic), [EffectArgument(Empty)]),
      ),
      Let(
        effect_result,
        TypeApply(Ref(effect_polymorphic), [TypeArgument(i64_type())]),
      ),
    ],
  }
  debug_inspect(
    verify_program(program),
    content=(
      #|{
      #|  diagnostics: [
      #|    {
      #|      kind: ExpectedTypeArgument(Empty),
      #|      provenance: [
      #|        TopTerm(
      #|          {
      #|            id: { index: 2 },
      #|            name: Some({ name_space: ValueName, occurrence: "value", unique: { value: 4 } }),
      #|          },
      #|        ),
      #|        Expression(TypeApply),
      #|      ],
      #|    },
      #|    {
      #|      kind: TypeMismatch(expected=Primitive(I64), actual=Parameter({ index: 0 })),
      #|      provenance: [
      #|        TopTerm(
      #|          {
      #|            id: { index: 2 },
      #|            name: Some({ name_space: ValueName, occurrence: "value", unique: { value: 4 } }),
      #|          },
      #|        ),
      #|        Expression(TypeApply),
      #|      ],
      #|    },
      #|    {
      #|      kind: ExpectedEffectArgument(Primitive(I64)),
      #|      provenance: [
      #|        TopTerm(
      #|          {
      #|            id: { index: 3 },
      #|            name: Some({ name_space: ValueName, occurrence: "value", unique: { value: 5 } }),
      #|          },
      #|        ),
      #|        Expression(TypeApply),
      #|      ],
      #|    },
      #|    {
      #|      kind: TypeMismatch(
      #|        expected=Function([], Primitive(I64), Empty),
      #|        actual=Function([], Primitive(I64), Parameter({ index: 1 })),
      #|      ),
      #|      provenance: [
      #|        TopTerm(
      #|          {
      #|            id: { index: 3 },
      #|            name: Some({ name_space: ValueName, occurrence: "value", unique: { value: 5 } }),
      #|          },
      #|        ),
      #|        Expression(TypeApply),
      #|      ],
      #|    },
      #|  ],
      #|}
    ),
  )
}

///|
test "diagnostic provenance distinguishes sibling call arguments" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let callee = metadata.define_value(
    "callee",
    External,
    Function([i64_type(), i64_type()], Primitive(Unit), Empty),
  )
  let result = metadata.define_value("result", Value, Primitive(Unit))
  let program = Program::{
    metadata,
    terms: [
      External(callee),
      Let(result, Call(Ref(callee), [Literal(Unit), Literal(Unit)])),
    ],
  }
  inspect(
    @prettyprinter.render(verify_program(program), width=100),
    content=(
      #|verify_result {
      #|  type_mismatch {
      #|    expected I64
      #|    actual Unit
      #|  } at term "result"#1 (value#1) / call / argument 0 / literal
      #|  type_mismatch {
      #|    expected I64
      #|    actual Unit
      #|  } at term "result"#1 (value#1) / call / argument 1 / literal
      #|}
    ),
  )
}

///|
test "verify buslane rejects effect widening through ordinary value binding" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let read = metadata.define_effect("Read", [])
  let narrow_type = Type::Function([], i64_type(), Empty)
  let wide_type = Type::Function([], i64_type(), Singleton(read, []))
  let narrow = metadata.define_value("narrow", External, narrow_type)
  let wide = metadata.define_value("wide", Value, wide_type)
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
      #|  } at term "wide"#2 (value#1) / ref value#0
      #|}
    ),
  )
}

///|
test "verify buslane widens function effects below forall binders" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let expected_parameter = metadata.define_type_parameter("A", Type)
  let actual_parameter = metadata.define_type_parameter("B", Type)
  let read = metadata.define_effect("Read", [])
  let function = metadata.define_value(
    "function",
    Function,
    Forall(
      [expected_parameter],
      Function(
        [Parameter(expected_parameter)],
        Parameter(expected_parameter),
        Singleton(read, []),
      ),
    ),
  )
  let parameter = metadata.define_value(
    "parameter",
    Parameter,
    Parameter(actual_parameter),
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
              parameters: [parameter],
              result_type: Parameter(actual_parameter),
              body: Ref(parameter),
            }),
          ),
        },
      ]),
    ],
  }
  inspect(
    @prettyprinter.render(verify_program(program), width=100),
    content=(
      #|verify_result {}
    ),
  )
}

///|
test "verify buslane reports structural errors" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let value = metadata.define_value("value", Value, i64_type())
  let binder = metadata.define_value("value", MatchBinder, bool_type())
  let program = Program::{
    metadata,
    terms: [
      Let(value, Call(Literal(I64(1L)), [])),
      Let(
        value,
        Match({
          scrutinee: Literal(Bool(true)),
          binder,
          result_type: i64_type(),
          alternatives: [
            {
              alt_constructor: Literal(Bool(true)),
              type_binders: [],
              value_binders: [],
              body: Literal(I64(1L)),
            },
          ],
        }),
      ),
    ],
  }
  inspect(
    @prettyprinter.render(verify_program(program), width=100),
    content=(
      #|verify_result {
      #|  not_function I64 at term "value"#0 (value#0) / call
      #|  type_mismatch {
      #|    expected I64
      #|    actual Unit
      #|  } at term "value"#0 (value#0) / call
      #|  non_exhaustive_match at term "value"#0 (value#0) / match
      #|}
    ),
  )
}

// `type_is_consumable_as` decides whether a value fits a position, not whether
// two types denote the same thing. It widens only by residual terms, because an
// Algebraic Effect changes how a callable is lowered.

///|
test "consumable types widen a latent effect by residual terms" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let external = metadata.define_effect("Fd", [], flavor=External)
  let pure_ = Type::Function([], i64_type(), Empty)
  let io = Type::Function([], i64_type(), Io)
  let both = Type::Function(
    [],
    i64_type(),
    Union([Io, Singleton(external, [])]),
  )
  assert_true(metadata.type_is_consumable_as(pure_, io))
  assert_true(metadata.type_is_consumable_as(pure_, both))
  assert_true(metadata.type_is_consumable_as(io, both))
  assert_false(metadata.type_is_consumable_as(io, pure_))
  assert_false(metadata.type_is_consumable_as(both, io))
}

///|
test "consumable types refuse to widen by an algebraic effect" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let read = metadata.define_effect("Read", [])
  let pure_ = Type::Function([], i64_type(), Empty)
  let algebraic = Type::Function([], i64_type(), Singleton(read, []))
  assert_false(metadata.type_is_consumable_as(pure_, algebraic))
  assert_false(metadata.type_is_consumable_as(algebraic, pure_))
}

///|
test "consumable types classify effect row variables by flavor" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let algebraic_row = metadata.define_type_parameter("E", Effect)
  let residual_row = metadata.define_type_parameter(
    "R",
    Effect,
    flavor=External,
  )
  let pure_ = Type::Function([], i64_type(), Empty)
  let over_algebraic = Type::Function([], i64_type(), Parameter(algebraic_row))
  let over_residual = Type::Function([], i64_type(), Parameter(residual_row))
  assert_true(metadata.type_is_consumable_as(pure_, over_residual))
  assert_false(metadata.type_is_consumable_as(pure_, over_algebraic))
}

///|
test "consumable types invert the direction under a parameter" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let pure_ = Type::Function([], i64_type(), Empty)
  let io = Type::Function([], i64_type(), Io)
  // A consumer that will be handed a pure callback cannot take one that only
  // accepts callbacks allowed to perform `Io`, and the reverse is fine.
  assert_true(
    metadata.type_is_consumable_as(
      Function([io], i64_type(), Empty),
      Function([pure_], i64_type(), Empty),
    ),
  )
  assert_false(
    metadata.type_is_consumable_as(
      Function([pure_], i64_type(), Empty),
      Function([io], i64_type(), Empty),
    ),
  )
}

///|
test "consumable types keep type arguments invariant" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let parameter = metadata.define_type_parameter("A", Type)
  let box = metadata.define_type("Box", [parameter])
  let pure_ = Type::Function([], i64_type(), Empty)
  let io = Type::Function([], i64_type(), Io)
  assert_false(
    metadata.type_is_consumable_as(
      Apply(Constructor(box), [TypeArgument(pure_)]),
      Apply(Constructor(box), [TypeArgument(io)]),
    ),
  )
}

///|
test "consumable types rename binders under contravariance" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let left = metadata.define_type_parameter("A", Type)
  let right = metadata.define_type_parameter("B", Type)
  // Alpha-equivalent, and the equivalence has to survive the direction flip a
  // contravariant parameter introduces.
  let with_binder = fn(parameter) {
    Type::Forall(
      [parameter],
      Function(
        [Function([Parameter(parameter)], i64_type(), Empty)],
        i64_type(),
        Empty,
      ),
    )
  }
  assert_true(
    metadata.type_is_consumable_as(with_binder(left), with_binder(right)),
  )
}

///|
test "definitional equality dedupes a row without the cross-side bindings" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let x = metadata.define_type_parameter("X", Effect)
  let y = metadata.define_type_parameter("Y", Effect)
  let doubled : Type = Forall(
    [x],
    Function([], Primitive(Unit), Union([Parameter(x), Parameter(x)])),
  )
  let single : Type = Forall([x], Function([], Primitive(Unit), Parameter(x)))
  let renamed : Type = Forall([y], Function([], Primitive(Unit), Parameter(y)))
  assert_true(metadata.types_definitionally_equal(doubled, single))
  assert_true(metadata.types_definitionally_equal(single, renamed))
  assert_true(metadata.types_definitionally_equal(doubled, renamed))
}

///|
test "alpha equality gives a rebound id to its innermost binder" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let x = metadata.define_type_parameter("X", Effect)
  let a = metadata.define_type_parameter("A", Effect)
  let b = metadata.define_type_parameter("B", Effect)
  let shadowed : Type = Forall(
    [x],
    Forall([x], Function([], Primitive(Unit), Parameter(x))),
  )
  let inner : Type = Forall(
    [a],
    Forall([b], Function([], Primitive(Unit), Parameter(b))),
  )
  let outer : Type = Forall(
    [a],
    Forall([b], Function([], Primitive(Unit), Parameter(a))),
  )
  assert_true(metadata.types_definitionally_equal(shadowed, inner))
  assert_false(metadata.types_definitionally_equal(shadowed, outer))
}

///|
test "substitution refuses to capture a replacement's free parameter" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let x = metadata.define_type_parameter("X", Type)
  let y = metadata.define_type_parameter("Y", Type)
  let substitution = TypeSubstitution::TypeSubstitution()
  substitution.insert_argument(x, TypeArgument(Parameter(y)))
  let body : Type = Forall(
    [y],
    Function([Parameter(x)], Primitive(Unit), Empty),
  )
  try body.try_substitute(substitution) catch {
    CapturedTypeParameter(parameter~, binder~) => {
      assert_eq(parameter, x)
      assert_eq(binder, y)
    }
    error => fail("unexpected substitution error: \{Repr(error)}")
  } noraise {
    _ => fail("expected substitution to refuse the capture")
  }
}

///|
test "substitution keeps a replacement's own binder without renaming" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let x = metadata.define_type_parameter("X", Type)
  let y = metadata.define_type_parameter("Y", Type)
  let a = metadata.define_type_parameter("A", Type)
  let b = metadata.define_type_parameter("B", Type)
  // The replacement binds its own `y`; planting it under the body's `y` makes
  // shadowing, not capture, and the innermost reading keeps it correct.
  let replacement : Type = Forall(
    [y],
    Function([Parameter(y)], Primitive(Unit), Empty),
  )
  let applied : Type = Apply(
    TypeLambda([x], Forall([y], Function([], Parameter(x), Empty))),
    [TypeArgument(replacement)],
  )
  let expected : Type = Forall(
    [a],
    Function(
      [],
      Forall([b], Function([Parameter(b)], Primitive(Unit), Empty)),
      Empty,
    ),
  )
  assert_true(metadata.types_definitionally_equal(applied, expected))
}

///|
fn capturing_construct_program(
  top_term_count : Int,
  payload_count : Int,
) -> Program raise MetadataAllocationError {
  let metadata = MetadataRegistry::MetadataRegistry()
  let element = metadata.define_type_parameter("T", Type)
  let y = metadata.define_type_parameter("Y", Type)
  let box = metadata.define_type("Box", [element])
  let payload_type : Type = Forall(
    [y],
    Function([Parameter(element), Parameter(y)], Primitive(Unit), Empty),
  )
  let payload_types = []
  for _ in 0..<payload_count {
    payload_types.push(payload_type)
  }
  let data_constructor = metadata.define_data_constructor(
    "box",
    box,
    [],
    payload_types,
  )
  let payload = metadata.define_value(
    "payload",
    External,
    Forall([element, y], payload_type),
  )
  let result_type : Type = Forall(
    [y],
    Apply(Constructor(box), [TypeArgument(Parameter(y))]),
  )
  let terms : Array[TopTerm] = [External(payload)]
  for index in 0..<top_term_count {
    let result = metadata.define_value("result\{index}", Value, result_type)
    let payloads : Array[Expr] = []
    for _ in 0..<payload_count {
      payloads.push(Ref(payload))
    }
    terms.push(
      Let(
        result,
        TypeLambda(
          [y],
          Construct({
            data_constructor,
            type_arguments: [TypeArgument(Parameter(y))],
            hidden_witnesses: [],
            payloads,
          }),
        ),
      ),
    )
  }
  { metadata, terms }
}

///|
fn substitution_failure_diagnostics(
  program : Program,
) -> Array[VerifyDiagnostic] {
  verify_program(program)
  .diagnostics()
  .filter(diagnostic => diagnostic.kind is TypeSubstitutionFailure(_))
}

///|
test "substitution failures preserve distinct provenance" {
  let failures = substitution_failure_diagnostics(
    capturing_construct_program(2, 1),
  )
  debug_inspect(
    failures,
    content=(
      #|[
      #|  {
      #|    kind: TypeSubstitutionFailure(CapturedTypeParameter(parameter={ index: 0 }, binder={ index: 1 })),
      #|    provenance: [
      #|      TopTerm(
      #|        {
      #|          id: { index: 1 },
      #|          name: Some({ name_space: ValueName, occurrence: "result0", unique: { value: 5 } }),
      #|        },
      #|      ),
      #|      Expression(TypeLambda),
      #|      Child(TypeLambdaBody),
      #|      Expression(Construct({ index: 0 })),
      #|    ],
      #|  },
      #|  {
      #|    kind: TypeSubstitutionFailure(CapturedTypeParameter(parameter={ index: 0 }, binder={ index: 1 })),
      #|    provenance: [
      #|      TopTerm(
      #|        {
      #|          id: { index: 2 },
      #|          name: Some({ name_space: ValueName, occurrence: "result1", unique: { value: 6 } }),
      #|        },
      #|      ),
      #|      Expression(TypeLambda),
      #|      Child(TypeLambdaBody),
      #|      Expression(Construct({ index: 0 })),
      #|    ],
      #|  },
      #|]
    ),
  )
}

///|
test "substitution failures deduplicate at one provenance" {
  let failures = substitution_failure_diagnostics(
    capturing_construct_program(1, 2),
  )
  debug_inspect(
    failures,
    content=(
      #|[
      #|  {
      #|    kind: TypeSubstitutionFailure(CapturedTypeParameter(parameter={ index: 0 }, binder={ index: 1 })),
      #|    provenance: [
      #|      TopTerm(
      #|        {
      #|          id: { index: 1 },
      #|          name: Some({ name_space: ValueName, occurrence: "result0", unique: { value: 5 } }),
      #|        },
      #|      ),
      #|      Expression(TypeLambda),
      #|      Child(TypeLambdaBody),
      #|      Expression(Construct({ index: 0 })),
      #|    ],
      #|  },
      #|]
    ),
  )
}

///|
test "type application that would capture fails verification" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let x = metadata.define_type_parameter("X", Type)
  let y = metadata.define_type_parameter("Y", Type)
  let g = metadata.define_value(
    "g",
    Value,
    Forall([x], Forall([y], Function([Parameter(x)], Primitive(Unit), Empty))),
  )
  let query = ExpressionFactsQuery::new({ metadata, terms: [] })
  let result = query.synthesize(
    TypeLambda([y], TypeApply(Ref(g), [TypeArgument(Parameter(y))])),
  )
  guard result is Err(verify) else { abort("expected capture rejection") }
  assert_eq(diagnostic_kinds(verify), [
    TypeSubstitutionFailure(CapturedTypeParameter(parameter=x, binder=y)),
  ])
}

///|
test "construct payload instantiation that would capture fails verification" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let element = metadata.define_type_parameter("T", Type)
  let y = metadata.define_type_parameter("Y", Type)
  let box = metadata.define_type("Type", [element])
  let payload_type : Type = Forall(
    [y],
    Function([Parameter(element), Parameter(y)], Primitive(Unit), Empty),
  )
  let con = metadata.define_data_constructor("Con", box, [], [payload_type])
  let payload = metadata.define_value("payload", Value, payload_type)
  let query = ExpressionFactsQuery::new({ metadata, terms: [] })
  let result = query.synthesize(
    Construct({
      data_constructor: con,
      type_arguments: [TypeArgument(Parameter(y))],
      hidden_witnesses: [],
      payloads: [Ref(payload)],
    }),
  )
  guard result is Err(verify) else { abort("expected capture rejection") }
  assert_eq(diagnostic_kinds(verify), [
    TypeSubstitutionFailure(CapturedTypeParameter(parameter=element, binder=y)),
  ])
}

///|
test "perform instantiation that would capture fails verification" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let element = metadata.define_type_parameter("T", Type)
  let y = metadata.define_type_parameter("Y", Type)
  let effect = metadata.define_effect("Effect", [element])
  let op = metadata.define_operation(
    "op",
    effect,
    [],
    [],
    Forall(
      [y],
      Function([Parameter(element), Parameter(y)], Primitive(Unit), Empty),
    ),
  )
  let query = ExpressionFactsQuery::new({ metadata, terms: [] })
  let result = query.synthesize(
    Perform({
      operation: op,
      effect_arguments: [TypeArgument(Parameter(y))],
      hidden_witnesses: [],
      payloads: [],
    }),
  )
  guard result is Err(verify) else { abort("expected capture rejection") }
  assert_eq(diagnostic_kinds(verify), [
    TypeSubstitutionFailure(CapturedTypeParameter(parameter=element, binder=y)),
  ])
}

///|
test "handler alternative instantiation that would capture fails verification" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let hidden = metadata.define_type_parameter("Hidden", Type)
  let w = metadata.define_type_parameter("W", Type)
  let effect = metadata.define_effect("Effect", [])
  let payload_type : Type = Forall(
    [w],
    Function([Parameter(hidden), Parameter(w)], Primitive(Unit), Empty),
  )
  let op = metadata.define_operation(
    "op",
    effect,
    [hidden],
    [payload_type],
    Primitive(Unit),
  )
  let instantiated_payload = metadata.define_value(
    "payload",
    Value,
    Forall(
      [w],
      Function([Primitive(I64), Parameter(w)], Primitive(Unit), Empty),
    ),
  )
  let result_binder = metadata.define_value(
    "result",
    MatchBinder,
    Primitive(Unit),
  )
  let payload_binder = metadata.define_value(
    "payload",
    MatchBinder,
    payload_type,
  )
  let resume_binder = metadata.define_value(
    "resume",
    MatchBinder,
    Function([Primitive(Unit)], Primitive(Unit), Empty),
  )
  let unit_value = metadata.define_value("unit", Value, Primitive(Unit))
  let query = ExpressionFactsQuery::new({ metadata, terms: [] })
  // The alternative reuses the payload's inner binder as its own hidden
  // binder, so instantiating the payload type for the binder check captures.
  let result = query.synthesize(
    Handle({
      body: Perform({
        operation: op,
        effect_arguments: [],
        hidden_witnesses: [TypeArgument(Primitive(I64))],
        payloads: [Ref(instantiated_payload)],
      }),
      result_binder,
      result_type: Primitive(Unit),
      final_body: Ref(unit_value),
      handlers: [
        {
          handled_effect: Singleton(effect, []),
          operations: [
            {
              operation: op,
              type_binders: [w],
              payload_binders: [payload_binder],
              resume_binder,
              body: Ref(unit_value),
            },
          ],
        },
      ],
    }),
  )
  guard result is Err(verify) else { abort("expected capture rejection") }
  assert_eq(diagnostic_kinds(verify), [
    TypeSubstitutionFailure(CapturedTypeParameter(parameter=hidden, binder=w)),
  ])
}

///|
test "substitution and alpha equality agree on shadowed binders" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let x = metadata.define_type_parameter("X", Effect)
  let y = metadata.define_type_parameter("Y", Effect)
  // Beta reduction hands `Io` to `x`, but the occurrence below belongs to the
  // inner rebinding of `x`: substitution must leave it alone, and equality
  // must then read it as the inner binder too.
  let applied : Type = Apply(
    TypeLambda([x], Forall([x], Function([], Primitive(Unit), Parameter(x)))),
    [EffectArgument(Io)],
  )
  let untouched : Type = Forall(
    [y],
    Function([], Primitive(Unit), Parameter(y)),
  )
  let captured : Type = Forall([y], Function([], Primitive(Unit), Io))
  assert_true(metadata.types_definitionally_equal(applied, untouched))
  assert_false(metadata.types_definitionally_equal(applied, captured))
}

///|
test "type application enforces an external row variable's flavor" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let algebraic = metadata.define_effect("Alg", [])
  let external = metadata.define_effect("Ext", [], flavor=External)
  let row = metadata.define_type_parameter("R", Effect, flavor=External)
  let g = metadata.define_value(
    "g",
    Value,
    Forall([row], Function([], Primitive(Unit), Parameter(row))),
  )
  let query = ExpressionFactsQuery::new({ metadata, terms: [] })
  let rejected = query.synthesize(
    TypeApply(Ref(g), [EffectArgument(Singleton(algebraic, []))]),
  )
  guard rejected is Err(verify) else { abort("expected a flavor diagnostic") }
  assert_eq(diagnostic_kinds(verify), [
    EffectFlavorMismatch(parameter=row, argument=Singleton(algebraic, [])),
  ])
  for
    admitted in (
      [Empty, Io, Singleton(external, []), Union([Io, Singleton(external, [])])] :
      Array[Effect]) {
    assert_true(
      query.synthesize(TypeApply(Ref(g), [EffectArgument(admitted)])) is Ok(_),
    )
  }
}

///|
test "binder compatibility distinguishes row variable flavors" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let algebraic_row = metadata.define_type_parameter("E", Effect)
  let external_row = metadata.define_type_parameter(
    "E",
    Effect,
    flavor=External,
  )
  let with_row = fn(parameter) {
    Type::Forall(
      [parameter],
      Function([], Primitive(Unit), Parameter(parameter)),
    )
  }
  assert_false(
    metadata.types_definitionally_equal(
      with_row(algebraic_row),
      with_row(external_row),
    ),
  )
  assert_false(
    metadata.type_is_consumable_as(
      with_row(algebraic_row),
      with_row(external_row),
    ),
  )
  assert_false(
    metadata.type_is_consumable_as(
      with_row(external_row),
      with_row(algebraic_row),
    ),
  )
}

///|
test "a handler over a purely external row must name its handled effect" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let algebraic = metadata.define_effect("Alg", [])
  let external_row = metadata.define_type_parameter(
    "R",
    Effect,
    flavor=External,
  )
  let algebraic_row = metadata.define_type_parameter("S", Effect)
  let external_body = metadata.define_value(
    "external_body",
    Value,
    Function([], Primitive(Unit), Parameter(external_row)),
  )
  let algebraic_body = metadata.define_value(
    "algebraic_body",
    Value,
    Function([], Primitive(Unit), Parameter(algebraic_row)),
  )
  let result_binder = metadata.define_value(
    "result",
    MatchBinder,
    Primitive(Unit),
  )
  let unit_value = metadata.define_value("unit", Value, Primitive(Unit))
  let query = ExpressionFactsQuery::new({ metadata, terms: [] })
  let handle_over = fn(body : ValueId) {
    Expr::Handle({
      body: Call(Ref(body), []),
      result_binder,
      result_type: Primitive(Unit),
      final_body: Ref(unit_value),
      handlers: [{ handled_effect: Singleton(algebraic, []), operations: [] }],
    })
  }
  // An External row provably lacks the algebraic effect, so handling it there
  // is a verifier diagnostic; an Algebraic row may still conceal it.
  guard query.synthesize(handle_over(external_body)) is Err(verify) else {
    abort("expected a handler diagnostic over the external row")
  }
  assert_eq(diagnostic_kinds(verify), [
    EffectMismatch(
      expected=Singleton(algebraic, []),
      actual=Parameter(external_row),
    ),
  ])
  assert_true(query.synthesize(handle_over(algebraic_body)) is Ok(_))
}

///|
test "declared types enforce constructor parameter flavors" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let algebraic = metadata.define_effect("Alg", [])
  let residual_row = metadata.define_type_parameter(
    "R",
    Effect,
    flavor=External,
  )
  let dictionary = metadata.define_type("Type", [residual_row])
  let _value = metadata.define_value(
    "value",
    Value,
    Apply(Constructor(dictionary), [EffectArgument(Singleton(algebraic, []))]),
  )
  let diagnostics = diagnostic_kinds(verify_program({ metadata, terms: [] }))
  assert_eq(diagnostics, [
    EffectFlavorMismatch(
      parameter=residual_row,
      argument=Singleton(algebraic, []),
    ),
  ])
}

///|
test "binding sites verify binder types in their own scope" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let bogus : TypeParameterId = { index: 9999 }
  let parameter = metadata.define_value("p", Parameter, Parameter(bogus))
  let local_binder = metadata.define_value(
    "f",
    Local,
    Function([Parameter(bogus)], Primitive(Unit), Empty),
  )
  let main = metadata.define_value("main", Value, Primitive(Unit))
  let program : Program = {
    metadata,
    terms: [
      Let(
        main,
        Let(
          local_binder,
          Function({
            parameters: [parameter],
            result_type: Primitive(Unit),
            body: Literal(Unit),
          }),
          Literal(Unit),
        ),
      ),
    ],
  }
  // The local's declared type and the function's parameter both name an id
  // that does not exist; equality alone would never ask.
  assert_eq(diagnostic_kinds(verify_program(program)), [
    UnknownTypeParameter(bogus),
    UnknownTypeParameter(bogus),
  ])
}

///|
test "binding sites reject closed declaration kinds" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let external = metadata.define_value("q", External, Primitive(I64))
  let main = metadata.define_value("main", Value, Primitive(Unit))
  let program : Program = {
    metadata,
    terms: [Let(main, Let(external, Literal(I64(1)), Literal(Unit)))],
  }
  assert_eq(diagnostic_kinds(verify_program(program)), [
    InvalidBinderKind(value=external, actual=External),
  ])
}

///|
test "a top-level binding keeps a closed declaration kind" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let binder_kind = metadata.define_value("top", Local, Primitive(I64))
  let program : Program = {
    metadata,
    terms: [Let(binder_kind, Literal(I64(1)))],
  }
  assert_eq(diagnostic_kinds(verify_program(program)), [
    InvalidBinderKind(value=binder_kind, actual=Local),
  ])
}

///|
test "binder kinds stay interchangeable across a lowering rewrite" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let main = metadata.define_value("main", Value, Primitive(Unit))
  let scrutinee = metadata.define_value("s", Value, Primitive(I64))
  // Lowering rewrites constructs without reissuing ids, so one value serves
  // as a match binder here and as a function parameter next door; both forms
  // must verify.
  let shared = metadata.define_value("shared", MatchBinder, Primitive(I64))
  let as_match : Expr = Match({
    scrutinee: Ref(scrutinee),
    binder: shared,
    result_type: Primitive(Unit),
    alternatives: [
      {
        alt_constructor: Default,
        type_binders: [],
        value_binders: [],
        body: Literal(Unit),
      },
    ],
  })
  let as_parameter : Expr = Call(
    Function({
      parameters: [shared],
      result_type: Primitive(Unit),
      body: Literal(Unit),
    }),
    [Ref(scrutinee)],
  )
  for form in [as_match, as_parameter] {
    let program : Program = {
      metadata,
      terms: [Let(scrutinee, Literal(I64(1))), Let(main, form)],
    }
    assert_eq(verify_program(program).diagnostics(), [])
  }
}

///|
test "top-level scope grows term by term" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let a = metadata.define_value("a", Value, Primitive(Unit))
  let b = metadata.define_value("b", Value, Primitive(Unit))
  // Both initializers are evaluated where they stand, so neither may reach a
  // binding the interpreter has not established yet.
  assert_eq(
    diagnostic_kinds(verify_program({ metadata, terms: [Let(a, Ref(a))] })),
    [UnknownValue(a)],
  )
  assert_eq(
    diagnostic_kinds(
      verify_program({
        metadata,
        terms: [Let(a, Ref(b)), Let(b, Literal(Unit))],
      }),
    ),
    [UnknownValue(b)],
  )
  assert_eq(
    verify_program({ metadata, terms: [Let(b, Literal(Unit)), Let(a, Ref(b))] }).diagnostics(),
    [],
  )
}

///|
test "a function body sees the whole top-level scope" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let unit_thunk : Type = Function([], Primitive(Unit), Empty)
  let caller = metadata.define_value("caller", Function, unit_thunk)
  let later = metadata.define_value("later", Value, Primitive(Unit))
  // The body runs only once the program is bound, so a later binding is in
  // scope there even though an eager position could not reach it.
  let body : Expr = Function({
    parameters: [],
    result_type: Primitive(Unit),
    body: Ref(later),
  })
  assert_eq(
    verify_program({
      metadata,
      terms: [Let(caller, body), Let(later, Literal(Unit))],
    }).diagnostics(),
    [],
  )
}

///|
test "a recursive group is in scope for its own right sides" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let thunk : Type = Function([], Primitive(Unit), Empty)
  let ping = metadata.define_value("ping", Function, thunk)
  let pong = metadata.define_value("pong", Function, thunk)
  let call = fn(target) {
    Expr::Function({
      parameters: [],
      result_type: Primitive(Unit),
      body: Call(Ref(target), []),
    })
  }
  assert_eq(
    verify_program({
      metadata,
      terms: [
        LetRec([{ id: ping, rhs: call(pong) }, { id: pong, rhs: call(ping) }]),
      ],
    }).diagnostics(),
    [],
  )
}

///|
test "a diagnostic carries the path the verifier took to reach it" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let missing : ValueId = { index: 9999 }
  let inner = metadata.define_value("inner", Local, Primitive(I64))
  let main = metadata.define_value(
    "main",
    Function,
    Function([], Primitive(I64), Empty),
  )
  let program : Program = {
    metadata,
    terms: [
      Let(
        main,
        Function({
          parameters: [],
          result_type: Primitive(I64),
          body: Let(inner, Ref(missing), Ref(inner)),
        }),
      ),
    ],
  }
  // Outermost first: the term, then each expression form on the way down.
  inspect(
    @prettyprinter.render(verify_program(program), width=100),
    content=(
      #|verify_result {
      #|  unknown_value value#9999 at term "main"#1 (value#1) / fn / function body / let value#0 / initializer / ref value#9999
      #|  type_mismatch {
      #|    expected I64
      #|    actual Unit
      #|  } at term "main"#1 (value#1) / fn / function body / let value#0 / initializer / ref value#9999
      #|}
    ),
  )
}

///|
test "metadata diagnostics name the entity under check" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let missing : TypeParameterId = { index: 9999 }
  let owner = metadata.define_type("Box", [])
  let _constructor = metadata.define_data_constructor("Box", owner, [], [
    Parameter(missing),
  ])
  inspect(
    @prettyprinter.render(verify_program({ metadata, terms: [] }), width=100),
    content=(
      #|verify_result {
      #|  unknown_type_parameter tparam#9999 at data_constructor "Box"#1 (datacon#0)
      #|}
    ),
  )
}

///|
test "a top-term anchor without metadata retains its id" {
  let missing : ValueId = { index: 9999 }
  inspect(
    @prettyprinter.render(
      verify_program({
        metadata: MetadataRegistry(),
        terms: [External(missing)],
      }),
      width=100,
    ),
    content=(
      #|verify_result {
      #|  unknown_value value#9999 at term value#9999
      #|}
    ),
  )
}

///|
test "a type argument in an effect position is a category mismatch" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let row = metadata.define_type_parameter("E", Effect)
  let callable = metadata.define_value(
    "callable",
    Value,
    Forall([row], Function([], Primitive(Unit), Parameter(row))),
  )
  let query = ExpressionFactsQuery::new({ metadata, terms: [] })
  // Reporting a kind mismatch here would have to name a kind the argument
  // does not have: its kind may well be Effect, and it is still the wrong
  // category of argument.
  guard query.synthesize(
      TypeApply(Ref(callable), [TypeArgument(Parameter(row))]),
    )
    is Err(verify) else {
    abort("expected a category diagnostic")
  }
  assert_eq(diagnostic_kinds(verify), [ExpectedEffectArgument(Parameter(row))])
}

///|
/// A union is a row of members and the empty row is `Empty`. Admitting both
/// would give one effect two encodings that every consumer would have to
/// relate — the canonical form already collapses them, and the text notation,
/// which spells a row by its members, cannot tell an empty one from `Empty`.
test "an empty effect union is not an effect" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let _ = metadata.define_value(
    "pure",
    Value,
    Function([], Primitive(Unit), Union([])),
  )
  assert_eq(diagnostic_kinds(verify_program({ metadata, terms: [] })), [
    EmptyEffectUnion,
  ])
}
