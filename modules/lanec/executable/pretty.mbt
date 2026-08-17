///|
using @prettyprinter {type Document, space, string, text}

///|
pub impl @prettyprinter.Pretty for ExecutableProgram with fn pretty(
  executable : ExecutableProgram,
) {
  text("executable") +
  space +
  @lanec_pretty.braced_block([
    executable_entry_doc(executable.entry),
    executable_externals_doc(executable.externals),
    executable_order_doc(
      executable.program,
      executable.initializer_roots,
      executable.entry.value,
    ),
    @lanec_pretty.section("program", [executable.program.pretty()]),
  ])
}

///|
fn executable_entry_doc(entry : @buslane_lowering.BuslaneEntry) -> Document {
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
  entry.type_.pretty()
}

///|
fn executable_externals_doc(
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
    external.type_().pretty()
  })
  docs.append(
    externals.runtime_imports.map(external => {
      text("runtime_import") +
      space +
      string(external.symbol) +
      space +
      text("as") +
      space +
      external.value.pretty() +
      space +
      text(":") +
      space +
      external.type_.pretty()
    }),
  )
  @lanec_pretty.section("externals", docs)
}

///|
fn executable_order_doc(
  program : @buslane.Program,
  initializer_roots : Array[@buslane.ValueId],
  entry : @buslane.ValueId,
) -> Document {
  let steps = []
  for term in program.terms {
    match term {
      Let(value, _) =>
        if initializer_roots.any(root => root == value) {
          steps.push(text("initialize") + space + value.pretty())
        }
      LetRec(bindings) => {
        let values = bindings.filter_map(binding => {
          if initializer_roots.any(root => root == binding.id) {
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
