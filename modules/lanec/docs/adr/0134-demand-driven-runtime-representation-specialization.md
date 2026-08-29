# Demand-driven runtime representation specialization

Status: superseded by
[ADR-0138](0138-uniform-generic-abi-and-optional-representation-specialization.md).

## Historical decision

This ADR introduced canonical runtime-ABI specialization keys, at most one
worker per key, a generic fallback, and a finite recursive-demand rule. Those
properties remain useful for an optional specialization pass.

The implementation subsequently made an immutable whole-program
representation plan a prerequisite for lowering. Lowering queried that plan
for worker, data-family, callable, and bridge choices. Later work expanded the
plan into per-value assignments and a structural Physical ANF.

## Reason for supersession

The evidence-passing generic ABI was already a complete correctness model.
Requiring a solved specialization plan before VM CFG construction therefore
coupled valid-program lowering to an optimization. It also caused multiple
parallel projections of one program to become independently stored and
verified facts.

ADR-0138 retains the sound parts of this decision but changes their ownership:

- the canonical generic ABI is sufficient for lowering;
- specialization rewrites actual program definitions and calls;
- private work queues and SCC analyses do not become consumer-visible plans;
- recursion that cannot reuse a finite stable key remains generic; and
- deleting specialization changes performance only.

Historical implementation results and measurements remain recorded in the
related issues, but they are not the accepted architecture.
