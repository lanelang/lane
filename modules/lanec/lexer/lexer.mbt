///|
/// Lexes a Lane2 source string into tokens and lexical diagnostics.
pub fn tokens_from_string(source : String) -> LexResult {
  let env = LexEnv::{
    tokens: [],
    trivia: [],
    pending_trivia: [],
    errors: [],
    current_line: 1,
    current_bol: 0,
    last_token: None,
    last_token_end: -1,
  }
  lex_tokens(source, base=source, env~)
  {
    concrete: { source_text: source, tokens: env.tokens, trivia: env.trivia, },
    errors: env.errors,
  }
}

///|
fn lex_tokens(input : StringView, base~ : StringView, env~ : LexEnv) -> Unit {
  let mut rest = input
  while !rest.is_empty() {
    rest = lex_token(rest, base~, env~)
  }
  let end = env.calc_offset(rest, base~)
  env.add_token(EOF, start=end, end~)
}

///|
fn lex_token(
  input : StringView,
  base~ : StringView,
  env~ : LexEnv,
) -> StringView {
  lexmatch input with longest {
    (re"^(\r\n|\r|\n)", after=rest) => {
      env.add_trivia(
        Newline,
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      env.newline(end=env.calc_offset(rest, base~))
      rest
    }
    (re"^[\u0009\u000B\u000C\u0020]+", after=rest) => {
      env.add_trivia(
        Whitespace,
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      rest
    }
    (re"^//[^\r\n]*", after=rest) => {
      env.add_trivia(
        LineComment,
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      rest
    }
    (re"^=>", after=rest) => {
      env.add_token(
        FAT_ARROW,
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      rest
    }
    (re"^->", after=rest) => {
      env.add_token(
        THIN_ARROW,
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      rest
    }
    (re"^::", after=rest) => {
      let start = env.calc_offset(input, base~)
      let right_tight = starts_with_non_whitespace(rest)
      let end = env.calc_offset(rest, base~)
      if env.has_tight_left_operand(start) && right_tight {
        env.add_token(TIGHT_COLONCOLON, start~, end~)
      } else if right_tight {
        env.add_token(COLONCOLON, start~, end~)
      } else {
        env.add_token(COLON, start~, end=start + 1)
        env.add_token(COLON, start=start + 1, end~)
      }
      rest
    }
    (re"^==", after=rest) => {
      env.add_token(
        EQEQ,
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      rest
    }
    (re"^!=", after=rest) => {
      env.add_token(
        BANGEQ,
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      rest
    }
    (re"^<=", after=rest) => {
      env.add_token(
        LTEQ,
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      rest
    }
    (re"^>=", after=rest) => {
      env.add_token(
        GTEQ,
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      rest
    }
    (re"^&&", after=rest) => {
      env.add_token(
        AMPAMP,
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      rest
    }
    (re"^[|][|]", after=rest) => {
      env.add_token(
        BARBAR,
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      rest
    }
    (re"^[|]>", after=rest) => {
      env.add_token(
        PIPE,
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      rest
    }
    (
      re"^" +
      (re"[0-9]+[.][0-9]+[eE]([+]|-)?[0-9]+" as body) +
      (re"[A-Za-z_][A-Za-z0-9_]*" as attached_tail),
      after=rest,
    ) =>
      add_numeric_literal(
        input,
        body,
        attached_tail,
        rest,
        base~,
        env~,
        floating=true,
      )
    (re"^[0-9]+[.][0-9]+[eE]([+]|-)?[0-9]+" as body, after=rest) =>
      add_numeric_literal(input, body, "", rest, base~, env~, floating=true)
    (
      re"^" +
      (re"[0-9]+[.][0-9]+" as body) +
      (re"[A-Za-z_][A-Za-z0-9_]*" as attached_tail),
      after=rest,
    ) =>
      add_numeric_literal(
        input,
        body,
        attached_tail,
        rest,
        base~,
        env~,
        floating=true,
      )
    (re"^[0-9]+[.][0-9]+" as body, after=rest) =>
      add_numeric_literal(input, body, "", rest, base~, env~, floating=true)
    (
      re"^" +
      (re"[0-9]+[eE]([+]|-)?[0-9]+" as body) +
      (re"[A-Za-z_][A-Za-z0-9_]*" as attached_tail),
      after=rest,
    ) =>
      add_numeric_literal(
        input,
        body,
        attached_tail,
        rest,
        base~,
        env~,
        floating=true,
      )
    (re"^[0-9]+[eE]([+]|-)?[0-9]+" as body, after=rest) =>
      add_numeric_literal(input, body, "", rest, base~, env~, floating=true)
    (re"^" + (re"[0-9]+" as body) + re"[.]", after=rest) => {
      let start = env.calc_offset(input, base~)
      let end = env.calc_offset(rest, base~)
      if starts_with_identifier_character(rest) {
        let body_end = end - 1
        env.add_token(
          INT({ body: body.to_owned(), suffix: None, }),
          start~,
          end=body_end,
        )
        env.add_token(DOT, start=body_end, end~)
      } else {
        env.add_error(
          IncompleteFloatingLiteral(body.to_owned() + "."),
          start~,
          end~,
        )
      }
      rest
    }
    (
      re"^" +
      (re"[0-9]+" as body) +
      (re"[A-Za-z_][A-Za-z0-9_]*" as attached_tail),
      after=rest,
    ) =>
      add_numeric_literal(
        input,
        body,
        attached_tail,
        rest,
        base~,
        env~,
        floating=false,
      )
    (re"^[0-9]+" as body, after=rest) =>
      add_numeric_literal(input, body, "", rest, base~, env~, floating=false)
    (re"^([A-Za-z][A-Za-z0-9_]*|_[A-Za-z0-9_]+)" as raw, after=rest) => {
      let name = raw.to_owned()
      let token = if keyword_table.get(name) is Some(token) {
        token
      } else if reserved_word_table.contains(name) {
        RESERVED(name)
      } else {
        IDENT(name)
      }
      env.add_token(
        token,
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      rest
    }
    (re"^\"", after=rest) => {
      let start = env.calc_offset(input, base~)
      let (rest, value) = lex_quoted_literal(
        rest,
        base~,
        env~,
        start~,
        delimiter='"',
        kind=StringLiteralKind,
      )
      env.add_token(
        STRING(value.text),
        start~,
        end=env.calc_offset(rest, base~),
      )
      rest
    }
    (re"^'", after=rest) => {
      let start = env.calc_offset(input, base~)
      let (rest, value) = lex_quoted_literal(
        rest,
        base~,
        env~,
        start~,
        delimiter='\'',
        kind=CharLiteralKind,
      )
      if value.valid {
        if value.scalar_count == 0 {
          env.add_error(
            EmptyCharLiteral,
            start~,
            end=env.calc_offset(rest, base~),
          )
        } else if value.scalar_count > 1 {
          env.add_error(
            MultipleCharLiteral,
            start~,
            end=env.calc_offset(rest, base~),
          )
        }
      }
      env.add_token(
        CHAR(value.first_scalar.unwrap_or(0)),
        start~,
        end=env.calc_offset(rest, base~),
      )
      rest
    }
    (re"^[(]", after=rest) => add_simple_token(LPAREN, input, rest, base~, env~)
    (re"^[)]", after=rest) => add_simple_token(RPAREN, input, rest, base~, env~)
    (re"^[{]", after=rest) => add_simple_token(LBRACE, input, rest, base~, env~)
    (re"^[}]", after=rest) => add_simple_token(RBRACE, input, rest, base~, env~)
    (re"^\[", after=rest) =>
      add_simple_token(LBRACKET, input, rest, base~, env~)
    (re"^\]", after=rest) =>
      add_simple_token(RBRACKET, input, rest, base~, env~)
    (re"^,", after=rest) => add_simple_token(COMMA, input, rest, base~, env~)
    (re"^;", after=rest) =>
      add_simple_token(SEMICOLON, input, rest, base~, env~)
    (re"^[.][*]", after=rest) =>
      add_simple_token(DOTSTAR, input, rest, base~, env~)
    (re"^[.][{]", after=rest) =>
      add_simple_token(DOTLBRACE, input, rest, base~, env~)
    (re"^[.]", after=rest) => add_simple_token(DOT, input, rest, base~, env~)
    (re"^:", after=rest) => add_simple_token(COLON, input, rest, base~, env~)
    (re"^[+]", after=rest) => add_simple_token(PLUS, input, rest, base~, env~)
    (re"^-", after=rest) => add_simple_token(MINUS, input, rest, base~, env~)
    (re"^[*]", after=rest) => add_simple_token(STAR, input, rest, base~, env~)
    (re"^/", after=rest) => add_simple_token(SLASH, input, rest, base~, env~)
    (re"^%", after=rest) => add_simple_token(PERCENT, input, rest, base~, env~)
    (re"^_", after=rest) =>
      add_simple_token(UNDERSCORE, input, rest, base~, env~)
    (re"^<", after=rest) => add_simple_token(LT, input, rest, base~, env~)
    (re"^>", after=rest) => add_simple_token(GT, input, rest, base~, env~)
    (re"^!", after=rest) => add_simple_token(BANG, input, rest, base~, env~)
    (re"^=", after=rest) => add_simple_token(EQUAL, input, rest, base~, env~)
    re"^$" => input
    _ => {
      let scalar_end = input.offset_of_nth_char(1).unwrap_or(input.length())
      let raw = input[:scalar_end]
      let rest = input[scalar_end:]
      env.add_error(
        IllegalCharacter(raw.to_owned()),
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      rest
    }
  }
}

///|
fn add_simple_token(
  token : Token,
  input : StringView,
  rest : StringView,
  base~ : StringView,
  env~ : LexEnv,
) -> StringView {
  env.add_token(
    token,
    start=env.calc_offset(input, base~),
    end=env.calc_offset(rest, base~),
  )
  rest
}

///|
fn add_numeric_literal(
  input : StringView,
  body : StringView,
  attached_tail : StringView,
  rest : StringView,
  base~ : StringView,
  env~ : LexEnv,
  floating~ : Bool,
) -> StringView {
  let suffix = NumericLiteralSuffix::parse(attached_tail.to_owned(), floating~)
  match suffix {
    Ok(suffix) =>
      env.add_token(
        if floating {
          DOUBLE({ body: body.to_owned(), suffix, })
        } else {
          INT({ body: body.to_owned(), suffix, })
        },
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
    Err(error) => {
      let spelling = body.to_owned() + attached_tail.to_owned()
      env.add_error(
        match error {
          UnknownSuffix => UnknownNumericLiteralSuffix(spelling)
          IntegerSuffixForFloatingBody =>
            IntegerSuffixOnFloatingLiteral(spelling)
        },
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
    }
  }
  rest
}

///|
fn starts_with_non_whitespace(input : StringView) -> Bool {
  if input.is_empty() {
    false
  } else {
    let unit = input.unsafe_get(0)
    unit != 0x09 &&
    unit != 0x0A &&
    unit != 0x0B &&
    unit != 0x0C &&
    unit != 0x0D &&
    unit != 0x20
  }
}

///|
fn starts_with_identifier_character(input : StringView) -> Bool {
  if input.is_empty() {
    false
  } else {
    let unit = input.unsafe_get(0)
    unit == 0x5F ||
    (unit >= 0x41 && unit <= 0x5A) ||
    (unit >= 0x61 && unit <= 0x7A)
  }
}

///|
priv enum QuotedLiteralKind {
  StringLiteralKind
  CharLiteralKind
}

///|
priv struct QuotedLiteralValue {
  text : String
  scalar_count : Int
  first_scalar : Int?
  valid : Bool
}

///|
fn lex_quoted_literal(
  input : StringView,
  base~ : StringView,
  env~ : LexEnv,
  start~ : Int,
  delimiter~ : Char,
  kind~ : QuotedLiteralKind,
) -> (StringView, QuotedLiteralValue) {
  let buf = StringBuilder()
  let mut scalar_count = 0
  let mut first_scalar : Int? = None
  let mut valid = true

  fn append_scalar(value : Int) -> Unit {
    if first_scalar is None {
      first_scalar = Some(value)
    }
    scalar_count += 1
    buf.write_char(value.unsafe_to_char())
  }

  fn unterminated(input : StringView) -> StringView {
    env.add_error(
      match kind {
        StringLiteralKind => UnterminatedString
        CharLiteralKind => UnterminatedChar
      },
      start~,
      end=env.calc_offset(input, base~),
    )
    valid = false
    input
  }

  fn process_unicode_escape(
    input : StringView,
    escape_start : Int,
  ) -> StringView {
    guard input is ['{', .. rest] else {
      env.add_error(
        InvalidUnicodeEscape("\\u", MissingBraces),
        start=escape_start,
        end=env.calc_offset(input, base~),
      )
      valid = false
      return input
    }
    let digits = StringBuilder()
    let mut digit_count = 0
    let mut value = 0
    let mut hexadecimal = true
    fn finish(input : StringView) -> StringView {
      let raw = digits.to_string()
      let error = if digit_count == 0 {
        Some(Empty)
      } else if digit_count > 6 {
        Some(TooManyDigits)
      } else if !hexadecimal {
        Some(NonHexadecimal)
      } else if value.to_char() is None {
        Some(
          if value >= 0xD800 && value <= 0xDFFF {
            Surrogate
          } else {
            OutOfRange
          },
        )
      } else {
        None
      }
      match error {
        Some(reason) => {
          env.add_error(
            InvalidUnicodeEscape(raw, reason),
            start=escape_start,
            end=env.calc_offset(input, base~),
          )
          valid = false
        }
        None => append_scalar(value)
      }
      input
    }
    fn scan(input : StringView) -> StringView {
      match input {
        ['}', .. rest] => finish(rest)
        ['\r' | '\n', ..] | [] => {
          env.add_error(
            InvalidUnicodeEscape(digits.to_string(), MissingBraces),
            start=escape_start,
            end=env.calc_offset(input, base~),
          )
          valid = false
          input
        }
        [character, ..] if character == delimiter => {
          env.add_error(
            InvalidUnicodeEscape(digits.to_string(), MissingBraces),
            start=escape_start,
            end=env.calc_offset(input, base~),
          )
          valid = false
          input
        }
        [character, .. rest] => {
          digits.write_char(character)
          digit_count += 1
          match hexadecimal_digit_value(character) {
            Some(digit) if hexadecimal => value = value * 16 + digit
            Some(_) => ()
            None => hexadecimal = false
          }
          scan(rest)
        }
      }
    }
    scan(rest)
  }

  fn process(input : StringView) -> StringView {
    match input {
      [] | ['\r' | '\n', ..] => unterminated(input)
      [character, .. rest] =>
        if character == delimiter {
          rest
        } else if character == '\\' {
          let escape_start = env.calc_offset(input, base~)
          match rest {
            [] | ['\r' | '\n', ..] => unterminated(rest)
            [escaped, .. after_escape] =>
              if escaped == delimiter {
                append_scalar(escaped.to_int())
                process(after_escape)
              } else {
                match escaped {
                  '\\' => {
                    append_scalar('\\'.to_int())
                    process(after_escape)
                  }
                  'n' => {
                    append_scalar('\n'.to_int())
                    process(after_escape)
                  }
                  'r' => {
                    append_scalar('\r'.to_int())
                    process(after_escape)
                  }
                  't' => {
                    append_scalar('\t'.to_int())
                    process(after_escape)
                  }
                  '0' => {
                    append_scalar(0)
                    process(after_escape)
                  }
                  'u' =>
                    process(process_unicode_escape(after_escape, escape_start))
                  _ => {
                    env.add_error(
                      InvalidLiteralEscape("\\" + escaped.to_string()),
                      start=escape_start,
                      end=env.calc_offset(after_escape, base~),
                    )
                    valid = false
                    process(after_escape)
                  }
                }
              }
          }
        } else {
          append_scalar(character.to_int())
          process(rest)
        }
    }
  }

  let rest = process(input)
  (rest, { text: buf.to_string(), scalar_count, first_scalar, valid, })
}

///|
fn hexadecimal_digit_value(character : Char) -> Int? {
  match character {
    '0'..='9' => Some(character.to_int() - '0'.to_int())
    'a'..='f' => Some(character.to_int() - 'a'.to_int() + 10)
    'A'..='F' => Some(character.to_int() - 'A'.to_int() + 10)
    _ => None
  }
}
