# Bytecode numeric primitives and undefined behavior

Lane `Int` uses signed two's-complement `I64 + Trivial`. V1 arithmetic instructions are `int_add`, `int_sub`, `int_mul`, `int_neg`, `int_div`, and `int_rem`. Addition, subtraction, multiplication, and negation overflow remain Lane Integer Undefined Behavior. Wasm lowering may therefore use wrapping `i64` arithmetic directly; negation may lower as zero minus the operand.

Signed division by zero and `MIN_INT / -1` may trap directly. Signed remainder by zero may also trap directly; `MIN_INT % -1` produces zero under the underlying Wasm operation. These are non-unwinding arithmetic traps rather than private fatal exceptions. Generated ownership cleanup does not run, and the embedding must discard the current interpreter or Wasm instance instead of resuming it or invoking it again.

Integer bitwise instructions are `int_and`, `int_or`, `int_xor`, and `int_not`. Shift instructions are `int_shl` and arithmetic `int_shr_s`. A negative shift count or a count greater than 63 is undefined Lane behavior. Wasm lowering may use ordinary `i64.shl` and `i64.shr_s`, which mask the count to its low six bits.

Integer comparison instructions are `int_eq`, `int_ne`, `int_lt`, `int_le`, `int_gt`, and `int_ge`; ordered comparisons are signed. Every comparison writes canonical Bool zero or one to an `I32 + Trivial` destination.

Bool v1 instructions are `bool_not`, `bool_eq`, and `bool_ne`. Valid Bool producers always produce zero or one. Source-level short-circuit conjunction and disjunction lower to bytecode CFG branches and do not become eager boolean arithmetic instructions.

Double v1 instructions are `double_add`, `double_sub`, `double_mul`, `double_div`, `double_neg`, and `double_eq`, `double_ne`, `double_lt`, `double_le`, `double_gt`, and `double_ge`. They operate on `F64 + Trivial` values and lower to Wasm binary64 operations. Division by zero follows IEEE-754 and does not trap. Comparisons follow Wasm NaN behavior: equality and ordered comparisons are false for NaN, inequality is true, and positive zero equals negative zero. Arithmetic may canonicalize or otherwise alter NaN payload bits.

Unary instructions encode destination then source. Binary instructions encode destination, left source, then right source. All destinations are logically dead before writing. Bytecode provides no implicit Int-to-Double or Double-to-Int conversion; ADR-0093 defines the only explicit numeric conversions and compiler-internal erasure bridges.

Consequences:

- Int primitives use signed `I64` operations.
- Overflow and invalid shifts remain undefined behavior.
- Wasm wrapping and masked-shift behavior are permitted for undefined cases.
- Invalid signed division may trap without ARC cleanup.
- Arithmetic traps invalidate the current instance.
- Integer comparisons produce canonical Bool values.
- Short-circuit Bool operations remain control flow.
- Double arithmetic follows Wasm IEEE-754 behavior.
- Constant NaN bits are preserved only until arithmetic operates on them.
- Numeric conversion is never implicit.
