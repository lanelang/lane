///|
pub impl @prettyprinter.Pretty for PrimitiveType with fn pretty(
  primitive : PrimitiveType,
) {
  match primitive {
    Int => text("Int")
    Bool => text("Bool")
    String => text("String")
    Unit => text("Unit")
  }
}

///|
pub impl @prettyprinter.Pretty for Kind with fn pretty(kind : Kind) {
  match kind {
    Type => text("Type")
    Arrow(parameter, result) =>
      group(parameter.pretty() + space + text("->") + space + result.pretty())
  }
}

///|
pub impl @prettyprinter.Pretty for TypeParameter with fn pretty(
  parameter : TypeParameter,
) {
  parameter.id.pretty() +
  space +
  text(parameter.name) +
  space +
  text(":") +
  space +
  parameter.kind.pretty()
}

///|
fn comma_list(items : Array[Document]) -> Document {
  separate(char(',') + line, items)
}

///|
fn bracketed(items : Array[Document]) -> Document {
  surround(char('['), char(']'), nest(softline + comma_list(items)) + softline)
}

///|
fn parenthesized(items : Array[Document]) -> Document {
  surround(char('('), char(')'), nest(softline + comma_list(items)) + softline)
}

///|
pub impl @prettyprinter.Pretty for Type with fn pretty(type_ : Type) {
  match type_ {
    Error => text("<error>")
    Primitive(primitive) => primitive.pretty()
    Nominal(symbol, arguments) =>
      if arguments.is_empty() {
        symbol.pretty()
      } else {
        group(symbol.pretty() + bracketed(arguments.map(Type::pretty)))
      }
    Parameter(id) => id.pretty()
    Function(parameters, result) =>
      group(
        parenthesized(parameters.map(Type::pretty)) +
        space +
        text("->") +
        space +
        result.pretty(),
      )
    Forall(parameters, body) =>
      group(
        text("forall") +
        space +
        bracketed(parameters.map(TypeParameter::pretty)) +
        text(".") +
        space +
        body.pretty(),
      )
  }
}

///|
impl @prettyprinter.Pretty for TypeSubstitutionEntry with fn pretty(
  entry : TypeSubstitutionEntry,
) {
  entry.parameter.pretty() +
  space +
  text("=>") +
  space +
  entry.replacement.pretty()
}

///|
pub impl @prettyprinter.Pretty for TypeSubstitution with fn pretty(
  substitution : TypeSubstitution,
) {
  text("substitution") +
  space +
  surround(
    char('{'),
    char('}'),
    nest(
      softline +
      comma_list(substitution.entries.map(TypeSubstitutionEntry::pretty)),
    ) +
    softline,
  )
}
