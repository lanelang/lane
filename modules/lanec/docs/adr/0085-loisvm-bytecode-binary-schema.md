# LoisVM bytecode binary schema

This ADR defines schema v1. ADR-0113 reserves schema v2 for the incompatible addition of Instance Globals and an optional Instance Initializer, and ADR-0114 defines their binary encoding; v1 remains unchanged.

Each LoisVM bytecode section begins with independent `bytecode_schema_version:u8`; v1 encodes `0x01`. Zero, `0xFF`, and every unsupported version are rejected. The enclosing linked-program section already identifies the payload kind and byte length, so the bytecode section does not repeat artifact magic. Bytecode schema changes do not require changing the artifact-container version, linked-program metadata schema, or Buslane codec version.

The schema version is followed by nonzero `entry_function_id:u32le`, then `function_count:u32le`. A zero function count is invalid. Function table position zero corresponds to `FunctionId = 1`, so valid identifiers are `1..function_count`. The selected entry must be a no-context bytecode body with zero witnesses, zero user parameters, and Unit result.

Bytecode uses fixed-width little-endian primitives. Identifiers, counts, array lengths, and byte lengths use `u32le`. Valid `FunctionId` and `LayoutId` values begin at one because zero is reserved. `BlockId`, `SlotId`, `ConstantId`, and `ObjectShapeId` are zero-based. Ordered-table position supplies each identifier, so entries do not repeat an explicit ID field.

Instructions and terminators have separate `u8` tag domains. A tag determines the exact operand sequence and operand widths. Individual instructions do not carry byte lengths, extension payloads, or alignment padding. An unknown instruction, terminator, representation, cleanup, function-entry, layout-recipe, object-shape, result, or layout-operand tag is a decoding error rather than a skipped extension.

The v1 instruction tags are `copy=0x01`, `move=0x02`, `retain_copy=0x03`, `release=0x04`, `const_int=0x05`, `const_double=0x06`, `const_bool=0x07`, `const_layout=0x08`, `const_function=0x09`, `const_string=0x0A`, `call_direct=0x0B`, `call_value=0x0C`, `make_data=0x0D`, `load_tag=0x0E`, `borrow_field=0x0F`, `consume_fields=0x10`, `make_env=0x11`, `borrow_capture=0x12`, `consume_captures=0x13`, `make_closure=0x14`, `string_length=0x15`, `string_concat=0x16`, `string_slice=0x17`, and `string_eq=0x18`.

Numeric and bridge instruction tags continue with `int_add=0x19`, `int_sub=0x1A`, `int_mul=0x1B`, `int_neg=0x1C`, `int_div=0x1D`, `int_rem=0x1E`, `int_and=0x1F`, `int_or=0x20`, `int_xor=0x21`, `int_not=0x22`, `int_shl=0x23`, `int_shr_s=0x24`, `int_eq=0x25`, `int_ne=0x26`, `int_lt=0x27`, `int_le=0x28`, `int_gt=0x29`, `int_ge=0x2A`, `bool_not=0x2B`, `bool_eq=0x2C`, `bool_ne=0x2D`, `double_add=0x2E`, `double_sub=0x2F`, `double_mul=0x30`, `double_div=0x31`, `double_neg=0x32`, `double_eq=0x33`, `double_ne=0x34`, `double_lt=0x35`, `double_le=0x36`, `double_gt=0x37`, `double_ge=0x38`, `int_to_double=0x39`, `double_to_int=0x3A`, `erase_i32=0x3B`, `unerase_i32=0x3C`, `erase_i64=0x3D`, `unerase_i64=0x3E`, `erase_f64=0x3F`, `unerase_f64=0x40`, `erase_unit=0x41`, `unerase_unit=0x42`, and `load_object_witness=0x43`.

The independent v1 terminator tags are `jump=0x01`, `branch_bool=0x02`, `switch_tag=0x03`, `return=0x04`, `tail_call_direct=0x05`, `tail_call_value=0x06`, and `unreachable=0x07`. The instruction count excludes the required final terminator. Normal calls are instructions; returns, tail calls, CFG transfers, and unreachable are terminators. V1 has no nop, generic operation-subtag instruction, opcode alias, or executable debug instruction.

Every `u8` tag namespace has explicit normative values independent of implementation enum ordinals. Namespaces reserve `0x00` and `0xFF` as invalid, assign known tags contiguously from `0x01`, and may reuse values across namespaces. Adding, removing, or renumbering a tag requires a bytecode schema-version change. V1 representation tags are I32 `0x01`, I64 `0x02`, and F64 `0x03`; cleanup tags are Trivial `0x01`, OwnedRef `0x02`, OwnedCallable `0x03`, and OwnedErased `0x04`; result tags are Unit `0x01`, I32 `0x02`, I64 `0x03`, and F64 `0x04`.

Each function-table entry begins with `function_entry_tag:u8`: BytecodeBody is `0x01`, and RuntimeImport is `0x02`. A BytecodeBody entry contains the existing length-delimited body and does not repeat FunctionId, context kind, arities, or result representation outside that body. A RuntimeImport entry contains `abi_major:u32le`, `user_arity:u32le`, `symbol_length:u32le`, and exact symbol bytes. It is implicitly no-context and witness-free. Its symbol is nonempty case-sensitive ASCII without NUL. Function entries have no common byte-length field.

After whole-program optimization and final body formation, the linker emits bytecode bodies first in final deterministic body-list order. It deduplicates runtime imports by `(symbol, abi_major, user_arity)` and appends them sorted by symbol bytes, ABI major, then user arity. FunctionIds are reproducible only for the same compiler version, exact inputs, options, and selected entry; build changes may renumber them. The runtime symbol registry remains the authority for parameter and result kinds; those lists are not serialized.

The function table is followed by `layout_count:u32le`. Layout table position zero corresponds to `LayoutId = 1`; zero remains invalid. A zero layout count is permitted. Each entry begins with `layout_recipe_tag:u8`: Unit `0x01`, Bool `0x02`, Int `0x03`, Double `0x04`, Callable `0x05`, String `0x06`, Data `0x07`, and Environment `0x08`. Primitive recipes carry no payload. Data and Environment append `ObjectShapeId:u32le`. Entries contain no representation, size, alignment, offset, sizer, or helper-index fields.

The linker deduplicates equal recipes. It emits used primitive recipes in Unit, Bool, Int, Double, Callable, String order, then Data recipes by ObjectShapeId, then Environment recipes by ObjectShapeId. A Data recipe must reference a Data shape and an Environment recipe an Environment shape. The later Object Shape table resolves those references.

Each function body begins with `body_length:u32le`, covering the complete payload after the length field, and its decoder must consume that slice completely. The payload order is slot table, function inputs, result descriptor, then block table. No entry `BlockId` is serialized because `BlockId = 0` is fixed as the entry.

The slot table begins with `slot_count:u32le`; zero is permitted. Table position defines zero-based `SlotId`. Each entry stores `representation_tag:u8` and `cleanup_tag:u8`; only `OwnedErased` appends `companion_slot_id:u32le`.

Function inputs encode `environment_slot_plus_one:u32le`, then a counted witness SlotId array, then a counted user-parameter SlotId array. Zero environment means absent; nonzero N means `SlotId = N - 1`. The result descriptor is one `result_tag:u8` in the closed domain Unit, I32, I64, or F64. Unit carries no SlotId.

The block table begins with nonzero `block_count:u32le`; table position defines zero-based `BlockId`. Each block stores a counted ordered parameter-slot list, a counted fixed-shape instruction array, then exactly one terminator. The entry block has zero parameters. Blocks do not carry separate byte lengths and never fall through.

Every optional SlotId uses `slot_plus_one:u32le`: zero is absent, and nonzero N denotes `SlotId = N - 1`. This form encodes function and direct-call environments, returning-call destinations, return sources, and projection witness destinations without a separate presence tag.

`call_direct` encodes target `FunctionId`, environment OptionalSlot, counted witness SlotId array, counted user-argument SlotId array, and destination OptionalSlot. `call_value` encodes callable `SlotId`, counted witness array, counted user-argument array, and destination OptionalSlot. A SlotId array is one `count:u32le` followed by exactly that many `SlotId:u32le` values; empty arrays are permitted. No `CallShapeId` is serialized.

The `return` terminator encodes only source OptionalSlot. Zero returns Unit; nonzero consumes one result owner into the caller. `tail_call_direct` encodes target, environment OptionalSlot, counted witness array, and counted user-argument array. `tail_call_value` encodes callable, counted witness array, and counted user-argument array. Tail terminators have no destination field.

An EdgeRecord encodes `target_block_id:u32le`, `argument_count:u32le`, then exactly that many ordered `argument_slot_id:u32le` values. Empty argument arrays are permitted. `jump` contains one EdgeRecord. `branch_bool` contains condition SlotId, true edge, and false edge. `switch_tag` contains tag SlotId, `case_count:u32le`, that many dense case edges, and one mandatory default edge. Zero cases are permitted. Dense edge ordinal N corresponds to unsigned local tag N; every tag bit pattern greater than or equal to the case count selects default. `unreachable` has no operands. No terminator uses implicit fallthrough.

Only the selected edge transfers values. Trivial sources are non-consuming reads; owned sources are consumed. One edge may repeat a Trivial source but may not repeat an owned source. Edge transfer is parallel and preserves overlapping source and target slots. Edge records contain no likelihood, inversion, source-case, representation, cleanup, or backend-label metadata.

The fixed-shape movement and ARC instructions are `copy(destination, source)`, `move(destination, source)`, `retain_copy(destination, source)`, and `release(slot)`. All operands are `u32le SlotId` values. Bytecode has no generic assignment or unary retain opcode.

Unless a field is explicitly an OptionalSlot, every SlotId operand is a direct zero-based `u32le`; direct SlotId zero is valid. Every producing instruction writes its logically dead destination first in the operand sequence.

Scalar constants are inline instruction operands. `const_int` encodes destination `SlotId` and `i64le`; `const_double` encodes destination and raw `u64le` binary64 bits; `const_bool` encodes destination and one byte restricted to zero or one, with every other byte rejected during decoding. `const_layout` encodes destination and nonzero `u32le LayoutId`. `const_function` encodes destination and nonzero `u32le FunctionId`. `const_string` encodes destination and zero-based `u32le ConstantId`. Unit has no constant instruction.

`make_closure` encodes destination `SlotId`, nonzero `u32le FunctionId`, and direct environment `SlotId`. Environment SlotId zero is valid; the referenced owned environment value must be nonzero. The instruction carries no layout, object-shape, call-shape, or type operand.

`string_length` encodes destination and source `SlotId`. `string_concat` encodes destination, left source, and right source. `string_slice` encodes destination, String source, start source, and length source. `string_eq` encodes destination, left source, and right source. These fixed operand shapes carry no index-unit, bounds, encoding, or ownership mode flags.

Unary numeric and boolean instructions encode destination `SlotId` then source `SlotId`. Binary arithmetic, bitwise, shift, equality, and ordered-comparison instructions encode destination, left source, then right source. Integer and Double comparisons write an `I32 + Trivial` canonical Bool destination. No numeric instruction carries an overflow mode or implicit conversion flag.

`int_to_double`, `double_to_int`, `erase_i32`, `unerase_i32`, `erase_i64`, `unerase_i64`, `erase_f64`, and `unerase_f64` each encode destination `SlotId` then source `SlotId`. `erase_unit` encodes only destination `SlotId`; `unerase_unit` encodes only source `SlotId`. Their distinct opcodes determine numeric-conversion versus representation-bridge semantics; no additional mode byte is present.

A `LayoutOperand` encodes `layout_operand_tag:u8` followed by `payload:u32le`. Immediate is `0x01` with a nonzero LayoutId payload; Witness is `0x02` with a layout-witness SlotId payload. Zero, `0xFF`, and unknown tags are invalid. A ProjectionResult encodes value destination SlotId followed by witness-destination OptionalSlot.

The zero-based Object Shape table follows the Layout Recipe table and begins with `object_shape_count:u32le`; zero is permitted. Each entry begins with `shape_tag:u8`: Data is `0x01`, and Environment is `0x02`. A Data entry stores local `constructor_tag:u32`, `stored_witness_count:u32le`, `member_count:u32le`, and ordered field schemas. An Environment entry omits the constructor tag and stores the same two counts followed by ordered capture schemas. Entries store no object alignment or computed byte offsets.

Each member schema stores `representation_tag:u8`, `cleanup_tag:u8`, and `witness_ordinal_plus_one:u32le`. Zero means no witness; nonzero N selects stored witness ordinal `N - 1`. Trivial permits I32, I64, or F64 with no witness. OwnedRef requires I32 and no witness. OwnedCallable requires I64 and no witness. OwnedErased requires I64 and an in-range witness ordinal.

Canonical layout starts after the common eight-byte header. Data stores its u32 constructor tag, then all u32 witnesses in ordinal order; Environment starts witnesses immediately after the header. Members follow in schema order with I32 size/alignment four and I64/F64 size/alignment eight. Total allocation size rounds up to eight bytes.

`make_data` encodes destination, direct zero-based Data `ObjectShapeId`, LayoutOperand, counted witness-slot array, and counted field-slot array. The constructor tag comes from the shape. `load_tag` encodes destination and object source. `load_object_witness` encodes destination SlotId, ObjectShapeId, object source SlotId, and witness ordinal. It non-consumingly copies one stored `LayoutId` into an `I32 + Trivial` destination and applies equally to Data and Environment shapes. It exposes representation and ARC metadata only, not an erased source type or a dynamic typecase facility. `borrow_field` encodes Data ObjectShapeId, object source, field index, and one ProjectionResult. `consume_fields` encodes Data ObjectShapeId, object source, selected-result count, then strictly increasing pairs of field index and ProjectionResult. Zero selected results are permitted.

The linker deduplicates exact canonical Object Shape encodings. Data shapes are sorted lexicographically by canonical encoded bytes before Environment shapes, which are sorted the same way. ObjectShapeId is the resulting zero-based table position.

`make_env` encodes destination, direct zero-based Environment `ObjectShapeId`, LayoutOperand, counted witness-slot array, and counted capture-slot array. The arrays follow shape order and match the shape's declared counts under the trusted-bytecode contract. `borrow_capture` encodes Environment ObjectShapeId, environment source, capture index, and one ProjectionResult. `consume_captures` encodes Environment ObjectShapeId, environment source, selected-result count, then strictly increasing pairs of capture index and ProjectionResult. Zero selected results are permitted.

The v1 constant pool begins with `u32le` entry count. Each zero-based entry is one `u32le` byte length followed by exact ASCII bytes. Entries carry no kind tag because v1 contains Strings only; adding another pool kind requires a bytecode schema-version change. After whole-program optimization, linker emission removes unreferenced strings, deduplicates exact bytes, sorts remaining entries by unsigned raw-byte lexicographic order, assigns ConstantIds from table position, and remaps `const_string` operands. The empty String is first when present.

The section is packed without address-alignment padding. Signed 64-bit integer constants are stored as their two's-complement `i64le` bits. `Double` constants store their raw IEEE-754 binary64 bits in little-endian order, preserving NaN payloads and signed zero at the serialization boundary.

Strict decoding checks primitive framing, known tags, declared lengths, ASCII symbols and String bytes, checked arithmetic, safe minimum-size preflight before count-driven allocation, and complete consumption. It does not prove control-flow targets, slot data flow, ownership, call arity, or other trusted bytecode invariants. Incompatible schema changes require a bytecode schema-version bump rather than an opcode escape mechanism or unknown-field skipping.

The schema defines no resource maxima below its `u32le` field capacities. Implementations may impose lower resource limits and report ResourceLimit without making the encoding malformed. Loading completes decode before import resolution, resolves all imports before execution-image construction or Wasm compilation, and publishes a reusable loaded executable image only after complete success. Any failure discards partial state.

Loading rejects zero function count, an out-of-range or incompatible selected entry, empty or invalid runtime symbols, unresolved imports, and ABI-major or arity mismatch. Failures distinguish UnsupportedSchema, MalformedEncoding, UnresolvedImport, AbiMismatch, ResourceLimit, and BackendCompileFailure. Malformed diagnostics carry section-relative byte offsets; import failures carry symbols. The executable bytecode retains only selected FunctionId, not the original exported symbol or source type used during link-time validation.

Consequences:

- LoisVM bytecode evolves independently from outer artifact framing.
- Bytecode sections contain a `u8` schema version and no duplicate magic.
- The v1 schema-version byte is `0x01`.
- Bytecode sections contain one selected executable FunctionId.
- Function tables use one-based FunctionId over zero-based entry position.
- Function entries are tagged BytecodeBody or RuntimeImport records.
- Function-entry tags are BytecodeBody `0x01` and RuntimeImport `0x02`.
- Layout entries are tagged backend-independent recipes.
- Layout-recipe tags are contiguous `0x01..0x09` in canonical recipe order; `Reference` uses `0x09` as a witness-only erased-reference recipe.
- LayoutId is one-based over zero-based recipe-table position.
- Layout recipes are deduplicated and deterministically ordered.
- Runtime imports carry major version, user arity, and nonempty ASCII symbol.
- Runtime imports are deduplicated and deterministically sorted after bytecode bodies.
- Body FunctionIds follow final deterministic post-optimization body order.
- FunctionIds are build-local rather than stable module or persistence identities.
- The explicit selected entry need not have FunctionId one.
- IDs, counts, and lengths use `u32le`.
- `FunctionId` and `LayoutId` are one-based; other current IDs are zero-based.
- Ordered tables omit redundant serialized ID fields.
- Instructions and terminators use separate fixed-shape `u8` tags.
- V1 instruction tags occupy `0x01..0x43`; terminator tags occupy `0x01..0x07`.
- Instruction counts exclude each block's required terminator.
- V1 has no nop, opcode alias, generic operation subtag, or debug instruction.
- Tag namespaces reserve `0x00` and `0xFF` and assign explicit contiguous values.
- Tag assignments are independent of implementation enum ordinals.
- Any accepted-tag change requires a bytecode schema-version bump.
- Individual instructions and blocks have no byte-length fields.
- Function bodies are byte-length-delimited and completely consumed.
- Function body payload order is slot table, inputs, result, then block table.
- Function inputs and result representation are explicit body metadata.
- Environment absence uses zero while nonzero values encode `SlotId + 1`.
- Result tags are Unit, I32, I64, and F64.
- Block zero is the fixed entry and is not serialized separately.
- Entry blocks have no block parameters.
- Every optional SlotId uses zero or `SlotId + 1` in one `u32le` field.
- SlotId arrays use a `u32le` count followed by exact SlotIds.
- Unit-returning calls carry no destination `SlotId`.
- Call operands contain explicit witness and user argument arrays.
- Return and tail-call terminators have fixed explicit operand layouts.
- Ordinary CFG terminators contain complete explicit edge records.
- Dense switches permit zero cases and always encode a default edge.
- Switch tags compare as unsigned `u32` against case count.
- Edge transfer is parallel and only the selected edge affects ownership.
- One edge may repeat Trivial but not owned source slots.
- Copy, move, retain-copy, and release have fixed slot-operand layouts.
- Scalar, layout, and function constants are inline instruction operands.
- Closure construction has fixed destination, function, and environment operands.
- String primitives have fixed slot-only operand layouts.
- V1 constant-pool entries are length-prefixed ASCII Strings only.
- Constant-pool entries are reachable, deduplicated, and unsigned-byte sorted.
- The empty String has ConstantId zero when present.
- Object shapes serialize tagged Data or Environment member schemas without byte offsets.
- Object-shape tags are Data `0x01` and Environment `0x02`.
- Data and environment construction and projection have fixed shape-aware operand layouts.
- LayoutOperand uses Immediate `0x01` or Witness `0x02` plus one `u32le` payload.
- Construction arrays remain explicitly counted for independent body framing.
- Consuming field and capture indices are strictly increasing and may be empty.
- `unreachable` is an operand-free trusted terminator.
- Bytecode contains no call-shape identifier table.
- Bytecode records contain no alignment padding.
- `i64` and `f64` constants preserve their raw little-endian bits.
- Unknown tags and trailing function bytes are decoding errors.
- Checked framing arithmetic and minimum-size preflight precede count-driven allocation.
- Resource caps are implementation policy rather than schema fields.
- Loading is atomic and publishes no partial execution instance.
- Runtime import resolution begins only after complete decoding.
