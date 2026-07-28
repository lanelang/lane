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
      #|  x : Int
      #|  y : Int
      #|}
      #|
      #|pub struct Wrapper[T] {
      #|  value : T
      #|}
      #|
      #|pub fn point_equal(
      #|  deriver : Deriver[Equal],
      #|  auto offer int_equal : Equal[Int]
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
    [derive_void_source(), derive_interface_source()],
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
      #|pub struct Point { value : Int }
      #|
      #|pub fn point_box(
      #|  deriver : Deriver[Box],
      #|  auto offer int_box : Box[Int]
      #|) -> Box[Point] {
      #|  derive[Box, Point](deriver=deriver)
      #|}
    ),
    [derive_void_source(), malformed_interface],
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
      #|    helps: ["provide the canonical `Basic.Trait.Derive` interface required by the language"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|]
    ),
  )
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
    [nonempty_void, derive_interface_source()],
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
      #|    helps: ["provide the canonical `Basic.Trait.Derive` interface required by the language"],
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
      #|  x : Int
      #|  y : Int
      #|}
      #|
      #|pub enum Choice {
      #|  none()
      #|  one(Int)
      #|  pair(Bool, Int)
      #|}
      #|
      #|pub struct Empty {}
      #|pub enum Never {}
      #|
      #|offer int_box : Box[Int] = Box::{}
      #|offer bool_box : Box[Bool] = Box::{}
      #|
      #|pub let point_box : Box[Point] = derive[Box, Point]()
      #|pub let choice_box : Box[Choice] = derive[Box, Choice]()
      #|pub let empty_box : Box[Empty] = derive[Box, Empty]()
      #|pub let never_box : Box[Never] = derive[Box, Never]()
    ),
    [derive_void_source(), derive_interface_source(), derive_support_source()],
  )
  debug_inspect(result.diagnostics, content="[]")
  guard result.source is Some(source) else { abort("expected checked source") }
  for declaration in source.declarations {
    if declaration is Let(declaration) &&
      declaration.name == "choice_box" &&
      declaration.initializer is Derive(plan~, ..) {
      debug_inspect(
        plan.evidence.map(fn(evidence) { evidence.path }),
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
      #|pub struct Point { value : Int }
      #|
      #|pub fn point_box(
      #|  auto offer int_box : Box[Int]
      #|) -> Box[Point] {
      #|  derive[Box, Point]()
      #|}
    ),
    [derive_void_source(), derive_interface_source(), derive_support_source()],
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
      #|offer int_box : Box[Int] = Box[Int]::{}
      #|offer bool_box : Box[Bool] = Box[Bool]::{}
      #|pub let position_box : Box[Position[Bool]] = derive[Box, Position[Bool]]()
    ),
    [
      derive_void_source(),
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
        #|pub type Position[A] = Pair[Int, A]
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
    [derive_void_source(), derive_interface_source(), derive_support_source()],
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
    #|  value : Int
    #|}
    #|
    #|pub offer int_box : Box[Int] = Box[Int]::{}
    #|
    #|pub let pair_box : Box[Pair] = derive[Box, Pair]()
  guard workspace.replace_sources([
      { source_id: "file:///Main.lane", text: root },
      { source_id: "file:///Void.lane", text: derive_void_source() },
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
      #|  first : Int
      #|  second : Int
      #|}
      #|
      #|pub offer first_int : Witness[Int] = Witness[Int]::{}
      #|pub offer second_int : Witness[Int] = Witness[Int]::{}
      #|
      #|pub fn ambiguous(
      #|  deriver : Deriver[Witness]
      #|) -> Witness[Pair] {
      #|  derive[Witness, Pair](deriver=deriver)
      #|}
    ),
    [derive_void_source(), derive_interface_source()],
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
      #|        message: "multiple contextual offers match `Witness[Int]`",
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
fn derive_void_source() -> String {
  (
    #|module Basic.Data.Void
    #|
    #|pub enum Void {}
  )
}

///|
fn derive_interface_source() -> String {
  (
    #|module Basic.Trait.Derive
    #|
    #|import Basic.Data.Void.{ Void }
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
    #|pub struct Iso[T, R] {
    #|  to : (T) -> R
    #|  from : (R) -> T
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
    #|import Basic.Trait.Derive.{ Deriver, FieldInfo, Iso, Product, Sum, TypeInfo, VariantInfo }
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
