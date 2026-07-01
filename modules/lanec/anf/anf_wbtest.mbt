///|
fn loc() -> SourceSpan {
  SourceSpan::dummy()
}

///|
fn hide_type(symbol : TypeSymbolId) -> @types.Type {
  @types.nominal_type(symbol, [])
}

///|
fn expect_anf_program(source : String) -> AnfProgram {
  let parse_result = @parser.parse_string("module Test\n" + source)
  if !parse_result.lexical_errors.is_empty() ||
    !parse_result.parse_errors.is_empty() {
    abort("expected parse success")
  }
  guard parse_result.source is Some(file) else { abort("expected source") }
  let resolved = @resolve.resolve_source_file(file)
  let checked = @typecheck.typecheck_checked_source_file(resolved)
  guard checked.source is Some(source) else {
    abort(@prettyprinter.render(checked.diagnostics, width=100))
  }
  lower_checked_source_file_to_anf(source)
}

///|
test "pretty prints ANF existential package and opening" {
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let hide = registry.define_type("Hide", Struct, 0, loc())
  let member_parameter = registry.define_type_parameter("T", loc())
  let type_member = registry.define_type_member(
    hide,
    "T",
    0,
    member_parameter,
    loc(),
  )
  let field = registry.define_field(hide, "val", 0, loc())
  let repack = registry.define_value("repack", TopLevelFunction, loc())
  let input = registry.define_value("h", Parameter, loc())
  let opened_parameter = registry.define_type_parameter("T", loc())
  let binder = registry.define_value("val", PatternBinder, loc())
  let packed = registry.define_value("packed", LocalBinding, loc())
  let hide_type = hide_type(hide)
  let opened_type = @types.Type::Parameter(opened_parameter)
  let pattern = @checked.CheckedPattern::Struct(
    symbol=hide,
    type_binders=[
      {
        symbol: type_member,
        type_parameter: Some({ id: opened_parameter, name: "T", kind: Type }),
        name: Some("T"),
        loc: loc(),
      },
    ],
    fields=[
      {
        symbol: field,
        name: "val",
        pattern: Binding(
          name="val",
          symbol=binder,
          type_=opened_type,
          loc=loc(),
        ),
        loc: loc(),
      },
    ],
    type_=hide_type,
    loc=loc(),
  )
  let initializer = AnfAtom::Value(
    name="h",
    symbol=input,
    type_=hide_type,
    loc=loc(),
  )
  let packed_value = AnfRhs::Struct(
    symbol=hide,
    type_arguments=[],
    type_witnesses=[
      { symbol: type_member, name: "T", type_: opened_type, loc: loc() },
    ],
    fields=[
      {
        symbol: field,
        name: "val",
        value: Value(name="val", symbol=binder, type_=opened_type, loc=loc()),
        loc: loc(),
      },
    ],
    type_=hide_type,
    loc=loc(),
  )
  let body = AnfExpr::Let(
    binding=Pattern(pattern~, initializer~, loc=loc()),
    body=Let(
      binding=Value(
        symbol=packed,
        name=Some("packed"),
        rhs=packed_value,
        type_=hide_type,
        loc=loc(),
      ),
      body=Atom(
        atom=Value(name="packed", symbol=packed, type_=hide_type, loc=loc()),
        type_=hide_type,
        loc=loc(),
      ),
      type_=hide_type,
      loc=loc(),
    ),
    type_=hide_type,
    loc=loc(),
  )
  let program = AnfProgram::{
    declarations: [
      Struct({
        is_public: false,
        symbol: hide,
        name: "Hide",
        type_parameters: [],
        type_members: [
          {
            symbol: type_member,
            type_parameter: { id: member_parameter, name: "T", kind: Type },
            name: "T",
            kind: Type,
            index: 0,
            loc: loc(),
          },
        ],
        fields: [
          {
            symbol: field,
            is_offered: false,
            name: "val",
            index: 0,
            type_: Parameter(member_parameter),
            loc: loc(),
          },
        ],
        loc: loc(),
      }),
      Function({
        symbol: repack,
        name: "repack",
        type_parameters: [],
        parameters: [
          {
            symbol: input,
            is_auto: false,
            is_offered: false,
            name: "h",
            type_: hide_type,
            loc: loc(),
          },
        ],
        return_type: hide_type,
        body,
        type_: Function([hide_type], hide_type),
        loc: loc(),
      }),
    ],
    loc: loc(),
  }
  inspect(
    @prettyprinter.render(program, width=100),
    content=(
      #|anf {
      #|  struct Hide#0 {
      #|    type T#0 : Type
      #|    val#0 : tparam#0
      #|  }
      #|  fn repack#0(h#1 : type#0) -> type#0 {
      #|    let type#0::{
      #|      type T#0 = T#1
      #|      val#0: val#2
      #|    } = h#1
      #|    let packed#3 : type#0 = type#0::{
      #|      type T#0 = tparam#1
      #|      val#0: val#2
      #|    }
      #|    packed#3
      #|  }
      #|}
    ),
  )
}

///|
test "lower checked source existential struct opening to ANF" {
  let program = expect_anf_program(
    (
      #|struct Hide {
      #|  type T : Type
      #|  val : T
      #|}
      #|fn repack(h : Hide) -> Hide {
      #|  {
      #|    let Hide::{ T, val } = h
      #|    Hide::{ T = T, val: val }
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(program, width=100),
    content=(
      #|anf {
      #|  struct Hide#0 {
      #|    type T#0 : Type
      #|    val#0 : tparam#0
      #|  }
      #|  fn repack#0(h#1 : type#0) -> type#0 {
      #|    let type#0::{
      #|      type T#0 = T#1
      #|      val#0: val#2
      #|    } = h#1
      #|    let temp#0 : type#0 = type#0::{
      #|      type T#0 = tparam#1
      #|      val#0: val#2
      #|    }
      #|    temp#0
      #|  }
      #|}
    ),
  )
}

///|
test "lower checked source existential enum opening to ANF" {
  let program = expect_anf_program(
    (
      #|enum Packed {
      #|  hide[T](T)
      #|}
      #|fn repack(p : Packed) -> Packed {
      #|  match p {
      #|    Packed::hide[T](value) => Packed::hide[T](value)
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(program, width=100),
    content=(
      #|anf {
      #|  enum Packed#0 {
      #|    hide#0[T#0 : Type](tparam#0)
      #|  }
      #|  fn repack#0(p#1 : type#0) -> type#0 {
      #|    match p#1 {
      #|      variant#0[tparam#1](value#2) => {
      #|        let temp#0 : type#0 = variant#0[tparam#1](value#2)
      #|        temp#0
      #|      }
      #|    }
      #|  }
      #|}
    ),
  )
}

///|
test "lower checked source generic call and unsafe builtin to ANF" {
  let program = expect_anf_program(
    (
      #|fn[A] id(value : A) -> A {
      #|  value
      #|}
      #|let answer : Int = id(builtin("%answer"))
    ),
  )
  inspect(
    @prettyprinter.render(program, width=100),
    content=(
      #|anf {
      #|  fn[tparam#0 A : Type] id#0(value#2 : tparam#0) -> tparam#0 {
      #|    value#2
      #|  }
      #|  let answer#1 : Int = {
      #|    let temp#0 : (Int) -> Int = id#0[Int]
      #|    let temp#1 : Int = temp#0(builtin("%answer"))
      #|    temp#1
      #|  }
      #|}
    ),
  )
}

///|
test "lower buslane function call to ANF" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let result = metadata.define_value(Value, Primitive(Int))
  let function = metadata.define_value(
    Function,
    Function([Primitive(Int)], Primitive(Int), Empty),
  )
  let parameter = metadata.define_value(Parameter, Primitive(Int))
  let program = @buslane.Program::{
    metadata,
    terms: [
      LetRec([
        {
          id: function,
          rhs: Function({
            parameters: [parameter],
            result_type: Primitive(Int),
            body: Ref(parameter),
          }),
        },
      ]),
      Let(result, Call(Ref(function), [Literal(Int(42L))])),
    ],
  }
  inspect(
    @prettyprinter.render(lower_buslane_program_to_anf(program), width=100),
    content=(
      #|buslane_anf_program {
      #|  letrec {
      #|    value#1 = fn(value#2) -> Int {
      #|      value#2
      #|    }
      #|  }
      #|  let value#0 = {
      #|    let temp#0 = value#1(42)
      #|    temp#0
      #|  }
      #|}
    ),
  )
}
