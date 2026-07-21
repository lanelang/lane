///|
fn assert_format(
  source : String,
  expected : String,
  width? : Int = 100,
) -> Unit raise {
  let options = FormatOptions::{ width, }
  let result = format_source_with_options(source, options)
  guard result is Ok(formatted) else {
    debug_inspect(result)
    abort("expected formatted source")
  }
  assert_eq(canonical_syntax(formatted), canonical_syntax(source))
  assert_eq(formatted, expected)
  if line_comments(formatted) != line_comments(source) {
    abort("formatted source lost or reordered line comments")
  }
  guard format_source_with_options(formatted, options) is Ok(reformatted) else {
    abort("expected formatted source to parse after formatting")
  }
  assert_eq(reformatted, formatted)
}

///|
fn canonical_syntax(source : String) -> String {
  guard @parser.parse_string(source) is Parsed(parsed) else {
    abort("expected syntax for formatter equivalence check")
  }
  @prettyprinter.render(parsed.syntax, width=100)
}

///|
test "format source preserves omitted struct type member kinds" {
  assert_format(
    "module Test\nstruct Packed { type T; value : T }\nstruct Explicit { type T : Type; value : T }",
    (
      #|module Test
      #|
      #|struct Packed {
      #|  type T
      #|  value : T
      #|}
      #|
      #|struct Explicit {
      #|  type T : Type
      #|  value : T
      #|}
      #|
    ),
  )
}

///|
test "formatter consumes the complete trivia attachment view" {
  let source =
    #|// leading module
    #|module Test
    #|pub fn add(left : Int, right : Int) -> Int { left + right }
    #|pub let answer : Int = add(
    #|  20, // before second
    #|  22 // trailing second
    #|)
    #|// eof comment
  guard @parser.parse_string(source) is Parsed(parsed) else {
    abort("expected parsed source")
  }
  let trivia = ConcreteLayout::make(
    parsed.concrete,
    parsed.layout_separator_gaps,
  ).start_session()
  ignore(
    @prettyprinter.render(
      @syntax.format_source_file_with_trivia(
        parsed.syntax,
        trivia.source_format_trivia(),
      ),
      width=100,
    ),
  )
  debug_inspect(
    trivia.layout.comments.mapi(fn(index, comment) {
      let placement = match comment.placement {
        Leading(span) => ("leading", span.start_offset, span.end_offset)
        Trailing(span) => ("trailing", span.start_offset, span.end_offset)
        Boundary => ("boundary", -1, -1)
        EndOfFile => ("eof", -1, -1)
      }
      (
        comment.text,
        comment.span.start_offset,
        comment.span.end_offset,
        placement,
        comment.blank_before,
        comment.blank_after,
        trivia.claimed[index],
      )
    }),
    content=(
      #|[
      #|  ("// leading module", 0, 17, ("leading", 18, 24), false, false, true),
      #|  (
      #|    "// before second",
      #|    124,
      #|    140,
      #|    ("boundary", -1, -1),
      #|    false,
      #|    false,
      #|    true,
      #|  ),
      #|  (
      #|    "// trailing second",
      #|    146,
      #|    164,
      #|    ("trailing", 143, 145),
      #|    false,
      #|    false,
      #|    true,
      #|  ),
      #|  ("// eof comment", 167, 181, ("eof", -1, -1), false, false, true),
      #|]
    ),
  )
}

///|
fn line_comments(source : String) -> Array[String] {
  let result = @lexer.tokens_from_string(source)
  result.concrete.trivia.filter_map(fn(item) {
    if item.kind is LineComment {
      Some(
        result.concrete.source_text.unsafe_substring(
          start=item.span.start_offset,
          end=item.span.end_offset,
        ),
      )
    } else {
      None
    }
  })
}

///|
test "concrete layout indexes nested delimiter pairs" {
  let concrete = @lexer.tokens_from_string("(([.{ }]))").concrete
  let layout = ConcreteLayout::make(
    concrete,
    Array::make(non_eof_tokens(concrete.tokens).length() + 1, false),
  )
  debug_inspect(
    [
      layout.delimiter_pairs.interior('(', 0, 10),
      layout.delimiter_pairs.interior('(', 1, 9),
      layout.delimiter_pairs.interior('[', 0, 10),
      layout.delimiter_pairs.interior('{', 0, 10),
      layout.delimiter_pairs.interior('[', 3, 10),
      layout.delimiter_pairs.interior('(', 0, 9),
    ],
    content=(
      #|[Some((1, 9)), Some((2, 8)), Some((3, 7)), Some((5, 6)), None, None]
    ),
  )
}

///|
test "formatter reports unconsumed concrete comments" {
  let source =
    #|module Test
    #|// unconsumed
    #|pub let answer : Int = 42
  guard @parser.parse_string(source) is Parsed(parsed) else {
    abort("expected parsed source")
  }
  let trivia = ConcreteLayout::make(
    parsed.concrete,
    parsed.layout_separator_gaps,
  ).start_session()
  ignore(trivia.source_format_trivia())
  debug_inspect(
    trivia
    .unconsumed_comment_diagnostics()
    .map(fn(diagnostic) {
      (diagnostic.message, diagnostic.code, diagnostic.span)
    }),
    content=(
      #|[
      #|  (
      #|    "formatter could not preserve a source comment",
      #|    Some("E1103"),
      #|    Some(
      #|      Local(
      #|        {
      #|          start_offset: 12,
      #|          end_offset: 25,
      #|          start_line: 2,
      #|          start_column: 1,
      #|          end_line: 2,
      #|          end_column: 14,
      #|        },
      #|      ),
      #|    ),
      #|  ),
      #|]
    ),
  )
}

///|
test "format source normalizes whitespace and final newline" {
  let source =
    #|module   Test
    #|pub   let answer   :   Int=42
  assert_format(
    source,
    (
      #|module Test
      #|
      #|pub let answer : Int = 42
      #|
    ),
  )
}

///|
test "format source keeps consecutive imports together" {
  assert_format(
    (
      #|module Test
      #|
      #|import Basic.Io.{ println }
      #|
      #|import Basic.Ops.*
      #|
      #|import Basic.Data.List.{ List }
      #|
      #|pub let answer : Int = 42
    ),
    (
      #|module Test
      #|
      #|import Basic.Io.{ println }
      #|import Basic.Ops.*
      #|import Basic.Data.List.{ List }
      #|
      #|pub let answer : Int = 42
      #|
    ),
  )
}

///|
test "format source uses shorthand for redundant struct field values" {
  assert_format(
    (
      #|module Test
      #|
      #|pub let dictionary : Mappable = Mappable::{ map: map, apply: apply_map }
    ),
    (
      #|module Test
      #|
      #|pub let dictionary : Mappable = Mappable::{ map, apply: apply_map }
      #|
    ),
  )
}

///|
test "format source preserves explicit struct field values with comments" {
  assert_format(
    (
      #|module Test
      #|
      #|pub let dictionary : Mappable = Mappable::{
      #|  map:
      #|    // keep explicit spelling
      #|    map
      #|}
    ),
    (
      #|module Test
      #|
      #|pub let dictionary : Mappable = Mappable::{
      #|  map: // keep explicit spelling
      #|  map
      #|}
      #|
    ),
  )
}

///|
test "format source canonicalizes pure blank line gaps structurally" {
  assert_format(
    (
      #|module Test
      #|
      #|
      #|pub fn answer() -> Int {
      #|  let left : Int = 20
      #|
      #|
      #|  let right : Int = 22
      #|
      #|  left + right
      #|}
    ),
    (
      #|module Test
      #|
      #|pub fn answer() -> Int {
      #|  let left : Int = 20
      #|  let right : Int = 22
      #|  left + right
      #|}
      #|
    ),
  )
}

///|
test "format source reports parse diagnostics" {
  let result = format_source("module Test\npub let answer : =")
  guard result is Err(diagnostics) else { abort("expected diagnostics") }
  debug_inspect(
    diagnostics,
    content=(
      #|[
      #|  {
      #|    source_id: None,
      #|    message: "unexpected token",
      #|    span: Some(
      #|      Local(
      #|        {
      #|          start_offset: 29,
      #|          end_offset: 30,
      #|          start_line: 2,
      #|          start_column: 18,
      #|          end_line: 2,
      #|          end_column: 19,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Error,
      #|    code: Some("E1100"),
      #|    labels: [
      #|      {
      #|        span: Local(
      #|          {
      #|            start_offset: 29,
      #|            end_offset: 30,
      #|            start_line: 2,
      #|            start_column: 18,
      #|            end_line: 2,
      #|            end_column: 19,
      #|          },
      #|        ),
      #|        message: "the parser did not expect `=`",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: ["expected one of: identifier, `type`, `(`, `[`"],
      #|    helps: ["rewrite this position so it starts with one of: identifier, `type`, `(`, `[`"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|]
    ),
  )
}

///|
test "format source preserves leading line comment block" {
  assert_format(
    (
      #|// invalid: example title
      #|// second line
      #|
      #|module Test
      #|pub let answer : Int = 42
    ),
    (
      #|// invalid: example title
      #|// second line
      #|
      #|module Test
      #|
      #|pub let answer : Int = 42
      #|
    ),
  )
}

///|
test "format source keeps consecutive line comments compact inside blocks" {
  assert_format(
    (
      #|module Test
      #|pub fn main() -> Unit {
      #|// first note
      #|// second note
      #|()
      #|}
    ),
    (
      #|module Test
      #|
      #|pub fn main() -> Unit {
      #|  // first note
      #|  // second note
      #|  ()
      #|}
      #|
    ),
  )
}

///|
test "format sequential expressions as newline-separated items" {
  assert_format(
    (
      #|module Test
      #|pub fn print(value:String)->Unit { () }
      #|pub fn main()->Unit { print("hello"); // first
      #|print("world") }
    ),
    (
      #|module Test
      #|
      #|pub fn print(value : String) -> Unit {
      #|  ()
      #|}
      #|
      #|pub fn main() -> Unit {
      #|  print("hello") // first
      #|  print("world")
      #|}
      #|
    ),
  )
}

///|
test "format explicit layout separators canonically" {
  assert_format(
    (
      #|module Test
      #|struct Pair { left:Int; right:Int }
      #|enum Choice { Left(Int); Right(Int) }
      #|effect Console { read()->Int; write(String)->Unit }
      #|pub fn choose(value:Bool)->Int {
      #|match value { true => 1; false => 0 }
      #|}
    ),
    (
      #|module Test
      #|
      #|struct Pair {
      #|  left : Int
      #|  right : Int
      #|}
      #|
      #|enum Choice {
      #|  Left(Int)
      #|  Right(Int)
      #|}
      #|
      #|effect Console {
      #|  read() -> Int
      #|  write(String) -> Unit
      #|}
      #|
      #|pub fn choose(value : Bool) -> Int {
      #|  match value {
      #|    true => 1
      #|    false => 0
      #|  }
      #|}
      #|
    ),
  )
}

///|
test "format newline-separated expressions without adding semicolons" {
  assert_format(
    (
      #|module Test
      #|pub fn print(value:String)->Unit { () }
      #|pub fn main()->Unit {
      #|print("hello")
      #|print("world")
      #|}
    ),
    (
      #|module Test
      #|
      #|pub fn print(value : String) -> Unit {
      #|  ()
      #|}
      #|
      #|pub fn main() -> Unit {
      #|  print("hello")
      #|  print("world")
      #|}
      #|
    ),
  )
}

///|
test "format source preserves comments around declarations and blocks" {
  assert_format(
    (
      #|module   Test
      #|
      #|// before declaration
      #|pub   let answer   :   Int=42 // trailing declaration
      #|
      #|pub fn main()->Unit{
      #|// inside block
      #|()}
    ),
    (
      #|module Test
      #|
      #|// before declaration
      #|pub let answer : Int = 42 // trailing declaration
      #|
      #|pub fn main() -> Unit {
      #|  // inside block
      #|  ()
      #|}
      #|
    ),
  )
}

///|
test "format source preserves trailing module comments" {
  assert_format(
    (
      #|module Test // module tail
      #|pub let answer : Int = 42
    ),
    (
      #|module Test // module tail
      #|
      #|pub let answer : Int = 42
      #|
    ),
  )
}

///|
test "format source assigns a leading comment to one syntax node" {
  assert_format(
    (
      #|module Test
      #|// function docs
      #|pub fn answer() -> Int { 42 }
    ),
    (
      #|module Test
      #|
      #|// function docs
      #|pub fn answer() -> Int {
      #|  42
      #|}
      #|
    ),
  )
}

///|
test "format source keeps initializer comments with the initializer" {
  assert_format(
    (
      #|module Test
      #|pub let answer : Int =
      #|  // initializer
      #|  42
    ),
    (
      #|module Test
      #|
      #|pub let answer : Int =
      #|  // initializer
      #|  42
      #|
    ),
  )
}

///|
test "format source does not treat comment markers inside strings as comments" {
  assert_format(
    (
      #|module   Test
      #|pub   let url:String="http://example"
    ),
    (
      #|module Test
      #|
      #|pub let url : String = "http://example"
      #|
    ),
  )
}

///|
test "format source preserves comments in top-level and type bodies" {
  assert_format(
    (
      #|module   Test
      #|
      #|// before import
      #|import   Basic.Ops.* // trailing import
      #|
      #|// before effect
      #|effect Console{
      #|  // before operation
      #|  read()->Int // trailing operation
      #|}
      #|
      #|// before struct
      #|struct Pair{
      #|  // before field
      #|  left:Int
      #|  right:Int // trailing field
      #|}
      #|
      #|// before enum
      #|enum Option{
      #|  // before variant
      #|  none()
      #|  some(Int) // trailing variant
      #|}
    ),
    (
      #|module Test
      #|
      #|// before import
      #|import Basic.Ops.* // trailing import
      #|
      #|// before effect
      #|effect Console {
      #|  // before operation
      #|  read() -> Int // trailing operation
      #|}
      #|
      #|// before struct
      #|struct Pair {
      #|  // before field
      #|  left : Int
      #|  right : Int // trailing field
      #|}
      #|
      #|// before enum
      #|enum Option {
      #|  // before variant
      #|  none()
      #|  some(Int) // trailing variant
      #|}
      #|
    ),
  )
}

///|
test "format source preserves comments in control flow" {
  assert_format(
    (
      #|module   Test
      #|
      #|pub fn choose(input:Int)->Int{
      #|// before let
      #|let base:Int=input+1 // trailing let
      #|// before if
      #|if base==0{
      #|// then branch
      #|1
      #|}else{
      #|// else branch
      #|base
      #|}
      #|}
    ),
    (
      #|module Test
      #|
      #|pub fn choose(input : Int) -> Int {
      #|  // before let
      #|  let base : Int = input + 1 // trailing let
      #|  // before if
      #|  if base == 0 {
      #|    // then branch
      #|    1
      #|  } else {
      #|    // else branch
      #|    base
      #|  }
      #|}
      #|
    ),
  )
}

///|
test "format source preserves comments in match and handler arms" {
  assert_format(
    (
      #|module   Test
      #|
      #|effect Console{
      #|  read()->Int
      #|}
      #|
      #|enum Option{
      #|  none()
      #|  some(Int)
      #|}
      #|
      #|pub fn read_or_default(value:Option)->Int{
      #|match value{
      #|// none arm
      #|none()=>0 // trailing none arm
      #|// some arm
      #|some(x)=>x
      #|}
      #|}
      #|
      #|pub let handled:Int={
      #|handle{
      #|// before perform
      #|Console::read!()
      #|}with{
      #|// before handler arm
      #|Console::read(resume)=>resume(1) // trailing handler arm
      #|}final value{
      #|// final branch
      #|value
      #|}
      #|}
    ),
    (
      #|module Test
      #|
      #|effect Console {
      #|  read() -> Int
      #|}
      #|
      #|enum Option {
      #|  none()
      #|  some(Int)
      #|}
      #|
      #|pub fn read_or_default(value : Option) -> Int {
      #|  match value {
      #|    // none arm
      #|    none() => 0 // trailing none arm
      #|    // some arm
      #|    some(x) => x
      #|  }
      #|}
      #|
      #|pub let handled : Int = {
      #|  handle {
      #|    // before perform
      #|    Console::read!()
      #|  } with {
      #|    // before handler arm
      #|    Console::read(resume) => resume(1) // trailing handler arm
      #|  } final value {
      #|    // final branch
      #|    value
      #|  }
      #|}
      #|
    ),
  )
}

///|
test "format source preserves comments around literals and end of file" {
  assert_format(
    (
      #|module   Test
      #|
      #|struct Pair{
      #|left:Int
      #|right:Int
      #|}
      #|
      #|pub let pair:Pair=Pair::{
      #|// left value
      #|left:1,
      #|// right value
      #|right:2
      #|}
      #|
      #|// eof marker
    ),
    (
      #|module Test
      #|
      #|struct Pair {
      #|  left : Int
      #|  right : Int
      #|}
      #|
      #|pub let pair : Pair = Pair::{
      #|  // left value
      #|  left: 1,
      #|  // right value
      #|  right: 2
      #|}
      #|
      #|// eof marker
      #|
    ),
  )
}

///|
test "format source keeps struct literal and pattern fields parseable" {
  let source =
    #|module Test
    #|pub struct Point {
    #|  x : Int
    #|  y : Int
    #|}
    #|pub let origin : Point = Point::{ x: 0, y: 0 }
    #|pub fn sum(point : Point) -> Int {
    #|  match point {
    #|    Point::{ x, y } => x + y
    #|  }
    #|}
  assert_format(
    source,
    (
      #|module Test
      #|
      #|pub struct Point {
      #|  x : Int
      #|  y : Int
      #|}
      #|
      #|pub let origin : Point = Point::{ x: 0, y: 0 }
      #|
      #|pub fn sum(point : Point) -> Int {
      #|  match point {
      #|    Point::{ x, y } => x + y
      #|  }
      #|}
      #|
    ),
  )
}

///|
test "format source keeps struct literals tighter than binary operators" {
  let source =
    #|module Test
    #|struct Meter {
    #|  value : Int
    #|}
    #|pub let answer : Bool = Meter::{ value: 1 } == Meter::{ value: 1 }
  assert_format(
    source,
    (
      #|module Test
      #|
      #|struct Meter {
      #|  value : Int
      #|}
      #|
      #|pub let answer : Bool = Meter::{ value: 1 } == Meter::{ value: 1 }
      #|
    ),
  )
}

///|
test "format source keeps else-if chains parseable" {
  let source =
    #|module Test
    #|pub fn choose(first : Bool, second : Bool) -> Int {
    #|  if first { 1 } else if second { 2 } else { 3 }
    #|}
  assert_format(
    source,
    (
      #|module Test
      #|
      #|pub fn choose(first : Bool, second : Bool) -> Int {
      #|  if first {
      #|    1
      #|  } else if second {
      #|    2
      #|  } else {
      #|    3
      #|  }
      #|}
      #|
    ),
  )
}

///|
test "format source keeps selective imports parseable" {
  let source =
    #|module Test
    #|import Lib.{ value, Box }
    #|pub let item : Box = Box::{ value }
  assert_format(
    source,
    (
      #|module Test
      #|
      #|import Lib.{ value, Box }
      #|
      #|pub let item : Box = Box::{ value }
      #|
    ),
  )
}

///|
test "format source preserves selective import comments" {
  assert_format(
    (
      #|module Test
      #|import Basic.Io.{
      #|  // selected value
      #|  println
      #|  // before close
      #|}
      #|pub let answer : Int = 42
    ),
    (
      #|module Test
      #|
      #|import Basic.Io.{
      #|  // selected value
      #|  println
      #|  // before close
      #|}
      #|
      #|pub let answer : Int = 42
      #|
    ),
  )
}

///|
test "format source preserves parameter comments" {
  assert_format(
    (
      #|module Test
      #|pub fn add(
      #|  // left operand
      #|  left : Int,
      #|  // right operand
      #|  right : Int
      #|) -> Int {
      #|  left + right
      #|}
    ),
    (
      #|module Test
      #|
      #|pub fn add(
      #|  // left operand
      #|  left : Int,
      #|  // right operand
      #|  right : Int
      #|) -> Int {
      #|  left + right
      #|}
      #|
    ),
  )
}

///|
test "format source preserves call separator and closing comments" {
  assert_format(
    (
      #|module Test
      #|pub fn add(left : Int, right : Int) -> Int { left + right }
      #|pub let answer : Int = add(
      #|  20, // second follows
      #|  22
      #|  // before close
      #|)
    ),
    (
      #|module Test
      #|
      #|pub fn add(left : Int, right : Int) -> Int {
      #|  left + right
      #|}
      #|
      #|pub let answer : Int = add(
      #|  20,
      #|  // second follows
      #|  22
      #|  // before close
      #|)
      #|
    ),
  )
}

///|
test "format source moves pre-comma comments after the separator" {
  assert_format(
    (
      #|module Test
      #|pub fn add(left : Int, right : Int) -> Int { left + right }
      #|pub let answer : Int = add(
      #|  20 // after first item
      #|  , 22
      #|)
    ),
    (
      #|module Test
      #|
      #|pub fn add(left : Int, right : Int) -> Int {
      #|  left + right
      #|}
      #|
      #|pub let answer : Int = add(
      #|  20,
      #|  // after first item
      #|  22
      #|)
      #|
    ),
  )
}

///|
test "format source preserves generic parameter and argument comments" {
  assert_format(
    (
      #|module Test
      #|pub fn[
      #|  // type parameter
      #|  A
      #|  // before parameter close
      #|] identity(value : A) -> A { value }
      #|pub let answer : Int = identity[
      #|  // type argument
      #|  Int
      #|  // before argument close
      #|](42)
    ),
    (
      #|module Test
      #|
      #|pub fn[
      #|  // type parameter
      #|  A
      #|  // before parameter close
      #|] identity(value : A) -> A {
      #|  value
      #|}
      #|
      #|pub let answer : Int = identity[
      #|  // type argument
      #|  Int
      #|  // before argument close
      #|](42)
      #|
    ),
  )
}

///|
test "format source preserves braced effect generic argument comments" {
  assert_format(
    (
      #|module Test
      #|effect Log { write(Int) -> Unit }
      #|fn[E : Effect] run(action : () -> Unit ! E) -> Unit ! E { action() }
      #|fn logged() -> Unit ! Log { Log::write!(1) }
      #|pub let result : Unit = run[
      #|  // before effect argument
      #|  {
      #|    // effect member
      #|    Log
      #|    // before effect close
      #|  }
      #|  // before generic close
      #|](logged)
    ),
    (
      #|module Test
      #|
      #|effect Log {
      #|  write(Int) -> Unit
      #|}
      #|
      #|fn[E : Effect] run(action : () -> Unit ! E) -> Unit ! E {
      #|  action()
      #|}
      #|
      #|fn logged() -> Unit ! Log {
      #|  Log::write!(1)
      #|}
      #|
      #|pub let result : Unit = run[
      #|  // before effect argument
      #|  {
      #|    // effect member
      #|    Log
      #|    // before effect close
      #|  }
      #|  // before generic close
      #|](logged)
      #|
    ),
  )
}

///|
test "format source preserves enum payload comments" {
  assert_format(
    (
      #|module Test
      #|pub enum Pair[A, B] {
      #|  pair(
      #|    // left payload
      #|    A,
      #|    // right payload
      #|    B
      #|    // before payload close
      #|  )
      #|}
    ),
    (
      #|module Test
      #|
      #|pub enum Pair[A, B] {
      #|  pair(
      #|    // left payload
      #|    A,
      #|    // right payload
      #|    B
      #|    // before payload close
      #|  )
      #|}
      #|
    ),
  )
}

///|
test "format source preserves list and struct literal comments" {
  assert_format(
    (
      #|module Test
      #|pub struct Pair { left : Int; right : Int }
      #|pub let numbers : List[Int] = [
      #|  // first item
      #|  20,
      #|  // second item
      #|  22
      #|  // before list close
      #|]
      #|pub let pair : Pair = Pair::{
      #|  // left field
      #|  left: 20,
      #|  right: 22
      #|  // before struct close
      #|}
    ),
    (
      #|module Test
      #|
      #|pub struct Pair {
      #|  left : Int
      #|  right : Int
      #|}
      #|
      #|pub let numbers : List[Int] = [
      #|  // first item
      #|  20,
      #|  // second item
      #|  22
      #|  // before list close
      #|]
      #|
      #|pub let pair : Pair = Pair::{
      #|  // left field
      #|  left: 20,
      #|  right: 22
      #|  // before struct close
      #|}
      #|
    ),
  )
}

///|
test "format source preserves comments after trailing container separators" {
  assert_format(
    (
      #|module Test
      #|struct Box {
      #|  value : Int; // trailing field separator
      #|}
      #|pub let numbers : List[Int] = [
      #|  1, // trailing item separator
      #|]
    ),
    (
      #|module Test
      #|
      #|struct Box {
      #|  value : Int
      #|  // trailing field separator
      #|}
      #|
      #|pub let numbers : List[Int] = [
      #|  1
      #|  // trailing item separator
      #|]
      #|
    ),
  )
}

///|
test "format source preserves function literal parameter comments" {
  assert_format(
    (
      #|module Test
      #|pub let add : (Int, Int) -> Int = fn(
      #|  // left parameter
      #|  left : Int,
      #|  // right parameter
      #|  right : Int
      #|  // before parameter close
      #|) -> Int { left + right }
    ),
    (
      #|module Test
      #|
      #|pub let add : (Int, Int) -> Int = fn(
      #|  // left parameter
      #|  left : Int,
      #|  // right parameter
      #|  right : Int
      #|  // before parameter close
      #|) -> Int {
      #|  left + right
      #|}
      #|
    ),
  )
}

///|
test "format source preserves effect operation payload comments" {
  assert_format(
    (
      #|module Test
      #|pub effect Console {
      #|  write(
      #|    // payload
      #|    String
      #|    // before payload close
      #|  ) -> Unit
      #|}
    ),
    (
      #|module Test
      #|
      #|pub effect Console {
      #|  write(
      #|    // payload
      #|    String
      #|    // before payload close
      #|  ) -> Unit
      #|}
      #|
    ),
  )
}

///|
test "format source preserves pattern payload comments" {
  assert_format(
    (
      #|module Test
      #|pub enum Option { none(); some(Int) }
      #|pub fn unwrap(value : Option) -> Int {
      #|  match value {
      #|    none() => 0
      #|    some(
      #|      // payload binder
      #|      item
      #|      // before pattern close
      #|    ) => item
      #|  }
      #|}
    ),
    (
      #|module Test
      #|
      #|pub enum Option {
      #|  none()
      #|  some(Int)
      #|}
      #|
      #|pub fn unwrap(value : Option) -> Int {
      #|  match value {
      #|    none() => 0
      #|    some(
      #|      // payload binder
      #|      item
      #|      // before pattern close
      #|    ) => item
      #|  }
      #|}
      #|
    ),
  )
}

///|
test "format source preserves declaration type parameter delimiters" {
  assert_format(
    (
      #|module Test
      #|extern type Handle[
      #|  // external parameter
      #|  A
      #|  // before external close
      #|] : Type
      #|pub struct Box[
      #|  // struct parameter
      #|  A
      #|  // before struct close
      #|] {
      #|  // before body close
      #|}
      #|pub type Identity[
      #|  // alias parameter
      #|  A
      #|  // before alias close
      #|] = A
    ),
    (
      #|module Test
      #|
      #|extern type Handle[
      #|  // external parameter
      #|  A
      #|  // before external close
      #|] : Type
      #|
      #|pub struct Box[
      #|  // struct parameter
      #|  A
      #|  // before struct close
      #|] {
      #|  // before body close
      #|}
      #|
      #|pub type Identity[
      #|  // alias parameter
      #|  A
      #|  // before alias close
      #|] = A
      #|
    ),
  )
}

///|
test "format source preserves effect and variant call delimiters" {
  assert_format(
    (
      #|module Test
      #|effect Prompt { choose[A](A, A) -> A }
      #|enum Option[A] { some(A) }
      #|pub let chosen : Int = Prompt::choose![
      #|  // type witness
      #|  Int
      #|  // before witness close
      #|](
      #|  // left choice
      #|  20,
      #|  22
      #|  // before argument close
      #|)
      #|pub let option : Option[Int] = Option::some[
      #|  // variant type argument
      #|  Int
      #|  // before variant type close
      #|](
      #|  // variant payload
      #|  42
      #|  // before variant close
      #|)
    ),
    (
      #|module Test
      #|
      #|effect Prompt {
      #|  choose[A](A, A) -> A
      #|}
      #|
      #|enum Option[A] {
      #|  some(A)
      #|}
      #|
      #|pub let chosen : Int = Prompt::choose![
      #|  // type witness
      #|  Int
      #|  // before witness close
      #|](
      #|  // left choice
      #|  20,
      #|  22
      #|  // before argument close
      #|)
      #|
      #|pub let option : Option[Int] = Option::some[
      #|  // variant type argument
      #|  Int
      #|  // before variant type close
      #|](
      #|  // variant payload
      #|  42
      #|  // before variant close
      #|)
      #|
    ),
  )
}

///|
test "format source preserves function type and effect row delimiters" {
  assert_format(
    (
      #|module Test
      #|effect Prompt { read() -> Int }
      #|pub let callback : [
      #|  // callable parameter
      #|  A
      #|  // before callable parameter close
      #|](
      #|  // callable input
      #|  A
      #|  // before callable input close
      #|) -> A ! {
      #|  // callable effect
      #|  Prompt
      #|  // before effect close
      #|} = fn[A](value : A) -> A { value }
    ),
    (
      #|module Test
      #|
      #|effect Prompt {
      #|  read() -> Int
      #|}
      #|
      #|pub let callback : [
      #|  // callable parameter
      #|  A
      #|  // before callable parameter close
      #|](
      #|  // callable input
      #|  A
      #|  // before callable input close
      #|) -> A ! {
      #|  // callable effect
      #|  Prompt
      #|  // before effect close
      #|} =
      #|  fn[A](value : A) -> A {
      #|    value
      #|  }
      #|
    ),
  )
}

///|
test "format source preserves function type separator comments" {
  assert_format(
    (
      #|module Test
      #|pub let callback : (
      #|  Int, // first parameter
      #|  String
      #|) -> Int = fn(_left : Int, _right : String) -> Int { 0 }
    ),
    (
      #|module Test
      #|
      #|pub let callback : (
      #|  Int,
      #|  // first parameter
      #|  String
      #|) -> Int =
      #|  fn(_left : Int, _right : String) -> Int {
      #|    0
      #|  }
      #|
    ),
  )
}

///|
test "format source preserves qualified variant separator comments" {
  assert_format(
    (
      #|module Test
      #|enum Pair { pair(Int, Int) }
      #|pub let pair : Pair = Pair::pair(
      #|  20, // left argument
      #|  22
      #|)
    ),
    (
      #|module Test
      #|
      #|enum Pair {
      #|  pair(Int, Int)
      #|}
      #|
      #|pub let pair : Pair = Pair::pair(
      #|  20,
      #|  // left argument
      #|  22
      #|)
      #|
    ),
  )
}

///|
test "format source preserves type binder separator comments" {
  assert_format(
    (
      #|module Test
      #|effect Prompt { choose[Left, Right](Left, Right) -> Left }
      #|pub enum Packed { hide[First, Second](First) }
      #|pub let chosen : Int = handle Prompt::choose![Int, Int](20, 22) with {
      #|  Prompt::choose[
      #|    Left, // handler type binder
      #|    Right
      #|  ](left, _right, resume) => resume(left)
      #|} final value {
      #|  match Packed::hide[Int, String](value) {
      #|    Packed::hide[
      #|      First, // pattern type binder
      #|      Second
      #|    ](item) => item
      #|  }
      #|}
    ),
    (
      #|module Test
      #|
      #|effect Prompt {
      #|  choose[Left, Right](Left, Right) -> Left
      #|}
      #|
      #|pub enum Packed {
      #|  hide[First, Second](First)
      #|}
      #|
      #|pub let chosen : Int = handle Prompt::choose![Int, Int](20, 22) with {
      #|  Prompt::choose[
      #|    Left,
      #|    // handler type binder
      #|    Right
      #|  ](left, _right, resume) => resume(left)
      #|} final value {
      #|  match Packed::hide[Int, String](value) {
      #|    Packed::hide[
      #|      First,
      #|      // pattern type binder
      #|      Second
      #|    ](item) => item
      #|  }
      #|}
      #|
    ),
  )
}

///|
test "format source preserves operator field and control flow boundaries" {
  assert_format(
    (
      #|module Test
      #|struct Pair { left : Int; right : Int }
      #|pub fn choose(flag : Bool, pair : Pair) -> Int {
      #|  if flag {
      #|    pair. // field boundary
      #|    left + // right operand
      #|    1
      #|  }
      #|  // before else
      #|  else {
      #|    pair.right
      #|  }
      #|}
    ),
    (
      #|module Test
      #|
      #|struct Pair {
      #|  left : Int
      #|  right : Int
      #|}
      #|
      #|pub fn choose(flag : Bool, pair : Pair) -> Int {
      #|  if flag {
      #|    pair. // field boundary
      #|      left + // right operand
      #|      1
      #|  }
      #|  // before else
      #|  else {
      #|    pair.right
      #|  }
      #|}
      #|
    ),
  )
}

///|
test "format source preserves handler keyword boundaries" {
  assert_format(
    (
      #|module Test
      #|effect Prompt { choose(Int, Int) -> Int }
      #|pub let chosen : Int = {
      #|  handle Prompt::choose!(20, 22)
      #|  // before with
      #|  with {
      #|    Prompt::choose(left, _right, resume) => resume(left)
      #|  }
      #|  // before final
      #|  final value { value }
      #|}
    ),
    (
      #|module Test
      #|
      #|effect Prompt {
      #|  choose(Int, Int) -> Int
      #|}
      #|
      #|pub let chosen : Int = {
      #|  handle Prompt::choose!(20, 22)
      #|  // before with
      #|  with {
      #|    Prompt::choose(left, _right, resume) => resume(left)
      #|  }
      #|  // before final
      #|  final value {
      #|    value
      #|  }
      #|}
      #|
    ),
  )
}

///|
test "format source preserves declaration separator and trailing comments" {
  assert_format(
    (
      #|module Test
      #|extern type Handle[A]
      #|// before colon
      #|: Type // external tail
      #|struct Box[A]
      #|// before body
      #|{ value : A } // struct tail
      #|enum Option[A] { some(A) } // enum tail
      #|effect Prompt {
      #|  read()
      #|  // before operation arrow
      #|  -> Int
      #|} // effect tail
      #|pub type Identity[A]
      #|// before alias equals
      #|= A // alias tail
      #|pub fn identity(value : Int)
      #|// before function arrow
      #|-> Int { value } // function tail
      #|pub let answer : Int
      #|// before let equals
      #|= 42 // let tail
    ),
    (
      #|module Test
      #|
      #|extern type Handle[A]
      #|// before colon
      #|: Type // external tail
      #|
      #|struct Box[A]
      #|// before body
      #|{
      #|  value : A
      #|} // struct tail
      #|
      #|enum Option[A] {
      #|  some(A)
      #|} // enum tail
      #|
      #|effect Prompt {
      #|  read()
      #|  // before operation arrow
      #|  -> Int
      #|} // effect tail
      #|
      #|pub type Identity[A]
      #|// before alias equals
      #|= A // alias tail
      #|
      #|pub fn identity(value : Int)
      #|// before function arrow
      #|-> Int {
      #|  value
      #|} // function tail
      #|
      #|pub let answer : Int
      #|// before let equals
      #|= 42 // let tail
      #|
    ),
  )
}

///|
test "format source preserves unary pipeline and match boundaries" {
  assert_format(
    (
      #|module Test
      #|enum Option { some(Int) }
      #|fn identity(value : Int) -> Int { value }
      #|pub fn inspect(value : Int, option : Option) -> Bool {
      #|  let piped : Int = value |> // pipeline operand
      #|    identity
      #|  let negated : Bool = ! // unary operand
      #|    false
      #|  match option
      #|  // before match body
      #|  {
      #|    some(item) => negated && piped == item
      #|  }
      #|}
    ),
    (
      #|module Test
      #|
      #|enum Option {
      #|  some(Int)
      #|}
      #|
      #|fn identity(value : Int) -> Int {
      #|  value
      #|}
      #|
      #|pub fn inspect(value : Int, option : Option) -> Bool {
      #|  let piped : Int =
      #|    value
      #|      |> // pipeline operand
      #|        identity
      #|  let negated : Bool = ! // unary operand
      #|    false
      #|  match option
      #|  // before match body
      #|  {
      #|    some(item) => negated && piped == item
      #|  }
      #|}
      #|
    ),
  )
}

///|
test "format source keeps pipelines after trailing comments parseable" {
  assert_format(
    (
      #|module Test
      #|fn use(value : Int) -> Int {
      #|  first(
      #|    value,
      #|    fn(item) {
      #|      item
      #|    }
      #|  ) // trailing comment
      #|    |> second
      #|}
      #|fn chained(value : Int) -> Int {
      #|  value
      #|    |> first(
      #|      value,
      #|      fn(item) {
      #|        item
      #|      }
      #|    ) // trailing segment
      #|    |> second
      #|}
    ),
    (
      #|module Test
      #|
      #|fn use(value : Int) -> Int {
      #|  first(
      #|    value,
      #|    fn(item) {
      #|      item
      #|    }
      #|  ) // trailing comment
      #|    |> second
      #|}
      #|
      #|fn chained(value : Int) -> Int {
      #|  value
      #|    |> first(
      #|      value,
      #|      fn(item) {
      #|        item
      #|      }
      #|    ) // trailing segment
      #|    |> second
      #|}
      #|
    ),
  )
}

///|
test "format source treats trailing comments as general line boundaries" {
  assert_format(
    (
      #|module Test
      #|struct Pair { fst : Int }
      #|fn binary(left : Int, right : Int) -> Int {
      #|  left // binary left
      #|    + right
      #|}
      #|fn field(value : Pair) -> Int {
      #|  value // field base
      #|    .fst
      #|}
      #|fn call(callee : (Int) -> Int) -> Int {
      #|  callee // call callee
      #|    (42)
      #|}
    ),
    (
      #|module Test
      #|
      #|struct Pair {
      #|  fst : Int
      #|}
      #|
      #|fn binary(left : Int, right : Int) -> Int {
      #|  left // binary left
      #|    + right
      #|}
      #|
      #|fn field(value : Pair) -> Int {
      #|  value // field base
      #|    .fst
      #|}
      #|
      #|fn call(callee : (Int) -> Int) -> Int {
      #|  callee // call callee
      #|  (42)
      #|}
      #|
    ),
  )
}

///|
test "format source preserves explicit expression type and kind grouping" {
  assert_format(
    (
      #|module Test
      #|pub type Nested = ((Int))
      #|pub type Higher[F : ([Type] -> Type)] = F[Int]
      #|pub fn grouped(value : Int) -> Int { ((value + 1)) }
    ),
    (
      #|module Test
      #|
      #|pub type Nested = ((Int))
      #|
      #|pub type Higher[F : ([Type] -> Type)] = F[Int]
      #|
      #|pub fn grouped(value : Int) -> Int {
      #|  ((value + 1))
      #|}
      #|
    ),
  )
}

///|
test "format source keeps grouped child trailing comments inside parentheses" {
  assert_format(
    (
      #|module Test
      #|pub type Nested = (
      #|  Int // child type
      #|  // grouped type dangling
      #|)
      #|pub type Higher[F : (
      #|  Type // child kind
      #|)] = F[Int]
      #|pub fn grouped(value : Int) -> Int {
      #|  (
      #|    value // child expression
      #|  )
      #|}
    ),
    (
      #|module Test
      #|
      #|pub type Nested = (
      #|  Int // child type
      #|  // grouped type dangling
      #|)
      #|
      #|pub type Higher[
      #|  F : (
      #|    Type // child kind
      #|  )
      #|] = F[Int]
      #|
      #|pub fn grouped(value : Int) -> Int {
      #|  (
      #|    value // child expression
      #|  )
      #|}
      #|
    ),
  )
}

///|
test "format grouping and function suffixes share width decisions" {
  assert_format(
    (
      #|module Test
      #|pub fn eval_if_int(
      #|  condition : Eval[Bool],
      #|  then_branch : Eval[Int],
      #|  else_branch : Eval[Int]
      #|) -> Eval[Int] {
      #|  then_branch
      #|}
      #|pub let handled : Int =
      #|  (program
      #|    |> handle_ask
      #|    |> handle_log)()
    ),
    (
      #|module Test
      #|
      #|pub fn eval_if_int(
      #|  condition : Eval[Bool],
      #|  then_branch : Eval[Int],
      #|  else_branch : Eval[Int]
      #|) -> Eval[Int] {
      #|  then_branch
      #|}
      #|
      #|pub let handled : Int =
      #|  (program
      #|    |> handle_ask
      #|    |> handle_log)()
      #|
    ),
  )
}

///|
test "format source nests broken call arguments in match arms" {
  let source =
    #|module Test
    #|import Ops.*
    #|pub enum Term { var(Int); app(Term, Term) }
    #|pub fn shift_from(cutoff : Int, delta : Int, term : Term) -> Term {
    #|  match term {
    #|    Term::var(index) => Term::var(index)
    #|    Term::app(function, argument) => Term::app(shift_from(cutoff, delta, function), shift_from(cutoff, delta, argument))
    #|  }
    #|}
  assert_format(
    source,
    (
      #|module Test
      #|
      #|import Ops.*
      #|
      #|pub enum Term {
      #|  var(Int)
      #|  app(Term, Term)
      #|}
      #|
      #|pub fn shift_from(cutoff : Int, delta : Int, term : Term) -> Term {
      #|  match term {
      #|    Term::var(index) => Term::var(index)
      #|    Term::app(function, argument) => Term::app(
      #|      shift_from(cutoff, delta, function),
      #|      shift_from(cutoff, delta, argument)
      #|    )
      #|  }
      #|}
      #|
    ),
  )
}

///|
test "format source nests structured expressions through arm wrappers" {
  assert_format(
    (
      #|module Test
      #|effect Assert { check(Bool) -> Unit }
      #|enum Choice { some(); grouped(); none() }
      #|pub fn handle_check(flag : Bool) -> Unit {
      #|  handle Assert::check!(flag) with {
      #|    Assert::check(value, resume) =>
      #|      if value {
      #|        ()
      #|      } else {
      #|        ()
      #|      } |> resume()
      #|  } final value {
      #|    value
      #|  }
      #|}
      #|pub fn choose(choice : Choice, flag : Bool) -> Int {
      #|  match choice {
      #|    some() =>
      #|      if flag {
      #|        1
      #|      } else {
      #|        0
      #|      }
      #|        + 1
      #|    grouped() =>
      #|      (if flag {
      #|        2
      #|      } else {
      #|        3
      #|      }) |> resume()
      #|    none() => 0
      #|  }
      #|}
    ),
    (
      #|module Test
      #|
      #|effect Assert {
      #|  check(Bool) -> Unit
      #|}
      #|
      #|enum Choice {
      #|  some()
      #|  grouped()
      #|  none()
      #|}
      #|
      #|pub fn handle_check(flag : Bool) -> Unit {
      #|  handle Assert::check!(flag) with {
      #|    Assert::check(value, resume) =>
      #|      if value {
      #|        ()
      #|      } else {
      #|        ()
      #|      } |> resume()
      #|  } final value {
      #|    value
      #|  }
      #|}
      #|
      #|pub fn choose(choice : Choice, flag : Bool) -> Int {
      #|  match choice {
      #|    some() =>
      #|      if flag {
      #|        1
      #|      } else {
      #|        0
      #|      }
      #|        + 1
      #|    grouped() =>
      #|      (if flag {
      #|        2
      #|      } else {
      #|        3
      #|      }) |> resume()
      #|    none() => 0
      #|  }
      #|}
      #|
    ),
  )
}

///|
test "format source breaks list-like syntax at small width" {
  let source =
    #|module Test
    #|import Lib.{ alpha, beta, gamma, delta }
    #|pub struct Pair[First, Second] { first : First; second : Second }
    #|pub enum Packed { hide[Hidden](Hidden) }
    #|effect Prompt { choose[Choice](Choice, Choice) -> Choice }
    #|pub fn run(first : Int, second : Int) -> Int ! { Prompt, Log } {
    #|  handle Prompt::choose![Int](first, second) with {
    #|    Prompt::choose[T](left, right, resume) => resume(left)
    #|  } final value {
    #|    match Packed::hide[Int](value) {
    #|      Packed::hide[T](item) => item
    #|    }
    #|  }
    #|}
  assert_format(
    source,
    (
      #|module Test
      #|
      #|import Lib.{
      #|  alpha,
      #|  beta,
      #|  gamma,
      #|  delta
      #|}
      #|
      #|pub struct Pair[
      #|  First,
      #|  Second
      #|] {
      #|  first : First
      #|  second : Second
      #|}
      #|
      #|pub enum Packed {
      #|  hide[Hidden](
      #|    Hidden
      #|  )
      #|}
      #|
      #|effect Prompt {
      #|  choose[Choice](
      #|    Choice,
      #|    Choice
      #|  ) -> Choice
      #|}
      #|
      #|pub fn run(
      #|  first : Int,
      #|  second : Int
      #|) -> Int ! {
      #|  Prompt,
      #|  Log
      #|} {
      #|  handle
      #|    Prompt::choose![
      #|      Int
      #|    ](first, second) with {
      #|    Prompt::choose[
      #|      T
      #|    ](
      #|      left,
      #|      right,
      #|      resume
      #|    ) => resume(
      #|      left
      #|    )
      #|  } final value {
      #|    match
      #|      Packed::hide[
      #|        Int
      #|      ](value) {
      #|      Packed::hide[
      #|        T
      #|      ](item) => item
      #|    }
      #|  }
      #|}
      #|
    ),
    width=20,
  )
}

///|
test "format source breaks declarations and expression chains at small width" {
  let source =
    #|module Test
    #|pub fn compute(input : Input, fallback : Int) -> Int {
    #|  let result : Int = very_long_function_name(input.first.second.third, fallback)
    #|  let chain : Int = input.first.second.third.fourth
    #|  let piped : Int = input |> first_step |> second_step
    #|  let mapped : Int = very_long_function_name(input.first.second.third, fallback) |> first_step
    #|  if first_condition && second_condition && third_condition { result } else { chain }
    #|}
  assert_format(
    source,
    (
      #|module Test
      #|
      #|pub fn compute(
      #|  input : Input,
      #|  fallback : Int
      #|) -> Int {
      #|  let result : Int =
      #|    very_long_function_name(
      #|      input.first.second.third,
      #|      fallback
      #|    )
      #|  let chain : Int =
      #|    input
      #|      .first
      #|      .second
      #|      .third
      #|      .fourth
      #|  let piped : Int =
      #|    input
      #|      |> first_step
      #|      |> second_step
      #|  let mapped : Int =
      #|    very_long_function_name(
      #|      input.first.second.third,
      #|      fallback
      #|    ) |> first_step
      #|  if
      #|    first_condition
      #|      && second_condition
      #|      && third_condition {
      #|    result
      #|  } else {
      #|    chain
      #|  }
      #|}
      #|
    ),
    width=30,
  )
}

///|
test "format source keeps short block-like assignment attached" {
  let source =
    #|module Test
    #|pub enum Maybe {
    #|  some(Int)
    #|  none()
    #|}
    #|pub fn bad(flag : Bool, item : Maybe) -> Int {
    #|  let id = fn (value) {
    #|    value
    #|  }
    #|  let choice = if flag {
    #|    1
    #|  } else {
    #|    0
    #|  }
    #|  let picked = match item {
    #|    Maybe::some(value) => value
    #|    Maybe::none() => 0
    #|  }
    #|  let called = apply(fn (value) {
    #|    value
    #|  }, choice)
    #|  id(called + picked)
    #|}
  assert_format(
    source,
    (
      #|module Test
      #|
      #|pub enum Maybe {
      #|  some(Int)
      #|  none()
      #|}
      #|
      #|pub fn bad(flag : Bool, item : Maybe) -> Int {
      #|  let id = fn(value) {
      #|    value
      #|  }
      #|  let choice = if flag {
      #|    1
      #|  } else {
      #|    0
      #|  }
      #|  let picked = match item {
      #|    Maybe::some(value) => value
      #|    Maybe::none() => 0
      #|  }
      #|  let called = apply(
      #|    fn(value) {
      #|      value
      #|    },
      #|    choice
      #|  )
      #|  id(called + picked)
      #|}
      #|
    ),
    width=80,
  )
}
