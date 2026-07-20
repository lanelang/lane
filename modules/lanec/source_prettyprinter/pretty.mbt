///|
pub(open) trait Pretty {
  fn pretty(Self) -> Document
}

///|
pub fn[A : Pretty] pretty(value : A) -> Document {
  value.pretty()
}

///|
pub fn[A : Pretty] render(document : A, width? : Int = 80) -> String {
  render_document(width, document.pretty())
}

///|
pub impl Pretty for Document with fn pretty(document) {
  document
}
