///|
fn test_loc() -> SourceSpan {
  SourceSpan::dummy()
}

///|
fn test_type(name : String, arguments? : Array[Type] = []) -> Type {
  let base = Name(name~, loc=test_loc())
  if arguments.is_empty() {
    base
  } else {
    Apply(callee=base, arguments~, loc=test_loc())
  }
}

///|
fn test_type_parameter(name : String) -> TypeParameter {
  { name, name_loc: test_loc(), kind: None, loc: test_loc() }
}

///|
fn test_module_path(name : String) -> ModulePath {
  { components: [name], loc: test_loc() }
}

///|
test "pretty print source file" {
  let int_type = test_type("Int")
  let option_int_type = test_type("Option", arguments=[int_type])
  let file = SourceFile::{
    module_path: test_module_path("Test"),
    imports: [],
    declarations: [
      Struct({
        is_public: false,
        name: "Point",
        name_loc: test_loc(),
        type_parameters: [],
        members: [
          Field({
            name: "x",
            name_loc: test_loc(),
            type_: int_type,
            loc: test_loc(),
          }),
          Field({
            name: "y",
            name_loc: test_loc(),
            type_: int_type,
            loc: test_loc(),
          }),
        ],
        loc: test_loc(),
      }),
      Enum({
        is_public: false,
        name: "Option",
        name_loc: test_loc(),
        type_parameters: [test_type_parameter("A")],
        variants: [
          {
            name: "none",
            name_loc: test_loc(),
            type_parameters: [],
            payload: [],
            loc: test_loc(),
          },
          {
            name: "some",
            name_loc: test_loc(),
            type_parameters: [],
            payload: [test_type("A")],
            loc: test_loc(),
          },
        ],
        loc: test_loc(),
      }),
      Function({
        is_public: false,
        type_parameters: [],
        name: "unwrap_or",
        name_loc: test_loc(),
        parameters: [
          {
            is_auto: false,
            is_offered: false,
            name: "value",
            name_loc: test_loc(),
            type_: option_int_type,
            loc: test_loc(),
          },
          {
            is_auto: false,
            is_offered: false,
            name: "fallback",
            name_loc: test_loc(),
            type_: int_type,
            loc: test_loc(),
          },
        ],
        return_type: int_type,
        effect: Empty(loc=test_loc()),
        body: Block(
          items=[],
          result=Match(
            scrutinee=Var("value", loc=test_loc()),
            arms=[
              {
                pattern: QualifiedVariant(
                  type_name="Option",
                  type_name_loc=test_loc(),
                  variant="none",
                  variant_loc=test_loc(),
                  type_binders=[],
                  arguments=[],
                  loc=test_loc(),
                ),
                body: Var("fallback", loc=test_loc()),
                loc: test_loc(),
              },
              {
                pattern: QualifiedVariant(
                  type_name="Option",
                  type_name_loc=test_loc(),
                  variant="some",
                  variant_loc=test_loc(),
                  type_binders=[],
                  arguments=[Binding("x", loc=test_loc())],
                  loc=test_loc(),
                ),
                body: Var("x", loc=test_loc()),
                loc: test_loc(),
              },
            ],
            loc=test_loc(),
          ),
          loc=test_loc(),
        ),
        loc: test_loc(),
      }),
    ],
    loc: test_loc(),
  }
  inspect(
    @prettyprinter.render(file),
    content=(
      #|module Test
      #|
      #|struct Point {
      #|  x : Int
      #|  y : Int
      #|}
      #|
      #|enum Option[A] {
      #|  none()
      #|  some(A)
      #|}
      #|
      #|fn unwrap_or(value : Option[Int], fallback : Int) -> Int {
      #|  match value {
      #|    Option::none() => fallback
      #|    Option::some(x) => x
      #|  }
      #|}
    ),
  )
}

///|
test "pretty print expression precedence" {
  let expression = Expr::Binary(
    operator=Mul,
    left=Binary(
      operator=Add,
      left=IntLiteral("1", loc=test_loc()),
      right=IntLiteral("2", loc=test_loc()),
      loc=test_loc(),
    ),
    right=IntLiteral("3", loc=test_loc()),
    loc=test_loc(),
  )
  inspect(@prettyprinter.render(expression), content="(1 + 2) * 3")
}

///|
test "pretty print handler keeps with and final attached" {
  let expression = Expr::Handler(
    body=Call(
      callee=Var("call_read", loc=test_loc()),
      arguments=[
        Positional(value=Var("read_int", loc=test_loc()), loc=test_loc()),
      ],
      loc=test_loc(),
    ),
    handlers=[
      {
        arms: [
          {
            name: Qualified(
              owner=test_type("Console"),
              operation="read",
              loc=test_loc(),
            ),
            type_binders: [],
            payload_patterns: [],
            resume_binder: "resume",
            resume_loc: test_loc(),
            body: Call(
              callee=Var("resume", loc=test_loc()),
              arguments=[
                Positional(
                  value=IntLiteral("42", loc=test_loc()),
                  loc=test_loc(),
                ),
              ],
              loc=test_loc(),
            ),
            loc: test_loc(),
          },
        ],
        loc: test_loc(),
      },
    ],
    final_branch={
      binder: "value",
      binder_loc: test_loc(),
      body: Block(items=[], result=Var("value", loc=test_loc()), loc=test_loc()),
      loc: test_loc(),
    },
    loc=test_loc(),
  )
  inspect(
    @prettyprinter.render(expression, width=80),
    content=(
      #|handle call_read(read_int) with {
      #|  Console::read(resume) => resume(42)
      #|} final value {
      #|  value
      #|}
    ),
  )
}

///|
test "pretty print short effect set inline" {
  let type_ = Type::Function(
    type_parameters=[],
    parameters=[],
    result=test_type("Bool"),
    effect=Union(
      items=[test_type("Coroutine"), test_type("Log")],
      loc=test_loc(),
    ),
    loc=test_loc(),
  )
  inspect(
    @prettyprinter.render(type_, width=80),
    content="() -> Bool ! { Coroutine, Log }",
  )
  inspect(
    @prettyprinter.render(type_, width=20),
    content=(
      #|() -> Bool ! {
      #|  Coroutine,
      #|  Log
      #|}
    ),
  )
}
