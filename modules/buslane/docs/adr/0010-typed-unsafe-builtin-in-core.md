# Typed unsafe builtin in core

Lane2 typed core represents `builtin("...")` as a typed unsafe builtin: the intrinsic name remains an uninterpreted string, but the direct expected type is recorded explicitly. The type checker does not validate or interpret intrinsic names, while execution targets map intrinsic strings to behavior and preserve the existing unsafe/undefined-behavior boundary.
