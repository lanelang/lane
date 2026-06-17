# First-class calls in core

Lane2 typed core call expressions accept any function-valued atom as the callee rather than only known top-level function symbols. This preserves first-class function semantics in typed core while leaving direct-call optimization, closure-call lowering, and calling-convention distinctions to later lowered IR or execution targets.
