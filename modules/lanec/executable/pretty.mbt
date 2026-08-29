///|
using @prettyprinter {type Document, space, string, text}

///|
pub impl @prettyprinter.Pretty for ExecutableProgram with fn pretty(
  executable : ExecutableProgram,
) {
  text("executable") +
  space +
  @lanec_pretty.braced_block([
    executable_entry_doc(
      executable.program.program().metadata,
      executable.entry,
    ),
    executable_externals_doc(
      executable.program.program().metadata,
      executable.externals,
    ),
    executable_order_doc(
      executable.program.program(),
      executable.retained_values,
      executable.entry.value,
    ),
    @lanec_pretty.section("program", [executable.program.program().pretty()]),
  ])
}

///|
fn executable_entry_doc(
  metadata : @buslane.MetadataRegistry,
  entry : @buslane_lowering.BuslaneEntry,
) -> Document {
  text("entry") +
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
  entry : @buslane.ValueId,
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
  steps.push(text("entry") + space + entry.pretty())
  @lanec_pretty.section("execution_order", steps)
}
