# RFC: Pure generic Array values

Status: Accepted for implementation on 2026-08-28

## Summary

Lane will add `Array : [Type] -> Type` as a globally available runtime primitive type constructor. An `Array[T]` is a fixed-length, homogeneous, pure value with constant-time length and indexed access. Updating an element returns another `Array[T]`; it never changes an existing observable value or alias.

The first implementation stores the Array object behind one ARC reference and stores its elements in contiguous erased `I64` slots. Each Array object records the runtime representation witness used for `T`, allowing the runtime to retain, release, copy, and destroy elements without runtime reflection or an `Any` representation. Elements are not individually boxed by Array. Values that are already references remain references in their erased slots, while scalar values occupy the erased bits directly.

The source interface uses five generic compiler intrinsics:

```lane
pub let array_empty : [T]() -> Array[T] = builtin("%array_empty")
pub let array_make : [T](I64, T) -> Array[T] = builtin("%array_make")
pub let array_length : [T](Array[T]) -> I64 = builtin("%array_length")
pub let array_get : [T](Array[T], I64) -> T = builtin("%array_get")
pub let array_set : [T](Array[T], I64, T) -> Array[T] = builtin("%array_set")
```

These builtins are ordinary first-class polymorphic values. The compiler extends its intrinsic signature model from monomorphic primitive signatures to closed polymorphic type schemes and lowers generic intrinsic calls through Lane's existing representation-erasure and layout-witness machinery. Physical Lowering and the Wasm target implement Array as internal instructions and helpers; Array does not extend the external host runtime-import ABI.

## Motivation

`Basic.Data.List.List[T]` is an appropriate persistent recursive sequence, but it cannot provide a flat generic runtime representation. A linked list requires one constructor object per element, uses linear-time indexing, and has poor locality for dense data. `Bytes` provides packed contiguous storage, but it is specialized to `Byte` and cannot represent arbitrary `T`.

Lane therefore needs a generic runtime collection with these properties:

- constant-time length and indexed access;
- one contiguous element region rather than one list node per element;
- ordinary pure value semantics;
- correct generic ownership for scalar, reference, callable, nominal, and nested Array elements;
- no runtime type reflection, `Any`, or source-visible mutation;
- the same behavior in the WebAssembly interpreter and JIT.

This representation cannot be implemented entirely in Basic. Ordinary Lane code cannot allocate a variable-size runtime object, erase and unerase arbitrary `T`, access the layout witness for `T`, perform descriptor-directed ARC, inspect reference-count uniqueness, or manipulate raw contiguous storage. Basic can own the safe public library interface, but the primitive storage and operations belong to the compiler and runtime.

## Goals

- Add a general fixed-length `Array[T]` value with pure semantics.
- Make `empty`, `length`, and indexed access constant time.
- Store the first-version element region as contiguous eight-byte erased slots.
- Avoid an additional heap allocation for each element.
- Reuse unique Array allocations for pure updates when ownership permits it.
- Preserve old aliases when an update receives a shared Array.
- Use `I64` consistently for source-level lengths, indices, and range operands.
- Extend compiler intrinsics through one general polymorphic signature mechanism rather than Array-specific typechecking rules.
- Reuse Lane's existing `LayoutId`, `OwnedErased`, erasure bridges, and generic-call ABI.
- Keep full source types, reflection, dynamic typechecking, and host ABI policy out of the runtime representation.

## First-version boundaries

The first version does not add Array literals, indexing syntax, update syntax, slices, concatenation, append, push, pop, capacity, resizing, builders, mutable references, shared mutation, parent-backed views, host ABI values, or element-layout specialization. These features can be designed independently without changing the core `Array[T]` value semantics.

The public type is named `Array[T]`, not `BoxedArray[T]`. The Array object itself is an ARC heap object, but the runtime does not allocate a separate box for every element. Naming the type after a particular representation would expose an implementation detail and would be misleading for immediate scalar elements.

`Bytes` remains the packed specialization for byte data. In the first generic implementation, `Array[Byte]` uses one eight-byte erased slot per element, while `Bytes` uses one byte per element.

## Language model

### Type constructor

`Array` is a globally available primitive type constructor of kind `[Type] -> Type`. It is resolved without an import, just like globally available primitive scalar types, and is not defined by a nominal declaration in Basic.

```lane
let integers : Array[I64] = ...
let names : Array[String] = ...
let nested : Array[Array[I32]] = ...
```

`Array[T]` is definitionally distinct from `List[T]`, `Bytes`, every nominal collection, and `Array[U]` when `T` and `U` are not definitionally equal. There is no implicit conversion between these types.

No parser grammar is required beyond the existing generic type-application syntax. The first version adds no Array expression syntax.

### Logical value

An `Array[T]` is a finite ordered sequence of `T` values with a nonnegative logical length. Its length never changes. The only primitive update operation replaces one existing element and preserves the length and every other element.

Array obeys pure value semantics. For any source value `xs`, evaluating an operation that produces `ys` cannot change the length or elements subsequently observed through `xs` or any alias of `xs`.

The runtime may reuse an allocation only when ownership proves that no observable alias shares it. Allocation reuse, reference counts, object addresses, and uniqueness tests are not observable in Lane.

### Empty arrays and uninhabited element types

Every element type has an empty Array value, including uninhabited types:

```lane
import Basic.Data.Void.{ Void }

let impossible_values : Array[Void] = array_empty[Void]()
```

This is well-formed because an empty Array contains no `Void` value. A generic collection must be able to produce an empty `Array[T]` without first producing a `T`; otherwise operations such as mapping an empty input to `Array[B]`, filtering away every element, or taking zero elements cannot be implemented uniformly.

`%array_make` cannot by itself define generic emptiness because its caller must evaluate and supply a `T` even when the length is zero. The dedicated `%array_empty` intrinsic is the smallest zero-element construction mechanism in the absence of Array literals or a builder. A future literal or builder could provide the same semantic capability, but it would not remove the requirement that empty construction need no element value.

## Closed builtin contract

A builtin remains an ordinary `builtin("%name")` expression whose actual type is synthesized from one compiler-owned closed type scheme. The annotated expected type must be able to consume that actual scheme through the existing directional type-compatibility rules, including the existing legal function-effect widening. Quantifier count and parameter kinds must agree after aligning bound-parameter names; the aligned quantified bodies are then checked directionally rather than by raw structural type equality. This RFC adds no alternate builtin declaration or invocation syntax.

| Builtin expression | Canonical compiler-owned type scheme |
| --- | --- |
| `builtin("%array_empty")` | `[T]() -> Array[T]` |
| `builtin("%array_make")` | `[T](I64, T) -> Array[T]` |
| `builtin("%array_length")` | `[T](Array[T]) -> I64` |
| `builtin("%array_get")` | `[T](Array[T], I64) -> T` |
| `builtin("%array_set")` | `[T](Array[T], I64, T) -> Array[T]` |

All type applications and calls use ordinary Lane syntax:

```lane
let empty_points = array_empty[Point]()
let zeros = array_make[I64](4, 0)
let first = array_get[I64](zeros, 0)
let changed = array_set[I64](zeros, 0, 42)
```

The operations have these semantics:

- `%array_empty[T]()` returns the unique logical empty sequence of `T` values.
- `%array_make[T](length, fill)` returns exactly `length` elements, each equal to `fill`.
- `%array_length[T](array)` returns the logical element count.
- `%array_get[T](array, index)` returns the element at zero-based `index`.
- `%array_set[T](array, index, value)` returns an Array of the same length with `value` at `index` and every other element equal to the corresponding element of `array`.

All five functions have an empty Lane effect row. Runtime allocation failure and failure after violating a primitive precondition do not become source-level algebraic effects.

### Preconditions

The primitive layer is partial:

| Operation | Value-domain precondition |
| --- | --- |
| `%array_empty` | none |
| `%array_make(length, _)` | `length >= 0` |
| `%array_length` | none |
| `%array_get(array, index)` | `0 <= index < array_length(array)` |
| `%array_set(array, index, _)` | `0 <= index < array_length(array)` |

Violating a value-domain precondition is undefined Lane behavior. The interpreter and compiled tier retain defensive checks and may panic or trap, but source programs cannot rely on a particular failure value, diagnostic, or evaluation order after the violation.

A nonnegative length that cannot be represented by the portable object layout, whose allocation-size calculation overflows, or whose allocation cannot be satisfied produces fatal runtime failure when the operation is actually executed. No failure publishes a partially initialized Array owner.

Lane evaluates ordinary function arguments strictly. `%array_make[T](0, fill)` therefore still evaluates and transfers the `fill` argument even though the resulting Array contains no elements. The runtime releases that transferred value rather than leaking it. Callers that need `fill` later receive the usual compiler-inserted retain before the call.

## Length and index type

The public length and index type is `I64`, consistently across `make`, `length`, `get`, `set`, and future range-oriented Array operations. This matches the existing `Bytes` and String collection interfaces and keeps the source interface independent of the backend address width.

The portable first-version Array object stores its physical length as `u32`. `%array_length` zero-extends that field to nonnegative `I64`. Indexed operations first reject negative `I64` values, compare the nonnegative value against the zero-extended stored length, and only then narrow it for physical addressing.

Returning `I32` would expose a signed maximum of `2^31 - 1`, despite the object representation using an unsigned field, and would force conversions between Array lengths and existing `I64` collection operations. Returning `I64` does not promise that the runtime can allocate `I64::MAX` elements; allocation remains constrained by the portable `u32` field, address space, element width, and resource limits.

## Standard-library interface

The compiler supplies the primitive type constructor and exact intrinsic identities. Basic supplies source bindings, checked operations, collection algorithms, and capability implementations.

`Basic.Builtins` owns the raw intrinsic bindings:

```lane
pub let array_empty : [T]() -> Array[T] = builtin("%array_empty")

// UB if length < 0.
pub let array_make : [T](I64, T) -> Array[T] = builtin("%array_make")

pub let array_length : [T](Array[T]) -> I64 = builtin("%array_length")

// UB unless 0 <= index < array_length(array).
pub let array_get : [T](Array[T], I64) -> T = builtin("%array_get")

// UB unless 0 <= index < array_length(array).
pub let array_set : [T](Array[T], I64, T) -> Array[T] = builtin("%array_set")
```

`Basic.Data.Array` owns the ordinary safe interface. Its checked `make`, `get`, and `set` functions validate the primitive preconditions and report invalid lengths or indices through the existing `OutOfBound` effect. It may also provide algorithms such as mapping, folding, searching, conversion to and from `List`, equality, hashing, and display without additional compiler knowledge.

| Function | Type |
| --- | --- |
| `empty` | `[T]() -> Array[T]` |
| `make` | `[T](I64, T) -> Array[T] ! OutOfBound` |
| `length` | `[T](Array[T]) -> I64` |
| `get` | `[T](Array[T], I64) -> T ! OutOfBound` |
| `set` | `[T](Array[T], I64, T) -> Array[T] ! OutOfBound` |

The compiler does not recognize `Basic.Data.Array`, `OutOfBound`, `Option`, `Equal`, `Hash`, or any other library declaration by name. The raw builtins remain sufficient to replace or omit Basic.

## Runtime representation

### Natural Array value representation

An `Array[T]` value uses `I32 + OwnedRef`: one ARC-owned reference to a Runtime Array Object. Passing, returning, capturing, or storing an Array transfers or retains this reference through the existing compiler-directed ARC rules. It does not copy the element region merely because the value crosses a function or data boundary.

The natural representation of `Array[T]` is the same for every `T`. The element type affects element storage and destruction through a hidden layout witness, not the width of the Array reference itself.

### Runtime Array Object

The portable first-version payload is:

```text
+0   ref_count:u32
+4   object_layout_id:u32
+8   length:u32
+12  element_layout_id:u32
+16  elements:i64[length]
```

The first eight bytes are Lane's common ARC object header. `object_layout_id` selects the common Array Layout Recipe. `element_layout_id` is the runtime representation witness used for values of `T` and remains valid for the lifetime of the loaded image; it is not a unique runtime identity for the source type `T`. The element region starts at an eight-byte-aligned offset and contains exactly `length` erased slots. The total portable object size is `16 + 8 * length`, subject to checked arithmetic and runtime allocation limits.

The object has no capacity, spare initialized slots, parent reference, slice metadata, element tags, per-element type descriptors, or source type name. Every object is fully initialized before publication.

An empty Array still has a valid `element_layout_id`, so `Array[Void]` and every other empty instantiation follow the same object invariant. This ID is a runtime representation witness, not a source type identity: definitionally distinct element types may legitimately share it. An implementation may share immortal empty objects when it can preserve this invariant, for example by interning one empty object per element layout. Sharing is not required or observable.

### Erased element representation

Every first-version element occupies one `I64` payload. The associated `LayoutId` supplies retain, release, and destruction behavior.

| Source element shape | Erased payload |
| --- | --- |
| `I64` | unchanged 64-bit value |
| `F64` | exact reinterpreted 64-bit pattern |
| `I32`, `F32`, `Bool`, `Char`, `Byte` | value bits in the low 32 bits |
| `Unit` | canonical zero payload |
| callable | packed callable bits, including its environment reference |
| `String`, `Bytes`, `Array[U]`, nominal data | reference bits in the low 32 bits |

Array introduces no additional element box. A nominal value remains a reference because that is already its ordinary Lane representation; Array does not allocate another wrapper around it.

The first version deliberately uses the same eight-byte slot for every element, including `Unit` and `Byte`. Layout-specialized arrays may be considered later, but they must preserve the source type and value semantics. Packed byte data continues to use `Bytes`.

### Array Layout Recipe

The Physical Program adds a portable `Array` Layout Recipe. It is the object-header layout of a Runtime Array Object: it describes an owned variable-size reference whose size is calculated from the stored `length` and whose destructor reads the stored `element_layout_id` before releasing the element slots.

The same Array Layout Recipe appears in the object header for every `Array[T]`; Lane does not dynamically construct one new descriptor for each instantiation. The Runtime Array Object stores the separate element witness required for its contents. This preserves the existing rule that layout descriptors are static image metadata rather than dynamically allocated runtime type objects.

When an `Array[T]` itself crosses an erased generic boundary, its erased payload contains the Array reference and uses the existing witness-only `Reference` Layout Recipe. Generic retain and release follow the concrete object's header LayoutId, just as they do for nominal reference values. The `Array` Layout Recipe belongs in Array object headers and must not become a second erased-value witness identity. When an element crosses an Array operation, the stored element `LayoutId` governs the erased payload.

## Ownership and pure updates

The intrinsic ownership contracts are:

| Operation | Array input | Element input | Result ownership |
| --- | --- | --- | --- |
| `ArrayEmpty` | none | none | creates one Array owner |
| `ArrayMake` | none | consumes one erased element owner | creates one Array owner |
| `ArrayLength` | borrows | none | trivial `I64` |
| `ArrayGet` | borrows | none | creates one erased element owner |
| `ArraySet` | consumes one Array owner | consumes one erased element owner | produces one Array owner |

Trivial element layouts turn retain and release operations into no-ops, but the ownership contract remains uniform.

### Empty

`ArrayEmpty` creates or returns an empty Array object carrying the supplied element layout witness. An immortal cached object may be returned because Array identity is not observable.

### Make

`ArrayMake` validates and preflights the complete allocation before publishing an owner. For positive length, it moves the consumed `fill` owner into one slot and establishes the remaining element owners through descriptor-directed retains. For zero length, it releases the consumed `fill` owner. A failure before completion does not return a partial Array.

### Get

`ArrayGet` borrows the Array owner. It copies the selected erased bits and uses the stored element layout to establish a new owner for the result. For a trivial element this is a bit copy; for an owned reference or callable it performs the required retain. The returned `T` therefore remains valid independently of the Array's later lifetime.

### Set

`ArraySet` consumes one Array owner and the new erased element owner.

If the Array owner is unique, the runtime releases the old element at the selected index, moves the new element into that slot, and returns the same Array allocation.

If the Array is shared or immortal, the runtime allocates a new exact-size object, retains each copied element except the element being replaced, moves the new element into the selected slot, and releases the consumed source Array owner after the new object is fully initialized. Other owners continue to observe the original object unchanged.

If source code uses the old Array after the call, ownership lowering establishes another owner before invoking `ArraySet`. The runtime consequently observes a shared object and takes the copy path. The source-level result is therefore independent of whether the implementation reused or copied storage.

```lane
let original = array_make[I64](2, 0)
let changed = array_set[I64](original, 0, 42)
array_get[I64](original, 0) // 0
array_get[I64](changed, 0)  // 42
```

## Generic intrinsic model

### Source type schemes

The current compiler intrinsic registry can describe only monomorphic primitive values and functions. Array requires a closed type-scheme representation that can express a bounded set of compiler-owned constructors and bound type parameters.

One sufficient internal model is:

```text
IntrinsicTypeTemplate =
  Primitive(primitive)
  Parameter(index)
  Apply(IntrinsicTypeConstructor, Array[IntrinsicTypeTemplate])

IntrinsicTypeConstructor =
  Array

IntrinsicSignature =
  Value(type_parameters:Array[Kind], value)
  Function(type_parameters:Array[Kind], parameters, result)
```

The Array signatures use one `Type`-kind parameter and the compiler-owned `Array` constructor. Kinds are part of the contract rather than being inferred from parameter position. Existing monomorphic intrinsics are the zero-parameter subset of the same model. This template is an intrinsic contract representation, not a second general-purpose source type system.

Typechecking converts the template into the compiler's ordinary `Forall` and type-application objects. It then applies the same directional compatibility check used by existing builtin expressions; it does not introduce raw type equality, overload search, inference from the builtin name, or a per-Array exception in expected-type checking.

### Direct generic calls

A direct call such as:

```lane
array_get[I64](array, index)
```

is lowered through the same substitution and representation adaptation used for an ordinary generic function. The compiler supplies the layout witness for the type argument, erases concrete element arguments to `I64 + OwnedErased`, invokes the Array operation, and unerases an element result to its natural representation.

Conceptually, the source operations have these low-level shapes:

```text
array_empty(element_layout:i32) -> array_ref:i32
array_make(length:i64, fill:(layout:i32, payload:i64)) -> array_ref:i32
array_length(array_ref:i32) -> i64
array_get(result_layout:i32, array_ref:i32, index:i64) -> payload:i64
array_set(array_ref:i32, index:i64, value:(layout:i32, payload:i64)) -> array_ref:i32
```

The actual Physical Program uses erased-slot companion metadata and result witness destinations rather than publishing this conceptual ABI as a host-call contract. Each operation has one authoritative runtime source for the element layout:

- `%array_empty` uses its explicit element Layout Operand because it has neither an Array object nor an element value;
- `%array_make` obtains the layout from the consumed fill slot's erased companion and stores it in the new object;
- `%array_get` obtains the authoritative layout from the Array object, requires the already initialized result companion to contain the same LayoutId, and uses the object-stored layout to retain the selected payload before publishing the result owner;
- `%array_set` obtains the authoritative layout from the Array object and requires the consumed value's erased companion to contain the same LayoutId;
- `%array_length` has no element-layout input or result.

No operation reconstructs a runtime layout from a substituted source type. A malformed Physical Program mismatch between an object-stored layout and an erased companion is a compiler defect, not another layout-selection path.

### First-class generic builtin values

A builtin expression is an ordinary value. The implementation must therefore support exported, stored, and indirectly called polymorphic intrinsic values rather than recognizing only direct call syntax.

When an Array intrinsic must be materialized as a callable, the compiler generates an ordinary physical wrapper whose inputs contain the required hidden layout witnesses and whose element parameters or result use erased slots. An in-scope `T` witness initializes erased argument and result companions through the existing generic-call ABI; it is an expected-layout contract, not a second layout-selection source. Array operations use object-stored or value-companion layouts as specified above and fail on disagreement. The wrapper executes the same Array instruction used by direct lowering. Existing generic direct-call and generic value-call adaptation remains authoritative.

The compiler must consequently support type application of intrinsic values and remove the current restriction that intrinsic wrappers have no type parameters. A direct-call-only `TypeApplied(Intrinsic)` special case would violate the ordinary value semantics of `builtin("%array_get")` and is not sufficient.

### Runtime meaning of genericity

The runtime never receives a Lane source type object. It receives only fixed-width values and the minimal `LayoutId` needed to manage erased ownership. The witness contains no type name, generic syntax, field metadata, constructor metadata, type equality operation, or dynamic cast facility.

Generic Array operations therefore reuse Lane's existing representation erasure; they do not introduce `Any`, runtime reflection, per-type method tables, or whole-program monomorphization. Optional later specialization may optimize concrete instantiations without changing the source contract.

## Compiler changes

### Semantic types and kinds

The compiler adds a canonical globally available Array type constructor of kind `[Type] -> Type`. Its semantic identity is one compiler-owned constructor tag, conceptually `BuiltinTypeConstructor::Array`, carried through every semantic layer. It is neither a reserved nominal symbol nor a zero-arity `PrimitiveType`. Resolution, kind checking, type equality, substitution, normalization, display, free-parameter analysis, and type application must preserve `Array[T]` without treating it as a nominal declaration or a scalar primitive.

The type representation must distinguish a runtime primitive type constructor from zero-arity primitive types. Adding one ad hoc `ArrayOf` case only in the typechecker is insufficient because the identity must survive every compiler-owned semantic layer.

### Interfaces and artifacts

Module interfaces and module objects encode `Array[T]` in exported types and encode Array intrinsic bindings as ordinary `Forall` values. Semantic fingerprints, binary artifact codecs, inspection output, linker remapping, and interface-closure traversal must preserve the constructor and its type argument.

This representation advances the Buslane codec to version 9, the module
interface schema to version 15, and the module object schema to version 26.
Current-only decoders reject versions 8, 14, and 25 respectively.

Array adds no provider module identity. Importing or omitting Basic does not change the meaning or identity of `Array[T]`.

### Checked core, Buslane, and Runtime ANF

Checked expressions represent Array intrinsics with their complete polymorphic
type. Buslane preserves the compiler-owned Array constructor as source-semantic
type structure. Runtime ANF projects an applied `Array[T]` to one explicit
`Array(element: RuntimeArgument)` representation fact carrying the element
layout evidence needed by intrinsic application. Runtime ANF does not retain
the source constructor syntax or make Array a nominal declaration.

For physical lowering, `Array[T]` has natural representation `I32 + OwnedRef`. A value that is exactly a representation-polymorphic parameter continues to use `I64 + OwnedErased` with a companion layout witness. Existing erasure bridges adapt between these forms.

Construction, projection, closure capture, globals, recursive functions, contextual values, and ordinary calls must handle `Array[T]` through their existing generic and owned-reference rules. None of these layers should contain collection-specific behavior beyond representation and intrinsic lowering.

### Intrinsic contract and checking

The ABI package extends `IntrinsicSignature` from a list of monomorphic `IntrinsicValueKind` values to the closed polymorphic template described above. It adds the five stable intrinsic identities and names. The typechecker synthesizes their `Forall` types and continues to diagnose an incompatible annotation at the builtin expression through the existing directional compatibility seam.

The external `RuntimeValueKind` and Lane extern-binding rules remain unchanged. Array is not added to the host ABI merely because compiler intrinsics can mention it.

### Runtime ANF and call lowering

Runtime ANF retains evidence application on intrinsic atoms until Physical
Lowering can select the concrete or generic representation adaptation. The
generic-call projection is shared with ordinary callables: Array builtins do
not introduce a second type-application representation. Physical call lowering
gains the intrinsic counterpart of its existing generic direct-call path:

- substitute source type parameters with explicit type arguments;
- materialize every required `LayoutId` witness;
- erase element arguments according to the formal parameter type;
- emit the Array VMCFG operation;
- unerase an element result according to the actual result type.

Materializing a polymorphic intrinsic produces a generic wrapper with witness
inputs. Wrapper planning, reachability, complete-runtime-ABI deduplication,
callable adaptation, and function-table assignment treat it as an ordinary
compiler-generated function body.

### VMCFG

VMCFG adds five typed instructions. A proposed contract is:

| Instruction | Destination | Inputs |
| --- | --- | --- |
| `ArrayEmpty` | `I32 + OwnedRef` | element `LayoutOperand` |
| `ArrayMake` | `I32 + OwnedRef` | `I64` length, consumed `I64 + OwnedErased` fill and its companion |
| `ArrayLength` | `I64 + Trivial` | borrowed `I32 + OwnedRef` Array |
| `ArrayGet` | owned `I64 + OwnedErased` payload with an already initialized companion | borrowed Array, `I64` index |
| `ArraySet` | `I32 + OwnedRef` | consumed Array, `I64` index, consumed `I64 + OwnedErased` value and its companion |

Only `ArrayEmpty` needs an element Layout Operand; it is immediate for a statically known element layout and witness-based inside generic code. `ArrayMake` stores the fill companion. `ArrayGet` uses the object-stored layout and requires the preinitialized result companion to agree before establishing its payload owner. `ArraySet` likewise uses the object-stored layout and requires the value companion to agree. Physical Program validation enforces the required companions, and both Wasm engine modes must fail safely if a compiler defect supplies an invalid LayoutId, a non-Array object, or a mismatched companion.

VMCFG use analysis, ownership, simplification, cloning, pretty printing, finalization, verification, and dead-code handling must model the instruction contracts directly. Ownership must not be reconstructed later from an intrinsic name.

### Optimization

Intrinsic calls remain pure empty-effect expressions. Ordinary dead-code elimination may remove an unused Array computation, including an allocation or a call whose precondition would otherwise fail. This follows Lane's existing empty-effect optimization rule.

The first implementation does not require monomorphization or element-width specialization. Later optimizations may inline wrappers, remove redundant erase/unerase bridges, constant-fold `length`, share empty arrays, eliminate redundant bounds checks, or specialize concrete element layouts without changing observable behavior.

## Physical Program and WebAssembly changes

### Physical Program model

The Physical Program adds the `Array` Layout Recipe and five fixed-shape instructions corresponding to the VMCFG operations. Their operands encode destinations and source slots explicitly; only `ArrayEmpty` additionally encodes a Layout Operand. These compiler-private forms are not persisted and do not change an artifact schema.

The physical instruction contract contains runtime representation and ownership facts but no source type. An Array source or result is `I32 + OwnedRef`; an element source or result is `I64 + OwnedErased` with its required companion; `ArrayEmpty` uses the existing immediate-or-witness Layout Operand form.

Pretty rendering, slot validation, companion validation, instruction use sets, and Physical Program documentation must cover every new form.

### WebAssembly heap

The Wasm target adds a Runtime Array Object payload containing a portable nonnegative length, an element `LayoutId`, and contiguous erased `I64` values. It implements descriptor-directed retain and release through the same layout table used for other erased generic values.

Array destruction iterates over all elements, releases each erased owner with the stored element layout, and then frees the object shell. Destruction of trivial elements performs no ownership work beyond the loop; an implementation may provide specialized no-op or bulk paths internally.

The Wasm interpreter and JIT implement the same uniqueness and copy-on-write rules. White-box tests may observe reuse to validate the optimization, but Lane tests must assert only pure value behavior.

### Runtime imports

Array operations are not `RuntimeImport` entries. Runtime imports remain witness-free host bindings over their existing closed direct-value domain. The Wasm compiler lowers Physical Program operations to generated code or module-internal helpers.

## Wasm implementation

The Wasm tier materializes one static Array layout descriptor. Its retain and release helpers operate on the Array reference; its size helper reads `length`; its destroy helper reads `element_layout_id` and releases the erased element region before freeing the object.

The compiler or internal helpers implement:

- checked `16 + 8 * length` allocation arithmetic;
- conversion of nonnegative source `I64` length to the stored `u32` length;
- zero-extension of stored length to source `I64`;
- signed-negative and unsigned upper-bound index checks before address calculation;
- descriptor-directed retain and release for erased elements;
- unique-owner replacement and shared-owner copy-on-write;
- complete initialization before the result reference becomes visible.

These helpers are internal to the generated module and may use the static layout table and allocator directly. They are not imported host functions and are not visible through the Lane extern interface.

For a shared update, allocation and size preflight occur before publishing the destination. The copy loop retains every preserved owned element, skips the replaced old element, and moves the new owner into its destination. For a unique update, the old element is released before the new owner replaces it. All paths consume exactly the owners declared by the instruction contract.

## Complexity and performance

| Operation | Time | Additional allocation |
| --- | ---: | ---: |
| `empty` | `O(1)` | zero when cached, otherwise one fixed-size object |
| `length` | `O(1)` | none |
| `make(n, value)` | `O(n)` | one exact-size object |
| `get` | `O(1)` | none for Array storage; element retain may update ARC |
| `set` on unique owner | `O(1)` | none |
| `set` on shared owner | `O(n)` | one exact-size object |

Passing an Array is constant size and normally transfers or retains one reference. The element region uses `16 + 8 * n` object bytes before allocator-private metadata. There is no per-element Array allocation.

Generic operations may pass one `LayoutId`, use erased element slots, and perform indirect descriptor-selected ARC for owned elements. Monomorphic scalar Array operations therefore have slightly more representation overhead than a fully specialized unboxed array, but they avoid whole-program code duplication and support separately compiled generic functions. Redundant erasure operations are compiler-internal and may be optimized later.

The collection roles are intentionally distinct:

| Type | Representation | Indexed access | Update |
| --- | --- | ---: | --- |
| `List[T]` | persistent recursive nodes | `O(n)` | structural reconstruction |
| `Array[T]` | contiguous erased generic slots | `O(1)` | pure COW replacement |
| `Bytes` | contiguous packed bytes | `O(1)` | pure COW replacement |

## Validation plan

### Type and intrinsic contract

- `Array` resolves without imports and has kind `[Type] -> Type`.
- Partially or incorrectly applied Array types receive ordinary kind and arity diagnostics.
- All five builtin names synthesize their documented canonical polymorphic type schemes.
- Alpha-renamed annotations and annotations using existing legal function-effect widening are accepted through ordinary directional compatibility.
- Incompatible quantifier counts, parameter kinds, quantified bodies, parameter types, or result types receive ordinary signature mismatch diagnostics.
- Existing monomorphic intrinsics continue to use the zero-parameter subset of the same signature model.
- The external host ABI does not acquire Array or erased generic values.

### Generic callable behavior

- Every Array builtin works through direct type application.
- Exporting and importing an Array builtin preserves its `Forall` type.
- Materializing an Array builtin as a callable generates a witness-aware wrapper.
- Indirect generic calls produce the same result as direct intrinsic calls.
- Concrete calls cover erase and unerase bridges for `I64`, `I32`, `F64`, `F32`, `Unit`, references, callables, nominal values, and nested Arrays.

### Array semantics

- Empty arrays work for ordinary, generic, and uninhabited element types, including `Array[Void]`.
- `make` produces the requested length and equal elements for zero and nonzero lengths.
- `length` returns nonnegative `I64` values obtained from the stored unsigned length.
- `get` covers the first, middle, and last valid positions.
- `set` covers the first, middle, and last valid positions and preserves every other element.
- Keeping an alias before `set` proves that the original value remains unchanged.
- Dropping the old value permits but does not semantically require unique-owner reuse.
- Repeated `get` results remain valid after the source Array is released.

### Ownership

- `Array[String]`, `Array[Bytes]`, `Array[Array[I64]]`, nominal values, and captured callables retain and release every element exactly once per owner.
- `make(0, owned_value)` releases the consumed fill owner.
- Unique `set` releases the replaced old element and moves the new owner.
- Shared `set` retains preserved elements, does not retain the replaced old element into the new object, and leaves aliases unchanged.
- Array destruction releases every owned element before freeing the shell.
- Fatal allocation paths do not publish a partial owner.

### Bounds and resource failure

- Negative `make` lengths are defensively rejected.
- Negative and past-the-end indices are defensively rejected by `get` and `set`.
- Allocation-size multiplication and addition overflow are rejected before allocation.
- Stored `u32` lengths round-trip to nonnegative source `I64` lengths.
- Basic wrappers report invalid value-domain operands through `OutOfBound` before invoking a primitive with violated preconditions.

### Serialization and execution

- Interfaces, module objects, semantic fingerprints, and inspection output preserve `Array[T]` and polymorphic intrinsic types; linked executables are raw WebAssembly modules.
- Physical validation and WebAssembly emission tests cover the Array Layout Recipe and instructions; the compiler-private Physical Program has no codec.
- Compiler-generated slots have the documented representation, cleanup, ownership, and companion metadata.
- Wasm interpreter and JIT execution agree for every valid semantic case.
- A malformed Physical Program with a zero or out-of-range element LayoutId, a non-Array object, a missing or uninitialized result companion, or a value/result companion that disagrees with the object-stored layout is rejected as a compiler defect rather than becoming source-level reflection, a cast, or another layout-selection path.

### Tooling

- Hover, completion, inlay presentation, and semantic indexing render `Array[T]` as a primitive generic type constructor.
- Formatting is unchanged because the RFC adds no source grammar.
- Examples demonstrate empty, make, get, pure set, alias preservation, generic functions, and owned elements.

## Implementation sequence

1. Add the semantic Array type constructor and closed polymorphic intrinsic
   signature templates, with typechecker and artifact round-trip tests.
2. Project Array and polymorphic intrinsic applications into verified Runtime
   ANF without retaining source type syntax or introducing an Array-only generic
   call path.
3. Add VMCFG operations, ownership/use contracts, the Array Layout Recipe,
   Physical Program instructions, first-class intrinsic wrapper lowering,
   rendering, and verification.
4. Implement Runtime Array Objects, descriptor-directed element ownership,
   bounds checks, destruction, and copy-on-write in the sole Wasm target.
5. Verify the same emitted Wasm through Wasmoon interpreter and JIT modes.
6. Add `Basic.Builtins` bindings, `Basic.Data.Array` checked wrappers and initial
   algorithms, tooling presentation, examples, and complete source-to-Wasm
   tests.

Each step must preserve the ordinary generic function model. No intermediate implementation should route element values through `Any`, expose raw layout witnesses to Lane code, or support only direct intrinsic calls.

## Acceptance criteria

The feature is complete when:

1. `Array : [Type] -> Type` is globally available and preserved across the complete compiler and artifact pipeline;
2. the five builtin expressions synthesize the documented canonical polymorphic schemes, participate in existing directional compatibility, and have ordinary first-class value behavior;
3. every Array object uses one ARC reference, one valid object-owned element layout witness, and contiguous eight-byte erased element slots without Array-added per-element boxes or a second runtime layout owner;
4. empty arrays work uniformly for every element type, including `Void`;
5. all public lengths and indices use `I64` while the runtime safely stores and addresses portable `u32` lengths;
6. `get` establishes an independently owned result and destruction releases all owned elements correctly;
7. `set` preserves pure alias semantics and performs unique-owner reuse or shared-owner copying according to ARC state;
8. generic intrinsics use ordinary layout witnesses and representation erasure without runtime reflection, `Any`, or external generic runtime imports;
9. Wasm interpreter and JIT results agree for valid calls, and defensive failure paths publish no partial owner;
10. Basic supplies checked policy without becoming a compiler-recognized provider of the primitive type.

## Deferred work

Future RFCs may independently add Array literals, indexing or update syntax, copied slices, immutable shared views, concatenation, resizing, capacity-bearing builders, layout-specialized arrays, packed scalar arrays, host ABI copying or borrowing, allocation limits, or concrete-type specialization. A tree-backed persistent vector implemented in Basic is also possible, but it is a different data structure with different layout and performance characteristics.

Deferred features must preserve pure value semantics and must not make Array object identity, uniqueness, layout witnesses, or runtime source types observable.
