///|
test "format layout sequences around comments" {
  assert_format(
    (
      #|module Test
      #|fn print(value:String)->Unit { () }
      #|pub fn main()->Unit {
      #|print("first") // trailing first
      #|// before second
      #|print("second"); // trailing second
      #|print("third")
      #|}
    ),
    (
      #|module Test
      #|
      #|fn print(value : String) -> Unit {
      #|  ()
      #|}
      #|
      #|pub fn main() -> Unit {
      #|  print("first") // trailing first
      #|  // before second
      #|  print("second") // trailing second
      #|  print("third")
      #|}
      #|
    ),
  )
}

///|
test "format comments after explicit item semicolons" {
  assert_format(
    (
      #|module Test
      #|struct Pair {
      #|left:Int; // trailing left
      #|right:Int
      #|}
    ),
    (
      #|module Test
      #|
      #|struct Pair {
      #|  left : Int // trailing left
      #|  right : Int
      #|}
      #|
    ),
  )
}

///|
test "format rejects repeated item separators before attaching comments" {
  let result = format_source(
    (
      #|module Test
      #|fn mark() -> Unit { () }
      #|fn bad() -> Unit {
      #|  mark();; // keep
      #|  ()
      #|}
    ),
  )
  debug_inspect(
    result,
    content=(
      #|Err(
      #|  [
      #|    {
      #|      source_id: None,
      #|      message: "unexpected token",
      #|      span: Some(
      #|        Local(
      #|          {
      #|            start_offset: 65,
      #|            end_offset: 66,
      #|            start_line: 4,
      #|            start_column: 10,
      #|            end_line: 4,
      #|            end_column: 11,
      #|          },
      #|        ),
      #|      ),
      #|      severity: Error,
      #|      code: Some("E1100"),
      #|      labels: [
      #|        {
      #|          span: Local(
      #|            {
      #|              start_offset: 65,
      #|              end_offset: 66,
      #|              start_line: 4,
      #|              start_column: 10,
      #|              end_line: 4,
      #|              end_column: 11,
      #|            },
      #|          ),
      #|          message: "the parser did not expect `;`",
      #|          style: Primary,
      #|        },
      #|      ],
      #|      notes: ["expected one of: integer literal, double literal, string literal, identifier, `false`, `true`, `fn`, `let`, `offer`, `if`, `match`, `handle`, `builtin`, `extern`, `-`, `!`, `(`, `{`, `[`"],
      #|      helps: ["rewrite this position so it starts with one of: integer literal, double literal, string literal, identifier, `false`, `true`, `fn`, `let`, `offer`, `if`, `match`, `handle`, `builtin`, `extern`, `-`, `!`, `(`, `{`, `[`"],
      #|      facts: [],
      #|      suggestions: [],
      #|    },
      #|  ],
      #|)
    ),
  )
}

///|
test "format trailing comments on newline shorthand struct fields" {
  assert_format(
    (
      #|module Test
      #|struct Pair { left : Int; right : Int }
      #|pub fn make(left : Int, right : Int) -> Pair {
      #|Pair::{
      #|left // keep
      #|right
      #|}
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
      #|pub fn make(left : Int, right : Int) -> Pair {
      #|  Pair::{
      #|    left // keep
      #|    right
      #|  }
      #|}
      #|
    ),
  )
}

///|
test "format layout inside function literals nested in calls" {
  assert_format(
    (
      #|module Test
      #|fn apply(callback:()->Unit)->Unit { callback() }
      #|fn print(value:String)->Unit { () }
      #|pub fn main()->Unit {
      #|apply(fn() {
      #|print("first")
      #|print("second")
      #|})
      #|}
    ),
    (
      #|module Test
      #|
      #|fn apply(callback : () -> Unit) -> Unit {
      #|  callback()
      #|}
      #|
      #|fn print(value : String) -> Unit {
      #|  ()
      #|}
      #|
      #|pub fn main() -> Unit {
      #|  apply(
      #|    fn() {
      #|      print("first")
      #|      print("second")
      #|    }
      #|  )
      #|}
      #|
    ),
  )
}

///|
test "format layout across nested control-flow blocks" {
  assert_format(
    (
      #|module Test
      #|fn print(value:String)->Unit { () }
      #|pub fn main(condition:Bool)->Unit {
      #|if condition { print("then one"); print("then two") }
      #|else { print("else one"); print("else two") };
      #|match condition { true => print("true"); false => print("false") }
      #|}
    ),
    (
      #|module Test
      #|
      #|fn print(value : String) -> Unit {
      #|  ()
      #|}
      #|
      #|pub fn main(condition : Bool) -> Unit {
      #|  if condition {
      #|    print("then one")
      #|    print("then two")
      #|  } else {
      #|    print("else one")
      #|    print("else two")
      #|  }
      #|  match condition {
      #|    true => print("true")
      #|    false => print("false")
      #|  }
      #|}
      #|
    ),
  )
}

///|
test "format comma list separators canonically" {
  assert_format(
    (
      #|module Test
      #|import Lib.{ alpha,beta }
      #|struct Pair { left:Int; right:Int }
      #|pub let pair:Pair=Pair::{ left:20,right:22 }
      #|pub fn sum(value:Pair)->Int {
      #|match value { Pair::{ left,right } => left + right }
      #|}
    ),
    (
      #|module Test
      #|
      #|import Lib.{ alpha, beta }
      #|
      #|struct Pair {
      #|  left : Int
      #|  right : Int
      #|}
      #|
      #|pub let pair : Pair = Pair::{ left: 20, right: 22 }
      #|
      #|pub fn sum(value : Pair) -> Int {
      #|  match value {
      #|    Pair::{ left, right } => left + right
      #|  }
      #|}
      #|
    ),
  )
}

///|
test "format layout removes blank gaps between sequential expressions" {
  assert_format(
    (
      #|module Test
      #|fn print(value:String)->Unit { () }
      #|pub fn main()->Unit {
      #|print("first")
      #|
      #|
      #|print("second")
      #|}
    ),
    (
      #|module Test
      #|
      #|fn print(value : String) -> Unit {
      #|  ()
      #|}
      #|
      #|pub fn main() -> Unit {
      #|  print("first")
      #|  print("second")
      #|}
      #|
    ),
  )
}

///|
test "format layout sequences mixed with local declarations" {
  assert_format(
    (
      #|module Test
      #|fn mark()->Unit { () }
      #|pub fn build()->Int {
      #|mark();
      #|let answer:Int=42;
      #|fn read()->Int { answer };
      #|mark()
      #|read()
      #|}
    ),
    (
      #|module Test
      #|
      #|fn mark() -> Unit {
      #|  ()
      #|}
      #|
      #|pub fn build() -> Int {
      #|  mark()
      #|  let answer : Int = 42
      #|  fn read() -> Int {
      #|    answer
      #|  }
      #|  mark()
      #|  read()
      #|}
      #|
    ),
  )
}
