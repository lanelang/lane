///|
pub impl @compiler_diag.ToCompilerDiagnostic for ResolveDiagnostic with fn to_compiler_diagnostic(
  diagnostic : ResolveDiagnostic,
  context : @compiler_diag.DiagnosticContext,
) -> @compiler_diag.CompilerDiagnostic {
  let span = Some(diagnostic.loc)
  match diagnostic.kind {
    UnresolvedType(name) =>
      @compiler_diag.compiler_error(
        "cannot find type `\{name}`",
        span~,
        code=Some("E2000"),
        labels=[
          @compiler_diag.compiler_primary_label(
            diagnostic.loc,
            "no type named `\{name}` is visible here",
          ),
        ],
        notes=[
          "Lane resolves type names from the current module and explicitly imported public types",
        ],
        helps=[
          "declare `\{name}`, import the module that exports it, or qualify the type as `Module.\{name}`",
        ],
        context~,
      )
    UnresolvedValue(name) =>
      @compiler_diag.compiler_error(
        "cannot find value `\{name}`",
        span~,
        code=Some("E2001"),
        labels=[
          @compiler_diag.compiler_primary_label(
            diagnostic.loc,
            "no value named `\{name}` is visible here",
          ),
        ],
        notes=[
          "Lane value lookup uses local bindings, top-level values, and explicitly imported public values",
        ],
        helps=[
          "define `\{name}` before this use, import it, or qualify it with its module path",
        ],
        context~,
      )
    UnresolvedEffectOperation(name) =>
      @compiler_diag.compiler_error(
        "cannot find effect operation `\{name}`",
        span~,
        code=Some("E2011"),
        labels=[
          @compiler_diag.compiler_primary_label(
            diagnostic.loc,
            "no effect operation named `\{name}` is visible here",
          ),
        ],
        notes=[
          "unqualified operation calls search the operation namespace, not ordinary values",
        ],
        helps=[
          "define the operation on an effect or call an existing operation with `Effect::\{name}!`",
        ],
        context~,
      )
    UnresolvedField(type_name~, field~) =>
      @compiler_diag.compiler_error(
        "cannot find field `\{field}` on `\{type_name}`",
        span~,
        code=Some("E2002"),
        labels=[
          @compiler_diag.compiler_primary_label(
            diagnostic.loc,
            "`\{type_name}` has no visible field named `\{field}`",
          ),
        ],
        notes=[
          "field lookup only sees fields declared by the resolved struct type",
        ],
        helps=[
          "check the field spelling or change the expression to a struct type that declares `\{field}`",
        ],
        context~,
      )
    UnresolvedQualifiedVariant(type_name~, variant~) =>
      @compiler_diag.compiler_error(
        "cannot find variant `\{type_name}::\{variant}`",
        span~,
        code=Some("E2003"),
        labels=[
          @compiler_diag.compiler_primary_label(
            diagnostic.loc,
            "this enum type does not expose a variant named `\{variant}`",
          ),
        ],
        notes=[
          "qualified variant lookup first resolves the enum type, then its variants",
        ],
        helps=[
          "check the variant spelling or use a variant declared by `\{type_name}`",
        ],
        context~,
      )
    UnresolvedImportItem(module_path~, name~) =>
      @compiler_diag.compiler_error(
        "cannot import `\{name}` from `\{module_path}`",
        span~,
        code=Some("E2009"),
        labels=[
          @compiler_diag.compiler_primary_label(
            diagnostic.loc,
            "`\{module_path}` has no exported declaration named `\{name}`",
          ),
        ],
        notes=[
          "selective imports can name only top-level declarations exported by the imported module",
        ],
        helps=[
          "check the name spelling or select a declaration exported by `\{module_path}`",
        ],
        context~,
      )
    PayloadlessVariantWithoutParens(name) =>
      @compiler_diag.compiler_error(
        "payloadless variant `\{name}` must use empty parentheses",
        span~,
        code=Some("E2004"),
        labels=[
          @compiler_diag.compiler_primary_label(
            diagnostic.loc,
            "`\{name}` has no payload, so construct it as `\{name}()`",
          ),
        ],
        notes=["all enum variant constructors use parentheses in expressions"],
        helps=["add empty parentheses: `\{name}()`"],
        context~,
      )
    ConflictingTopLevelValue(
      name~,
      existing~,
      incoming~,
      existing_source_id~,
      existing_loc~,
      existing_origin~
    ) => {
      let labels = [
        @compiler_diag.compiler_primary_label(
          diagnostic.loc,
          "`\{incoming}` conflicts with an existing value named `\{existing}`",
        ),
      ]
      if existing_loc is Some(existing_loc) {
        let span = match existing_source_id {
          Some(source_id) =>
            @compiler_diag.compiler_source_span(source_id, existing_loc)
          None => @compiler_diag.compiler_local_span(existing_loc)
        }
        labels.push({
          span,
          message: "previous definition of `\{existing}` is here",
          style: Secondary,
        })
      }
      let notes = ["a Lane module has one top-level value namespace"]
      if existing_loc is None {
        if existing_origin is Some(origin) {
          notes.push("previous definition comes from \{origin}")
        }
      }
      @compiler_diag.compiler_error(
        "conflicting top-level value `\{name}`",
        span~,
        code=Some("E2005"),
        labels~,
        notes~,
        helps=["rename one of the declarations or remove the duplicate import"],
        context~,
      )
    }
    ConflictingTopLevelTypeAndEffectName(name~, type_kind~, effect_kind~) =>
      @compiler_diag.compiler_error(
        "conflicting top-level type/effect name `\{name}`",
        span~,
        code=Some("E2007"),
        labels=[
          @compiler_diag.compiler_primary_label(
            diagnostic.loc,
            "this `\{effect_kind}` name overlaps with a `\{type_kind}` name",
          ),
        ],
        notes=[
          "Lane keeps effect declarations and type/type-alias declarations in distinct namespaces, but their names cannot overlap",
        ],
        helps=["rename either the effect or the type/type alias"],
        context~,
      )
    AmbiguousModuleBinding(name~, existing_loc~) =>
      @compiler_diag.compiler_error(
        "ambiguous module binding `\{name}`",
        span~,
        code=Some("E2008"),
        labels=[
          @compiler_diag.compiler_primary_label(
            diagnostic.loc,
            "this import also binds `\{name}`",
          ),
          @compiler_diag.compiler_secondary_label(
            existing_loc,
            "`\{name}` was first bound here",
          ),
        ],
        notes=[
          "Lane module bindings do not shadow one another or use import-order priority",
        ],
        helps=["choose a distinct alias or remove one of the imports"],
        context~,
      )
    AmbiguousModuleValue(name) =>
      @compiler_diag.compiler_error(
        "ambiguous module-qualified value `\{name}`",
        span~,
        code=Some("E2006"),
        labels=[
          @compiler_diag.compiler_primary_label(
            diagnostic.loc,
            "`\{name}` can refer to more than one imported value",
          ),
        ],
        notes=[
          "Lane does not choose between ambiguous imports because doing so would make name resolution order-dependent",
        ],
        helps=[
          "import only one matching module or use a more specific module path before the value name",
        ],
        context~,
      )
    AmbiguousUnqualifiedVariant(name~, candidates~) =>
      @compiler_diag.compiler_error(
        "ambiguous variant `\{name}`",
        span~,
        code=Some("E2010"),
        labels=[
          @compiler_diag.compiler_primary_label(
            diagnostic.loc,
            "`\{name}` matches more than one visible enum variant",
          ),
        ],
        notes=["candidates: \{resolve_variant_candidates_text(candidates)}"],
        helps=[
          "qualify the variant with its enum type, for example `Enum::\{name}`",
        ],
        context~,
      )
  }
}

///|
fn resolve_variant_candidates_text(
  candidates : Array[ResolveVariantCandidate],
) -> String {
  candidates
  .map(fn(candidate) { "\{candidate.owner}::\{candidate.variant}" })
  .join(", ")
}

///|
fn Resolver::report_type_effect_conflict_if_effect_exists(
  self : Resolver,
  name : String,
  type_kind : String,
  loc : SourceSpan,
) -> Unit {
  if self.effect_binding(name) is Some(_) {
    self.report(
      ConflictingTopLevelTypeAndEffectName(
        name~,
        type_kind~,
        effect_kind="effect",
      ),
      loc,
    )
  }
}

///|
fn Resolver::report_effect_type_conflict_if_type_exists(
  self : Resolver,
  name : String,
  loc : SourceSpan,
) -> Unit {
  if self.type_binding(name) is Some(_) {
    self.report(
      ConflictingTopLevelTypeAndEffectName(
        name~,
        type_kind="type",
        effect_kind="effect",
      ),
      loc,
    )
  } else if self.type_alias_binding(name) is Some(_) {
    self.report(
      ConflictingTopLevelTypeAndEffectName(
        name~,
        type_kind="type alias",
        effect_kind="effect",
      ),
      loc,
    )
  }
}

///|
fn UnqualifiedNameUse::report_payloadless_variant_without_parens(
  self : UnqualifiedNameUse,
  resolver : Resolver,
  symbol : VariantSymbolId,
  name : String,
) -> Unit {
  guard self is BareUse(_) else { return }
  guard resolver.registry.variant_metadata(symbol) is Some(metadata) else {
    return
  }
  if metadata.payload_count == 0 {
    resolver.report(PayloadlessVariantWithoutParens(name), self.loc())
  }
}

///|
fn Resolver::report_conflicting_top_level_value(
  self : Resolver,
  incoming : ValueBinding,
  existing : ValueBinding,
  loc : SourceSpan,
) -> Unit {
  self.conflicting_top_value_names.push(incoming.name)
  self.report(
    ConflictingTopLevelValue(
      name=incoming.name,
      existing=self.binding_display(existing),
      incoming=self.binding_display(incoming),
      existing_source_id=binding_source_id(existing),
      existing_loc=self.binding_loc(existing),
      existing_origin=binding_origin(existing),
    ),
    loc,
  )
}

///|
fn Resolver::binding_display(self : Resolver, binding : ValueBinding) -> String {
  match binding.reference {
    Symbol(symbol) =>
      match self.registry.value_metadata(symbol) {
        Some(metadata) => metadata.name
        None => binding.name
      }
    Unresolved(name) => name
  }
}

///|
fn binding_source_id(binding : ValueBinding) -> String? {
  match binding.source {
    ExternalSource(source_id~) => Some(source_id)
    _ => None
  }
}

///|
fn Resolver::binding_loc(
  self : Resolver,
  binding : ValueBinding,
) -> SourceSpan? {
  match binding.source {
    NoSource(_) => None
    _ =>
      match binding.reference {
        Symbol(symbol) =>
          match self.registry.value_metadata(symbol) {
            Some(metadata) => Some(metadata.loc)
            None => None
          }
        Unresolved(_) => None
      }
  }
}

///|
fn binding_origin(binding : ValueBinding) -> String? {
  match binding.source {
    NoSource(origin~) => Some(origin)
    _ => None
  }
}

///|
fn Resolver::report(
  self : Resolver,
  kind : ResolveDiagnosticKind,
  loc : SourceSpan,
) -> Unit {
  self.diagnostics.push({ kind, loc })
}

///|
fn Resolver::report_unresolved_value(
  self : Resolver,
  reference : ResolvedValueReference,
  loc : SourceSpan,
) -> Unit {
  match reference {
    Symbol(_) => ()
    Unresolved(name) => self.report(UnresolvedValue(name), loc)
  }
}

///|
fn Resolver::report_unresolved_field(
  self : Resolver,
  owner : TypeSymbolId,
  field : String,
  loc : SourceSpan,
) -> Unit {
  let type_name = match self.registry.type_metadata(owner) {
    Some(metadata) => metadata.name
    None => "<unknown>"
  }
  self.report(UnresolvedField(type_name~, field~), loc)
}

///|
fn resolver_report_qualified_variant(
  resolver : Resolver,
  type_name : String,
  variant : String,
  loc : SourceSpan,
) -> Unit {
  resolver.report(UnresolvedQualifiedVariant(type_name~, variant~), loc)
}
