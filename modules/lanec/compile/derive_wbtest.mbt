///|
test "explicit derive checks through the canonical structural interface" {
  let result = compile_sources(
    (
      #|module Main
      #|
      #|import Basic.Trait.Derive.{ Deriver }
      #|
      #|pub struct Equal[T] {
      #|  equal : (T, T) -> Bool
      #|}
      #|
      #|pub struct Point {
      #|  x : I64
      #|  y : I64
      #|}
      #|
      #|pub struct Wrapper[T] {
      #|  value : T
      #|}
      #|
      #|pub fn point_equal(
      #|  deriver : Deriver[Equal],
      #|  auto offer i64_equal : Equal[I64]
      #|) -> Equal[Point] {
      #|  derive[Equal, Point](deriver=deriver)
      #|}
      #|
      #|pub fn[T] wrapper_equal(
      #|  deriver : Deriver[Equal],
      #|  auto offer value_equal : Equal[T]
      #|) -> Equal[Wrapper[T]] {
      #|  derive[Equal, Wrapper[T]](deriver=deriver)
      #|}
    ),
    [derive_void_source(), derive_iso_source(), derive_interface_source()],
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "derive rejects a malformed canonical structural interface" {
  let malformed_interface = derive_interface_source().replace(
    old="  field : [A](FieldInfo, C[A]) -> C[A]",
    new="  component : [A](FieldInfo, C[A]) -> C[A]",
  )
  let result = compile_sources(
    (
      #|module Main
      #|
      #|import Basic.Trait.Derive.{ Deriver }
      #|
      #|pub struct Box[_T] {}
      #|pub struct Point { value : I64 }
      #|
      #|pub fn point_box(
      #|  deriver : Deriver[Box],
      #|  auto offer i64_box : Box[I64]
      #|) -> Box[Point] {
      #|  derive[Box, Point](deriver=deriver)
      #|}
    ),
    [derive_void_source(), derive_iso_source(), malformed_interface],
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "invalid structural derivation interface",
      #|    span: Some(
      #|      Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 204,
      #|          end_offset: 239,
      #|          start_line: 12,
      #|          start_column: 3,
      #|          end_line: 12,
      #|          end_column: 38,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Error,
      #|    code: Some("E3032"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="<root>",
      #|          span={
      #|            start_offset: 204,
      #|            end_offset: 239,
      #|            start_line: 12,
      #|            start_column: 3,
      #|            end_line: 12,
      #|            end_column: 38,
      #|          },
      #|        ),
      #|        message: "`Deriver` fields must match the canonical declaration order",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: [],
      #|    helps: ["provide the canonical structural derivation interfaces required by the language"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|]
    ),
  )
}

///|
test "derive rejects hidden type members in canonical structs" {
  let cases = [
    (
      "Deriver", "pub struct Deriver[C : [Type] -> Type] {", "pub struct Deriver[C : [Type] -> Type] {\n  type Hidden : Type",
    ),
    (
      "Product", "pub struct Product[A, B] {", "pub struct Product[A, B] {\n  type Hidden : Type",
    ),
    (
      "Iso", "pub struct Iso[T, R] {", "pub struct Iso[T, R] {\n  type Hidden : Type",
    ),
  ]
  let missing_diagnostics = []
  for case in cases {
    let (name, old, new) = case
    let malformed_interface = derive_interface_source().replace(old~, new~)
    let malformed_iso = derive_iso_source().replace(old~, new~)
    let result = compile_sources(
      (
        #|module Main
        #|
        #|import Basic.Trait.Derive.{ Deriver }
        #|
        #|pub struct Box[_T] {}
        #|pub struct Point { value : I64 }
        #|
        #|pub fn point_box(
        #|  deriver : Deriver[Box],
        #|  auto offer i64_box : Box[I64]
        #|) -> Box[Point] {
        #|  derive[Box, Point](deriver=deriver)
        #|}
      ),
      [derive_void_source(), malformed_iso, malformed_interface],
    )
    if result.diagnostics is [diagnostic] {
      assert_diagnostic_headline(
        diagnostic, "E3032", "invalid structural derivation interface",
      )
      assert_eq(diagnostic.labels.map(fn(label) { label.message }), [
        "`\{name}` must not declare hidden type members",
      ])
      assert_single_help(
        diagnostic, "provide the canonical structural derivation interfaces required by the language",
      )
    } else {
      missing_diagnostics.push(name)
    }
  }
  assert_eq(missing_diagnostics, [])
}

///|
test "derive rejects a nonempty canonical void type" {
  let nonempty_void = derive_void_source().replace(
    old="pub enum Void {}",
    new="pub enum Void { inhabited() }",
  )
  let result = compile_sources(
    (
      #|module Main
      #|
      #|import Basic.Trait.Derive.{ Deriver }
      #|
      #|pub struct Box[_T] {}
      #|pub struct Empty {}
      #|
      #|pub fn empty_box(deriver : Deriver[Box]) -> Box[Empty] {
      #|  derive[Box, Empty](deriver=deriver)
      #|}
    ),
    [nonempty_void, derive_iso_source(), derive_interface_source()],
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "invalid structural derivation interface",
      #|    span: Some(
      #|      Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 154,
      #|          end_offset: 189,
      #|          start_line: 9,
      #|          start_column: 3,
      #|          end_line: 9,
      #|          end_column: 38,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Error,
      #|    code: Some("E3032"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="<root>",
      #|          span={
      #|            start_offset: 154,
      #|            end_offset: 189,
      #|            start_line: 9,
      #|            start_column: 3,
      #|            end_line: 9,
      #|            end_column: 38,
      #|          },
      #|        ),
      #|        message: "`Basic.Data.Void.Void` must be an empty enum",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: [],
      #|    helps: ["provide the canonical structural derivation interfaces required by the language"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|]
    ),
  )
}

///|
test "derive uses a contextual deriver without importing its canonical module" {
  let result = check_sources(
    (
      #|module Main
      #|
      #|import Support.{ Box, derive_box }
      #|
      #|pub struct Point {
      #|  x : I64
      #|  y : I64
      #|}
      #|
      #|pub enum Choice {
      #|  none()
      #|  one(I64)
      #|  pair(Bool, I64)
      #|}
      #|
      #|pub struct Empty {}
      #|pub enum Never {}
      #|
      #|offer i64_box : Box[I64] = Box::{}
      #|offer bool_box : Box[Bool] = Box::{}
      #|
      #|pub let point_box : Box[Point] = derive[Box, Point]()
      #|pub let choice_box : Box[Choice] = derive[Box, Choice]()
      #|pub let empty_box : Box[Empty] = derive[Box, Empty]()
      #|pub let never_box : Box[Never] = derive[Box, Never]()
    ),
    [
      derive_void_source(),
      derive_iso_source(),
      derive_interface_source(),
      derive_support_source(),
    ],
  )
  debug_inspect(result.diagnostics, content="[]")
  guard result.source is Some(source) else { abort("expected checked source") }
  for declaration in source.declarations {
    if declaration is Let(declaration) &&
      declaration.name == "choice_box" &&
      declaration.initializer is Derive(plan~, ..) {
      let paths = []
      plan.shape.for_each_evidence(fn(evidence) { paths.push(evidence.path) })
      debug_inspect(
        paths,
        content=(
          #|["Choice.one[0]", "Choice.pair[0]", "Choice.pair[1]"]
        ),
      )
      return
    }
  }
  abort("expected enum derive plan")
}

///|
test "nested derive adds its canonical compiler dependencies" {
  let result = compile_sources(
    (
      #|module Main
      #|
      #|import Support.{ Box, derive_box }
      #|
      #|pub struct Point { value : I64 }
      #|
      #|pub fn point_box(
      #|  auto offer i64_box : Box[I64]
      #|) -> Box[Point] {
      #|  derive[Box, Point]()
      #|}
    ),
    [
      derive_void_source(),
      derive_iso_source(),
      derive_interface_source(),
      derive_support_source(),
    ],
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "derive metadata follows a normalized target through an imported alias" {
  let result = check_sources(
    (
      #|module Main
      #|
      #|import Alias.{ Position }
      #|import Support.{ Box, derive_box }
      #|
      #|offer i64_box : Box[I64] = Box[I64]::{}
      #|offer bool_box : Box[Bool] = Box[Bool]::{}
      #|pub let position_box : Box[Position[Bool]] = derive[Box, Position[Bool]]()
    ),
    [
      derive_void_source(),
      derive_iso_source(),
      derive_interface_source(),
      derive_support_source(),
      (
        #|module Hidden
        #|
        #|pub struct Pair[A, B] {
        #|  first : A
        #|  second : B
        #|}
      ),
      (
        #|module Alias
        #|
        #|import Hidden.{ Pair }
        #|
        #|pub type Position[A] = Pair[I64, A]
      ),
    ],
  )
  debug_inspect(result.diagnostics, content="[]")
  guard result.source is Some(source) else { abort("expected checked source") }
  for declaration in source.declarations {
    if declaration is Let(declaration) &&
      declaration.name == "position_box" &&
      declaration.initializer is Derive(plan~, ..) {
      debug_inspect(
        plan.metadata,
        content="{ name: \"Pair\", qualified_name: \"Hidden.Pair\" }",
      )
      return
    }
  }
  abort("expected checked derive plan")
}

///|
test "derive treats a closed existential nominal as ordinary component evidence" {
  let result = compile_sources(
    (
      #|module Main
      #|
      #|import Support.{ Box, derive_box }
      #|
      #|pub struct Hidden {
      #|  type Value : Type
      #|  value : Value
      #|}
      #|
      #|pub struct Container {
      #|  hidden : Hidden
      #|}
      #|
      #|offer hidden_box : Box[Hidden] = Box[Hidden]::{}
      #|
      #|pub let container_box : Box[Container] = derive[Box, Container]()
    ),
    [
      derive_void_source(),
      derive_iso_source(),
      derive_interface_source(),
      derive_support_source(),
    ],
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "derive type arguments retain semantic navigation" {
  let workspace = @analysis.SemanticWorkspace::new()
  let root =
    #|module Main
    #|
    #|import Support.{ Box, derive_box }
    #|
    #|pub struct Pair {
    #|  value : I64
    #|}
    #|
    #|pub offer i64_box : Box[I64] = Box[I64]::{}
    #|
    #|pub let pair_box : Box[Pair] = derive[Box, Pair]()
  guard workspace.replace_sources([
      { source_id: "file:///Main.lane", text: root },
      { source_id: "file:///Void.lane", text: derive_void_source() },
      { source_id: "file:///Iso.lane", text: derive_iso_source() },
      { source_id: "file:///Derive.lane", text: derive_interface_source() },
      { source_id: "file:///Support.lane", text: derive_support_source() },
    ])
    is Some(snapshot) else {
    abort("expected semantic snapshot")
  }
  debug_inspect(snapshot.diagnostics(), content="[]")
  guard snapshot.definition_at("file:///Main.lane", 11, 40) is Some(capability) else {
    abort("expected derive capability definition")
  }
  guard snapshot.definition_at("file:///Main.lane", 11, 45) is Some(target) else {
    abort("expected derive target definition")
  }
  assert_eq(capability.source_id, "file:///Support.lane")
  assert_eq(target.source_id, "file:///Main.lane")
  guard snapshot.hover_at("file:///Main.lane", 11, 45) is Some(hover) else {
    abort("expected derive target hover")
  }
  assert_eq(hover.contents, "type Pair")
  debug_inspect(
    (
      snapshot.definition_at("file:///Main.lane", 11, 33),
      snapshot.hover_at("file:///Main.lane", 11, 33),
      snapshot.inlay_hints_in_range("file:///Main.lane", 11, 1, 11, 51),
    ),
    content=(
      #|(
      #|  Some(
      #|    {
      #|      source_id: "file:///Support.lane",
      #|      span: {
      #|        start_offset: 825,
      #|        end_offset: 835,
      #|        start_line: 26,
      #|        start_column: 11,
      #|        end_line: 26,
      #|        end_column: 21,
      #|      },
      #|    },
      #|  ),
      #|  Some(
      #|    {
      #|      location: {
      #|        source_id: "file:///Main.lane",
      #|        span: {
      #|          start_offset: 160,
      #|          end_offset: 166,
      #|          start_line: 11,
      #|          start_column: 32,
      #|          end_line: 11,
      #|          end_column: 38,
      #|        },
      #|      },
      #|      contents: "derive[Box, Pair]() : Box[Pair]\nderiver: derive_box : Deriver[Box]\nevidence:\n  Pair.value: i64_box : Box[I64]\n// `C` must have kind `[Type] -> Type`.\n// `T` must normalize to a struct or enum application.\n// A bare generic type parameter cannot be used as `T` because its structure is unknown.\n// Omitting `deriver` selects one visible `Deriver[C]` offer.",
      #|    },
      #|  ),
      #|  [
      #|    {
      #|      location: {
      #|        source_id: "file:///Main.lane",
      #|        span: {
      #|          start_offset: 178,
      #|          end_offset: 178,
      #|          start_line: 11,
      #|          start_column: 50,
      #|          end_line: 11,
      #|          end_column: 50,
      #|        },
      #|      },
      #|      kind: ImplicitArgumentHint,
      #|      label: "deriver=derive_box",
      #|    },
      #|  ],
      #|)
    ),
  )
}

///|
test "explicit derive has hover without implicit navigation" {
  let workspace = @analysis.SemanticWorkspace::new()
  let root =
    #|module Main
    #|
    #|import Basic.Trait.Derive.{ Deriver }
    #|import Support.{ Box }
    #|
    #|pub struct Pair {
    #|  value : I64
    #|}
    #|
    #|pub offer i64_box : Box[I64] = Box[I64]::{}
    #|
    #|pub fn explicit(deriver : Deriver[Box]) -> Box[Pair] {
    #|  derive[Box, Pair](deriver=deriver)
    #|}
  guard workspace.replace_sources([
      { source_id: "file:///Main.lane", text: root },
      { source_id: "file:///Void.lane", text: derive_void_source() },
      { source_id: "file:///Iso.lane", text: derive_iso_source() },
      { source_id: "file:///Derive.lane", text: derive_interface_source() },
      { source_id: "file:///Support.lane", text: derive_support_source() },
    ])
    is Some(snapshot) else {
    abort("expected semantic snapshot")
  }
  debug_inspect(snapshot.diagnostics(), content="[]")
  assert_eq(snapshot.definition_at("file:///Main.lane", 13, 4), None)
  assert_eq(snapshot.inlay_hints_in_range("file:///Main.lane", 13, 1, 13, 40), [])
  guard snapshot.hover_at("file:///Main.lane", 13, 4) is Some(hover) else {
    abort("expected explicit derive hover")
  }
  assert_eq(
    hover.contents,
    (
      #|derive[Box, Pair](deriver=...) : Box[Pair]
      #|deriver: explicit : Deriver[Box]
      #|evidence:
      #|  Pair.value: i64_box : Box[I64]
      #|// `C` must have kind `[Type] -> Type`.
      #|// `T` must normalize to a struct or enum application.
      #|// A bare generic type parameter cannot be used as `T` because its structure is unknown.
      #|// Omitting `deriver` selects one visible `Deriver[C]` offer.
    ),
  )
}

///|
test "invalid generic derive target retains explanatory hover" {
  let workspace = @analysis.SemanticWorkspace::new()
  let root =
    #|module Main
    #|
    #|import Support.{ Box, derive_box }
    #|
    #|pub fn[T] invalid() -> Box[T] {
    #|  derive[Box, T]()
    #|}
  guard workspace.replace_sources([
      { source_id: "file:///Main.lane", text: root },
      { source_id: "file:///Void.lane", text: derive_void_source() },
      { source_id: "file:///Iso.lane", text: derive_iso_source() },
      { source_id: "file:///Derive.lane", text: derive_interface_source() },
      { source_id: "file:///Support.lane", text: derive_support_source() },
    ])
    is Some(snapshot) else {
    abort("expected semantic snapshot")
  }
  guard snapshot.hover_at("file:///Main.lane", 6, 4) is Some(hover) else {
    abort("expected derive hover after typechecking failure")
  }
  assert_eq(
    hover.contents,
    (
      #|derive[C, T](deriver=...) -> C[T]
      #|// `C` must have kind `[Type] -> Type`.
      #|// `T` must normalize to a struct or enum application.
      #|// A bare generic type parameter cannot be used as `T` because its structure is unknown.
      #|// Omitting `deriver` selects one visible `Deriver[C]` offer.
    ),
  )
}

///|
test "derive groups ambiguous component evidence by required type" {
  let result = compile_sources(
    (
      #|module Main
      #|
      #|import Basic.Trait.Derive.{ Deriver }
      #|
      #|pub struct Witness[_T] {}
      #|
      #|pub struct Pair {
      #|  first : I64
      #|  second : I64
      #|}
      #|
      #|pub offer first_int : Witness[I64] = Witness[I64]::{}
      #|pub offer second_int : Witness[I64] = Witness[I64]::{}
      #|
      #|pub fn ambiguous(
      #|  deriver : Deriver[Witness]
      #|) -> Witness[Pair] {
      #|  derive[Witness, Pair](deriver=deriver)
      #|}
    ),
    [derive_void_source(), derive_iso_source(), derive_interface_source()],
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "ambiguous structural derivation evidence",
      #|    span: Some(
      #|      Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 309,
      #|          end_offset: 347,
      #|          start_line: 18,
      #|          start_column: 3,
      #|          end_line: 18,
      #|          end_column: 41,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Error,
      #|    code: Some("E3031"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="<root>",
      #|          span={
      #|            start_offset: 309,
      #|            end_offset: 347,
      #|            start_line: 18,
      #|            start_column: 3,
      #|            end_line: 18,
      #|            end_column: 41,
      #|          },
      #|        ),
      #|        message: "multiple contextual offers match `Witness[I64]`",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: [
      #|      "required by: Pair.first, Pair.second",
      #|      "candidates: first_int, second_int",
      #|    ],
      #|    helps: ["hide or rename offers so exactly one candidate is visible"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|]
    ),
  )
}

///|
test "derive collects component evidence diagnostics after missing deriver" {
  let result = compile_sources(
    (
      #|module Main
      #|
      #|pub struct Witness[_T] {}
      #|
      #|pub struct Pair {
      #|  first : I64
      #|  second : Bool
      #|}
      #|
      #|pub let pair_witness : Witness[Pair] = derive[Witness, Pair]()
    ),
    [derive_void_source(), derive_iso_source(), derive_interface_source()],
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "missing contextual offer",
      #|    span: Some(
      #|      Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 130,
      #|          end_offset: 153,
      #|          start_line: 10,
      #|          start_column: 40,
      #|          end_line: 10,
      #|          end_column: 63,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Error,
      #|    code: Some("E3013"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="<root>",
      #|          span={
      #|            start_offset: 130,
      #|            end_offset: 153,
      #|            start_line: 10,
      #|            start_column: 40,
      #|            end_line: 10,
      #|            end_column: 63,
      #|          },
      #|        ),
      #|        message: "no visible offer matches required type `Deriver[Witness]`",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: ["contextual arguments are inserted only from visible `offer` bindings with matching type"],
      #|    helps: ["pass the argument explicitly or add a visible `offer` with type `Deriver[Witness]`"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "missing structural derivation evidence",
      #|    span: Some(
      #|      Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 130,
      #|          end_offset: 153,
      #|          start_line: 10,
      #|          start_column: 40,
      #|          end_line: 10,
      #|          end_column: 63,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Error,
      #|    code: Some("E3030"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="<root>",
      #|          span={
      #|            start_offset: 130,
      #|            end_offset: 153,
      #|            start_line: 10,
      #|            start_column: 40,
      #|            end_line: 10,
      #|            end_column: 63,
      #|          },
      #|        ),
      #|        message: "no exact contextual offer is available for `Witness[I64]`",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: ["required by: Pair.first"],
      #|    helps: ["provide one visible offer of the required component capability"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|  {
      #|    source_id: Some("<root>"),
      #|    message: "missing structural derivation evidence",
      #|    span: Some(
      #|      Source(
      #|        source_id="<root>",
      #|        span={
      #|          start_offset: 130,
      #|          end_offset: 153,
      #|          start_line: 10,
      #|          start_column: 40,
      #|          end_line: 10,
      #|          end_column: 63,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Error,
      #|    code: Some("E3030"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="<root>",
      #|          span={
      #|            start_offset: 130,
      #|            end_offset: 153,
      #|            start_line: 10,
      #|            start_column: 40,
      #|            end_line: 10,
      #|            end_column: 63,
      #|          },
      #|        ),
      #|        message: "no exact contextual offer is available for `Witness[Bool]`",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: ["required by: Pair.second"],
      #|    helps: ["provide one visible offer of the required component capability"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|]
    ),
  )
}

///|
fn derive_void_source() -> String {
  (
    #|module Basic.Data.Void
    #|
    #|pub enum Void {}
  )
}

///|
fn derive_iso_source() -> String {
  (
    #|module Basic.Trait.Iso
    #|
    #|pub struct Iso[T, R] {
    #|  to : (T) -> R
    #|  from : (R) -> T
    #|}
  )
}

///|
fn derive_interface_source() -> String {
  (
    #|module Basic.Trait.Derive
    #|
    #|import Basic.Data.Void.{ Void }
    #|import Basic.Trait.Iso.{ Iso }
    #|
    #|pub struct Deriver[C : [Type] -> Type] {
    #|  unit : () -> C[Unit]
    #|  product : [A, B](C[A], C[B]) -> C[Product[A, B]]
    #|  void : () -> C[Void]
    #|  sum : [A, B](C[A], C[B]) -> C[Sum[A, B]]
    #|  field : [A](FieldInfo, C[A]) -> C[A]
    #|  variant : [A](VariantInfo, C[A]) -> C[A]
    #|  record : [T, R](TypeInfo, Iso[T, R], C[R]) -> C[T]
    #|  enumeration : [T, R](TypeInfo, Iso[T, R], C[R]) -> C[T]
    #|}
    #|
    #|pub struct Product[A, B] {
    #|  head : A
    #|  tail : B
    #|}
    #|
    #|pub enum Sum[A, B] {
    #|  here(A)
    #|  there(B)
    #|}
    #|
    #|pub struct TypeInfo {
    #|  name : String
    #|  qualified_name : String
    #|}
    #|
    #|pub struct FieldInfo {
    #|  name : String
    #|}
    #|
    #|pub struct VariantInfo {
    #|  name : String
    #|}
  )
}

///|
fn derive_support_source() -> String {
  (
    #|module Support
    #|
    #|import Basic.Data.Void.{ Void }
    #|import Basic.Trait.Derive.{ Deriver, FieldInfo, Product, Sum, TypeInfo, VariantInfo }
    #|import Basic.Trait.Iso.{ Iso }
    #|
    #|pub struct Box[_T] {}
    #|
    #|fn box_unit() -> Box[Unit] { Box[Unit]::{} }
    #|fn[A, B] box_product(_a : Box[A], _b : Box[B]) -> Box[Product[A, B]] {
    #|  Box[Product[A, B]]::{}
    #|}
    #|fn box_void() -> Box[Void] { Box[Void]::{} }
    #|fn[A, B] box_sum(_a : Box[A], _b : Box[B]) -> Box[Sum[A, B]] {
    #|  Box[Sum[A, B]]::{}
    #|}
    #|fn[A] box_field(_info : FieldInfo, value : Box[A]) -> Box[A] { value }
    #|fn[A] box_variant(_info : VariantInfo, value : Box[A]) -> Box[A] { value }
    #|fn[T, R] box_record(_info : TypeInfo, _iso : Iso[T, R], _value : Box[R]) -> Box[T] {
    #|  Box[T]::{}
    #|}
    #|fn[T, R] box_enumeration(_info : TypeInfo, _iso : Iso[T, R], _value : Box[R]) -> Box[T] {
    #|  Box[T]::{}
    #|}
    #|
    #|pub offer derive_box : Deriver[Box] = Deriver::{
    #|  unit: box_unit,
    #|  product: box_product,
    #|  void: box_void,
    #|  sum: box_sum,
    #|  field: box_field,
    #|  variant: box_variant,
    #|  record: box_record,
    #|  enumeration: box_enumeration,
    #|}
  )
}
