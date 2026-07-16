# LoisVM bytecode v2 global encoding

Status: Superseded by ADR-0116. The initializer, globals, and global instructions remain in the current format, but the version discriminator and legacy branch were removed.

LoisVM bytecode schema v2 encodes its image in this fixed order:

1. `bytecode_schema_version:u8 = 0x02`;
2. nonzero `entry_function_id:u32le`;
3. `initializer_function_id:u32le`, where zero means absent and a nonzero value is a direct FunctionId;
4. `function_count:u32le` and the function table;
5. `global_count:u32le` and the Instance Global table;
6. the existing layout, object-shape, and constant tables in their v1 order and encoding.

GlobalId is a zero-based dense `u32le` index supplied by Instance Global table position. Zero is valid and no GlobalId value is reserved. The table follows Executable Program initialization order rather than sorting by representation or cleanup category.

Each Instance Global record contains the existing `representation_tag:u8` and `cleanup_tag:u8`. `OwnedErased` additionally contains one direct zero-based `erased_companion_global_id:u32le`; other cleanup categories have no companion field. An erased companion is an `I32 + Trivial` global placed immediately before its owning `I64 + OwnedErased` global. It is synthetic storage for the immutable LayoutId and is not independently initialized by bytecode.

Schema v2 preserves every v1 instruction tag and appends two tags:

- `init_global = 0x44` encodes `global_id:u32le` followed by `source_slot_id:u32le`;
- `borrow_global = 0x45` encodes `destination_slot_id:u32le` followed by `global_id:u32le`.

`init_global` consumes its source slot into an uninitialized Instance Global. For `OwnedErased`, the instruction atomically copies the source slot's LayoutId companion into the global companion and transfers the erased payload into the owning global. Both global records become initialized as one operation. The instruction may execute in the Instance Initializer or one of its callees while the execution instance remains in Initialization Phase. Executing it outside that phase, targeting a companion directly, or initializing an already initialized target is an InternalRuntimeFailure under the trusted-image contract.

`borrow_global` reads an initialized global without transferring or retaining ownership. For `OwnedErased`, it also copies the immutable LayoutId into the destination slot's declared erased companion. Representation, cleanup, and companion compatibility follow the same trusted-bytecode assumptions as existing aggregate projections. Consuming or escaping uses require compiler-inserted retain-copy after the borrow.

Loading checks that a nonzero initializer FunctionId selects an existing bytecode body with no context, witnesses, user parameters, or result value. A nonempty Instance Global table requires an initializer. A zero-length table may still have an initializer because eager top-level computation can be required even when it retains no result. Returning normally from initialization without initializing every non-companion global is an InternalRuntimeFailure.

Schema v1 tag assignments and binary records remain unchanged. A v1 decoder rejects schema v2 as unsupported rather than interpreting the appended fields or opcodes.

## Consequences

- Schema v2 adds one optional initializer field and one Instance Global table.
- GlobalId is zero-based and dense.
- Global records reuse slot representation and cleanup tags.
- OwnedErased companion globals immediately precede their owners.
- Erased payload and LayoutId initialization and borrowing are atomic VM operations.
- V1 instruction tags remain stable; global instructions use `0x44` and `0x45`.
- Global initialization is legal throughout the dynamic initializer call tree, not only in its root body.
- Empty global tables may retain an initializer for eager computation.
