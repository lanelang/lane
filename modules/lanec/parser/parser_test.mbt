///|
fn expect_parse_ok(source : String) -> @syntax.SourceFile {
  let result = parse_string("module Test\n" + source)
  if !result.lexical_errors().is_empty() || !result.parse_errors().is_empty() {
    abort(
      "expected parse success, got lexical_errors=\{Repr(result.lexical_errors())} parse_errors=\{Repr(result.parse_errors())}",
    )
  }
  guard result.syntax() is Some(file) else { abort("expected source file") }
  file
}

///|
fn parse_errors(source : String) -> Array[ParseError] {
  let result = parse_string("module Test\n" + source)
  if !result.lexical_errors().is_empty() {
    abort("expected parser errors, got lexer errors")
  }
  result.parse_errors()
}

///|
fn parse_error_kinds(source : String) -> Array[ParseErrorKind] {
  parse_errors(source).map(fn(error) { error.kind })
}

///|
test "parse character literals in expressions and patterns" {
  let file = expect_parse_ok(
    (
      #|fn classify(value : Char) -> Char {
      #|  match value {
      #|    '你' => '\u{1F600}'
      #|    _ => 'x'
      #|  }
      #|}
    ),
  )
  debug_inspect(
    file.declarations,
    content=(
      #|[
      #|  Function(
      #|    {
      #|      is_public: false,
      #|      is_offered: false,
      #|      type_parameters: [],
      #|      name: "classify",
      #|      name_loc: {
      #|        start_offset: 15,
      #|        end_offset: 23,
      #|        start_line: 2,
      #|        start_column: 4,
      #|        end_line: 2,
      #|        end_column: 12,
      #|      },
      #|      parameters: [
      #|        {
      #|          is_auto: false,
      #|          is_offered: false,
      #|          name: "value",
      #|          name_loc: {
      #|            start_offset: 24,
      #|            end_offset: 29,
      #|            start_line: 2,
      #|            start_column: 13,
      #|            end_line: 2,
      #|            end_column: 18,
      #|          },
      #|          type_: Name(
      #|            name="Char",
      #|            loc={
      #|              start_offset: 32,
      #|              end_offset: 36,
      #|              start_line: 2,
      #|              start_column: 21,
      #|              end_line: 2,
      #|              end_column: 25,
      #|            },
      #|          ),
      #|          loc: {
      #|            start_offset: 24,
      #|            end_offset: 36,
      #|            start_line: 2,
      #|            start_column: 13,
      #|            end_line: 2,
      #|            end_column: 25,
      #|          },
      #|        },
      #|      ],
      #|      return_type: Name(
      #|        name="Char",
      #|        loc={
      #|          start_offset: 41,
      #|          end_offset: 45,
      #|          start_line: 2,
      #|          start_column: 30,
      #|          end_line: 2,
      #|          end_column: 34,
      #|        },
      #|      ),
      #|      effect: Empty(
      #|        loc={
      #|          start_offset: 41,
      #|          end_offset: 45,
      #|          start_line: 2,
      #|          start_column: 30,
      #|          end_line: 2,
      #|          end_column: 34,
      #|        },
      #|      ),
      #|      body: Block(
      #|        items=[],
      #|        result=Match(
      #|          scrutinee=Var(
      #|            "value",
      #|            loc={
      #|              start_offset: 56,
      #|              end_offset: 61,
      #|              start_line: 3,
      #|              start_column: 9,
      #|              end_line: 3,
      #|              end_column: 14,
      #|            },
      #|          ),
      #|          arms=[
      #|            {
      #|              pattern: CharLiteral(
      #|                20320,
      #|                loc={
      #|                  start_offset: 68,
      #|                  end_offset: 71,
      #|                  start_line: 4,
      #|                  start_column: 5,
      #|                  end_line: 4,
      #|                  end_column: 8,
      #|                },
      #|              ),
      #|              body: CharLiteral(
      #|                128512,
      #|                loc={
      #|                  start_offset: 75,
      #|                  end_offset: 86,
      #|                  start_line: 4,
      #|                  start_column: 12,
      #|                  end_line: 4,
      #|                  end_column: 23,
      #|                },
      #|              ),
      #|              loc: {
      #|                start_offset: 68,
      #|                end_offset: 86,
      #|                start_line: 4,
      #|                start_column: 5,
      #|                end_line: 4,
      #|                end_column: 23,
      #|              },
      #|            },
      #|            {
      #|              pattern: Wildcard(
      #|                {
      #|                  start_offset: 91,
      #|                  end_offset: 92,
      #|                  start_line: 5,
      #|                  start_column: 5,
      #|                  end_line: 5,
      #|                  end_column: 6,
      #|                },
      #|              ),
      #|              body: CharLiteral(
      #|                120,
      #|                loc={
      #|                  start_offset: 96,
      #|                  end_offset: 99,
      #|                  start_line: 5,
      #|                  start_column: 10,
      #|                  end_line: 5,
      #|                  end_column: 13,
      #|                },
      #|              ),
      #|              loc: {
      #|                start_offset: 91,
      #|                end_offset: 99,
      #|                start_line: 5,
      #|                start_column: 5,
      #|                end_line: 5,
      #|                end_column: 13,
      #|              },
      #|            },
      #|          ],
      #|          loc={
      #|            start_offset: 50,
      #|            end_offset: 103,
      #|            start_line: 3,
      #|            start_column: 3,
      #|            end_line: 6,
      #|            end_column: 4,
      #|          },
      #|        ),
      #|        loc={
      #|          start_offset: 46,
      #|          end_offset: 105,
      #|          start_line: 2,
      #|          start_column: 35,
      #|          end_line: 7,
      #|          end_column: 2,
      #|        },
      #|      ),
      #|      loc: {
      #|        start_offset: 12,
      #|        end_offset: 105,
      #|        start_line: 2,
      #|        start_column: 1,
      #|        end_line: 7,
      #|        end_column: 2,
      #|      },
      #|    },
      #|  ),
      #|]
    ),
  )
}

///|
test "parse aliased qualified import with binder spans" {
  let file = expect_parse_ok("import Basic.Data.List as List")
  guard file.imports
    is [Qualified(module_path~, module_alias=Some(module_alias), loc~)] else {
    abort("expected one aliased qualified import")
  }
  debug_inspect(
    (module_path, module_alias, loc),
    content=(
      #|(
      #|  {
      #|    components: ["Basic", "Data", "List"],
      #|    loc: {
      #|      start_offset: 19,
      #|      end_offset: 34,
      #|      start_line: 2,
      #|      start_column: 8,
      #|      end_line: 2,
      #|      end_column: 23,
      #|    },
      #|  },
      #|  {
      #|    name: "List",
      #|    name_loc: {
      #|      start_offset: 38,
      #|      end_offset: 42,
      #|      start_line: 2,
      #|      start_column: 27,
      #|      end_line: 2,
      #|      end_column: 31,
      #|    },
      #|    loc: {
      #|      start_offset: 35,
      #|      end_offset: 42,
      #|      start_line: 2,
      #|      start_column: 24,
      #|      end_line: 2,
      #|      end_column: 31,
      #|    },
      #|  },
      #|  {
      #|    start_offset: 12,
      #|    end_offset: 42,
      #|    start_line: 2,
      #|    start_column: 1,
      #|    end_line: 2,
      #|    end_column: 31,
      #|  },
      #|)
    ),
  )
}

///|
test "import aliases are rejected on open and selective imports" {
  debug_inspect(
    parse_error_kinds("import Basic.Data.List.* as List"),
    content=(
      #|[
      #|  UnexpectedToken(
      #|    { label: "`as`" },
      #|    [
      #|      { label: "end of file" },
      #|      { label: "`struct`" },
      #|      { label: "`enum`" },
      #|      { label: "`effect`" },
      #|      { label: "`fn`" },
      #|      { label: "`let`" },
      #|      { label: "`type`" },
      #|      { label: "`offer`" },
      #|      { label: "`extern`" },
      #|      { label: "`import`" },
      #|      { label: "`pub`" },
      #|    ],
      #|  ),
      #|]
    ),
  )
  debug_inspect(
    parse_error_kinds("import Basic.Data.List.{ empty } as List"),
    content=(
      #|[
      #|  UnexpectedToken(
      #|    { label: "`as`" },
      #|    [
      #|      { label: "end of file" },
      #|      { label: "`struct`" },
      #|      { label: "`enum`" },
      #|      { label: "`effect`" },
      #|      { label: "`fn`" },
      #|      { label: "`let`" },
      #|      { label: "`type`" },
      #|      { label: "`offer`" },
      #|      { label: "`extern`" },
      #|      { label: "`import`" },
      #|      { label: "`pub`" },
      #|    ],
      #|  ),
      #|]
    ),
  )
}

///|
priv struct ParseFailureConcreteSummary {
  errors : Array[ParseErrorKind]
  trivia : Array[@lexer.TriviaKind]
} derive(Debug)

///|
test "parse grammar failure keeps concrete syntax" {
  let result = parse_string("module Test\nlet x : = // keep")
  guard result is Failed(Grammar(concrete, errors, _)) else {
    abort("expected grammar parse failure")
  }
  debug_inspect(
    ParseFailureConcreteSummary::{
      errors: errors.map(fn(error) { error.kind }),
      trivia: concrete.trivia.map(fn(item) { item.kind }),
    },
    content=(
      #|{
      #|  errors: [
      #|    UnexpectedToken(
      #|      { label: "`=`" },
      #|      [
      #|        { label: "identifier" },
      #|        { label: "`type`" },
      #|        { label: "`(`" },
      #|        { label: "`[`" },
      #|      ],
      #|    ),
      #|  ],
      #|  trivia: [
      #|    Whitespace,
      #|    Newline,
      #|    Whitespace,
      #|    Whitespace,
      #|    Whitespace,
      #|    Whitespace,
      #|    LineComment,
      #|  ],
      #|}
    ),
  )
}

///|
test "parse failures retain expected identifier slots" {
  let type_result = parse_string("module Test\npub let value :")
  guard type_result.parse_errors().get(0) is Some(type_error) else {
    abort("expected missing type parse error")
  }
  assert_eq(type_error.loc.start_offset, type_error.loc.end_offset)
  assert_eq(
    type_result
    .syntactic_identifier_index()
    .role_at(type_error.loc.start_offset),
    Some(TypeIdentifier),
  )
  let effect_result = parse_string("module Test\nfn run() -> Unit !")
  guard effect_result.parse_errors().get(0) is Some(effect_error) else {
    abort("expected missing effect parse error")
  }
  assert_eq(effect_error.loc.start_offset, effect_error.loc.end_offset)
  assert_eq(
    effect_result
    .syntactic_identifier_index()
    .role_at(effect_error.loc.start_offset),
    Some(EffectIdentifier),
  )
  let value_result = parse_string("module Test\npub let value : I64 =")
  guard value_result.parse_errors().get(0) is Some(value_error) else {
    abort("expected missing value parse error")
  }
  assert_eq(
    value_result
    .syntactic_identifier_index()
    .role_at(value_error.loc.start_offset),
    Some(ValueIdentifier),
  )
}

///|
test "truncated identifiers retain their syntactic roles" {
  let sources = [
    "module Test\npub let value : Thi", "module Test\nfn run() -> Unit ! Con", "module Test\nfn make() -> (I64, I64) { (1, Thi",
    "module Test\nfn use(value : I64) -> I64 { match value { (head, Thi",
  ]
  let roles = sources.map(fn(source) {
    parse_string(source).syntactic_identifier_index().role_at(source.length())
  })
  debug_inspect(
    roles,
    content=(
      #|[
      #|  Some(TypeIdentifier),
      #|  Some(EffectIdentifier),
      #|  Some(ValueIdentifier),
      #|  Some(PatternIdentifier),
      #|]
    ),
  )
}

///|
test "incomplete tuple items retain type value and pattern slots" {
  let type_result = parse_string("module Test\ntype Pair = (I64,")
  guard type_result.parse_errors().get(0) is Some(type_error) else {
    abort("expected missing tuple type item")
  }
  assert_eq(
    type_result
    .syntactic_identifier_index()
    .role_at(type_error.loc.start_offset),
    Some(TypeIdentifier),
  )
  let value_result = parse_string("module Test\nfn make() -> I64 { (1,")
  guard value_result.parse_errors().get(0) is Some(value_error) else {
    abort("expected missing tuple expression item")
  }
  assert_eq(
    value_result
    .syntactic_identifier_index()
    .role_at(value_error.loc.start_offset),
    Some(ValueIdentifier),
  )
  let pattern_result = parse_string(
    "module Test\nfn use(value : I64) -> I64 { match value { (head,",
  )
  guard pattern_result.parse_errors().get(0) is Some(pattern_error) else {
    abort("expected missing tuple pattern item")
  }
  assert_eq(
    pattern_result
    .syntactic_identifier_index()
    .role_at(pattern_error.loc.start_offset),
    Some(PatternIdentifier),
  )
}

///|
test "syntactic identifier roles include nested pattern type owners" {
  let source =
    #|module Test
    #|
    #|fn inspect(value : I64) -> I64 {
    #|  match value {
    #|    MatchOwner::variant(NestedOwner::{ field }) => 0
    #|  }
    #|}
    #|
    #|fn destructure(value : I64) -> I64 {
    #|  let LetOwner::{ field: LetNested::variant() } = value
    #|  0
    #|}
    #|
    #|fn handle_it(value : I64) -> I64 {
    #|  handle value with {
    #|    Console::op(HandlerOwner::{ field: HandlerNested::variant() }, resume) => 0
    #|  } final result { result }
    #|}
  let result = parse_string(source)
  guard result is Parsed(_) else { abort("expected parsed source") }
  let index = result.syntactic_identifier_index()
  for
    owner in [
      "MatchOwner", "NestedOwner", "LetOwner", "LetNested", "HandlerOwner", "HandlerNested",
    ] {
    guard source.find(owner) is Some(offset) else {
      abort("expected pattern owner in source")
    }
    assert_eq(index.role_at(offset), Some(TypeIdentifier))
  }
}

///|
test "parse rejects explicit semicolons outside item bodies" {
  debug_inspect(
    parse_string("module M;\npub let answer : I64 = 42").parse_errors(),
    content=(
      #|[
      #|  {
      #|    kind: UnexpectedToken(
      #|      { label: "`;`" },
      #|      [
      #|        { label: "end of file" },
      #|        { label: "`struct`" },
      #|        { label: "`enum`" },
      #|        { label: "`effect`" },
      #|        { label: "`fn`" },
      #|        { label: "`let`" },
      #|        { label: "`type`" },
      #|        { label: "`offer`" },
      #|        { label: "`extern`" },
      #|        { label: "`import`" },
      #|        { label: "`pub`" },
      #|        { label: "`.`" },
      #|      ],
      #|    ),
      #|    loc: {
      #|      start_offset: 8,
      #|      end_offset: 9,
      #|      start_line: 1,
      #|      start_column: 9,
      #|      end_line: 1,
      #|      end_column: 10,
      #|    },
      #|  },
      #|]
    ),
  )
  debug_inspect(
    parse_errors("let first : I64 = 1;\nlet second : I64 = 2"),
    content=(
      #|[
      #|  {
      #|    kind: UnexpectedToken(
      #|      { label: "`;`" },
      #|      [
      #|        { label: "end of file" },
      #|        { label: "`struct`" },
      #|        { label: "`enum`" },
      #|        { label: "`effect`" },
      #|        { label: "`fn`" },
      #|        { label: "`let`" },
      #|        { label: "`type`" },
      #|        { label: "`offer`" },
      #|        { label: "`extern`" },
      #|        { label: "`pub`" },
      #|        { label: "`+`" },
      #|        { label: "`-`" },
      #|        { label: "`*`" },
      #|        { label: "`/`" },
      #|        { label: "`%`" },
      #|        { label: "`==`" },
      #|        { label: "`!=`" },
      #|        { label: "`<`" },
      #|        { label: "`<=`" },
      #|        { label: "`>`" },
      #|        { label: "`>=`" },
      #|        { label: "`&&`" },
      #|        { label: "`||`" },
      #|        { label: "`|>`" },
      #|        { label: "`(`" },
      #|        { label: "`[`" },
      #|        { label: "`.`" },
      #|      ],
      #|    ),
      #|    loc: {
      #|      start_offset: 31,
      #|      end_offset: 32,
      #|      start_line: 2,
      #|      start_column: 20,
      #|      end_line: 2,
      #|      end_column: 21,
      #|    },
      #|  },
      #|]
    ),
  )
  debug_inspect(
    parse_errors(
      (
        #|struct Box[A, B] {
        #|  first : A
        #|  second : B
        #|}
        #|fn bad(value : Box[I64; Bool]) -> Box[I64, Bool] {
        #|  value
        #|}
      ),
    ),
    content=(
      #|[
      #|  {
      #|    kind: UnexpectedToken(
      #|      { label: "`;`" },
      #|      [
      #|        { label: "`[`" },
      #|        { label: "`]`" },
      #|        { label: "`,`" },
      #|        { label: "`.`" },
      #|      ],
      #|    ),
      #|    loc: {
      #|      start_offset: 80,
      #|      end_offset: 81,
      #|      start_line: 6,
      #|      start_column: 23,
      #|      end_line: 6,
      #|      end_column: 24,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "parse rejects repeated item separators" {
  debug_inspect(
    parse_errors(
      (
        #|fn mark() -> Unit { () }
        #|fn bad() -> Unit {
        #|  mark();; // keep
        #|  ()
        #|}
      ),
    ),
    content=(
      #|[
      #|  {
      #|    kind: UnexpectedToken(
      #|      { label: "`;`" },
      #|      [
      #|        { label: "integer literal" },
      #|        { label: "double literal" },
      #|        { label: "string literal" },
      #|        { label: "character literal" },
      #|        { label: "identifier" },
      #|        { label: "`false`" },
      #|        { label: "`true`" },
      #|        { label: "`fn`" },
      #|        { label: "`let`" },
      #|        { label: "`offer`" },
      #|        { label: "`if`" },
      #|        { label: "`match`" },
      #|        { label: "`handle`" },
      #|        { label: "`derive`" },
      #|        { label: "`builtin`" },
      #|        { label: "`extern`" },
      #|        { label: "`-`" },
      #|        { label: "`!`" },
      #|        { label: "`(`" },
      #|        { label: "`{`" },
      #|        { label: "`[`" },
      #|      ],
      #|    ),
      #|    loc: {
      #|      start_offset: 65,
      #|      end_offset: 66,
      #|      start_line: 4,
      #|      start_column: 10,
      #|      end_line: 4,
      #|      end_column: 11,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "parse positional call argument keeps argument source span" {
  let file = expect_parse_ok(
    (
      #|struct Box {
      #|  field : I64
      #|}
      #|fn take(input : I64) -> I64 {
      #|  input
      #|}
      #|fn answer(value : Box) -> I64 {
      #|  take(value.field)
      #|}
    ),
  )
  guard file.declarations[2] is Function(function) else {
    abort("expected function declaration")
  }
  guard function.body is Block(result~, ..) else {
    abort("expected block body")
  }
  guard result is Call(arguments~, ..) else { abort("expected call") }
  guard arguments[0] is Positional(value=Field(name~, loc=field_loc, ..), loc~) else {
    abort("expected positional field argument")
  }
  debug_inspect(
    (name, field_loc, loc),
    content=(
      #|(
      #|  "field",
      #|  {
      #|    start_offset: 120,
      #|    end_offset: 131,
      #|    start_line: 9,
      #|    start_column: 8,
      #|    end_line: 9,
      #|    end_column: 19,
      #|  },
      #|  {
      #|    start_offset: 120,
      #|    end_offset: 131,
      #|    start_line: 9,
      #|    start_column: 8,
      #|    end_line: 9,
      #|    end_column: 19,
      #|  },
      #|)
    ),
  )
}

///|
test "parse declarations and blocks keep complete source spans" {
  let file = expect_parse_ok("pub fn answer() -> I64 { 42 }")
  guard file.declarations[0] is Function(function) else {
    abort("expected function declaration")
  }
  guard function.body is Block(result~, loc=body_loc, ..) else {
    abort("expected function block")
  }
  debug_inspect(
    (function.loc, body_loc, result.loc()),
    content=(
      #|(
      #|  {
      #|    start_offset: 12,
      #|    end_offset: 41,
      #|    start_line: 2,
      #|    start_column: 1,
      #|    end_line: 2,
      #|    end_column: 30,
      #|  },
      #|  {
      #|    start_offset: 35,
      #|    end_offset: 41,
      #|    start_line: 2,
      #|    start_column: 24,
      #|    end_line: 2,
      #|    end_column: 30,
      #|  },
      #|  {
      #|    start_offset: 37,
      #|    end_offset: 39,
      #|    start_line: 2,
      #|    start_column: 26,
      #|    end_line: 2,
      #|    end_column: 28,
      #|  },
      #|)
    ),
  )
}

///|
test "parse sequential unit expressions as block local items" {
  let file = expect_parse_ok(
    (
      #|fn print(value : String) -> Unit {
      #|  ()
      #|}
      #|fn main() -> Unit {
      #|  print("hello");
      #|  print("world")
      #|}
    ),
  )
  guard file.declarations[1] is Function(function) else {
    abort("expected main function")
  }
  guard function.body
    is Block(items=[Expression(expression=Call(..))], result=Call(..), ..) else {
    abort("expected one sequential expression and one block result")
  }
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|fn print(value : String) -> Unit {
      #|  ()
      #|}
      #|
      #|fn main() -> Unit {
      #|  print("hello")
      #|  print("world")
      #|}
    ),
  )
}

///|
test "parse newline-separated unit expressions as block local items" {
  let file = expect_parse_ok(
    (
      #|fn print(value : String) -> Unit {
      #|  ()
      #|}
      #|fn main() -> Unit {
      #|  print("hello")
      #|  print("world")
      #|}
    ),
  )
  guard file.declarations[1] is Function(function) else {
    abort("expected main function")
  }
  assert_true(
    function.body
    is Block(items=[Expression(expression=Call(..))], result=Call(..), ..),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|fn print(value : String) -> Unit {
      #|  ()
      #|}
      #|
      #|fn main() -> Unit {
      #|  print("hello")
      #|  print("world")
      #|}
    ),
  )
}

///|
test "parse newline after if expression as a sequence separator" {
  let file = expect_parse_ok(
    (
      #|fn main(condition : Bool) -> Unit {
      #|  if condition {
      #|    ()
      #|  }
      #|  if condition {
      #|    ()
      #|  }
      #|}
    ),
  )
  guard file.declarations[0] is Function(function) else {
    abort("expected main function")
  }
  assert_true(
    function.body
    is Block(items=[Expression(expression=If(..))], result=If(..), ..),
  )
}

///|
test "parse newline-separated struct literal fields" {
  let file = expect_parse_ok(
    (
      #|struct Pair {
      #|  fst : I64
      #|  snd : I64
      #|}
      #|fn make() -> Pair {
      #|  Pair::{ fst: 1
      #|    snd: 2 }
      #|}
    ),
  )
  guard file.declarations[1] is Function(function) else {
    abort("expected make function")
  }
  assert_true(
    function.body
    is Block(result=StructLiteral(fields=[Value(..), Value(..)], ..), ..),
  )
}

///|
test "parse unit literal as a sequential expression" {
  let result = parse_string(
    (
      #|module Test
      #|fn main() -> Unit {
      #|  ();
      #|  ()
      #|}
    ),
  )
  debug_inspect(result.parse_errors(), content="[]")
}

///|
test "parse declarations between sequential expressions" {
  let result = parse_string(
    (
      #|module Test
      #|fn mark() -> Unit {
      #|  ()
      #|}
      #|fn build() -> I64 {
      #|  mark();
      #|  let answer : I64 = 42
      #|  mark();
      #|  answer
      #|}
    ),
  )
  debug_inspect(result.parse_errors(), content="[]")
}

///|
test "parse nominal declarations and match" {
  let file = expect_parse_ok(
    (
      #|struct Point {
      #|  x : I64
      #|  y : I64
      #|}
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|fn unwrap_or(value : Option[I64], fallback : I64) -> I64 {
      #|  match value {
      #|    none() => fallback
      #|    some(x) => x
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|struct Point {
      #|  x : I64
      #|  y : I64
      #|}
      #|
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|
      #|fn unwrap_or(value : Option[I64], fallback : I64) -> I64 {
      #|  match value {
      #|    none() => fallback
      #|    some(x) => x
      #|  }
      #|}
    ),
  )
}

///|
test "parse unqualified enum variant pattern" {
  let file = expect_parse_ok(
    (
      #|enum Single {
      #|  wrap(I64)
      #|}
      #|fn unwrap(value : Single) -> I64 {
      #|  match value {
      #|    wrap(x) => x
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|enum Single {
      #|  wrap(I64)
      #|}
      #|
      #|fn unwrap(value : Single) -> I64 {
      #|  match value {
      #|    wrap(x) => x
      #|  }
      #|}
    ),
  )
}

///|
test "parse single-constructor enum pattern let" {
  let file = expect_parse_ok(
    (
      #|enum Single {
      #|  wrap(I64)
      #|}
      #|fn unwrap(value : Single) -> I64 {
      #|  {
      #|    let wrap(x) = value
      #|    x
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|enum Single {
      #|  wrap(I64)
      #|}
      #|
      #|fn unwrap(value : Single) -> I64 {
      #|  {
      #|    let wrap(x) = value
      #|    x
      #|  }
      #|}
    ),
  )
}

///|
test "parse does not recognize spaced double colon as qualified variant pattern" {
  debug_inspect(
    parse_error_kinds(
      (
        #|enum Option[A] {
        #|  none()
        #|  some(A)
        #|}
        #|fn unwrap(value : Option[I64], fallback : I64) -> I64 {
        #|  match value {
        #|    Option :: none() => fallback
        #|  }
        #|}
      ),
    ),
    content=(
      #|[
      #|  UnexpectedToken(
      #|    { label: "`:`" },
      #|    [
      #|      { label: "`(`" },
      #|      { label: "`[`" },
      #|      { label: "`.`" },
      #|      { label: "`::`" },
      #|      { label: "`=>`" },
      #|    ],
      #|  ),
      #|]
    ),
  )
}

///|
test "parse does not recognize right-spaced double colon as variant pattern" {
  debug_inspect(
    parse_error_kinds(
      (
        #|enum Option[A] {
        #|  none()
        #|  some(A)
        #|}
        #|fn unwrap(value : Option[I64], fallback : I64) -> I64 {
        #|  match value {
        #|    Option:: none() => fallback
        #|  }
        #|}
      ),
    ),
    content=(
      #|[
      #|  UnexpectedToken(
      #|    { label: "`:`" },
      #|    [
      #|      { label: "`(`" },
      #|      { label: "`[`" },
      #|      { label: "`.`" },
      #|      { label: "`::`" },
      #|      { label: "`=>`" },
      #|    ],
      #|  ),
      #|]
    ),
  )
}

///|
test "parse rejects leading double colon enum variant pattern" {
  assert_false(
    parse_errors(
      (
        #|enum Single {
        #|  wrap(I64)
        #|}
        #|fn unwrap(value : Single) -> I64 {
        #|  match value {
        #|    ::wrap(x) => x
        #|  }
        #|}
      ),
    ).is_empty(),
  )
}

///|
test "parse type aliases and F-omega type expressions" {
  let file = expect_parse_ok(
    (
      #|struct Box[A] {
      #|  value : A
      #|}
      #|type Id[A] = A
      #|type ApplyInt[F : [Type] -> Type] = F[I64]
      #|fn get(box : ApplyInt[Box]) -> Id[I64] {
      #|  box.value
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|struct Box[A] {
      #|  value : A
      #|}
      #|
      #|type Id[A] = A
      #|
      #|type ApplyInt[F : [Type] -> Type] = F[I64]
      #|
      #|fn get(box : ApplyInt[Box]) -> Id[I64] {
      #|  box.value
      #|}
    ),
  )
}

///|
test "parse explicit generic expression application" {
  let file = expect_parse_ok(
    (
      #|fn[A] id(value : A) -> A {
      #|  value
      #|}
      #|fn use() -> I64 {
      #|  {
      #|    let id_int : (I64) -> I64 = id[I64]
      #|    id[I64](id_int(1))
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|fn[A] id(value : A) -> A {
      #|  value
      #|}
      #|
      #|fn use() -> I64 {
      #|  {
      #|    let id_int : (I64) -> I64 = id[I64]
      #|    id[I64](id_int(1))
      #|  }
      #|}
    ),
  )
}

///|
test "parse braced effect generic arguments" {
  let file = expect_parse_ok(
    (
      #|effect Log {
      #|  write(I64) -> Unit
      #|}
      #|effect Ops {
      #|  ping[E : Effect]() -> Unit
      #|}
      #|effect Coroutine[E : Effect] {
      #|  yield() -> Unit
      #|}
      #|struct Box[A, E : Effect] {
      #|  value : A
      #|}
      #|enum Task {
      #|  task[E : Effect]()
      #|}
      #|fn[E : Effect] run(action : () -> Unit ! E) -> Unit ! E {
      #|  action()
      #|}
      #|fn pure() -> Unit {
      #|  ()
      #|}
      #|fn use() -> I64 ! Ops {
      #|  {
      #|    let ran : Unit = run[{}](pure)
      #|    let box : Box[I64, {}] = Box[I64, {}]::{ value: 1 }
      #|    let task : Task = Task::task[{ Log }]()
      #|    let pinged : Unit = Ops::ping![{}]()
      #|    box.value
      #|  }
      #|}
      #|fn handled() -> Unit {
      #|  handle Coroutine[{}]::yield!() with {
      #|    Coroutine[{}]::yield(resume) => resume(())
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|effect Log {
      #|  write(I64) -> Unit
      #|}
      #|
      #|effect Ops {
      #|  ping[E : Effect]() -> Unit
      #|}
      #|
      #|effect Coroutine[E : Effect] {
      #|  yield() -> Unit
      #|}
      #|
      #|struct Box[A, E : Effect] {
      #|  value : A
      #|}
      #|
      #|enum Task {
      #|  task[E : Effect]()
      #|}
      #|
      #|fn[E : Effect] run(action : () -> Unit ! E) -> Unit ! E {
      #|  action()
      #|}
      #|
      #|fn pure() -> Unit {
      #|  ()
      #|}
      #|
      #|fn use() -> I64 ! Ops {
      #|  {
      #|    let ran : Unit = run[{}](pure)
      #|    let box : Box[I64, {}] = Box[I64, {}]::{ value: 1 }
      #|    let task : Task = Task::task[{ Log }]()
      #|    let pinged : Unit = Ops::ping![{}]()
      #|    box.value
      #|  }
      #|}
      #|
      #|fn handled() -> Unit {
      #|  handle Coroutine[{}]::yield!() with {
      #|    Coroutine[{}]::yield(resume) => resume(())
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
}

///|
test "parse rejects empty explicit generic expression arguments" {
  debug_inspect(
    parse_error_kinds(
      (
        #|fn[A] id(value : A) -> A {
        #|  value
        #|}
        #|fn use() -> I64 {
        #|  id[](1)
        #|}
      ),
    ),
    content=(
      #|[EmptyGenericArgumentList]
    ),
  )
}

///|
test "parse type alias with effect set body" {
  let file = expect_parse_ok(
    (
      #|effect Console {
      #|  read() -> I64
      #|}
      #|effect Log {
      #|  write(I64) -> Unit
      #|}
      #|type Answer : Type = I64
      #|type Identity : [Type] -> Type = type[A] => A
      #|type UI : Effect = { Console, Log }
      #|type Task[E : Effect] : Effect = { UI, E }
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|effect Console {
      #|  read() -> I64
      #|}
      #|
      #|effect Log {
      #|  write(I64) -> Unit
      #|}
      #|
      #|type Answer : Type = I64
      #|
      #|type Identity : [Type] -> Type = type[A] => A
      #|
      #|type UI : Effect = { Console, Log }
      #|
      #|type Task[E : Effect] : Effect = { UI, E }
    ),
  )
}

///|
test "parse tuple syntax and format right-nested tuples flat" {
  let file = expect_parse_ok(
    (
      #|type Pair = (I64, Bool)
      #|type Triple = (I64, (Bool, String))
      #|fn make() -> (I64, Bool, String) {
      #|  (1, (true, "lane"))
      #|}
      #|fn first(value : (I64, Bool, String)) -> I64 {
      #|  match value {
      #|    (head, _, _) => head
      #|  }
      #|}
      #|fn apply(f : ((I64, Bool)) -> I64, value : (I64, Bool)) -> I64 {
      #|  f(value)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|type Pair = (I64, Bool)
      #|
      #|type Triple = (I64, Bool, String)
      #|
      #|fn make() -> (I64, Bool, String) {
      #|  (1, true, "lane")
      #|}
      #|
      #|fn first(value : (I64, Bool, String)) -> I64 {
      #|  match value {
      #|    (head, _, _) => head
      #|  }
      #|}
      #|
      #|fn apply(f : ((I64, Bool)) -> I64, value : (I64, Bool)) -> I64 {
      #|  f(value)
      #|}
    ),
  )
}

///|
test "tuple syntax rejects singleton tuples and bare function parameter types" {
  assert_eq(parse_error_kinds("type Bad = (I64,)"), [MissingTupleItem])
  assert_eq(parse_error_kinds("fn bad() -> I64 { (1,) }"), [MissingTupleItem])
  assert_eq(
    parse_error_kinds(
      (
        #|fn bad(value : I64) -> I64 {
        #|  match value {
        #|    (item,) => item
        #|  }
        #|}
      ),
    ),
    [MissingTupleItem],
  )
  debug_inspect(
    parse_errors("type Bad = I64 -> I64"),
    content=(
      #|[
      #|  {
      #|    kind: UnexpectedToken(
      #|      { label: "`->`" },
      #|      [
      #|        { label: "end of file" },
      #|        { label: "`struct`" },
      #|        { label: "`enum`" },
      #|        { label: "`effect`" },
      #|        { label: "`fn`" },
      #|        { label: "`let`" },
      #|        { label: "`type`" },
      #|        { label: "`offer`" },
      #|        { label: "`extern`" },
      #|        { label: "`pub`" },
      #|        { label: "`[`" },
      #|        { label: "`.`" },
      #|      ],
      #|    ),
      #|    loc: {
      #|      start_offset: 27,
      #|      end_offset: 29,
      #|      start_line: 2,
      #|      start_column: 16,
      #|      end_line: 2,
      #|      end_column: 18,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "parse rejects unknown kind names in every kind position" {
  let accepted = [
    "type A : Banana = I64",
    "type A[T : Banana] = T",
    (
      #|struct S {
      #|  type A : Banana
      #|}
    ),
    "extern type A : Banana",
    "type A : [Banana] -> Type = I64",
    "type A : [Type] -> Banana = I64",
    "type A : effect = I64",
  ].filter(fn(source) { parse_errors(source).is_empty() })
  debug_inspect(accepted, content="[]")
  debug_inspect(
    parse_error_kinds("type A : Banana = I64"),
    content=(
      #|[
      #|  UnexpectedToken(
      #|    { label: "identifier `Banana`" },
      #|    [
      #|      { label: "`Type`" },
      #|      { label: "`Effect`" },
      #|      { label: "`(`" },
      #|      { label: "`[`" },
      #|    ],
      #|  ),
      #|]
    ),
  )
}

///|
test "parse rejects value block as type alias body" {
  assert_false(parse_errors("type Bad = { let x : I64 = 1 x }").is_empty())
}

///|
test "parse function literal and pipeline" {
  let file = expect_parse_ok(
    (
      #|fn pipeline_literal(x : I64) -> I64 {
      #|  x |> fn(value : I64) {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|fn pipeline_literal(x : I64) -> I64 {
      #|  x
      #|    |> fn(value : I64) {
      #|      value
      #|    }
      #|}
    ),
  )
}

///|
test "parse else-if chain" {
  let file = expect_parse_ok(
    (
      #|fn choose(first : Bool, second : Bool) -> I64 {
      #|  if first {
      #|    1
      #|  } else if second {
      #|    2
      #|  } else {
      #|    3
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|fn choose(first : Bool, second : Bool) -> I64 {
      #|  if first {
      #|    1
      #|  } else if second {
      #|    2
      #|  } else {
      #|    3
      #|  }
      #|}
    ),
  )
}

///|
test "parse offered value definitions and contextual parameter syntax" {
  let file = expect_parse_ok(
    (
      #|struct Equal[A] {
      #|  equal : (A, A) -> Bool
      #|}
      #|struct Compare[A] {
      #|  equal_impl : Equal[A]
      #|  less : (A, A) -> Bool
      #|}
      #|fn[A] op_equal(a : A, b : A, auto op : Equal[A]) -> Bool {
      #|  op.equal(a, b)
      #|}
      #|offer i64_equal_ops : Equal[I64] = Equal::{ equal: i64_equal }
      #|fn use(a : I64, b : I64) -> Bool {
      #|  op_equal(a, b, op=i64_equal_ops)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|struct Equal[A] {
      #|  equal : (A, A) -> Bool
      #|}
      #|
      #|struct Compare[A] {
      #|  equal_impl : Equal[A]
      #|  less : (A, A) -> Bool
      #|}
      #|
      #|fn[A] op_equal(a : A, b : A, auto op : Equal[A]) -> Bool {
      #|  op.equal(a, b)
      #|}
      #|
      #|offer i64_equal_ops : Equal[I64] = Equal::{ equal: i64_equal }
      #|
      #|fn use(a : I64, b : I64) -> Bool {
      #|  op_equal(a, b, op=i64_equal_ops)
      #|}
    ),
  )
}

///|
test "parse offered function definitions" {
  let file = expect_parse_ok(
    (
      #|pub offer fn[A] provide(value : A) -> A {
      #|  value
      #|}
      #|fn outer() -> I64 {
      #|  offer fn local() -> I64 {
      #|    42
      #|  }
      #|  local()
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|pub offer fn[A] provide(value : A) -> A {
      #|  value
      #|}
      #|
      #|fn outer() -> I64 {
      #|  offer fn local() -> I64 {
      #|    42
      #|  }
      #|  local()
      #|}
    ),
  )
}

///|
test "parse effect declarations and effect kind" {
  let file = expect_parse_ok(
    (
      #|pub effect State[S] {
      #|  get() -> S
      #|  put(S) -> Unit
      #|  choose[A](A, A) -> A
      #|}
      #|struct Runner[F : Effect] {
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|pub effect State[S] {
      #|  get() -> S
      #|  put(S) -> Unit
      #|  choose[A](A, A) -> A
      #|}
      #|
      #|struct Runner[F : Effect] {}
    ),
  )
}

///|
test "parse effect operation calls" {
  let file = expect_parse_ok(
    (
      #|effect Console {
      #|  write(String) -> Unit
      #|  choose[A](A, A) -> A
      #|}
      #|fn write_hello() -> String ! Console {
      #|  let ignored : Unit = Console::write!("hi")
      #|  Console::choose![String]("left", "right")
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|effect Console {
      #|  write(String) -> Unit
      #|  choose[A](A, A) -> A
      #|}
      #|
      #|fn write_hello() -> String ! Console {
      #|  let ignored : Unit = Console::write!("hi")
      #|  Console::choose![String]("left", "right")
      #|}
    ),
  )
}

///|
test "parse qualified postfix forms inside expressions" {
  let file = expect_parse_ok(
    (
      #|effect Console {
      #|  choose[A](A, A) -> A
      #|}
      #|enum Option[A] {
      #|  none()
      #|  some[A](A)
      #|}
      #|struct Box[A] {
      #|  value : A
      #|}
      #|let boxed : Box[I64] = Box[I64]::{
      #|  value: Console::choose![I64](1, 2)
      #|}
      #|fn use(box : Box[I64]) -> Option[I64] ! Console {
      #|  Option::some[I64](Console::choose![I64](box.value, 0))
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|effect Console {
      #|  choose[A](A, A) -> A
      #|}
      #|
      #|enum Option[A] {
      #|  none()
      #|  some[A](A)
      #|}
      #|
      #|struct Box[A] {
      #|  value : A
      #|}
      #|
      #|let boxed : Box[I64] = Box[I64]::{ value: Console::choose![I64](1, 2) }
      #|
      #|fn use(box : Box[I64]) -> Option[I64] ! Console {
      #|  Option::some[I64](Console::choose![I64](box.value, 0))
      #|}
    ),
  )
}

///|
test "parse member forms with generic owner types" {
  let file = expect_parse_ok(
    (
      #|effect Coroutine[E : Effect] {
      #|  yield() -> Unit
      #|}
      #|effect Log {
      #|  log(String) -> Unit
      #|}
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|struct Box[A] {
      #|  value : A
      #|}
      #|fn handled() -> Unit {
      #|  handle Coroutine[Log]::yield!() with {
      #|    Coroutine[Log]::yield(resume) => resume(())
      #|  } final value {
      #|    value
      #|  }
      #|}
      #|fn use(box : Box[I64]) -> Option[I64] ! Coroutine[Log] {
      #|  let copied : Box[I64] = Box[I64]::{ value: box.value }
      #|  let ignored : Unit = Coroutine[Log]::yield!()
      #|  Option[I64]::some(copied.value)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|effect Coroutine[E : Effect] {
      #|  yield() -> Unit
      #|}
      #|
      #|effect Log {
      #|  log(String) -> Unit
      #|}
      #|
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|
      #|struct Box[A] {
      #|  value : A
      #|}
      #|
      #|fn handled() -> Unit {
      #|  handle Coroutine[Log]::yield!() with {
      #|    Coroutine[Log]::yield(resume) => resume(())
      #|  } final value {
      #|    value
      #|  }
      #|}
      #|
      #|fn use(box : Box[I64]) -> Option[I64] ! Coroutine[Log] {
      #|  let copied : Box[I64] = Box[I64]::{ value: box.value }
      #|  let ignored : Unit = Coroutine[Log]::yield!()
      #|  Option[I64]::some(copied.value)
      #|}
    ),
  )
}

///|
test "parse rejects expression-shaped member owner" {
  debug_inspect(
    parse_error_kinds(
      (
        #|struct Box[A] {
        #|  value : A
        #|}
        #|fn make() -> Box[I64] {
        #|  Box[I64]::{ value: 1 }
        #|}
        #|let bad : Box[I64] = make()::{ value: 2 }
      ),
    ),
    content=(
      #|[
      #|  UnexpectedToken(
      #|    { label: "`::`" },
      #|    [
      #|      { label: "end of file" },
      #|      { label: "`struct`" },
      #|      { label: "`enum`" },
      #|      { label: "`effect`" },
      #|      { label: "`fn`" },
      #|      { label: "`let`" },
      #|      { label: "`type`" },
      #|      { label: "`offer`" },
      #|      { label: "`extern`" },
      #|      { label: "`pub`" },
      #|      { label: "`+`" },
      #|      { label: "`-`" },
      #|      { label: "`*`" },
      #|      { label: "`/`" },
      #|      { label: "`%`" },
      #|      { label: "`==`" },
      #|      { label: "`!=`" },
      #|      { label: "`<`" },
      #|      { label: "`<=`" },
      #|      { label: "`>`" },
      #|      { label: "`>=`" },
      #|      { label: "`&&`" },
      #|      { label: "`||`" },
      #|      { label: "`|>`" },
      #|      { label: "`(`" },
      #|      { label: "`[`" },
      #|      { label: "`.`" },
      #|    ],
      #|  ),
      #|]
    ),
  )
}

///|
test "parse handler expressions" {
  let file = expect_parse_ok(
    (
      #|effect Console {
      #|  read() -> String
      #|  write(String) -> Unit
      #|}
      #|fn program() -> String ! Console {
      #|  handle Console::read!() with {
      #|    Console::write(message, resume) => resume(())
      #|    Console::choose[A](left, right, resume) => resume(left)
      #|    Console::read(resume) => "fallback"
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|effect Console {
      #|  read() -> String
      #|  write(String) -> Unit
      #|}
      #|
      #|fn program() -> String ! Console {
      #|  handle Console::read!() with {
      #|    Console::write(message, resume) => resume(())
      #|    Console::choose[A](left, right, resume) => resume(left)
      #|    Console::read(resume) => "fallback"
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
}

///|
test "parse handler operation keeps exact operation token span" {
  let file = expect_parse_ok(
    (
      #|effect Prompt {
      #|  choose[A](A, A) -> A
      #|}
      #|fn handled() -> I64 {
      #|  handle Prompt::choose![I64](1, 2) with {
      #|    Prompt::choose[A](left, right, resume) => resume(left)
      #|  } final value { value }
      #|}
    ),
  )
  guard file.declarations[1] is Function(function) else {
    abort("expected function declaration")
  }
  guard function.body is Block(result=Handler(handlers~, ..), ..) else {
    abort("expected handler expression")
  }
  guard handlers[0].arms[0].name
    is Qualified(owner~, operation~, operation_loc~) else {
    abort("expected qualified handler operation")
  }
  debug_inspect(
    (owner.loc(), operation, operation_loc),
    content=(
      #|(
      #|  {
      #|    start_offset: 122,
      #|    end_offset: 128,
      #|    start_line: 7,
      #|    start_column: 5,
      #|    end_line: 7,
      #|    end_column: 11,
      #|  },
      #|  "choose",
      #|  {
      #|    start_offset: 130,
      #|    end_offset: 136,
      #|    start_line: 7,
      #|    start_column: 13,
      #|    end_line: 7,
      #|    end_column: 19,
      #|  },
      #|)
    ),
  )
}

///|
test "parse handler owner type arguments" {
  let file = expect_parse_ok(
    (
      #|effect State[S] {
      #|  get() -> S
      #|}
      #|fn good() -> I64 ! State[I64] {
      #|  handle State[I64]::get!() with {
      #|    State[I64]::get(resume) => resume(0)
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|effect State[S] {
      #|  get() -> S
      #|}
      #|
      #|fn good() -> I64 ! State[I64] {
      #|  handle State[I64]::get!() with {
      #|    State[I64]::get(resume) => resume(0)
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
}

///|
test "parse rejects effect arguments as unqualified handler binders" {
  debug_inspect(
    parse_error_kinds(
      (
        #|fn bad() -> I64 {
        #|  handle 0 with {
        #|    ask[{}](resume) => resume(0)
        #|  } final value {
        #|    value
        #|  }
        #|}
      ),
    ),
    content=(
      #|[UnexpectedToken({ label: "`{`" }, [{ label: "identifier" }])]
    ),
  )
}

///|
test "parse unqualified handler operation type binders" {
  let file = expect_parse_ok(
    (
      #|fn good() -> I64 {
      #|  handle 0 with {
      #|    ask[A](resume) => resume(0)
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|fn good() -> I64 {
      #|  handle 0 with {
      #|    ask[A](resume) => resume(0)
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
}

///|
test "parse rejects malformed handler expressions" {
  let empty_with_errors = parse_error_kinds(
    (
      #|fn bad() -> Unit {
      #|  handle () with {} final value {
      #|    value
      #|  }
      #|}
    ),
  )
  assert_false(empty_with_errors.is_empty())
  let missing_final_errors = parse_error_kinds(
    (
      #|fn bad() -> Unit {
      #|  handle () with {
      #|    op(resume) => ()
      #|  }
      #|}
    ),
  )
  assert_false(missing_final_errors.is_empty())
}

///|
test "parse rejects empty enum and effect operation parameter headers" {
  debug_inspect(
    parse_error_kinds("enum Empty[] { value }"),
    content=(
      #|[EmptyTypeParameterList]
    ),
  )
  debug_inspect(
    parse_error_kinds("effect Prompt { choose[](I64, I64) -> I64 }"),
    content=(
      #|[EmptyTypeParameterList]
    ),
  )
}

///|
test "parse rejects empty operation witness and handler binder lists" {
  debug_inspect(
    parse_error_kinds(
      (
        #|effect Prompt {
        #|  choose[A](A, A) -> A
        #|}
        #|fn bad() -> I64 ! Prompt {
        #|  Prompt::choose![](1, 2)
        #|}
      ),
    ),
    content=(
      #|[EmptyGenericArgumentList]
    ),
  )
  debug_inspect(
    parse_error_kinds(
      (
        #|effect Prompt {
        #|  choose[A](A, A) -> A
        #|}
        #|fn bad() -> I64 {
        #|  handle Prompt::choose![I64](1, 2) with {
        #|    Prompt::choose[](left, right, resume) => resume(left)
        #|  } final value {
        #|    value
        #|  }
        #|}
      ),
    ),
    content=(
      #|[EmptyTypeParameterList]
    ),
  )
}

///|
test "parse rejects empty type application arguments" {
  debug_inspect(
    parse_error_kinds("type Bad = Option[]"),
    content=(
      #|[EmptyGenericArgumentList]
    ),
  )
  debug_inspect(
    parse_error_kinds("type Bad = [](I64) -> I64"),
    content=(
      #|[EmptyTypeParameterList]
    ),
  )
}

///|
test "parse existential surface syntax" {
  let file = expect_parse_ok(
    (
      #|struct Hide {
      #|  type T
      #|  val : T
      #|}
      #|enum Any {
      #|  hide[T](T)
      #|}
      #|let h : Hide = Hide::{ T = I64, val: 5 }
      #|let e : Any = Any::hide[I64](5)
      #|fn use(h : Hide, e : Any) -> I64 {
      #|  match e {
      #|    Any::hide[T](value) => {
      #|      let Hide::{ _, val } = h
      #|      1
      #|    }
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|struct Hide {
      #|  type T
      #|  val : T
      #|}
      #|
      #|enum Any {
      #|  hide[T](T)
      #|}
      #|
      #|let h : Hide = Hide::{ T = I64, val: 5 }
      #|
      #|let e : Any = Any::hide[I64](5)
      #|
      #|fn use(h : Hide, e : Any) -> I64 {
      #|  match e {
      #|    Any::hide[T](value) => {
      #|      let Hide::{ _, val } = h
      #|      1
      #|    }
      #|  }
      #|}
    ),
  )
}

///|
test "parse rejects empty type alias parameter header" {
  debug_inspect(
    parse_error_kinds("type Empty[] = I64"),
    content=(
      #|[EmptyTypeParameterList]
    ),
  )
}

///|
test "parse rejects multi-layer type alias parameter header" {
  debug_inspect(
    parse_error_kinds("type Result[E][A] = I64"),
    content=(
      #|[
      #|  UnexpectedToken(
      #|    { label: "`[`" },
      #|    [{ label: "`:`" }, { label: "`=`" }],
      #|  ),
      #|]
    ),
  )
}

///|
test "parse rejects equals function body syntax" {
  debug_inspect(
    parse_error_kinds("fn add(a : I64, b : I64) -> I64 = a + b"),
    content=(
      #|[
      #|  UnexpectedToken(
      #|    { label: "`=`" },
      #|    [
      #|      { label: "`!`" },
      #|      { label: "`{`" },
      #|      { label: "`[`" },
      #|      { label: "`.`" },
      #|    ],
      #|  ),
      #|]
    ),
  )
}

///|
test "parse accepts empty enum variant payload syntax" {
  let file = expect_parse_ok(
    (
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
    ),
  )
}

///|
test "parse rejects payloadless enum variant declaration syntax without parentheses" {
  assert_false(parse_errors("enum Option[A] { none some(A) }").is_empty())
}

///|
test "parse accepts else-if chain without final else" {
  let file = expect_parse_ok(
    (
      #|fn choose(first : Bool, second : Bool) -> Unit {
      #|  if first {
      #|    ()
      #|  } else if second {
      #|    ()
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|fn choose(first : Bool, second : Bool) -> Unit {
      #|  if first {
      #|    ()
      #|  } else if second {
      #|    ()
      #|  }
      #|}
    ),
  )
}

///|
test "parse rejects payloadless qualified variant expression syntax without parentheses" {
  assert_false(
    parse_errors(
      (
        #|enum Option[A] { none() some(A) }
        #|let value : Option[I64] = Option::none
      ),
    ).is_empty(),
  )
}

///|
test "parse rejects payloadless qualified variant pattern syntax without parentheses" {
  assert_false(
    parse_errors(
      (
        #|enum Option[A] { none() some(A) }
        #|fn qualified(value : Option[I64]) -> I64 {
        #|  match value {
        #|    Option::none => 0
        #|    Option::some(x) => x
        #|  }
        #|}
      ),
    ).is_empty(),
  )
}

///|
test "parse accepts empty qualified variant argument syntax" {
  let file = expect_parse_ok(
    (
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|let value : Option[I64] = Option::none()
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|
      #|let value : Option[I64] = Option::none()
    ),
  )
}

///|
test "parse external host type and effect declarations" {
  let file = expect_parse_ok(
    (
      #|extern type Fd : Type
      #|pub extern type VectorOp[A : Type] : Effect
    ),
  )
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|extern type Fd : Type
      #|
      #|pub extern type VectorOp[A : Type] : Effect
    ),
  )
}

///|
test "parse rejects external declaration bodies" {
  assert_false(parse_errors("extern type Fd : Type = I64").is_empty())
  assert_false(parse_errors("extern type VectorOp : Effect {}").is_empty())
}
