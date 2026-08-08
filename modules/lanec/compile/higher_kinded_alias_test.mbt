///|
/// Contextual checking binds the higher-kinded parameter `F` before checking a
/// member whose template contains `F[..]`. Inference must apply that existing
/// binding, head-beta-reduce the result, and match what it denotes. It must not
/// decompose `F[..]` to infer a second binding for `F`. This is a local
/// inference rule; definitional equality remains beta-only.
fn higher_kinded_alias_source(declarations : String) -> String {
  (
    #|module Test
    #|pub struct Box[A] {
    #|  value : A
    #|}
    #|pub type MyBox[A] = Box[A]
    #|
  ) +
  declarations
}

///|
test "a higher-kinded struct instantiated with an alias checks" {
  let source = higher_kinded_alias_source(
    (
      #|pub struct Wrapper[F : [Type] -> Type] {
      #|  held : F[I64]
      #|}
      #|pub let wrapped : Wrapper[MyBox] = Wrapper::{ held: Box::{ value: 5 } }
    ),
  )
  guard check_source(source) is Succeeded(_, _) else {
    abort("expected the aliased struct instantiation to check")
  }
}

///|
test "a higher-kinded enum instantiated with an alias checks" {
  let source = higher_kinded_alias_source(
    (
      #|pub enum Holder[F : [Type] -> Type] {
      #|  hold(F[I64])
      #|}
      #|pub let held : Holder[MyBox] = Holder::hold(Box::{ value: 5 })
    ),
  )
  guard check_source(source) is Succeeded(_, _) else {
    abort("expected the aliased enum instantiation to check")
  }
}

///|
test "an explicit generic application with an alias still checks" {
  let source = higher_kinded_alias_source(
    (
      #|pub fn[F : [Type] -> Type] take(_held : F[I64]) -> I64 {
      #|  42
      #|}
      #|pub let taken : I64 = take[MyBox](Box::{ value: 5 })
    ),
  )
  guard check_source(source) is Succeeded(_, _) else {
    abort("expected the explicit generic application to check")
  }
}

///|
/// The discriminating case: `Swap` reorders its parameters rather than
/// eta-expanding `Pair`, so eta equality cannot explain why this checks. The
/// conflicting second binding is collected before final type equality, so
/// globally normalizing compared types cannot repair it either. Success
/// requires the local rule above: honor the existing `F` binding and
/// head-beta-reduce its complete application.
test "a reordering alias instantiates a higher-kinded parameter" {
  let source =
    #|module Test
    #|pub struct Pair[A, B] {
    #|  first : A
    #|  second : B
    #|}
    #|pub type Swap[A, B] = Pair[B, A]
    #|pub struct Wrapper[F : [Type, Type] -> Type] {
    #|  held : F[I64, Bool]
    #|}
    #|pub let held : Wrapper[Swap] = Wrapper::{
    #|  held: Pair::{ first: true, second: 5 },
    #|}
  guard check_source(source) is Succeeded(_, _) else {
    abort("expected the reordering alias to instantiate the parameter")
  }
}

///|
test "a callable returned through a higher-kinded field can be called" {
  let source =
    #|module Test
    #|pub type Callable = type[T] => (T) -> T
    #|pub struct Recursive[C : [Type] -> Type] {
    #|  defer : [T](() -> C[T]) -> C[T]
    #|}
    #|pub let recursive : Recursive[Callable] = Recursive::{
    #|  defer: fn[T](get_value) {
    #|    fn(value : T) {
    #|      get_value()(value)
    #|    }
    #|  },
    #|}
  guard check_source(source) is Succeeded(_, _) else {
    abort("expected the head-normalized callable result to check")
  }
}

///|
test "a function literal uses a head-normalized higher-kinded expectation" {
  let source =
    #|module Test
    #|pub type Callable = type[T] => (T) -> T
    #|pub struct Holder[C : [Type] -> Type] {
    #|  value : C[I64]
    #|}
    #|pub let holder : Holder[Callable] = Holder::{
    #|  value: fn(value) { value },
    #|}
  guard check_source(source) is Succeeded(_, _) else {
    abort("expected the head-normalized function expectation to check")
  }
}

///|
fn capability_lifting_source(result : String) -> String {
  (
    #|module Test
    #|pub enum Maybe[A] {
    #|  none()
    #|  some(A)
    #|}
    #|pub struct Nominal[A] {
    #|  value : A
    #|}
    #|pub type Transparent[A] = (A) -> String
    #|pub fn[Evid : [Type] -> Type, T1 : [Type] -> Type, T2] lift(
    #|  auto provider : [T](Evid[T]) -> Evid[T1[T]],
    #|  auto base : Evid[T2]
    #|) -> Evid[T1[T2]] {
    #|  provider(base)
    #|}
    #|pub offer nominal_base : Nominal[I64] = Nominal::{ value: 42 }
    #|pub offer fn[A] nominal_maybe(
    #|  auto base : Nominal[A]
    #|) -> Nominal[Maybe[A]] {
    #|  Nominal::{ value: Maybe::some(base.value) }
    #|}
    #|pub offer transparent_base : Transparent[I64] = fn(_value) { "base" }
    #|pub offer fn[A] transparent_maybe(
    #|  auto _base : Transparent[A]
    #|) -> Transparent[Maybe[A]] {
    #|  fn(_value) { "lifted" }
    #|}
    #|
  ) +
  result
}

///|
test "capability lifting infers nominal heads and accepts explicit transparent heads" {
  let source = capability_lifting_source(
    (
      #|pub let nominal : Nominal[Maybe[I64]] = lift()
      #|pub let transparent : Transparent[Maybe[I64]] =
      #|  lift[Transparent, Maybe, I64]()
    ),
  )
  let result = check_source(source)
  guard result is Succeeded(_, _) else {
    abort("unexpected diagnostics: \{Repr(result.diagnostics())}")
  }
}

///|
test "transparent capability heads are not synthesized by higher-order inference" {
  let diagnostic = single_check_diagnostic(
    capability_lifting_source(
      (
        #|pub let transparent : Transparent[Maybe[I64]] = lift()
      ),
    ),
  )
  assert_diagnostic_headline(
    diagnostic, "E3010", "cannot infer generic arguments for this call",
  )
}
