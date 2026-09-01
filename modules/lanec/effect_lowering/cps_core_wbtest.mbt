///|
test "CPS Core certification rejects a residual handler" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_effect("Effect", [])
  let operation = metadata.define_operation(
    "op",
    effect,
    [],
    [],
    Primitive(I64),
  )
  let result = metadata.define_value("result", Value, Primitive(I64))
  let result_binder = metadata.define_value("result", Local, Primitive(I64))
  let continuation = metadata.define_value(
    "continuation",
    Parameter,
    Function([Primitive(I64)], Primitive(I64), Empty),
  )
  let source : @buslane.Program = {
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
                  resume_binder: continuation,
                  body: Call(Ref(continuation), [Literal(I64(1L))]),
                },
              ],
            },
          ],
        }),
      ),
    ],
  }
  let (program, origins) = @function_origin.certify_uniform_program(
    source,
    SourceWritten,
  ).unwrap()
  assert_eq(
    certify_cps_core_program(program, origins, []),
    Err(ResidualHandle(owner=Some(result))),
  )
}

///|
test "CPS Core certification rejects an escaped source effect parameter" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let action = metadata.define_value(
    "action",
    External,
    Forall(
      [effect_parameter],
      Function([], Primitive(Unit), Parameter(effect_parameter)),
    ),
  )
  let source : @buslane.Program = { metadata, terms: [External(action)], }
  let (program, origins) = @function_origin.certify_uniform_program(
    source,
    SourceWritten,
  ).unwrap()
  assert_eq(
    certify_initial_cps_core_program(
      program,
      origins,
      source_effect_parameters(source.metadata),
    ),
    Err(EscapedSourceEffectParameter(effect_parameter)),
  )
}

///|
test "CPS Core certification rejects algebraic latent effects" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect = metadata.define_effect("Effect", [])
  let action = metadata.define_value(
    "action",
    External,
    Function([], Primitive(Unit), Singleton(effect, [])),
  )
  let source : @buslane.Program = { metadata, terms: [External(action)], }
  let (program, origins) = @function_origin.certify_uniform_program(
    source,
    SourceWritten,
  ).unwrap()
  assert_eq(
    certify_cps_core_program(program, origins, []),
    Err(AlgebraicLatentEffect(owner=Some(action), effect=Singleton(effect, []))),
  )
}

///|
test "CPS Core certification rejects a function without provenance" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let entry = metadata.define_value(
    "entry",
    Function,
    Function([], Primitive(Unit), Empty),
  )
  let source : @buslane.Program = {
    metadata,
    terms: [
      Let(
        entry,
        Function({
          parameters: [],
          result_type: Primitive(Unit),
          body: Literal(Unit),
        }),
      ),
    ],
  }
  assert_eq(
    certify_cps_core_program(
      source.certify().unwrap(),
      @function_origin.FunctionOriginCatalog::new(),
      [],
    ),
    Err(MissingFunctionOrigin(owner=Some(entry))),
  )
}
