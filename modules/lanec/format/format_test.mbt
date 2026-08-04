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
test "format Unicode strings and character literals canonically" {
  assert_format(
    (
      #|module Test
      #|fn literal(value:Char)->String {
      #|  match value { '\u{4f60}' => "\u{1F600}\u{0}\u{7f}" ; _ => "你" }
      #|}
    ),
    (
      #|module Test
      #|
      #|fn literal(value : Char) -> String {
      #|  match value {
      #|    '你' => "😀\0\u{7F}"
      #|    _ => "你"
      #|  }
      #|}
      #|
    ),
  )
}

///|
test "format explicit numeric literal suffixes" {
  assert_format(
    (
      #|module Test
      #|fn literals()->Unit {
      #|let i32=42i32
      #|let i64=42i64
      #|let whole_f32=1f32
      #|let whole_f64=1f64
      #|let f32=100.30f32
      #|let f64=1.25e-3f64
      #|let minimum=-2147483648i32
      #|match i32 { 42i32=>(); _=>() }
      #|()
      #|}
    ),
    (
      #|module Test
      #|
      #|fn literals() -> Unit {
      #|  let i32 = 42i32
      #|  let i64 = 42i64
      #|  let whole_f32 = 1f32
      #|  let whole_f64 = 1f64
      #|  let f32 = 100.30f32
      #|  let f64 = 1.25e-3f64
      #|  let minimum = -2147483648i32
      #|  match i32 {
      #|    42i32 => ()
      #|    _ => ()
      #|  }
      #|  ()
      #|}
      #|
    ),
  )
}

///|
test "format source preserves comments around an import alias" {
  assert_format(
    (
      #|module Test
      #|import Basic.Data.List // before as
      #|as // before alias
      #|List
    ),
    (
      #|module Test
      #|
      #|import Basic.Data.List
      #|// before as
      #|as
      #|// before alias
      #|List
      #|
    ),
  )
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
test "format offered function definitions" {
  assert_format(
    "module Test\npub offer fn[A] identity(value:A)->A{value}\nfn outer()->I64{offer fn local()->I64{42};local()}",
    (
      #|module Test
      #|
      #|pub offer fn[A] identity(value : A) -> A {
      #|  value
      #|}
      #|
      #|fn outer() -> I64 {
      #|  offer fn local() -> I64 {
      #|    42
      #|  }
      #|  local()
      #|}
      #|
    ),
  )
}

///|
test "format offered function preserves comment between offer and fn" {
  assert_format(
    (
      #|module Test
      #|offer // kept
      #|fn provide() -> I64 { 1 }
      #|pub offer // public kept
      #|fn public_provide() -> I64 { 2 }
      #|offer
      #|// standalone kept
      #|fn standalone_provide() -> I64 { 3 }
    ),
    (
      #|module Test
      #|
      #|offer // kept
      #|fn provide() -> I64 {
      #|  1
      #|}
      #|
      #|pub offer // public kept
      #|fn public_provide() -> I64 {
      #|  2
      #|}
      #|
      #|offer
      #|// standalone kept
      #|fn standalone_provide() -> I64 {
      #|  3
      #|}
      #|
    ),
  )
}

///|
test "format declaration keyword chains preserve comments" {
  assert_format(
    (
      #|module Test
      #|pub // pub offer
      #|offer // offer fn
      #|fn provide() -> I64 { 1 }
      #|pub // pub fn
      #|fn ordinary() -> I64 { 2 }
      #|pub // pub struct
      #|struct Box { value : I64 }
      #|pub // pub extern
      #|extern // extern type
      #|type Handle : Type
    ),
    (
      #|module Test
      #|
      #|pub // pub offer
      #|offer // offer fn
      #|fn provide() -> I64 {
      #|  1
      #|}
      #|
      #|pub // pub fn
      #|fn ordinary() -> I64 {
      #|  2
      #|}
      #|
      #|pub // pub struct
      #|struct Box {
      #|  value : I64
      #|}
      #|
      #|pub // pub extern
      #|extern // extern type
      #|type Handle : Type
      #|
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
test "format source normalizes whitespace and final newline" {
  let source =
    #|module   Test
    #|pub   let answer   :   I64=42
  assert_format(
    source,
    (
      #|module Test
      #|
      #|pub let answer : I64 = 42
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
      #|pub let answer : I64 = 42
    ),
    (
      #|module Test
      #|
      #|import Basic.Io.{ println }
      #|import Basic.Ops.*
      #|import Basic.Data.List.{ List }
      #|
      #|pub let answer : I64 = 42
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
      #|pub fn answer() -> I64 {
      #|  let left : I64 = 20
      #|
      #|
      #|  let right : I64 = 22
      #|
      #|  left + right
      #|}
    ),
    (
      #|module Test
      #|
      #|pub fn answer() -> I64 {
      #|  let left : I64 = 20
      #|  let right : I64 = 22
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
      #|pub let answer : I64 = 42
    ),
    (
      #|// invalid: example title
      #|// second line
      #|
      #|module Test
      #|
      #|pub let answer : I64 = 42
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
      #|struct Pair { left:I64; right:I64 }
      #|enum Choice { Left(I64); Right(I64) }
      #|effect Console { read()->I64; write(String)->Unit }
      #|pub fn choose(value:Bool)->I64 {
      #|match value { true => 1; false => 0 }
      #|}
    ),
    (
      #|module Test
      #|
      #|struct Pair {
      #|  left : I64
      #|  right : I64
      #|}
      #|
      #|enum Choice {
      #|  Left(I64)
      #|  Right(I64)
      #|}
      #|
      #|effect Console {
      #|  read() -> I64
      #|  write(String) -> Unit
      #|}
      #|
      #|pub fn choose(value : Bool) -> I64 {
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
      #|pub   let answer   :   I64=42 // trailing declaration
      #|
      #|pub fn main()->Unit{
      #|// inside block
      #|()}
    ),
    (
      #|module Test
      #|
      #|// before declaration
      #|pub let answer : I64 = 42 // trailing declaration
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
      #|pub let answer : I64 = 42
    ),
    (
      #|module Test // module tail
      #|
      #|pub let answer : I64 = 42
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
      #|pub fn answer() -> I64 { 42 }
    ),
    (
      #|module Test
      #|
      #|// function docs
      #|pub fn answer() -> I64 {
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
      #|pub let answer : I64 =
      #|  // initializer
      #|  42
    ),
    (
      #|module Test
      #|
      #|pub let answer : I64 =
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
      #|  read()->I64 // trailing operation
      #|}
      #|
      #|// before struct
      #|struct Pair{
      #|  // before field
      #|  left:I64
      #|  right:I64 // trailing field
      #|}
      #|
      #|// before enum
      #|enum Option{
      #|  // before variant
      #|  none()
      #|  some(I64) // trailing variant
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
      #|  read() -> I64 // trailing operation
      #|}
      #|
      #|// before struct
      #|struct Pair {
      #|  // before field
      #|  left : I64
      #|  right : I64 // trailing field
      #|}
      #|
      #|// before enum
      #|enum Option {
      #|  // before variant
      #|  none()
      #|  some(I64) // trailing variant
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
      #|pub fn choose(input:I64)->I64{
      #|// before let
      #|let base:I64=input+1 // trailing let
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
      #|pub fn choose(input : I64) -> I64 {
      #|  // before let
      #|  let base : I64 = input + 1 // trailing let
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
      #|  read()->I64
      #|}
      #|
      #|enum Option{
      #|  none()
      #|  some(I64)
      #|}
      #|
      #|pub fn read_or_default(value:Option)->I64{
      #|match value{
      #|// none arm
      #|none()=>0 // trailing none arm
      #|// some arm
      #|some(x)=>x
      #|}
      #|}
      #|
      #|pub let handled:I64={
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
      #|  read() -> I64
      #|}
      #|
      #|enum Option {
      #|  none()
      #|  some(I64)
      #|}
      #|
      #|pub fn read_or_default(value : Option) -> I64 {
      #|  match value {
      #|    // none arm
      #|    none() => 0 // trailing none arm
      #|    // some arm
      #|    some(x) => x
      #|  }
      #|}
      #|
      #|pub let handled : I64 = {
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
      #|left:I64
      #|right:I64
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
      #|  left : I64
      #|  right : I64
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
    #|  x : I64
    #|  y : I64
    #|}
    #|pub let origin : Point = Point::{ x: 0, y: 0 }
    #|pub fn sum(point : Point) -> I64 {
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
      #|  x : I64
      #|  y : I64
      #|}
      #|
      #|pub let origin : Point = Point::{ x: 0, y: 0 }
      #|
      #|pub fn sum(point : Point) -> I64 {
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
    #|  value : I64
    #|}
    #|pub let answer : Bool = Meter::{ value: 1 } == Meter::{ value: 1 }
  assert_format(
    source,
    (
      #|module Test
      #|
      #|struct Meter {
      #|  value : I64
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
    #|pub fn choose(first : Bool, second : Bool) -> I64 {
    #|  if first { 1 } else if second { 2 } else { 3 }
    #|}
  assert_format(
    source,
    (
      #|module Test
      #|
      #|pub fn choose(first : Bool, second : Bool) -> I64 {
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
test "format source preserves omitted else and its trailing comment" {
  let source =
    #|module Test
    #|pub fn run(flag : Bool) -> Unit {
    #|  if flag { () } // keep
    #|  ()
    #|}
    #|pub fn explicit(flag : Bool) -> Unit {
    #|  if flag { () } else { () }
    #|}
  assert_format(
    source,
    (
      #|module Test
      #|
      #|pub fn run(flag : Bool) -> Unit {
      #|  if flag {
      #|    ()
      #|  } // keep
      #|  ()
      #|}
      #|
      #|pub fn explicit(flag : Bool) -> Unit {
      #|  if flag {
      #|    ()
      #|  } else {
      #|    ()
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
      #|pub let answer : I64 = 42
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
      #|pub let answer : I64 = 42
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
      #|  left : I64,
      #|  // right operand
      #|  right : I64
      #|) -> I64 {
      #|  left + right
      #|}
    ),
    (
      #|module Test
      #|
      #|pub fn add(
      #|  // left operand
      #|  left : I64,
      #|  // right operand
      #|  right : I64
      #|) -> I64 {
      #|  left + right
      #|}
      #|
    ),
  )
}

///|
test "format source preserves trailing parameter comments" {
  assert_format(
    (
      #|module Test
      #|pub fn add(
      #|  left : I64, // left operand
      #|  right : I64 // right operand
      #|) -> I64 {
      #|  left + right
      #|}
    ),
    (
      #|module Test
      #|
      #|pub fn add(
      #|  left : I64, // left operand
      #|  right : I64 // right operand
      #|) -> I64 {
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
      #|pub fn add(left : I64, right : I64) -> I64 { left + right }
      #|pub let answer : I64 = add(
      #|  20, // second follows
      #|  22
      #|  // before close
      #|)
    ),
    (
      #|module Test
      #|
      #|pub fn add(left : I64, right : I64) -> I64 {
      #|  left + right
      #|}
      #|
      #|pub let answer : I64 = add(
      #|  20, // second follows
      #|  22
      #|  // before close
      #|)
      #|
    ),
  )
}

///|
test "format source places pre-comma comments after the separator inline" {
  assert_format(
    (
      #|module Test
      #|pub fn add(left : I64, right : I64) -> I64 { left + right }
      #|pub let answer : I64 = add(
      #|  20 // after first item
      #|  , 22
      #|)
    ),
    (
      #|module Test
      #|
      #|pub fn add(left : I64, right : I64) -> I64 {
      #|  left + right
      #|}
      #|
      #|pub let answer : I64 = add(
      #|  20, // after first item
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
      #|pub let answer : I64 = identity[
      #|  // type argument
      #|  I64
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
      #|pub let answer : I64 = identity[
      #|  // type argument
      #|  I64
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
      #|effect Log { write(I64) -> Unit }
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
      #|  write(I64) -> Unit
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
      #|pub struct Pair { left : I64; right : I64 }
      #|pub let numbers : List[I64] = [
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
      #|  left : I64
      #|  right : I64
      #|}
      #|
      #|pub let numbers : List[I64] = [
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
      #|  value : I64; // trailing field separator
      #|}
      #|pub let numbers : List[I64] = [
      #|  1, // trailing item separator
      #|]
    ),
    (
      #|module Test
      #|
      #|struct Box {
      #|  value : I64
      #|  // trailing field separator
      #|}
      #|
      #|pub let numbers : List[I64] = [
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
      #|pub let add : (I64, I64) -> I64 = fn(
      #|  // left parameter
      #|  left : I64,
      #|  // right parameter
      #|  right : I64
      #|  // before parameter close
      #|) -> I64 { left + right }
    ),
    (
      #|module Test
      #|
      #|pub let add : (I64, I64) -> I64 = fn(
      #|  // left parameter
      #|  left : I64,
      #|  // right parameter
      #|  right : I64
      #|  // before parameter close
      #|) -> I64 {
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
      #|pub enum Option { none(); some(I64) }
      #|pub fn unwrap(value : Option) -> I64 {
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
      #|  some(I64)
      #|}
      #|
      #|pub fn unwrap(value : Option) -> I64 {
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
      #|pub let chosen : I64 = Prompt::choose![
      #|  // type witness
      #|  I64
      #|  // before witness close
      #|](
      #|  // left choice
      #|  20,
      #|  22
      #|  // before argument close
      #|)
      #|pub let option : Option[I64] = Option::some[
      #|  // variant type argument
      #|  I64
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
      #|pub let chosen : I64 = Prompt::choose![
      #|  // type witness
      #|  I64
      #|  // before witness close
      #|](
      #|  // left choice
      #|  20,
      #|  22
      #|  // before argument close
      #|)
      #|
      #|pub let option : Option[I64] = Option::some[
      #|  // variant type argument
      #|  I64
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
      #|effect Prompt { read() -> I64 }
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
      #|  read() -> I64
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
      #|  I64, // first parameter
      #|  String
      #|) -> I64 = fn(_left : I64, _right : String) -> I64 { 0 }
    ),
    (
      #|module Test
      #|
      #|pub let callback : (
      #|  I64, // first parameter
      #|  String
      #|) -> I64 =
      #|  fn(_left : I64, _right : String) -> I64 {
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
      #|enum Pair { pair(I64, I64) }
      #|pub let pair : Pair = Pair::pair(
      #|  20, // left argument
      #|  22
      #|)
    ),
    (
      #|module Test
      #|
      #|enum Pair {
      #|  pair(I64, I64)
      #|}
      #|
      #|pub let pair : Pair = Pair::pair(
      #|  20, // left argument
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
      #|pub let chosen : I64 = handle Prompt::choose![I64, I64](20, 22) with {
      #|  Prompt::choose[
      #|    Left, // handler type binder
      #|    Right
      #|  ](left, _right, resume) => resume(left)
      #|} final value {
      #|  match Packed::hide[I64, String](value) {
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
      #|pub let chosen : I64 = handle Prompt::choose![I64, I64](20, 22) with {
      #|  Prompt::choose[
      #|    Left, // handler type binder
      #|    Right
      #|  ](left, _right, resume) => resume(left)
      #|} final value {
      #|  match Packed::hide[I64, String](value) {
      #|    Packed::hide[
      #|      First, // pattern type binder
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
      #|struct Pair { left : I64; right : I64 }
      #|pub fn choose(flag : Bool, pair : Pair) -> I64 {
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
      #|  left : I64
      #|  right : I64
      #|}
      #|
      #|pub fn choose(flag : Bool, pair : Pair) -> I64 {
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
      #|effect Prompt { choose(I64, I64) -> I64 }
      #|pub let chosen : I64 = {
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
      #|  choose(I64, I64) -> I64
      #|}
      #|
      #|pub let chosen : I64 = {
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
      #|  -> I64
      #|} // effect tail
      #|pub type Identity[A]
      #|// before alias equals
      #|= A // alias tail
      #|pub fn identity(value : I64)
      #|// before function arrow
      #|-> I64 { value } // function tail
      #|pub let answer : I64
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
      #|  -> I64
      #|} // effect tail
      #|
      #|pub type Identity[A]
      #|// before alias equals
      #|= A // alias tail
      #|
      #|pub fn identity(value : I64)
      #|// before function arrow
      #|-> I64 {
      #|  value
      #|} // function tail
      #|
      #|pub let answer : I64
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
      #|enum Option { some(I64) }
      #|fn identity(value : I64) -> I64 { value }
      #|pub fn inspect(value : I64, option : Option) -> Bool {
      #|  let piped : I64 = value |> // pipeline operand
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
      #|  some(I64)
      #|}
      #|
      #|fn identity(value : I64) -> I64 {
      #|  value
      #|}
      #|
      #|pub fn inspect(value : I64, option : Option) -> Bool {
      #|  let piped : I64 =
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
      #|fn use(value : I64) -> I64 {
      #|  first(
      #|    value,
      #|    fn(item) {
      #|      item
      #|    }
      #|  ) // trailing comment
      #|    |> second
      #|}
      #|fn chained(value : I64) -> I64 {
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
      #|fn use(value : I64) -> I64 {
      #|  first(
      #|    value,
      #|    fn(item) {
      #|      item
      #|    }
      #|  ) // trailing comment
      #|    |> second
      #|}
      #|
      #|fn chained(value : I64) -> I64 {
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
      #|struct Pair { fst : I64 }
      #|fn binary(left : I64, right : I64) -> I64 {
      #|  left // binary left
      #|    + right
      #|}
      #|fn field(value : Pair) -> I64 {
      #|  value // field base
      #|    .fst
      #|}
      #|fn call(callee : (I64) -> I64) -> I64 {
      #|  callee // call callee
      #|    (42)
      #|}
    ),
    (
      #|module Test
      #|
      #|struct Pair {
      #|  fst : I64
      #|}
      #|
      #|fn binary(left : I64, right : I64) -> I64 {
      #|  left // binary left
      #|    + right
      #|}
      #|
      #|fn field(value : Pair) -> I64 {
      #|  value // field base
      #|    .fst
      #|}
      #|
      #|fn call(callee : (I64) -> I64) -> I64 {
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
      #|pub type Nested = ((I64))
      #|pub type Higher[F : ([Type] -> Type)] = F[I64]
      #|pub fn grouped(value : I64) -> I64 { ((value + 1)) }
    ),
    (
      #|module Test
      #|
      #|pub type Nested = ((I64))
      #|
      #|pub type Higher[F : ([Type] -> Type)] = F[I64]
      #|
      #|pub fn grouped(value : I64) -> I64 {
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
      #|  I64 // child type
      #|  // grouped type dangling
      #|)
      #|pub type Higher[F : (
      #|  Type // child kind
      #|)] = F[I64]
      #|pub fn grouped(value : I64) -> I64 {
      #|  (
      #|    value // child expression
      #|  )
      #|}
    ),
    (
      #|module Test
      #|
      #|pub type Nested = (
      #|  I64 // child type
      #|  // grouped type dangling
      #|)
      #|
      #|pub type Higher[
      #|  F : (
      #|    Type // child kind
      #|  )
      #|] = F[I64]
      #|
      #|pub fn grouped(value : I64) -> I64 {
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
      #|  then_branch : Eval[I64],
      #|  else_branch : Eval[I64]
      #|) -> Eval[I64] {
      #|  then_branch
      #|}
      #|pub let handled : I64 =
      #|  (program
      #|    |> handle_ask
      #|    |> handle_log)()
    ),
    (
      #|module Test
      #|
      #|pub fn eval_if_int(
      #|  condition : Eval[Bool],
      #|  then_branch : Eval[I64],
      #|  else_branch : Eval[I64]
      #|) -> Eval[I64] {
      #|  then_branch
      #|}
      #|
      #|pub let handled : I64 =
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
    #|pub enum Term { var(I64); app(Term, Term) }
    #|pub fn shift_from(cutoff : I64, delta : I64, term : Term) -> Term {
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
      #|  var(I64)
      #|  app(Term, Term)
      #|}
      #|
      #|pub fn shift_from(cutoff : I64, delta : I64, term : Term) -> Term {
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
      #|enum Choice { some(); grouped(); unary(); unary_match(); unary_handler(); f64_unary(); grouped_unary(); commented_unary(); none() }
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
      #|pub fn choose(choice : Choice, flag : Bool) -> I64 {
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
      #|    unary() =>
      #|      !if flag {
      #|        true
      #|      } else {
      #|        false
      #|      }
      #|    unary_match() =>
      #|      !match flag {
      #|        true => true
      #|        false => false
      #|      }
      #|    unary_handler() =>
      #|      !handle Assert::check!(flag) with {
      #|        Assert::check(value, resume) => resume()
      #|      } final value {
      #|        value
      #|      }
      #|    f64_unary() =>
      #|      !!if flag {
      #|        true
      #|      } else {
      #|        false
      #|      }
      #|    grouped_unary() =>
      #|      !(if flag {
      #|        true
      #|      } else {
      #|        false
      #|      })
      #|    commented_unary() =>
      #|      ! // unary operand
      #|        if flag {
      #|          true
      #|        } else {
      #|          false
      #|        }
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
      #|  unary()
      #|  unary_match()
      #|  unary_handler()
      #|  f64_unary()
      #|  grouped_unary()
      #|  commented_unary()
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
      #|pub fn choose(choice : Choice, flag : Bool) -> I64 {
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
      #|    unary() =>
      #|      !(if flag {
      #|        true
      #|      } else {
      #|        false
      #|      })
      #|    unary_match() =>
      #|      !(match flag {
      #|        true => true
      #|        false => false
      #|      })
      #|    unary_handler() =>
      #|      !(handle Assert::check!(flag) with {
      #|        Assert::check(value, resume) => resume()
      #|      } final value {
      #|        value
      #|      })
      #|    f64_unary() =>
      #|      !!(if flag {
      #|        true
      #|      } else {
      #|        false
      #|      })
      #|    grouped_unary() =>
      #|      !(if flag {
      #|        true
      #|      } else {
      #|        false
      #|      })
      #|    commented_unary() =>
      #|      ! // unary operand
      #|        (if flag {
      #|          true
      #|        } else {
      #|          false
      #|        })
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
    #|pub fn run(first : I64, second : I64) -> I64 ! { Prompt, Log } {
    #|  handle Prompt::choose![I64](first, second) with {
    #|    Prompt::choose[T](left, right, resume) => resume(left)
    #|  } final value {
    #|    match Packed::hide[I64](value) {
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
      #|  first : I64,
      #|  second : I64
      #|) -> I64 ! {
      #|  Prompt,
      #|  Log
      #|} {
      #|  handle
      #|    Prompt::choose![
      #|      I64
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
      #|        I64
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
    #|pub fn compute(input : Input, fallback : I64) -> I64 {
    #|  let result : I64 = very_long_function_name(input.first.second.third, fallback)
    #|  let chain : I64 = input.first.second.third.fourth
    #|  let piped : I64 = input |> first_step |> second_step
    #|  let mapped : I64 = very_long_function_name(input.first.second.third, fallback) |> first_step
    #|  if first_condition && second_condition && third_condition { result } else { chain }
    #|}
  assert_format(
    source,
    (
      #|module Test
      #|
      #|pub fn compute(
      #|  input : Input,
      #|  fallback : I64
      #|) -> I64 {
      #|  let result : I64 =
      #|    very_long_function_name(
      #|      input.first.second.third,
      #|      fallback
      #|    )
      #|  let chain : I64 =
      #|    input
      #|      .first
      #|      .second
      #|      .third
      #|      .fourth
      #|  let piped : I64 =
      #|    input
      #|      |> first_step
      #|      |> second_step
      #|  let mapped : I64 =
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
    #|  some(I64)
    #|  none()
    #|}
    #|pub fn bad(flag : Bool, item : Maybe) -> I64 {
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
      #|  some(I64)
      #|  none()
      #|}
      #|
      #|pub fn bad(flag : Bool, item : Maybe) -> I64 {
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

///|
test "format tuple syntax with flat right spine and preserved left nesting" {
  assert_format(
    (
      #|module Test
      #|type Right = (I64,(Bool,String))
      #|type Left = ((I64,Bool),String)
      #|fn make()->(I64,Bool,String){(1,(true,"lane"))}
      #|fn first(value:(I64,Bool,String))->I64{
      #|  match value { ((head,_),tail) => head }
      #|}
    ),
    (
      #|module Test
      #|
      #|type Right = (I64, Bool, String)
      #|
      #|type Left = ((I64, Bool), String)
      #|
      #|fn make() -> (I64, Bool, String) {
      #|  (1, true, "lane")
      #|}
      #|
      #|fn first(value : (I64, Bool, String)) -> I64 {
      #|  match value {
      #|    ((head, _), tail) => head
      #|  }
      #|}
      #|
    ),
  )
}

///|
test "format flattened tuple syntax preserves nested comments" {
  assert_format(
    (
      #|module Test
      #|type Triple = (I64, (Bool, // type kept
      #|String))
      #|fn make() -> (I64, Bool, String) {
      #|  (1, (true, // expression kept
      #|  "lane"))
      #|}
      #|fn first(value : (I64, Bool, String)) -> I64 {
      #|  match value {
      #|    (head, (_, // pattern kept
      #|    _)) => head
      #|  }
      #|}
    ),
    (
      #|module Test
      #|
      #|type Triple = (
      #|  I64,
      #|  Bool, // type kept
      #|  String
      #|)
      #|
      #|fn make() -> (I64, Bool, String) {
      #|  (
      #|    1,
      #|    true, // expression kept
      #|    "lane"
      #|  )
      #|}
      #|
      #|fn first(value : (I64, Bool, String)) -> I64 {
      #|  match value {
      #|    (
      #|      head,
      #|      _, // pattern kept
      #|      _
      #|    ) => head
      #|  }
      #|}
      #|
    ),
  )
}
