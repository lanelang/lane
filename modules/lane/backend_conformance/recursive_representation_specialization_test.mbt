///|
test "finite recursive effect-polymorphic callables execute on every backend" {
  let actual = execute_compiler_test_matrix(
    (
      #|module Main
      #|
      #|effect Assert {
      #|  assert(Bool) -> Unit
      #|}
      #|
      #|let add : (I64, I64) -> I64 = builtin("%i64_add")
      #|let subtract : (I64, I64) -> I64 = builtin("%i64_sub")
      #|let equal : (I64, I64) -> Bool = builtin("%i64_equal")
      #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe_i64")
      #|
      #|fn[R, E : Effect] fold(
      #|  remaining : I64,
      #|  accumulator : R,
      #|  step : (R, I64) -> R ! E
      #|) -> R ! E {
      #|  if equal(remaining, 0) {
      #|    accumulator
      #|  } else {
      #|    fold(subtract(remaining, 1), step(accumulator, remaining), step)
      #|  }
      #|}
      #|
      #|fn test_fold() -> Unit ! Assert {
      #|  let result = fold(
      #|    3,
      #|    0,
      #|    fn(accumulator, value) {
      #|      Assert::assert!(true)
      #|      add(accumulator, value)
      #|    }
      #|  )
      #|  Assert::assert!(equal(result, 6))
      #|}
      #|
      #|fn execute_test(action : () -> Unit ! Assert) -> Bool {
      #|  handle action() with {
      #|    Assert::assert(condition, resume) => {
      #|      let rest = resume(())
      #|      if condition { rest } else { false }
      #|    }
      #|  } final _value {
      #|    true
      #|  }
      #|}
      #|
      #|pub fn main() -> Unit ! Io {
      #|  observe(if execute_test(test_fold) { 1 } else { 0 })
      #|}
    ),
  )
  assert_eq(actual, expected_i64_execution_matrix(1L, 0))
}

///|
test "global callable crosses a recursive generic boundary on every backend" {
  let actual = execute_compiler_test_matrix(
    (
      #|module Main
      #|
      #|effect Assert {
      #|  assert(Bool) -> Unit
      #|}
      #|
      #|let add : (I64, I64) -> I64 = builtin("%i64_add")
      #|let subtract : (I64, I64) -> I64 = builtin("%i64_sub")
      #|let equal : (I64, I64) -> Bool = builtin("%i64_equal")
      #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe_i64")
      #|
      #|fn[R, E : Effect] fold(
      #|  remaining : I64,
      #|  accumulator : R,
      #|  step : (R, I64) -> R ! E
      #|) -> R ! E {
      #|  if equal(remaining, 0) {
      #|    accumulator
      #|  } else {
      #|    fold(subtract(remaining, 1), step(accumulator, remaining), step)
      #|  }
      #|}
      #|
      #|fn add_step(accumulator : I64, value : I64) -> I64 ! Assert {
      #|  Assert::assert!(true)
      #|  add(accumulator, value)
      #|}
      #|
      #|fn test_fold() -> Unit ! Assert {
      #|  Assert::assert!(equal(fold(3, 0, add_step), 6))
      #|}
      #|
      #|fn execute_test(action : () -> Unit ! Assert) -> Bool {
      #|  handle action() with {
      #|    Assert::assert(condition, resume) => {
      #|      let rest = resume(())
      #|      if condition { rest } else { false }
      #|    }
      #|  } final _value {
      #|    true
      #|  }
      #|}
      #|
      #|pub fn main() -> Unit ! Io {
      #|  observe(if execute_test(test_fold) { 1 } else { 0 })
      #|}
    ),
  )
  assert_eq(actual, expected_i64_execution_matrix(1L, 0))
}

///|
test "generic callable stored in data keeps one physical ABI on every backend" {
  let actual = execute_compiler_test_matrix(
    (
      #|module Main
      #|
      #|pub type Equal = type[T] => (T, T) -> Bool
      #|
      #|struct Iso[T, R] {
      #|  to : (T) -> R
      #|}
      #|
      #|struct Deriver[C : [Type] -> Type] {
      #|  record : [T, R](Iso[T, R], C[R]) -> C[T]
      #|}
      #|
      #|let equal_deriver : Deriver[Equal] = Deriver::{
      #|  record: fn[T, R](iso, equal) {
      #|    fn(left : T, right : T) {
      #|      equal(iso.to(left), iso.to(right))
      #|    }
      #|  }
      #|}
      #|
      #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe_i64")
      #|
      #|pub fn main() -> Unit ! Io {
      #|  let equal_unit = equal_deriver.record[Unit, Unit](
      #|    Iso::{ to: fn(value : Unit) { value } },
      #|    fn(_left : Unit, _right : Unit) { true }
      #|  )
      #|  observe(if equal_unit((), ()) { 1 } else { 0 })
      #|}
    ),
  )
  assert_eq(actual, expected_i64_execution_matrix(1L, 0))
}

///|
test "every constructor follows its specialized data family on every backend" {
  let actual = execute_compiler_test_matrix(
    (
      #|module Main
      #|
      #|enum Optional[T] {
      #|  some(T)
      #|  none()
      #|}
      #|
      #|let equal : (I64, I64) -> Bool = builtin("%i64_equal")
      #|let subtract : (I64, I64) -> I64 = builtin("%i64_sub")
      #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe_i64")
      #|
      #|fn seek(offset : I64, remaining : I64) -> Optional[I64] {
      #|  if equal(remaining, 0) {
      #|    some(offset)
      #|  } else if equal(offset, 0) {
      #|    none()
      #|  } else {
      #|    seek(subtract(offset, 1), subtract(remaining, 1))
      #|  }
      #|}
      #|
      #|pub fn main() -> Unit ! Io {
      #|  match seek(2, 3) {
      #|    some(value) => observe(value)
      #|    none() => observe(1)
      #|  }
      #|}
    ),
  )
  assert_eq(actual, expected_i64_execution_matrix(1L, 0))
}

///|
test "a data join keeps the generic family required by one branch on every backend" {
  let actual = execute_compiler_test_matrix(
    (
      #|module Main
      #|
      #|enum Sequence[T] {
      #|  empty()
      #|  cons(T, Sequence[T])
      #|}
      #|
      #|enum Carrier[T] {
      #|  stored(Sequence[T])
      #|  missing()
      #|}
      #|
      #|struct Decoder {
      #|  decode : [T](Carrier[T], T) -> Sequence[T]
      #|}
      #|
      #|let decoder : Decoder = Decoder::{
      #|  decode: fn[T](carrier, fallback) {
      #|    match carrier {
      #|      stored(sequence) => sequence
      #|      missing() => cons(fallback, empty())
      #|    }
      #|  }
      #|}
      #|
      #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe_i64")
      #|
      #|pub fn main() -> Unit ! Io {
      #|  let sequence = decoder.decode[I64](stored(empty()), 42)
      #|  match sequence {
      #|    empty() => observe(1)
      #|    cons(value, _rest) => observe(value)
      #|  }
      #|}
    ),
  )
  assert_eq(actual, expected_i64_execution_matrix(1L, 0))
}

///|
test "recursive higher-kinded callable adapters preserve data values on every backend" {
  let actual = execute_compiler_test_matrix(
    (
      #|module Main
      #|
      #|struct Equal[T] {
      #|  equal : (T, T) -> Bool
      #|}
      #|
      #|struct Recursive[C : [Type] -> Type] {
      #|  defer : [T](() -> C[T]) -> C[T]
      #|}
      #|
      #|enum Sequence[T] {
      #|  empty()
      #|  cons(T, Sequence[T])
      #|}
      #|
      #|let recursive_equal : Recursive[Equal] = Recursive::{
      #|  defer: fn[T](get_equal) {
      #|    Equal::{
      #|      equal: fn(left, right) {
      #|        get_equal().equal(left, right)
      #|      }
      #|    }
      #|  }
      #|}
      #|
      #|fn[T] sequence_equal(element : Equal[T]) -> Equal[Sequence[T]] {
      #|  let recursive : Equal[Sequence[T]] = recursive_equal.defer(
      #|    fn() { sequence_equal(element) }
      #|  )
      #|  Equal::{
      #|    equal: fn(left, right) {
      #|      match left {
      #|        empty() => match right {
      #|          empty() => true
      #|          cons(_, _) => false
      #|        }
      #|        cons(left_head, left_tail) => match right {
      #|          empty() => false
      #|          cons(right_head, right_tail) =>
      #|            if element.equal(left_head, right_head) {
      #|              recursive.equal(left_tail, right_tail)
      #|            } else {
      #|              false
      #|            }
      #|        }
      #|      }
      #|    }
      #|  }
      #|}
      #|
      #|let i64_equal : (I64, I64) -> Bool = builtin("%i64_equal")
      #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe_i64")
      #|
      #|pub fn main() -> Unit ! Io {
      #|  let equal = sequence_equal(Equal::{ equal: i64_equal })
      #|  let left = cons(1, cons(2, empty()))
      #|  let right = cons(1, cons(2, empty()))
      #|  observe(if equal.equal(left, right) { 1 } else { 0 })
      #|}
    ),
  )
  assert_eq(actual, expected_i64_execution_matrix(1L, 0))
}

///|
test "recursive higher-kinded callable aliases preserve data values on every backend" {
  let actual = execute_compiler_test_matrix(
    (
      #|module Main
      #|
      #|pub type Measure[T] = (T) -> I64
      #|
      #|struct Recursive[C : [Type] -> Type] {
      #|  defer : [T](() -> C[T]) -> C[T]
      #|}
      #|
      #|enum Sequence[T] {
      #|  empty()
      #|  cons(T, Sequence[T])
      #|}
      #|
      #|let recursive_measure : Recursive[Measure] = Recursive::{
      #|  defer: fn[T](get_measure) {
      #|    fn(value : T) {
      #|      get_measure()(value)
      #|    }
      #|  }
      #|}
      #|
      #|let add : (I64, I64) -> I64 = builtin("%i64_add")
      #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe_i64")
      #|
      #|fn[T] sequence_measure(element : Measure[T]) -> Measure[Sequence[T]] {
      #|  let recursive : Measure[Sequence[T]] = recursive_measure.defer(
      #|    fn() { sequence_measure(element) }
      #|  )
      #|  fn(sequence) {
      #|    match sequence {
      #|      empty() => 0
      #|      cons(head, tail) => add(element(head), recursive(tail))
      #|    }
      #|  }
      #|}
      #|
      #|pub fn main() -> Unit ! Io {
      #|  let measure = sequence_measure[I64](fn(value : I64) { value })
      #|  observe(measure(cons(20, cons(22, empty()))))
      #|}
    ),
  )
  assert_eq(actual, expected_i64_execution_matrix(42L, 0))
}

///|
test "one generic handler returns distinct runtime representations on every backend" {
  let actual = execute_compiler_test_matrix(
    (
      #|module Main
      #|
      #|effect OutOfBound {
      #|  fail[R]() -> R
      #|}
      #|
      #|effect Assert {
      #|  assert(Bool, String, String) -> Unit
      #|}
      #|
      #|enum List[T] {
      #|  empty()
      #|  cons(T, List[T])
      #|}
      #|
      #|fn[T] expect_in_bounds(action : () -> T ! OutOfBound, fallback : T) -> T ! Assert {
      #|  handle action() with {
      #|    fail[R](_resume) => {
      #|      assert!(false, "out of bounds", "unexpected failure")
      #|      fallback
      #|    }
      #|  } final value {
      #|    value
      #|  }
      #|}
      #|
      #|fn[T] possible_bound(value : T, fail_now : Bool) -> T ! OutOfBound {
      #|  if fail_now {
      #|    fail!()
      #|  } else {
      #|    value
      #|  }
      #|}
      #|
      #|let char_to_i32 : (Char) -> I32 = builtin("%char_to_i32")
      #|let i32_to_i64 : (I32) -> I64 = builtin("%i32_to_i64")
      #|let string_to_bytes : (String) -> Bytes = builtin("%string_to_bytes")
      #|let bytes_length : (Bytes) -> I64 = builtin("%bytes_length")
      #|let add : (I64, I64) -> I64 = builtin("%i64_add")
      #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe_i64")
      #|
      #|fn test_bound() -> Unit ! { Assert, Io } {
      #|  let scalar = expect_in_bounds[Char](fn() { possible_bound('中', false) }, '\0')
      #|  let text = expect_in_bounds[String](fn() { possible_bound("ok", false) }, "")
      #|  observe(add(i32_to_i64(char_to_i32(scalar)), bytes_length(string_to_bytes(text))))
      #|}
      #|
      #|fn[E : Effect] execute_test(action : () -> Unit ! { E, Assert }) -> Bool ! E {
      #|  handle action() with {
      #|    assert(_condition, _info, _message, resume) => resume(())
      #|  } final _value {
      #|    true
      #|  }
      #|}
      #|
      #|fn[E : Effect] execute_tests(tests : List[() -> Unit ! { E, Assert }]) -> Unit ! E {
      #|  match tests {
      #|    empty() => ()
      #|    cons(test, rest) => {
      #|      let _passed = execute_test(test)
      #|      execute_tests(rest)
      #|    }
      #|  }
      #|}
      #|
      #|pub fn main() -> Unit ! Io {
      #|  execute_tests(cons(test_bound, empty()))
      #|}
    ),
  )
  assert_eq(actual, expected_i64_execution_matrix(20015L, 0))
}

///|
test "recursive generic data results keep one family on every backend" {
  let actual = execute_compiler_test_matrix(
    (
      #|module Main
      #|
      #|enum Optional[T] {
      #|  none()
      #|  some(T)
      #|}
      #|
      #|enum Sequence[T] {
      #|  empty()
      #|  cons(T, Sequence[T])
      #|}
      #|
      #|fn[T] last(values : Sequence[T]) -> Optional[T] {
      #|  match values {
      #|    empty() => Optional::none()
      #|    cons(value, rest) => match rest {
      #|      empty() => some(value)
      #|      cons(_, _) => last(rest)
      #|    }
      #|  }
      #|}
      #|
      #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe_i64")
      #|
      #|pub fn main() -> Unit ! Io {
      #|  let result : Optional[I64] = last(cons(1, cons(42, Sequence::empty())))
      #|  match result {
      #|    none() => observe(0)
      #|    some(value) => observe(value)
      #|  }
      #|}
    ),
  )
  assert_eq(actual, expected_i64_execution_matrix(42L, 0))
}

///|
test "specialized generic closure captures its exact data family on every backend" {
  let actual = execute_compiler_test_matrix(
    (
      #|module Main
      #|
      #|struct Box[T] {
      #|  value : T
      #|}
      #|
      #|fn[T] defer_box(box : Box[T]) -> () -> Box[T] {
      #|  fn() { box }
      #|}
      #|
      #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe_i64")
      #|
      #|pub fn main() -> Unit ! Io {
      #|  observe(defer_box(Box::{ value: 42 })().value)
      #|}
    ),
  )
  assert_eq(actual, expected_i64_execution_matrix(42L, 0))
}

///|
test "generic stored closure forces its captured callable to the generic ABI" {
  let actual = execute_compiler_test_matrix(
    (
      #|module Main
      #|
      #|struct Eval[T] {
      #|  value : T
      #|}
      #|
      #|fn lift(body : (Eval[I64]) -> Eval[I64]) -> Eval[(I64) -> I64] {
      #|  Eval::{
      #|    value: fn(input : I64) {
      #|      body(Eval::{ value: input }).value
      #|    }
      #|  }
      #|}
      #|
      #|let add : (I64, I64) -> I64 = builtin("%i64_add")
      #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe_i64")
      #|
      #|pub fn main() -> Unit ! Io {
      #|  let increment = lift(fn(value) {
      #|    Eval::{ value: add(value.value, 1) }
      #|  })
      #|  observe(increment.value(41))
      #|}
    ),
  )
  assert_eq(actual, expected_i64_execution_matrix(42L, 0))
}

///|
test "higher-kinded callable stored in data keeps its generic metadata argument" {
  let actual = execute_compiler_test_matrix(
    (
      #|module Main
      #|
      #|struct Wrapper[T] {
      #|  run : (T) -> T
      #|}
      #|
      #|struct FieldInfo {
      #|  name : String
      #|}
      #|
      #|struct Deriver[C : [Type] -> Type] {
      #|  field : [T](FieldInfo, C[T]) -> C[T]
      #|}
      #|
      #|let deriver : Deriver[Wrapper] = Deriver::{
      #|  field: fn[T](info, value) {
      #|    let _name = info.name
      #|    Wrapper::{ run: value.run }
      #|  }
      #|}
      #|
      #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe_i64")
      #|
      #|pub fn main() -> Unit ! Io {
      #|  let wrapped = deriver.field[I64](
      #|    FieldInfo::{ name: "value" },
      #|    Wrapper::{ run: fn(value : I64) { value } }
      #|  )
      #|  observe(wrapped.run(42))
      #|}
    ),
  )
  assert_eq(actual, expected_i64_execution_matrix(42L, 0))
}

///|
test "recursive nested effect companion forwarding preserves its generic edge" {
  let actual = execute_compiler_test_matrix(
    (
      #|module Main
      #|
      #|effect Forward[E : Effect] {
      #|  request(() -> Unit ! E) -> Unit
      #|}
      #|
      #|effect Log {
      #|  write() -> Unit
      #|}
      #|
      #|fn[E : Effect] request(action : () -> Unit ! E) -> Unit ! Forward[E] {
      #|  Forward[E]::request!(action)
      #|}
      #|
      #|fn[E : Effect] nested(action : () -> Unit ! E) -> Unit ! Forward[E] {
      #|  let invoke : () -> Unit ! Forward[E] = fn() {
      #|    request(action)
      #|  }
      #|  invoke()
      #|}
      #|
      #|let observe : (I64) -> Unit ! Io = extern("lane.test.observe_i64")
      #|
      #|pub fn main() -> Unit ! Io {
      #|  handle {
      #|    handle nested[Log](fn() { Log::write!() }) with {
      #|      Forward[Log]::request(action, resume) => {
      #|        action()
      #|        resume(())
      #|      }
      #|    } final _value {
      #|      ()
      #|    }
      #|  } with {
      #|    Log::write(resume) => {
      #|      observe(42)
      #|      resume(())
      #|    }
      #|  } final _value {
      #|    ()
      #|  }
      #|}
    ),
  )
  assert_eq(actual, expected_i64_execution_matrix(42L, 0))
}
