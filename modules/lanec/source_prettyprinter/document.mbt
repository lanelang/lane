///|
enum Document {
  Empty
  Line
  Space
  MandatoryLine
  MandatorySpace
  Text(String)
  LineComment(String)
  Concat(Requirement, Document, Document)
  Group(Requirement, Document)
  Switch(Requirement, Document, Document)
  Nest(Requirement, Int, Document)
  Dynamic(Requirement, (Context) -> Document)
}

///|
pub struct Context {
  indent : Int
  next_indent : Int
  width : Int
}

///|
pub impl Show for Context with fn output(self, buf) {
  buf.write_string("{ indent: ")
  buf.write_string(self.indent.to_string())
  buf.write_string(", next_indent: ")
  buf.write_string(self.next_indent.to_string())
  buf.write_string(", width: ")
  buf.write_string(self.width.to_string())
  buf.write_string(" }")
}

///|
pub fn Context::current_remain(self : Self) -> Requirement {
  Space(@cmp.maximum(0, self.width - self.indent))
}

///|
pub fn Context::next_remain(self : Self) -> Requirement {
  Space(@cmp.maximum(0, self.width - self.next_indent))
}

///|
priv struct State {
  indent : Int
  fit : Bool
  doc : Document
}

///|
fn render_document(width : Int, doc : Document) -> String {
  let buf = StringBuilder::new()
  let stack = [{ indent: 0, fit: false, doc }]
  let mut column = 0
  // record the MandatoryLine that has not yet been decided to print
  let mut dangling_newline : Int? = None
  // record the MandatorySpace that has not yet been decided to print
  let mut dangling_space : Bool = false
  let mut line_comment_pending : Bool = false
  let mut has_leading_space : Bool = false
  let mut has_leading_newline : Bool = false
  fn write_newline(indent) {
    buf.write_char('\n')
    for _ in 0..<indent {
      buf.write_char(' ')
    }
  }

  while stack.pop() is Some({ indent, fit, doc }) {
    match doc {
      Empty => ()
      Line => {
        line_comment_pending = false
        has_leading_newline = true
        write_newline(indent)
        column = indent
      }
      Space =>
        if !line_comment_pending {
          has_leading_space = true
          buf.write_char(' ')
          column += 1
        }
      Text(s) => {
        if line_comment_pending {
          write_newline(indent)
          column = indent
          has_leading_newline = true
          line_comment_pending = false
        }
        if dangling_newline is Some(indent) && !has_leading_newline {
          write_newline(indent)
          column = indent
        }
        if dangling_space && !has_leading_space && !has_leading_newline {
          buf.write_char(' ')
        }
        has_leading_space = false
        has_leading_newline = false
        dangling_space = false
        dangling_newline = None
        buf.write_string(s)
        column += s.length()
      }
      LineComment(s) => {
        if line_comment_pending {
          write_newline(indent)
          column = indent
        } else if !has_leading_space && !has_leading_newline {
          buf.write_char(' ')
          column += 1
        }
        has_leading_space = false
        has_leading_newline = false
        dangling_space = false
        dangling_newline = None
        buf.write_string(s)
        column += s.length()
        line_comment_pending = true
      }
      Concat(_, l, r) => {
        stack.push({ indent, fit, doc: r })
        stack.push({ indent, fit, doc: l })
      }
      Nest(_, i, d) => stack.push({ indent: indent + i, fit, doc: d })
      Switch(_, a, b) =>
        stack.push(
          if fit {
            { indent, fit, doc: a }
          } else {
            { indent, fit, doc: b }
          },
        )
      Group(req, d) => {
        let fit = fit || Requirement::Space(column) + req <= Space(width)
        stack.push({ indent, fit, doc: d })
      }
      MandatoryLine =>
        if !line_comment_pending {
          dangling_newline = Some(indent)
        }
      MandatorySpace => if !line_comment_pending { dangling_space = true }
      Dynamic(_, f) => {
        let doc = f({ indent: column, width, next_indent: indent })
        stack.push({ indent, fit, doc })
      }
    }
  }
  buf.to_string()
}

///|
pub impl Show for Document with fn output(self, buf) {
  buf.write_string(render_document(80, self))
}

///|
pub impl Add for Document with fn add(self, other) {
  concat(self, other)
}

///|
pub fn Document::to_generic(self : Document) -> @generic_prettyprinter.Document {
  match self {
    Empty => @generic_prettyprinter.empty
    Line => @generic_prettyprinter.hardline
    Space => @generic_prettyprinter.space
    MandatoryLine => @generic_prettyprinter.mandatory_line
    MandatorySpace => @generic_prettyprinter.mandatory_space
    Text(value) => @generic_prettyprinter.text(value)
    LineComment(value) => @generic_prettyprinter.text(value)
    Concat(_, left, right) => left.to_generic() + right.to_generic()
    Group(_, document) => @generic_prettyprinter.group(document.to_generic())
    Switch(_, flat, broken) =>
      @generic_prettyprinter.switch(flat.to_generic(), broken.to_generic())
    Nest(_, indent, document) =>
      @generic_prettyprinter.nest(document.to_generic(), indent~)
    Dynamic(_, build) =>
      @generic_prettyprinter.dynamic(fn(context) {
        build({
          indent: context.indent,
          next_indent: context.next_indent,
          width: context.width,
        }).to_generic()
      })
  }
}
