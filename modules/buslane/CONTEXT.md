# Buslane

Buslane is Lane's typed semantic core language. It is intentionally independent
from the Lane source front end so it can remain a small reusable module.

## Language

**Buslane Core Language**:
The typed expression-tree core produced after checked source elaboration and
before ANF.
_Avoid_: source AST, parser syntax, compiler symbol table

**Buslane Program**:
A metadata registry plus a sequence of top-level value terms.
_Avoid_: source file, package, module

**Buslane Name**:
A readable occurrence name attached to a Buslane identity for source-like core
text and diagnostics.
_Avoid_: Lane source name, numeric identity alone, display-only label, unnamed fallback

**Buslane Unique**:
A program-wide disambiguator carried by a **Buslane Name** and used for stable
identity in text.
_Avoid_: namespace-local index, source span, occurrence name

**Buslane Name Origin**:
The producer-side source of a **Buslane Name**, used by the Buslane name system
to allocate or reuse a **Buslane Unique**.
_Avoid_: weak display hint, source span alone, array index

**Buslane Identity**:
The stable internal identity used for Buslane equality, lookup, verification,
and interpretation.
_Avoid_: occurrence name, pretty text, source span, namespace-local text suffix

**Buslane Verifier**:
The pure checker that validates Buslane metadata, scope, and expression typing.
_Avoid_: Lane source typechecker, parser validation

**Metadata Registry**:
The authoritative table of Buslane identities and their declarations, including
the binder kinds and effect flavors required by semantic type relations.
_Avoid_: source symbol table, display-name index, raw metadata arrays

**Buslane Type Logic**:
The metadata-aware family of Buslane type and effect relations used for
normalization, equality, value compatibility, and declaration conformance.
_Avoid_: structural `Eq`, Lane source inference, one universal compatibility relation

**Definitional Type Equality**:
The symmetric relation asking whether two types denote the same type after beta
normalization and alpha-renaming; it permits no type or effect widening.
_Avoid_: structural type equality, value compatibility, assignability

**Type Consumability**:
The directed relation asking whether an `actual` value fits an `expected`
position; function parameters are contravariant, results are covariant, and
latent effects may widen only by residual, non-algebraic terms.
_Avoid_: definitional equality, representation compatibility, plain effect subset

**Function Implementation Conformance**:
The directed relation asking whether a direct function body implements its
declaration; parameters and results stay invariant while the body's effects may
widen to any declared superset, including algebraic terms, because the
declaration owns the ABI under which the body is lowered.
_Avoid_: function-value consumability, reference adaptation, implicit coercion

**Effect Subeffect Relation**:
The directed plain-subset relation asking whether every term in a lower effect
occurs in an upper effect; unlike **Type Consumability**, it permits algebraic
as well as residual widening.
_Avoid_: effect equality, callable ABI compatibility, handler subtraction

**Buslane Expression Facts**:
The type and effect synthesized for a Buslane expression from its program metadata. Type-compatibility diagnostics do not invalidate already synthesized facts; structural failures that require sentinel facts do. Verification and effect-aware optimization share this semantic query rather than maintaining parallel expression classifications.
_Avoid_: optimizer purity taxonomy, duplicated type field, structural effect equality

**Buslane Interpreter**:
The reference evaluator for Buslane programs.
_Avoid_: source interpreter, bytecode VM

**Buslane Effect Core**:
The Buslane core-language model for effect constructors, effect operations,
effect terms, `perform`, handlers, resume values, and effect-aware verification.
_Avoid_: source effect syntax, source `with` block, external runtime plugin

**Deep Handler**:
A Buslane handler whose resume value reinstalls the same handler around the
captured continuation.
_Avoid_: shallow handler, callback, exception handler

**Handler Table**:
A Buslane handler structure grouped by handled singleton effect and then by
effect operation alternative.
_Avoid_: source `with` block, flat operation map, exception table

**Operation Alternative**:
The Buslane handler arm for one **Effect Operation** inside a **Handler Table**.
_Avoid_: source pattern arm, function clause, callback

**Resume Value**:
A Buslane runtime value representing the captured continuation under a
**Deep Handler**.
_Avoid_: host callback, exception payload, one-shot continuation

**Closed Effect Set**:
A fully known finite effect set with no effect row variable.
_Avoid_: open effect row, effect subtyping

**Open Effect Row**:
An effect set that contains an effect row variable standing for unknown residual
effects.
_Avoid_: closed effect set, effect subtyping, implicit weakening

**Effect Row Variable**:
A type-level effect variable used to preserve unknown residual effects through
effect-polymorphic functions and handlers.
_Avoid_: singleton effect, operation identity, runtime value

**Effect Flavor**:
The Algebraic-or-External classification attached to effect declarations and
effect row variables, determining whether their terms may require handling.
_Avoid_: effect kind, effect set, naming convention

**Effect Row Variable Flavor**:
The **Effect Flavor** carried by an **Effect Row Variable**, saying what the rows
it ranges over may contain: Algebraic admits any row, External admits only rows
of External Effects. A consumer that must eliminate algebraic effects reads the
flavor to tell a variable it still has to discharge from one it may keep.
Three verifier rules consume it. Instantiation: an argument paired with a
declared External-flavored parameter — through substitution or nominal type
application — must contain no algebraic term (`EffectFlavorMismatch`
otherwise); higher-kinded application carries kinds without declarations, and
flavor is a property of declared row variables, not of kinds. Binder
compatibility: Effect-kind binders pair only when their flavors are equal, in
definitional equality and consumability alike — an External variable ranges
over fewer rows, so a directional reading could be sound, but no relation has
a measured need for it and both stay strict. Open rows: a row ending in an
External-flavored variable is closed to algebraic effects, so a handler over
it must find its handled algebraic effect among the row's explicit terms.
_Avoid_: naming convention, binder position, pipeline phase

**Canonical Effect**:
The metadata-registry-normalized representation of an effect set used for
equality, removal, and unification. Binder kinds participate in canonical
identity.
_Avoid_: source effect syntax, array order, duplicate-preserving effect list

**Effect Operation**:
A Buslane metadata identity invoked by `perform` within its owning effect
constructor.
_Avoid_: value identity, function value, external value

**Effect Owner Argument**:
A type argument supplied to an effect constructor when forming a singleton
effect.
_Avoid_: operation witness, generic perform argument, hidden type binder

**Hidden Type Parameter**:
A metadata type parameter owned by a data constructor or effect operation, packed
with a type witness at construction or `perform` and opened by the matching
alternative.
_Avoid_: owner type parameter, generic function parameter, standalone exists type

**Hidden Type Witness**:
The concrete type supplied for a **Hidden Type Parameter** at the pack site.
_Avoid_: effect owner argument, runtime value, inferred binder

**Opened Type Binder**:
The fresh type binder introduced by a match or handler alternative when it
unpacks a **Hidden Type Parameter**.
_Avoid_: hidden witness, ordinary type alias, owner type parameter

**Effect Kind**:
The Buslane kind for effect constructors, singleton effect terms, and effect
row variables.
_Avoid_: value type, operation set

**Function Latent Effect**:
The effect set attached to a Buslane function type.
_Avoid_: operation set, inferred capability

**Canonical F64 Text**:
A fixed-width lowercase hexadecimal representation of the raw bits of a Buslane `F64` literal.
_Avoid_: original source spelling, decimal Pretty output, locale-dependent float text

**Canonical F32 Text**:
A fixed-width lowercase hexadecimal representation of the raw bits of a Buslane `F32` literal.
_Avoid_: binary64 formatting, decimal Pretty output, locale-dependent float text

**Canonical Core Artifact Role**:
The role Buslane programs play in compiler module objects and the in-memory linked core as the semantic payload used before executable lowering.
_Avoid_: linked `.lbp` payload, module interface policy, bytecode image, execution cache

**Buslane Codec**:
The Buslane-owned structured binary encoder and decoder for Buslane programs,
metadata, types, expressions, and related core identities.
_Avoid_: artifact text parser, compiler artifact writer, inspect renderer

## Relationships

- `lanec` lowers checked Lane source into the **Buslane Core Language**.
- `buslane` does not depend on Lane parser, resolver, or source diagnostics.
- **Buslane Expression Facts** are synthesized by the verifier-owned typing relation and reused by effect-aware optimization.
- A Buslane program may serve the **Canonical Core Artifact Role**, but Buslane
  itself does not own module interfaces, module objects, linked artifacts, bytecode caches, or
  execution image policy.
- The **Buslane Codec** owns binary serialization of Buslane core structures;
  compiler artifact codecs should delegate Buslane payloads to it rather than
  embedding Buslane text or duplicating Buslane AST encoders in `lanec`.
- The **Buslane Codec** should use the shared `bytecodec` module for primitive
  byte reading and writing instead of defining its own byte-level format tools.
- **Buslane Effect Core** belongs to the **Buslane Core Language**, not to
  Lane source syntax.
- A **Handler Table** is grouped by singleton effect before **Operation
  Alternatives**.
- An **Operation Alternative** binds evaluated operation payloads positionally;
  source payload patterns are lowered before Buslane.
- A **Resume Value** reinstalls its **Deep Handler** when invoked.
- **Closed Effect Set** is the fully known case of an effect set; **Open Effect
  Row** is the effect-polymorphic case.
- **Canonical Effect** ignores singleton order and duplicate singleton effects.
- **Buslane Type Logic** uses the **Metadata Registry** for definitional type
  equality, **Type Consumability**, **Function Implementation Conformance**,
  the **Effect Subeffect Relation**, effect equality, and effect
  canonicalization; structural `Eq` on core terms is not semantic equality.
- **Buslane Effect Core** must be represented by Buslane text parsing and
  pretty printing.
- Buslane text is a readable canonical core-language representation; it may use
  compact syntax, but must preserve Buslane-specific semantic distinctions.
- Buslane display output and canonical text are one language, not two syntax
  strategies: the `Pretty` implementations own every construct's spelling and
  the canonical writer renders through them, so what a diagnostic prints is
  what the parser accepts. Declarations are flat and identity-complete for
  that reason — an entity may legally exist without its owner listing it, and
  nesting it inside its owner would not round-trip.
- Buslane text should follow the GHC Core style: readable names for core
  references, internal identities for disambiguation and semantics.
- A **Buslane Name** improves readability and text-level references, while a
  **Buslane Identity** remains the authority for semantic equality.
- Every **Buslane Identity** has a **Buslane Name**; generated entities receive
  synthetic names instead of falling back to nameless numeric syntax.
- A **Buslane Unique** is global within a Buslane program/module text, not local
  to one identity family such as values or operations.
- A producer such as `lanec` supplies **Buslane Name Origins**, not weak display
  hints; the Buslane name system uses origins to allocate or reuse uniques.
- **Effect Row Variables** have **Effect Kind**.
- **Effect Row Variables** are type-level parameters, not a separate runtime
  identity family.
- An **Effect Row Variable** carries an **Effect Row Variable Flavor**, the same
  classification an effect declaration carries; Buslane records it rather than
  leaving consumers to infer it from where the binder sits.
- An **Effect Operation** is not a Buslane value and does not enter the value
  context.
- Buslane represents existential enum lowering through data-constructor
  **Hidden Type Parameters**, construct-site **Hidden Type Witnesses**, and
  match-alternative **Opened Type Binders**; it does not need a standalone
  `exists` type constructor for this path.
- Operation-level type parameters should follow the same hidden
  witness/opened-binder discipline as data constructors.
- Effect owner type arguments and operation **Hidden Type Witnesses** are
  separate Buslane concepts and should not share one overloaded argument array.
- An unhandled **Effect Operation** is not resolved by external runtime plugins.
- A **Function Latent Effect** is an effect set of singleton effects plus
  optional residual row information, not a flattened operation set.
- **Canonical F64 Text** is owned by Buslane/core text and artifacts, while
  source diagnostics may still retain the user's original **Floating Literal**
  spelling before lowering.
- **Canonical F32 Text** is owned by Buslane/core text and artifacts after contextual binary32 rounding, while source diagnostics retain the authored **Floating Literal** spelling.
- **Buslane Interpreter** must evaluate **Deep Handlers** according to Buslane
  runtime semantics.
- The formal contract for Buslane belongs in the `spec` repository; this
  repository owns the implementation-facing model, verifier, interpreter, and
  pretty printer.
