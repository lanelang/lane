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
    Effect => text("Effect")
    Function(parameters, result) =>
      group(
        bracketed(parameters.map(Kind::pretty)) +
        space +
        text("->") +
        space +
        result.pretty(),
      )
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
    Constructor(symbol) => symbol.pretty()
    Apply(callee, arguments) =>
      group(callee.pretty() + bracketed(arguments.map(GenericArgument::pretty)))
    TypeLambda(parameters, body) =>
      group(
        text("type") +
        space +
        bracketed(parameters.map(TypeParameter::pretty)) +
        space +
        text("=>") +
        space +
        body.pretty(),
      )
    Parameter(id) => id.pretty()
    Function(parameters, result, effect) => {
      let effect_doc = match effect {
        Empty => empty
        _ => space + text("!") + space + effect.pretty()
      }
      group(
        parenthesized(parameters.map(Type::pretty)) +
        space +
        text("->") +
        space +
        result.pretty() +
        effect_doc,
      )
    }
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
pub impl @prettyprinter.Pretty for Effect with fn pretty(effect : Effect) {
  match effect {
    Empty => text("{}")
    Singleton(symbol, arguments) =>
      if arguments.is_empty() {
        symbol.pretty()
      } else {
        group(
          symbol.pretty() + bracketed(arguments.map(GenericArgument::pretty)),
        )
      }
    Parameter(id) => id.pretty()
    Union(effects) =>
      surround(
        char('{'),
        char('}'),
        nest(softline + comma_list(effects.map(Effect::pretty))) + softline,
      )
  }
}

///|
pub impl @prettyprinter.Pretty for GenericArgument with fn pretty(
  argument : GenericArgument,
) {
  match argument {
    TypeArgument(type_) => type_.pretty()
    EffectArgument(effect) => effect.pretty()
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
