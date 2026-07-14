///|
fn mon_trans_validation_program(
  metadata : @buslane.MetadataRegistry,
  expression : Expr,
) -> Program {
  let result = metadata.define_value("result", Value, Primitive(Unit))
  { metadata, terms: [Let(result, expression)] }
}

///|
test "mon-trans validator reports every forbidden residual form" {
  let invoke_metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let invoke_effect = invoke_metadata.define_effect("Invoke", [])
  let operation = invoke_metadata.define_operation(
    "operation",
    invoke_effect,
    [],
    [],
    Primitive(Unit),
  )
  assert_eq(
    validate_mon_trans_output(
      mon_trans_validation_program(
        invoke_metadata,
        Invoke({
          operation,
          effect_arguments: [],
          hidden_witnesses: [],
          payloads: [],
        }),
      ),
    ),
    Err(ResidualInvoke(operation)),
  )

  let install_metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let final_parameter = install_metadata.define_value(
    "final",
    Parameter,
    Primitive(Unit),
  )
  assert_eq(
    validate_mon_trans_output(
      mon_trans_validation_program(
        install_metadata,
        Install({
          body: Literal(Unit),
          result_type: Primitive(Unit),
          dictionaries: [],
          final_clause: {
            parameters: [final_parameter],
            result_type: Primitive(Unit),
            body: Ref(final_parameter),
          },
        }),
      ),
    ),
    Err(ResidualInstall),
  )

  let bind_metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let bind_parameter = bind_metadata.define_value(
    "bound",
    Parameter,
    Primitive(Unit),
  )
  assert_eq(
    validate_mon_trans_output(
      mon_trans_validation_program(
        bind_metadata,
        Bind({
          computation: Literal(Unit),
          binder: bind_parameter,
          continuation: {
            parameters: [bind_parameter],
            result_type: Primitive(Unit),
            body: Ref(bind_parameter),
          },
        }),
      ),
    ),
    Err(ResidualBind),
  )

  let parameter_metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let effect_parameter = parameter_metadata.define_type_parameter("E", Effect)
  let effect_value = parameter_metadata.define_value(
    "effect_value",
    External,
    Parameter(effect_parameter),
  )
  assert_eq(
    validate_mon_trans_output({
      metadata: parameter_metadata,
      terms: [External(effect_value)],
    }),
    Err(ResidualEffectParameter(effect_parameter)),
  )

  let argument_metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let argument_effect = argument_metadata.define_effect("Argument", [])
  assert_eq(
    validate_mon_trans_output(
      mon_trans_validation_program(
        argument_metadata,
        TypeApply(Literal(Unit), [
          EffectArgument(Singleton(argument_effect, [])),
        ]),
      ),
    ),
    Err(ResidualEffectArgument(Singleton(argument_effect, []))),
  )

  let latent_metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let latent_effect = latent_metadata.define_effect("Latent", [])
  let latent_value = latent_metadata.define_value(
    "latent",
    External,
    Function([], Primitive(Unit), Singleton(latent_effect, [])),
  )
  assert_eq(
    validate_mon_trans_output({
      metadata: latent_metadata,
      terms: [External(latent_value)],
    }),
    Err(ResidualLatentEffect(Singleton(latent_effect, []))),
  )

  let open_metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let open_effect = open_metadata.define_effect("Concrete", [])
  let concrete : @buslane.Effect = Singleton(open_effect, [])
  assert_eq(
    validate_mon_trans_output(
      mon_trans_validation_program(
        open_metadata,
        OpenContext({
          source_effect: concrete,
          target_effect: concrete,
          body: Literal(Unit),
        }),
      ),
    ),
    Err(ConcreteOpenContext(source=concrete, target=concrete)),
  )
}

///|
test "mon-trans validator permits only abstract open-context plans" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let parameter = metadata.define_type_parameter("E", Effect)
  let abstract_effect : @buslane.Effect = Parameter(parameter)
  assert_eq(
    validate_mon_trans_output(
      mon_trans_validation_program(
        metadata,
        OpenContext({
          source_effect: abstract_effect,
          target_effect: abstract_effect,
          body: Literal(Unit),
        }),
      ),
    ),
    Ok(()),
  )
}
