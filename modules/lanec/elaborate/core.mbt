///|
pub(all) struct ElaborateResult {
  source : @checked.CheckedSourceFile?
  diagnostics : Array[@typecheck.TypeCheckDiagnostic]
} derive(Debug, Eq)

///|
pub(all) struct AnfElaborateResult {
  program : @anf.BuslaneAnfProgram?
  diagnostics : Array[@typecheck.TypeCheckDiagnostic]
} derive(Debug, Eq)

///|
pub(all) struct BuslaneElaborateResult {
  program : @buslane.Program?
  diagnostics : Array[@typecheck.TypeCheckDiagnostic]
} derive(Debug, Eq)

///|
pub(all) struct BuslaneBuiltinExternal {
  value : @buslane.ValueId
  name : String
  type_ : @buslane.Type
} derive(Debug, Eq, FromJson, ToJson)

///|
pub(all) struct BuslaneExternalMap {
  builtins : Array[BuslaneBuiltinExternal]
} derive(Debug, Eq, FromJson, ToJson)

///|
pub(all) struct BuslaneEntry {
  name : String
  value : @buslane.ValueId
  type_ : @buslane.Type
} derive(Debug, Eq, FromJson, ToJson)

///|
pub(all) enum BuslaneModuleExportKind {
  Type
  DataConstructor
  FieldSelector
  Value
} derive(Debug, Eq, FromJson, ToJson)

///|
pub(all) struct BuslaneModuleExport {
  kind : BuslaneModuleExportKind
  name : String
  type_id : @buslane.TypeId?
  data_constructor : @buslane.DataConId?
  value : @buslane.ValueId?
} derive(Debug, Eq, FromJson, ToJson)

///|
pub(all) struct BuslaneModuleImport {
  module_path_text : String
  kind : BuslaneModuleExportKind
  name : String
  type_id : @buslane.TypeId?
  data_constructor : @buslane.DataConId?
  value : @buslane.ValueId?
} derive(Debug, Eq, FromJson, ToJson)

///|
pub(all) struct BuslaneLowerResult {
  program : @buslane.Program
  externals : BuslaneExternalMap
  entries : Array[BuslaneEntry]
} derive(Debug, Eq, FromJson, ToJson)

///|
pub(all) struct BuslaneModuleObject {
  module_path_text : String
  metadata : @buslane.MetadataRegistry
  terms : Array[@buslane.TopTerm]
  externals : BuslaneExternalMap
  entries : Array[BuslaneEntry]
  exports : Array[BuslaneModuleExport]
  imports : Array[BuslaneModuleImport]
} derive(Debug, Eq, FromJson, ToJson)

///|
pub(all) struct BuslaneModuleObjectSet {
  objects : Array[BuslaneModuleObject]
} derive(Debug, Eq, FromJson, ToJson)

///|
/// Elaborates a resolved source file into Checked Source AST when type checking
/// succeeds and all checked-source nodes required by the file are implemented.
pub fn elaborate_resolved_source_file(
  source : @resolve.ResolvedSourceFile,
) -> ElaborateResult {
  let result = @typecheck.typecheck_checked_source_file(source)
  { source: result.source, diagnostics: result.diagnostics }
}

///|
/// Elaborates a resolved source file into Buslane Core Language when Checked
/// Source construction succeeds.
pub fn elaborate_resolved_source_file_to_buslane(
  source : @resolve.ResolvedSourceFile,
) -> BuslaneElaborateResult {
  let result = @typecheck.typecheck_checked_source_file(source)
  let program = match result.source {
    Some(source) => Some(lower_checked_source_file_to_buslane(source))
    None => None
  }
  { program, diagnostics: result.diagnostics }
}

///|
/// Elaborates a resolved source file into ANF IR through Buslane Core Language
/// when Checked Source construction succeeds.
pub fn elaborate_resolved_source_file_to_anf(
  source : @resolve.ResolvedSourceFile,
) -> AnfElaborateResult {
  let result = @typecheck.typecheck_checked_source_file(source)
  let program = match result.source {
    Some(source) =>
      Some(
        @anf.lower_buslane_program_to_anf(
          lower_checked_source_file_to_buslane(source),
        ),
      )
    None => None
  }
  { program, diagnostics: result.diagnostics }
}

///|
pub impl @prettyprinter.Pretty for ElaborateResult with fn pretty(
  result : ElaborateResult,
) {
  let source = match result.source {
    Some(source) => source.pretty()
    None => text("<no checked source>")
  }
  text("elaborate_result") +
  space +
  @pretty.braced_block([
    source,
    @pretty.section(
      "diagnostics",
      result.diagnostics.map(@typecheck.TypeCheckDiagnostic::pretty),
    ),
  ])
}

///|
pub impl @prettyprinter.Pretty for BuslaneElaborateResult with fn pretty(
  result : BuslaneElaborateResult,
) {
  let program = match result.program {
    Some(program) => program.pretty()
    None => text("<no buslane program>")
  }
  text("buslane_elaborate_result") +
  space +
  @pretty.braced_block([
    program,
    @pretty.section(
      "diagnostics",
      result.diagnostics.map(@typecheck.TypeCheckDiagnostic::pretty),
    ),
  ])
}

///|
pub impl @prettyprinter.Pretty for AnfElaborateResult with fn pretty(
  result : AnfElaborateResult,
) {
  let program = match result.program {
    Some(program) => program.pretty()
    None => text("<no anf program>")
  }
  text("anf_elaborate_result") +
  space +
  @pretty.braced_block([
    program,
    @pretty.section(
      "diagnostics",
      result.diagnostics.map(@typecheck.TypeCheckDiagnostic::pretty),
    ),
  ])
}
