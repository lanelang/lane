///|
test "selective import may rename a value" {
  let diagnostics = successful_compile_modules_diagnostics(
    (
      #|module Main
      #|import Provider.{ value as answer }
      #|pub let result : I64 = answer
    ),
    [
      (
        #|module Provider
        #|pub let value : I64 = 42
      ),
    ],
  )
  assert_eq(diagnostics, [])
}

///|
test "public import aliases preserve provider identity across namespaces" {
  let diagnostics = successful_compile_modules_diagnostics(
    (
      #|module Main
      #|import Facade.{ Renamed as Local }
      #|pub let item : Local = Local::{ value: Local }
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
        #|pub import Provider.{ Item as Renamed }
      ),
    ],
  )
  assert_eq(diagnostics, [])
}

///|
test "aliased nominal effects and offers keep provider-owned semantics" {
  let diagnostics = successful_compile_modules_diagnostics(
    (
      #|module Main
      #|import Facade.{ Decision, Signal, Evidence, evidence, use }
      #|pub fn choose() -> Decision {
      #|  yes(42)
      #|}
      #|pub fn emit() -> Unit ! Signal {
      #|  Signal::ping!()
      #|}
      #|pub let answer : I64 = use()
    ),
    [
      (
        #|module Provider
        #|pub enum Choice {
        #|  yes(I64)
        #|  no()
        #|}
        #|pub effect Ping {
        #|  ping() -> Unit
        #|}
        #|pub struct Witness {
        #|  value : I64
        #|}
        #|pub offer witness : Witness = Witness::{ value: 42 }
        #|pub fn use(auto item : Witness) -> I64 {
        #|  item.value
        #|}
      ),
      (
        #|module Facade
        #|pub import Provider.{
        #|  Choice as Decision,
        #|  Ping as Signal,
        #|  Witness as Evidence,
        #|  witness as evidence,
        #|  use
        #|}
      ),
    ],
  )
  assert_eq(diagnostics, [])
}

///|
test "qualified facade access uses the public alias" {
  let diagnostics = successful_compile_modules_diagnostics(
    (
      #|module Main
      #|import Facade
      #|pub let item : Facade.Container = Facade.Container::{ value: Facade.answer }
    ),
    [
      (
        #|module Provider
        #|pub struct Box {
        #|  value : I64
        #|}
        #|pub let value : I64 = 42
      ),
      (
        #|module Facade
        #|pub import Provider.{ Box as Container, value as answer }
      ),
    ],
  )
  assert_eq(diagnostics, [])
}

///|
test "open facade imports expose the public alias" {
  let diagnostics = successful_compile_modules_diagnostics(
    (
      #|module Main
      #|import Facade.*
      #|pub let result : I64 = answer
    ),
    [
      (
        #|module Provider
        #|pub let value : I64 = 42
      ),
      (
        #|module Facade
        #|pub import Provider.{ value as answer }
      ),
    ],
  )
  assert_eq(diagnostics, [])
}

///|
test "import item alias conflicts are reported under the local name" {
  let diagnostics = check(
    test_compilation_request(
      (
        #|module Main
        #|import Provider.{ value as answer }
        #|pub let answer : I64 = 0
      ),
      [
        (
          #|module Provider
          #|pub let value : I64 = 42
        ),
      ],
    ),
  ).diagnostics()
  assert_eq(
    diagnostics.map(fn(diagnostic) { (diagnostic.code, diagnostic.message) }),
    [(Some("E2005"), "conflicting top-level value `answer`")],
  )
}
