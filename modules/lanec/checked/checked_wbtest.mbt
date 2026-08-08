///|
fn loc() -> SourceSpan {
  SourceSpan::dummy()
}

///|
fn i64_type() -> @types.Type {
  Primitive(I64)
}

///|
fn bool_type() -> @types.Type {
  Primitive(Bool)
}

///|
fn function_type(
  parameters : Array[@types.Type],
  result : @types.Type,
) -> @types.Type {
  Function(parameters, result, Empty)
}

///|
fn checked_function(
  symbol : @symbol.ValueSymbolId,
  name : String,
  parameters : Array[CheckedValueParameter],
  body : CheckedExpr,
) -> CheckedFunctionDeclaration {
  {
    is_public: false,
    is_offered: false,
    symbol,
    name,
    name_loc: loc(),
    type_parameters: [],
    parameters,
    return_type: i64_type(),
    body,
    type_: function_type(
      parameters.map(fn(parameter) { parameter.type_ }),
      i64_type(),
    ),
    loc: loc(),
  }
}

///|
fn checked_source(
  registry : @symbol.SymbolRegistry,
  body : CheckedExpr,
) -> CheckedSourceFile {
  let main = registry.define_value("main", TopLevelFunction, loc())
  {
    module_path: { components: ["Test"], loc: loc() },
    declarations: [Function(checked_function(main, "main", [], body))],
    loc: loc(),
  }
}

///|
fn unused_binder_summary(
  binders : Array[CheckedValueUseBinder],
) -> Array[String] {
  binders.map(fn(binder) {
    "\{binder.name}:\{value_use_binder_kind_text(binder.kind)}"
  })
}

///|
fn value_use_binder_kind_text(kind : CheckedValueUseBinderKind) -> String {
  match kind {
    LocalLet => "local-let"
    LocalFunction => "local-function"
    FunctionParameter => "function-parameter"
    FunctionLiteralParameter => "function-literal-parameter"
    PatternBinder => "pattern-binder"
    HandlerResumeBinder => "handler-resume-binder"
    HandlerFinalBinder => "handler-final-binder"
  }
}

///|
test "pretty prints checked source without surface-only syntax" {
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let x = registry.define_value("x", LocalBinding, loc())
  let increment = registry.define_value("increment", TopLevelFunction, loc())
  let answer = registry.define_value("answer", TopLevelValue, loc())
  let value = CheckedExpr::Value(
    name="x",
    symbol=x,
    type_=i64_type(),
    loc=loc(),
  )
  let callee = CheckedExpr::Value(
    name="increment",
    symbol=increment,
    type_=function_type([i64_type()], i64_type()),
    loc=loc(),
  )
  let call = CheckedExpr::Call(
    callee~,
    arguments=[{ value, loc: loc(), provenance: Authored }],
    type_=i64_type(),
    loc=loc(),
  )
  let source = CheckedSourceFile::{
    module_path: { components: ["Test"], loc: loc() },
    declarations: [
      Let({
        is_public: true,
        is_offered: false,
        symbol: answer,
        name: "answer",
        name_loc: loc(),
        initializer: call,
        type_: i64_type(),
        loc: loc(),
      }),
    ],
    loc: loc(),
  }
  inspect(
    @prettyprinter.render(source),
    content=(
      #|checked {
      #|  let answer#2 : I64 = increment#1(x#0)
      #|}
    ),
  )
}

///|
test "pretty prints checked thunked short circuit call shape" {
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let op_and_symbol = registry.define_value("op_and", TopLevelValue, loc())
  let op_and_type = function_type(
    [bool_type(), function_type([], bool_type())],
    bool_type(),
  )
  let op_and = CheckedExpr::Value(
    name="op_and",
    symbol=op_and_symbol,
    type_=op_and_type,
    loc=loc(),
  )
  let left = CheckedExpr::Literal(
    literal=Bool(true),
    type_=bool_type(),
    loc=loc(),
  )
  let right = CheckedExpr::Literal(
    literal=Bool(false),
    type_=bool_type(),
    loc=loc(),
  )
  let thunk = CheckedExpr::FunctionLiteral(
    type_parameters=[],
    parameters=[],
    return_type=bool_type(),
    body=right,
    type_=function_type([], bool_type()),
    loc=loc(),
  )
  let call = CheckedExpr::Call(
    callee=op_and,
    arguments=[
      { value: left, loc: loc(), provenance: Synthetic },
      { value: thunk, loc: loc(), provenance: Synthetic },
    ],
    type_=bool_type(),
    loc=loc(),
  )
  inspect(
    @prettyprinter.render(call),
    content=(
      #|op_and#0(true, fn() -> Bool {
      #|  false
      #|}) : Bool
    ),
  )
}

///|
test "pretty prints checked match with resolved patterns" {
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let option = registry.define_type("Option", Enum, 1, loc())
  let box = registry.define_type("Box", Struct, 1, loc())
  let some = registry.define_variant(option, "some", 0, 1, loc())
  let field = registry.define_field(box, "value", 0, loc())
  let binder = registry.define_value("x", PatternBinder, loc())
  let scrutinee = registry.define_value("value", Parameter, loc())
  let box_int = @types.nominal_type(box, [i64_type()])
  let option_box = @types.nominal_type(option, [box_int])
  let pattern = CheckedPattern::Variant(
    symbol=some,
    variant_loc=loc(),
    generic_arguments=[],
    arguments=[
      Struct(
        symbol=box,
        type_name_loc=loc(),
        type_binders=[],
        fields=[
          {
            symbol: field,
            name: "value",
            pattern: Binding(
              name="x",
              symbol=binder,
              type_=i64_type(),
              loc=loc(),
            ),
            loc: loc(),
          },
        ],
        type_=box_int,
        loc=loc(),
      ),
    ],
    type_=option_box,
    loc=loc(),
  )
  let arm = CheckedMatchArm::{
    pattern,
    body: Value(name="x", symbol=binder, type_=i64_type(), loc=loc()),
    loc: loc(),
  }
  let match_expr = CheckedExpr::Match(
    scrutinee=Value(name="value", symbol=scrutinee, type_=option_box, loc=loc()),
    arms=[arm],
    type_=i64_type(),
    loc=loc(),
  )
  inspect(
    @prettyprinter.render(match_expr),
    content=(
      #|match value#1 {
      #|  variant#0(type#1::{
      #|    value#0: x#0
      #|  }) => x#0
      #|} : I64
    ),
  )
}

///|
test "value use analysis classifies local dependency groups" {
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let x = registry.define_value("x", LocalBinding, loc())
  let y = registry.define_value("y", LocalBinding, loc())
  let loop_symbol = registry.define_value("loop", LocalFunction, loc())
  let n = registry.define_value("n", Parameter, loc())
  let a = registry.define_value("a", LocalFunction, loc())
  let b = registry.define_value("b", LocalFunction, loc())
  let loop_parameter : CheckedValueParameter = {
    symbol: n,
    is_auto: false,
    is_offered: false,
    name: "n",
    name_loc: loc(),
    type_: i64_type(),
    loc: loc(),
  }
  let loop_body = CheckedExpr::Call(
    callee=Value(
      name="loop",
      symbol=loop_symbol,
      type_=function_type([i64_type()], i64_type()),
      loc=loc(),
    ),
    arguments=[
      {
        value: Value(name="n", symbol=n, type_=i64_type(), loc=loc()),
        loc: loc(),
        provenance: Authored,
      },
    ],
    type_=i64_type(),
    loc=loc(),
  )
  let block = CheckedExpr::Block(
    items=[
      Let({
        is_public: false,
        is_offered: false,
        symbol: x,
        name: "x",
        name_loc: loc(),
        initializer: Literal(
          literal=I64({ raw: "1", value: 1 }),
          type_=i64_type(),
          loc=loc(),
        ),
        type_: i64_type(),
        loc: loc(),
      }),
      Let({
        is_public: false,
        is_offered: false,
        symbol: y,
        name: "y",
        name_loc: loc(),
        initializer: Value(name="x", symbol=x, type_=i64_type(), loc=loc()),
        type_: i64_type(),
        loc: loc(),
      }),
      Function(
        checked_function(loop_symbol, "loop", [loop_parameter], loop_body),
      ),
      Function(
        checked_function(
          a,
          "a",
          [],
          Value(
            name="b",
            symbol=b,
            type_=function_type([], i64_type()),
            loc=loc(),
          ),
        ),
      ),
      Function(
        checked_function(
          b,
          "b",
          [],
          Value(
            name="a",
            symbol=a,
            type_=function_type([], i64_type()),
            loc=loc(),
          ),
        ),
      ),
    ],
    result=Literal(
      literal=I64({ raw: "0", value: 0 }),
      type_=i64_type(),
      loc=loc(),
    ),
    type_=i64_type(),
    loc=loc(),
  )
  debug_inspect(
    unused_binder_summary(
      checked_source(registry, block)
      .value_use_analysis(registry)
      .unused_binders(),
    ),
    content=(
      #|[
      #|  "y:local-let",
      #|  "loop:local-function",
      #|  "a:local-function",
      #|  "b:local-function",
      #|]
    ),
  )
}

///|
test "value use analysis does not cascade through unused captured function" {
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let x = registry.define_value("x", LocalBinding, loc())
  let helper = registry.define_value("helper", LocalFunction, loc())
  let block = CheckedExpr::Block(
    items=[
      Let({
        is_public: false,
        is_offered: false,
        symbol: x,
        name: "x",
        name_loc: loc(),
        initializer: Literal(
          literal=I64({ raw: "1", value: 1 }),
          type_=i64_type(),
          loc=loc(),
        ),
        type_: i64_type(),
        loc: loc(),
      }),
      Function(
        checked_function(
          helper,
          "helper",
          [],
          Value(name="x", symbol=x, type_=i64_type(), loc=loc()),
        ),
      ),
    ],
    result=Literal(
      literal=I64({ raw: "0", value: 0 }),
      type_=i64_type(),
      loc=loc(),
    ),
    type_=i64_type(),
    loc=loc(),
  )
  debug_inspect(
    unused_binder_summary(
      checked_source(registry, block)
      .value_use_analysis(registry)
      .unused_binders(),
    ),
    content=(
      #|["helper:local-function"]
    ),
  )
}

///|
test "value use analysis excludes generated locals without losing authored uses" {
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let main = registry.define_value("main", TopLevelFunction, loc())
  let input = registry.define_value("input", Parameter, loc())
  let result = registry.define_value("result", LocalBinding, loc())
  let temporary = registry.define_generated_local("_temporary", loc())
  let input_parameter : CheckedValueParameter = {
    is_auto: false,
    is_offered: false,
    symbol: input,
    name: "input",
    name_loc: loc(),
    type_: i64_type(),
    loc: loc(),
  }
  let generated_initializer = CheckedExpr::Block(
    items=[
      Let({
        is_public: false,
        is_offered: false,
        symbol: temporary,
        name: "_temporary",
        name_loc: loc(),
        initializer: Value(
          name="input",
          symbol=input,
          type_=i64_type(),
          loc=loc(),
        ),
        type_: i64_type(),
        loc: loc(),
      }),
    ],
    result=Value(
      name="_temporary",
      symbol=temporary,
      type_=i64_type(),
      loc=loc(),
    ),
    type_=i64_type(),
    loc=loc(),
  )
  let body = CheckedExpr::Block(
    items=[
      Let({
        is_public: false,
        is_offered: false,
        symbol: result,
        name: "result",
        name_loc: loc(),
        initializer: generated_initializer,
        type_: i64_type(),
        loc: loc(),
      }),
    ],
    result=Value(name="result", symbol=result, type_=i64_type(), loc=loc()),
    type_=i64_type(),
    loc=loc(),
  )
  let source = CheckedSourceFile::{
    module_path: { components: ["Test"], loc: loc() },
    declarations: [
      Function(checked_function(main, "main", [input_parameter], body)),
    ],
    loc: loc(),
  }
  assert_eq(source.value_use_analysis(registry), {
    binders: [
      { symbol: input, name: "input", loc: loc(), kind: FunctionParameter },
      { symbol: result, name: "result", loc: loc(), kind: LocalLet },
    ],
    references: [
      { target: input, origin_binder: Some(result), loc: loc() },
      { target: result, origin_binder: None, loc: loc() },
    ],
  })
}
