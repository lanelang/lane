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
priv struct EffectLoweringCode {
  terms : Array[@effect_lowering_core.TopTerm]
}

///|
impl @prettyprinter.Pretty for EffectLoweringCode with fn pretty(
  code : EffectLoweringCode,
) {
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
fn render_resolved_code(source : @resolve.ResolvedSourceFile) -> String {
  @prettyprinter.render(
    ResolvedCode::{ declarations: source.declarations },
    width=100,
  )
}

///|
fn render_checked_code(source : @checked.CheckedSourceFile) -> String {
  @prettyprinter.render(
    CheckedCode::{ declarations: source.declarations },
    width=100,
  )
}

///|
fn render_buslane_code(program : @buslane.Program) -> String {
  @prettyprinter.render(BuslaneCode::{ terms: program.terms }, width=100)
}

///|
fn render_effect_lowering_code(
  program : @effect_lowering_core.Program,
) -> String {
  @prettyprinter.render(EffectLoweringCode::{ terms: program.terms }, width=100)
}

///|
fn render_anf_code(program : @anf.AnfProgram) -> String {
  @prettyprinter.render(AnfCode::{ terms: program.terms }, width=100)
}
