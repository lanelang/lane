///|
test "generic nested closures preserve erased captures in both backends" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let type_parameter = metadata.define_type_parameter("T", Type)
  let generic_type = @buslane.Type::Parameter(type_parameter)
  let generic_callable_type = @buslane.Type::Function([], generic_type, Empty)
  let make_type = @buslane.Type::Forall(
    [type_parameter],
    Function([generic_type], generic_callable_type, Empty),
  )
  let captured = metadata.define_value("captured", Parameter, generic_type)
  let make = metadata.define_value("make", Function, make_type)
  let string_type = @buslane.Type::Primitive(String)
  let int_type = @buslane.Type::Primitive(Int)
  let unit_type = @buslane.Type::Primitive(Unit)
  let string_callable_type = @buslane.Type::Function([], string_type, Empty)
  let measure_type = @buslane.Type::Function([string_type], int_type, Empty)
  let measure = metadata.define_value("measure", External, measure_type)
  let observe_type = @buslane.Type::Function([int_type], unit_type, Empty)
  let observe = metadata.define_value("observe", External, observe_type)
  let closure = metadata.define_value("closure", Local, string_callable_type)
  let produced = metadata.define_value("produced", Local, string_type)
  let measured = metadata.define_value("measured", Local, int_type)
  let main_type = @buslane.Type::Function([], unit_type, Empty)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(measure),
      External(observe),
      Let(
        make,
        TypeLambda(
          [type_parameter],
          Function({
            parameters: [captured],
            result_type: generic_callable_type,
            body: Function({
              parameters: [],
              result_type: generic_type,
              body: Ref(captured),
            }),
          }),
        ),
      ),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Let(
            closure,
            Call(TypeApply(Ref(make), [TypeArgument(string_type)]), [
              Literal(String("Lane")),
            ]),
            Let(
              produced,
              Call(Ref(closure), []),
              Let(
                measured,
                Call(Ref(measure), [Ref(produced)]),
                Call(Ref(observe), [Ref(measured)]),
              ),
            ),
          ),
        }),
      ),
    ],
  }
  let image = match
    @loisvm_lowering.lower_linked_program_to_bytecode(
      program,
      {
        builtins: [
          {
            value: measure,
            name: "lane.test.string_length",
            type_: measure_type,
          },
          {
            value: observe,
            name: "lane.test.observe_callable_boundary",
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{to_repr(error)}")
  }
  execute_callable_image_in_both_backends(image, 4L)
}

///|
test "nominal values cross erased generic boundaries in both backends" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let element = metadata.define_type_parameter("Element", Type)
  let identity_parameter = metadata.define_type_parameter("T", Type)
  let option = metadata.define_type("Option", [element])
  let some = metadata.define_data_constructor("Some", option, [], [
    Parameter(element),
  ])
  let generic_type = @buslane.Type::Parameter(identity_parameter)
  let identity_type = @buslane.Type::Forall(
    [identity_parameter],
    Function([generic_type], generic_type, Empty),
  )
  let identity_value = metadata.define_value("value", Parameter, generic_type)
  let identity = metadata.define_value("identity", Function, identity_type)
  let string_type = @buslane.Type::Primitive(String)
  let int_type = @buslane.Type::Primitive(Int)
  let unit_type = @buslane.Type::Primitive(Unit)
  let option_string = @buslane.Type::Apply(Constructor(option), [
    TypeArgument(string_type),
  ])
  let measure_type = @buslane.Type::Function([string_type], int_type, Empty)
  let measure = metadata.define_value("measure", External, measure_type)
  let observe_type = @buslane.Type::Function([int_type], unit_type, Empty)
  let observe = metadata.define_value("observe", External, observe_type)
  let constructed = metadata.define_value("constructed", Local, option_string)
  let roundtrip = metadata.define_value("roundtrip", Local, option_string)
  let match_binder = metadata.define_value("option", MatchBinder, option_string)
  let payload = metadata.define_value("payload", MatchBinder, string_type)
  let measured = metadata.define_value("measured", Local, int_type)
  let main_type = @buslane.Type::Function([], unit_type, Empty)
  let main = metadata.define_value("main", Function, main_type)
  let program : @buslane.Program = {
    metadata,
    terms: [
      External(measure),
      External(observe),
      Let(
        identity,
        TypeLambda(
          [identity_parameter],
          Function({
            parameters: [identity_value],
            result_type: generic_type,
            body: Ref(identity_value),
          }),
        ),
      ),
      Let(
        main,
        Function({
          parameters: [],
          result_type: unit_type,
          body: Let(
            constructed,
            Construct({
              data_constructor: some,
              type_arguments: [TypeArgument(string_type)],
              hidden_witnesses: [],
              payloads: [Literal(String("Lane"))],
            }),
            Let(
              roundtrip,
              Call(TypeApply(Ref(identity), [TypeArgument(option_string)]), [
                Ref(constructed),
              ]),
              Match({
                scrutinee: Ref(roundtrip),
                binder: match_binder,
                result_type: unit_type,
                alternatives: [
                  {
                    alt_constructor: DataCon(some),
                    type_binders: [],
                    value_binders: [payload],
                    body: Let(
                      measured,
                      Call(Ref(measure), [Ref(payload)]),
                      Call(Ref(observe), [Ref(measured)]),
                    ),
                  },
                ],
              }),
            ),
          ),
        }),
      ),
    ],
  }
  let image = match
    @loisvm_lowering.lower_linked_program_to_bytecode(
      program,
      {
        builtins: [
          {
            value: measure,
            name: "lane.test.string_length",
            type_: measure_type,
          },
          {
            value: observe,
            name: "lane.test.observe_callable_boundary",
            type_: observe_type,
          },
        ],
      },
      { module_path_text: "Main", name: "main", value: main, type_: main_type },
    ) {
    Ok(value) => value
    Err(error) => fail("lowering failed: \{to_repr(error)}")
  }
  assert_true(image.layouts.contains(Reference))
  execute_callable_image_in_both_backends(image, 4L)
}
