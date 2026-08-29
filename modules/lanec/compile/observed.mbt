///|
using @prettyprinter {hardline, separate}

///|
priv struct ResolvedCode {
  declarations : Array[@resolve.ResolvedTopLevelDeclaration]
}

///|
impl @prettyprinter.Pretty for ResolvedCode with fn pretty(code : ResolvedCode) {
  separate(hardline, code.declarations.map(declaration => declaration.pretty()))
}

///|
priv struct CheckedCode {
  declarations : Array[@checked.CheckedTopLevelDeclaration]
}

///|
impl @prettyprinter.Pretty for CheckedCode with fn pretty(code : CheckedCode) {
  separate(hardline, code.declarations.map(declaration => declaration.pretty()))
}

///|
priv struct BuslaneCode {
  terms : Array[@buslane.TopTerm]
}

///|
impl @prettyprinter.Pretty for BuslaneCode with fn pretty(code : BuslaneCode) {
  separate(hardline, code.terms.map(term => term.pretty()))
}

///|
fn render_resolved_source(
  source : @resolve.ResolvedSourceFile,
  width : Int,
) -> String {
  @prettyprinter.render(
    ResolvedCode::{ declarations: source.declarations, },
    width~,
  )
}

///|
fn render_checked_source(
  source : @checked.CheckedSourceFile,
  width : Int,
) -> String {
  @prettyprinter.render(
    CheckedCode::{ declarations: source.declarations, },
    width~,
  )
}

///|
fn render_buslane_program(program : @buslane.Program, width : Int) -> String {
  @prettyprinter.render(BuslaneCode::{ terms: program.terms, }, width~)
}
