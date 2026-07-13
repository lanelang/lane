# Wasm ARC object header

Every Lane object reference in the Wasm tier is a nonzero wasm32 offset aligned to eight bytes and points to the start of a common 8-byte header. The word at offset zero is `ref_count:u32`, the word at offset four is `LayoutId:u32`, and layout-specific payload begins at offset eight. Pointing references at the header makes generic retain, release, and layout lookup independent of payload shape.

The common header contains no flags, allocation byte size, constructor tag, payload length, or allocator metadata. Fixed allocation size comes from the image layout table. Variable-size objects, including String, store their length according to their layout and use a layout-specific size rule. Allocator size classes, boundary tags, free-list links, or other metadata remain in a private allocation prefix or side structure and are not part of the Lane object ABI.

After destruction, the allocator may overwrite dead payload bytes with free-list metadata. Reallocation does not imply zeroed payload; object initialization must write every observable field before publication.

Nominal data stores its constructor tag as the first payload word after the common header. The tag is dense only within the owning nominal data type. `LayoutId` selects concrete field offsets and destruction behavior but is not used as constructor identity. Fieldless constructors that need no stored generic witness may use immortal image-owned singleton objects.

A new dynamic allocation begins with one strong owner. Retain increments the count before establishing an additional owner. Release decrements it; transition to zero invokes the layout destructor, which releases owned fields, before the allocator reclaims the block.

Descriptor-driven release obtains total allocation size from the fixed size field or variable sizer, invokes the `(object_ref:i32) -> ()` destroy helper, and then returns the block to the allocator. Destroy helpers do not free their own object.

Image-owned static objects use `0xFFFF_FFFF` as an immortal count sentinel. Generic retain and release recognize that value and perform no count update. A dynamic object may use counts only through `0xFFFF_FFFE`; retaining at that limit is a fatal internal execution failure. Counts never saturate into the immortal value and never wrap around.

Linear-memory offset zero remains reserved for null or no-environment representation and is never returned by the allocator. Eight-byte alignment keeps payload `i64` and `f64` fields naturally aligned after the 8-byte header.

Consequences:

- Every Lane reference points to the common header rather than payload.
- The common header is exactly two `u32` words.
- Payload begins at byte offset eight and is naturally eight-byte aligned.
- New dynamic objects have one strong owner.
- Static image objects use the immortal maximum-`u32` count.
- Dynamic overflow into the sentinel is a fatal internal failure.
- Release to zero destroys owned fields before allocator free.
- Object size and allocator metadata are absent from the common header.
- Layout-specific rules handle fixed and variable allocation sizes.
