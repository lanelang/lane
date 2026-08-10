///|
fn analyze_test_source_inputs(
  root : @module_frontend.SourceInput,
  libraries : Array[@module_frontend.SourceInput],
) -> @analysis.AnalysisResult {
  let workspace = @analysis.SemanticWorkspace::new()
  guard workspace.replace_sources([root] + libraries) is Some(snapshot) else {
    abort("expected semantic snapshot")
  }
  snapshot.analysis()
}

///|
test "semantic workspace reports diagnostics from every workspace module" {
  let result = analyze_test_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|import Lib.*
        #|pub let answer : I64 = value
      ),
    },
    [
      {
        source_id: "file:///Lib.lane",
        text: (
          #|module Lib
          #|pub let broken : =
        ),
      },
      {
        source_id: "file:///Unrelated.lane",
        text: (
          #|module Unrelated
          #|pub let also_broken : =
        ),
      },
    ],
  )
  debug_inspect(
    result.diagnostics.map(fn(diagnostic) {
      (diagnostic.source_id, diagnostic.message)
    }),
    content=(
      #|[
      #|  (Some("file:///Lib.lane"), "unexpected token"),
      #|  (Some("file:///Unrelated.lane"), "unexpected token"),
      #|]
    ),
  )
}

///|
test "analysis resolves same-file definition and hover" {
  let result = analyze_test_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub let value : I64 = 42
        #|
        #|pub let answer : I64 = value
      ),
    },
    [],
  )
  debug_inspect(result.diagnostics, content="[]")
  match result.definition_at("file:///Main.lane", 5, 24) {
    Some(location) => {
      inspect(location.source_id, content="file:///Main.lane")
      inspect(location.span.start_line, content="3")
    }
    None => abort("expected definition")
  }
  match result.hover_at("file:///Main.lane", 5, 24) {
    Some(hover) => inspect(hover.contents, content="value : I64")
    None => abort("expected hover")
  }
  match result.hover_at("file:///Main.lane", 3, 10) {
    Some(hover) => inspect(hover.contents, content="value : I64")
    None => abort("expected definition hover")
  }
  inspect(
    result.definition_at("file:///Main.lane", 5, 29) is None,
    content="true",
  )
}

///|
test "analysis traverses explicit generic application" {
  let result = analyze_test_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub struct Box {
        #|  value : I64
        #|}
        #|
        #|pub fn[A] id(value : A) -> A {
        #|  value
        #|}
        #|
        #|pub let answer : Box = id[Box](Box::{ value: 1 })
      ),
    },
    [],
  )
  debug_inspect(result.diagnostics, content="[]")
  match result.definition_at("file:///Main.lane", 11, 24) {
    Some(location) => inspect(location.span.start_line, content="7")
    None => abort("expected generic callee definition")
  }
  match result.hover_at("file:///Main.lane", 11, 24) {
    Some(hover) =>
      inspect(hover.contents, content="id : forall [A : Type]. (A) -> A")
    None => abort("expected generic callee hover")
  }
  match result.definition_at("file:///Main.lane", 11, 27) {
    Some(location) => inspect(location.span.start_line, content="3")
    None => abort("expected generic argument type definition")
  }
  debug_inspect(
    result.inlay_hints.map(fn(hint) { hint.label }),
    content=(
      #|["value="]
    ),
  )
}

///|
test "analysis keeps generic operation hover declaration detail" {
  let result = analyze_test_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub effect Prompt {
        #|  choose[A](A, A) -> A
        #|}
        #|
        #|pub fn use() -> I64 ! Prompt {
        #|  Prompt::choose![I64](1, 2)
        #|}
      ),
    },
    [],
  )
  debug_inspect(result.diagnostics, content="[]")
  match result.hover_at("file:///Main.lane", 8, 11) {
    Some(hover) =>
      inspect(
        hover.contents,
        content="operation Prompt::choose[A : Type](A, A) -> A",
      )
    None => abort("expected operation hover")
  }
}

///|
test "analysis resolves cross-module definition by source identity" {
  let result = analyze_test_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|import Lib.*
        #|
        #|pub let answer : I64 = value
      ),
    },
    [
      {
        source_id: "file:///Lib.lane",
        text: (
          #|module Lib
          #|
          #|pub let value : I64 = 42
        ),
      },
    ],
  )
  debug_inspect(result.diagnostics, content="[]")
  match result.definition_at("file:///Main.lane", 5, 24) {
    Some(location) => {
      inspect(location.source_id, content="file:///Lib.lane")
      inspect(location.span.start_line, content="3")
    }
    None => abort("expected cross-module definition")
  }
}

///|
test "analysis resolves types fields and variants" {
  let result = analyze_test_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub struct Point {
        #|  x : I64
        #|}
        #|
        #|pub enum Option {
        #|  some(Point)
        #|  none()
        #|}
        #|
        #|pub let point : Point = Point::{ x: 1 }
        #|
        #|pub let field_value : I64 = point.x
        #|
        #|pub let wrapped : Option = some(point)
      ),
    },
    [],
  )
  debug_inspect(result.diagnostics, content="[]")
  match result.definition_at("file:///Main.lane", 12, 18) {
    Some(location) => inspect(location.span.start_line, content="3")
    None => abort("expected type definition")
  }
  match result.definition_at("file:///Main.lane", 12, 26) {
    Some(location) => inspect(location.span.start_line, content="3")
    None => abort("expected struct literal type definition")
  }
  inspect(
    result.definition_at("file:///Main.lane", 12, 32) is None,
    content="true",
  )
  inspect(
    result.definition_at("file:///Main.lane", 12, 38) is None,
    content="true",
  )
  inspect(
    result.definition_at("file:///Main.lane", 12, 39) is None,
    content="true",
  )
  match result.hover_at("file:///Main.lane", 3, 13) {
    Some(hover) => inspect(hover.contents, content="type Point : Type")
    None => abort("expected type definition hover")
  }
  match result.definition_at("file:///Main.lane", 14, 35) {
    Some(location) => inspect(location.span.start_line, content="4")
    None => abort("expected field definition")
  }
  match result.hover_at("file:///Main.lane", 4, 3) {
    Some(hover) => inspect(hover.contents, content="x : I64")
    None => abort("expected field definition hover")
  }
  match result.definition_at("file:///Main.lane", 16, 29) {
    Some(location) => inspect(location.span.start_line, content="8")
    None => abort("expected variant definition")
  }
  match result.hover_at("file:///Main.lane", 16, 29) {
    Some(hover) => inspect(hover.contents, content="some(Point)")
    None => abort("expected variant hover")
  }
}

///|
test "analysis hovers handler binders with checked types" {
  let result = analyze_test_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub effect Console {
        #|  read() -> I64
        #|}
        #|pub effect State {
        #|  get() -> I64
        #|}
        #|pub fn answer() -> I64 ! State {
        #|  handle Console::read!() with {
        #|    Console::read(resume) => resume(0)
        #|  } final value {
        #|    let _state : I64 = State::get!()
        #|    value
        #|  }
        #|}
      ),
    },
    [],
  )
  debug_inspect(result.diagnostics, content="[]")
  match result.hover_at("file:///Main.lane", 11, 20) {
    Some(hover) =>
      inspect(hover.contents, content="resume : (I64) -> I64 ! State")
    None => abort("expected resume binder hover")
  }
  match result.hover_at("file:///Main.lane", 11, 31) {
    Some(hover) =>
      inspect(hover.contents, content="resume : (I64) -> I64 ! State")
    None => abort("expected resume reference hover")
  }
  match result.hover_at("file:///Main.lane", 12, 12) {
    Some(hover) => inspect(hover.contents, content="value : I64")
    None => abort("expected final binder hover")
  }
}

///|
test "analysis narrows struct pattern type references" {
  let result = analyze_test_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub struct Point {
        #|  x : I64
        #|}
        #|
        #|pub fn get_x(point : Point) -> I64 {
        #|  match point {
        #|    Point::{ x } => x
        #|  }
        #|}
      ),
    },
    [],
  )
  debug_inspect(result.diagnostics, content="[]")
  match result.definition_at("file:///Main.lane", 9, 6) {
    Some(location) => inspect(location.span.start_line, content="3")
    None => abort("expected pattern type definition")
  }
  inspect(
    result.definition_at("file:///Main.lane", 9, 13) is None,
    content="true",
  )
}

///|
test "analysis keeps partial definitions when unrelated diagnostics exist" {
  let result = analyze_test_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub let value : I64 = 42
        #|
        #|pub let answer : I64 = value
        #|
        #|pub let bad : I64 = missing
      ),
    },
    [],
  )
  debug_inspect(
    result.diagnostics.map(fn(diagnostic) { diagnostic.message }),
    content=(
      #|["cannot find value `missing`"]
    ),
  )
  match result.definition_at("file:///Main.lane", 5, 24) {
    Some(location) => {
      inspect(location.source_id, content="file:///Main.lane")
      inspect(location.span.start_line, content="3")
    }
    None => abort("expected partial definition")
  }
}

///|
test "analysis produces type inlay hints for inferred binders" {
  let result = analyze_test_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub fn answer(seed : I64) -> I64 {
        #|  let local = seed
        #|  match local {
        #|    value => value
        #|  }
        #|}
      ),
    },
    [],
  )
  debug_inspect(result.diagnostics, content="[]")
  debug_inspect(
    result.inlay_hints,
    content=(
      #|[
      #|  {
      #|    position: { source_id: "file:///Main.lane", line: 4, column: 12 },
      #|    kind: TypeHint,
      #|    label: ": I64",
      #|  },
      #|  {
      #|    position: { source_id: "file:///Main.lane", line: 6, column: 10 },
      #|    kind: TypeHint,
      #|    label: ": I64",
      #|  },
      #|]
    ),
  )
}

///|
test "analysis renders user-facing type names in type inlay hints" {
  let result = analyze_test_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub enum Option[T] {
        #|  some(T)
        #|  none()
        #|}
        #|
        #|pub fn answer(seed : I64) -> I64 {
        #|  let boxed = some(seed)
        #|  seed
        #|}
      ),
    },
    [],
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    source_id: Some("file:///Main.lane"),
      #|    message: "unused local value binding",
      #|    span: Some(
      #|      Source(
      #|        source_id="file:///Main.lane",
      #|        span={
      #|          start_offset: 97,
      #|          end_offset: 102,
      #|          start_line: 9,
      #|          start_column: 7,
      #|          end_line: 9,
      #|          end_column: 12,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Warning,
      #|    code: Some("W2001"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="file:///Main.lane",
      #|          span={
      #|            start_offset: 97,
      #|            end_offset: 102,
      #|            start_line: 9,
      #|            start_column: 7,
      #|            end_line: 9,
      #|            end_column: 12,
      #|          },
      #|        ),
      #|        message: "`boxed` is never used",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: [],
      #|    helps: ["prefix the name with `_` if this is intentional"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|]
    ),
  )
  debug_inspect(
    result.inlay_hints,
    content=(
      #|[
      #|  {
      #|    position: { source_id: "file:///Main.lane", line: 9, column: 12 },
      #|    kind: TypeHint,
      #|    label: ": Option[I64]",
      #|  },
      #|]
    ),
  )
}

///|
test "analysis produces parameter name inlay hints for calls" {
  let result = analyze_test_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub enum Option {
        #|  some(I64, Bool)
        #|  none()
        #|}
        #|
        #|pub fn choose(left : I64, right : I64) -> I64 {
        #|  left
        #|}
        #|
        #|pub fn answer(seed : I64) -> I64 {
        #|  let local = choose(seed, 1)
        #|  match some(local, true) {
        #|    some(value, flag) => value
        #|    none() => 0
        #|  }
        #|}
      ),
    },
    [],
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    source_id: Some("file:///Main.lane"),
      #|    message: "unused local value binding",
      #|    span: Some(
      #|      Source(
      #|        source_id="file:///Main.lane",
      #|        span={
      #|          start_offset: 87,
      #|          end_offset: 92,
      #|          start_line: 8,
      #|          start_column: 27,
      #|          end_line: 8,
      #|          end_column: 32,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Warning,
      #|    code: Some("W2001"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="file:///Main.lane",
      #|          span={
      #|            start_offset: 87,
      #|            end_offset: 92,
      #|            start_line: 8,
      #|            start_column: 27,
      #|            end_line: 8,
      #|            end_column: 32,
      #|          },
      #|        ),
      #|        message: "`right` is never used",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: [],
      #|    helps: ["prefix the name with `_` if this is intentional"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|  {
      #|    source_id: Some("file:///Main.lane"),
      #|    message: "unused local value binding",
      #|    span: Some(
      #|      Source(
      #|        source_id="file:///Main.lane",
      #|        span={
      #|          start_offset: 228,
      #|          end_offset: 232,
      #|          start_line: 15,
      #|          start_column: 17,
      #|          end_line: 15,
      #|          end_column: 21,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Warning,
      #|    code: Some("W2001"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="file:///Main.lane",
      #|          span={
      #|            start_offset: 228,
      #|            end_offset: 232,
      #|            start_line: 15,
      #|            start_column: 17,
      #|            end_line: 15,
      #|            end_column: 21,
      #|          },
      #|        ),
      #|        message: "`flag` is never used",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: [],
      #|    helps: ["prefix the name with `_` if this is intentional"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|]
    ),
  )
  debug_inspect(
    result.inlay_hints,
    content=(
      #|[
      #|  {
      #|    position: { source_id: "file:///Main.lane", line: 13, column: 12 },
      #|    kind: TypeHint,
      #|    label: ": I64",
      #|  },
      #|  {
      #|    position: { source_id: "file:///Main.lane", line: 13, column: 22 },
      #|    kind: ParameterHint,
      #|    label: "left=",
      #|  },
      #|  {
      #|    position: { source_id: "file:///Main.lane", line: 13, column: 28 },
      #|    kind: ParameterHint,
      #|    label: "right=",
      #|  },
      #|  {
      #|    position: { source_id: "file:///Main.lane", line: 15, column: 15 },
      #|    kind: TypeHint,
      #|    label: ": I64",
      #|  },
      #|  {
      #|    position: { source_id: "file:///Main.lane", line: 15, column: 21 },
      #|    kind: TypeHint,
      #|    label: ": Bool",
      #|  },
      #|]
    ),
  )
}

///|
test "analysis does not synthesize constructor parameter hints from payload types" {
  let result = analyze_test_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub enum List[A] {
        #|  nil()
        #|  cons(A, List[A])
        #|}
        #|
        #|pub fn answer(hd : I64, tl : List[I64]) -> List[I64] {
        #|  List::cons(hd, tl)
        #|}
      ),
    },
    [],
  )
  debug_inspect(result.diagnostics, content="[]")
  inspect(result.inlay_hints.length(), content="0")
}

///|
test "analysis keeps nested call parameter hints at distinct positions" {
  let result = analyze_test_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub fn append(left : I64, right : I64) -> I64 {
        #|  left
        #|}
        #|
        #|pub fn apply(f : (I64) -> I64, value : I64) -> I64 {
        #|  f(value)
        #|}
        #|
        #|pub fn inc(value : I64) -> I64 {
        #|  value
        #|}
        #|
        #|pub let answer : I64 = append(1, apply(inc, 2))
      ),
    },
    [],
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    source_id: Some("file:///Main.lane"),
      #|    message: "unused local value binding",
      #|    span: Some(
      #|      Source(
      #|        source_id="file:///Main.lane",
      #|        span={
      #|          start_offset: 39,
      #|          end_offset: 44,
      #|          start_line: 3,
      #|          start_column: 27,
      #|          end_line: 3,
      #|          end_column: 32,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Warning,
      #|    code: Some("W2001"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="file:///Main.lane",
      #|          span={
      #|            start_offset: 39,
      #|            end_offset: 44,
      #|            start_line: 3,
      #|            start_column: 27,
      #|            end_line: 3,
      #|            end_column: 32,
      #|          },
      #|        ),
      #|        message: "`right` is never used",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: [],
      #|    helps: ["prefix the name with `_` if this is intentional"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|]
    ),
  )
  assert_no_duplicate_parameter_hint_positions(result.inlay_hints)
}

///|
test "analysis anchors field argument parameter hint at argument start" {
  let result = analyze_test_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub struct Box {
        #|  field : I64
        #|}
        #|
        #|pub fn take(arg : I64) -> I64 {
        #|  arg
        #|}
        #|
        #|pub fn answer(value : Box) -> I64 {
        #|  take(value.field)
        #|}
      ),
    },
    [],
  )
  debug_inspect(result.diagnostics, content="[]")
  debug_inspect(
    result.inlay_hints,
    content=(
      #|[
      #|  {
      #|    position: { source_id: "file:///Main.lane", line: 12, column: 8 },
      #|    kind: ParameterHint,
      #|    label: "arg=",
      #|  },
      #|]
    ),
  )
}

///|
test "analysis skips parameter name inlay hints for source operators" {
  let result = analyze_test_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub fn op_add(left : I64, right : I64) -> I64 {
        #|  left
        #|}
        #|
        #|pub fn answer(seed : I64) -> I64 {
        #|  let local = seed + 1
        #|  local
        #|}
      ),
    },
    [],
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    source_id: Some("file:///Main.lane"),
      #|    message: "unused local value binding",
      #|    span: Some(
      #|      Source(
      #|        source_id="file:///Main.lane",
      #|        span={
      #|          start_offset: 39,
      #|          end_offset: 44,
      #|          start_line: 3,
      #|          start_column: 27,
      #|          end_line: 3,
      #|          end_column: 32,
      #|        },
      #|      ),
      #|    ),
      #|    severity: Warning,
      #|    code: Some("W2001"),
      #|    labels: [
      #|      {
      #|        span: Source(
      #|          source_id="file:///Main.lane",
      #|          span={
      #|            start_offset: 39,
      #|            end_offset: 44,
      #|            start_line: 3,
      #|            start_column: 27,
      #|            end_line: 3,
      #|            end_column: 32,
      #|          },
      #|        ),
      #|        message: "`right` is never used",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: [],
      #|    helps: ["prefix the name with `_` if this is intentional"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|]
    ),
  )
  debug_inspect(
    result.inlay_hints,
    content=(
      #|[
      #|  {
      #|    position: { source_id: "file:///Main.lane", line: 8, column: 12 },
      #|    kind: TypeHint,
      #|    label: ": I64",
      #|  },
      #|]
    ),
  )
}

///|
test "analysis produces implicit argument inlay hints for auto offers" {
  let result = analyze_test_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub struct Add[A] {
        #|  add : (A, A) -> A
        #|}
        #|
        #|pub fn[A] op_add(a : A, b : A, auto op : Add[A]) -> A {
        #|  op.add(a, b)
        #|}
        #|
        #|offer i64_add_ops : Add[I64] = Add::{ add: fn(a : I64, b : I64) -> I64 { builtin("%i64_add")(a, b) } }
        #|
        #|pub fn answer(seed : I64) -> I64 {
        #|  let local = seed + 1
        #|  local
        #|}
      ),
    },
    [],
  )
  debug_inspect(result.diagnostics, content="[]")
  debug_inspect(
    result.inlay_hints,
    content=(
      #|[
      #|  {
      #|    position: { source_id: "file:///Main.lane", line: 14, column: 12 },
      #|    kind: TypeHint,
      #|    label: ": I64",
      #|  },
      #|  {
      #|    position: { source_id: "file:///Main.lane", line: 14, column: 23 },
      #|    kind: ImplicitArgumentHint,
      #|    label: ", op=i64_add_ops",
      #|  },
      #|]
    ),
  )
}

///|
test "analysis combines implicit argument inlay hints at the call end" {
  let result = analyze_test_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub struct Add[A] {
        #|  add : (A, A) -> A
        #|}
        #|
        #|pub struct Eq[A] {
        #|  eq : (A, A) -> Bool
        #|}
        #|
        #|pub fn[A] choose(a : A, b : A, auto op : Add[A], auto eq : Eq[A]) -> A {
        #|  if eq.eq(a, b) {
        #|    op.add(a, b)
        #|  } else {
        #|    a
        #|  }
        #|}
        #|
        #|offer i64_add_ops : Add[I64] = Add::{ add: fn(a : I64, b : I64) -> I64 { builtin("%i64_add")(a, b) } }
        #|offer i64_eq_ops : Eq[I64] = Eq::{ eq: fn(a : I64, b : I64) -> Bool { builtin("%i64_equal")(a, b) } }
        #|
        #|pub fn answer(seed : I64) -> I64 {
        #|  let local = choose(seed, 1)
        #|  local
        #|}
      ),
    },
    [],
  )
  debug_inspect(result.diagnostics, content="[]")
  inspect(
    implicit_inlay_hint_labels(result.inlay_hints).join("\n"),
    content=", op=i64_add_ops, eq=i64_eq_ops",
  )
}

///|
test "analysis omits the separator for an auto-only call" {
  let result = analyze_test_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub struct Default {
        #|  value : I64
        #|}
        #|
        #|pub fn use(auto impl : Default) -> I64 {
        #|  impl.value
        #|}
        #|
        #|offer default_impl : Default = Default::{ value: 1 }
        #|
        #|pub fn answer() -> I64 {
        #|  use()
        #|}
      ),
    },
    [],
  )
  debug_inspect(result.diagnostics, content="[]")
  assert_eq(implicit_inlay_hint_labels(result.inlay_hints), [
    "impl=default_impl",
  ])
}

///|
test "analysis does not mark explicit named auto arguments as implicit" {
  let result = analyze_test_source_inputs(
    {
      source_id: "file:///Main.lane",
      text: (
        #|module Main
        #|
        #|pub struct Add[A] {
        #|  add : (A, A) -> A
        #|}
        #|
        #|pub fn[A] op_add(a : A, b : A, auto op : Add[A]) -> A {
        #|  op.add(a, b)
        #|}
        #|
        #|let i64_add_ops : Add[I64] = Add::{ add: fn(a : I64, b : I64) -> I64 { builtin("%i64_add")(a, b) } }
        #|
        #|pub fn answer(seed : I64) -> I64 {
        #|  let local = op_add(seed, 1, op=i64_add_ops)
        #|  local
        #|}
      ),
    },
    [],
  )
  debug_inspect(result.diagnostics, content="[]")
  debug_inspect(
    result.inlay_hints,
    content=(
      #|[
      #|  {
      #|    position: { source_id: "file:///Main.lane", line: 14, column: 12 },
      #|    kind: TypeHint,
      #|    label: ": I64",
      #|  },
      #|  {
      #|    position: { source_id: "file:///Main.lane", line: 14, column: 22 },
      #|    kind: ParameterHint,
      #|    label: "a=",
      #|  },
      #|  {
      #|    position: { source_id: "file:///Main.lane", line: 14, column: 28 },
      #|    kind: ParameterHint,
      #|    label: "b=",
      #|  },
      #|]
    ),
  )
}

///|
fn implicit_inlay_hint_labels(
  hints : Array[@analysis.InlayHintEntry],
) -> Array[String] {
  let labels = []
  for hint in hints {
    match hint.kind {
      ImplicitArgumentHint => labels.push(hint.label)
      _ => ()
    }
  }
  labels
}

///|
fn assert_no_duplicate_parameter_hint_positions(
  hints : Array[@analysis.InlayHintEntry],
) -> Unit {
  let positions = []
  for hint in hints {
    guard hint.kind is ParameterHint else { continue }
    let position = "\{hint.position.source_id}:\{hint.position.line}:\{hint.position.column}"
    if positions.contains(position) {
      abort("duplicate parameter inlay hint position: \{position}")
    }
    positions.push(position)
  }
}
