# Lane Module Subsystem

This directory groups packages that model, parse, and compile Lane modules.
It is not itself a MoonBit package and intentionally has no `moon.pkg`.

## Packages

- `interface/` owns the public module interface model shared by resolver,
  typechecker, lowering, artifact codecs, and module compilation.
- `frontend/` owns source inputs, module headers, module input sets, and module
  graph construction.
- `compile/` owns module compilation, interface/object artifacts, fingerprints,
  linking, and executable program assembly.

## Dependency Boundaries

- `interface` must not depend on `frontend` or `compile`.
- `frontend` must not depend on `compile`.
- `compile` may depend on `frontend` and `interface`.
- Downstream packages should import the narrowest package they need instead of
  treating this directory as one combined subsystem package.
