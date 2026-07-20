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
    (
      report.stages.map(stage => {
        (stage.id, stage.text.split("\n").collect()[0].to_owned())
      }),
      report.diagnostics,
      report.failure,
    ),
    content=(
      #|(
      #|  [
      #|    ("syntax", "module Main"),
      #|    ("resolved", "fn value#0 main() -> Unit {"),
      #|    ("checked", "fn main#0() -> Unit {"),
      #|    ("buslane.module", "letrec {"),
      #|    ("buslane.linked", "letrec {"),
      #|    ("buslane.effect-specialized", "letrec {"),
      #|    ("buslane.handlers-elaborated", "letrec {"),
      #|    ("buslane.monadic", "letrec {"),
      #|    ("buslane.selective-cps", "letrec {"),
      #|    ("buslane.open-context-resolved", "letrec {"),
      #|    ("buslane.monadic-lifted", "letrec {"),
      #|    ("buslane.core-optimized", "letrec {"),
      #|    ("buslane.effects-erased", "letrec {"),
      #|    ("executable", "letrec {"),
      #|    ("anf", "letrec {"),
      #|    ("vmcfg.initial", "function f1("),
      #|    ("loisvm.bytecode", "function f1("),
      #|    ("wasm", "(module"),
      #|  ],
      #|  [],
      #|  None,
      #|)
    ),
  )
}
