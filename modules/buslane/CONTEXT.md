# Buslane

Buslane is Lane's source-independent typed semantic core between checked source
and lower compiler IRs.

## Language

### Core Model

**Buslane Core Language**:
The typed expression-tree language used as Lane's canonical semantic core.
_Avoid_: source AST, ANF, Physical Program

**Buslane Program**:
A Metadata Registry and an ordered sequence of top-level terms.
_Avoid_: source file, module interface, execution image

**Buslane Identity**:
The stable internal identity used for semantic equality, lookup, verification,
and interpretation.
_Avoid_: source symbol, display name, array position

**Buslane Name**:
The readable occurrence name attached to a Buslane Identity for canonical text
and diagnostics.
_Avoid_: semantic identity, optional debug label

**Buslane Unique**:
The program-wide nonnegative disambiguator carried by a Buslane Name.
_Avoid_: namespace-local index, source span

**Metadata Registry**:
The authoritative table of Buslane declarations, binder kinds, effect flavors,
and identity allocation state.
_Avoid_: source symbol table, raw metadata arrays

**Buslane Verifier**:
The pure semantic boundary that validates metadata, scope, types, effects,
initialization order, and core invariants.
_Avoid_: source typechecker, parser validation

**Buslane Expression Facts**:
The verifier-owned type and effect synthesized for one core expression.
_Avoid_: duplicated optimizer classification, cached AST annotation

**Buslane Interpreter**:
The reference evaluator for verified Buslane programs.
_Avoid_: source interpreter, Lane runtime

### Type And Effect Logic

**Buslane Type Logic**:
The Metadata Registry-aware family of normalization, equality, compatibility,
and effect relations.
_Avoid_: structural `Eq`, source inference

**Definitional Type Equality**:
The symmetric equality of types after beta normalization and alpha-renaming.
_Avoid_: structural equality, value compatibility, beta-eta equality

**Type Consumability**:
The directed relation asking whether an actual value may occupy an expected
position, including function variance and permitted residual-effect widening.
_Avoid_: definitional equality, representation compatibility

**Function Implementation Conformance**:
The directed relation asking whether a function body satisfies its declaration,
with invariant values and effect widening to the declared contract.
_Avoid_: function-value variance, ABI cast

**Effect Subeffect Relation**:
The directed relation asking whether every term of one effect occurs in another.
_Avoid_: effect equality, handler subtraction

**Effect Row**:
A canonical collection of singleton effects with an optional residual Effect
Row Variable.
_Avoid_: ordered effect list, runtime handler table

**Effect Row Variable**:
An Effect-kind parameter standing for unknown residual effects.
_Avoid_: singleton effect, runtime value

**Effect Flavor**:
The `Algebraic` or `External` classification of an effect declaration or row
variable, defining which rows it may denote and whether handling is required.
_Avoid_: effect kind, naming convention

**Canonical Effect**:
The Metadata Registry-normalized form used by Buslane effect relations.
_Avoid_: source spelling, duplicate-preserving list

**Function Latent Effect**:
The Effect Row attached to a Buslane function type.
_Avoid_: operation table, inferred capability object

### Algebraic Effects And Hidden Types

**Buslane Effect Core**:
The core representation of effect constructors, operations, `perform`, deep
handlers, and resume values.
_Avoid_: source handler syntax, runtime plugin API

**Handler Table**:
A core handler grouped first by handled singleton effect and then by operation
alternative.
_Avoid_: source `with` block, flat callback map

**Deep Handler**:
A handler whose resume value reinstalls the same handler around the captured
continuation.
_Avoid_: shallow handler, exception handler

**Resume Value**:
The first-class core value representing a continuation under a Deep Handler.
_Avoid_: host callback, dedicated VM stack object

**Hidden Type Parameter**:
A type binder owned by a data constructor or effect operation and packed at its
construction or perform site.
_Avoid_: owner type parameter, standalone existential type

**Hidden Type Witness**:
The concrete type supplied for a Hidden Type Parameter at a pack site.
_Avoid_: runtime value, owner type argument

**Opened Type Binder**:
The fresh binder introduced by a matching alternative when it opens a Hidden
Type Parameter.
_Avoid_: packed witness, ordinary type alias

### Text And Persistence

**Canonical Buslane Text**:
The single readable, identity-complete syntax shared by pretty printing,
diagnostics, and parsing.
_Avoid_: separate debug format, source reconstruction

**Canonical Floating Text**:
The exact raw-bit spelling used for Buslane `F32` and `F64` literals.
_Avoid_: original source spelling, locale-dependent decimal

**Buslane Codec**:
The Buslane-owned binary encoding of core programs, metadata, types, and
expressions.
_Avoid_: Lane artifact container, pretty text serializer
