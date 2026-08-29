///|
fn runtime_anf_test_input(program : @buslane.Program) -> RuntimeAnfInput {
  let retained_values = []
  for term in program.terms {
    match term {
      Let(value, _) | External(value) => retained_values.push(value)
      LetRec(bindings) =>
        for binding in bindings {
          retained_values.push(binding.id)
        }
    }
  }
  let (program, function_origins) = @function_origin.certify_uniform_program(
    program,
    SourceWritten,
  ).unwrap()
  { program, retained_values, function_origins, }
}

///|
fn verify_forged_runtime_anf(
  program : AnfProgram,
) -> Result[Unit, RuntimeAnfLoweringError] {
  try {
    verify_runtime_anf(program)
    Ok(())
  } catch {
    error => Err(error)
  }
}

///|
test "lower buslane function call to ANF" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let result = metadata.define_value("value", Value, Primitive(I64))
  let function = metadata.define_value(
    "value",
    Function,
    Function([Primitive(I64)], Primitive(I64), Empty),
  )
  let parameter = metadata.define_value("value", Parameter, Primitive(I64))
  let program = @buslane.Program::{
    metadata,
    terms: [
      LetRec([
        {
          id: function,
          rhs: Function({
            parameters: [parameter],
            result_type: Primitive(I64),
            body: Ref(parameter),
          }),
        },
      ]),
      Let(result, Call(Ref(function), [Literal(I64(42L))])),
    ],
  }
  inspect(
    @prettyprinter.render(
      lower_cps_core_to_runtime_anf(runtime_anf_test_input(program)).unwrap(),
      width=100,
    ),
    content=(
      #|anf {
      #|  letrec {
      #|    value#1 = fn@0(value#2) -> I64 {
      #|      value#2
      #|    }
      #|  }
      #|  let value#0 = {
      #|    let temp#0 : I64 = value#1(42)
      #|    temp#0
      #|  }
      #|}
    ),
  )
}

///|
test "ANF binds a match before applying its continuation" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let consume = metadata.define_value(
    "consume",
    External,
    Function([Primitive(Bool)], Primitive(I64), Empty),
  )
  let result = metadata.define_value("result", Value, Primitive(I64))
  let binder = metadata.define_value("matched", MatchBinder, Primitive(Bool))
  let program = @buslane.Program::{
    metadata,
    terms: [
      External(consume),
      Let(
        result,
        Call(Ref(consume), [
          Match({
            scrutinee: Literal(Bool(true)),
            binder,
            result_type: Primitive(Bool),
            alternatives: [
              {
                alt_constructor: Literal(Bool(true)),
                type_binders: [],
                value_binders: [],
                body: Literal(Bool(true)),
              },
              {
                alt_constructor: Default,
                type_binders: [],
                value_binders: [],
                body: Literal(Bool(false)),
              },
            ],
          }),
        ]),
      ),
    ],
  }
  debug_inspect(
    (match lower_cps_core_to_runtime_anf(runtime_anf_test_input(program)) {
      Ok(program) => program
      Err(error) => abort("unexpected runtime ANF error: \{Repr(error)}")
    }).terms()[1],
    content=(
      #|Let(
      #|  { index: 1 },
      #|  Let(
      #|    Temp(
      #|      temp={ index: 0 },
      #|      type_=Scalar(Bool),
      #|      rhs=Match(
      #|        {
      #|          scrutinee: Literal(Bool(true)),
      #|          binder: { index: 2 },
      #|          result_type: Scalar(Bool),
      #|          alternatives: [
      #|            {
      #|              alt_constructor: Literal(Bool(true)),
      #|              evidence_binders: [],
      #|              value_binders: [],
      #|              body: Atom(Literal(Bool(true))),
      #|            },
      #|            {
      #|              alt_constructor: Default,
      #|              evidence_binders: [],
      #|              value_binders: [],
      #|              body: Atom(Literal(Bool(false))),
      #|            },
      #|          ],
      #|        },
      #|      ),
      #|    ),
      #|    Let(
      #|      Temp(
      #|        temp={ index: 1 },
      #|        type_=Scalar(I64),
      #|        rhs=Call(callee=Ref({ index: 0 }), arguments=[Temp({ index: 0 })]),
      #|      ),
      #|      Atom(Temp({ index: 1 })),
      #|    ),
      #|  ),
      #|)
    ),
  )
}

///|
test "runtime ANF rejects residual handlers" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_effect("Effect", [])
  let operation = metadata.define_operation(
    "op",
    effect,
    [],
    [],
    Primitive(I64),
  )
  let result = metadata.define_value("value", Value, Primitive(I64))
  let result_binder = metadata.define_value("value", Local, Primitive(I64))
  let resume_value = metadata.define_value(
    "value",
    Parameter,
    Function([Primitive(I64)], Primitive(I64), Empty),
  )
  let first_resume = metadata.define_value("value", Local, Primitive(I64))
  let program = @buslane.Program::{
    metadata,
    terms: [
      Let(
        result,
        Handle({
          body: Perform({
            operation,
            effect_arguments: [],
            hidden_witnesses: [],
            payloads: [],
          }),
          result_binder,
          result_type: Primitive(I64),
          final_body: Ref(result_binder),
          handlers: [
            {
              handled_effect: Singleton(effect, []),
              operations: [
                {
                  operation,
                  type_binders: [],
                  payload_binders: [],
                  resume_binder: resume_value,
                  body: Let(
                    first_resume,
                    Call(Ref(resume_value), [Literal(I64(1L))]),
                    Call(Ref(resume_value), [Ref(first_resume)]),
                  ),
                },
              ],
            },
          ],
        }),
      ),
    ],
  }
  assert_true(
    lower_cps_core_to_runtime_anf(runtime_anf_test_input(program))
    is Err(ResidualHandle),
  )
}

///|
fn nested_callable_disposition_program(
  recursive_body : (@buslane.ValueId, @buslane.ValueId, @buslane.ValueId) -> @buslane.Expr,
  enclosing_body : (@buslane.ValueId) -> @buslane.Expr,
  main_result : @buslane.Type,
) -> @buslane.Program raise @buslane.MetadataAllocationError {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64 = @buslane.Type::Primitive(I64)
  let loop_type = @buslane.Type::Function([i64], i64, Empty)
  let main = metadata.define_value(
    "main",
    Function,
    Function([], main_result, Empty),
  )
  let recursive = metadata.define_value("loop", Local, loop_type)
  let parameter = metadata.define_value("n", Parameter, i64)
  let non_tail_result = metadata.define_value("result", Local, i64)
  {
    metadata,
    terms: [
      Let(
        main,
        Function({
          parameters: [],
          result_type: main_result,
          body: LetRec(
            [
              {
                id: recursive,
                rhs: Function({
                  parameters: [parameter],
                  result_type: i64,
                  body: recursive_body(recursive, parameter, non_tail_result),
                }),
              },
            ],
            enclosing_body(recursive),
          ),
        }),
      ),
    ],
  }
}

///|
fn nested_callable_atom(program : @buslane.Program) -> AnfAtom {
  let anf = lower_cps_core_to_runtime_anf(runtime_anf_test_input(program)).unwrap()
  guard anf.terms()[0] is Let(_, Atom(Function(main))) else {
    abort("expected one enclosing function")
  }
  match main.body {
    LetRec([binding], _) => binding.rhs
    Let(Value(rhs=Atom(atom), ..), _) => atom
    _ => abort("expected one nested callable")
  }
}

///|
test "runtime ANF classifies a saturated tail-only recursive group as a join point" {
  let i64 = @buslane.Type::Primitive(I64)
  let program = nested_callable_disposition_program(
    (recursive, parameter, _) => Call(Ref(recursive), [Ref(parameter)]),
    recursive => Call(Ref(recursive), [Literal(I64(0L))]),
    i64,
  )
  assert_true(nested_callable_atom(program) is JoinPoint(_))
}

///|
test "runtime ANF classifies a saturated non-tail recursive group as direct" {
  let i64 = @buslane.Type::Primitive(I64)
  let program = nested_callable_disposition_program(
    (recursive, parameter, result) => {
      Let(result, Call(Ref(recursive), [Ref(parameter)]), Literal(I64(1L)))
    },
    recursive => Call(Ref(recursive), [Literal(I64(0L))]),
    i64,
  )
  assert_true(nested_callable_atom(program) is DirectFunction(_))
}

///|
test "runtime ANF preserves closure semantics for a returned local function" {
  let i64 = @buslane.Type::Primitive(I64)
  let loop_type = @buslane.Type::Function([i64], i64, Empty)
  let program = nested_callable_disposition_program(
    (_, parameter, _) => Ref(parameter),
    recursive => Ref(recursive),
    loop_type,
  )
  assert_true(nested_callable_atom(program) is Function(_))
}

///|
test "runtime ANF partitions an escaping callable from an independent join SCC" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64 = @buslane.Type::Primitive(I64)
  let callable = @buslane.Type::Function([i64], i64, Empty)
  let main = metadata.define_value(
    "main",
    Function,
    Function([], callable, Empty),
  )
  let recursive = metadata.define_value("loop", Local, callable)
  let escape = metadata.define_value("escape", Local, callable)
  let loop_parameter = metadata.define_value("n", Parameter, i64)
  let escape_parameter = metadata.define_value("value", Parameter, i64)
  let source = @buslane.Program::{
    metadata,
    terms: [
      Let(
        main,
        Function({
          parameters: [],
          result_type: callable,
          body: LetRec(
            [
              {
                id: recursive,
                rhs: Function({
                  parameters: [loop_parameter],
                  result_type: i64,
                  body: Call(Ref(recursive), [Ref(loop_parameter)]),
                }),
              },
              {
                id: escape,
                rhs: Function({
                  parameters: [escape_parameter],
                  result_type: i64,
                  body: Ref(escape_parameter),
                }),
              },
            ],
            Ref(escape),
          ),
        }),
      ),
    ],
  }
  let lowered = lower_cps_core_to_runtime_anf(runtime_anf_test_input(source)).unwrap()
  guard lowered.terms is [Let(_, Atom(Function(lowered_main)))] &&
    lowered_main.body is LetRec([loop_binding], Let(escape_binding, _)) else {
    fail("expected a recursive SCC around an acyclic callable binding")
  }
  assert_true(loop_binding.rhs is JoinPoint(_))
  assert_true(
    escape_binding is Value(id=actual, rhs=Atom(Function(_))) &&
    actual == escape,
  )
}

///|
test "runtime ANF partitions independent recursive SCCs with different results" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let i64 = @buslane.Type::Primitive(I64)
  let bool = @buslane.Type::Primitive(Bool)
  let i64_callable = @buslane.Type::Function([i64], i64, Empty)
  let bool_callable = @buslane.Type::Function([bool], bool, Empty)
  let main = metadata.define_value("main", Function, Function([], i64, Empty))
  let integers = metadata.define_value("integers", Local, i64_callable)
  let booleans = metadata.define_value("booleans", Local, bool_callable)
  let integer = metadata.define_value("integer", Parameter, i64)
  let boolean = metadata.define_value("boolean", Parameter, bool)
  let source = @buslane.Program::{
    metadata,
    terms: [
      Let(
        main,
        Function({
          parameters: [],
          result_type: i64,
          body: LetRec(
            [
              {
                id: integers,
                rhs: Function({
                  parameters: [integer],
                  result_type: i64,
                  body: Call(Ref(integers), [Ref(integer)]),
                }),
              },
              {
                id: booleans,
                rhs: Function({
                  parameters: [boolean],
                  result_type: bool,
                  body: Call(Ref(booleans), [Ref(boolean)]),
                }),
              },
            ],
            Call(Ref(integers), [Literal(I64(0L))]),
          ),
        }),
      ),
    ],
  }
  let lowered = lower_cps_core_to_runtime_anf(runtime_anf_test_input(source)).unwrap()
  guard lowered.terms is [Let(_, Atom(Function(lowered_main)))] &&
    lowered_main.body is LetRec([integer_binding], LetRec([boolean_binding], _)) else {
    fail("expected two minimal recursive SCCs")
  }
  assert_true(integer_binding.rhs is JoinPoint(_))
  assert_true(boolean_binding.rhs is JoinPoint(_))
}

///|
test "runtime ANF verifier rejects a first-class join point" {
  let i64 = @buslane.Type::Primitive(I64)
  let lowered = lower_cps_core_to_runtime_anf(
    runtime_anf_test_input(
      nested_callable_disposition_program(
        (recursive, parameter, _) => Call(Ref(recursive), [Ref(parameter)]),
        recursive => Call(Ref(recursive), [Literal(I64(0L))]),
        i64,
      ),
    ),
  ).unwrap()
  guard lowered.terms is [Let(main_id, Atom(Function(main)))] &&
    main.body is LetRec([binding], _) &&
    binding.rhs is JoinPoint(function) else {
    fail("expected one classified join point")
  }
  let invalid : AnfProgram = {
    metadata: lowered.metadata,
    terms: [
      Let(
        main_id,
        Atom(
          Function({
            ..main,
            body: LetRec(
              [{ ..binding, rhs: JoinPoint(function), }],
              Atom(Ref(binding.id)),
            ),
          }),
        ),
      ),
    ],
  }
  let verification : Result[Unit, RuntimeAnfLoweringError] = try {
    verify_callable_dispositions(invalid)
    Ok(())
  } catch {
    error => Err(error)
  }
  assert_true(
    verification
    is Err(InvalidRuntimeAnf({ kind: CallableDispositionMismatch(_), .. })),
  )
}

///|
test "runtime ANF verifier rejects an unsaturated direct-only call" {
  let i64 = @buslane.Type::Primitive(I64)
  let lowered = lower_cps_core_to_runtime_anf(
    runtime_anf_test_input(
      nested_callable_disposition_program(
        (recursive, parameter, result) => {
          Let(result, Call(Ref(recursive), [Ref(parameter)]), Literal(I64(1L)))
        },
        recursive => Call(Ref(recursive), [Literal(I64(0L))]),
        i64,
      ),
    ),
  ).unwrap()
  guard lowered.terms is [Let(main_id, Atom(Function(main)))] &&
    main.body is LetRec([binding], _) &&
    binding.rhs is DirectFunction(function) else {
    fail("expected one classified direct-only function")
  }
  let invalid : AnfProgram = {
    metadata: lowered.metadata,
    terms: [
      Let(
        main_id,
        Atom(
          Function({
            ..main,
            body: LetRec(
              [{ ..binding, rhs: DirectFunction(function), }],
              Let(
                Temp(
                  temp={ index: 999, },
                  type_=Scalar(I64),
                  rhs=Call(callee=Ref(binding.id), arguments=[]),
                ),
                Atom(Temp({ index: 999, })),
              ),
            ),
          }),
        ),
      ),
    ],
  }
  let verification : Result[Unit, RuntimeAnfLoweringError] = try {
    verify_callable_dispositions(invalid)
    Ok(())
  } catch {
    error => Err(error)
  }
  assert_true(
    verification
    is Err(InvalidRuntimeAnf({ kind: CallableDispositionMismatch(_), .. })),
  )
}

///|
test "Runtime ANF boundary rejects a top-level value without metadata" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let source : @buslane.Program = { metadata, terms: [], }
  let lowered = lower_cps_core_to_runtime_anf(runtime_anf_test_input(source)).unwrap()
  let missing : @buslane.ValueId = { index: 0, }
  let invalid : AnfProgram = {
    metadata: lowered.metadata,
    terms: [External(missing)],
  }
  assert_true(
    verify_forged_runtime_anf(invalid)
    is Err(
      InvalidRuntimeAnf(
        { kind: MissingValueMetadata(actual), path: [TopTerm(0)], }
      )
    ) &&
    actual == missing,
  )
}

///|
test "Runtime ANF boundary rejects an unbound temporary" {
  let i64 = @buslane.Type::Primitive(I64)
  let lowered = lower_cps_core_to_runtime_anf(
    runtime_anf_test_input(
      nested_callable_disposition_program(
        (_, parameter, _) => Ref(parameter),
        recursive => Call(Ref(recursive), [Literal(I64(0L))]),
        i64,
      ),
    ),
  ).unwrap()
  guard lowered.terms is [Let(main_id, Atom(Function(main)))] else {
    fail("expected one top-level function")
  }
  let missing : AnfTempId = { index: 999, }
  let invalid : AnfProgram = {
    metadata: lowered.metadata,
    terms: [
      Let(main_id, Atom(Function({ ..main, body: Atom(Temp(missing)), }))),
    ],
  }
  assert_true(
    verify_forged_runtime_anf(invalid)
    is Err(
      InvalidRuntimeAnf(
        { kind: UnboundTemp(actual), path: [TopTerm(0), AnfFunction(_)], }
      )
    ) &&
    actual == missing,
  )
}

///|
test "Runtime ANF boundary rejects an unbound value with complete metadata" {
  let i64 = @buslane.Type::Primitive(I64)
  let lowered = lower_cps_core_to_runtime_anf(
    runtime_anf_test_input(
      nested_callable_disposition_program(
        (_, parameter, _) => Ref(parameter),
        recursive => Call(Ref(recursive), [Literal(I64(0L))]),
        i64,
      ),
    ),
  ).unwrap()
  guard lowered.terms is [Let(main_id, Atom(Function(main)))] else {
    fail("expected one top-level function")
  }
  let nested = match main.body {
    LetRec([binding], _) => anf_atom_function(binding.rhs)
    Let(Value(rhs=Atom(atom), ..), _) => anf_atom_function(atom)
    _ => None
  }
  guard nested is Some(nested) && nested.parameters is [unbound] else {
    fail("expected one nested callable parameter")
  }
  let invalid : AnfProgram = {
    metadata: lowered.metadata,
    terms: [Let(main_id, Atom(Function({ ..main, body: Atom(Ref(unbound)), })))],
  }
  assert_true(
    verify_forged_runtime_anf(invalid)
    is Err(InvalidRuntimeAnf({ kind: UnboundValue(actual), .. })) &&
    actual == unbound,
  )
}

///|
test "Runtime ANF boundary rejects a missing type expression" {
  let i64 = @buslane.Type::Primitive(I64)
  let lowered = lower_cps_core_to_runtime_anf(
    runtime_anf_test_input(
      nested_callable_disposition_program(
        (_, parameter, _) => Ref(parameter),
        recursive => Call(Ref(recursive), [Literal(I64(0L))]),
        i64,
      ),
    ),
  ).unwrap()
  guard lowered.terms is [Let(main_id, Atom(Function(main)))] else {
    fail("expected one top-level function")
  }
  let missing : RuntimeTypeExpressionId = { index: 999, }
  let temp : AnfTempId = { index: 999, }
  let invalid : AnfProgram = {
    metadata: lowered.metadata,
    terms: [
      Let(
        main_id,
        Atom(
          Function({
            ..main,
            body: Let(
              Temp(
                temp~,
                type_=Erased(missing, Static(I64)),
                rhs=Atom(Literal(I64(0L))),
              ),
              Atom(Temp(temp)),
            ),
          }),
        ),
      ),
    ],
  }
  assert_true(
    verify_forged_runtime_anf(invalid)
    is Err(InvalidRuntimeAnf({ kind: MissingTypeExpression(actual), .. })) &&
    actual == missing,
  )
}

///|
test "Runtime ANF boundary rejects an empty recursive group" {
  let i64 = @buslane.Type::Primitive(I64)
  let lowered = lower_cps_core_to_runtime_anf(
    runtime_anf_test_input(
      nested_callable_disposition_program(
        (_, parameter, _) => Ref(parameter),
        recursive => Call(Ref(recursive), [Literal(I64(0L))]),
        i64,
      ),
    ),
  ).unwrap()
  guard lowered.terms is [Let(main_id, Atom(Function(main)))] else {
    fail("expected one top-level function")
  }
  let invalid : AnfProgram = {
    metadata: lowered.metadata,
    terms: [
      Let(
        main_id,
        Atom(Function({ ..main, body: LetRec([], Atom(Literal(I64(0L)))), })),
      ),
    ],
  }
  assert_true(
    verify_forged_runtime_anf(invalid)
    is Err(InvalidRuntimeAnf({ kind: InvalidRecursiveGroup, .. })),
  )
}

///|
test "Runtime ANF boundary includes callable disposition verification" {
  let i64 = @buslane.Type::Primitive(I64)
  let lowered = lower_cps_core_to_runtime_anf(
    runtime_anf_test_input(
      nested_callable_disposition_program(
        (recursive, parameter, result) => {
          Let(result, Call(Ref(recursive), [Ref(parameter)]), Literal(I64(1L)))
        },
        recursive => Call(Ref(recursive), [Literal(I64(0L))]),
        i64,
      ),
    ),
  ).unwrap()
  guard lowered.terms is [Let(main_id, Atom(Function(main)))] &&
    main.body is LetRec([binding], body) &&
    binding.rhs is DirectFunction(function) else {
    fail("expected one direct-only recursive function")
  }
  let invalid : AnfProgram = {
    metadata: lowered.metadata,
    terms: [
      Let(
        main_id,
        Atom(
          Function({
            ..main,
            body: LetRec([{ ..binding, rhs: Function(function), }], body),
          }),
        ),
      ),
    ],
  }
  assert_true(
    verify_forged_runtime_anf(invalid)
    is Err(InvalidRuntimeAnf({ kind: CallableDispositionMismatch(_), .. })),
  )
}

///|
fn runtime_argument_for_test(
  expression : Int,
  layout : RuntimeLayout,
) -> RuntimeArgument {
  { type_expression: { index: expression, }, evidence: Static(layout), }
}

///|
test "Runtime ANF instantiates an evidence application result" {
  let parameter : RuntimeEvidenceParameter = { id: Projected(0), arity: 0, }
  let callee : @buslane.ValueId = { index: 0, }
  let result : @buslane.ValueId = { index: 1, }
  let temp : AnfTempId = { index: 0, }
  let metadata : RuntimeMetadata = {
    values: [
      {
        type_: Forall(
          [parameter],
          Erased({ index: 0, }, Parameter(parameter.id)),
        ),
      },
      { type_: Unit, },
    ],
    types: [],
    data_constructors: [],
    evidence_parameters: [Some(parameter)],
    type_expressions: [Parameter(parameter.id), Static(Scalar(I64))],
  }
  let invalid : AnfProgram = {
    metadata,
    terms: [
      External(callee),
      Let(
        result,
        Let(
          Temp(
            temp~,
            type_=Unit,
            rhs=ApplyEvidence(callee=Ref(callee), arguments=[
              runtime_argument_for_test(1, I64),
            ]),
          ),
          Atom(Temp(temp)),
        ),
      ),
    ],
  }
  assert_true(
    verify_forged_runtime_anf(invalid)
    is Err(
      InvalidRuntimeAnf(
        { kind: RuntimeTypeMismatch(expected=Unit, actual=Scalar(I64)), .. }
      )
    ),
  )
}

///|
test "Runtime ANF rejects disagreement between a runtime type expression and its evidence" {
  let parameter : RuntimeEvidenceParameter = { id: Projected(0), arity: 0, }
  let callee : @buslane.ValueId = { index: 0, }
  let result : @buslane.ValueId = { index: 1, }
  let temp : AnfTempId = { index: 0, }
  let inconsistent = runtime_argument_for_test(1, Bool)
  let metadata : RuntimeMetadata = {
    values: [
      {
        type_: Forall(
          [parameter],
          Erased({ index: 0, }, Parameter(parameter.id)),
        ),
      },
      { type_: Scalar(I64), },
    ],
    types: [],
    data_constructors: [],
    evidence_parameters: [Some(parameter)],
    type_expressions: [Parameter(parameter.id), Static(Scalar(I64))],
  }
  let invalid : AnfProgram = {
    metadata,
    terms: [
      External(callee),
      Let(
        result,
        Let(
          Temp(
            temp~,
            type_=Scalar(I64),
            rhs=ApplyEvidence(callee=Ref(callee), arguments=[inconsistent]),
          ),
          Atom(Temp(temp)),
        ),
      ),
    ],
  }
  assert_true(
    verify_forged_runtime_anf(invalid)
    is Err(InvalidRuntimeAnf({ kind: InvalidRuntimeArgument(actual), .. })) &&
    actual == inconsistent,
  )
}

///|
fn generic_box_runtime_anf(
  type_argument : RuntimeArgument,
  payload : AnfAtom,
) -> AnfProgram {
  let parameter : RuntimeEvidenceParameter = { id: Projected(0), arity: 0, }
  let owner : @buslane.TypeId = { index: 0, }
  let data_constructor : @buslane.DataConId = { index: 0, }
  let result : @buslane.ValueId = { index: 0, }
  let expected_argument = runtime_argument_for_test(1, I64)
  let expected = RuntimeType::Data(owner, [expected_argument])
  let temp : AnfTempId = { index: 0, }
  {
    metadata: {
      values: [{ type_: expected, }],
      types: [
        {
          kind: Data,
          evidence_parameters: [parameter],
          constructors: [data_constructor],
        },
      ],
      data_constructors: [
        {
          owner,
          hidden_evidence_parameters: [],
          payload_types: [Erased({ index: 0, }, Parameter(parameter.id))],
        },
      ],
      evidence_parameters: [Some(parameter)],
      type_expressions: [
        Parameter(parameter.id),
        Static(Scalar(I64)),
        Static(Scalar(Bool)),
      ],
    },
    terms: [
      Let(
        result,
        Let(
          Temp(
            temp~,
            type_=expected,
            rhs=Construct({
              data_constructor,
              type_arguments: [type_argument],
              hidden_arguments: [],
              payloads: [payload],
            }),
          ),
          Atom(Temp(temp)),
        ),
      ),
    ],
  }
}

///|
test "Runtime ANF constructor result preserves complete nominal arguments" {
  let invalid = generic_box_runtime_anf(
    runtime_argument_for_test(2, Bool),
    Literal(Bool(true)),
  )
  assert_true(
    verify_forged_runtime_anf(invalid)
    is Err(InvalidRuntimeAnf({ kind: RuntimeTypeMismatch(_), .. })),
  )
}

///|
test "Runtime ANF constructor payload uses the instantiated field type" {
  let invalid = generic_box_runtime_anf(
    runtime_argument_for_test(1, I64),
    Literal(Bool(true)),
  )
  assert_true(
    verify_forged_runtime_anf(invalid)
    is Err(
      InvalidRuntimeAnf(
        {
          kind: RuntimeTypeMismatch(expected=Scalar(I64), actual=Scalar(Bool)),
          ..
        }
      )
    ),
  )
}
