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

**Transparent Export**:
An exported alias whose definition remains visible through a **Module Interface**.
_Avoid_: opaque type, abstract type, private alias

**Interface-Visible Type**:
A type that can appear in a **Module Interface** because it is exported or imported from another **Module Interface**.
_Avoid_: private representation type, local type, hidden implementation detail

**Library Input**:
Explicitly supplied library source files or library directories made available to a **Build Workflow** or **Direct File Run**.
_Avoid_: implicit prelude, textual include, mandatory project manifest

**Open Import**:
An import that places exported members of another **Module** directly in local scope.
_Avoid_: textual include, module alias, hidden global scope

**Visible Offer**:
An exported offer available to contextual resolution in the current **Compilation Unit**.
_Avoid_: qualified-only offer, hidden candidate, trait instance

**Module Name Ambiguity**:
A module-level name conflict between local declarations and open imports, or between multiple open imports.
_Avoid_: import-order priority, implicit prelude shadowing, local block shadowing

**Qualified Import**:
An import that makes an external **Module** name visible without placing its members directly in local scope.
_Avoid_: open import, textual include, prelude concatenation

**Import Section**:
The contiguous import declarations after a **Module Declaration** and before ordinary declarations.
_Avoid_: late import, local import, declaration interleaving

**Module Alias**:
A local shorthand name introduced for an imported **Module Path**.
_Avoid_: member alias, open import, renamed declaration

**Selective Import**:
An import that places named exported members of another **Module** directly in local scope.
_Avoid_: wildcard open import, module alias, private declaration access

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
- A **Module Declaration** is a header declaration, not a braced block.
- **Synthetic Modules** are limited to interactive and test drivers.
- A **Source File** has an **Import Section** before ordinary declarations.
- Source locations carry **Source Identity**.
- A **Compilation Unit** may be checked against an **Imported Environment**.
- An **Imported Environment** is made of **Module Interfaces**.
- A **Module Interface** is consumed during downstream compilation.
- A **Module Object** is consumed during linking.
- A **Compiled Module** pairs a **Module Interface** with a **Module Object**.
- A **Module Object** may contain **Private Lowered Definitions**.
- A **Qualified Import** exposes module-qualified names by default.
- A **Module** may explicitly use an **Open Import**.
- A **Module** may explicitly use a **Selective Import**.
- First-stage imports are qualified imports, module aliases, open imports, and selective imports.
- A **Selective Import** imports top-level **Exported Declarations**, not **Owner-Visible Members**.
- An **Open Import** opens top-level **Exported Declarations**, not **Owner-Visible Members**.
- An **Open Import** contributes exported offers as **Visible Offers**.
- A **Selective Import** contributes selected exported offers as **Visible Offers**.
- **Module Name Ambiguity** is an error rather than a shadowing rule.
- A **Qualified Import** may introduce a **Module Alias**.
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
- A **Direct File Run** still requires a **Module Declaration**.
- A **Direct File Run** compiles the requested source file without discovering a project graph.
- A **Direct File Run** has no implicit library imports and receives libraries only through **Library Inputs**.
- **Entry Selection** is explicit workflow policy rather than a language-level `main` rule.
- Direct **Entry Selection** is limited to **Public Entries**.
- The **Import Graph** is acyclic.
- Buslane core remains independent of **Module** and **Source Identity** concepts.
- The workspace root owns cross-module development layout only; module-specific
  design notes stay inside each module directory.
