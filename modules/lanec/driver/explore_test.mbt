///|
test "explore exposes the complete executable lowering pipeline" {
  let report = explore({
    root_source: {
      source_id: "Main.lane",
      text: (
        #|module Main
        #|pub fn main() -> Unit {
        #|  ()
        #|}
      ),
    },
    library_sources: [],
    entry: "main",
  })
  debug_inspect(
    (report.stages.map(stage => stage.id), report.diagnostics, report.failure),
    content=(
      #|(
      #|  [
      #|    "syntax",
      #|    "resolved",
      #|    "checked",
      #|    "buslane.module",
      #|    "buslane.linked",
      #|    "buslane.effect-specialized",
      #|    "buslane.handlers-elaborated",
      #|    "buslane.monadic",
      #|    "buslane.selective-cps",
      #|    "buslane.open-context-resolved",
      #|    "buslane.monadic-lifted",
      #|    "buslane.core-optimized",
      #|    "buslane.effects-erased",
      #|    "executable",
      #|    "anf",
      #|    "vmcfg.initial",
      #|    "loisvm.bytecode",
      #|    "wasm",
      #|  ],
      #|  [],
      #|  None,
      #|)
    ),
  )
}
