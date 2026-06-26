///|
pub(all) enum Token {
  IDENT(String)
  INT(String)
  STRING(String)
  BUSLANE_BLOCK(String)
  EOF
  LBRACE
  RBRACE
  COLON
  SEMI
  DOT
  MINUS
} derive(Debug)

///|
pub fn Token::kind(self : Token) -> TokenKind {
  match self {
    IDENT(_) => TK_IDENT
    INT(_) => TK_INT
    STRING(_) => TK_STRING
    BUSLANE_BLOCK(_) => TK_BUSLANE_BLOCK
    EOF => TK_EOF
    LBRACE => TK_LBRACE
    RBRACE => TK_RBRACE
    COLON => TK_COLON
    SEMI => TK_SEMI
    DOT => TK_DOT
    MINUS => TK_MINUS
  }
}

///|
pub(all) enum TokenKind {
  TK_IDENT
  TK_INT
  TK_STRING
  TK_BUSLANE_BLOCK
  TK_EOF
  TK_LBRACE
  TK_RBRACE
  TK_COLON
  TK_SEMI
  TK_DOT
  TK_MINUS
} derive(Eq, Hash, Compare)

///|
pub impl Show for TokenKind with fn output(self, logger) {
  logger.write_string(
    match self {
      TK_IDENT => "IDENT"
      TK_INT => "INT"
      TK_STRING => "STRING"
      TK_BUSLANE_BLOCK => "BUSLANE_BLOCK"
      TK_EOF => "EOF"
      TK_LBRACE => "\"{\""
      TK_RBRACE => "\"}\""
      TK_COLON => "\":\""
      TK_SEMI => "\";\""
      TK_DOT => "\".\""
      TK_MINUS => "\"-\""
    },
  )
}

///|
pub impl Debug for TokenKind with fn to_repr(self) {
  match self {
    TK_IDENT => to_repr("IDENT")
    TK_INT => to_repr("INT")
    TK_STRING => to_repr("STRING")
    TK_BUSLANE_BLOCK => to_repr("BUSLANE_BLOCK")
    TK_EOF => to_repr("EOF")
    TK_LBRACE => to_repr("{")
    TK_RBRACE => to_repr("}")
    TK_COLON => to_repr(":")
    TK_SEMI => to_repr(";")
    TK_DOT => to_repr(".")
    TK_MINUS => to_repr("-")
  }
}

///|
pub suberror ParseError {
  UnexpectedToken(Token, (SourceSpan, SourceSpan), Array[TokenKind])
  UnexpectedEndOfInput(SourceSpan, Array[TokenKind])
} derive(Debug)

///|
type YYObj = Error

///|
priv suberror YYObj_Void

///|
priv suberror YYObj_Array_ArtifactEntry_ {
  YYObj_Array_ArtifactEntry_(Array[ArtifactEntry])
}

///|
priv suberror YYObj_String {
  YYObj_String(String)
}

///|
priv suberror YYObj_ArtifactEntry {
  YYObj_ArtifactEntry(ArtifactEntry)
}

///|
priv suberror YYObj_ArtifactValue {
  YYObj_ArtifactValue(ArtifactValue)
}

///|
priv suberror YYObj_ArtifactDocument {
  YYObj_ArtifactDocument(ArtifactDocument)
}

///|
type YYState = (YYSymbol) -> YYDecision

///|
type YYAction = (SourceSpan, ArrayView[(YYObj, SourceSpan, SourceSpan)]) -> YYObj

///|
priv enum YYDecision {
  Accept
  Shift(YYState)
  Reduce(Int, YYSymbol, YYAction)
  ReduceNoLookahead(Int, YYSymbol, YYAction)
  Error
}

///|
priv enum YYSymbol {
  T_IDENT
  T_INT
  T_STRING
  T_BUSLANE_BLOCK
  T_EOF
  T_LBRACE
  T_RBRACE
  T_COLON
  T_SEMI
  T_DOT
  T_MINUS
  NT_artifact_document
  NT_entries
  NT_entry
  NT_field_name
  NT_value
  EOI
}

// Workaround for EOI unused warning

///|
fn init {
  match (EOI : YYSymbol) {
    EOI => ()
    _ => ()
  }
}

// file:///./parser.mbty
// 25|    IDENT IDENT "{" entries "}" EOF {
// 26|    make_document($1, $2, $4)
// 27|  }

///|
fn yy_action_0(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[1].0 is YYObj_String(_dollar2)
  guard _args[3].0 is YYObj_Array_ArtifactEntry_(_dollar4)
  YYObj_ArtifactDocument(
    {
      ()
      make_document(_dollar1, _dollar2, _dollar4)
    },
  )
}

// file:///./parser.mbty
// 32|    entries entry { comma_push($1, $2) }

///|
fn yy_action_1(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_Array_ArtifactEntry_(_dollar1)
  guard _args[1].0 is YYObj_ArtifactEntry(_dollar2)
  YYObj_Array_ArtifactEntry_(
    {
      ()
      comma_push(_dollar1, _dollar2)
    },
  )
}

// file:///./parser.mbty
// 36|    field_name ";" { Tag($1) }

///|
fn yy_action_2(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_ArtifactEntry(
    {
      ()
      Tag(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 37|    field_name ":" value ";" { Value($1, $3) }

///|
fn yy_action_3(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[2].0 is YYObj_ArtifactValue(_dollar3)
  YYObj_ArtifactEntry(
    {
      ()
      Value(_dollar1, _dollar3)
    },
  )
}

// file:///./parser.mbty
// 47|    IDENT { Atom($1) }

///|
fn yy_action_4(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_ArtifactValue(
    {
      ()
      Atom(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 48|    INT { Atom($1) }

///|
fn yy_action_5(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_ArtifactValue(
    {
      ()
      Atom(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 49|    "-" INT { Atom("-" + $2) }

///|
fn yy_action_6(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[1].0 is YYObj_String(_dollar2)
  YYObj_ArtifactValue(
    {
      ()
      Atom("-" + _dollar2)
    },
  )
}

// file:///./parser.mbty
// 50|    STRING { Text($1) }

///|
fn yy_action_7(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_ArtifactValue(
    {
      ()
      Text(_dollar1)
    },
  )
}

// file:///./parser.mbty
// 43|    field_name "." IDENT { extend_name($1, $3) }

///|
fn yy_action_8(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  guard _args[2].0 is YYObj_String(_dollar3)
  YYObj_String(
    {
      ()
      extend_name(_dollar1, _dollar3)
    },
  )
}

// file:///./parser.mbty
// 38|    BUSLANE_BLOCK { Block("buslane", $1) }

///|
fn yy_action_9(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_ArtifactEntry(
    {
      ()
      Block("buslane", _dollar1)
    },
  )
}

// file:///./parser.mbty
// 42|    IDENT { $1 }

///|
fn yy_action_10(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  guard _args[0].0 is YYObj_String(_dollar1)
  YYObj_String(
    {
      ()
      _dollar1
    },
  )
}

// file:///./parser.mbty
// 31|    { [] }

///|
fn yy_action_11(
  _last_pos : SourceSpan,
  _args : ArrayView[(YYObj, SourceSpan, SourceSpan)],
) -> YYObj {
  YYObj_Array_ArtifactEntry_(
    {
      ()
      []
    },
  )
}

///|
fn yy_input(
  token : Token,
  _start_pos : SourceSpan,
  _end_pos : SourceSpan,
) -> (YYSymbol, YYObj) {
  match token {
    IDENT(data) => (T_IDENT, YYObj_String(data))
    INT(data) => (T_INT, YYObj_String(data))
    STRING(data) => (T_STRING, YYObj_String(data))
    BUSLANE_BLOCK(data) => (T_BUSLANE_BLOCK, YYObj_String(data))
    EOF => (T_EOF, YYObj_Void)
    LBRACE => (T_LBRACE, YYObj_Void)
    RBRACE => (T_RBRACE, YYObj_Void)
    COLON => (T_COLON, YYObj_Void)
    SEMI => (T_SEMI, YYObj_Void)
    DOT => (T_DOT, YYObj_Void)
    MINUS => (T_MINUS, YYObj_Void)
  }
}

///|
fn yy_state_0(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_artifact_document => Shift(yy_state_1)
    T_IDENT => Shift(yy_state_2)
    _ => Error
  }
}

///|
fn yy_state_1(_lookahead : YYSymbol) -> YYDecision {
  Accept
}

///|
fn yy_state_2(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_3)
    _ => Error
  }
}

///|
fn yy_state_3(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_LBRACE => Shift(yy_state_4)
    _ => Error
  }
}

///|
fn yy_state_4(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    NT_entries => Shift(yy_state_5)
    T_IDENT | T_BUSLANE_BLOCK | T_RBRACE => Reduce(0, NT_entries, yy_action_11)
    _ => Error
  }
}

///|
fn yy_state_5(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_6)
    T_BUSLANE_BLOCK => Shift(yy_state_7)
    NT_field_name => Shift(yy_state_8)
    NT_entry => Shift(yy_state_20)
    T_RBRACE => Shift(yy_state_21)
    _ => Error
  }
}

///|
fn yy_state_6(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_field_name, yy_action_10)
}

///|
fn yy_state_7(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_entry, yy_action_9)
}

///|
fn yy_state_8(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_DOT => Shift(yy_state_9)
    T_COLON => Shift(yy_state_11)
    T_SEMI => Shift(yy_state_19)
    _ => Error
  }
}

///|
fn yy_state_9(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_IDENT => Shift(yy_state_10)
    _ => Error
  }
}

///|
fn yy_state_10(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(3, NT_field_name, yy_action_8)
}

///|
fn yy_state_11(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_STRING => Shift(yy_state_12)
    T_MINUS => Shift(yy_state_13)
    T_INT => Shift(yy_state_15)
    T_IDENT => Shift(yy_state_16)
    NT_value => Shift(yy_state_17)
    _ => Error
  }
}

///|
fn yy_state_12(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value, yy_action_7)
}

///|
fn yy_state_13(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_INT => Shift(yy_state_14)
    _ => Error
  }
}

///|
fn yy_state_14(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_value, yy_action_6)
}

///|
fn yy_state_15(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value, yy_action_5)
}

///|
fn yy_state_16(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(1, NT_value, yy_action_4)
}

///|
fn yy_state_17(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_SEMI => Shift(yy_state_18)
    _ => Error
  }
}

///|
fn yy_state_18(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(4, NT_entry, yy_action_3)
}

///|
fn yy_state_19(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_entry, yy_action_2)
}

///|
fn yy_state_20(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(2, NT_entries, yy_action_1)
}

///|
fn yy_state_21(_lookahead : YYSymbol) -> YYDecision {
  match _lookahead {
    T_EOF => Shift(yy_state_22)
    _ => Error
  }
}

///|
fn yy_state_22(_lookahead : YYSymbol) -> YYDecision {
  ReduceNoLookahead(6, NT_artifact_document, yy_action_0)
}

///|
fn[T] yy_parse(
  tokens : Array[(Token, SourceSpan, SourceSpan)],
  start : YYState,
  return_ : (YYObj) -> T,
  initial_pos? : SourceSpan,
) -> T raise ParseError {
  let mut cursor = 0
  let mut state_stack : @list.List[YYState] = @list.cons(start, @list.empty())
  let data_stack : Array[(YYObj, SourceSpan, SourceSpan)] = []
  let mut last_pos = initial_pos.unwrap_or(tokens[0].1)
  let mut state = start
  let mut lookahead : (YYSymbol, (YYObj, SourceSpan, SourceSpan), Token?)? = None
  let mut last_shifted_state_stack = state_stack
  while true {
    let decision = match state(EOI) {
      ReduceNoLookahead(_) | Accept as t => t
      _ =>
        match lookahead {
          Some(la) => state(la.0)
          None =>
            if cursor < tokens.length() {
              let (token, start_pos, end_pos) = tokens[cursor]
              cursor += 1
              let (symbol, data) = yy_input(token, start_pos, end_pos)
              lookahead = Some(
                (symbol, (data, start_pos, end_pos), Some(token)),
              )
              state(symbol)
            } else {
              lookahead = Some((EOI, (YYObj_Void, last_pos, last_pos), None))
              state(EOI)
            }
        }
    }
    match decision {
      Accept => return return_(data_stack.unsafe_pop().0)
      Shift(next_state) => {
        guard lookahead is Some(la)
        data_stack.push(la.1)
        state_stack = @list.cons(next_state, state_stack)
        last_shifted_state_stack = state_stack
        state = next_state
        last_pos = la.1.2
        lookahead = None
      }
      Reduce(count, symbol, action)
      | ReduceNoLookahead(count, symbol, action) =>
        for count = count, symbol = symbol, action = action {
          let args = data_stack[data_stack.length() - count:]
          let data = action(last_pos, args)
          let (start_pos, end_pos) = if args.length() == 0 {
            (last_pos, last_pos)
          } else {
            (args[0].1, args[args.length() - 1].2)
          }
          for _ in 0..<count {
            ignore(data_stack.unsafe_pop())
            state_stack = state_stack.unsafe_tail()
          }
          state = state_stack.unsafe_head()
          data_stack.push((data, start_pos, end_pos))
          match state(symbol) {
            Accept => return return_(data_stack.unsafe_pop().0)
            Shift(next_state) => {
              state_stack = @list.cons(next_state, state_stack)
              state = next_state
              break ()
            }
            Reduce(count, symbol, action)
            | ReduceNoLookahead(count, symbol, action) =>
              continue count, symbol, action
            _ => panic()
          }
        }
      Error => {
        let (_, (_, start_pos, end_pos), token) = lookahead.unwrap()
        error(last_shifted_state_stack, token, (start_pos, end_pos))
      }
    }
  }
  panic()
}

///|
fn error(
  stack : @list.List[YYState],
  token : Token?,
  loc : (SourceSpan, SourceSpan),
) -> Unit raise ParseError {
  let expected = []
  fn try_add(symbol : YYSymbol, kind : TokenKind) {
    fn go(stack : @list.List[YYState]) {
      match stack {
        Empty => ()
        More(state, ..) =>
          match state(symbol) {
            Accept | Shift(_) => expected.push(kind)
            Reduce(count, symbol, _) | ReduceNoLookahead(count, symbol, _) => {
              fn inner_go(stack : @list.List[YYState], count, symbol) {
                let stack = stack.drop(count)
                guard stack is More(state, ..)
                match state(symbol) {
                  Shift(state) => go(@list.cons(state, stack))
                  Reduce(count, symbol, _)
                  | ReduceNoLookahead(count, symbol, _) =>
                    inner_go(stack, count, symbol)
                  _ => panic()
                }
              }
              inner_go(stack, count, symbol)
            }
            Error => ()
          }
      }
    }
    go(stack)
  }
  for
    term in (
      [
        (T_IDENT, TK_IDENT),
        (T_INT, TK_INT),
        (T_STRING, TK_STRING),
        (T_BUSLANE_BLOCK, TK_BUSLANE_BLOCK),
        (T_EOF, TK_EOF),
        (T_LBRACE, TK_LBRACE),
        (T_RBRACE, TK_RBRACE),
        (T_COLON, TK_COLON),
        (T_SEMI, TK_SEMI),
        (T_DOT, TK_DOT),
        (T_MINUS, TK_MINUS),
      ] : Array[(YYSymbol, TokenKind)]) {
    try_add(term.0, term.1)
  }
  match token {
    None => raise UnexpectedEndOfInput(loc.1, expected)
    Some(token) => raise UnexpectedToken(token, loc, expected)
  }
}

///|
pub fn artifact_document(
  tokens : Array[(Token, SourceSpan, SourceSpan)],
  initial_pos? : SourceSpan,
) -> ArtifactDocument raise ParseError {
  yy_parse(
    tokens,
    yy_state_0,
    it => {
      guard it is YYObj_ArtifactDocument(result)
      result
    },
    initial_pos?,
  )
}
