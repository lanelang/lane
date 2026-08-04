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
