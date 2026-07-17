///|
using @prettyprinter {type Document, space, string, text}

///|
pub impl @prettyprinter.Pretty for ExecutableProgram with fn pretty(
  executable : ExecutableProgram,
) {
  text("executable") +
  space +
  @lanec_pretty.braced_block([
    executable_modules_doc(executable.module_path_texts),
    executable_entry_doc(executable.entry),
    executable_externals_doc(executable.externals),
    executable_initializers_doc(executable.initializers),
    executable_roots_doc(executable.execution_roots),
    executable_companions_doc(executable.effect_companions),
    @lanec_pretty.section("program", [executable.program.pretty()]),
  ])
}

///|
fn executable_modules_doc(module_path_texts : Array[String]) -> Document {
  @lanec_pretty.section("modules", module_path_texts.map(text))
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
    string(external.name) +
    space +
    text("as") +
    space +
    external.value.pretty() +
    space +
    text(":") +
    space +
    external.type_.pretty()
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
fn executable_initializers_doc(
  initializers : Array[TopLevelInitializer],
) -> Document {
  @lanec_pretty.section(
    "initializers",
    initializers.mapi((index, initializer) => {
      let target = match initializer {
        Value(value, _) => value.pretty()
        Recursive(bindings) =>
          text("letrec") +
          space +
          @lanec_pretty.bracketed_inline(
            bindings.map(binding => binding.id.pretty()),
          )
      }
      text("init#\{index}") + space + text("=") + space + target
    }),
  )
}

///|
fn executable_roots_doc(roots : Array[ExecutionRoot]) -> Document {
  @lanec_pretty.section(
    "execution_order",
    roots.map(root => {
      match root {
        Initializer(index) => text("init#\{index}")
        Entry(value) => text("entry") + space + value.pretty()
      }
    }),
  )
}

///|
fn executable_companions_doc(
  companions : Array[@effect_lowering_cps.EffectCompanionBinding],
) -> Document {
  @lanec_pretty.section(
    "effect_companions",
    companions.map(companion => {
      companion.source.pretty() +
      space +
      text("=>") +
      space +
      companion.companion.pretty()
    }),
  )
}
