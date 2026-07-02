///|
fn effect_int_type() -> @buslane.Type {
  Primitive(Int)
}

///|
fn effect_bool_type() -> @buslane.Type {
  Primitive(Bool)
}

///|
fn effect_unit_type() -> @buslane.Type {
  Primitive(Unit)
}

///|
fn effect_expect_ok(program : @buslane.Program) -> Unit raise {
  inspect(
    @prettyprinter.render(@buslane.verify_program(program), width=100),
    content=(
      #|verify_result {}
    ),
  )
}

///|
fn effect_plus_runtime(plus : @buslane.ValueId) -> BuslaneExternalRuntime {
  let runtime = BuslaneExternalRuntime::BuslaneExternalRuntime()
  runtime.add_resolver((id, _type) => {
    if id != plus {
      raise missing_external(id)
    }
    BuslaneRuntimeValue::native_function(arguments => {
      if arguments.length() != 2 {
        raise external_failure(plus, "plus expects two arguments")
      }
      guard arguments[0].as_int() is Some(left) else {
        raise external_failure(plus, "plus expects an integer left argument")
      }
      guard arguments[1].as_int() is Some(right) else {
        raise external_failure(plus, "plus expects an integer right argument")
      }
      BuslaneRuntimeValue::int(left + right)
    })
  })
  runtime
}

///|
test "reader effect supplies the same environment to every ask" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let reader = metadata.define_effect([])
  let ask = metadata.define_operation(reader, [], effect_int_type())
  let plus = metadata.define_value(
    External,
    Function([effect_int_type(), effect_int_type()], effect_int_type(), Empty),
  )
  let first = metadata.define_value(Local, effect_int_type())
  let second = metadata.define_value(Local, effect_int_type())
  let result = metadata.define_value(Value, effect_int_type())
  let final_binder = metadata.define_value(Local, effect_int_type())
  let resume_binder = metadata.define_value(
    Parameter,
    Function([effect_int_type()], effect_int_type(), Empty),
  )
  let program = @buslane.Program::{
    metadata,
    terms: [
      External(plus),
      Let(
        result,
        Handle({
          body: Let(
            first,
            Perform({ operation: ask, type_arguments: [], payloads: [] }),
            Let(
              second,
              Perform({ operation: ask, type_arguments: [], payloads: [] }),
              Call(Ref(plus), [Ref(first), Ref(second)]),
            ),
          ),
          result_binder: final_binder,
          result_type: effect_int_type(),
          final_body: Ref(final_binder),
          handlers: [
            {
              handled_effect: Singleton(reader, []),
              operations: [
                {
                  operation: ask,
                  payload_binders: [],
                  resume_binder,
                  body: Call(Resume(resume_binder), [Literal(Int(21L))]),
                },
              ],
            },
          ],
        }),
      ),
    ],
  }
  effect_expect_ok(program)
  let evaluated = evaluate_buslane_program(program, effect_plus_runtime(plus))
  inspect(
    @prettyprinter.render(evaluated.lookup(result), width=80),
    content="int 42",
  )
}

///|
test "writer effect folds tell payloads around the resumed continuation" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let writer = metadata.define_effect([])
  let tell = metadata.define_operation(
    writer,
    [effect_int_type()],
    effect_unit_type(),
  )
  let plus = metadata.define_value(
    External,
    Function([effect_int_type(), effect_int_type()], effect_int_type(), Empty),
  )
  let first_tell = metadata.define_value(Local, effect_unit_type())
  let second_tell = metadata.define_value(Local, effect_unit_type())
  let result = metadata.define_value(Value, effect_int_type())
  let final_binder = metadata.define_value(Local, effect_int_type())
  let payload = metadata.define_value(Parameter, effect_int_type())
  let resume_binder = metadata.define_value(
    Parameter,
    Function([effect_unit_type()], effect_int_type(), Empty),
  )
  let program = @buslane.Program::{
    metadata,
    terms: [
      External(plus),
      Let(
        result,
        Handle({
          body: Let(
            first_tell,
            Perform({
              operation: tell,
              type_arguments: [],
              payloads: [Literal(Int(3L))],
            }),
            Let(
              second_tell,
              Perform({
                operation: tell,
                type_arguments: [],
                payloads: [Literal(Int(4L))],
              }),
              Literal(Int(10L)),
            ),
          ),
          result_binder: final_binder,
          result_type: effect_int_type(),
          final_body: Ref(final_binder),
          handlers: [
            {
              handled_effect: Singleton(writer, []),
              operations: [
                {
                  operation: tell,
                  payload_binders: [payload],
                  resume_binder,
                  body: Call(Ref(plus), [
                    Ref(payload),
                    Call(Resume(resume_binder), [Literal(Unit)]),
                  ]),
                },
              ],
            },
          ],
        }),
      ),
    ],
  }
  effect_expect_ok(program)
  let evaluated = evaluate_buslane_program(program, effect_plus_runtime(plus))
  inspect(
    @prettyprinter.render(evaluated.lookup(result), width=80),
    content="int 17",
  )
}

///|
test "exception effect aborts the captured continuation with a fallback value" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let exception = metadata.define_effect([])
  let raise_ = metadata.define_operation(
    exception,
    [Primitive(String)],
    effect_int_type(),
  )
  let result = metadata.define_value(Value, effect_int_type())
  let final_binder = metadata.define_value(Local, effect_int_type())
  let message = metadata.define_value(Parameter, Primitive(String))
  let resume_binder = metadata.define_value(
    Parameter,
    Function([effect_int_type()], effect_int_type(), Empty),
  )
  let program = @buslane.Program::{
    metadata,
    terms: [
      Let(
        result,
        Handle({
          body: Perform({
            operation: raise_,
            type_arguments: [],
            payloads: [Literal(String("boom"))],
          }),
          result_binder: final_binder,
          result_type: effect_int_type(),
          final_body: Ref(final_binder),
          handlers: [
            {
              handled_effect: Singleton(exception, []),
              operations: [
                {
                  operation: raise_,
                  payload_binders: [message],
                  resume_binder,
                  body: Literal(Int(42L)),
                },
              ],
            },
          ],
        }),
      ),
    ],
  }
  effect_expect_ok(program)
  let evaluated = evaluate_buslane_program(program, BuslaneExternalRuntime())
  inspect(
    @prettyprinter.render(evaluated.lookup(result), width=80),
    content="int 42",
  )
}

///|
test "nondeterminism effect explores both choices with multi-shot resume" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let nondet = metadata.define_effect([])
  let choose = metadata.define_operation(nondet, [], effect_bool_type())
  let plus = metadata.define_value(
    External,
    Function([effect_int_type(), effect_int_type()], effect_int_type(), Empty),
  )
  let choice = metadata.define_value(Local, effect_bool_type())
  let match_binder = metadata.define_value(MatchBinder, effect_bool_type())
  let result = metadata.define_value(Value, effect_int_type())
  let final_binder = metadata.define_value(Local, effect_int_type())
  let resume_binder = metadata.define_value(
    Parameter,
    Function([effect_bool_type()], effect_int_type(), Empty),
  )
  let program = @buslane.Program::{
    metadata,
    terms: [
      External(plus),
      Let(
        result,
        Handle({
          body: Let(
            choice,
            Perform({ operation: choose, type_arguments: [], payloads: [] }),
            Match({
              scrutinee: Ref(choice),
              binder: match_binder,
              result_type: effect_int_type(),
              alternatives: [
                {
                  alt_constructor: Literal(Bool(true)),
                  type_binders: [],
                  value_binders: [],
                  body: Literal(Int(10L)),
                },
                {
                  alt_constructor: Literal(Bool(false)),
                  type_binders: [],
                  value_binders: [],
                  body: Literal(Int(1L)),
                },
              ],
            }),
          ),
          result_binder: final_binder,
          result_type: effect_int_type(),
          final_body: Ref(final_binder),
          handlers: [
            {
              handled_effect: Singleton(nondet, []),
              operations: [
                {
                  operation: choose,
                  payload_binders: [],
                  resume_binder,
                  body: Call(Ref(plus), [
                    Call(Resume(resume_binder), [Literal(Bool(true))]),
                    Call(Resume(resume_binder), [Literal(Bool(false))]),
                  ]),
                },
              ],
            },
          ],
        }),
      ),
    ],
  }
  effect_expect_ok(program)
  let evaluated = evaluate_buslane_program(program, effect_plus_runtime(plus))
  inspect(
    @prettyprinter.render(evaluated.lookup(result), width=80),
    content="int 11",
  )
}

///|
test "state effect threads state through get and put with a state-passing handler" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let pair_type_id = metadata.define_type([])
  let pair_constructor = metadata.define_data_constructor(pair_type_id, [], [
    effect_int_type(),
    effect_int_type(),
  ])
  let pair_type = @buslane.Type::Constructor(pair_type_id)
  let state_function_type = @buslane.Type::Function(
    [effect_int_type()],
    pair_type,
    Empty,
  )
  let state = metadata.define_effect([])
  let get = metadata.define_operation(state, [], effect_int_type())
  let put = metadata.define_operation(
    state,
    [effect_int_type()],
    effect_unit_type(),
  )
  let result = metadata.define_value(Value, pair_type)
  let old_state = metadata.define_value(Local, effect_int_type())
  let ignored = metadata.define_value(Local, effect_unit_type())
  let final_binder = metadata.define_value(Local, effect_int_type())
  let final_state = metadata.define_value(Parameter, effect_int_type())
  let get_state = metadata.define_value(Parameter, effect_int_type())
  let put_state = metadata.define_value(Parameter, effect_int_type())
  let put_payload = metadata.define_value(Parameter, effect_int_type())
  let get_resume = metadata.define_value(
    Parameter,
    Function([effect_int_type()], state_function_type, Empty),
  )
  let put_resume = metadata.define_value(
    Parameter,
    Function([effect_unit_type()], state_function_type, Empty),
  )
  let program = @buslane.Program::{
    metadata,
    terms: [
      Let(
        result,
        Call(
          Handle({
            body: Let(
              old_state,
              Perform({ operation: get, type_arguments: [], payloads: [] }),
              Let(
                ignored,
                Perform({
                  operation: put,
                  type_arguments: [],
                  payloads: [Literal(Int(7L))],
                }),
                Perform({ operation: get, type_arguments: [], payloads: [] }),
              ),
            ),
            result_binder: final_binder,
            result_type: state_function_type,
            final_body: Function({
              parameters: [final_state],
              result_type: pair_type,
              body: Construct({
                data_constructor: pair_constructor,
                type_arguments: [],
                hidden_witnesses: [],
                payloads: [Ref(final_binder), Ref(final_state)],
              }),
            }),
            handlers: [
              {
                handled_effect: Singleton(state, []),
                operations: [
                  {
                    operation: get,
                    payload_binders: [],
                    resume_binder: get_resume,
                    body: Function({
                      parameters: [get_state],
                      result_type: pair_type,
                      body: Call(Call(Resume(get_resume), [Ref(get_state)]), [
                        Ref(get_state),
                      ]),
                    }),
                  },
                  {
                    operation: put,
                    payload_binders: [put_payload],
                    resume_binder: put_resume,
                    body: Function({
                      parameters: [put_state],
                      result_type: pair_type,
                      body: Call(Call(Resume(put_resume), [Literal(Unit)]), [
                        Ref(put_payload),
                      ]),
                    }),
                  },
                ],
              },
            ],
          }),
          [Literal(Int(1L))],
        ),
      ),
    ],
  }
  effect_expect_ok(program)
  let evaluated = evaluate_buslane_program(program, BuslaneExternalRuntime())
  inspect(
    @prettyprinter.render(evaluated.lookup(result), width=80),
    content=(
      #|data_value datacon#0 {
      #|  int 7
      #|  int 7
      #|}
    ),
  )
}
