///|
fn expect_parse_ok(source : String) -> @syntax.SourceFile {
  let result = @parser.parse_string("module Test\n" + source)
  if !result.lexical_errors.is_empty() || !result.parse_errors.is_empty() {
    abort("expected parse success")
  }
  guard result.source is Some(file) else { abort("expected source file") }
  file
}

///|
fn desugar_source(source : String) -> DesugaredSourceFile {
  let file = expect_parse_ok(source)
  let resolved = @resolve.resolve_source_file(file)
  desugar_source_file(resolved)
}

///|
test "desugar operators and pipeline into ordinary calls" {
  let source = desugar_source(
    (
      #|fn op_add(a : Int, b : Int) -> Int {
      #|  a
      #|}
      #|fn first(a : Int, b : Int) -> Int {
      #|  a
      #|}
      #|fn use() -> Int {
      #|  1 + 2 |> first(3)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(source, width=100),
    content=(
      #|desugared_source {
      #|  fn value#0 op_add {
      #|    body {
      #|      {
      #|        var value#3 a
      #|      }
      #|    }
      #|  }
      #|  fn value#1 first {
      #|    body {
      #|      {
      #|        var value#5 a
      #|      }
      #|    }
      #|  }
      #|  fn value#2 use {
      #|    body {
      #|      {
      #|        var value#1 first(var value#0 op_add(1, 2), 3)
      #|      }
      #|    }
      #|  }
      #|}
    ),
  )
}

///|
test "desugar lazy bool operators into thunked ordinary calls" {
  let source = desugar_source(
    (
      #|fn op_and(a : Bool, b : () -> Bool) -> Bool {
      #|  a
      #|}
      #|fn use(a : Bool, b : Bool) -> Bool {
      #|  a && b
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(source, width=100),
    content=(
      #|desugared_source {
      #|  fn value#0 op_and {
      #|    body {
      #|      {
      #|        var value#2 a
      #|      }
      #|    }
      #|  }
      #|  fn value#1 use {
      #|    body {
      #|      {
      #|        var value#0 op_and(var value#4 a, fn() -> Bool var value#5 b)
      #|      }
      #|    }
      #|  }
      #|}
    ),
  )
}

///|
test "desugar preserves offered value definitions and expands struct field punning" {
  let source = desugar_source(
    (
      #|struct Box {
      #|  value : Int
      #|}
      #|offer box : Box = Box::{ value: 1 }
      #|fn make(value : Int) -> Box {
      #|  Box::{ value }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(source, width=100),
    content=(
      #|desugared_source {
      #|  struct type#0 Box {
      #|    field field#0 value : Int index=0
      #|  }
      #|  offer value#0 box {
      #|    Box::{
      #|      value: 1
      #|    }
      #|  }
      #|  fn value#1 make {
      #|    body {
      #|      {
      #|        Box::{
      #|          value: var value#2 value
      #|        }
      #|      }
      #|    }
      #|  }
      #|}
    ),
  )
}

///|
test "desugar qualified and unqualified variant calls into one expression shape" {
  let source = desugar_source(
    (
      #|enum Option[A] {
      #|  none
      #|  some(A)
      #|}
      #|fn qualified(value : Int) -> Option[Int] {
      #|  Option::some(value)
      #|}
      #|fn unqualified(value : Int) -> Option[Int] {
      #|  some(value)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(source, width=100),
    content=(
      #|desugared_source {
      #|  enum type#0 Option[tparam#0 A] {
      #|    variant variant#0 none index=0 payloads=0
      #|    variant variant#1 some index=1 payloads=1(tparam#0 A)
      #|  }
      #|  fn value#0 qualified {
      #|    body {
      #|      {
      #|        variant#1 Option::some(var value#2 value)
      #|      }
      #|    }
      #|  }
      #|  fn value#1 unqualified {
      #|    body {
      #|      {
      #|        variant#1 some(var value#3 value)
      #|      }
      #|    }
      #|  }
      #|}
    ),
  )
}
