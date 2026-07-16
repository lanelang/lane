# Buslane

`Milky2018/buslane` is a typed semantic core language for compilers and language tools written in MoonBit. It provides a compact, source-independent representation for whole programs together with verification, canonical text, binary serialization, pretty printing, and a reference interpreter.

Buslane is the semantic boundary between a source-language type checker and execution-oriented IRs:

```text
Checked source -> Buslane -> ANF / executable lowering -> bytecode or another backend
```

It is used by the Lane compiler, but the module does not depend on Lane syntax, parsing, name resolution, source diagnostics, or the Lane type checker. Other language implementations can construct Buslane directly.

## Features

- Typed expression-tree IR with explicit metadata and stable identities
- Primitive, nominal, polymorphic, higher-kinded, and effect-aware types
- Explicit functions, type abstraction and application, nominal construction, matching, algebraic operations, handlers, and resumptions
- Built-in `Io` effect plus user-defined parameterized effects
- Pure verifier for metadata, scope, kind, type, effect, arity, and match invariants
- Pretty-printing for diagnostics and snapshots
- Round-trippable canonical text representation
- Versioned structured binary codec
- Reference interpreter with external-value and runtime-operation integration

## Installation

Add the module to a MoonBit project:

```bash
moon add Milky2018/buslane
```

Import only the packages your project uses in `moon.pkg`: `Milky2018/buslane` for the core model, `Milky2018/buslane/text` for canonical text, `Milky2018/buslane/codec` for binary persistence, and `Milky2018/buslane/interpreter` for reference execution.

The root `Milky2018/buslane` package is sufficient for constructing, inspecting, and verifying programs.

## Quick start

A Buslane producer first defines semantic identities and their types in a `MetadataRegistry`, then builds top-level terms using those identities.

```mbt check
///|
test "build and verify a Buslane program" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let main = metadata.define_value(
    "main",
    Function,
    Function([], Primitive(Int), Empty),
  )
  let program = Program::{
    metadata,
    terms: [
      Let(
        main,
        Function({
          parameters: [],
          result_type: Primitive(Int),
          body: Literal(Int(42L)),
        }),
      ),
    ],
  }

  debug_inspect(verify_program(program), content="{ diagnostics: [] }")
  inspect(
    @prettyprinter.render(program, width=80),
    content=(
      #|buslane {
      #|  metadata {
      #|    function main#0 : () -> Int
      #|  }
      #|  let value#0 = fn() -> Int {
      #|    42
      #|  }
      #|}
    ),
  )
}
```

The metadata registry allocates IDs and globally unique readable names. Expressions refer to IDs; occurrence names are for readable core text and diagnostics, not semantic equality.

### Canonicalize effects

Effect equality treats unions as sets. Canonicalization removes empty and duplicate members.

```mbt check
///|
test "canonicalize a Buslane effect set" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let state = metadata.define_effect("State", [])
  let effect = Effect::Union([
    Singleton(state, []),
    Empty,
    Io,
    Singleton(state, []),
  ])

  inspect(
    @prettyprinter.render(effect.canonicalize(), width=80),
    content="{effect#0, Io}",
  )
  assert_true(effect.equals(Union([Io, Singleton(state, [])])))
}
```

### Construct and match nominal data

Nominal data constructors are declared in metadata. Construction carries owner type arguments, while match alternatives bind payload values explicitly.

```mbt check
///|
test "verify nominal construction and matching" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let element = metadata.define_type_parameter("T", Type)
  let box_type = metadata.define_type("Box", [element])
  let box = metadata.define_data_constructor("Box", box_type, [], [
    Parameter(element),
  ])
  let box_of_int = Type::Apply(Constructor(box_type), [
    TypeArgument(Primitive(Int)),
  ])
  let result = metadata.define_value("result", Value, Primitive(Int))
  let matched = metadata.define_value("matched", MatchBinder, box_of_int)
  let payload = metadata.define_value("payload", Parameter, Primitive(Int))
  let program = Program::{
    metadata,
    terms: [
      Let(
        result,
        Match({
          scrutinee: Construct({
            data_constructor: box,
            type_arguments: [TypeArgument(Primitive(Int))],
            hidden_witnesses: [],
            payloads: [Literal(Int(42L))],
          }),
          binder: matched,
          result_type: Primitive(Int),
          alternatives: [
            {
              alt_constructor: DataCon(box),
              type_binders: [],
              value_binders: [payload],
              body: Ref(payload),
            },
          ],
        }),
      ),
    ],
  }

  debug_inspect(verify_program(program), content="{ diagnostics: [] }")
}
```

### Substitute types and effects

`TypeSubstitution` replaces both `Type`-kind and `Effect`-kind parameters in one traversal.

```mbt check
///|
test "substitute a polymorphic function body" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let value_parameter = metadata.define_type_parameter("T", Type)
  let effect_parameter = metadata.define_type_parameter("E", Effect)
  let function_type = Type::Function(
    [Parameter(value_parameter)],
    Parameter(value_parameter),
    Parameter(effect_parameter),
  )
  let substitution = TypeSubstitution::TypeSubstitution()
  substitution.insert(value_parameter, Primitive(String))
  substitution.insert_effect(effect_parameter, Io)

  inspect(
    @prettyprinter.render(function_type.substitute(substitution), width=80),
    content="(String) -> String ! Io",
  )
}
```

## Language model

### Programs and metadata

A `Program` contains:

- `metadata`: definitions for types, type parameters, values, data constructors, effects, and operations;
- `terms`: ordered top-level `Let`, `LetRec`, and `External` terms.

Metadata describes semantic entities independently from executable bodies. Top-level term order preserves initialization order, while `LetRec` explicitly identifies recursive value groups.

Use `MetadataRegistry` methods rather than constructing IDs manually:

- `define_type_parameter`
- `define_type`
- `define_data_constructor`
- `define_effect`
- `define_operation`
- `define_value`

Each definition receives a readable occurrence name and returns the corresponding typed ID.

### Types, kinds, and effects

Buslane types include:

- primitive `Unit`, `Bool`, `Int`, `Double`, and `String` types;
- nominal constructors and kind-aware generic application;
- type parameters and type-level lambdas;
- n-ary function types with latent effects;
- explicit `Forall` polymorphism.

Type parameters have kind `Type`, `Effect`, or `Function(parameters, result)`. Generic applications therefore use `GenericArgument::TypeArgument` or `GenericArgument::EffectArgument` explicitly.

Effects include:

- `Empty` for no effects;
- `Io` for the built-in runtime I/O effect;
- `Singleton(effect_id, arguments)` for a user-defined effect instance;
- `Parameter(type_parameter_id)` for an open effect row;
- `Union(effects)` for a set of effects.

Use `Effect::canonicalize` or `Effect::equals` when comparing effect sets. Canonicalization removes empty terms and duplicates while making equality independent from union ordering.

### Expressions

Buslane retains semantic expression structure instead of forcing ANF. `Expr` includes:

- references and primitive literals;
- function and type-lambda introduction;
- value and type application;
- local `Let` and `LetRec` bindings;
- nominal construction and one-level alternatives;
- effect `Perform`, deep `Handle`, and `Resume` nodes.

Calls may contain arbitrary expressions. Introducing administrative temporaries and atomizing calls are responsibilities of a later ANF or executable-lowering pass.

Nominal construction separates owner type arguments from hidden witnesses. Match alternatives bind the hidden type parameters and payload values opened by a data constructor. Effect operations use the same distinction between effect-owner arguments and operation-level hidden witnesses.

## Verification

Call `verify_program` after constructing, parsing, or decoding a program and before handing it to later compiler passes.

```mbt check
///|
test "inspect verifier diagnostics" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let answer = metadata.define_value("answer", Value, Primitive(Bool))
  let program = Program::{ metadata, terms: [Let(answer, Literal(Int(42L)))] }

  inspect(
    @prettyprinter.render(verify_program(program), width=80),
    content=(
      #|verify_result {
      #|  type_mismatch {
      #|    expected Bool
      #|    actual Int
      #|  }
      #|}
    ),
  )
}
```

The verifier checks, among other invariants:

- referenced metadata identities exist;
- type and effect arguments have the expected kinds;
- references are in scope and binding categories are valid;
- expressions agree with their declared value and result types;
- function, constructor, operation, and alternative arities match metadata;
- recursive groups contain valid recursive right-hand sides;
- match alternatives are unique, ordered correctly, and exhaustive;
- effect operations and handler alternatives agree with their owners.

`VerifyResult` accumulates structured `VerifyDiagnostic` values rather than stopping at the first error. The verifier is a Buslane well-formedness checker, not a source-language type checker.

## Package guide

### `Milky2018/buslane`

Owns the IR data model, identity allocation, type and effect operations, verifier, and `Pretty` implementations. Use this package in producers and analyses that operate directly on Buslane.

`@prettyprinter.render(value, width=...)` produces readable diagnostic output. Pretty output is intended for humans and snapshots; use the text package when a parseable representation is required.

### `Milky2018/buslane/text`

Provides a canonical, round-trippable textual representation:

```mbt check
///|
test "round-trip canonical Buslane text" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let answer = metadata.define_value("answer", Value, Primitive(Int))
  let program = Program::{ metadata, terms: [Let(answer, Literal(Int(42L)))] }
  let source = @text.CanonicalTextWriter::CanonicalTextWriter().write_program(
    program,
  )
  let decoded = match @text.parse_program_text(source) {
    Ok(program) => program
    Err(message) => fail(message)
  }

  assert_eq(decoded, program)
  debug_inspect(verify_program(decoded), content="{ diagnostics: [] }")
}
```

`write_type` and `parse_type_text` provide the same boundary for standalone Buslane types. Canonical text preserves semantic distinctions and stable identities; it is suitable for fixtures, debugging artifacts, and interoperability tests.

### `Milky2018/buslane/codec`

Provides the structured binary persistence boundary:

```mbt check
///|
test "round-trip Buslane binary" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let answer = metadata.define_value("answer", Value, Primitive(Int))
  let program = Program::{ metadata, terms: [Let(answer, Literal(Int(42L)))] }

  let decoded = @codec.decode_program(@codec.encode_program(program))
  assert_eq(decoded, program)
  debug_inspect(verify_program(decoded), content="{ diagnostics: [] }")
}
```

The decoder rejects unsupported schema versions, invalid tags, malformed primitive fields, and trailing bytes through `BuslaneDecodeError`. Binary encoding is for Buslane payloads; enclosing compiler artifacts remain responsible for their own framing, module metadata, compatibility policy, and resource limits.

### `Milky2018/buslane/interpreter`

Provides a reference evaluator for verified Buslane semantics:

```mbt check
///|
test "evaluate a Buslane value" {
  let metadata = MetadataRegistry::MetadataRegistry()
  let answer = metadata.define_value("answer", Value, Primitive(Int))
  let program = Program::{ metadata, terms: [Let(answer, Literal(Int(42L)))] }
  let runtime = @interpreter.BuslaneExternalRuntime::BuslaneExternalRuntime()
  let evaluated = @interpreter.evaluate_buslane_program(program, runtime)

  debug_inspect(evaluated.lookup(answer).as_int(), content="Some(42)")
}
```

Register `BuslaneExternalRuntime` resolvers for `TopTerm::External` values. Native functions and primitive runtime values are created with `BuslaneRuntimeValue` constructors. Runtime operation handlers can be registered by `OperationId` where an embedding uses that interpreter boundary.

The interpreter is intended as a semantic reference, testing oracle, and simple embedding path. Production lowering may target ANF, bytecode, WebAssembly, or another backend without changing the Buslane program model.

## Producer contract

A producer is responsible for preserving these boundaries:

1. Finish source parsing, name resolution, source type checking, and source-specific desugaring before constructing Buslane.
2. Allocate semantic identities through one program metadata registry.
3. Expand transparent source aliases and lower source-only constructs before the Buslane boundary.
4. Preserve polymorphism, nominal hidden witnesses, latent effects, handlers, and resumptions explicitly.
5. Run `verify_program` before publishing a Buslane artifact or beginning executable lowering.
6. Treat pretty output as diagnostic text, canonical text as the readable round-trip format, and the binary codec as the persistence format.

Buslane deliberately does not own source modules, import resolution, compiler symbol tables, source spans, artifact linking policy, ANF scheduling, ownership analysis, bytecode, or backend execution images.

## Development

From the Lane workspace root, name the Buslane packages explicitly so the surrounding workspace is not included:

```bash
moon check modules/buslane modules/buslane/codec modules/buslane/interpreter modules/buslane/text --target all
moon test modules/buslane modules/buslane/codec modules/buslane/interpreter modules/buslane/text --target all
moon info modules/buslane
moon fmt
```

The repository also contains:

- [`docs/buslane-core.md`](docs/buslane-core.md): implementation-oriented language model;
- [`docs/adr/`](docs/adr/): representation and semantic decisions;
- [`CONTEXT.md`](CONTEXT.md): canonical project vocabulary and package boundaries.

Normative Lane language rules belong to the separate specification. This module documents and implements the reusable Buslane core model.

## License

MIT
