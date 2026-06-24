///|
fn checked_source_from_module_graph(
  graph : ModuleGraph,
) -> Result[@checked.CheckedSourceFile, Array[CompileDiagnostic]] {
  let source = legacy_single_source_from_module_graph(graph)
  checked_source(source)
}

///|
/// Temporary bridge for the old single-source resolver and typechecker.
fn legacy_single_source_from_module_graph(
  graph : ModuleGraph,
) -> @syntax.SourceFile {
  let declarations = []
  guard graph.modules.last() is Some(root) else {
    return @syntax.SourceFile::{
      module_path: @syntax.ModulePath::{
        components: ["<empty>"],
        loc: @basic.SourceSpan::dummy(),
      },
      imports: [],
      declarations,
      loc: @basic.SourceSpan::dummy(),
    }
  }
  for module_ in graph.modules {
    let keep_public = module_.path == graph.root_path
    for declaration in module_.source.declarations {
      declarations.push(declaration_with_public(declaration, keep_public))
    }
  }
  {
    module_path: root.source.module_path,
    imports: [],
    declarations,
    loc: root.source.loc,
  }
}

///|
fn declaration_with_public(
  declaration : @syntax.TopLevelDeclaration,
  keep_public : Bool,
) -> @syntax.TopLevelDeclaration {
  match declaration {
    Struct(declaration) =>
      Struct({ ..declaration, is_public: keep_public && declaration.is_public })
    Enum(declaration) =>
      Enum({ ..declaration, is_public: keep_public && declaration.is_public })
    TypeAlias(declaration) =>
      TypeAlias({
        ..declaration,
        is_public: keep_public && declaration.is_public,
      })
    Function(declaration) =>
      Function({
        ..declaration,
        is_public: keep_public && declaration.is_public,
      })
    Let(declaration) =>
      Let({ ..declaration, is_public: keep_public && declaration.is_public })
    Offer(declaration) =>
      Offer({ ..declaration, is_public: keep_public && declaration.is_public })
  }
}

///|
fn checked_source(
  source : @syntax.SourceFile,
) -> Result[@checked.CheckedSourceFile, Array[CompileDiagnostic]] {
  let resolved = @resolve.resolve_source_file_result(source)
  checked_resolved_source(resolved)
}

///|
fn checked_resolved_source(
  resolved : @resolve.ResolveResult,
) -> Result[@checked.CheckedSourceFile, Array[CompileDiagnostic]] {
  let resolve_diagnostics = resolved.diagnostics.map(fn(diagnostic) {
    make_error(
      @prettyprinter.render(diagnostic.kind, width=100),
      span=Some(diagnostic.loc),
    )
  })
  if !resolve_diagnostics.is_empty() {
    return Err(resolve_diagnostics)
  }
  let checked = @typecheck.typecheck_checked_source_file(resolved.source)
  let typecheck_diagnostics = checked.diagnostics.map(fn(diagnostic) {
    make_error(
      @prettyprinter.render(diagnostic.kind, width=100),
      span=Some(diagnostic.loc),
    )
  })
  if !typecheck_diagnostics.is_empty() {
    return Err(typecheck_diagnostics)
  }
  match checked.source {
    Some(source) => Ok(source)
    None => Err([make_error("checked source construction failed", span=None)])
  }
}
