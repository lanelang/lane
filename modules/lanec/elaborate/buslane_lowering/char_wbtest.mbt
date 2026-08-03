///|
test "lower Unicode character literals and patterns to Buslane" {
  let result = elaborate_buslane_source(
    (
      #|fn classify(value : Char) -> I64 {
      #|  match value {
      #|    '\u{4F60}' => 1
      #|    _ => 0
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|buslane_elaborate_result {
      #|  buslane {
      #|    metadata {
      #|      value value#0 = "classify"#0 function : (Char) -> I64;
      #|      value value#1 = "value"#1 parameter : Char;
      #|      value value#2 = "scrutinee"#2 match_binder : Char;
      #|    }
      #|    letrec {
      #|      value#0 = fn(value#1) -> I64 {
      #|        match value#1 as value#2 -> I64 {
      #|          char(20320) => 1
      #|          _ => 0
      #|        }
      #|      }
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}
