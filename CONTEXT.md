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
The exported type, value, and offer surface of a compiled **Module**.
_Avoid_: checked source body, private declarations, source AST

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

**Effect Handler**:
A source-language construct that implements effect operations and discharges their tracked effect requirements.
_Avoid_: catch block, runtime error handler, builtin plugin

**Unchecked Runtime Exception**:
A catchable language-level failure that can escape static effect tracking.
_Avoid_: typed algebraic effect, runtime error report, undefined behavior

**Lane Workspace**:
The MoonBit workspace that contains the compiler, Buslane, command line tool,
and language server modules.
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
The `modules/lane` native command module.
_Avoid_: compiler module, language server module

**Lane LSP Module**:
The `modules/lane_lsp` native language-server module.
_Avoid_: VS Code extension, compiler front end

## Relationships

- `modules/lanec` depends on `modules/buslane`.
- `modules/lane` depends on `modules/lanec` and `modules/buslane`.
- `modules/lane_lsp` depends on `modules/lanec`.
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
