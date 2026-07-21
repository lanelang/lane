///|
pub(all) struct SourceSpan {
  start_offset : Int
  end_offset : Int
  start_line : Int
  start_column : Int
  end_line : Int
  end_column : Int
} derive(Debug, Eq)

///|
/// Returns a source span that starts at `start` and ends at `end`.
pub fn SourceSpan::join(start : SourceSpan, end : SourceSpan) -> SourceSpan {
  {
    start_offset: start.start_offset,
    end_offset: end.end_offset,
    start_line: start.start_line,
    start_column: start.start_column,
    end_line: end.end_line,
    end_column: end.end_column,
  }
}

///|
/// Returns a zero-width placeholder span for compiler-created nodes.
pub fn SourceSpan::dummy() -> SourceSpan {
  {
    start_offset: 0,
    end_offset: 0,
    start_line: 1,
    start_column: 1,
    end_line: 1,
    end_column: 1,
  }
}

///|
/// Returns the leading ASCII subspan with `length` bytes.
pub fn SourceSpan::ascii_prefix(self : SourceSpan, length : Int) -> SourceSpan {
  {
    ..self,
    end_offset: self.start_offset + length,
    end_line: self.start_line,
    end_column: self.start_column + length,
  }
}

///|
/// Returns the trailing ASCII subspan with `length` bytes.
pub fn SourceSpan::ascii_suffix(self : SourceSpan, length : Int) -> SourceSpan {
  {
    ..self,
    start_offset: self.end_offset - length,
    start_line: self.end_line,
    start_column: self.end_column - length,
  }
}

///|
/// Returns an ASCII subspan immediately after this span and a separator.
pub fn SourceSpan::ascii_after(
  self : SourceSpan,
  separator_length : Int,
  length : Int,
) -> SourceSpan {
  let start_offset = self.end_offset + separator_length
  let start_column = self.end_column + separator_length
  {
    start_offset,
    end_offset: start_offset + length,
    start_line: self.end_line,
    start_column,
    end_line: self.end_line,
    end_column: start_column + length,
  }
}
