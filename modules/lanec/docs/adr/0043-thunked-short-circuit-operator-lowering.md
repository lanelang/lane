# Thunked short-circuit operator lowering

Lane2 typed core lowers `&&` and `||` to calls of the certified `Basic.Ops.op_and` or `Basic.Ops.op_or` identity with the right operand wrapped as a zero-argument thunk. These operators do not lower directly to `if` in typed core because their provider semantics live in Basic. Any contextual parameters declared by Basic are handled by the ordinary call judgment; Basic boolean operations may themselves be implemented with ordinary `if`.
