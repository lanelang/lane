# Lane Module Subsystem

This directory groups packages that model, parse, and compile Lane modules.
The directory root is also the module-interface package.

## Packages

- `./` owns the public module interface model shared by resolver,
  typechecker, lowering, artifact codecs, and module compilation.
- `frontend/` owns source inputs, module headers, module input sets, and module
  graph construction.
- `compile/` owns module compilation, interface/object artifacts, fingerprints,
  linking, and executable program assembly.

## Dependency Boundaries

- the root `module` package must not depend on `frontend` or `compile`.
- `frontend` must not depend on `compile`.
- `compile` may depend on `frontend` and the root `module` package.
- Downstream packages should import the narrowest package they need instead of
  treating this directory as one combined subsystem package.
