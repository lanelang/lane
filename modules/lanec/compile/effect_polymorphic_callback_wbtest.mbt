///|
test "compiler adapts pure callback passed through effect-polymorphic field" {
  ignore(
    compile_test_loisvm_image(
      (
        #|module Test
        #|
        #|pub struct Apply {
        #|  call : [T, Eff : Effect](T, (T) -> T ! Eff) -> T ! Eff
        #|}
        #|
        #|fn[T, Eff : Effect] apply_call(
        #|  value : T,
        #|  callback : (T) -> T ! Eff
        #|) -> T ! Eff {
        #|  callback(value)
        #|}
        #|
        #|fn increment(value : I64) -> I64 {
        #|  value
        #|}
        #|
        #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe")
        #|
        #|pub fn answer() -> Unit ! Io {
        #|  let apply = Apply::{ call: apply_call }
        #|  observe(apply.call[I64, {}](41, increment))
        #|}
      ),
    ),
  )
}

///|
test "compiler preserves effectful callback passed through effect-polymorphic field" {
  ignore(
    compile_test_loisvm_image(
      (
        #|module Test
        #|
        #|pub struct Apply {
        #|  call : [T, Eff : Effect](T, (T) -> T ! Eff) -> T ! Eff
        #|}
        #|
        #|fn[T, Eff : Effect] apply_call(
        #|  value : T,
        #|  callback : (T) -> T ! Eff
        #|) -> T ! Eff {
        #|  callback(value)
        #|}
        #|
        #|effect Tick {
        #|  tick(I64) -> I64
        #|}
        #|
        #|fn ticked(value : I64) -> I64 ! Tick {
        #|  Tick::tick!(value)
        #|}
        #|
        #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe")
        #|
        #|pub fn answer() -> Unit ! Io {
        #|  let apply = Apply::{ call: apply_call }
        #|  let value = handle apply.call[I64, { Tick }](41, ticked) with {
        #|    Tick::tick(value, resume) => resume(value)
        #|  } final value {
        #|    value
        #|  }
        #|  observe(value)
        #|}
      ),
    ),
  )
}

///|
test "compiler adapts pure callback passed through higher-kinded mappable field" {
  ignore(
    compile_test_loisvm_image(
      (
        #|module Test
        #|
        #|enum Box[T] {
        #|  box(T)
        #|}
        #|
        #|struct Mappable[M : [Type] -> Type] {
        #|  map : [T, R, Eff : Effect](M[T], (T) -> R ! Eff) -> M[R] ! Eff
        #|}
        #|
        #|fn[T, R, Eff : Effect] box_map(
        #|  box : Box[T],
        #|  callback : (T) -> R ! Eff
        #|) -> Box[R] ! Eff {
        #|  match box {
        #|    Box::box(value) => Box::box(callback(value))
        #|  }
        #|}
        #|
        #|fn increment(value : I64) -> I64 {
        #|  value
        #|}
        #|
        #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe")
        #|
        #|pub fn answer() -> Unit ! Io {
        #|  let mappable : Mappable[Box] = Mappable::{ map: box_map }
        #|  let mapped = mappable.map[I64, I64, {}](Box::box(41), increment)
        #|  match mapped {
        #|    Box::box(value) => observe(value)
        #|  }
        #|}
      ),
    ),
  )
}
