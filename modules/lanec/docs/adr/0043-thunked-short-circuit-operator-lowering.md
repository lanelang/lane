# Thunked short-circuit operator lowering

Lane2 typed core lowers `&&` and `||` to calls of the resolved `op_and` or `op_or` operation with the right operand wrapped as a zero-argument thunk. These operators do not lower directly to `if` in typed core, because Contextual Resolution must supply the actual operation value; Basic library boolean operations may themselves be implemented with ordinary `if`.
