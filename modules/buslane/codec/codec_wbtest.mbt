///|
test "program binary codec roundtrips core structures" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let effect_param = metadata.define_type_parameter("E", Effect)
  let type_param = metadata.define_type_parameter("A", Type)
  let box_type = metadata.define_type("Box", [type_param])
  let box_con = metadata.define_data_constructor(
    "box",
    box_type,
    [type_param],
    [Parameter(type_param)],
  )
  let async_effect = metadata.define_effect("Async", [effect_param])
  let await_op = metadata.define_operation(
    "await",
    async_effect,
    [type_param],
    [
      Function(
        [Parameter(type_param)],
        Primitive(Unit),
        Parameter(effect_param),
      ),
    ],
    Parameter(type_param),
  )
  let body = metadata.define_value(
    "body",
    Parameter,
    Function([], Primitive(Int), Singleton(async_effect, [EffectArgument(Io)])),
  )
  let resume_value = metadata.define_value(
    "resume",
    Parameter,
    Function([Primitive(Int)], Primitive(Int), Empty),
  )
  let payload = metadata.define_value("payload", Local, Primitive(Int))
  let main = metadata.define_value(
    "main",
    Function,
    Function([], Primitive(Int), Empty),
  )
  let program : Program = {
    metadata,
    terms: [
      Let(
        main,
        Function({
          parameters: [],
          result_type: Primitive(Int),
          body: Handle({
            body: Perform({
              operation: await_op,
              effect_arguments: [EffectArgument(Empty)],
              hidden_witnesses: [TypeArgument(Primitive(Int))],
              payloads: [
                Function({
                  parameters: [payload],
                  result_type: Primitive(Unit),
                  body: Literal(Unit),
                }),
              ],
            }),
            result_binder: payload,
            result_type: Primitive(Int),
            final_body: Ref(payload),
            handlers: [
              {
                handled_effect: Singleton(async_effect, [EffectArgument(Io)]),
                operations: [
                  {
                    operation: await_op,
                    type_binders: [type_param],
                    payload_binders: [body],
                    resume_binder: resume_value,
                    body: Call(Resume(resume_value), [Literal(Int(42L))]),
                  },
                ],
              },
            ],
          }),
        }),
      ),
      Let(
        payload,
        Construct({
          data_constructor: box_con,
          type_arguments: [TypeArgument(Primitive(Int))],
          hidden_witnesses: [TypeArgument(Primitive(Int))],
          payloads: [Literal(Int(1L))],
        }),
      ),
    ],
  }
  let decoded = decode_program(encode_program(program))
  assert_true(decoded == program)
}

///|
test "program decoder rejects invalid version" {
  let writer = @bytecodec.ByteWriter::new()
  writer.write_u32_le(999)
  let error = try {
    ignore(decode_program(writer.to_bytes()))
    None
  } catch {
    error => Some(error)
  }
  debug_inspect(error, content="Some(UnsupportedCodecVersion(version=999))")
}

///|
test "program decoder rejects trailing bytes" {
  let bytes = encode_program({ metadata: MetadataRegistry(), terms: [] })
  let writer = @bytecodec.ByteWriter::new()
  writer.write_raw_bytes(bytes)
  writer.write_u8(0)
  let error = try {
    ignore(decode_program(writer.to_bytes()))
    None
  } catch {
    error => Some(error)
  }
  debug_inspect(
    error,
    content=(
      #|Some(ByteError(TrailingBytes(offset=36, remaining=1)))
    ),
  )
}

///|
test "program decoder rejects invalid top term tag" {
  let writer = @bytecodec.ByteWriter::new()
  writer.write_u32_le(1) // codec version
  writer.write_u32_le(0) // metadata next_unique
  writer.write_u32_le(0) // types
  writer.write_u32_le(0) // type parameters
  writer.write_u32_le(0) // values
  writer.write_u32_le(0) // data constructors
  writer.write_u32_le(0) // effects
  writer.write_u32_le(0) // operations
  writer.write_u32_le(1) // terms
  writer.write_u8(99)
  let error = try {
    ignore(decode_program(writer.to_bytes()))
    None
  } catch {
    error => Some(error)
  }
  debug_inspect(
    error,
    content=(
      #|Some(InvalidTag(offset=36, domain="TopTerm", tag=99))
    ),
  )
}
