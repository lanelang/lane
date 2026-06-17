///|
priv struct LexEnv {
  tokens : Array[(Token, SourceSpan)]
  errors : Array[LexError]
  mut current_line : Int
  mut current_bol : Int
}

///|
fn LexEnv::calc_offset(
  _self : LexEnv,
  view : StringView,
  base~ : StringView,
) -> Int {
  view.start_offset() - base.start_offset()
}

///|
fn LexEnv::span(self : LexEnv, start~ : Int, end~ : Int) -> SourceSpan {
  {
    start_offset: start,
    end_offset: end,
    start_line: self.current_line,
    start_column: start - self.current_bol + 1,
    end_line: self.current_line,
    end_column: end - self.current_bol + 1,
  }
}

///|
fn LexEnv::add_token(
  self : LexEnv,
  token : Token,
  start~ : Int,
  end~ : Int,
) -> Unit {
  self.tokens.push((token, self.span(start~, end~)))
}

///|
fn LexEnv::add_error(
  self : LexEnv,
  error : LexicalError,
  start~ : Int,
  end~ : Int,
) -> Unit {
  self.errors.push({ error, span: self.span(start~, end~) })
}

///|
fn LexEnv::newline(self : LexEnv, end~ : Int) -> Unit {
  self.current_line += 1
  self.current_bol = end
}
