///|
test "selective public import works through qualified facade access" {
  let outcome = compile(
    test_compilation_request(
      (
        #|module Main
        #|import Facade
        #|pub fn answer(box : Facade.Box) -> Facade.Count {
        #|  let _base = Facade.base
        #|  box.value
        #|}
      ),
      [
        (
          #|module Provider
          #|pub struct Box {
          #|  value : I64
          #|}
          #|pub type Count = I64
          #|pub let base : I64 = 40
        ),
        (
          #|module Facade
          #|pub import Provider.{ Box, Count, base }
        ),
      ],
    ),
  )
  guard outcome is Succeeded(_, warnings) else {
    abort("expected re-exported provider references to link")
  }
  assert_eq(warnings.diagnostics(), [])
}

///|
test "selective public import works through a second selective import" {
  let diagnostics = successful_compile_modules_diagnostics(
    (
      #|module Main
      #|import Facade.{ Box, Count, base }
      #|pub fn answer(box : Box) -> Count {
      #|  let _base = base
      #|  box.value
      #|}
    ),
    [
      (
        #|module Provider
        #|pub struct Box {
        #|  value : I64
        #|}
        #|pub type Count = I64
        #|pub let base : I64 = 40
      ),
      (
        #|module Facade
        #|pub import Provider.{ Box, Count, base }
      ),
    ],
  )
  assert_eq(diagnostics, [])
}

///|
test "selective public import works through a downstream open import" {
  let diagnostics = successful_compile_modules_diagnostics(
    (
      #|module Main
      #|import Facade.*
      #|pub let answer : I64 = base
    ),
    [
      (
        #|module Provider
        #|pub let base : I64 = 42
      ),
      (
        #|module Facade
        #|pub import Provider.{ base }
      ),
    ],
  )
  assert_eq(diagnostics, [])
}

///|
test "selective public import preserves enum and effect surfaces" {
  let diagnostics = successful_compile_modules_diagnostics(
    (
      #|module Main
      #|import Facade
      #|pub fn choice() -> Facade.Choice {
      #|  Facade.Choice::yes()
      #|}
      #|pub fn ping() -> Unit ! Facade.Ping {
      #|  Facade.Ping::ping!()
      #|}
    ),
    [
      (
        #|module Provider
        #|pub enum Choice {
        #|  yes()
        #|  no()
        #|}
        #|pub effect Ping {
        #|  ping() -> Unit
        #|}
      ),
      (
        #|module Facade
        #|pub import Provider.{ Choice, Ping }
      ),
    ],
  )
  assert_eq(diagnostics, [])
}

///|
test "public export target dependencies enter the interface closure" {
  let diagnostics = successful_compile_modules_diagnostics(
    (
      #|module Main
      #|import Facade
      #|pub let answer : I64 = (Facade.token).value
    ),
    [
      (
        #|module Dependency
        #|pub struct Token {
        #|  value : I64
        #|}
      ),
      (
        #|module Provider
        #|import Dependency
        #|pub let token : Dependency.Token = Dependency.Token::{ value: 42 }
      ),
      (
        #|module Facade
        #|pub import Provider.{ token }
      ),
    ],
  )
  assert_eq(diagnostics, [])
}

///|
test "transitive public imports remain flattened to the provider" {
  let outcome = compile(
    test_compilation_request(
      (
        #|module Main
        #|import Facade
        #|pub let answer : I64 = Facade.value
      ),
      [
        (
          #|module Provider
          #|pub let value : I64 = 42
        ),
        (
          #|module Middle
          #|pub import Provider.{ value }
        ),
        (
          #|module Facade
          #|pub import Middle.{ value }
        ),
      ],
    ),
  )
  guard outcome is Succeeded(_, warnings) else {
    abort("expected a transitive public import to link")
  }
  assert_eq(warnings.diagnostics(), [])
}

///|
test "direct and facade paths share one nominal identity" {
  let diagnostics = successful_compile_modules_diagnostics(
    (
      #|module Main
      #|import Provider
      #|import Facade
      #|pub fn same(box : Provider.Box) -> Facade.Box {
      #|  box
      #|}
    ),
    [
      (
        #|module Provider
        #|pub struct Box {
        #|  value : I64
        #|}
      ),
      (
        #|module Facade
        #|pub import Provider.{ Box }
      ),
    ],
  )
  assert_eq(diagnostics, [])
}

///|
test "re-exported offers preserve ordinary selective activation" {
  let diagnostics = successful_compile_modules_diagnostics(
    (
      #|module Main
      #|import Facade.{ Witness, witness, use }
      #|pub let answer : I64 = use()
    ),
    [
      (
        #|module Provider
        #|pub struct Witness {
        #|  value : I64
        #|}
        #|pub offer witness : Witness = Witness::{ value: 42 }
        #|pub fn use(auto evidence : Witness) -> I64 {
        #|  evidence.value
        #|}
      ),
      (
        #|module Facade
        #|pub import Provider.{ Witness, witness, use }
      ),
    ],
  )
  assert_eq(diagnostics, [])
}

///|
test "one public import item may export distinct Lane namespaces" {
  let diagnostics = successful_compile_modules_diagnostics(
    (
      #|module Main
      #|import Facade.{ Item }
      #|pub fn read(item : Item) -> I64 {
      #|  let _number : I64 = Item
      #|  item.value
      #|}
    ),
    [
      (
        #|module Provider
        #|pub struct Item {
        #|  value : I64
        #|}
        #|pub let Item : I64 = 42
      ),
      (
        #|module Facade
        #|pub import Provider.{ Item }
      ),
    ],
  )
  assert_eq(diagnostics, [])
}

///|
test "public import rejects duplicate export keys" {
  let outcome = check(
    test_compilation_request(
      (
        #|module Facade
        #|pub import Provider.{ value }
        #|pub import Provider.{ value }
      ),
      [
        (
          #|module Provider
          #|pub let value : I64 = 42
        ),
      ],
    ),
  )
  guard outcome is Failed(failure) else {
    abort("expected duplicate public exports to fail")
  }
  assert_eq(
    failure
    .diagnostics()
    .map(fn(diagnostic) { (diagnostic.code, diagnostic.message) }),
    [
      (Some("E2005"), "conflicting top-level value `value`"),
      (Some("E2010"), "conflicting public export `value`"),
    ],
  )
}

///|
test "public import cannot expose a private provider declaration" {
  let outcome = check(
    test_compilation_request(
      (
        #|module Facade
        #|pub import Provider.{ secret }
      ),
      [
        (
          #|module Provider
          #|let secret : I64 = 42
        ),
      ],
    ),
  )
  guard outcome is Failed(failure) else {
    abort("expected a private declaration re-export to fail")
  }
  assert_eq(
    failure
    .diagnostics()
    .map(fn(diagnostic) { (diagnostic.code, diagnostic.message) }),
    [(Some("E2009"), "cannot import `secret` from `Provider`")],
  )
}

///|
test "public import is limited to selective syntax" {
  for
    source in [
      "module Facade\npub import Provider", "module Facade\npub import Provider.*",
      "module Facade\npub import Provider as P",
    ] {
    guard check_source(source) is Failed(_) else {
      abort("expected non-selective public import syntax to fail")
    }
  }
}
