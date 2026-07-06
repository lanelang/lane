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
        code=Some("E2007"),
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
