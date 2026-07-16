///|
fn int_type() -> Type {
  Primitive(Int)
}

///|
fn bool_type() -> Type {
  Primitive(Bool)
}

///|
fn assert_type_equal(actual : Type, expected : Type) -> Unit {
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
fn assert_effect_equal(actual : Effect, expected : Effect) -> Unit {
  if actual != expected {
    abort(
      "expected equal buslane effects\nactual:\n" +
      @prettyprinter.render(actual, width=100) +
      "\nexpected:\n" +
      @prettyprinter.render(expected, width=100),
    )
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
      #|  type Type#1[tparam#0] {
      #|    Con#2()
      #|    Con#3(tparam#0)
      #|  }
      #|  type_parameter T#0 : Type
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
      #|  type_parameter T#0 : Type
      #|  type_parameter E#1 : Effect
      #|  effect Effect#2[tparam#0] {
      #|    op#3() -> tparam#0
      #|    op#4(tparam#0) -> Unit
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(
      Effect::Union([
        Singleton(state, [TypeArgument(int_type())]),
        Parameter(row_param),
      ]),
      width=100,
    ),
    content="{effect#0[Int], tparam#1}",
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
  let left_param = TypeParameterId::{ index: 0 }
  let right_param = TypeParameterId::{ index: 1 }
  let left = Type::Forall([left_param], Parameter(left_param))
  let right = Type::Forall([right_param], Parameter(right_param))
  assert_type_equal(left, right)
}

///|
test "buslane type equality beta normalizes type lambdas" {
  let parameter = TypeParameterId::{ index: 0 }
  let lambda = Type::TypeLambda([parameter], Parameter(parameter))
  assert_type_equal(Apply(lambda, [TypeArgument(int_type())]), int_type())
}

///|
test "buslane function latent effects participate in type equality and substitution" {
  let left_param = TypeParameterId::{ index: 0 }
  let right_param = TypeParameterId::{ index: 1 }
  let effect_id = EffectId::{ index: 0 }
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
  assert_type_equal(left, right)
  let left_row : Type = Forall(
    [left_param],
    Function([], int_type(), Parameter(left_param)),
  )
  let right_row : Type = Forall(
    [right_param],
    Function([], int_type(), Parameter(right_param)),
  )
  assert_type_equal(left_row, right_row)
  let substitution = TypeSubstitution::TypeSubstitution()
  substitution.insert(left_param, int_type())
  let effectful : Type = Function(
    [],
    Parameter(left_param),
    Singleton(effect_id, [TypeArgument(Parameter(left_param))]),
  )
  inspect(
    @prettyprinter.render(effectful.substitute(substitution), width=100),
    content="() -> Int ! effect#0[Int]",
  )
}

///|
test "buslane canonical effect equality ignores ordering and duplicates" {
  let console = EffectId::{ index: 0 }
  let state = EffectId::{ index: 1 }
  let row = TypeParameterId::{ index: 2 }
  let left = Effect::Union([
    Singleton(state, []),
    Empty,
    Singleton(console, [TypeArgument(int_type())]),
    Singleton(state, []),
    Parameter(row),
  ])
  let right = Effect::Union([
    Parameter(row),
    Singleton(console, [TypeArgument(int_type())]),
    Singleton(state, []),
  ])
  assert_effect_equal(left, right)
  inspect(
    @prettyprinter.render(left.canonicalize(), width=100),
    content="{effect#1, effect#0[Int], tparam#2}",
  )
}

///|
test "buslane preserves the built-in Io effect atom" {
  let row = TypeParameterId::{ index: 0 }
  let effect = Effect::Union([Io, Empty, Parameter(row), Io])
  inspect(
    @prettyprinter.render(effect.canonicalize(), width=100),
    content="{Io, tparam#0}",
  )
  let substitution = TypeSubstitution::TypeSubstitution()
  substitution.insert_effect(row, Io)
  let substituted = Type::Function([], Primitive(Unit), effect).substitute(
    substitution,
  )
  guard substituted is Function(_, _, substituted_effect) else {
    fail("expected substituted function type")
  }
  debug_inspect(substituted_effect.canonicalize(), content="Io")
  assert_false(Io == Empty)
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
        int_type(),
        Union([Singleton({ index: 9 }, []), Parameter(ordinary_parameter)]),
      ),
    ),
  )
  let result = metadata.define_value("value", Value, int_type())
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
      #|  unknown_effect effect#9
      #|  kind_mismatch {
      #|    expected Effect
      #|    actual Type
      #|  }
      #|  unknown_operation operation#8
      #|  type_mismatch {
      #|    expected Int
      #|    actual Unit
      #|  }
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
    [int_type()],
    int_type(),
  )
  let result = metadata.define_value("value", Value, int_type())
  let program = Program::{
    metadata,
    terms: [
      Let(
        result,
        Perform({
          operation: print,
          effect_arguments: [],
          hidden_witnesses: [],
          payloads: [Literal(Int(1L))],
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
      #|  }
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
    [int_type()],
    int_type(),
  )
  let result = metadata.define_value("value", Value, int_type())
  let final_binder = metadata.define_value("value", Local, int_type())
  let payload = metadata.define_value("value", Parameter, int_type())
  let resume_binder = metadata.define_value(
    "value",
    Parameter,
    Function([int_type()], int_type(), Empty),
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
    [int_type()],
    int_type(),
  )
  let external = metadata.define_value(
    "value",
    External,
    Forall([row], Function([], int_type(), Parameter(row))),
  )
  let function = metadata.define_value(
    "value",
    Function,
    Forall([row], Function([], int_type(), Parameter(row))),
  )
  let final_binder = metadata.define_value("value", Local, int_type())
  let payload = metadata.define_value("value", Parameter, int_type())
  let resume_binder = metadata.define_value(
    "value",
    Parameter,
    Function([int_type()], int_type(), Parameter(row)),
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
              result_type: int_type(),
              body: Handle({
                body: Call(
                  TypeApply(Ref(external), [TypeArgument(Parameter(row))]),
                  [],
                ),
                result_binder: final_binder,
                result_type: int_type(),
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
    [int_type()],
    int_type(),
  )
  let result = metadata.define_value("value", Value, int_type())
  let final_binder = metadata.define_value("value", Local, int_type())
  let payload = metadata.define_value("value", Parameter, bool_type())
  let resume_binder = metadata.define_value(
    "value",
    Parameter,
    Function([bool_type()], int_type(), Empty),
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
          result_type: int_type(),
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
                  body: Literal(Int(1L)),
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
      #|    expected Int
      #|    actual Bool
      #|  }
      #|  type_mismatch {
      #|    expected Int
      #|    actual Bool
      #|  }
      #|  type_mismatch {
      #|    expected Int
      #|    actual Bool
      #|  }
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
    [int_type()],
    int_type(),
  )
  let result = metadata.define_value("value", Value, int_type())
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
      #|  }
      #|  effect_mismatch {
      #|    expected {}
      #|    actual effect#0
      #|  }
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
    [int_type()],
    int_type(),
  )
  let result = metadata.define_value("value", Value, int_type())
  let final_binder = metadata.define_value("value", Local, int_type())
  let resume_binder = metadata.define_value(
    "value",
    Parameter,
    Function([], int_type(), Empty),
  )
  let program = Program::{
    metadata,
    terms: [
      Let(
        result,
        Handle({
          body: Literal(Int(1L)),
          result_binder: final_binder,
          result_type: int_type(),
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
                  body: Literal(Int(1L)),
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
      #|  }
      #|  effect_mismatch {
      #|    expected effect#1
      #|    actual effect#0
      #|  }
      #|  arity_mismatch {
      #|    expected 1
      #|    actual 0
      #|  }
      #|  arity_mismatch {
      #|    expected 1
      #|    actual 0
      #|  }
      #|}
    ),
  )
}

///|
test "pretty buslane expression tree core" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let value = metadata.define_value("value", Value, int_type())
  let function = metadata.define_value(
    "value",
    Function,
    Function([int_type()], int_type(), Empty),
  )
  let parameter = metadata.define_value("value", Parameter, int_type())
  let program = Program::{
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
  inspect(
    @prettyprinter.render(program, width=100),
    content=(
      #|buslane {
      #|  metadata {
      #|    value value#0 : Int
      #|    function value#1 : (Int) -> Int
      #|    parameter value#2 : Int
      #|  }
      #|  letrec {
      #|    value#1 = fn(value#2) -> Int {
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
    Apply(Constructor(option_type), [TypeArgument(int_type())]),
  )
  let match_binder = metadata.define_value(
    "value",
    MatchBinder,
    Apply(Constructor(option_type), [TypeArgument(int_type())]),
  )
  let payload = metadata.define_value("value", Parameter, int_type())
  let program = Program::{
    metadata,
    terms: [
      Let(
        scrutinee,
        Construct({
          data_constructor: some,
          type_arguments: [TypeArgument(int_type())],
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
  inspect(
    @prettyprinter.render(program.terms[1], width=100),
    content=(
      #|let value#2 = match value#0 as value#1 -> Int {
      #|  datacon#0(value#2) => value#2
      #|}
    ),
  )
}

///|
test "verify buslane function call program" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let value = metadata.define_value("value", Value, int_type())
  let function = metadata.define_value(
    "value",
    Function,
    Function([int_type()], int_type(), Empty),
  )
  let parameter = metadata.define_value("value", Parameter, int_type())
  let program = Program::{
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
test "verify buslane reports structural errors" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let value = metadata.define_value("value", Value, int_type())
  let binder = metadata.define_value("value", MatchBinder, bool_type())
  let program = Program::{
    metadata,
    terms: [
      Let(value, Call(Literal(Int(1L)), [])),
      Let(
        value,
        Match({
          scrutinee: Literal(Bool(true)),
          binder,
          result_type: int_type(),
          alternatives: [
            {
              alt_constructor: Literal(Bool(true)),
              type_binders: [],
              value_binders: [],
              body: Literal(Int(1L)),
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
      #|  not_function Int
      #|  type_mismatch {
      #|    expected Int
      #|    actual Unit
      #|  }
      #|  non_exhaustive_match
      #|}
    ),
  )
}
