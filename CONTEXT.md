# Lane Workspace

This context defines repository-wide language shared by Lane modules and workflows. Module-specific vocabulary is routed by `CONTEXT-MAP.md`; portable bytecode and runtime terms belong only to `modules/loisvm/CONTEXT.md`.

## Language

**Module**:
A Lane source-language namespace that owns declarations and forms a visibility boundary.
_Avoid_: source file, prelude, MoonBit package

**Module Declaration**:
The source declaration that gives a **Module** its language-level identity.
_Avoid_: file path, package name, implicit filename module

**Module Binding**:
A name made available by importing a **Module Path** for module-qualified access.
_Avoid_: value declaration, type declaration, filesystem directory component

**Source File**:
A non-interactive Lane source text that contains exactly one **Module**.
_Avoid_: module bundle, project, compilation unit

**Source Identity**:
The file or module identity attached to source locations and diagnostics.
_Avoid_: concatenated source offset, anonymous line range, prelude line shift

**Synthetic Module**:
A driver-supplied module identity for interactive or test snippets that are not ordinary source files.
_Avoid_: ordinary source file fallback, implicit filename module, compatibility mode

**Diagnostic Infrastructure**:
Reusable diagnostic data, source mapping, protocol conversion, and rendering primitives shared by Lane tools without knowing Lane compiler semantics.
_Avoid_: compiler diagnostic adapter, Lane error taxonomy, command report

**Module Path**:
A dotted name that identifies a **Module**.
_Avoid_: filesystem path, package URL, source filename

**Double**:
A Lane primitive type representing IEEE 754 binary64 floating-point values.
_Avoid_: Float, Float64, Basic library number type

**Double Literal**:
A source numeric literal containing digits with a decimal fraction or exponent and whose type is **Double**.
_Avoid_: overloaded numeric literal, Float literal, decimal arbitrary-precision value

**Basic Library Module**:
A normal library **Module** supplied explicitly as a **Library Input**.
_Avoid_: prelude, implicit builtin scope, compiler magic module

**Conventional Basic Module**:
A **Basic Library Module** whose module path and exported shapes are recognized by tools as conventions rather than by an official implementation fingerprint.
_Avoid_: pinned Basic library, compiler-owned module, trusted artifact

**Compilation Unit**:
One **Module** compiled by `lanec` against an **Imported Environment**.
_Avoid_: project, module graph, linked program

**Imported Environment**:
The externally supplied module interfaces visible while compiling one **Compilation Unit**.
_Avoid_: concatenated source, prelude text, linker output

**Module Interface**:
The compiler-readable interface artifact for a compiled **Module**, including its exported type, value, and offer surface plus downstream compilation metadata such as **Optimization Hints**.
_Avoid_: checked source body, private declarations, source AST

**Optimization Hint**:
Compiler-produced metadata stored in a **Module Interface** to help downstream compilation or optimization without changing source-language semantics.
_Avoid_: source declaration, module object code, linker-only metadata

**Module Object**:
The lowered link-time artifact for one compiled **Module**.
_Avoid_: module interface, imported environment, source API surface

**Compiled Module**:
The paired output of compiling one **Module**, containing its **Module Interface** and **Module Object**.
_Avoid_: module interface alone, module object alone, linked program

**Module Fingerprint**:
A stable identity for the **Compiled Module** produced by compiling a **Module Interface** against a specific set of **Imported Interface Fingerprints**.
_Avoid_: module path, source file path, linker symbol

**Module Interface Fingerprint**:
A semantic fingerprint of the exported interface surface alone.
_Avoid_: object code hash, filesystem path, modification time

**Imported Interface Fingerprint**:
The compilation-time fingerprint of an imported **Module Interface** recorded by a dependent **Compiled Module**.
_Avoid_: linked object hash, filesystem timestamp, import path match

**Private Lowered Definition**:
A non-exported lowered definition kept inside a **Module Object** for executing exported code.
_Avoid_: exported symbol, interface member, cross-module reference target

**Exported Symbol**:
A stable source-level identity for an exported declaration in a **Module Interface**.
_Avoid_: Buslane identity, local compiler temporary, runtime address

**Linked Program**:
A set of compiled modules whose imported references have been connected and whose executable entry has been selected by the link step.
_Avoid_: single compilation unit, source concatenation, unchecked module graph, run-time entry selection

**GHC-Like Artifact Layering**:
A compiler artifact strategy where interfaces carry public semantics and optimization metadata, objects carry linkable semantic core plus link metadata, and execution images are derived after linking.
_Avoid_: JVM-style runtime symbolic linking, bytecode-as-only-source, ANF-as-artifact-boundary

**Binary Artifact Container**:
The versioned on-disk container used by `.lmi`, `.lmo`, and `.lbp`, starting with Lane artifact magic, an artifact kind, and a structured binary payload.
_Avoid_: text artifact file, JSON wrapper, UTF-8 payload envelope

**Binary Artifact Payload**:
The structured binary record data inside a **Binary Artifact Container** that is the authoritative serialized form for artifact loading.
_Avoid_: artifact text roundtrip, human-readable dump, debug pretty output

**Minimal Linked Program Payload**:
The fixed-order `.lbp` payload containing `linked_program_schema_version:u32le = 4` followed by a LoisVM bytecode section occupying every remaining payload byte.
_Avoid_: section directory, duplicate entry metadata, module provenance record, nested bytecode length

**Canonical Linked Disassembly**:
The deterministic lowered-code projection used by `lane inspect` for `.lbp`, showing schema versions, the selected entry, table summaries, and canonical bytecode instructions without reconstructing source semantics.
_Avoid_: raw byte dump, Buslane reconstruction, source-debug view

**Artifact Text Format**:
A former human-readable artifact serialization that must not be part of the official artifact load path once binary artifact payloads are introduced.
_Avoid_: compatibility parser, canonical artifact schema, inspect output

**Bytecodec**:
A small reusable MoonBit module for strict byte-level binary readers, writers,
primitive little-endian codecs, length-prefixed strings, offset tracking, and
decode errors.
_Avoid_: Lane artifact schema, Buslane AST codec, generic serialization framework

**Canonical Core Artifact**:
The authoritative semantic payload of a Lane **Module Object** and the in-memory linked core, currently Buslane core plus the metadata needed to link, inspect, verify, optimize, or lower it.
_Avoid_: `.lbp` payload, ANF cache, bytecode image, runtime execution layout

**Whole-Program Core Optimization**:
An optimization phase over a linked canonical core program after imported references have been resolved and before lowering to an execution image.
_Avoid_: bytecode-only optimization, source rewriting, interface type checking

**Core Occurrence Analysis**:
A read-only core analysis over a linked **Canonical Core Artifact** before final executable artifact emission that records how core values occur for later optimization decisions.
_Avoid_: source value-use analysis, unused-warning policy, type/effect symbol analysis, raw use-count-only pass, bytecode liveness, artifact payload

**Execution Image**:
A lowered representation for a concrete execution target, such as a portable bytecode image or native code, produced from a linked canonical core program.
_Avoid_: module interface, source API surface, canonical semantic payload

**Bytecode Cache**:
An optional, invalidatable code section stored to avoid repeated lowering when the compiler version, target, options, and core fingerprint still match.
_Avoid_: canonical module payload, interface fingerprint source, cross-module semantic record

**NoBuild Model**:
A build philosophy where running a source file is direct and higher-level compile, link, optimize, and entrypoint policies are user-authored library workflows.
_Avoid_: hard-coded main rule, mandatory project manifest, compiler-owned build graph policy

**Build Workflow**:
A user-authored workflow that composes compilation, linking, optimization, and entrypoint selection.
_Avoid_: language semantics, fixed CLI convention, compiler phase

**Direct File Run**:
Running the module declared by a single source file without requiring a project manifest.
_Avoid_: script mode, anonymous module execution, project discovery

**Entry Selection**:
The workflow choice of which compiled value or function to inspect or execute.
_Avoid_: language-level main rule, implicit export, compiler-owned policy

**Public Entry**:
An exported value or function selected for execution or inspection by a workflow.
_Avoid_: private debug entry, implicit main, unexported root symbol

**Imported Reference Placeholder**:
A Buslane-level placeholder for an imported exported symbol before linking connects it to its defining module.
_Avoid_: source symbol, prelude text, final linked identity

**External Origin**:
The compiler-side classification of a Buslane external value as a runtime intrinsic or an imported reference.
_Avoid_: Buslane source syntax, module namespace in core, untyped runtime lookup

**Import Graph**:
The acyclic dependency graph between modules through their imports.
_Avoid_: recursive module group, textual include order, linker SCC

**Import Graph Check**:
The pre-compilation validation of duplicate modules, missing imports, and import cycles in a **Module Input Set**.
_Avoid_: linker error, filesystem path validation, recursive compilation fallback

**Transparent Export**:
An exported alias whose definition remains visible through a **Module Interface**.
_Avoid_: opaque type, abstract type, private alias

**Interface-Visible Type**:
A type that can appear in a **Module Interface** because it is exported or imported from another **Module Interface**.
_Avoid_: private representation type, local type, hidden implementation detail

**Interface-Visible Effect**:
An effect that can appear in a **Module Interface** because it is exported or imported from another **Module Interface**.
_Avoid_: private effect leak, implementation-only operation, runtime capability

**Library Input**:
Explicitly supplied library source files or library directories made available to a **Build Workflow** or **Direct File Run**.
_Avoid_: implicit prelude, textual include, mandatory project manifest

**Module Input Set**:
The root source and supplied library modules available to one **Direct File Run**.
_Avoid_: global module search path, implicit Basic library, project registry

**Library Directory**:
A directory supplied as a **Library Input** whose source files can provide modules.
_Avoid_: project manifest, implicit Basic library, module identity source

**Open Import**:
An import that places exported members of another **Module** directly in local scope.
_Avoid_: textual include, module shorthand, hidden global scope

**Visible Offer**:
An exported offer available to contextual resolution in the current **Compilation Unit**.
_Avoid_: qualified-only offer, hidden candidate, trait instance

**Module Name Ambiguity**:
A module-level name conflict between local declarations and open imports, or between multiple open imports.
_Avoid_: import-order priority, implicit prelude shadowing, local block shadowing

**Duplicate Module Input**:
Two supplied source files declaring the same **Module Path**.
_Avoid_: library override, search path priority, last-one-wins

**Qualified Import**:
An import that makes an external **Module** name visible without placing its members directly in local scope.
_Avoid_: open import, textual include, prelude concatenation

**Import Section**:
The contiguous import declarations after a **Module Declaration** and before ordinary declarations.
_Avoid_: late import, local import, declaration interleaving

**Duplicate Import**:
Two structurally identical import declarations in the same **Import Section**.
_Avoid_: multi-form import, import-order conflict, last-one-wins

**Selective Import**:
An import that places named exported members of another **Module** directly in local scope.
_Avoid_: wildcard open import, module shorthand, member rename, private declaration access

**Qualified Access**:
Selection through a namespace. Module-qualified value and type access uses `.`, while nominal constructors and variants use `::`.
_Avoid_: implicit open lookup, shadowing rule

**Unambiguous Owner Elision**:
The source-language rule that enum variant and effect operation owners may be omitted when the visible variant or operation namespace contains exactly one matching member name, and must be rejected when no member or multiple members fit.
_Avoid_: expected-type disambiguation, overload resolution, first-match owner, mandatory qualification, delayed ambiguity

**Exported Declaration**:
A declaration explicitly made visible outside its defining **Module**.
_Avoid_: default-public declaration, implementation helper

**Visibility Modifier**:
The top-level declaration prefix that marks an **Exported Declaration**.
_Avoid_: local visibility, module visibility, export block

**Owner-Visible Member**:
A struct field, struct type member, or enum variant whose visibility follows its owning exported type.
_Avoid_: independently exported field, independently exported variant

**Exported Nominal Shape**:
The public fields, type members, and variants of an exported struct or enum.
_Avoid_: opaque representation, private constructor, hidden variant set

**Typed Algebraic Effect**:
A declared source-language operation whose use is statically tracked in effect sets and discharged by effect handlers.
_Avoid_: unchecked exception, runtime panic, implicit IO

**Effect Declaration**:
A top-level nominal declaration that owns a complete set of effect operations and any shared effect type parameters.
_Avoid_: value declaration, operation namespace, runtime plugin

**Effect Operation**:
A member of an effect declaration with a Lane function type signature such as `(String) -> Unit` or `() -> String`.
_Avoid_: top-level function, arbitrary expression payload, unchecked command

**Operation Type Parameter**:
A type parameter introduced by an **Effect Operation** and opened by handlers for each performed operation instance.
_Avoid_: effect type parameter, ordinary value parameter, generic function parameter, runtime tag

**Type Argument List**:
A non-empty bracketed list of type witnesses supplied to a generic type, nominal member, or effect operation call.
_Avoid_: empty brackets, omitted type arguments, type parameter binder list

**Effect Operation Call**:
An effectful operation invocation written with `!`, such as `Console::print!("hi")` or an unambiguous `print!("hi")`.
_Avoid_: ordinary function call, omitted call parentheses, implicit perform expression, unchecked command dispatch

**Effect Set**:
The finite, order-insensitive set of typed algebraic effects that an expression or function may perform.
_Avoid_: exception list, ordered runtime list, runtime capability bag, implicit ambient state

**Effect Set Alias**:
A transparent top-level alias whose expansion has **Effect Kind** and denotes an **Effect Set**.
_Avoid_: effect declaration alias, operation alias, nominal effect wrapper

**Effect Variable**:
A type-level variable ranging over effect sets in an effect-polymorphic function type.
_Avoid_: value parameter, contextual offer, dynamic capability token

**Effect Kind**:
The kind `Effect` whose inhabitants are effect sets and effect variables.
_Avoid_: value-level type, ordinary nominal type kind, runtime capability object

**Effect Polymorphism**:
The ability for a function type to quantify over an effect set and propagate that set through calls.
_Avoid_: effect subtyping, unchecked effect escape, implicit handler search

**Effect Row Unification**:
The equality-based inference process that solves effect variables inside effect sets, including decomposition into handled concrete effects plus a residual row.
_Avoid_: effect subtyping, implicit widening, containment constraint solving, multiple row tails

**Function Effect Annotation**:
The optional `!` suffix after a function result type that states a function's non-empty effect set.
_Avoid_: prefix effect marker, unchecked throws clause, handler declaration

**Effect Handler**:
An expression of the form `handle expression with { ... } with { ... }* final binder { ... }` that implements effect operations and computes one handler result.
_Avoid_: catch block, runtime error handler, implicit identity final branch, per-effect return branch

**Handler With Block**:
One non-empty `with { ... }` block in a handler expression; all arms in the block target the same handled effect.
_Avoid_: mixed-effect handler block, implicit global handler, exception catch group

**Handler Operation Arm**:
A handler pattern arm that matches one effect operation invocation, uses ordinary Lane patterns for operation arguments, and binds an explicit final resume continuation.
_Avoid_: catch clause, method override, optional resume, tupled operation arguments

**Handler Final Branch**:
The required `final binder { ... }` branch that handles ordinary return from the handled expression.
_Avoid_: operation arm, final pattern, match-arm arrow body, implicit identity result

**Resume Continuation**:
The explicit, first-class, multi-shot continuation binder in a handler operation arm.
_Avoid_: implicit resume keyword, one-shot continuation, stack-only continuation, unchecked jump

**Residual Effect Set**:
The effect set that remains on a handler expression after handled effects are removed and unhandled, final-branch, and operation-arm effects are preserved.
_Avoid_: swallowed handler effects, unchecked escape, operation-level leftovers

**Handler Coverage Check**:
The static check that each handled effect is covered as a whole and that each handled operation's argument pattern matrix is exhaustive and useful.
_Avoid_: partial handler, runtime missing-operation failure, duplicate-only rejection

**Deep Effect Handler**:
An effect handler whose resumed continuation remains under the same handler while effects produced directly by handler arm bodies are not self-captured.
_Avoid_: shallow handler, one-shot catch, implicit rehandle of arm bodies

**Buslane Effect Core**:
The Buslane `perform` and `handle` core forms produced by lowering source effect operation calls and handlers.
_Avoid_: source syntax, ordinary function call, exception catch frame

**Unhandled Perform State**:
A stuck Buslane runtime state where a `perform` expression reaches no enclosing handler for its owning effect.
_Avoid_: unchecked exception, implicit runtime catch, successful effect propagation

**Unchecked Runtime Exception**:
A catchable language-level failure that can escape static effect tracking.
_Avoid_: typed algebraic effect, runtime error report, undefined behavior

**Lane Workspace**:
The MoonBit workspace that contains the compiler, Buslane, and command line
tool modules.
_Avoid_: single package, release artifact

**Module Repository Layout**:
The repository layout where each MoonBit module lives under `modules/`.
_Avoid_: `lane-tools`, root package layout

**Compiler Module**:
The `modules/lanec` MoonBit module that owns parsing, resolution, type
checking, source elaboration, and lowering.
_Avoid_: CLI tool, language server

**Buslane Module**:
The `modules/buslane` MoonBit module that owns the typed core language,
verifier, interpreter, and pretty printer.
_Avoid_: source AST, compiler front end

**Lane Command Module**:
The `modules/lane` native command module, including the `lane lsp` language
server subcommand.
_Avoid_: VS Code extension, compiler front end

## Relationships

- `modules/lanec` depends on `modules/buslane`.
- `modules/lane` depends on `modules/lanec` and `modules/buslane`.
- A **Compilation Unit** contains exactly one **Module**.
- Every non-interactive **Module** has an explicit **Module Declaration**.
- A **Source File** contains exactly one **Module**, and its **Module Declaration** is first.
- A **Module Declaration** names a **Module Path**.
- A **Module Declaration** does not create a value or type declaration.
- **Basic Library Modules** use ordinary **Module Paths** such as `Basic.Builtins`, `Basic.Ops`, and `Basic.Io`.
- A **Module Declaration** is a header declaration, not a braced block.
- **Synthetic Modules** are limited to interactive and test drivers.
- A **Source File** has an **Import Section** before ordinary declarations.
- Once an ordinary declaration appears, the **Import Section** is closed and later imports are invalid.
- The order of imports inside an **Import Section** does not affect semantics.
- Source locations carry **Source Identity**.
- A **Compilation Unit** may be checked against an **Imported Environment**.
- An **Imported Environment** is made of **Module Interfaces**.
- `lanec` core compiles one **Compilation Unit** without recursively resolving imports.
- CLI and **Build Workflows** construct the **Imported Environment** before calling `lanec`.
- A **Module Interface** is consumed during downstream compilation.
- A **Module Interface** may carry **Optimization Hints** for downstream compilation.
- A **Module Object** is consumed during linking.
- A **Module Object** carries a **Canonical Core Artifact**; ANF and bytecode are not its semantic source of truth.
- A **Compiled Module** pairs a **Module Interface** with a **Module Object**.
- The **Module Interface** and **Module Object** in one **Compiled Module** share a **Module Fingerprint**.
- A **Compiled Module** records the **Imported Interface Fingerprints** it used during compilation.
- A **Module Interface Fingerprint** is based on interface-visible semantic content, not filesystem metadata.
- A **Module Fingerprint** includes the imported interface fingerprints used by that module compilation.
- Linking rejects mismatched **Module Interface** and **Module Object** pairs.
- Linking rejects modules whose recorded **Imported Interface Fingerprints** do not match the linked **Module Interfaces**.
- Linking rejects imported reference placeholders whose recorded **Module Fingerprint** does not match the linked imported **Module Object**.
- A **Module Object** may contain **Private Lowered Definitions**.
- A **Qualified Import** exposes module-qualified names by default.
- A **Module** may explicitly use an **Open Import**.
- A **Module** may explicitly use a **Selective Import**.
- First-stage imports are qualified imports, open imports, and selective imports.
- A **Duplicate Import** is an error.
- The same **Module** may be imported through multiple non-identical import declarations.
- A default **Qualified Import** binds the full **Module Path** for **Qualified Access**.
- A **Module Binding** is separate from value and type namespaces.
- Value and type declarations do not shadow **Module Bindings**.
- Module-qualified value access is written as `Module.Path.name`.
- Module-qualified type access is written as `Module.Path.Type`.
- Module-qualified effect and **Effect Set Alias** access is written as `Module.Path.Name`.
- Module-qualified nominal member access combines both separators, such as `Module.Path.Type::{ ... }` and `Module.Path.Type::variant`.
- The left side of module-qualified access must be an imported complete **Module Path**.
- Importing `Module` does not make `Module.Child.name` or `Module.Child.Type` available.
- **Double Literals** produce **Double** values directly; Lane does not use
  numeric literal overloading or implicit conversion between `Int` and
  **Double**.
- **Typed Algebraic Effects** are the only planned language-level effect mechanism; **Unchecked Runtime Exceptions** are permanently outside the Lane language design.
- An **Effect Declaration** owns uniquely named **Effect Operations**; an **Effect Operation** may introduce **Operation Type Parameters**.
- An **Operation Type Parameter** is scoped only to its owning **Effect Operation** signature and may shadow an **Effect Declaration** type parameter by normal innermost-binder lookup.
- An **Effect Operation Call** may qualify a generic owning **Effect Declaration** with ordinary owner type arguments, and separately supplies **Operation Type Parameter** witnesses at the perform site.
- An **Effect Handler** must explicitly open **Operation Type Parameters** as fresh type binders for the matching handler arm.
- **Operation Type Parameters** follow the same witness/opened-binder split as existential enum variant type parameters.
- A written **Type Argument List** is always non-empty; omitting brackets is the only way to omit type arguments.
- Public **Effect Declarations** and their operation signatures enter module interfaces; exported function signatures may mention only **Interface-Visible Effects**.
- Public **Effect Set Aliases** enter module interfaces as transparent type aliases and may mention only **Interface-Visible Effects**.
- An **Effect Operation Call** invokes an **Effect Operation**, keeps ordinary call parentheses even for zero arguments, and contributes the owning **Typed Algebraic Effect** to the surrounding **Effect Set**.
- Source **Effect Operation Calls** lower to the `perform` part of **Buslane Effect Core**; source **Effect Handlers** lower to the `handle` part.
- **Effect Operation Lookup** is separate from ordinary value lookup and contextual offer lookup; qualified operation syntax is distinguished by `!` in calls and by handler-arm position.
- A **Function Effect Annotation** names an **Effect Set**; non-empty named function effects must be explicit, while function literals may use an explicit annotation or an expected function type.
- **Effect Sets** normalize by removing duplicates, ignoring order, expanding single-effect sugar, and allowing at most one row tail to solve to the empty effect set.
- An **Effect Set Alias** is a transparent **Top-Level Type Alias** of **Effect Kind**, not a new **Effect Declaration**.
- An **Effect Declaration** and an **Effect Set Alias** cannot share the same top-level name in one **Module**.
- **Effect Polymorphism** uses **Effect Variables** of **Effect Kind** and **Effect Row Unification**, not effect subtyping.
- An **Effect Handler** contains one or more **Handler With Blocks** and exactly one **Handler Final Branch**; each `with` block is non-empty, handles one effect, and cannot be duplicated for the same effect.
- **Handler Operation Arms** must target the block's handled effect, match operation arguments with ordinary Lane patterns, and place the **Resume Continuation** as the final binder.
- **Handler Coverage Check** covers every operation of the handled effect and uses the existing pattern usefulness, exhaustiveness, and first-match order rules; the resume binder is not part of the pattern matrix.
- A **Handler Final Branch** must use `final binder { ... }`, and the binder must be an identifier rather than a pattern.
- The **Residual Effect Set** keeps unhandled effects from the handled expression plus effects from handler arms and the final branch; closed effect sets reject absent handled effects.
- **Deep Effect Handlers** make resumed computation run under the same handler, but effects produced directly by handler arm bodies are not self-captured.
- A **Resume Continuation** is first-class and multi-shot; its type returns the handler result and carries only the handler's **Residual Effect Set**.
- An **Unhandled Perform State** is impossible for well-typed complete safe programs.
- Importing a module does not implicitly import its dotted child module paths.
- A **Selective Import** imports top-level **Exported Declarations**, not **Owner-Visible Members**.
- A **Selective Import** introduces selected exported declarations as unqualified names.
- A **Selective Import** may list exported value and type declarations together.
- A **Selective Import** item is ambiguous if the same imported name matches multiple namespaces without syntactic disambiguation.
- Import declarations do not support `as` aliases or renaming.
- An **Open Import** opens top-level **Exported Declarations**, not **Owner-Visible Members**.
- An **Open Import** contributes exported offers as **Visible Offers**.
- A **Selective Import** contributes selected exported offers as **Visible Offers**.
- **Module Name Ambiguity** is an error rather than a shadowing rule.
- **Module Name Ambiguity** includes dotted chains that could be both module-qualified access and value field projection.
- **Qualified Access** uses `.` for module members and `::` for nominal members.
- Module-level names remain separated by namespace; duplicate names in the same namespace are invalid.
- Declarations are module-private unless they are **Exported Declarations**.
- A **Visibility Modifier** applies only to top-level declarations.
- Type members, fields, and variants are **Owner-Visible Members**.
- A **Module Interface** includes each **Exported Nominal Shape**.
- Public type aliases are **Transparent Exports**.
- Public signatures only mention **Interface-Visible Types**.
- Public nominal shapes only mention **Interface-Visible Types**.
- A **Module Interface** records **Exported Symbols**, not Buslane identities.
- **Optimization Hints** do not change the source-language meaning of an imported **Module**.
- A compilation action produces a **Compiled Module**.
- Cross-module references target **Exported Symbols**, not **Private Lowered Definitions**.
- Module-level visibility is outside the **Module** milestone.
- Imported references lower to **Imported Reference Placeholders** before linking.
- **External Origin** distinguishes runtime intrinsics from imported references.
- A **Linked Program** connects imported references across compiled modules and records the executable entry selected by `link`.
- A build `link` primitive chooses the executable entry before **Core Occurrence Analysis** and whole-program optimization.
- A linked executable artifact exposes one selected entry, not a list of run-time selectable public entries.
- A link-time executable entry is selected through an **Exported Symbol**; private lowered definitions are not command-line entry contracts.
- Link validates the selected entry's executable type and supported runtime effects before producing a linked executable artifact.
- `runobj` must not rely on source-level type information to decide whether an entry is executable; a linked executable artifact may omit type information needed only for link-time validation.
- `runobj` executes the selected entry recorded in the **Linked Program**; it does not choose an entry at run time.
- Lane follows **GHC-Like Artifact Layering** for compile, link, optimization, and execution artifacts.
- **Optimization Hints** may guide downstream optimization like interface metadata, but they do not define source semantics.
- **Whole-Program Core Optimization** runs over a linked **Canonical Core Artifact**, not over source text or per-module bytecode alone.
- **Core Occurrence Analysis** is a **Whole-Program Core Optimization**
  analysis input, not a replacement for **Checked Value-Use Analysis**.
- **Core Occurrence Analysis** runs before final executable artifact emission,
  while type, effect, entry, and root metadata needed for optimization are still
  available.
- **Core Occurrence Analysis** produces optimizer-local derived facts; linked
  artifacts do not store those facts as semantic payload.
- **Core Occurrence Analysis** tracks value-level Buslane/core bindings and
  references, not source type or effect symbols.
- **Core Occurrence Analysis** records structured occurrence facts such as use
  count, call-position use, escape to non-call positions, effectful-context use,
  and reachability from the selected entry.
- **Core Occurrence Analysis** runs on linked Buslane/core, not on ANF; ANF is a
  lower derived form that may have its own later liveness or occurrence pass.
- ANF is a derived normalization layer below Buslane and may be regenerated from the **Canonical Core Artifact**.
- An **Execution Image** is produced from linked core after optimization; it may be the primary payload used by `runobj`, but it is not the public interface contract.
- A **Bytecode Cache** may appear in a **Module Object** or **Linked Program** only as a target-specific cache guarded by fingerprints, compiler version, and lowering options.
- `inspect` should expose semantic metadata and Buslane/core for module objects, while `.lbp` inspection uses **Canonical Linked Disassembly** because linked artifacts contain only the execution image.
- The **NoBuild Model** leaves build policy to **Build Workflows**.
- A **Module Input Set** is parsed for module declarations and import sections before module compilation.
- An **Import Graph Check** runs before compiling any module in the **Module Input Set**.
- A module importing itself is an **Import Graph** cycle.
- Modules in a valid **Module Input Set** compile in topological import order.
- A **Direct File Run** still requires a **Module Declaration**.
- A **Direct File Run** compiles the requested source file without discovering a project graph.
- A **Direct File Run** has no implicit library imports and receives libraries only through **Library Inputs**.
- A **Direct File Run** resolves imports only within its **Module Input Set**.
- A **Library Input** can be a source file or a **Library Directory**.
- Source-file and directory **Library Inputs** follow the same compile, import-resolution, and link-reachability rules.
- A **Library Directory** recursively discovers Lane source files.
- A **Library Directory** skips hidden directories and build output directories during CLI discovery.
- Source files discovered from a **Library Directory** must be valid **Source Files**.
- Filesystem paths do not define or validate **Module Paths**.
- A **Basic Library Module** is never injected implicitly by compiler or command tooling; users provide its interface, object, or source as ordinary inputs.
- A **Conventional Basic Module** may be implemented by any user-provided artifact whose exported shapes satisfy the tool convention.
- A **Duplicate Module Input** is an error, including duplicates between the root source and libraries.
- All modules supplied by **Library Inputs** are compiled, even when they are not imported by the root source.
- Every compiled module must resolve its imports within the **Module Input Set**.
- A **Direct File Run** links the modules reachable from the root source, not every compiled library object.
- Direct run link reachability is computed over the **Import Graph** at module granularity.
- **Entry Selection** is explicit workflow policy rather than a language-level `main` rule.
- Direct **Entry Selection** is limited to **Public Entries**.
- The **Import Graph** is acyclic.
- Buslane core remains independent of **Module** and **Source Identity** concepts.
- The **Pre-Buslane Contract** belongs to `lanec`; it documents checked-source
  invariants, type/effect canonicalization ownership, and source-origin side
  data before Buslane lowering.
- The workspace root owns cross-module development layout only; module-specific
  design notes stay inside each module directory.
