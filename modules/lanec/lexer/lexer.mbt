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
    concrete: { source_text: source, tokens: env.tokens, trivia: env.trivia },
    errors: env.errors,
  }
}

///|
fn lex_tokens(input : StringView, base~ : StringView, env~ : LexEnv) -> Unit {
  lexscan input with longest {
    (re"^(\r\n|\r|\n)", after=rest) => {
      env.add_trivia(
        Newline,
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      env.newline(end=env.calc_offset(rest, base~))
      lex_tokens(rest, base~, env~)
    }
    (re"^[\u0009\u000B\u000C\u0020]+", after=rest) => {
      env.add_trivia(
        Whitespace,
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      lex_tokens(rest, base~, env~)
    }
    (re"^//[^\r\n]*", after=rest) => {
      env.add_trivia(
        LineComment,
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      lex_tokens(rest, base~, env~)
    }
    (re"^=>", after=rest) => {
      env.add_token(
        FAT_ARROW,
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      lex_tokens(rest, base~, env~)
    }
    (re"^->", after=rest) => {
      env.add_token(
        THIN_ARROW,
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      lex_tokens(rest, base~, env~)
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
      lex_tokens(rest, base~, env~)
    }
    (re"^==", after=rest) => {
      env.add_token(
        EQEQ,
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      lex_tokens(rest, base~, env~)
    }
    (re"^!=", after=rest) => {
      env.add_token(
        BANGEQ,
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      lex_tokens(rest, base~, env~)
    }
    (re"^<=", after=rest) => {
      env.add_token(
        LTEQ,
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      lex_tokens(rest, base~, env~)
    }
    (re"^>=", after=rest) => {
      env.add_token(
        GTEQ,
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      lex_tokens(rest, base~, env~)
    }
    (re"^&&", after=rest) => {
      env.add_token(
        AMPAMP,
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      lex_tokens(rest, base~, env~)
    }
    (re"^[|][|]", after=rest) => {
      env.add_token(
        BARBAR,
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      lex_tokens(rest, base~, env~)
    }
    (re"^[|]>", after=rest) => {
      env.add_token(
        PIPE,
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      lex_tokens(rest, base~, env~)
    }
    (re"^[0-9]+[.][0-9]+[eE][+][0-9]+" as raw, after=rest) => {
      env.add_token(
        DOUBLE(raw.to_owned()),
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      lex_tokens(rest, base~, env~)
    }
    (re"^[0-9]+[.][0-9]+[eE]-[0-9]+" as raw, after=rest) => {
      env.add_token(
        DOUBLE(raw.to_owned()),
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      lex_tokens(rest, base~, env~)
    }
    (re"^[0-9]+[.][0-9]+[eE][0-9]+" as raw, after=rest) => {
      env.add_token(
        DOUBLE(raw.to_owned()),
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      lex_tokens(rest, base~, env~)
    }
    (re"^[0-9]+[.][0-9]+" as raw, after=rest) => {
      env.add_token(
        DOUBLE(raw.to_owned()),
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      lex_tokens(rest, base~, env~)
    }
    (re"^[0-9]+[eE][+][0-9]+" as raw, after=rest) => {
      env.add_token(
        DOUBLE(raw.to_owned()),
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      lex_tokens(rest, base~, env~)
    }
    (re"^[0-9]+[eE]-[0-9]+" as raw, after=rest) => {
      env.add_token(
        DOUBLE(raw.to_owned()),
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      lex_tokens(rest, base~, env~)
    }
    (re"^[0-9]+[eE][0-9]+" as raw, after=rest) => {
      env.add_token(
        DOUBLE(raw.to_owned()),
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      lex_tokens(rest, base~, env~)
    }
    (re"^[0-9]+" as raw, after=rest) => {
      env.add_token(
        INT(raw.to_owned()),
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      lex_tokens(rest, base~, env~)
    }
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
      lex_tokens(rest, base~, env~)
    }
    (re"^\"", after=rest) => {
      let start = env.calc_offset(input, base~)
      let (rest, repr) = lex_string(rest, base~, env~, start~)
      env.add_token(STRING(repr), start~, end=env.calc_offset(rest, base~))
      lex_tokens(rest, base~, env~)
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
    re"^$" => {
      let end = env.calc_offset(input, base~)
      env.add_token(EOF, start=end, end~)
    }
    (re"^." as raw, after=rest) => {
      env.add_error(
        IllegalCharacter(raw.to_string()),
        start=env.calc_offset(input, base~),
        end=env.calc_offset(rest, base~),
      )
      lex_tokens(rest, base~, env~)
    }
    _ => panic()
  }
}

///|
fn add_simple_token(
  token : Token,
  input : StringView,
  rest : StringView,
  base~ : StringView,
  env~ : LexEnv,
) -> Unit {
  env.add_token(
    token,
    start=env.calc_offset(input, base~),
    end=env.calc_offset(rest, base~),
  )
  lex_tokens(rest, base~, env~)
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
fn lex_string(
  input : StringView,
  base~ : StringView,
  env~ : LexEnv,
  start~ : Int,
) -> (StringView, String) {
  let buf = StringBuilder::new()
  fn process(input : StringView) -> StringView {
    lexscan input with longest {
      (re"^\"", after=rest) => rest
      (re"^\\[\\\"nrt]" as raw, after=rest) => {
        buf.write_string(raw.to_owned())
        process(rest)
      }
      (re"^\\x([0-6][0-9a-fA-F]|7[0-7])" as raw, after=rest) => {
        buf.write_string(raw.to_owned())
        process(rest)
      }
      (re"^\\x[0-9a-fA-F]{2}" as raw, after=rest) => {
        env.add_error(
          InvalidHexEscape(raw.to_owned()),
          start=env.calc_offset(input, base~),
          end=env.calc_offset(rest, base~),
        )
        buf.write_string(raw.to_owned())
        process(rest)
      }
      (re"^\\." as raw, after=rest) => {
        env.add_error(
          InvalidStringEscape(raw.to_owned()),
          start=env.calc_offset(input, base~),
          end=env.calc_offset(rest, base~),
        )
        buf.write_string(raw.to_owned())
        process(rest)
      }
      (re"^[\x20-\x21\x23-\x5B\x5D-\x7E]+" as raw, after=rest) => {
        buf.write_string(raw.to_owned())
        process(rest)
      }
      (re"^(\r\n|\r|\n)", after=_) => {
        env.add_error(
          UnterminatedString,
          start~,
          end=env.calc_offset(input, base~),
        )
        input
      }
      re"^$" => {
        env.add_error(
          UnterminatedString,
          start~,
          end=env.calc_offset(input, base~),
        )
        input
      }
      (re"^." as raw, after=rest) => {
        if raw.to_int() > 127 {
          env.add_error(
            NonAsciiStringCharacter,
            start=env.calc_offset(input, base~),
            end=env.calc_offset(rest, base~),
          )
        } else {
          env.add_error(
            UnterminatedString,
            start=env.calc_offset(input, base~),
            end=env.calc_offset(rest, base~),
          )
        }
        process(rest)
      }
      _ => panic()
    }
  }

  let rest = process(input)
  (rest, buf.to_string())
}
