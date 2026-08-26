# CPS-aware callable-instance planning

Status: superseded by
[ADR-0138](0138-uniform-generic-abi-and-optional-representation-specialization.md).

## Historical decision

This ADR proposed a whole-program Callable Instance Plan, Representation
Constraint Graph, Representation Solution, specialized nominal data families,
and structural Physical ANF. The design attempted to assign every runtime
value port one exact physical contract before VM CFG emission.

The motivation was valid: CPS-generated higher-kinded callables, nominal
storage, captures, and recursive flow must not be assigned incompatible
physical ABIs. VM CFG emission must not guess an ABI from source effect syntax,
raw type spelling, or an ambient family list.

## Reason for supersession

The design made representation specialization responsible for compiler
correctness. Its intermediate facts mirrored program topology and had to be
kept consistent with Runtime ANF, each other, Physical ANF, and VM CFG. Adding
a new physical operation required synchronized planner, graph, materializer,
verifier, and emitter changes.

ADR-0138 restores the correct layering:

- CPS-generated parameters use the same complete generic evidence ABI as all
  other polymorphic values;
- generic lowering remains correct without callable-instance specialization;
- callable-flow analysis may be private input to an optional program rewrite;
- generic nominal data keeps one declaration-owned storage schema;
- representation adaptations are explicit structural operations; and
- the verified physical-program seam carries final contracts, not demand,
  solution, recipe, or occurrence sidecars.

The historical terms remain in closed issue records only. They are not owning
glossary concepts and must not guide new implementation work.
