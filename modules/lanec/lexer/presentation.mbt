///|
pub(all) struct LexicalErrorPresentation {
  code : String
  title : String
  label : String
  notes : Array[String]
  helps : Array[String]
}

///|
pub fn LexicalError::presentation(
  self : LexicalError,
) -> LexicalErrorPresentation {
  {
    code: match self {
      IllegalCharacter(_) => "E1000"
      UnknownNumericLiteralSuffix(_) => "E1008"
      IntegerSuffixOnFloatingLiteral(_) => "E1009"
      UnterminatedString => "E1002"
      InvalidLiteralEscape(_) => "E1003"
      InvalidUnicodeEscape(_, _) => "E1004"
      UnterminatedChar => "E1005"
      EmptyCharLiteral => "E1006"
      MultipleCharLiteral => "E1007"
    },
    title: match self {
      IllegalCharacter(_) => "illegal character in source"
      UnknownNumericLiteralSuffix(_) => "unknown numeric literal suffix"
      IntegerSuffixOnFloatingLiteral(_) =>
        "integer suffix requires an integer literal body"
      UnterminatedString => "unterminated string literal"
      UnterminatedChar => "unterminated character literal"
      InvalidLiteralEscape(_) => "invalid literal escape"
      InvalidUnicodeEscape(_, _) => "invalid Unicode escape"
      EmptyCharLiteral => "empty character literal"
      MultipleCharLiteral => "character literal has multiple scalars"
    },
    label: match self {
      IllegalCharacter(value) => "`\{value}` is not valid Lane syntax"
      UnknownNumericLiteralSuffix(value) =>
        "`\{value}` ends with an unsupported numeric literal suffix"
      IntegerSuffixOnFloatingLiteral(value) =>
        "`\{value}` has a fractional or exponent form with an integer suffix"
      UnterminatedString => "this string literal is never closed"
      UnterminatedChar => "this character literal is never closed"
      InvalidLiteralEscape(value) =>
        "`\{value}` is not a supported escape sequence"
      InvalidUnicodeEscape(value, reason) =>
        "`\{value}` is not a valid Unicode escape: \{reason.description()}"
      EmptyCharLiteral => "a character literal must contain one Unicode scalar"
      MultipleCharLiteral =>
        "a character literal must contain exactly one Unicode scalar"
    },
    notes: match self {
      InvalidUnicodeEscape(_, Surrogate) =>
        ["Unicode surrogate code points are not Unicode scalar values"]
      _ => []
    },
    helps: match self {
      IllegalCharacter(_) =>
        ["remove this character or replace it with a valid Lane token"]
      UnknownNumericLiteralSuffix(_) =>
        ["use one of the lowercase suffixes `i32`, `i64`, `f32`, or `f64`"]
      IntegerSuffixOnFloatingLiteral(_) =>
        ["remove the fractional or exponent part, or use `f32` or `f64`"]
      UnterminatedString => ["add a closing `\"` before the end of the line"]
      UnterminatedChar => ["add a closing `'` before the end of the line"]
      InvalidLiteralEscape(_) =>
        [
          "use `\\n`, `\\r`, `\\t`, `\\0`, `\\\\`, a delimiter escape, or `\\u{HEX}`",
        ]
      InvalidUnicodeEscape(_, _) =>
        ["write one through six hexadecimal digits for a Unicode scalar value"]
      EmptyCharLiteral | MultipleCharLiteral =>
        ["write exactly one direct or escaped Unicode scalar"]
    },
  }
}

///|
fn UnicodeEscapeError::description(self : UnicodeEscapeError) -> String {
  match self {
    MissingBraces => "expected braces after `\\u`"
    Empty => "the braces contain no digits"
    TooManyDigits => "more than six hexadecimal digits were provided"
    NonHexadecimal => "the braces contain a non-hexadecimal digit"
    OutOfRange => "the value exceeds U+10FFFF"
    Surrogate => "the value is a surrogate code point"
  }
}
