///|
using @prettyprinter {hardline, separate}

///|
priv struct BuslaneCode {
  terms : Array[@buslane.TopTerm]
}

///|
impl @prettyprinter.Pretty for BuslaneCode with fn pretty(code : BuslaneCode) {
  separate(hardline, code.terms.map(term => term.pretty()))
}

///|
priv struct AnfCode {
  terms : Array[@anf.AnfTopTerm]
}

///|
impl @prettyprinter.Pretty for AnfCode with fn pretty(code : AnfCode) {
  separate(hardline, code.terms.map(term => term.pretty()))
}

///|
fn render_buslane_code(program : @buslane.Program) -> String {
  @prettyprinter.render(BuslaneCode::{ terms: program.terms }, width=100)
}

///|
fn render_executable_code(program : @executable.ExecutableProgram) -> String {
  @prettyprinter.render(program, width=100)
}

///|
fn render_anf_code(program : @anf.AnfProgram) -> String {
  @prettyprinter.render(AnfCode::{ terms: program.terms }, width=100)
}
