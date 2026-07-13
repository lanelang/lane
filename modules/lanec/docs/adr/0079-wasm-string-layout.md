# Wasm String layout

Lane Strings are immutable ARC objects in canonical wasm32 linear memory. A String reference points to the common 8-byte ARC header. The payload word at object offset eight is `byte_length:u32`, and ASCII bytes begin immediately at object offset twelve. Total allocation size is `align_up(12 + byte_length, 8)`.

Strings store no capacity, cached hash, trailing NUL, or pointer to a parent String. Dynamic Strings begin with one owner. The image-global v1 constant pool deduplicates exact ASCII bytes, including empty String. Pooled Strings use the same physical layout with the immortal count and receive deterministic zero-based `ConstantId` values.

A synchronous runtime import receives an owned String argument but reads it through the borrowed pair `(string_ref + 12, byte_length)`. The view is zero-copy and expires before the import returns; the host cannot retain either the pointer or the view.

A physical Wasm runtime import returns String as one owned `string_ref:i32`, already referring to a newly initialized Lane String. RuntimeContext obtains that reference by making a restricted nested call to `"lane.runtime.string.new":(byte_length:i32) -> string_ref:i32`, then writes host-provided bytes through `"lane.memory"` after validating the ASCII invariant. The service is outside the Lane callable namespace and cannot invoke `"lane.entry"`, a closure, or an ordinary `FunctionId`. Non-ASCII bytes or service failure produce the private fatal exception. The resulting String has one owned reference.

`string_length` reads non-consumingly and widens the stored `u32` byte length to Lane `Int`. `string_eq` also reads non-consumingly and compares length plus exact ASCII bytes; pointer equality is only a fast path.

`string_concat` consumes both input owners, computes the combined length, allocates one target object, and uses Bulk Memory copies for the two byte ranges. When either input is empty, execution may move the other input directly because String identity is unobservable. `string_slice` consumes its input and normally allocates an independent String containing the selected byte range. A complete-range slice may move the input directly. No slice creates a view object that retains the parent String.

Slice start and length are signed Lane Int operands but must be nonnegative and define an in-bounds, non-overflowing byte range. Because v1 Strings are ASCII, byte and character indices coincide. Invalid ranges, concatenation length overflow, wasm32 addressability overflow, and allocation failure produce the private fatal exception and make the instance unusable.

Consequences:

- String length is a `u32` at object offset eight.
- String bytes begin at object offset twelve.
- Allocation size rounds up to eight-byte alignment.
- Dynamic, constant, and empty Strings share one physical layout.
- Constant and empty Strings are immortal image-owned objects.
- Exact ASCII literals are deduplicated under deterministic `ConstantId` values.
- Host input receives a temporary zero-copy pointer-length view.
- Host output is copied and ASCII-validated into a new owned String.
- Wasm host output physically returns one owned `string_ref:i32`.
- RuntimeContext uses the restricted String-allocation service and canonical memory.
- Nonempty concatenation performs one allocation and bulk copies.
- Substring and slice produce independent copies.
- Length and equality read without consuming String ownership.
- Concatenation and slicing consume their String operands.
- Empty concatenation and complete slicing may reuse an input owner.
- String indices are ASCII byte indices represented as Lane Int.
- Invalid ranges and length or allocation failures are fatal execution failures.
