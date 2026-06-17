# Dedicated data constructors

Lane2 typed core represents struct and enum construction with dedicated data-constructor forms rather than treating constructors as first-class function values. This keeps nominal construction, named struct fields, field completeness, payload arity, and diagnostics explicit while avoiding accidental currying or function-value semantics for constructors in v1.
