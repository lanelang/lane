///|
using @buslane {type MetadataRegistry, type Program}

///|
test "program binary codec roundtrips core structures" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let effect_param = metadata.define_type_parameter("E", Effect)
  let type_param = metadata.define_type_parameter("A", Type)
  let box_type = metadata.define_type("Box", [type_param])
  let fd_type = metadata.define_type("Fd", [], flavor=External)
  let box_con = metadata.define_data_constructor(
    "box",
    box_type,
    [type_param],
    [Parameter(type_param)],
  )
  let async_effect = metadata.define_effect("Async", [effect_param])
  let vector_op = metadata.define_effect(
    "VectorOp",
    [type_param],
    flavor=External,
  )
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
    Function(
      [],
      Primitive(I64),
      Singleton(async_effect, [
        EffectArgument(Union([Builtin(Io), Builtin(Panic)])),
      ]),
    ),
  )
  let resume_value = metadata.define_value(
    "resume",
    Parameter,
    Function([Primitive(I64)], Primitive(I64), Empty),
  )
  let payload = metadata.define_value("payload", Local, Primitive(I64))
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
          body: Handle({
            body: Perform({
              operation: await_op,
              effect_arguments: [EffectArgument(Empty)],
              hidden_witnesses: [TypeArgument(Primitive(I64))],
              payloads: [
                Function({
                  parameters: [payload],
                  result_type: Primitive(Unit),
                  body: Literal(Unit),
                }),
              ],
            }),
            result_binder: payload,
            result_type: Primitive(I64),
            final_body: Ref(payload),
            handlers: [
              {
                handled_effect: Singleton(async_effect, [
                  EffectArgument(Union([Builtin(Io), Builtin(Panic)])),
                ]),
                operations: [
                  {
                    operation: await_op,
                    type_binders: [type_param],
                    payload_binders: [body],
                    resume_binder: resume_value,
                    body: Call(Resume(resume_value), [Literal(I64(42L))]),
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
          type_arguments: [TypeArgument(Primitive(I64))],
          hidden_witnesses: [TypeArgument(Primitive(I64))],
          payloads: [Literal(I64(1L))],
        }),
      ),
    ],
  }
  let decoded = decode_program(encode_program(program))
  assert_true(decoded == program)
  debug_inspect(
    (
      decoded.metadata.type_info(fd_type).map(info => info.flavor),
      decoded.metadata.effect_info(vector_op).map(info => info.flavor),
    ),
    content="(Some(External), Some(External))",
  )
}

///|
test "program codec writes schema version 9" {
  let bytes = encode_program({ metadata: MetadataRegistry(), terms: [], })
  guard bytes is [i32le(version), ..] else {
    fail("expected Buslane codec version prefix")
  }
  assert_eq(version, 9)
}

///|
test "program decoder rejects schema version 8 at the version boundary" {
  let writer = @bytecodec.ByteWriter::new()
  writer.write_u32_le_int(8)
  let error = try {
    ignore(decode_program(writer.to_bytes()))
    None
  } catch {
    error => Some(error)
  }
  debug_inspect(error, content="Some(UnsupportedCodecVersion(version=8))")
}

///|
test "program decoder rejects invalid version" {
  let writer = @bytecodec.ByteWriter::new()
  writer.write_u32_le_int(999)
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
  let bytes = encode_program({ metadata: MetadataRegistry(), terms: [], })
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
      #|Some(ByteError(TrailingBytes(offset=37, remaining=1)))
    ),
  )
}

///|
test "program decoder rejects invalid top term tag" {
  let writer = @bytecodec.ByteWriter::new()
  writer.write_u32_le_int(9) // codec version
  writer.write_u8(0) // fresh metadata name allocator
  writer.write_u32_le_int(0) // metadata next_unique
  writer.write_u32_le_int(0) // types
  writer.write_u32_le_int(0) // type parameters
  writer.write_u32_le_int(0) // values
  writer.write_u32_le_int(0) // data constructors
  writer.write_u32_le_int(0) // effects
  writer.write_u32_le_int(0) // operations
  writer.write_u32_le_int(1) // terms
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
      #|Some(InvalidTag(offset=37, domain="TopTerm", tag=99))
    ),
  )
}

///|
test "program codec roundtrips the last unique and exhausted allocator" {
  let metadata = MetadataRegistry::MetadataRegistry()
  metadata.name_allocator = Fresh(
    @buslane.BuslaneUnique::from_int(0x7FFFFFFF).unwrap(),
  )
  assert_eq(
    decode_program(encode_program({ metadata, terms: [], })).metadata,
    metadata,
  )
  ignore(metadata.define_value("last", Value, Primitive(Unit)))
  assert_eq(metadata.name_allocator, Exhausted)
  assert_eq(
    decode_program(encode_program({ metadata, terms: [], })).metadata,
    metadata,
  )
}

///|
test "program decoder rejects an invalid metadata allocator tag" {
  let writer = @bytecodec.ByteWriter::new()
  writer.write_u32_le_int(9)
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
      #|Some(InvalidTag(offset=4, domain="metadata name allocator", tag=99))
    ),
  )
}

///|
test "program codec roundtrips I32 type and literal" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let value = metadata.define_value("value", Value, Primitive(I32))
  let program : Program = {
    metadata,
    terms: [Let(value, Literal(I32(-2147483647 - 1)))],
  }
  assert_eq(decode_program(encode_program(program)), program)
}

///|
test "program codec roundtrips F32 type and literal" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let value = metadata.define_value("value", Value, Primitive(F32))
  let program : Program = {
    metadata,
    terms: [Let(value, Literal(F32(Float::reinterpret_from_int(0x3EAAAAAB))))],
  }
  assert_eq(decode_program(encode_program(program)), program)
}

///|
test "program codec roundtrips Char type and literal" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let value = metadata.define_value("value", Value, Primitive(Char))
  let program : Program = {
    metadata,
    terms: [Let(value, Literal(Char(0x1F600)))],
  }
  assert_eq(decode_program(encode_program(program)), program)
}

///|
test "program codec roundtrips the built-in Array constructor" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let value = metadata.define_value(
    "values",
    Value,
    Apply(BuiltinConstructor(Array), [TypeArgument(Primitive(I64))]),
  )
  let program : Program = { metadata, terms: [External(value)], }
  assert_eq(decode_program(encode_program(program)), program)
}

///|
test "program decoder rejects invalid Char literals" {
  let errors : Array[@codec.BuslaneDecodeError] = []
  for value in [-1, 0xD800, 0xDFFF, 0x110000] {
    let metadata = MetadataRegistry::MetadataRegistry()
    let target = metadata.define_value("target", Value, Primitive(Char))
    let program : Program = {
      metadata,
      terms: [Let(target, Literal(Char(value)))],
    }
    let error = try {
      ignore(decode_program(encode_program(program)))
      None
    } catch {
      error => Some(error)
    }
    match error {
      Some(error) => errors.push(error)
      None => fail("expected invalid Unicode scalar")
    }
  }
  debug_inspect(
    errors,
    content=(
      #|[
      #|  InvalidUnicodeScalar(offset=62, value=-1),
      #|  InvalidUnicodeScalar(offset=62, value=55296),
      #|  InvalidUnicodeScalar(offset=62, value=57343),
      #|  InvalidUnicodeScalar(offset=62, value=1114112),
      #|]
    ),
  )
}
