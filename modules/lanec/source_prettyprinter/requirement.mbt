///|
priv enum Requirement {
  Space(Int)
  Infinite
  Contextual
}

///|
impl Add for Requirement with fn add(self, other) {
  match (self, other) {
    (Space(a), Space(b)) => Space(a + b)
    (Infinite, _) | (_, Infinite) => Infinite
    _ => Contextual
  }
}

///|
fn Document::requirement(doc : Self) -> Requirement {
  match doc {
    Empty => Space(0)
    MandatoryLine | Line => Infinite
    MandatorySpace | Space => Space(1)
    Text(s) => Space(s.length())
    LineComment(_) => Contextual
    Concat(req, _, _) | Switch(req, _, _) | Nest(req, _, _) | Group(req, _) =>
      req
    Dynamic(_) => Contextual
  }
}
