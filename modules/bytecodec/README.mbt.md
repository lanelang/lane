# Bytecodec

`Milky2018/bytecodec` is a small, domain-independent foundation for strict binary formats in MoonBit.

It provides:

- an append-only `ByteWriter`;
- a forward-only `ByteReader` with absolute offsets;
- fixed-width little-endian integer and floating-point primitives;
- canonical booleans and u32-length-prefixed bytes and UTF-8 strings;
- zero-copy raw views and bounded child readers;
- structured low-level decode errors.

It deliberately does not know about artifact headers, schema versions, enum tags, resource policies, compiler IR, or virtual-machine instructions. Those belong to codecs in the modules that own the corresponding data model.

## Basic usage

```mbt check
///|
test "encode and decode a small record" {
  let writer = ByteWriter::new()
  writer.write_u8(3)
  writer.write_u32_le(42U)
  writer.write_string("lane")

  let reader = ByteReader::from_bytes(writer.to_bytes())
  debug_inspect(
    (reader.read_u8(), reader.read_u32_le(), reader.read_string()),
    content="(3, 42, \"lane\")",
  )
  reader.expect_end()
}
```

## Bounded sections

Use a child reader when an enclosing schema gives a byte length. The parent advances over the whole section immediately, and the child retains absolute offsets into the original input.

```mbt check
///|
test "decode a bounded section" {
  let reader = ByteReader::from_bytes(b"\x02\x00\x00\x00\xaa\xbb\xcc")
  let length = reader.read_u32_le_int()
  let section = reader.read_section(length, expected="payload")
  debug_inspect(
    (section.offset(), section.read_u8(), section.read_u8(), reader.read_u8()),
    content="(4, 170, 187, 204)",
  )
  section.expect_end()
  reader.expect_end()
}
```

## Unsigned values

`read_u32_le` returns `UInt`, preserving the complete wire domain. Callers whose in-memory model uses nonnegative `Int` can use `read_u32_le_int`; values above the host range produce `ImplementationLimit` instead of being mistaken for malformed signed data.

`write_u32_le` accepts `UInt`. `write_u32_le_int` is the checked adapter for nonnegative `Int` values. Signed 32-bit bit patterns use `write_i32_le` explicitly.

## Pattern parsers

Domain codecs may inspect `reader.view()` with a small MoonBit bitstring pattern for fixed magic bytes or closed tags, then call `reader.update_view(rest)`. `update_view` accepts only a suffix of the current view. Ordinary primitive fields should use the typed reader methods.

## Validation

From this module directory:

```bash
moon check --target all
moon test --target all
moon info
moon fmt
```
