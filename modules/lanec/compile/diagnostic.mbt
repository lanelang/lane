///|
using @prettyprinter {type Document, line, separate, space, text}

///|
pub(all) struct CompileDiagnostic {
  source_id : String?
  message : String
  span : @basic.SourceSpan?
  severity : CompileDiagnosticSeverity
  code : String?
  labels : Array[CompileDiagnosticLabel]
  notes : Array[String]
  helps : Array[String]
} derive(Debug, Eq)

///|
pub(all) enum CompileDiagnosticSeverity {
  Error
  Warning
} derive(Debug, Eq)

///|
pub(all) struct CompileDiagnosticLabel {
  span : @basic.SourceSpan
  message : String
  style : CompileDiagnosticLabelStyle
} derive(Debug, Eq)

///|
pub(all) enum CompileDiagnosticLabelStyle {
  Primary
  Secondary
} derive(Debug, Eq)

///|
priv enum CompileErrorKind {
  NoRootSourceModule
  DuplicateModuleInput(String)
  MissingImport(String)
  ImportCycle(String)
  DuplicateModuleInterfaceArtifact(String)
  UnsupportedModuleInterfaceArtifactSchema(String)
  InvalidModuleInterfaceArtifact(module_path_text~ : String, reason~ : String)
  DuplicateModuleObjectArtifact(String)
  UnsupportedModuleObjectArtifactSchema(
    schema~ : Int,
    module_path_text~ : String
  )
  InvalidModuleObjectArtifact(module_path_text~ : String, reason~ : String)
  DuplicateModuleArtifact(String)
  UnsupportedModuleArtifactSchema(String?)
  InvalidModuleArtifact(module_path_text~ : String, reason~ : String)
  MissingObject(String)
  MissingImportedObject(String)
  ImportedInterfaceFingerprintMismatch(importer~ : String, imported~ : String)
  ImportedReferenceFingerprintMismatch(
    importer~ : String,
    imported~ : String,
    name~ : String
  )
  ImportedReferenceMismatch(
    importer~ : String,
    imported~ : String,
    name~ : String
  )
  MissingExported(
    kind~ : String,
    provider~ : String,
    name~ : String,
    importer~ : String
  )
  StaleModuleObject(module_path_text~ : String, reason~ : String)
  UnsupportedLinkedProgramArtifactSchema
  InvalidLinkedBuslaneProgram
  DuplicateLinkedModule(String)
  LinkedEntryUnknownValue(String)
  DuplicateLinkedEntry(String)
  CheckedSourceConstructionFailed
  ParserProducedNoSourceFile
}

///|
fn diagnostic(
  message : String,
  span~ : @basic.SourceSpan?,
  severity~ : CompileDiagnosticSeverity,
  code~ : String?,
  labels~ : Array[CompileDiagnosticLabel],
  notes~ : Array[String],
  helps~ : Array[String],
) -> CompileDiagnostic {
  { source_id: None, message, span, severity, code, labels, notes, helps }
}

///|
fn CompileDiagnostic::with_source_id(
  self : CompileDiagnostic,
  source_id : String,
) -> CompileDiagnostic {
  { ..self, source_id: Some(source_id) }
}

///|
fn primary_label(
  span : @basic.SourceSpan?,
  message : String,
) -> Array[CompileDiagnosticLabel] {
  match span {
    Some(span) => [{ span, message, style: Primary }]
    None => []
  }
}

///|
fn CompileErrorKind::to_diagnostic(
  self : CompileErrorKind,
  span : @basic.SourceSpan?,
) -> CompileDiagnostic {
  match self {
    NoRootSourceModule =>
      compile_report(
        "no root source module",
        span,
        code="E4000",
        label="the compiler did not receive a root Lane module",
        note="Lane compile/check needs exactly one root source module",
        help="pass a source file that starts with a `module` declaration",
      )
    DuplicateModuleInput(module_) =>
      compile_report(
        "duplicate module input `\{module_}`",
        span,
        code="E4001",
        label="this module was supplied more than once",
        note="a module input set cannot contain two sources with the same module name",
        help="remove one source file or rename one of the modules",
      )
    MissingImport(module_) =>
      compile_report(
        "missing imported module `\{module_}`",
        span,
        code="E4002",
        label="this import has no matching module input or interface artifact",
        note="Lane does not search the file system by module name during compilation",
        help="pass the imported module as a library source or compiled interface",
      )
    ImportCycle(module_) =>
      compile_report(
        "import cycle involving `\{module_}`",
        span,
        code="E4003",
        label="module imports must form an acyclic graph",
        note="cyclic module dependencies cannot be typechecked in a stable order",
        help="move shared declarations into a separate module imported by both sides",
      )
    DuplicateModuleInterfaceArtifact(module_) =>
      compile_report(
        "duplicate interface artifact for `\{module_}`",
        span,
        code="E4100",
        label="two interface artifacts describe the same module",
        note="compile uses one interface per imported module",
        help="remove the duplicate `--interface` input",
      )
    UnsupportedModuleInterfaceArtifactSchema(module_) =>
      compile_report(
        "unsupported module interface artifact schema",
        span,
        code="E4101",
        label="unsupported module interface artifact schema \{module_}",
        note="this `.lmi` was produced by an incompatible Lane compiler or edited by hand",
        help="recompile the provider module with the current `lane compile`",
      )
    InvalidModuleInterfaceArtifact(module_path_text~, reason~) =>
      compile_report(
        "invalid module interface artifact",
        span,
        code="E4102",
        label="module interface artifact \{reason} \{module_path_text}",
        note="the interface artifact metadata does not match its embedded module interface",
        help="recompile the provider module and pass the fresh `.lmi` file",
      )
    DuplicateModuleObjectArtifact(module_) =>
      compile_report(
        "duplicate object artifact for `\{module_}`",
        span,
        code="E4200",
        label="two object artifacts define the same module",
        note="linking requires one object artifact per module",
        help="remove the duplicate `.lmo` input",
      )
    UnsupportedModuleObjectArtifactSchema(schema~, module_path_text~) =>
      compile_report(
        "unsupported module object artifact schema",
        span,
        code="E4201",
        label="unsupported module object artifact schema \{schema} for \{module_path_text}",
        note="this `.lmo` was produced by an incompatible Lane compiler or edited by hand",
        help="recompile the module with the current `lane compile`",
      )
    InvalidModuleObjectArtifact(module_path_text~, reason~) =>
      compile_report(
        "invalid module object artifact",
        span,
        code="E4202",
        label="module object artifact \{reason} \{module_path_text}",
        note="the object artifact metadata does not match its embedded interface or fingerprints",
        help="recompile the module and pass the fresh `.lmo` file",
      )
    DuplicateModuleArtifact(module_) =>
      compile_report(
        "duplicate compiled module `\{module_}`",
        span,
        code="E4300",
        label="two compiled modules have the same module name",
        note="linking requires one compiled module for each module name",
        help="remove the duplicate module artifact",
      )
    UnsupportedModuleArtifactSchema(module_) =>
      compile_report(
        "unsupported compiled module artifact schema",
        span,
        code="E4301",
        label=unsupported_module_artifact_schema_label(module_),
        note="this compiled module artifact is not compatible with the current compiler",
        help="recompile all modules with the current compiler",
      )
    InvalidModuleArtifact(module_path_text~, reason~) =>
      compile_report(
        "invalid compiled module artifact",
        span,
        code="E4302",
        label="module artifact \{reason} \{module_path_text}",
        note="the compiled module artifact has inconsistent interface/object metadata",
        help="recompile the module instead of mixing old interface and object files",
      )
    MissingObject(module_) =>
      compile_report(
        "missing object artifact for `\{module_}`",
        span,
        code="E4203",
        label="the linker needs this module object but it was not provided",
        note="module objects contain the compiled Buslane terms used by the linker",
        help="compile `\{module_}` and pass its `.lmo` to `lane link`",
      )
    MissingImportedObject(module_) =>
      compile_report(
        "missing imported object artifact for `\{module_}`",
        span,
        code="E4204",
        label="an object imports this module but the linker cannot find its object",
        note="linking follows object dependencies recorded during compile",
        help="pass the missing module's `.lmo` to `lane link`",
      )
    ImportedInterfaceFingerprintMismatch(importer~, imported~) =>
      compile_report(
        "stale imported interface",
        span,
        code="E4103",
        label="imported interface fingerprint mismatch \{importer} -> \{imported}",
        note="the importer was compiled against a different interface fingerprint",
        help="recompile the importer and provider modules together",
      )
    ImportedReferenceFingerprintMismatch(importer~, imported~, name~) =>
      compile_report(
        "stale imported reference",
        span,
        code="E4205",
        label="imported reference fingerprint mismatch \{importer} -> \{imported}::\{name}",
        note="an object refers to an exported symbol shape that no longer matches its provider",
        help="recompile the importing module against the current provider object",
      )
    ImportedReferenceMismatch(importer~, imported~, name~) =>
      compile_report(
        "stale imported reference",
        span,
        code="E4205",
        label="imported reference mismatch \{importer} -> \{imported}::\{name}",
        note="an object refers to an exported symbol shape that no longer matches its provider",
        help="recompile the importing module against the current provider object",
      )
    MissingExported(kind~, provider~, name~, importer~) =>
      compile_report(
        "object artifact does not satisfy its interface",
        span,
        code="E4206",
        label="missing exported \{kind} \{provider}::\{name} imported by \{importer}",
        note="the imported interface advertises a public item that the object does not export",
        help="recompile the provider module and use matching `.lmi` and `.lmo` artifacts",
      )
    StaleModuleObject(module_path_text~, reason~) =>
      compile_report(
        "stale module object",
        span,
        code="E4207",
        label="\{reason} \{module_path_text}",
        note="the compiled object fingerprint does not match the module interface metadata",
        help="recompile the module before linking",
      )
    UnsupportedLinkedProgramArtifactSchema =>
      compile_report(
        "unsupported linked program artifact schema",
        span,
        code="E4400",
        label="unsupported linked program artifact schema",
        note="this linked program artifact is not compatible with the current runtime",
        help="link the program again with the current `lane link`",
      )
    InvalidLinkedBuslaneProgram =>
      compile_report(
        "linked program contains invalid Buslane",
        span,
        code="E4401",
        label="the Buslane verifier rejected the linked program",
        note="this usually means the compiler or linker emitted inconsistent core terms",
        help="recompile and relink; if the error remains, report it as a compiler bug",
      )
    DuplicateLinkedModule(module_) =>
      compile_report(
        "duplicate linked module `\{module_}`",
        span,
        code="E4402",
        label="the linked program lists this module more than once",
        note="linked program metadata must contain each module once",
        help="relink from a deduplicated object input set",
      )
    LinkedEntryUnknownValue(entry) =>
      compile_report(
        "linked entry `\{entry}` points to an unknown value",
        span,
        code="E4403",
        label="entry metadata references a value that is not in the Buslane program",
        note="entry metadata is produced by the linker from public Lane entries",
        help="relink the program; if the error remains, report it as a compiler bug",
      )
    DuplicateLinkedEntry(entry) =>
      compile_report(
        "duplicate linked entry `\{entry}`",
        span,
        code="E4404",
        label="the linked program exports this entry name more than once",
        note="entry lookup must resolve to exactly one linked value",
        help="rename one of the public entries or relink from a consistent object set",
      )
    CheckedSourceConstructionFailed =>
      compile_report(
        "compiler produced no checked source",
        span,
        code="E4500",
        label="checked source construction failed",
        note="type checking finished without a checked source tree",
        help="report this as a compiler bug with the input that triggered it",
      )
    ParserProducedNoSourceFile =>
      compile_report(
        "parser produced no source file",
        span,
        code="E1102",
        label="parser produced no source file",
        note="the parser returned neither a source tree nor a concrete parse error",
        help="report this as a compiler bug with the input that triggered it",
      )
  }
}

///|
fn unsupported_module_artifact_schema_label(module_ : String?) -> String {
  match module_ {
    Some(module_) => "unsupported module artifact schema \{module_}"
    None => "unsupported module artifact schema"
  }
}

///|
fn compile_report(
  title : String,
  span : @basic.SourceSpan?,
  code~ : String,
  label~ : String,
  note~ : String,
  help~ : String,
) -> CompileDiagnostic {
  diagnostic(
    title,
    span~,
    severity=Error,
    code=Some(code),
    labels=primary_label(span, label),
    notes=[note],
    helps=[help],
  )
}

///|
fn parse_diagnostics(result : @parser.ParseResult) -> Array[CompileDiagnostic] {
  let diagnostics = []
  for error in result.lexical_errors {
    diagnostics.push(lex_diagnostic(error))
  }
  for error in result.parse_errors {
    diagnostics.push(parse_diagnostic(error))
  }
  diagnostics
}

///|
fn resolve_diagnostic(
  diagnostic_ : @resolve.ResolveDiagnostic,
  _display : TypeDisplayContext,
) -> CompileDiagnostic {
  let span = Some(diagnostic_.loc)
  match diagnostic_.kind {
    UnresolvedType(name) =>
      diagnostic(
        "cannot find type `\{name}`",
        span~,
        severity=Error,
        code=Some("E2000"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "no type named `\{name}` is visible here",
            style: Primary,
          },
        ],
        notes=[
          "Lane resolves type names from the current module and explicitly imported public types",
        ],
        helps=[
          "declare `\{name}`, import the module that exports it, or qualify the type as `Module.\{name}`",
        ],
      )
    UnresolvedValue(name) =>
      diagnostic(
        "cannot find value `\{name}`",
        span~,
        severity=Error,
        code=Some("E2001"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "no value named `\{name}` is visible here",
            style: Primary,
          },
        ],
        notes=[
          "Lane value lookup uses local bindings, top-level values, and explicitly imported public values",
        ],
        helps=[
          "define `\{name}` before this use, import it, or qualify it with its module path",
        ],
      )
    UnresolvedField(type_name~, field~) =>
      diagnostic(
        "cannot find field `\{field}` on `\{type_name}`",
        span~,
        severity=Error,
        code=Some("E2002"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "`\{type_name}` has no visible field named `\{field}`",
            style: Primary,
          },
        ],
        notes=[
          "field lookup only sees fields declared by the resolved struct type",
        ],
        helps=[
          "check the field spelling or change the expression to a struct type that declares `\{field}`",
        ],
      )
    UnresolvedQualifiedVariant(type_name~, variant~) =>
      diagnostic(
        "cannot find variant `\{type_name}::\{variant}`",
        span~,
        severity=Error,
        code=Some("E2003"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "this enum type does not expose a variant named `\{variant}`",
            style: Primary,
          },
        ],
        notes=[
          "qualified variant lookup first resolves the enum type, then its variants",
        ],
        helps=[
          "check the variant spelling or use a variant declared by `\{type_name}`",
        ],
      )
    PayloadlessVariantCall(name) =>
      diagnostic(
        "payloadless variant `\{name}` is not callable",
        span~,
        severity=Error,
        code=Some("E2004"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "`\{name}` has no payload, so it is already a value",
            style: Primary,
          },
        ],
        notes=["only variants with payload fields are called with arguments"],
        helps=["remove the call syntax and use `\{name}` directly"],
      )
    ConflictingTopLevelValue(name~, existing~, incoming~) =>
      diagnostic(
        "conflicting top-level value `\{name}`",
        span~,
        severity=Error,
        code=Some("E2005"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "`\{incoming}` conflicts with an existing value named `\{existing}`",
            style: Primary,
          },
        ],
        notes=["a Lane module has one top-level value namespace"],
        helps=["rename one of the declarations or remove the duplicate import"],
      )
    AmbiguousModuleValue(name) =>
      diagnostic(
        "ambiguous module-qualified value `\{name}`",
        span~,
        severity=Error,
        code=Some("E2006"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "`\{name}` can refer to more than one imported value",
            style: Primary,
          },
        ],
        notes=[
          "Lane does not choose between ambiguous imports because doing so would make name resolution order-dependent",
        ],
        helps=[
          "import only one matching module or use a more specific module path before the value name",
        ],
      )
    AmbiguousUnqualifiedVariant(name~, candidates~) =>
      diagnostic(
        "ambiguous variant `\{name}`",
        span~,
        severity=Error,
        code=Some("E2007"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "`\{name}` matches more than one visible enum variant",
            style: Primary,
          },
        ],
        notes=["candidates: \{resolve_variant_candidates_text(candidates)}"],
        helps=[
          "qualify the variant with its enum type, for example `Enum::\{name}`",
        ],
      )
  }
}

///|
fn resolve_variant_candidates_text(
  candidates : Array[@resolve.ResolveVariantCandidate],
) -> String {
  candidates
  .map(fn(candidate) { "\{candidate.owner}::\{candidate.variant}" })
  .join(", ")
}

///|
fn typecheck_diagnostic(
  diagnostic_ : @typecheck.TypeCheckDiagnostic,
  display : TypeDisplayContext,
) -> CompileDiagnostic {
  let span = Some(diagnostic_.loc)
  match diagnostic_.kind {
    UnresolvedType(name) =>
      diagnostic(
        "cannot find type `\{name}`",
        span~,
        severity=Error,
        code=Some("E3000"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "type checking could not resolve `\{name}`",
            style: Primary,
          },
        ],
        notes=[
          "this name survived resolution but has no usable type declaration",
        ],
        helps=["declare the type or fix the import that should provide it"],
      )
    UnresolvedValue(name) =>
      diagnostic(
        "cannot find value `\{name}`",
        span~,
        severity=Error,
        code=Some("E3001"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "type checking could not resolve `\{name}`",
            style: Primary,
          },
        ],
        notes=[
          "this name survived resolution but has no usable value declaration",
        ],
        helps=["define the value or fix the import that should provide it"],
      )
    MissingTopLevelLetAnnotation =>
      diagnostic(
        "top-level `let` needs a type annotation",
        span~,
        severity=Error,
        code=Some("E3002"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "this compilation boundary cannot infer a top-level `let` type",
            style: Primary,
          },
        ],
        notes=[
          "Lane requires top-level `let` declarations to state their interface type explicitly",
        ],
        helps=["write the declaration as `let name : Type = expression`"],
      )
    TypeArgumentArityMismatch(name~, expected~, actual~) =>
      diagnostic(
        "wrong number of type arguments for `\{name}`",
        span~,
        severity=Error,
        code=Some("E3003"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "`\{name}` expects \{expected} type argument(s), but \{actual} were provided",
            style: Primary,
          },
        ],
        notes=[
          "type constructors and generic functions must be applied with their declared arity",
        ],
        helps=["add or remove type arguments so the count is \{expected}"],
      )
    TypeAliasCycle(name~) =>
      diagnostic(
        "type alias `\{name}` is recursive",
        span~,
        severity=Error,
        code=Some("E3004"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "`\{name}` expands back to itself",
            style: Primary,
          },
        ],
        notes=["Lane type aliases must be finite expansions"],
        helps=["break the cycle by introducing a nominal `struct` or `enum`"],
      )
    KindMismatch(expected~, actual~) =>
      diagnostic(
        "kind mismatch",
        span~,
        severity=Error,
        code=Some("E3005"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "expected kind `\{display.kind_text(expected)}`, found `\{display.kind_text(actual)}`",
            style: Primary,
          },
        ],
        notes=[
          "`Type` is the kind of value-level types; function kinds such as `[Type] -> Type` describe type constructors",
        ],
        helps=[
          "add the intended kind annotation or apply the type constructor to enough type arguments",
        ],
      )
    TypeMismatch(expected~, actual~) =>
      diagnostic(
        "type mismatch",
        span~,
        severity=Error,
        code=Some("E3006"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "expected `\{display.type_text(expected)}`, found `\{display.type_text(actual)}`",
            style: Primary,
          },
        ],
        notes=[
          "Lane does not insert implicit conversions between different types",
        ],
        helps=[
          "change the expression type or adjust the annotation/expected type",
        ],
      )
    EffectMismatch(expected~, actual~) =>
      diagnostic(
        "effect mismatch",
        span~,
        severity=Error,
        code=Some("E3007"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "expected effect `\{display.effect_text(expected)}`, found `\{display.effect_text(actual)}`",
            style: Primary,
          },
        ],
        notes=["Lane functions without an effect annotation are pure"],
        helps=[
          "add the required effect annotation or remove the effectful operation",
        ],
      )
    NotCallable(type_) =>
      diagnostic(
        "value is not callable",
        span~,
        severity=Error,
        code=Some("E3007"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "`\{display.type_text(type_)}` is not a function type",
            style: Primary,
          },
        ],
        notes=["only values with function type can be used in call position"],
        helps=["remove the call or use a function value here"],
      )
    UnknownField(name~) =>
      diagnostic(
        "unknown field `\{name}`",
        span~,
        severity=Error,
        code=Some("E3100"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "this struct does not have a visible field named `\{name}`",
            style: Primary,
          },
        ],
        notes=[
          "field names are checked against the resolved struct declaration",
        ],
        helps=["check the field spelling or update the struct declaration"],
      )
    MissingField(name~) =>
      diagnostic(
        "missing field `\{name}`",
        span~,
        severity=Error,
        code=Some("E3101"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "this struct construction or pattern omits required field `\{name}`",
            style: Primary,
          },
        ],
        notes=[
          "Lane struct literals and struct patterns must account for required fields",
        ],
        helps=["add a `\{name}: ...` field entry"],
      )
    DuplicateField(name~) =>
      diagnostic(
        "duplicate field `\{name}`",
        span~,
        severity=Error,
        code=Some("E3102"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "`\{name}` is provided more than once",
            style: Primary,
          },
        ],
        notes=["each struct field may appear at most once"],
        helps=["remove the duplicate field entry"],
      )
    UnknownTypeMember(name~) =>
      diagnostic(
        "unknown type member `\{name}`",
        span~,
        severity=Error,
        code=Some("E3103"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "this existential struct has no visible type member named `\{name}`",
            style: Primary,
          },
        ],
        notes=[
          "type members are checked against the resolved struct declaration",
        ],
        helps=[
          "check the type member spelling or update the struct declaration",
        ],
      )
    MissingTypeMember(name~) =>
      diagnostic(
        "missing type member `\{name}`",
        span~,
        severity=Error,
        code=Some("E3104"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "this existential struct value omits required type member `\{name}`",
            style: Primary,
          },
        ],
        notes=[
          "existential struct construction must provide witnesses for required type members",
        ],
        helps=["add a `type \{name} = ...` member entry"],
      )
    DuplicateTypeMember(name~) =>
      diagnostic(
        "duplicate type member `\{name}`",
        span~,
        severity=Error,
        code=Some("E3105"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "`\{name}` is provided more than once",
            style: Primary,
          },
        ],
        notes=["each type member may appear at most once"],
        helps=["remove the duplicate type member entry"],
      )
    DuplicateTypeParameter(name~) =>
      diagnostic(
        "duplicate type parameter `\{name}`",
        span~,
        severity=Error,
        code=Some("E3106"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "`\{name}` is bound more than once in the same parameter list",
            style: Primary,
          },
        ],
        notes=[
          "duplicate type parameter binders would make references ambiguous",
        ],
        helps=["rename one of the type parameters"],
      )
    NotAStruct(type_) =>
      diagnostic(
        "expected a struct type",
        span~,
        severity=Error,
        code=Some("E3008"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "`\{display.type_text(type_)}` is not a struct type",
            style: Primary,
          },
        ],
        notes=[
          "field access, struct literals, and struct patterns require a struct type",
        ],
        helps=[
          "use a struct value here or change the surrounding type annotation",
        ],
      )
    NonExhaustiveMatch(type_) =>
      diagnostic(
        "non-exhaustive match",
        span~,
        severity=Error,
        code=Some("E3200"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "patterns do not cover every `\{display.type_text(type_)}` value",
            style: Primary,
          },
        ],
        notes=["Lane checks match coverage statically using the pattern matrix"],
        helps=["add a missing constructor case or a final `_` wildcard arm"],
      )
    UnreachableMatchArm =>
      diagnostic(
        "unreachable match arm",
        span~,
        severity=Error,
        code=Some("E3201"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "this arm can never be selected",
            style: Primary,
          },
        ],
        notes=[
          "an earlier pattern already covers every value that would reach this arm",
        ],
        helps=["remove this arm or make the earlier patterns more specific"],
      )
    MixedHandlerEffects =>
      diagnostic(
        "handler block mixes effects",
        span~,
        severity=Error,
        code=Some("E3202"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "all operation arms in one `with` block must belong to the same effect",
            style: Primary,
          },
        ],
        notes=["Lane handlers group operation alternatives by concrete effect"],
        helps=[
          "split operations from different effects into separate `with` blocks",
        ],
      )
    DuplicateHandledEffect(effect) =>
      diagnostic(
        "duplicate handled effect",
        span~,
        severity=Error,
        code=Some("E3203"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "this handler already has a `with` block for `\{display.effect_text(effect)}`",
            style: Primary,
          },
        ],
        notes=["a handler expression may handle each concrete effect once"],
        helps=["merge these operation arms into the existing `with` block"],
      )
    MissingHandlerOperation(operation) =>
      diagnostic(
        "missing handler operation",
        span~,
        severity=Error,
        code=Some("E3204"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "this handler does not cover operation `operation#\{operation.index}`",
            style: Primary,
          },
        ],
        notes=[
          "every operation declared by a handled effect must have exhaustive handler arms",
        ],
        helps=["add an arm for the missing operation"],
      )
    DuplicatePatternBinder(name~) =>
      diagnostic(
        "duplicate pattern binder `\{name}`",
        span~,
        severity=Error,
        code=Some("E3202"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "`\{name}` is bound more than once in the same pattern",
            style: Primary,
          },
        ],
        notes=[
          "Lane patterns do not use repeated names as equality constraints",
        ],
        helps=["rename one binder or match the second position with `_`"],
      )
    PatternArityMismatch(name~, expected~, actual~) =>
      diagnostic(
        "wrong number of fields for pattern `\{name}`",
        span~,
        severity=Error,
        code=Some("E3203"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "`\{name}` expects \{expected} payload field(s), but \{actual} were provided",
            style: Primary,
          },
        ],
        notes=["constructor patterns must match the variant payload arity"],
        helps=["add or remove pattern arguments so the count is \{expected}"],
      )
    HiddenTypeEscape(type_~) =>
      diagnostic(
        "hidden existential type escapes its scope",
        span~,
        severity=Error,
        code=Some("E3107"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "this expression exposes hidden type `\{display.type_text(type_)}` outside its unpacking scope",
            style: Primary,
          },
        ],
        notes=[
          "existential witnesses must remain abstract outside the packed value",
        ],
        helps=["return a value whose type does not mention the hidden witness"],
      )
    PrivateTypeEscape(name~) =>
      diagnostic(
        "private type `\{name}` in public interface",
        span~,
        severity=Error,
        code=Some("E3108"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "public interface exposes private type `\{name}`",
            style: Primary,
          },
        ],
        notes=[
          "downstream modules need public type information to compile against this item",
        ],
        helps=[
          "make `\{name}` public or change the public signature to hide it",
        ],
      )
    InvalidIntLiteral(raw) =>
      diagnostic(
        "invalid integer literal `\{raw}`",
        span~,
        severity=Error,
        code=Some("E3009"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "`\{raw}` cannot be represented as a Lane `Int`",
            style: Primary,
          },
        ],
        notes=[
          "Lane `Int` literals must fit the compiler's supported integer range",
        ],
        helps=["use a smaller integer literal"],
      )
    CannotInferExpression(label) =>
      diagnostic(
        "cannot infer expression type",
        span~,
        severity=Error,
        code=Some("E3010"),
        labels=[
          {
            span: diagnostic_.loc,
            message: "the checker needs more type information for `\{label}`",
            style: Primary,
          },
        ],
        notes=[
          "this diagnostic is emitted when local context is not enough to choose a unique type",
        ],
        helps=[cannot_infer_help(label)],
      )
  }
}

///|
fn cannot_infer_help(label : String) -> String {
  if label.contains("contextual offer") {
    "add a visible `offer` with the required type or pass the contextual argument explicitly"
  } else if label.contains("function literal parameter") {
    "add an explicit parameter type annotation to the function literal"
  } else if label.contains("call arity") || label.contains("arity") {
    "check the number of arguments and type arguments at this call site"
  } else if label.contains("type arguments") {
    "add explicit type arguments or provide an expected result type"
  } else if label.contains("builtin") {
    "add a type annotation so the builtin can be checked against a concrete function type"
  } else {
    "add a type annotation near this expression"
  }
}

///|
fn lex_diagnostic(error : @lexer.LexError) -> CompileDiagnostic {
  let span = Some(error.span)
  diagnostic(
    lex_error_title(error.error),
    span~,
    severity=Error,
    code=Some(lex_error_code(error.error)),
    labels=[
      {
        span: error.span,
        message: lex_error_label(error.error),
        style: Primary,
      },
    ],
    notes=lex_error_notes(error.error),
    helps=lex_error_helps(error.error),
  )
}

///|
fn lex_error_code(error : @lexer.LexicalError) -> String {
  match error {
    IllegalCharacter(_) => "E1000"
    UnterminatedBlockComment => "E1001"
    UnterminatedString => "E1002"
    InvalidStringEscape(_) => "E1003"
    InvalidHexEscape(_) => "E1004"
    NonAsciiStringCharacter => "E1005"
  }
}

///|
fn lex_error_title(error : @lexer.LexicalError) -> String {
  match error {
    IllegalCharacter(_) => "illegal character in source"
    UnterminatedBlockComment => "unterminated block comment"
    UnterminatedString => "unterminated string literal"
    InvalidStringEscape(_) => "invalid string escape"
    InvalidHexEscape(_) => "invalid hexadecimal escape"
    NonAsciiStringCharacter => "non-ASCII character in string literal"
  }
}

///|
fn lex_error_label(error : @lexer.LexicalError) -> String {
  match error {
    IllegalCharacter(value) => "`\{value}` is not valid Lane syntax"
    UnterminatedBlockComment => "this block comment is never closed"
    UnterminatedString => "this string literal is never closed"
    InvalidStringEscape(value) =>
      "`\{value}` is not a supported escape sequence"
    InvalidHexEscape(value) => "`\{value}` is not a valid hexadecimal escape"
    NonAsciiStringCharacter =>
      "Lane string literals currently accept ASCII characters only"
  }
}

///|
fn lex_error_notes(error : @lexer.LexicalError) -> Array[String] {
  match error {
    NonAsciiStringCharacter =>
      [
        "the lexer rejects non-ASCII bytes inside string literals in the current language version",
      ]
    _ => []
  }
}

///|
fn lex_error_helps(error : @lexer.LexicalError) -> Array[String] {
  match error {
    IllegalCharacter(_) =>
      ["remove this character or replace it with a valid Lane token"]
    UnterminatedBlockComment => ["add a closing `*/` before the end of file"]
    UnterminatedString => ["add a closing `\"` before the end of the line"]
    InvalidStringEscape(_) =>
      ["use a supported escape such as `\\n`, `\\t`, `\\\"`, or `\\\\`"]
    InvalidHexEscape(_) =>
      ["write hexadecimal escapes with exactly two hexadecimal digits"]
    NonAsciiStringCharacter =>
      ["replace the character with ASCII text or an explicit supported escape"]
  }
}

///|
fn parse_diagnostic(error : @parser.ParseError) -> CompileDiagnostic {
  let span = Some(error.loc)
  diagnostic(
    parse_error_title(error.kind),
    span~,
    severity=Error,
    code=Some(parse_error_code(error.kind)),
    labels=[
      {
        span: error.loc,
        message: parse_error_label(error.kind),
        style: Primary,
      },
    ],
    notes=parse_error_notes(error.kind),
    helps=parse_error_helps(error.kind),
  )
}

///|
fn parse_error_code(error : @parser.ParseErrorKind) -> String {
  match error {
    UnexpectedToken(_, _) => "E1100"
    UnexpectedEndOfInput(_) => "E1101"
  }
}

///|
fn parse_error_title(error : @parser.ParseErrorKind) -> String {
  match error {
    UnexpectedToken(_, _) => "unexpected token"
    UnexpectedEndOfInput(_) => "unexpected end of input"
  }
}

///|
fn parse_error_label(error : @parser.ParseErrorKind) -> String {
  match error {
    UnexpectedToken(token, _) => "the parser did not expect \{token.label}"
    UnexpectedEndOfInput(_) =>
      "the source file ended while parsing this construct"
  }
}

///|
fn parse_error_notes(error : @parser.ParseErrorKind) -> Array[String] {
  match error {
    UnexpectedToken(_, expected) | UnexpectedEndOfInput(expected) =>
      if expected.is_empty() {
        []
      } else {
        ["expected one of: \{expected_list(expected)}"]
      }
  }
}

///|
fn parse_error_helps(error : @parser.ParseErrorKind) -> Array[String] {
  match error {
    UnexpectedToken(_, expected) =>
      if expected.is_empty() {
        ["remove the unexpected token or rewrite the surrounding expression"]
      } else {
        [
          "rewrite this position so it starts with one of: \{expected_list(expected)}",
        ]
      }
    UnexpectedEndOfInput(expected) =>
      if expected.is_empty() {
        ["finish the incomplete construct before the end of file"]
      } else {
        [
          "add the missing syntax before the end of file; expected one of: \{expected_list(expected)}",
        ]
      }
  }
}

///|
fn expected_list(expected : Array[@parser.ExpectedSyntax]) -> String {
  expected.map(fn(item) { item.label }).join(", ")
}

///|
fn span_text(span : @basic.SourceSpan) -> String {
  "\{span.start_line}:\{span.start_column}-\{span.end_line}:\{span.end_column}"
}

///|
pub impl @prettyprinter.Pretty for CompileDiagnostic with fn pretty(
  diagnostic : CompileDiagnostic,
) -> Document {
  let header = diagnostic.header_doc()
  let body = diagnostic.body_doc()
  if body is Some(body) {
    header + line + body
  } else {
    header
  }
}

///|
fn CompileDiagnostic::header_doc(self : CompileDiagnostic) -> Document {
  self.severity.to_doc() +
  self.code_doc() +
  text(":") +
  space +
  text(self.message)
}

///|
fn CompileDiagnosticSeverity::to_doc(
  self : CompileDiagnosticSeverity,
) -> Document {
  match self {
    Error => text("error")
    Warning => text("warning")
  }
}

///|
fn CompileDiagnostic::code_doc(self : CompileDiagnostic) -> Document {
  match self.code {
    Some(code) => text("[") + text(code) + text("]")
    None => text("")
  }
}

///|
fn CompileDiagnostic::body_doc(self : CompileDiagnostic) -> Document? {
  let docs : Array[Document] = []
  match self.span {
    Some(span) => docs.push(text("  -->") + space + text(span_text(span)))
    None => ()
  }
  for label in self.labels {
    docs.push(label.to_doc())
  }
  for note in self.notes {
    docs.push(text("  = note:") + space + text(note))
  }
  for help in self.helps {
    docs.push(text("  = help:") + space + text(help))
  }
  if docs.is_empty() {
    None
  } else {
    Some(separate(line, docs))
  }
}

///|
fn CompileDiagnosticLabel::to_doc(self : CompileDiagnosticLabel) -> Document {
  let prefix = match self.style {
    Primary => text("  = label:")
    Secondary => text("  = note:")
  }
  prefix + space + text(span_text(self.span)) + space + text(self.message)
}

///|
pub impl @prettyprinter.Pretty for CheckResult with fn pretty(
  result : CheckResult,
) -> Document {
  CompileDiagnostic::list_doc(result.diagnostics)
}

///|
pub impl @prettyprinter.Pretty for CompileResult with fn pretty(
  result : CompileResult,
) -> Document {
  CompileDiagnostic::list_doc(result.diagnostics)
}

///|
fn CompileDiagnostic::list_doc(
  diagnostics : Array[CompileDiagnostic],
) -> Document {
  if diagnostics.is_empty() {
    text("diagnostics") + space + text("{}")
  } else {
    text("diagnostics") +
    space +
    separate(line, diagnostics.map(CompileDiagnostic::pretty))
  }
}
