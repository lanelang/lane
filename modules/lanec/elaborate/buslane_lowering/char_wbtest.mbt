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
      #|      function classify#0 : (Char) -> I64
      #|      parameter value#1 : Char
      #|      match_binder scrutinee#2 : Char
      #|    }
      #|    letrec {
      #|      value#0 = fn(value#1) -> I64 {
      #|        match value#1 as value#2 -> I64 {
      #|          20320 => 1
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
