///|
test "selective import preserves an offered function" {
  let library = compile_modules_for_test(
    (
      #|module A
      #|pub offer fn provide() -> I64 {
      #|  42
      #|}
    ),
    [],
  )
  guard library.modules is Some(modules) else {
    abort("expected compiled library")
  }
  guard @module_compile.find_compiled_module(modules.modules, "A")
    is Some(module_) else {
    abort("expected module A")
  }
  let binary = @artifact.module_interface_artifact_to_binary(
    module_.to_interface_artifact(),
  )
  let interface = match
    @artifact.parse_module_interface_artifact_binary(binary) {
    Ok(interface) => interface
    Err(message) => abort(message)
  }
  guard interface.interface.values
    is [{ kind: Function, is_offered: true, name: "provide", .. }] else {
    abort("expected offered function interface metadata")
  }
  let result = check_source_with_interfaces_for_test(
    (
      #|module B
      #|import A.{ provide }
      #|fn use(auto provider : () -> I64) -> I64 {
      #|  provider()
      #|}
      #|pub let answer : I64 = use()
    ),
    [interface],
  )
  guard result.source is Some(_) else { abort("expected checked source") }
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "compile sources accepts explicit library modules" {
  let result = compile_sources_for_test(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : I64 = value
    ),
    [
      (
        #|module Lib
        #|pub let value : I64 = 42
      ),
    ],
  )
  debug_inspect(result.diagnostics, content="[]")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "compile sources exposes only root public entries" {
  let result = compile_sources_for_test(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : I64 = value
    ),
    [
      (
        #|module Lib
        #|pub let value : I64 = 42
      ),
    ],
  )
  debug_inspect(result.diagnostics, content="[]")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "compile sources accepts selective import with module dot syntax" {
  let result = compile_sources_for_test(
    (
      #|module Main
      #|import Lib.{ value }
      #|pub let answer : I64 = value
    ),
    [
      (
        #|module Lib
        #|pub let value : I64 = 42
      ),
    ],
  )
  debug_inspect(result.diagnostics, content="[]")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
fn contextual_import_test_library() -> String {
  (
    #|module Ops
    #|pub struct Add[A] {
    #|  add : (A, A) -> A
    #|}
    #|pub fn[A] op_add(left : A, right : A, auto op : Add[A]) -> A {
    #|  op.add(left, right)
    #|}
    #|pub offer i64_add_ops : Add[I64] = Add::{ add: fn(left : I64, right : I64) -> I64 { builtin("%i64_add")(left, right) } }
  )
}

///|
test "selective import does not expose an unselected contextual offer" {
  let result = check_sources_for_test(
    (
      #|module Main
      #|import Ops.{ op_add }
      #|pub let answer : I64 = 1 + 1
    ),
    [contextual_import_test_library()],
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
      #|          start_offset: 57,
      #|          end_offset: 62,
      #|          start_line: 3,
      #|          start_column: 24,
      #|          end_line: 3,
      #|          end_column: 29,
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
      #|            start_offset: 57,
      #|            end_offset: 62,
      #|            start_line: 3,
      #|            start_column: 24,
      #|            end_line: 3,
      #|            end_column: 29,
      #|          },
      #|        ),
      #|        message: "no visible offer matches required type `Add[I64]`",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: ["contextual arguments are inserted only from visible `offer` bindings with matching type"],
      #|    helps: ["pass the argument explicitly or add a visible `offer` with type `Add[I64]`"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|]
    ),
  )
}

///|
test "qualified import does not expose a contextual offer" {
  let result = check_sources_for_test(
    (
      #|module Main
      #|import Ops
      #|pub let answer : I64 = Ops.op_add(1, 1)
    ),
    [contextual_import_test_library()],
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
      #|          start_offset: 46,
      #|          end_offset: 62,
      #|          start_line: 3,
      #|          start_column: 24,
      #|          end_line: 3,
      #|          end_column: 40,
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
      #|            start_offset: 46,
      #|            end_offset: 62,
      #|            start_line: 3,
      #|            start_column: 24,
      #|            end_line: 3,
      #|            end_column: 40,
      #|          },
      #|        ),
      #|        message: "no visible offer matches required type `Add[I64]`",
      #|        style: Primary,
      #|      },
      #|    ],
      #|    notes: ["contextual arguments are inserted only from visible `offer` bindings with matching type"],
      #|    helps: ["pass the argument explicitly or add a visible `offer` with type `Add[I64]`"],
      #|    facts: [],
      #|    suggestions: [],
      #|  },
      #|]
    ),
  )
}

///|
test "qualified offer can be passed as an explicit contextual argument" {
  let result = check_sources_for_test(
    (
      #|module Main
      #|import Ops
      #|pub let answer : I64 = Ops.op_add(1, 1, op=Ops.i64_add_ops)
    ),
    [contextual_import_test_library()],
  )
  debug_inspect(result.diagnostics, content="[]")
  guard result.source is Some(_) else { abort("expected checked source") }
}

///|
test "selective import exposes an explicitly selected contextual offer" {
  let result = check_sources_for_test(
    (
      #|module Main
      #|import Ops.{ op_add, i64_add_ops }
      #|pub let answer : I64 = 1 + 1
    ),
    [contextual_import_test_library()],
  )
  debug_inspect(result.diagnostics, content="[]")
  guard result.source is Some(_) else { abort("expected checked source") }
}

///|
test "open import exposes contextual offers" {
  let result = check_sources_for_test(
    (
      #|module Main
      #|import Ops.*
      #|pub let answer : I64 = 1 + 1
    ),
    [contextual_import_test_library()],
  )
  debug_inspect(result.diagnostics, content="[]")
  guard result.source is Some(_) else { abort("expected checked source") }
}

///|
test "compile sources links only root reachable library modules" {
  let result = compile_sources_for_test(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : I64 = value
    ),
    [
      (
        #|module Lib
        #|pub let value : I64 = 42
      ),
      (
        #|module Extra
        #|pub let extra : (I64, I64) -> I64 = builtin("%i64_add")
        #|pub let broken : Missing = 0
      ),
    ],
  )
  debug_inspect(result.diagnostics, content="[]")
  inspect(result.externals.builtins.length(), content="0")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "compile sources lower transitive public type dependencies" {
  let result = compile_sources_for_test(
    (
      #|module Main
      #|import Facade.{ make_token, read_token }
      #|pub fn answer() -> I64 {
      #|  read_token(make_token())
      #|}
    ),
    [
      (
        #|module Types
        #|pub struct Token {
        #|  value : I64
        #|}
      ),
      (
        #|module Facade
        #|import Types.{ Token }
        #|pub fn make_token() -> Token {
        #|  Token::{ value: 42 }
        #|}
        #|pub fn read_token(token : Token) -> I64 {
        #|  token.value
        #|}
      ),
    ],
  )
  debug_inspect(result.diagnostics, content="[]")
  guard result.program is Some(program) else {
    abort("expected linked Buslane program")
  }
  inspect(
    @prettyprinter.render(@buslane.verify_program(program), width=100),
    content="verify_result {}",
  )
}

///|
test "transitive public types do not become source-visible" {
  let result = check_sources_for_test(
    (
      #|module Main
      #|import Facade.{ make_token }
      #|pub let token : Token = make_token()
    ),
    [
      (
        #|module Types
        #|pub struct Token {
        #|  value : I64
        #|}
      ),
      (
        #|module Facade
        #|import Types.{ Token }
        #|pub fn make_token() -> Token {
        #|  Token::{ value: 42 }
        #|}
      ),
    ],
  )
  debug_inspect(
    result.diagnostics.map(fn(diagnostic) { diagnostic.message }),
    content=(
      #|["cannot find type `Token`"]
    ),
  )
}

///|
test "compile sources lower transitive public effect dependencies" {
  let result = compile_sources_for_test(
    (
      #|module Main
      #|import Facade.{ action }
      #|pub fn main() -> Unit {
      #|  ()
      #|}
    ),
    [
      (
        #|module Effects
        #|pub effect Network {
        #|  receive() -> I64
        #|}
      ),
      (
        #|module Facade
        #|import Effects.{ Network }
        #|pub fn action() -> I64 ! Network {
        #|  Network::receive!()
        #|}
      ),
    ],
  )
  guard result.program is Some(program) else {
    abort("expected linked Buslane program")
  }
  inspect(
    @prettyprinter.render(@buslane.verify_program(program), width=100),
    content="verify_result {}",
  )
}

///|
test "transitive public dependencies add only required nominal imports" {
  let result = compile_modules_for_test(
    (
      #|module Main
      #|import Facade.{ make_token, read_token }
      #|pub fn answer() -> I64 {
      #|  read_token(make_token())
      #|}
    ),
    [
      (
        #|module Types
        #|pub struct Token {
        #|  value : I64
        #|}
        #|pub let unrelated : I64 = 0
      ),
      (
        #|module Facade
        #|import Types.{ Token }
        #|pub fn make_token() -> Token {
        #|  Token::{ value: 42 }
        #|}
        #|pub fn read_token(token : Token) -> I64 {
        #|  token.value
        #|}
      ),
    ],
  )
  debug_inspect(result.diagnostics, content="[]")
  guard result.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  guard @module_compile.find_compiled_module(modules.modules, "Main")
    is Some(main) else {
    abort("expected Main module")
  }
  debug_inspect(
    main.object.imports.map(fn(import_) {
      (import_.module_path_text, import_.reference, import_.name)
    }),
    content=(
      #|[
      #|  ("Types", Type({ index: 0 }), "Token"),
      #|  ("Types", FieldSelector({ index: 0 }), "Token.value"),
      #|  ("Facade", Value({ index: 1 }), "make_token"),
      #|  ("Facade", Value({ index: 2 }), "read_token"),
      #|]
    ),
  )
}

///|
test "source graph semantic catalogs do not pollute sibling interfaces" {
  let result = compile_modules_for_test(
    (
      #|module Main
      #|import Left
      #|import Right
      #|pub let answer : I64 = 42
    ),
    [
      (
        #|module Left
        #|pub struct Noise {
        #|  value : I64
        #|}
      ),
      (
        #|module Right
        #|pub struct Box {
        #|  value : I64
        #|}
      ),
    ],
  )
  guard result.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  guard @module_compile.find_compiled_module(modules.modules, "Right")
    is Some(right) else {
    abort("expected Right module")
  }
  debug_inspect(
    right.interface.type_references.map(fn(reference) {
      (reference.module_path, reference.name)
    }),
    content=(
      #|[("Right", "Box")]
    ),
  )
}

///|
test "compile modules returns separate module objects and interfaces" {
  let result = compile_modules_for_test(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : I64 = value
    ),
    [
      (
        #|module Lib
        #|pub struct Box {
        #|  value : I64
        #|}
        #|pub let value : I64 = 42
      ),
    ],
  )
  debug_inspect(result.diagnostics, content="[]")
  guard result.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  inspect(modules.root_module_path_text, content="Main")
  inspect(
    modules.modules
    .map(fn(module_) { module_.object.module_path_text })
    .join(","),
    content="Lib,Main",
  )
  guard @module_compile.find_compiled_module(modules.modules, "Lib")
    is Some(lib) else {
    abort("expected Lib module")
  }
  guard @module_compile.find_compiled_module(modules.modules, "Main")
    is Some(main) else {
    abort("expected Main module")
  }
  inspect(lib.interface.values.length(), content="1")
  inspect(lib.object.module_path_text, content="Lib")
  inspect(
    lib.object.exports.map(fn(item) { item.name }).join(","),
    content="Box,Box,Box.value,value",
  )
  inspect(
    main.object.imports
    .map(fn(item) { "\{item.module_path_text}::\{item.name}" })
    .join(","),
    content="Lib::Box,Lib::Box,Lib::Box.value,Lib::value",
  )
}

///|
test "link modules produces Buslane program from reachable module objects" {
  let compiled = compile_modules_for_test(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : I64 = value
    ),
    [
      (
        #|module Lib
        #|pub let value : I64 = 42
      ),
      (
        #|module Extra
        #|pub let extra : (I64, I64) -> I64 = builtin("%i64_add")
      ),
    ],
  )
  debug_inspect(compiled.diagnostics, content="[]")
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let linked = link_modules_for_test(modules)
  debug_inspect(linked.diagnostics, content="[]")
  guard linked.program is Some(program) else {
    abort("expected linked program")
  }
  inspect(program.module_path_texts.join(","), content="Lib,Main")
  inspect(program.externals.builtins.length(), content="0")
  inspect(
    program.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
  inspect(
    @prettyprinter.render(program.program, width=100),
    content=(
      #|buslane {
      #|  metadata {
      #|    value value#0 = "value"#0 value : I64;
      #|    value value#1 = "answer"#1 value : I64;
      #|  }
      #|  let value#0 = 42
      #|  let value#1 = value#0
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(@buslane.verify_program(program.program), width=100),
    content="verify_result {}",
  )
}

///|
test "link modules remaps effect operations through one identity" {
  let compiled = compile_modules_for_test(
    (
      #|module Main
      #|import Lib.*
      #|pub fn program() -> I64 {
      #|  handle read_int() with {
      #|    Console::read(resume) => resume(42)
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
    [
      (
        #|module Lib
        #|pub effect Console {
        #|  read() -> I64
        #|}
        #|pub fn read_int() -> I64 ! Console {
        #|  Console::read!()
        #|}
      ),
    ],
  )
  debug_inspect(compiled.diagnostics, content="[]")
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let linked = link_modules_for_test(modules)
  debug_inspect(linked.diagnostics, content="[]")
  guard linked.program is Some(program) else {
    abort("expected linked program")
  }
  assert_eq(program.program.metadata.effects.length(), 1)
  assert_eq(program.program.metadata.operations.length(), 1)
  inspect(
    @prettyprinter.render(@buslane.verify_program(program.program), width=100),
    content="verify_result {}",
  )
}

///|
test "link modules remaps data constructors through one identity" {
  let compiled = compile_modules_for_test(
    (
      #|module Main
      #|import Lib.*
      #|pub let main_flag : Flag = flag
    ),
    [
      (
        #|module Lib
        #|pub enum Flag {
        #|  on()
        #|}
        #|pub let flag : Flag = Flag::on()
      ),
    ],
  )
  debug_inspect(compiled.diagnostics, content="[]")
  guard compiled.modules is Some(modules) else {
    abort("expected compiled modules")
  }
  let linked = link_modules_for_test(modules)
  debug_inspect(linked.diagnostics, content="[]")
  guard linked.program is Some(program) else {
    abort("expected linked program")
  }
  assert_eq(program.program.metadata.types.length(), 1)
  assert_eq(program.program.metadata.data_constructors.length(), 1)
  inspect(
    @prettyprinter.render(@buslane.verify_program(program.program), width=100),
    content="verify_result {}",
  )
}

///|
test "check sources does not expose private imported values" {
  let result = check_sources_for_test(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : I64 = value
    ),
    [
      (
        #|module Lib
        #|let value : I64 = 42
      ),
    ],
  )
  debug_inspect(
    result.diagnostics.map(fn(diagnostic) { diagnostic.message }),
    content=(
      #|["cannot find value `value`"]
    ),
  )
}

///|
test "check sources does not expose private imported types" {
  let result = check_sources_for_test(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : Hidden = Hidden::{ value: 42 }
    ),
    [
      (
        #|module Lib
        #|struct Hidden {
        #|  value : I64
        #|}
      ),
    ],
  )
  debug_inspect(
    result.diagnostics.map(fn(diagnostic) { diagnostic.message }),
    content=(
      #|["cannot find type `Hidden`"]
    ),
  )
}

///|
test "check sources rejects private nominal type escape through public function" {
  let result = check_sources_for_test(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : I64 = leak().value
    ),
    [
      (
        #|module Lib
        #|struct Hidden {
        #|  value : I64
        #|}
        #|pub fn leak() -> Hidden {
        #|  Hidden::{ value: 42 }
        #|}
      ),
    ],
  )
  debug_inspect(
    result.diagnostics.map(fn(diagnostic) {
      (diagnostic.message, diagnostic.span)
    }),
    content=(
      #|[
      #|  (
      #|    "private type `Hidden` in public interface",
      #|    Some(
      #|      Source(
      #|        source_id="<library:0>",
      #|        span={
      #|          start_offset: 60,
      #|          end_offset: 66,
      #|          start_line: 5,
      #|          start_column: 18,
      #|          end_line: 5,
      #|          end_column: 24,
      #|        },
      #|      ),
      #|    ),
      #|  ),
      #|]
    ),
  )
}

///|
test "check source rejects private nominal type escape through public let" {
  let result = check_source_for_test(
    (
      #|module Test
      #|struct Hidden {
      #|  value : I64
      #|}
      #|pub let answer : Hidden = Hidden::{ value: 42 }
    ),
  )
  debug_inspect(
    result.diagnostics.map(fn(diagnostic) { diagnostic.message }),
    content=(
      #|["private type `Hidden` in public interface"]
    ),
  )
}

///|
test "check source rejects private nominal type escape through public struct field" {
  let result = check_source_for_test(
    (
      #|module Test
      #|struct Hidden {
      #|  value : I64
      #|}
      #|pub struct Box {
      #|  hidden : Hidden
      #|}
    ),
  )
  debug_inspect(
    result.diagnostics.map(fn(diagnostic) { diagnostic.message }),
    content=(
      #|["private type `Hidden` in public interface"]
    ),
  )
}

///|
test "check source rejects private nominal type escape through public enum payload" {
  let result = check_source_for_test(
    (
      #|module Test
      #|struct Hidden {
      #|  value : I64
      #|}
      #|pub enum Box {
      #|  boxed(Hidden)
      #|}
    ),
  )
  debug_inspect(
    result.diagnostics.map(fn(diagnostic) { diagnostic.message }),
    content=(
      #|["private type `Hidden` in public interface"]
    ),
  )
}

///|
test "check source rejects private nominal type escape through public type alias" {
  let result = check_source_for_test(
    (
      #|module Test
      #|struct Hidden {
      #|  value : I64
      #|}
      #|pub type Exposed = Hidden
    ),
  )
  debug_inspect(
    result.diagnostics.map(fn(diagnostic) { diagnostic.message }),
    content=(
      #|["private type `Hidden` in public interface"]
    ),
  )
}

///|
test "check sources exposes public imported nominal shape through public value" {
  let result = check_sources_for_test(
    (
      #|module Main
      #|import Lib.*
      #|pub let answer : I64 = point().x
    ),
    [
      (
        #|module Lib
        #|pub struct Point {
        #|  x : I64
        #|}
        #|pub fn point() -> Point {
        #|  Point::{ x: 42 }
        #|}
      ),
    ],
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "check sources rejects missing import" {
  let result = check_sources_for_test(
    (
      #|module Main
      #|import Missing
      #|pub let answer : I64 = 42
    ),
    [],
  )
  debug_inspect(
    result.diagnostics.map(fn(diagnostic) { diagnostic.message }),
    content=(
      #|["missing imported module `Missing`"]
    ),
  )
}

///|
test "check sources resolves module qualified value access" {
  let result = compile_sources_for_test(
    (
      #|module Main
      #|import Core.I64
      #|pub let answer : I64 = Core.I64.id(42)
    ),
    [
      (
        #|module Core.I64
        #|pub fn id(value : I64) -> I64 {
        #|  value
        #|}
      ),
    ],
  )
  debug_inspect(result.diagnostics, content="[]")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "check sources does not import child module through parent module" {
  let result = check_sources_for_test(
    (
      #|module Main
      #|import Core
      #|pub let answer : I64 = Core.I64.id(42)
    ),
    [
      (
        #|module Core
        #|pub let marker : I64 = 0
      ),
      (
        #|module Core.I64
        #|pub fn id(value : I64) -> I64 {
        #|  value
        #|}
      ),
    ],
  )
  debug_inspect(
    result.diagnostics.map(fn(diagnostic) { diagnostic.message }),
    content=(
      #|["cannot find value `Core.I64.id`"]
    ),
  )
}

///|
test "check sources resolves module qualified nominal type access" {
  let result = compile_sources_for_test(
    (
      #|module Main
      #|import Lib
      #|pub let answer : Lib.Box = Lib.Box::{ value: 42 }
    ),
    [
      (
        #|module Lib
        #|pub struct Box {
        #|  value : I64
        #|}
      ),
    ],
  )
  debug_inspect(result.diagnostics, content="[]")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "check sources resolves module qualified type alias access" {
  let result = compile_sources_for_test(
    (
      #|module Main
      #|import Lib
      #|pub let answer : Lib.Answer = 42
    ),
    [
      (
        #|module Lib
        #|pub type Answer = I64
      ),
    ],
  )
  debug_inspect(result.diagnostics, content="[]")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "check sources preserves imported type alias owner identity" {
  let result = compile_sources_for_test(
    (
      #|module Main
      #|import AliasB.{ X }
      #|pub let value : X = true
    ),
    [
      (
        #|module AliasA
        #|pub type X = I64
        #|pub let marker : I64 = 0
      ),
      (
        #|module AliasB
        #|import AliasA.{ marker }
        #|pub type X = Bool
        #|pub let copied : I64 = marker
      ),
    ],
  )
  debug_inspect(result.diagnostics, content="[]")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="value",
  )
}

///|
test "check sources rejects values against the selected imported alias" {
  let result = check_sources_for_test(
    (
      #|module Main
      #|import AliasB.{ X }
      #|pub let value : X = 1
    ),
    [
      (
        #|module AliasA
        #|pub type X = I64
        #|pub let marker : I64 = 0
      ),
      (
        #|module AliasB
        #|import AliasA.{ marker }
        #|pub type X = Bool
        #|pub let copied : I64 = marker
      ),
    ],
  )
  debug_inspect(
    result.diagnostics.map(fn(diagnostic) { diagnostic.message }),
    content=(
      #|["type mismatch"]
    ),
  )
}

///|
test "check sources resolves imported aliases in explicit generic arguments" {
  let result = compile_sources_for_test(
    (
      #|module Main
      #|import AliasLib.{ Number }
      #|fn[A] identity(value : A) -> A {
      #|  value
      #|}
      #|pub fn use() -> Number {
      #|  identity[Number](1)
      #|}
    ),
    [
      (
        #|module AliasLib
        #|pub type Number = I64
      ),
    ],
  )
  debug_inspect(result.diagnostics, content="[]")
  inspect(result.entries.map(fn(entry) { entry.name }).join(","), content="use")
}

///|
test "check sources preserves imported effect alias owner identity" {
  let result = compile_sources_for_test(
    (
      #|module Main
      #|import AliasB.{ Actions, run }
      #|pub fn use() -> Unit ! Actions {
      #|  run()
      #|}
    ),
    [
      (
        #|module AliasA
        #|pub effect First {
        #|  fire() -> Unit
        #|}
        #|pub type Actions : Effect = { First }
        #|pub let marker : I64 = 0
      ),
      (
        #|module AliasB
        #|import AliasA.{ marker }
        #|pub effect Second {
        #|  fire() -> Unit
        #|}
        #|pub type Actions : Effect = { Second }
        #|pub fn run() -> Unit ! Actions {
        #|  let _marker : I64 = marker
        #|  Second::fire!()
        #|}
      ),
    ],
  )
  debug_inspect(result.diagnostics, content="[]")
  inspect(result.entries.map(fn(entry) { entry.name }).join(","), content="use")
}

///|
test "check sources resolves imported effect aliases in explicit arguments" {
  let result = compile_sources_for_test(
    (
      #|module Main
      #|import AliasLib.{ ReadOnly, callback }
      #|fn[E : Effect] consume(callback : () -> I64 ! E) -> I64 ! E {
      #|  callback()
      #|}
      #|pub fn use() -> I64 ! ReadOnly {
      #|  consume[ReadOnly](callback)
      #|}
    ),
    [
      (
        #|module AliasLib
        #|pub effect Read {
        #|  read() -> I64
        #|}
        #|pub type ReadOnly : Effect = { Read }
        #|pub fn callback() -> I64 ! ReadOnly {
        #|  Read::read!()
        #|}
      ),
    ],
  )
  debug_inspect(result.diagnostics, content="[]")
  inspect(result.entries.map(fn(entry) { entry.name }).join(","), content="use")
}

///|
test "check sources resolves module qualified variant expressions and patterns" {
  let result = compile_sources_for_test(
    (
      #|module Main
      #|import Lib
      #|pub let answer : I64 = match Lib.Option::some(42) {
      #|  Lib.Option::some(value) => value
      #|  Lib.Option::none() => 0
      #|}
    ),
    [
      (
        #|module Lib
        #|pub enum Option {
        #|  some(I64)
        #|  none()
        #|}
      ),
    ],
  )
  debug_inspect(result.diagnostics, content="[]")
  inspect(
    result.entries.map(fn(entry) { entry.name }).join(","),
    content="answer",
  )
}

///|
test "check sources does not import child module qualified type through parent module" {
  let result = check_sources_for_test(
    (
      #|module Main
      #|import Core
      #|pub fn consume(value : Core.I64.Box) -> I64 {
      #|  0
      #|}
    ),
    [
      (
        #|module Core
        #|pub let marker : I64 = 0
      ),
      (
        #|module Core.I64
        #|pub struct Box {
        #|  value : I64
        #|}
      ),
    ],
  )
  debug_inspect(
    result.diagnostics.map(fn(diagnostic) { diagnostic.message }),
    content=(
      #|["cannot find type `Core.I64.Box`"]
    ),
  )
}

///|
test "check sources rejects ambiguous module qualified field chain" {
  let result = check_sources_for_test(
    (
      #|module Main
      #|import core.int
      #|struct AddField {
      #|  add : I64
      #|}
      #|struct CoreBox {
      #|  int : AddField
      #|}
      #|let core : CoreBox = CoreBox::{ int: AddField::{ add: 1 } }
      #|pub let answer : I64 = core.int.add
    ),
    [
      (
        #|module core.int
        #|pub let add : I64 = 42
      ),
    ],
  )
  debug_inspect(
    result.diagnostics.map(fn(diagnostic) { diagnostic.message }),
    content=(
      #|["ambiguous module-qualified value `core.int.add`"]
    ),
  )
}

///|
test "check sources rejects duplicate module input" {
  let result = check_sources_for_test(
    (
      #|module Main
      #|pub let answer : I64 = 42
    ),
    [
      (
        #|module Main
        #|pub let value : I64 = 1
      ),
    ],
  )
  debug_inspect(
    result.diagnostics.map(fn(diagnostic) { diagnostic.message }),
    content=(
      #|["duplicate module input `Main`"]
    ),
  )
}

///|
test "import reachable source inputs ignore unrelated parse diagnostics" {
  let result = @module_frontend.import_reachable_source_inputs(
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
          #|pub let value : I64 = 42
        ),
      },
      {
        source_id: "file:///Unrelated.lane",
        text: (
          #|module Unrelated
          #|pub let broken : =
        ),
      },
    ],
  )
  match result {
    Ok(inputs) =>
      inspect(
        inputs.map(fn(input) { input.source_id }).join(","),
        content="file:///Main.lane,file:///Lib.lane",
      )
    Err(diagnostics) => {
      inspect(diagnostics.map(fn(diagnostic) { diagnostic.message }).join("\n"))
      fail("expected unrelated parse diagnostics to be ignored")
    }
  }
}

///|
test "check sources ignores unimported library errors" {
  let result = check_sources_for_test(
    (
      #|module Main
      #|pub let answer : I64 = 42
    ),
    [
      (
        #|module Extra
        #|pub let extra : I64 = missing
      ),
    ],
  )
  debug_inspect(
    (result.source is Some(_), result.diagnostics),
    content="(true, [])",
  )
}

///|
test "check sources ignores unimported library import cycles" {
  let result = check_sources_for_test(
    (
      #|module Main
      #|pub let answer : I64 = 42
    ),
    [
      (
        #|module ExtraA
        #|import ExtraB
        #|pub let value : I64 = 1
      ),
      (
        #|module ExtraB
        #|import ExtraA
        #|pub let value : I64 = 2
      ),
    ],
  )
  debug_inspect(
    (result.source is Some(_), result.diagnostics),
    content="(true, [])",
  )
}

///|
test "check sources rejects import cycle" {
  let result = check_sources_for_test(
    (
      #|module Main
      #|import Lib
      #|pub let answer : I64 = 42
    ),
    [
      (
        #|module Lib
        #|import Main
        #|pub let value : I64 = 1
      ),
    ],
  )
  debug_inspect(
    result.diagnostics.map(fn(diagnostic) { diagnostic.message }),
    content=(
      #|["import cycle involving `Main`"]
    ),
  )
}
