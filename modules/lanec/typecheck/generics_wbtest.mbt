///|
test "typecheck generic call uses expected result type" {
  let result = expect_typecheck_result(
    (
      #|enum Marker[A] {
      #|  marker()
      #|}
      #|fn[A] make() -> Marker[A] {
      #|  Marker::marker()
      #|}
      #|fn use() -> Marker[I64] {
      #|  make()
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {
      #|      enum Marker#0[A#0 : Type] {
      #|        marker#0
      #|      }
      #|    }
      #|    type_members {}
      #|    fields {}
      #|    variants {
      #|      marker#0
      #|    }
      #|  }
      #|  checked_values {
      #|    fn make#0 : forall [tparam#1 A : Type]. () -> type#0[tparam#1]
      #|    fn use#1 : () -> type#0[I64]
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck generic call drives function literal argument" {
  let result = expect_typecheck_result(
    (
      #|fn[A] apply(callback : (A) -> A, value : A) -> A {
      #|  callback(value)
      #|}
      #|fn use() -> I64 {
      #|  apply(fn(value) {
      #|    value
      #|  }, 1)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {}
      #|    type_members {}
      #|    fields {}
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn apply#0 : forall [tparam#0 A : Type]. ((tparam#0) -> tparam#0, tparam#0) -> tparam#0
      #|    fn use#1 : () -> I64
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck polymorphic function parameter instantiation" {
  let result = expect_typecheck_result(
    (
      #|fn[B] apply(f : [A](A) -> A, x : B) -> B {
      #|  f(x)
      #|}
      #|fn[A] id(value : A) -> A {
      #|  value
      #|}
      #|fn use() -> I64 {
      #|  apply(id, 1)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|typecheck_result {
      #|  checked_declarations {
      #|    types {}
      #|    type_members {}
      #|    fields {}
      #|    variants {}
      #|  }
      #|  checked_values {
      #|    fn apply#0 : forall [
      #|      tparam#0 B : Type
      #|    ]. (forall [tparam#1 A : Type]. (tparam#1) -> tparam#1, tparam#0) -> tparam#0
      #|    fn id#1 : forall [tparam#2 A : Type]. (tparam#2) -> tparam#2
      #|    fn use#2 : () -> I64
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck explicit generic function application" {
  let result = expect_checked_source_result(
    (
      #|fn[A] id(value : A) -> A {
      #|  value
      #|}
      #|let id_int : (I64) -> I64 = id[I64]
      #|let value : I64 = id[I64](id_int(1))
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|checked_source_typecheck_result {
      #|  checked {
      #|    fn[A#0 : Type] id#0(value#3 : tparam#0) -> tparam#0 {
      #|      value#3
      #|    }
      #|    let id_int#1 : (I64) -> I64 = id#0[I64]
      #|    let value#2 : I64 = id#0[I64](id_int#1(1))
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck explicit effect-kind generic function argument" {
  let result = expect_checked_source_result(
    (
      #|effect Log {
      #|  log(I64) -> Unit
      #|}
      #|effect Coroutine[E : Effect] {
      #|  yield() -> Unit
      #|}
      #|fn[E : Effect] yield_once() -> Unit ! Coroutine[E] {
      #|  Coroutine[E]::yield!()
      #|}
      #|fn use() -> I64 {
      #|  handle yield_once[Log]() with {
      #|    Coroutine[Log]::yield(resume) => resume(())
      #|  } final value {
      #|    42
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|checked_source_typecheck_result {
      #|  checked {
      #|    effect Log#0 {
      #|      log#0(I64) -> Unit
      #|    }
      #|    effect Coroutine#1[E#0 : Effect] {
      #|      yield#1 -> Unit
      #|    }
      #|    fn[E#1 : Effect] yield_once#0() -> Unit {
      #|      operation#1!()
      #|    }
      #|    fn use#1() -> I64 {
      #|      {
      #|        handle yield_once#0[effect#0]()
      #|        with effect#1[effect#0] {
      #|          operation#1(resume#2) => resume#2(())
      #|        }
      #|        final value#3 {
      #|          42
      #|        }
      #|      }
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck braced effect generic arguments" {
  let result = expect_typecheck_result(
    (
      #|effect Log {
      #|  write(I64) -> Unit
      #|}
      #|effect Ops {
      #|  ping[E : Effect]() -> Unit
      #|}
      #|effect Coroutine[E : Effect] {
      #|  yield() -> Unit
      #|}
      #|struct Box[A, E : Effect] {
      #|  value : A
      #|}
      #|enum Task {
      #|  task[E : Effect]()
      #|}
      #|fn[E : Effect] run(action : () -> Unit ! E) -> Unit ! E {
      #|  action()
      #|}
      #|fn pure() -> Unit {
      #|  ()
      #|}
      #|fn use() -> I64 ! Ops {
      #|  {
      #|    let ran : Unit = run[{}](pure)
      #|    let box : Box[I64, {}] = Box[I64, {}]::{ value: 1 }
      #|    let task : Task = Task::task[{ Log }]()
      #|    let pinged : Unit = Ops::ping![{}]()
      #|    box.value
      #|  }
      #|}
      #|fn handled() -> Unit {
      #|  handle Coroutine[{}]::yield!() with {
      #|    Coroutine[{}]::yield(resume) => resume(())
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[]
    ),
  )
}

///|
test "typecheck infers empty residual effect row in generic function argument" {
  let result = expect_typecheck_result(
    (
      #|effect Log {
      #|  write(I64) -> Unit
      #|}
      #|fn program() -> I64 ! Log {
      #|  let _written : Unit = Log::write!(40)
      #|  42
      #|}
      #|fn[A, E : Effect] handle_log(task : () -> A ! { Log, E }) -> () -> A ! E {
      #|  fn () {
      #|    handle task() with {
      #|      Log::write(_value, resume) => resume(())
      #|    } final value {
      #|      value
      #|    }
      #|  }
      #|}
      #|fn use() -> I64 {
      #|  handle_log(program)()
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[]
    ),
  )
}

///|
test "typecheck infers empty effect parameter from unannotated callback" {
  let result = expect_typecheck_result(
    (
      #|struct Pair {
      #|  first : I64
      #|  second : I64
      #|}
      #|fn[T, R, E : Effect] transform(value : T, callback : (T) -> R ! E) -> R ! E {
      #|  callback(value)
      #|}
      #|fn use(pair : Pair) -> I64 {
      #|  transform(pair, fn(item) { item.second })
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[]
    ),
  )
}

///|
test "typecheck infers non-empty effect from ground anonymous callback" {
  let result = expect_typecheck_result(
    (
      #|effect Read {
      #|  read() -> I64
      #|}
      #|fn[E : Effect] consume(callback : () -> I64 ! E) -> I64 ! E {
      #|  callback()
      #|}
      #|fn use() -> I64 ! Read {
      #|  consume(fn() { Read::read!() })
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "typecheck infers effect from explicitly annotated anonymous callback" {
  let result = expect_typecheck_result(
    (
      #|effect Read {
      #|  read() -> I64
      #|}
      #|fn[E : Effect] consume(callback : () -> I64 ! E) -> I64 ! E {
      #|  callback()
      #|}
      #|fn use() -> I64 ! Read {
      #|  consume(fn() -> I64 ! Read { Read::read!() })
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "typecheck rejects effect evidence from invalid callback body" {
  let result = expect_typecheck_result(
    (
      #|effect Read {
      #|  read() -> I64
      #|}
      #|fn[E : Effect] consume(callback : () -> I64 ! E) -> I64 ! E {
      #|  callback()
      #|}
      #|fn use() -> I64 {
      #|  let _result = consume(fn() {
      #|    let _value : I64 = Read::read!()
      #|    true
      #|  })
      #|  0
      #|}
    ),
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: GenericArgumentInferenceFailed(
      #|      label="consume",
      #|      failure=MissingGenericArguments(parameters=[{ id: { index: 0 }, name: "E", kind: Effect }]),
      #|    ),
      #|    loc: {
      #|      start_offset: 155,
      #|      end_offset: 220,
      #|      start_line: 9,
      #|      start_column: 17,
      #|      end_line: 12,
      #|      end_column: 5,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "typecheck infers non-empty residual effect row in generic function argument" {
  let result = expect_typecheck_result(
    (
      #|effect Ask {
      #|  read() -> I64
      #|}
      #|effect Log {
      #|  write(I64) -> Unit
      #|}
      #|fn program() -> I64 ! { Ask, Log } {
      #|  let value : I64 = Ask::read!()
      #|  let _written : Unit = Log::write!(value)
      #|  value
      #|}
      #|fn[A, E : Effect] handle_ask(task : () -> A ! { Ask, E }) -> () -> A ! E {
      #|  fn () {
      #|    handle task() with {
      #|      Ask::read(resume) => resume(0)
      #|    } final value {
      #|      value
      #|    }
      #|  }
      #|}
      #|fn use() -> I64 ! Log {
      #|  handle_ask(program)()
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[]
    ),
  )
}

///|
test "typecheck rejects callback effect measurement before its shape is ground" {
  let result = expect_typecheck_result(
    (
      #|fn[A, E : Effect] consume(callback : (A) -> A ! E) -> Unit {
      #|  ()
      #|}
      #|fn use() -> Unit {
      #|  consume(fn(value) { value })
      #|}
    ),
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: GenericArgumentInferenceFailed(
      #|      label="consume",
      #|      failure=MissingGenericArguments(
      #|        parameters=[
      #|          { id: { index: 0 }, name: "A", kind: Type },
      #|          { id: { index: 1 }, name: "E", kind: Effect },
      #|        ],
      #|      ),
      #|    ),
      #|    loc: {
      #|      start_offset: 101,
      #|      end_offset: 129,
      #|      start_line: 6,
      #|      start_column: 3,
      #|      end_line: 6,
      #|      end_column: 31,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "typecheck does not infer callback result from its return annotation" {
  let result = expect_typecheck_result(
    (
      #|fn[R, E : Effect] consume(callback : () -> R ! E) -> Unit {
      #|  ()
      #|}
      #|fn use() -> Unit {
      #|  consume(fn() -> I64 { 1 })
      #|}
    ),
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: GenericArgumentInferenceFailed(
      #|      label="consume",
      #|      failure=MissingGenericArguments(
      #|        parameters=[
      #|          { id: { index: 0 }, name: "R", kind: Type },
      #|          { id: { index: 1 }, name: "E", kind: Effect },
      #|        ],
      #|      ),
      #|    ),
      #|    loc: {
      #|      start_offset: 100,
      #|      end_offset: 126,
      #|      start_line: 6,
      #|      start_column: 3,
      #|      end_line: 6,
      #|      end_column: 29,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "typecheck does not decompose forall arguments during generic inference" {
  let result = expect_typecheck_result(
    (
      #|fn[R] consume(callback : [A](A) -> R) -> Unit {
      #|  ()
      #|}
      #|fn[A] identity(value : A) -> A {
      #|  value
      #|}
      #|fn use() -> Unit {
      #|  consume(identity)
      #|}
    ),
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: GenericArgumentInferenceFailed(
      #|      label="consume",
      #|      failure=MissingGenericArguments(parameters=[{ id: { index: 0 }, name: "R", kind: Type }]),
      #|    ),
      #|    loc: {
      #|      start_offset: 131,
      #|      end_offset: 148,
      #|      start_line: 9,
      #|      start_column: 3,
      #|      end_line: 9,
      #|      end_column: 20,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "typecheck does not backtrack ambiguous effect row inference" {
  let result = expect_typecheck_result(
    (
      #|effect Mark[A] {
      #|  mark() -> Unit
      #|}
      #|fn[A, B] consume(callback : () -> Unit ! { Mark[A], Mark[B] }) -> Unit {
      #|  ()
      #|}
      #|fn callback() -> Unit ! { Mark[I64], Mark[Bool] } {
      #|  let _first : Unit = Mark[I64]::mark!()
      #|  Mark[Bool]::mark!()
      #|}
      #|fn use() -> Unit {
      #|  consume(callback)
      #|}
    ),
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: GenericArgumentInferenceFailed(
      #|      label="consume",
      #|      failure=AmbiguousEffectRowInference(
      #|        expected=Union(
      #|          [
      #|            Singleton({ index: 0 }, [TypeArgument(Parameter({ index: 1 }))]),
      #|            Singleton({ index: 0 }, [TypeArgument(Parameter({ index: 2 }))]),
      #|          ],
      #|        ),
      #|        actual=Union(
      #|          [
      #|            Singleton({ index: 0 }, [TypeArgument(Primitive(I64))]),
      #|            Singleton({ index: 0 }, [TypeArgument(Primitive(Bool))]),
      #|          ],
      #|        ),
      #|      ),
      #|    ),
      #|    loc: {
      #|      start_offset: 274,
      #|      end_offset: 282,
      #|      start_line: 13,
      #|      start_column: 11,
      #|      end_line: 13,
      #|      end_column: 19,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "typecheck infers unmatched terms into an effect upper bound" {
  let result = expect_typecheck_result(
    (
      #|effect Ask {
      #|  ask() -> Unit
      #|}
      #|effect Log {
      #|  log() -> Unit
      #|}
      #|fn[E : Effect] consume(callback : () -> Unit ! { Ask, E }) -> Unit {
      #|  ()
      #|}
      #|fn callback() -> Unit ! Log {
      #|  Log::log!()
      #|}
      #|fn use() -> Unit {
      #|  consume(callback)
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "typecheck matches effect rows after grounding owner arguments" {
  let result = expect_typecheck_result(
    (
      #|effect State[A] {
      #|  get() -> A
      #|}
      #|fn[A, E : Effect] consume(callback : () -> Bool ! { State[A], E }, value : A) -> Unit {
      #|  ()
      #|}
      #|fn callback() -> Bool ! { State[I64], State[Bool] } {
      #|  let _first : I64 = State[I64]::get!()
      #|  State[Bool]::get!()
      #|}
      #|fn use() -> Unit {
      #|  consume(callback, 1)
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "typecheck rejects impossible partially ground effect owner candidates" {
  let result = expect_typecheck_result(
    (
      #|struct Pair[A, B] {
      #|  first : A
      #|  second : B
      #|}
      #|effect State[A] {
      #|  get() -> A
      #|}
      #|fn[T, E : Effect] consume(
      #|  callback : () -> Bool ! { State[Pair[T, I64]], E }
      #|) -> Unit {
      #|  ()
      #|}
      #|fn callback() -> Bool
      #|  ! { State[Pair[String, I64]], State[Pair[Bool, Bool]] } {
      #|  let _left : Pair[String, I64] = State[Pair[String, I64]]::get!()
      #|  let _right : Pair[Bool, Bool] = State[Pair[Bool, Bool]]::get!()
      #|  true
      #|}
      #|fn use() -> Unit {
      #|  consume(callback)
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "typecheck does not infer polymorphic recursion" {
  let result = expect_typecheck_result(
    (
      #|enum Box[A] {
      #|  box(A)
      #|}
      #|fn[A] recurse(value : A) -> Unit {
      #|  recurse(Box::box(value))
      #|}
    ),
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: GenericArgumentInferenceFailed(
      #|      label="recurse",
      #|      failure=RecursiveGenericArgument(
      #|        parameter={ id: { index: 1 }, name: "A", kind: Type },
      #|        actual=TypeArgument(
      #|          Apply(
      #|            Constructor({ index: 0 }),
      #|            [TypeArgument(Parameter({ index: 1 }))],
      #|          ),
      #|        ),
      #|      ),
      #|    ),
      #|    loc: {
      #|      start_offset: 82,
      #|      end_offset: 97,
      #|      start_line: 6,
      #|      start_column: 11,
      #|      end_line: 6,
      #|      end_column: 26,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "typecheck reports explicit generic function arity mismatch" {
  let result = expect_typecheck_result(
    (
      #|fn[A] id(value : A) -> A {
      #|  value
      #|}
      #|let value : I64 = id[I64, Bool](1)
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[type_arity_mismatch explicit_generic_application id expected=1 actual=2 @ 5:19-5:32]
    ),
  )
}

///|
test "typecheck reports explicit generic function kind mismatch" {
  let result = expect_typecheck_result(
    (
      #|effect Log {
      #|  log(I64) -> Unit
      #|}
      #|fn[E : Effect] run(action : () -> Unit ! E) -> Unit ! E {
      #|  action()
      #|}
      #|fn logged() -> Unit ! Log {
      #|  Log::log!(1)
      #|}
      #|let value : Unit = run[I64](logged)
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[kind_mismatch expected=Effect actual=Type @ 11:24-11:27]
    ),
  )
}

///|
test "typecheck reports generic arguments on non-generic function" {
  let result = expect_typecheck_result(
    (
      #|fn plain(value : I64) -> I64 {
      #|  value
      #|}
      #|let value : I64 = plain[I64](1)
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[generic_arguments_on_non_generic explicit_generic_application plain (I64) -> I64 @ 5:19-5:29]
    ),
  )
}

///|
test "typecheck reports unresolved generic arguments" {
  let result = expect_typecheck_result(
    (
      #|enum Marker[A] {
      #|  marker()
      #|}
      #|fn[A] make() -> Marker[A] {
      #|  Marker::marker()
      #|}
      #|fn use() -> Bool {
      #|  {
      #|    let value = make()
      #|    true
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[generic_argument_inference_failed make missing A @ 10:17-10:23]
    ),
  )
}

///|
test "typecheck reports conflicting generic argument inference" {
  let result = expect_typecheck_result(
    (
      #|fn[A] choose(left : A, right : A) -> A {
      #|  left
      #|}
      #|fn use() -> Bool {
      #|  {
      #|    let _ = choose(1, true)
      #|    true
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[generic_argument_inference_failed choose conflict A previous=I64 actual=Bool @ 7:23-7:27]
    ),
  )
}

///|
test "typecheck expands transparent type alias beta applications" {
  let result = expect_typecheck_result(
    (
      #|type Id[A] = A
      #|let answer : Id[I64] = 42
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
  guard result.values.values[0] is Let(value) else {
    abort("expected checked let")
  }
  inspect(@prettyprinter.render(value.type_, width=100), content="I64")
}

///|
test "typecheck accepts higher-kinded alias parameter" {
  let result = expect_typecheck_result(
    (
      #|struct Box[A] {
      #|  value : A
      #|}
      #|type ApplyInt[F : [Type] -> Type] = F[I64]
      #|fn get(box : ApplyInt[Box]) -> I64 {
      #|  box.value
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
}

///|
test "typecheck accepts higher-kinded struct literal type argument" {
  let result = expect_typecheck_result(
    (
      #|enum Option[T] {
      #|  some(T)
      #|  none()
      #|}
      #|fn[T, R] map_option(val : Option[T], f : (T) -> R) -> Option[R] {
      #|  match val {
      #|    Option::some(v) => Option::some(f(v))
      #|    Option::none() => Option::none()
      #|  }
      #|}
      #|struct Mappable[U : [Type] -> Type] {
      #|  map : [A, B](U[A], (A) -> B) -> U[B]
      #|}
      #|let option_mappable : Mappable[Option] = Mappable[Option]::{
      #|  map: map_option
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
}

///|
test "typecheck reports kind mismatch for higher-kinded struct literal type argument" {
  let result = expect_typecheck_result(
    (
      #|enum Option[T] {
      #|  some(T)
      #|  none()
      #|}
      #|fn[T, R] map_option(val : Option[T], f : (T) -> R) -> Option[R] {
      #|  match val {
      #|    Option::some(v) => Option::some(f(v))
      #|    Option::none() => Option::none()
      #|  }
      #|}
      #|struct Mappable[U : [Type] -> Type] {
      #|  map : [A, B](U[A], (A) -> B) -> U[B]
      #|}
      #|let bad : Mappable[Option] = Mappable[I64]::{
      #|  map: map_option
      #|}
    ),
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: KindMismatch(expected=Function([Type], Type), actual=Type),
      #|    loc: {
      #|      start_offset: 332,
      #|      end_offset: 335,
      #|      start_line: 15,
      #|      start_column: 39,
      #|      end_line: 15,
      #|      end_column: 42,
      #|    },
      #|  },
      #|  {
      #|    kind: TypeMismatch(
      #|      expected=Forall(
      #|        [
      #|          { id: { index: 4 }, name: "A", kind: Type },
      #|          { id: { index: 5 }, name: "B", kind: Type },
      #|        ],
      #|        Function(
      #|          [
      #|            Apply(Primitive(I64), [TypeArgument(Parameter({ index: 4 }))]),
      #|            Function([Parameter({ index: 4 })], Parameter({ index: 5 }), Empty),
      #|          ],
      #|          Apply(Primitive(I64), [TypeArgument(Parameter({ index: 5 }))]),
      #|          Empty,
      #|        ),
      #|      ),
      #|      actual=Forall(
      #|        [
      #|          { id: { index: 1 }, name: "T", kind: Type },
      #|          { id: { index: 2 }, name: "R", kind: Type },
      #|        ],
      #|        Function(
      #|          [
      #|            Apply(
      #|              Constructor({ index: 0 }),
      #|              [TypeArgument(Parameter({ index: 1 }))],
      #|            ),
      #|            Function([Parameter({ index: 1 })], Parameter({ index: 2 }), Empty),
      #|          ],
      #|          Apply(
      #|            Constructor({ index: 0 }),
      #|            [TypeArgument(Parameter({ index: 2 }))],
      #|          ),
      #|          Empty,
      #|        ),
      #|      ),
      #|    ),
      #|    loc: {
      #|      start_offset: 347,
      #|      end_offset: 357,
      #|      start_line: 16,
      #|      start_column: 8,
      #|      end_line: 16,
      #|      end_column: 18,
      #|    },
      #|  },
      #|  {
      #|    kind: TypeMismatch(
      #|      expected=Apply(
      #|        Constructor({ index: 1 }),
      #|        [TypeArgument(Constructor({ index: 0 }))],
      #|      ),
      #|      actual=Apply(Constructor({ index: 1 }), [TypeArgument(Primitive(I64))]),
      #|    ),
      #|    loc: {
      #|      start_offset: 323,
      #|      end_offset: 359,
      #|      start_line: 15,
      #|      start_column: 30,
      #|      end_line: 17,
      #|      end_column: 2,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "typecheck accepts higher-kinded qualified variant type argument" {
  let result = expect_typecheck_result(
    (
      #|enum Option[T] {
      #|  some(T)
      #|  none()
      #|}
      #|enum Box[F : [Type] -> Type] {
      #|  wrap(F[I64])
      #|}
      #|let boxed : Box[Option] = Box[Option]::wrap(Option::some(1))
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
}

///|
test "typecheck reports kind mismatch for higher-kinded qualified variant type argument" {
  let result = expect_typecheck_result(
    (
      #|enum Option[T] {
      #|  some(T)
      #|  none()
      #|}
      #|enum Box[F : [Type] -> Type] {
      #|  wrap(F[I64])
      #|}
      #|let boxed : Box[Option] = Box[I64]::wrap(Option::some(1))
    ),
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: KindMismatch(expected=Function([Type], Type), actual=Type),
      #|    loc: {
      #|      start_offset: 128,
      #|      end_offset: 131,
      #|      start_line: 9,
      #|      start_column: 31,
      #|      end_line: 9,
      #|      end_column: 34,
      #|    },
      #|  },
      #|  {
      #|    kind: TypeMismatch(
      #|      expected=Apply(Primitive(I64), [TypeArgument(Primitive(I64))]),
      #|      actual=Apply(Constructor({ index: 0 }), [TypeArgument(Primitive(I64))]),
      #|    ),
      #|    loc: {
      #|      start_offset: 139,
      #|      end_offset: 154,
      #|      start_line: 9,
      #|      start_column: 42,
      #|      end_line: 9,
      #|      end_column: 57,
      #|    },
      #|  },
      #|  {
      #|    kind: TypeMismatch(
      #|      expected=Apply(
      #|        Constructor({ index: 1 }),
      #|        [TypeArgument(Constructor({ index: 0 }))],
      #|      ),
      #|      actual=Apply(Constructor({ index: 1 }), [TypeArgument(Primitive(I64))]),
      #|    ),
      #|    loc: {
      #|      start_offset: 124,
      #|      end_offset: 155,
      #|      start_line: 9,
      #|      start_column: 27,
      #|      end_line: 9,
      #|      end_column: 58,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "typecheck infers higher-kinded generic argument from application spine" {
  let result = expect_typecheck_result(
    (
      #|enum Option[T] {
      #|  some(T)
      #|  none()
      #|}
      #|fn[F : [Type] -> Type] consume(value : F[I64]) -> I64 {
      #|  0
      #|}
      #|fn use() -> I64 {
      #|  consume(Option::some(1))
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
}

///|
test "typecheck infers higher-kinded and ordinary arguments from application spine" {
  let result = expect_typecheck_result(
    (
      #|enum Option[T] {
      #|  some(T)
      #|  none()
      #|}
      #|fn[F : [Type] -> Type, A] select(value : F[A], fallback : A) -> A {
      #|  fallback
      #|}
      #|let picked : I64 = select(Option::some(1), 0)
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
}

///|
test "typecheck forwards outer higher-kinded generic argument" {
  let result = expect_typecheck_result(
    (
      #|fn[F : [Type] -> Type] consume(value : F[I64]) -> I64 {
      #|  0
      #|}
      #|fn[F : [Type] -> Type] forward(value : F[I64]) -> I64 {
      #|  consume(value)
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
}

///|
test "typecheck does not synthesize higher-order lambda during generic inference" {
  let result = expect_typecheck_result(
    (
      #|enum Pair[A, B] {
      #|  pair(A, B)
      #|}
      #|fn[F : [Type] -> Type] consume(value : F[I64]) -> I64 {
      #|  0
      #|}
      #|fn bad(value : Pair[I64, Bool]) -> I64 {
      #|  consume(value)
      #|}
    ),
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: GenericArgumentInferenceFailed(
      #|      label="consume",
      #|      failure=GenericArgumentConstraintMismatch(
      #|        expected=TypeArgument(Parameter({ index: 2 })),
      #|        actual=TypeArgument(Constructor({ index: 0 })),
      #|      ),
      #|    ),
      #|    loc: {
      #|      start_offset: 158,
      #|      end_offset: 163,
      #|      start_line: 9,
      #|      start_column: 11,
      #|      end_line: 9,
      #|      end_column: 16,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "typecheck defaults unannotated alias header parameter kind to Type" {
  let result = expect_typecheck_result(
    (
      #|type ApplyInt[F] = F[I64]
      #|let answer : ApplyInt[I64] = 42
    ),
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: KindMismatch(expected=Function([], Type), actual=Type),
      #|    loc: {
      #|      start_offset: 31,
      #|      end_offset: 37,
      #|      start_line: 2,
      #|      start_column: 20,
      #|      end_line: 2,
      #|      end_column: 26,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "typecheck reports duplicate type alias header parameter" {
  let result = expect_typecheck_result(
    (
      #|type Bad[A, A] = A
      #|let answer : I64 = 42
    ),
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: DuplicateTypeParameter(name="A"),
      #|    loc: {
      #|      start_offset: 24,
      #|      end_offset: 25,
      #|      start_line: 2,
      #|      start_column: 13,
      #|      end_line: 2,
      #|      end_column: 14,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "typecheck reports type alias cycle" {
  let result = expect_typecheck_result(
    (
      #|type A = B
      #|type B = A
      #|let answer : A = 42
    ),
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: TypeAliasCycle(name="A"),
      #|    loc: {
      #|      start_offset: 32,
      #|      end_offset: 33,
      #|      start_line: 3,
      #|      start_column: 10,
      #|      end_line: 3,
      #|      end_column: 11,
      #|    },
      #|  },
      #|  {
      #|    kind: TypeAliasCycle(name="B"),
      #|    loc: {
      #|      start_offset: 21,
      #|      end_offset: 22,
      #|      start_line: 2,
      #|      start_column: 10,
      #|      end_line: 2,
      #|      end_column: 11,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "typecheck reports normalization fuel exhaustion as internal diagnostic" {
  let diagnostics : Array[TypeCheckDiagnostic] = []
  report_type_computation_failure(
    diagnostics,
    "type alias body",
    @basic.SourceSpan::dummy(),
    TypeNormalizationFuelExhausted,
  )
  debug_inspect(
    diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: InternalTypecheckFailure(label="type-level computation did not terminate while normalizing type alias body"),
      #|    loc: {
      #|      start_offset: 0,
      #|      end_offset: 0,
      #|      start_line: 1,
      #|      start_column: 1,
      #|      end_line: 1,
      #|      end_column: 1,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
fn deeply_nested_test_type(base : @types.Type) -> @types.Type {
  let mut type_ = base
  for _ in 0..<270 {
    type_ = Function([type_], Primitive(Unit), Empty)
  }
  type_
}

///|
fn empty_generic_argument_inference() -> GenericArgumentInference {
  GenericArgumentInference(
    {
      types: [],
      type_members: [],
      fields: [],
      variants: [],
      effects: [],
      operations: [],
    },
    {
      values: [],
      offers: ContextualOfferScope(),
      type_kinds: TypeKindScope::empty(),
      provisional_effect_parameters: [],
      expected_effect: None,
    },
    [],
  )
}

///|
test "generic effect occurs-check sees latent effects in type arguments" {
  let parameter : @types.TypeParameter = {
    id: { index: 0, },
    name: "E",
    kind: Effect,
  }
  let candidate : @types.GenericArgument = EffectArgument(
    Singleton({ index: 0, }, [
      TypeArgument(Function([], Primitive(Unit), Parameter(parameter.id))),
    ]),
  )
  let inference = empty_generic_argument_inference()
  inference.parameters.push(parameter)
  let remembered = inference.remember(parameter, candidate)
  assert_eq(
    (remembered, inference.failure),
    (false, Some(RecursiveGenericArgument(parameter~, actual=candidate))),
  )
}

///|
test "generic inference records an effect lower bound atomically" {
  let parameter : @types.TypeParameter = {
    id: { index: 0, },
    name: "E",
    kind: Effect,
  }
  let inference = empty_generic_argument_inference()
  inference.parameters.push(parameter)
  assert_true(inference.remember_effect_lower_bound(parameter, Empty))
  guard inference.bindings
    is [
      {
        parameter: recorded_parameter,
        constraint: EffectLowerBoundConstraint(
          effect=Empty,
          is_provisional=false
        ),
      },
    ] &&
    recorded_parameter == parameter else {
    abort("expected one atomic effect lower-bound constraint")
  }
}

///|
test "generic inference records type computation failure" {
  let inference = empty_generic_argument_inference()
  assert_false(
    inference.types_equal(
      deeply_nested_test_type(Primitive(Unit)),
      deeply_nested_test_type(Primitive(Bool)),
    ),
  )
  assert_true(
    inference.computation_error is Some(TypeNormalizationFuelExhausted),
  )
}

///|
test "generic inference reports a missing failure reason as internal" {
  let file = expect_parse_ok("")
  let resolution = @resolve.resolve_source_file_result(file)
  let source = @desugar.desugar_source_file(resolution.source)
  let declarations : CheckedDeclarationEnvironment = {
    types: [],
    type_members: [],
    fields: [],
    variants: [],
    effects: [],
    operations: [],
  }
  let diagnostics = []
  let interface_declarations = module_interface_declaration_surface(
    resolution.source,
    declarations,
    diagnostics,
  )
  let checker = SemanticChecker::{
    resolved_source: resolution.source,
    source,
    imported_environment: empty_imported_environment(),
    declarations,
    interface_declarations,
    canonical_basic_abi: @canonical_basic_abi.CanonicalBasicAbi::from_module_input(
      resolution.source.canonical_basic_abi,
      empty_imported_environment(),
      interface_declarations.types,
    ),
    diagnostics,
    values: [],
    value_types: [],
    ordered_value_types: [],
    offers: ContextualOfferScope(),
    ordered_offers: ContextualOfferScope(),
  }
  checker.report_generic_argument_inference_failure(
    "call generic arguments",
    empty_generic_argument_inference(),
    @basic.SourceSpan::dummy(),
  )
  guard checker.diagnostics
    is [
      {
        kind: InternalTypecheckFailure(
          label="generic argument inference failed without a recorded reason while inferring call generic arguments"
        ),
        ..
      },
    ] else {
    abort(@prettyprinter.render(checker.diagnostics, width=100))
  }
}

///|
test "generic inference rejects missing kind metadata" {
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let nominal = registry.define_type(
    "Missing",
    Struct,
    0,
    @basic.SourceSpan::dummy(),
  )
  let parameter = registry.define_type_parameter(
    "Missing",
    @basic.SourceSpan::dummy(),
  )
  let inference = empty_generic_argument_inference()
  assert_false(
    inference.generic_argument_has_kind(
      TypeArgument(Constructor(nominal)),
      Type,
    ),
  )
  assert_true(
    inference.missing_kind_metadata is Some(Nominal(id)) && id == nominal,
  )
  let parameter_inference = empty_generic_argument_inference()
  assert_false(
    parameter_inference.generic_argument_has_kind(
      TypeArgument(Parameter(parameter)),
      Type,
    ),
  )
  assert_true(
    parameter_inference.missing_kind_metadata is Some(TypeParameter(id)) &&
    id == parameter,
  )
}

///|
test "generic inference reads external nominal kind metadata" {
  let result = expect_checked_source_result(
    (
      #|extern type Fd : Type
      #|fn[T] identity(value : T) -> T { value }
      #|fn keep(fd : Fd) -> Fd { identity(fd) }
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
}

///|
test "handler effect operations propagate type computation failure" {
  let registry = @symbol.SymbolRegistry::SymbolRegistry()
  let effect = registry.define_effect("State", 0, @basic.SourceSpan::dummy())
  let left = @types.Effect::Singleton(effect, [
    TypeArgument(deeply_nested_test_type(Primitive(Unit))),
  ])
  let right = @types.Effect::Singleton(effect, [
    TypeArgument(deeply_nested_test_type(Primitive(Bool))),
  ])
  try handler_effect_union([left, right]) catch {
    error => debug_inspect(error, content="TypeNormalizationFuelExhausted")
  } noraise {
    _ => fail("handler effect equality must propagate normalization failure")
  }
}
