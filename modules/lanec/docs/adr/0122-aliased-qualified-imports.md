---
status: accepted
---

# Aliased qualified imports separate module identity from local names

Lane accepts an aliased qualified import as:

```lane
import Basic.Data.List as List
```

`as` is a reserved keyword and the alias is one identifier. The alias replaces
the complete imported module path as the authored qualifier for that
declaration: `List.empty` is visible, while `Basic.Data.List.empty` requires a
separate import that binds the complete path. Open and selective imports do not
accept aliases.

The imported module and its lexical module bindings are distinct. An imported
module is identified by its complete canonical module path and owns the module
interface used by resolution, artifacts, fingerprints, and linking. A module
binding is a source-local qualifier, either the complete path introduced by an
ordinary qualified import or the single identifier introduced by an aliased
qualified import. Multiple distinct bindings may target the same imported
module, but one local module name cannot target competing imports.

Aliases use the existing module namespace and ambiguity rules. They do not open
members or offers, do not shadow values or types specially, and do not rewrite
module-path prefixes. The current module's complete path already occupies its
module binding name, so an import cannot reuse that path as an alias or other
local module binding. Lane module paths may share components but do not form a
parent/child module hierarchy.

An alias is a source binder. Qualifier references navigate and rename through
that binder, while qualified member references target their original exported
declarations. Once name resolution succeeds, aliased and unaliased references
contain the same canonical symbols. Checked types, module interfaces,
artifacts, fingerprints, linking, and semantic type presentation do not retain
alias spelling.

Fixed language sugar resolves its typed syntax nodes through canonical
imported-module availability, not through an authored qualifier spelling.
Therefore an aliased import of `Basic.Data.List` enables list syntax and an
aliased import of `Basic.Data.Tuple` enables tuple syntax, while the replaced
complete path remains unavailable to authored qualified access. Sugar targets
and authored module names use separate resolver entry points and both produce
the same ordinary resolved symbols.

Authored qualified access marks only the named module binding as used. A fixed
sugar reference marks every import declaration that provides its canonical
module target as used, avoiding import-order-dependent ownership when one
module has multiple bindings.

## Consequences

- Resolver state separates canonical imported modules from lexical module
  bindings instead of storing both meanings in one path string.
- Module graph edges and module headers use the canonical imported path and
  ignore local aliases.
- Completion exposes the local alias as a module candidate and completes the
  target module interface after `Alias.`.
- Definition on an alias qualifier targets the alias binder; definition on a
  member targets the original declaration.
- Formatter trivia handling covers both boundaries around the `as` keyword.
