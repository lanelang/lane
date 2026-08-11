# Bytecodec

Bytecodec is a domain-neutral leaf module for strict in-memory binary encoding
and decoding.

## Language

**Byte Writer**:
An append-only writer for primitive values and length-delimited byte sequences.
_Avoid_: schema serializer, artifact writer

**Byte Reader**:
A forward-only cursor over immutable bytes that reports structured failures at
absolute input offsets.
_Avoid_: semantic validator, recovering parser

**Bounded Reader**:
A Byte Reader restricted to one length-delimited region while preserving the
parent input's offset coordinates.
_Avoid_: copied section, relative-offset reader

**Domain Codec Adapter**:
A data-owning codec that maps Bytecodec primitives and failures into its own
schema, limits, and diagnostics.
_Avoid_: Bytecodec extension with Lane semantics, duplicated byte cursor
