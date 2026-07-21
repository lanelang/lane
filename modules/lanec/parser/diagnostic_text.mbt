///|
pub fn ParseErrorKind::diagnostic_code(self : ParseErrorKind) -> String {
  match self {
    UnexpectedToken(_, _) => "E1100"
    UnexpectedEndOfInput(_) => "E1101"
    EmptyGenericArgumentList => "E1102"
    EmptyTypeParameterList => "E1103"
  }
}

///|
pub fn ParseErrorKind::diagnostic_title(self : ParseErrorKind) -> String {
  match self {
    UnexpectedToken(_, _) if self.is_empty_block() =>
      "block needs a result expression"
    UnexpectedToken(_, _) if self.is_block_item_after_result() =>
      "block result expression must be last"
    UnexpectedToken(_, _) if self.is_missing_declaration_type() =>
      "declaration needs a type annotation"
    UnexpectedToken(_, _) if self.is_missing_function_result_type() =>
      "function declaration needs a result type"
    UnexpectedToken(_, _) if self.is_equals_function_body() =>
      "function body must be a block"
    UnexpectedToken(_, _) if self.is_tuple_type() =>
      "tuple types are not supported"
    UnexpectedToken(_, _) if self.is_extra_type_parameter_list() =>
      "type alias has one parameter list"
    UnexpectedToken(_, _) if self.is_struct_spread() =>
      "struct spread is not supported"
    UnexpectedToken(_, _) if self.is_missing_variant_constructor_parens() =>
      "variant constructor needs parentheses"
    UnexpectedToken(_, _) if self.is_missing_final_else() =>
      "`if` expression needs an `else` branch"
    UnexpectedToken(_, _) if self.is_leading_double_colon_pattern() =>
      "variant patterns do not use leading `::`"
    UnexpectedToken(_, _) => "unexpected token"
    UnexpectedEndOfInput(_) => "unexpected end of input"
    EmptyGenericArgumentList => "empty generic argument list"
    EmptyTypeParameterList => "empty type parameter list"
  }
}

///|
pub fn ParseErrorKind::diagnostic_label(self : ParseErrorKind) -> String {
  match self {
    UnexpectedToken(_, _) if self.is_empty_block() =>
      "this block has no final expression"
    UnexpectedToken(_, _) if self.is_block_item_after_result() =>
      "this appears after the block's final expression"
    UnexpectedToken(_, _) if self.is_missing_declaration_type() =>
      "write `: Type` before `=`"
    UnexpectedToken(_, _) if self.is_missing_function_result_type() =>
      "write `-> Type` before the function body"
    UnexpectedToken(_, _) if self.is_equals_function_body() =>
      "write the function body as `{ ... }`, not after `=`"
    UnexpectedToken(_, _) if self.is_tuple_type() =>
      "parenthesized types are parsed as function types and need `->`"
    UnexpectedToken(_, _) if self.is_extra_type_parameter_list() =>
      "put every type parameter in the first `[...]` list"
    UnexpectedToken(_, _) if self.is_struct_spread() =>
      "`..` spread is not part of Lane struct literals"
    UnexpectedToken(_, _) if self.is_missing_variant_constructor_parens() =>
      "write empty parentheses after this payloadless constructor"
    UnexpectedToken(_, _) if self.is_missing_final_else() =>
      "add an `else` branch before the block ends"
    UnexpectedToken(_, _) if self.is_leading_double_colon_pattern() =>
      "write the variant pattern without leading `::`"
    UnexpectedToken(token, _) => "the parser did not expect \{token.label}"
    UnexpectedEndOfInput(_) =>
      "the source file ended while parsing this construct"
    EmptyGenericArgumentList =>
      "explicit generic argument lists must contain at least one argument"
    EmptyTypeParameterList =>
      "generic parameter lists must contain at least one parameter"
  }
}

///|
pub fn ParseErrorKind::diagnostic_notes(self : ParseErrorKind) -> Array[String] {
  match self {
    UnexpectedToken(_, _) if self.is_empty_block() =>
      [
        "Lane blocks evaluate to their final expression; empty blocks do not implicitly produce `Unit`",
      ]
    UnexpectedToken(_, _) if self.is_block_item_after_result() =>
      [
        "Lane blocks contain local items followed by exactly one final expression",
      ]
    UnexpectedToken(_, _) if self.is_missing_declaration_type() =>
      [
        "top-level declarations and local `let` bindings use `name : Type = expression`",
      ]
    UnexpectedToken(_, _) if self.is_missing_function_result_type() =>
      ["Lane function declarations state their result type before the body"]
    UnexpectedToken(_, _) if self.is_equals_function_body() =>
      ["Lane named functions always use block bodies"]
    UnexpectedToken(_, _) if self.is_tuple_type() =>
      ["Lane v1 has structs and function types, but no tuple type syntax"]
    UnexpectedToken(_, _) if self.is_extra_type_parameter_list() =>
      ["Lane declarations use one generic parameter list before `=`"]
    UnexpectedToken(_, _) if self.is_struct_spread() =>
      ["Lane struct literals list their fields explicitly"]
    UnexpectedToken(_, _) if self.is_missing_variant_constructor_parens() =>
      ["all enum variant constructors use parentheses in expressions"]
    UnexpectedToken(_, _) if self.is_missing_final_else() =>
      ["Lane `if` is an expression, so both branches must produce a value"]
    UnexpectedToken(_, _) if self.is_leading_double_colon_pattern() =>
      ["unqualified variant patterns are written as `variant(...)`"]
    UnexpectedToken(_, expected) | UnexpectedEndOfInput(expected) =>
      if expected.is_empty() {
        []
      } else {
        ["expected one of: \{expected_list(expected)}"]
      }
    EmptyGenericArgumentList =>
      [
        "use explicit generic arguments only when at least one argument is provided",
      ]
    EmptyTypeParameterList =>
      ["omit the brackets when a declaration has no generic parameters"]
  }
}

///|
pub fn ParseErrorKind::diagnostic_helps(self : ParseErrorKind) -> Array[String] {
  match self {
    UnexpectedToken(_, _) if self.is_empty_block() =>
      ["write a final expression before `}`"]
    UnexpectedToken(_, _) if self.is_block_item_after_result() =>
      [
        "separate the expressions with a newline or `;`; either form requires the preceding expression to have type `Unit`; otherwise, bind or otherwise use its value",
      ]
    UnexpectedToken(_, _) if self.is_missing_declaration_type() =>
      ["write the binding as `name : Type = expression`"]
    UnexpectedToken(_, _) if self.is_missing_function_result_type() =>
      ["write the declaration as `fn name(...) -> Type { ... }`"]
    UnexpectedToken(_, _) if self.is_equals_function_body() =>
      ["write `fn name(...) -> Type { expression }`"]
    UnexpectedToken(_, _) if self.is_tuple_type() =>
      ["define a struct for this pair-shaped value"]
    UnexpectedToken(_, _) if self.is_extra_type_parameter_list() =>
      ["write all parameters together, for example `Result[E, A]`"]
    UnexpectedToken(_, _) if self.is_struct_spread() =>
      ["write each field explicitly, for example `Point::{ x: 3, y: point.y }`"]
    UnexpectedToken(_, _) if self.is_missing_variant_constructor_parens() =>
      ["write the constructor call with `()`"]
    UnexpectedToken(_, _) if self.is_missing_final_else() =>
      ["add `else { ... }`"]
    UnexpectedToken(_, _) if self.is_leading_double_colon_pattern() =>
      ["use `none()` instead of `::none()`"]
    UnexpectedToken(_, expected) =>
      if expected.is_empty() {
        ["remove the unexpected token or rewrite the surrounding expression"]
      } else {
        [
          "rewrite this position so it starts with one of: \{expected_list(expected)}",
        ]
      }
    UnexpectedEndOfInput(expected) =>
      if expected.is_empty() {
        ["finish the incomplete construct before the end of file"]
      } else {
        [
          "add the missing syntax before the end of file; expected one of: \{expected_list(expected)}",
        ]
      }
    EmptyGenericArgumentList =>
      ["remove the empty `[]` or provide at least one generic argument"]
    EmptyTypeParameterList =>
      ["remove the empty `[]` or add a parameter name such as `[A]`"]
  }
}

///|
fn ParseErrorKind::is_empty_block(self : ParseErrorKind) -> Bool {
  match self {
    UnexpectedToken(token, expected) =>
      token.label == "`}`" &&
      expected.contains_label("integer literal") &&
      !expected.contains_label("`else`")
    _ => false
  }
}

///|
fn ParseErrorKind::is_block_item_after_result(self : ParseErrorKind) -> Bool {
  match self {
    UnexpectedToken(token, expected) =>
      expected.contains_label("`}`") &&
      expected.contains_label("`+`") &&
      (token.label.has_prefix("identifier ") || token.label == "`fn`")
    _ => false
  }
}

///|
fn ParseErrorKind::is_missing_declaration_type(self : ParseErrorKind) -> Bool {
  match self {
    UnexpectedToken(token, expected) =>
      token.label == "`=`" && expected.contains_label("`:`")
    _ => false
  }
}

///|
fn ParseErrorKind::is_equals_function_body(self : ParseErrorKind) -> Bool {
  match self {
    UnexpectedToken(token, expected) =>
      token.label == "`=`" &&
      expected.contains_label("`{`") &&
      expected.contains_label("`->`")
    _ => false
  }
}

///|
fn ParseErrorKind::is_tuple_type(self : ParseErrorKind) -> Bool {
  match self {
    UnexpectedToken(token, expected) =>
      token.label == "`=`" &&
      expected.contains_label("`->`") &&
      !expected.contains_label("`{`")
    _ => false
  }
}

///|
fn ParseErrorKind::is_extra_type_parameter_list(self : ParseErrorKind) -> Bool {
  match self {
    UnexpectedToken(token, expected) =>
      token.label == "`[`" && expected.contains_label("`=`")
    _ => false
  }
}

///|
fn ParseErrorKind::is_struct_spread(self : ParseErrorKind) -> Bool {
  match self {
    UnexpectedToken(token, expected) =>
      token.label == "`.`" &&
      expected.contains_label("identifier") &&
      expected.contains_label("`}`")
    _ => false
  }
}

///|
fn ParseErrorKind::is_missing_variant_constructor_parens(
  self : ParseErrorKind,
) -> Bool {
  match self {
    UnexpectedToken(token, expected) =>
      token.label == "end of file" &&
      expected.contains_label("`(`") &&
      expected.contains_label("`[`")
    _ => false
  }
}

///|
fn ParseErrorKind::is_missing_final_else(self : ParseErrorKind) -> Bool {
  match self {
    UnexpectedToken(token, expected) =>
      token.label == "`}`" && expected.contains_label("`else`")
    _ => false
  }
}

///|
fn ParseErrorKind::is_leading_double_colon_pattern(
  self : ParseErrorKind,
) -> Bool {
  match self {
    UnexpectedToken(token, expected) =>
      token.label == "`::`" &&
      expected.contains_label("`_`") &&
      expected.contains_label("identifier")
    _ => false
  }
}

///|
fn ParseErrorKind::is_missing_function_result_type(
  self : ParseErrorKind,
) -> Bool {
  match self {
    UnexpectedToken(token, expected) =>
      token.label == "`{`" && expected.contains_label("`->`")
    _ => false
  }
}

///|
fn Array::contains_label(self : Array[ExpectedSyntax], label : String) -> Bool {
  self.any(fn(item) { item.label == label })
}

///|
fn expected_list(expected : Array[ExpectedSyntax]) -> String {
  expected.map(fn(item) { item.label }).join(", ")
}
