///|
using @prettyprinter {type Document, space, string, text}

///|
pub impl @prettyprinter.Pretty for ExecutableProgram with fn pretty(
  executable : ExecutableProgram,
) {
  let program = executable.cps_core.program().program()
  text("executable") +
  space +
  @lanec_pretty.braced_block([
    @lanec_pretty.section(
      "exports",
      executable.exports.map(export_ => {
        executable_export_doc(program.metadata, export_)
      }),
    ),
    executable_externals_doc(program.metadata, executable.externals),
    executable_order_doc(
      program,
      executable.retained_values,
      executable.exports,
    ),
    @lanec_pretty.section("program", [program.pretty()]),
  ])
}

///|
fn executable_export_doc(
  metadata : @buslane.MetadataRegistry,
  export_ : ExecutableExport,
) -> Document {
  let entry = export_.entry()
  text(export_.name()) +
  space +
  text(entry.module_path_text) +
  text(".") +
  text(entry.name) +
  space +
  text("=") +
  space +
  entry.value.pretty() +
  space +
  text(":") +
  space +
  source_type_doc(metadata, entry.value)
}

///|
fn executable_externals_doc(
  metadata : @buslane.MetadataRegistry,
  externals : @buslane_lowering.BuslaneExternalMap,
) -> Document {
  let docs = externals.builtins.map(external => {
    text("builtin") +
    space +
    string(external.intrinsic().name()) +
    space +
    text("as") +
    space +
    external.value().pretty() +
    space +
    text(":") +
    space +
    source_type_doc(metadata, external.value())
  })
  docs.append(
    externals.runtime_imports.map(external => {
      text("runtime_import") +
      space +
      string(external.contract.module_name) +
      text(".") +
      string(external.contract.field_name) +
      space +
      text("as") +
      space +
      external.value.pretty() +
      space +
      text(":") +
      space +
      source_type_doc(metadata, external.value)
    }),
  )
  @lanec_pretty.section("externals", docs)
}

///|
fn source_type_doc(
  metadata : @buslane.MetadataRegistry,
  value : @buslane.ValueId,
) -> Document {
  @buslane_lowering.source_value_type(metadata, value).pretty() catch {
    MissingValueMetadata(_) => text("<missing value metadata>")
  }
}

///|
fn executable_order_doc(
  program : @buslane.Program,
  retained_values : Array[@buslane.ValueId],
  exports : Array[ExecutableExport],
) -> Document {
  let steps = []
  for term in program.terms {
    match term {
      Let(value, expression) =>
        if retained_values.contains(value) &&
          !is_static_top_level_expression(program, expression) {
          steps.push(text("initialize") + space + value.pretty())
        }
      LetRec(bindings) => {
        let values = bindings.filter_map(binding => {
          if retained_values.contains(binding.id) &&
            !is_static_top_level_expression(program, binding.rhs) {
            Some(binding.id.pretty())
          } else {
            None
          }
        })
        if !values.is_empty() {
          steps.push(
            text("initialize") +
            space +
            text("letrec") +
            space +
            @lanec_pretty.bracketed_inline(values),
          )
        }
      }
      External(_) => ()
    }
  }
  for export_ in exports {
    steps.push(
      text("export") +
      space +
      string(export_.name()) +
      space +
      export_.entry().value.pretty(),
    )
  }
  @lanec_pretty.section("execution_order", steps)
}
