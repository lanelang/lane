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
  { name, kind: None, loc: test_loc() }
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
        type_parameters: [],
        members: [
          Field({
            is_offered: false,
            name: "x",
            type_: int_type,
            loc: test_loc(),
          }),
          Field({
            is_offered: false,
            name: "y",
            type_: int_type,
            loc: test_loc(),
          }),
        ],
        loc: test_loc(),
      }),
      Enum({
        is_public: false,
        name: "Option",
        type_parameters: [test_type_parameter("A")],
        variants: [
          { name: "none", type_parameters: [], payload: [], loc: test_loc() },
          {
            name: "some",
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
        parameters: [
          {
            is_auto: false,
            is_offered: false,
            name: "value",
            type_: option_int_type,
            loc: test_loc(),
          },
          {
            is_auto: false,
            is_offered: false,
            name: "fallback",
            type_: int_type,
            loc: test_loc(),
          },
        ],
        return_type: int_type,
        body: Block(
          items=[],
          result=Match(
            scrutinee=Var("value", loc=test_loc()),
            arms=[
              {
                pattern: QualifiedVariant(
                  type_name="Option",
                  variant="none",
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
                  variant="some",
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
      #|  none
      #|  some(A)
      #|}
      #|
      #|fn unwrap_or(value : Option[Int], fallback : Int) -> Int {
      #|  match value {
      #|    Option::none => fallback
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
