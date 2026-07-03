///|
pub(all) struct SourceFile {
  id : @core.SourceId
  path : String?
  text : String
  line_starts : Array[Int]
  char_line_starts : Array[Int]
  byte_to_text_offsets : Array[Int]
  text_to_byte_offsets : Array[Int]
} derive(Debug, Eq)

///|
pub(all) struct SourceDatabase {
  files : Array[SourceFile]
} derive(Debug, Eq)

///|
pub(all) struct SourcePosition {
  line : Int
  column : Int
} derive(Debug, Eq)

///|
pub(all) struct SourceRange {
  start : SourcePosition
  end : SourcePosition
} derive(Debug, Eq)

///|
pub fn SourceDatabase::SourceDatabase() -> SourceDatabase {
  { files: [] }
}

///|
pub fn SourceDatabase::add(
  self : SourceDatabase,
  text : String,
  path? : String,
) -> @core.SourceId {
  let id = @core.SourceId::{ value: self.files.length() }
  let metrics = source_metrics(text)
  self.files.push({
    id,
    path,
    text,
    line_starts: metrics.byte_line_starts,
    char_line_starts: metrics.text_line_starts,
    byte_to_text_offsets: metrics.byte_to_text_offsets,
    text_to_byte_offsets: metrics.text_to_byte_offsets,
  })
  id
}

///|
pub fn SourceDatabase::file(
  self : SourceDatabase,
  id : @core.SourceId,
) -> SourceFile? {
  self.files.get(id.value)
}

///|
pub fn SourceDatabase::span(
  self : SourceDatabase,
  id : @core.SourceId,
  start_offset : Int,
  end_offset : Int,
) -> @core.SourceSpan {
  ignore(self)
  { source_id: id, start_offset, end_offset }
}

///|
pub fn SourceDatabase::span_from_text_offsets(
  self : SourceDatabase,
  id : @core.SourceId,
  start_offset : Int,
  end_offset : Int,
) -> @core.SourceSpan {
  guard self.file(id) is Some(file) else {
    return { source_id: id, start_offset, end_offset }
  }
  {
    source_id: id,
    start_offset: file.byte_offset_for_text_offset(start_offset),
    end_offset: file.byte_offset_for_text_offset(end_offset),
  }
}

///|
pub fn SourceDatabase::line_text(
  self : SourceDatabase,
  id : @core.SourceId,
  line : Int,
) -> String? {
  guard self.file(id) is Some(file) else { return None }
  file.line_text(line)
}

///|
pub fn SourceDatabase::position(
  self : SourceDatabase,
  span : @core.SourceSpan,
) -> SourcePosition? {
  guard self.file(span.source_id) is Some(file) else { return None }
  Some(file.position(span.start_offset))
}

///|
pub fn SourceDatabase::range(
  self : SourceDatabase,
  span : @core.SourceSpan,
) -> SourceRange? {
  guard self.file(span.source_id) is Some(file) else { return None }
  Some({
    start: file.position(span.start_offset),
    end: file.position(span.end_offset),
  })
}

///|
pub fn SourceFile::display_name(self : SourceFile) -> String {
  match self.path {
    Some(path) => path
    None => "<source#\{self.id.value}>"
  }
}

///|
pub fn SourceFile::position(self : SourceFile, offset : Int) -> SourcePosition {
  let offset = clamp_offset(offset, self.byte_length())
  let mut line_index = 0
  for index in 0..<self.line_starts.length() {
    if self.line_starts[index] <= offset {
      line_index = index
    } else {
      break
    }
  }
  let text_offset = self.text_offset_for_byte_offset(offset)
  let column = text_offset - self.char_line_starts[line_index] + 1
  { line: line_index + 1, column }
}

///|
pub fn SourceFile::line_text(self : SourceFile, line : Int) -> String? {
  if line < 1 || line > self.char_line_starts.length() {
    return None
  }
  let start = self.char_line_starts[line - 1]
  let end = if line < self.char_line_starts.length() {
    self.char_line_starts[line] - 1
  } else {
    self.text.length()
  }
  Some(trim_line_ending(self.text[start:end].to_owned()))
}

///|
pub fn SourceFile::byte_offset_for_text_offset(
  self : SourceFile,
  offset : Int,
) -> Int {
  let offset = clamp_offset(offset, self.text_to_byte_offsets.length() - 1)
  self.text_to_byte_offsets[offset]
}

///|
pub fn SourceFile::text_offset_for_byte_offset(
  self : SourceFile,
  offset : Int,
) -> Int {
  let offset = clamp_offset(offset, self.byte_to_text_offsets.length() - 1)
  self.byte_to_text_offsets[offset]
}

///|
pub fn SourceFile::byte_length(self : SourceFile) -> Int {
  self.byte_to_text_offsets.length() - 1
}

///|
priv struct SourceMetrics {
  byte_line_starts : Array[Int]
  text_line_starts : Array[Int]
  byte_to_text_offsets : Array[Int]
  text_to_byte_offsets : Array[Int]
}

///|
fn source_metrics(text : String) -> SourceMetrics {
  let byte_line_starts = [0]
  let text_line_starts = [0]
  let byte_to_text_offsets = [0]
  let text_to_byte_offsets = [0]
  let mut byte_offset = 0
  let mut text_offset = 0
  for char in text {
    let byte_width = utf8_byte_width(char)
    let text_width = char.utf16_len()
    byte_offset += byte_width
    text_offset += text_width
    for _ in 0..<byte_width {
      byte_to_text_offsets.push(text_offset)
    }
    for _ in 0..<text_width {
      text_to_byte_offsets.push(byte_offset)
    }
    if char == '\n' {
      byte_line_starts.push(byte_offset)
      text_line_starts.push(text_offset)
    }
  }
  {
    byte_line_starts,
    text_line_starts,
    byte_to_text_offsets,
    text_to_byte_offsets,
  }
}

///|
fn utf8_byte_width(char : Char) -> Int {
  let code = char.to_int()
  if code <= 0x7F {
    1
  } else if code <= 0x7FF {
    2
  } else if code <= 0xFFFF {
    3
  } else {
    4
  }
}

///|
fn trim_line_ending(text : String) -> String {
  if text.length() > 0 && text[text.length() - 1] == '\r' {
    text[:text.length() - 1].to_owned()
  } else {
    text
  }
}

///|
fn clamp_offset(offset : Int, length : Int) -> Int {
  if offset < 0 {
    0
  } else if offset > length {
    length
  } else {
    offset
  }
}
