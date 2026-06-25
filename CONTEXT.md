# Lane Workspace

This repository groups the core Lane implementation modules that should evolve
together during early compiler and tooling development.

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

**Module Path**:
A dotted name that identifies a **Module**.
_Avoid_: filesystem path, package URL, source filename

**Standard Library Module**:
A normal library **Module** supplied explicitly as a **Library Input**.
_Avoid_: prelude, implicit builtin scope, compiler magic module

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

**Compilation Fingerprint**:
A stable identity shared by the **Module Interface** and **Module Object** produced by the same module compilation.
_Avoid_: module path, source file path, linker symbol

**Module Interface Fingerprint**:
A semantic fingerprint of the exported interface surface and the imported interface fingerprints it depends on.
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
A set of compiled modules whose imported references have been connected for execution or Buslane verification.
_Avoid_: single compilation unit, source concatenation, unchecked module graph

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
_Avoid_: global module search path, implicit standard library, project registry

**Library Directory**:
A directory supplied as a **Library Input** whose source files can provide modules.
_Avoid_: project manifest, implicit standard library, module identity source

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
Selection of a declaration through a module or nominal namespace using `::`.
_Avoid_: field access, implicit open lookup

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
A declared source-language operation whose use is statically tracked and handled by an effect handler.
_Avoid_: unchecked exception, runtime panic, implicit IO

**Effect Declaration**:
A top-level nominal declaration that owns effect operations.
_Avoid_: value declaration, operation namespace, runtime plugin

**Effect Type Parameter**:
A type parameter declared on an effect declaration and shared by all of its operations.
_Avoid_: operation-local type parameter, value parameter, effect variable

**Effect Handler**:
A source-language construct that implements effect operations and discharges their tracked effect requirements.
_Avoid_: catch block, runtime error handler, builtin plugin

**Handler Expression**:
An expression of the form `handle expression with { ... } with { ... }* final binder { ... }` that evaluates a computation under handler with blocks and one final branch.
_Avoid_: statement handler, implicit dynamic scope, exception try block

**Handler With Block**:
One `with { ... }` block in a handler expression.
_Avoid_: mixed-effect handler block, implicit global handler, exception catch group

**Handler Operation Arm**:
A handler pattern arm that matches one effect operation invocation and binds an explicit resume continuation.
_Avoid_: catch clause, method override, single-arm operation implementation

**Effect Handler Exhaustiveness Check**:
The static check that a handler covers every operation of each handled effect and covers each handled operation's argument patterns exhaustively.
_Avoid_: partial handler, operation-level effect removal, runtime missing-operation failure

**Handler Operation Pattern Matrix**:
The pattern matrix formed by all handler operation arms for one effect operation.
_Avoid_: duplicate-arm rejection, operation overloading, unordered handler cases

**Handler Operation Argument Pattern**:
A normal Lane pattern used to match one argument of an effect operation in a handler operation arm.
_Avoid_: handler-only pattern, guard pattern, operation overload case

**Handler Arm Order**:
The source-order matching rule for handler operation arms targeting the same effect operation.
_Avoid_: unordered handler cases, type-directed arm selection, duplicate-arm rejection

**Handled Effect Set**:
The effect set discharged by a handler, inferred from the effects named by its handler with blocks.
_Avoid_: explicit handler effect list, operation-level residual set, runtime handler registry

**Residual Effect Set**:
The effect set that remains on a handler expression after handled effects are removed and handler-arm effects are added.
_Avoid_: swallowed handler effects, unchecked escape, operation-level leftovers

**Expression Effect Propagation**:
The static propagation of expression effect sets outward through blocks, lets, calls, and handlers.
_Avoid_: let-level effect annotation, inferred function effect signature, runtime-only effect tracking

**Callee Effect Set**:
The effect set on a function type that becomes the effect set of a function call expression.
_Avoid_: callee body rechecking, dynamic effect discovery, implicit call-site widening

**Handler Final Branch**:
The required handler branch that binds the normally returned value of the handled expression and computes the handler result.
_Avoid_: operation arm, implicit identity result, per-effect return branch

**Handler Final Branch Requirement**:
The rule that every handler expression has exactly one explicit final branch after all handler with blocks.
_Avoid_: implicit identity final branch, missing final branch, per-with-block final branch

**Resume Continuation**:
The explicit continuation binder in a handler operation arm.
_Avoid_: implicit resume keyword, unchecked jump, ordinary recursive function

**Resume Continuation Type**:
The function type of a resume continuation from an operation result to the handler result with the handler residual effect set.
_Avoid_: pure continuation type, operation argument type, unchecked jump target

**Resume Binder Position**:
The rule that a handler operation arm's resume continuation binder is the final parameter and must be a value binder.
_Avoid_: resume pattern, implicit continuation, non-final resume parameter

**Multi-Shot Resume Continuation**:
A resume continuation that may be invoked multiple times without linear or affine use restrictions.
_Avoid_: one-shot continuation, affine resume, escape-analysis-dependent resume

**First-Class Resume Continuation**:
A resume continuation that can be passed, stored, returned, and invoked like an ordinary function value.
_Avoid_: stack-only resume, scoped resume keyword, non-escaping continuation

**Deep Effect Handler**:
An effect handler whose resumed continuation remains under the same handler.
_Avoid_: shallow handler, one-shot catch, dynamic exception handler

**Effect Operation**:
A member of an effect declaration with a Lane function type signature such as `(String) -> Unit` or `() -> String`.
_Avoid_: top-level function, arbitrary expression payload, unchecked command

**Effect Operation Visibility**:
The rule that effect operations inherit the visibility of their owning effect declaration.
_Avoid_: operation-level export, private operation in public effect, partial public effect surface

**Effect Operation Name Uniqueness**:
The rule that one effect declaration cannot contain two operations with the same name.
_Avoid_: operation overloading, type-directed operation selection, duplicate operation arm

**Operation-Level Generic Effect Operation**:
An effect operation that declares its own type parameters independently of the owning effect declaration.
_Avoid_: effect type parameter, ordinary generic function, handler-polymorphic operation

**Effect Operation Call**:
An effectful operation invocation written with `!`, such as `Console::print!("hi")` or an unambiguous `print!("hi")`.
_Avoid_: ordinary function call, implicit perform expression, unchecked command dispatch

**Qualified Effect Operation Syntax**:
The use of `Effect::operation` in an effect operation call or handler operation arm.
_Avoid_: new operation separator, enum variant syntax, ordinary module-qualified value access

**Effect Operation Lookup**:
The name-resolution process for effect operation calls, separate from ordinary value lookup.
_Avoid_: ordinary function lookup, contextual offer lookup, implicit handler search

**Effect Set**:
The finite set of typed algebraic effects that an expression or function may perform.
_Avoid_: exception list, runtime capability bag, implicit ambient state

**Braced Effect Set**:
An effect set surface syntax written with braces when multiple effects or row extensions are present.
_Avoid_: exception tuple, unordered runtime list, implicit ambient scope

**Single-Effect Sugar**:
The syntax that lets `! E` stand for `! { E }` when the effect annotation contains one effect or effect variable.
_Avoid_: special effect kind, singleton runtime wrapper, non-set effect

**Effect Variable**:
A type-level variable ranging over effect sets in an effect-polymorphic function type.
_Avoid_: value parameter, contextual offer, dynamic capability token

**Effect Kind**:
The kind `Effect` whose inhabitants are effect sets and effect variables.
_Avoid_: value-level type, ordinary nominal type kind, runtime capability object

**Effect Union**:
The type-level union operation for inhabitants of the effect kind.
_Avoid_: value-level union, subtyping join, ordered effect list

**Effect Polymorphism**:
The ability for a function type to quantify over an effect set and propagate it through calls.
_Avoid_: effect subtyping, unchecked effect escape, implicit handler search

**Effect Row Unification**:
The equality-based inference process that solves effect variables inside effect sets.
_Avoid_: effect subtyping, implicit widening, containment constraint solving

**Effect Row Tail**:
The single optional effect variable that may appear inside an effect set.
_Avoid_: multiple row variables, unordered row-variable bag, non-unique effect split

**Effect Set Normalization**:
The set-style normalization of effect sets before comparison or row unification.
_Avoid_: ordered effect list, duplicate-sensitive effects, syntactic equality only

**Function Effect Annotation**:
The optional `!` suffix after a function result type that states a function's non-empty effect set.
_Avoid_: prefix effect marker, unchecked throws clause, handler declaration

**Explicit Function Effect**:
A non-empty function effect set that must be written in the source signature.
_Avoid_: inferred effectful named function, implicit throws, body-only effect discovery

**Expected Function Effect**:
An effect set supplied by an expected function type when checking a function literal.
_Avoid_: body-inferred effect, ambient handler assumption, unchecked effect escape

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
- **Standard Library Modules** use ordinary **Module Paths** such as `Builtins`, `Ops`, and `Core.Int`.
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
- A **Compiled Module** pairs a **Module Interface** with a **Module Object**.
- The **Module Interface** and **Module Object** in one **Compiled Module** share a **Compilation Fingerprint**.
- A **Compiled Module** records the **Imported Interface Fingerprints** it used during compilation.
- A **Module Interface Fingerprint** is based on interface-visible semantic content, not filesystem metadata.
- A **Module Interface Fingerprint** includes the imported interface fingerprints referenced by that interface.
- Linking rejects mismatched **Module Interface** and **Module Object** pairs.
- Linking rejects modules whose recorded **Imported Interface Fingerprints** do not match the linked **Module Interfaces**.
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
- Module-qualified access is written as `Module.Path::name`.
- The left side of module-qualified access must be an imported complete **Module Path**.
- **Typed Algebraic Effects** are the only planned language-level effect mechanism.
- An **Effect Declaration** owns one or more **Effect Operations**.
- An **Effect Declaration** may declare **Effect Type Parameters**.
- Public **Effect Declarations** and their operation signatures enter **Module Interfaces**.
- Exported function signatures may mention only **Interface-Visible Effects**.
- **Effect Operation Visibility** follows the owning **Effect Declaration**.
- **Effect Operation Name Uniqueness** rejects overloaded operations inside one effect declaration.
- **Operation-Level Generic Effect Operations** are not part of the first effect design.
- An **Effect Operation Call** invokes an **Effect Operation** and contributes the owning **Typed Algebraic Effect** to the surrounding **Effect Set**.
- **Qualified Effect Operation Syntax** is distinguished from nominal `::` syntax by `!` in calls and by handler-arm syntactic position.
- **Effect Operation Lookup** resolves `name!` only against visible **Effect Operations**, not ordinary values.
- **Handler Operation Arms** use **Effect Operation Lookup** for unqualified operation names.
- A **Function Effect Annotation** names an **Effect Set**.
- A non-empty function **Effect Set** is an **Explicit Function Effect**.
- A function literal's non-empty **Effect Set** must come from an explicit annotation or an **Expected Function Effect**.
- A **Single-Effect Sugar** annotation is equivalent to a singleton **Braced Effect Set**.
- **Effect Variables** use ordinary type parameter binding syntax with the **Effect Kind**.
- The **Effect Kind** supports **Effect Union** and set-style normalization.
- **Effect Union** is expressed with **Braced Effect Set** syntax rather than a separate operator.
- **Effect Polymorphism** uses **Effect Variables** to propagate effect sets through higher-order function types.
- **Effect Row Unification** solves effect flexibility without **Effect Subtyping**.
- Each **Effect Set** may contain at most one **Effect Row Tail**.
- **Effect Set Normalization** removes duplicates, ignores order, expands singleton sugar, and allows an **Effect Row Tail** to solve to the empty effect set.
- **Expression Effect Propagation** requires expression effects to be covered by the surrounding function effect annotation or discharged by handlers.
- A function call expression uses the **Callee Effect Set** from the callee's function type.
- A **Handler Expression** contains one or more **Handler With Blocks**.
- A **Handler With Block** handles one effect; multiple handled effects use multiple **Handler With Blocks**.
- A **Handler Final Branch Requirement** requires exactly one explicit **Handler Final Branch**.
- A **Handler Operation Arm** binds a **Resume Continuation** explicitly.
- **Resume Binder Position** fixes the **Resume Continuation** as the final handler operation arm parameter.
- A handler's **Handled Effect Set** is inferred from its **Handler With Blocks**.
- A handler's **Residual Effect Set** keeps unhandled effects from the handled expression and effects produced by handler arms.
- Multiple **Handler Operation Arms** may target the same **Effect Operation** when their argument patterns distinguish cases.
- **Handler Arm Order** follows the existing first-match rule for pattern matching.
- **Handler Operation Argument Patterns** use the existing Lane pattern language.
- **Handler Operation Pattern Matrices** use existing pattern usefulness and exhaustiveness checks.
- An **Effect Handler Exhaustiveness Check** checks each **Handler Operation Pattern Matrix**.
- A **Resume Continuation** is a **Multi-Shot Resume Continuation**.
- A **Resume Continuation** is a **First-Class Resume Continuation**.
- A **Resume Continuation Type** carries the handler's **Residual Effect Set**.
- **Effect Handlers** are **Deep Effect Handlers** by default.
- **Effect Handlers** discharge **Typed Algebraic Effects**.
- **Unchecked Runtime Exceptions** are permanently outside the Lane language design.
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
- **Qualified Access** is used for module members and nominal members.
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
- A **Linked Program** connects imported references across compiled modules.
- A build `link` primitive produces a **Linked Program** suitable for optimization or execution.
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
- A **Duplicate Module Input** is an error, including duplicates between the root source and libraries.
- All modules supplied by **Library Inputs** are compiled, even when they are not imported by the root source.
- Every compiled module must resolve its imports within the **Module Input Set**.
- A **Direct File Run** links the modules reachable from the root source, not every compiled library object.
- Direct run link reachability is computed over the **Import Graph** at module granularity.
- **Entry Selection** is explicit workflow policy rather than a language-level `main` rule.
- Direct **Entry Selection** is limited to **Public Entries**.
- The **Import Graph** is acyclic.
- Buslane core remains independent of **Module** and **Source Identity** concepts.
- The workspace root owns cross-module development layout only; module-specific
  design notes stay inside each module directory.
