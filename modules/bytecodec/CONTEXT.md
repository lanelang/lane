# Bytecodec

`Milky2018/bytecodec` is an independent leaf module for strict byte-level binary encoding and decoding.

## Language

**Byte Writer**:
An append-only in-memory writer for fixed-width little-endian primitives, raw bytes, and u32-length-prefixed bytes and UTF-8 strings.
_Avoid_: artifact writer, schema serializer, streaming file writer

**Byte Reader**:
A forward-only cursor over immutable bytes that tracks an absolute offset and reports structured primitive decode failures.
_Avoid_: semantic validator, resource-policy engine, recovering parser

**Bounded Reader**:
A child Byte Reader that owns one length-delimited view, reports offsets in the coordinate system of the original input, and cannot consume bytes from the enclosing reader.
_Avoid_: copied section, relative-offset reader, section directory

**Domain Codec Adapter**:
A codec in a data-owning module that maps Bytecodec primitives and errors into its own tags, records, schema versions, resource limits, and diagnostics.
_Avoid_: Bytecodec extension with Lane semantics, duplicated byte cursor

## Relationships

- Bytecodec imports only MoonBit UTF-8 support and has no dependency on Lane, Buslane, Lanec, or LoisVM.
- `read_u32_le` and `write_u32_le` use `UInt` so every u32 bit pattern is representable.
- `read_u32_le_int` and `write_u32_le_int` are explicit adapters for nonnegative `Int` data models.
- `read_section` is the canonical seam for nested length-delimited formats.
- Small fixed-layout and tag parsers may pattern match `ByteReader::view`; they must commit only the returned suffix with `update_view`.
- Domain codecs own schema meaning and map ByteDecodeError into domain-specific failure categories.
- Bytecodec does not own version negotiation, enum assignments, allocation policy, resource ceilings, semantic validation, checksums, compression, or IO.
