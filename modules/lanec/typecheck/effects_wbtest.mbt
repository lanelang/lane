///|
test "typecheck accepts pure computation under an effect upper bound" {
  let result = expect_typecheck_result(
    (
      #|effect Read {
      #|  read() -> Int
      #|}
      #|fn pure() -> Int {
      #|  42
      #|}
      #|fn declared() -> Int ! Read {
      #|  42
      #|}
      #|fn consume(callback : () -> Int ! Read) -> Int ! Read {
      #|  callback()
      #|}
      #|fn use() -> Int ! Read {
      #|  let direct : () -> Int ! Read = pure
      #|  consume(direct)
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "typecheck records function effect widening in checked expressions" {
  let expression = expect_checked_let_initializer(
    (
      #|effect Read {
      #|  read() -> Int
      #|}
      #|fn pure() -> Int {
      #|  42
      #|}
      #|let widened : () -> Int ! Read = pure
    ),
    "widened",
    Function([], Primitive(Int), Singleton({ index: 0 }, [])),
  )
  assert_true(
    expression
    is FunctionEffectWiden(
      value=Value(name="pure", type_=Function([], Primitive(Int), Empty), ..),
      ..
    ),
  )
}

///|
test "typecheck widens a narrower effect row" {
  let result = expect_typecheck_result(
    (
      #|effect Read {
      #|  read() -> Int
      #|}
      #|effect Write {
      #|  write(Int) -> Unit
      #|}
      #|fn read() -> Int ! Read {
      #|  Read::read!()
      #|}
      #|fn consume(callback : () -> Int ! { Read, Write }) -> Int ! { Read, Write } {
      #|  callback()
      #|}
      #|fn use() -> Int ! { Read, Write } {
      #|  consume(read)
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "typecheck rejects function effect narrowing" {
  let result = expect_typecheck_result(
    (
      #|effect Read {
      #|  read() -> Unit
      #|}
      #|effect Write {
      #|  write() -> Unit
      #|}
      #|fn wide() -> Unit ! { Read, Write } {
      #|  let _read : Unit = Read::read!()
      #|  Write::write!()
      #|}
      #|let narrow : () -> Unit ! Read = wide
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[
      #|  type_mismatch expected=() -> Unit ! effect#0 actual=() -> Unit ! {effect#0, effect#1} @ 12:34-12:38
      #|]
    ),
  )
}

///|
test "function literal annotation remains its body effect bound" {
  let result = expect_typecheck_result(
    (
      #|effect Read {
      #|  read() -> Unit
      #|}
      #|effect Write {
      #|  write() -> Unit
      #|}
      #|fn consume(callback : () -> Unit ! { Read, Write }) -> Unit {
      #|  ()
      #|}
      #|fn use() -> Unit {
      #|  consume(fn() -> Unit ! Read { Write::write!() })
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[effect_mismatch expected=effect#0 actual=effect#1 @ 12:31-12:50]
    ),
  )
}

///|
test "generic effect inference accepts a narrower repeated constraint" {
  let result = expect_typecheck_result(
    (
      #|effect Read {
      #|  read() -> Int
      #|}
      #|fn effectful() -> Int ! Read {
      #|  Read::read!()
      #|}
      #|fn pure() -> Int {
      #|  42
      #|}
      #|fn[E : Effect] choose(
      #|  first : () -> Int ! E,
      #|  second : () -> Int ! E
      #|) -> Int ! E {
      #|  let _first : Int = first()
      #|  second()
      #|}
      #|fn use() -> Int ! Read {
      #|  choose(effectful, pure)
      #|}
      #|fn use_reverse() -> Int ! Read {
      #|  choose(pure, effectful)
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "typecheck effect lower bounds and exact constraints are order independent" {
  let result = expect_typecheck_result(
    (
      #|effect Read {
      #|  read() -> Unit
      #|}
      #|effect Write {
      #|  write() -> Unit
      #|}
      #|struct Carrier[E : Effect] {
      #|  value : Int
      #|}
      #|fn callback() -> Unit ! Read {
      #|  Read::read!()
      #|}
      #|fn[E : Effect] lower_first(
      #|  action : () -> Unit ! E,
      #|  carrier : Carrier[{ E }]
      #|) -> Unit {
      #|  ()
      #|}
      #|fn[E : Effect] exact_first(
      #|  carrier : Carrier[{ E }],
      #|  action : () -> Unit ! E
      #|) -> Unit {
      #|  ()
      #|}
      #|fn use(carrier : Carrier[{ Read, Write }]) -> Unit {
      #|  lower_first(callback, carrier)
      #|  exact_first(carrier, callback)
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "typecheck upgrades an effect lower bound with an exact effect-atom argument" {
  let result = expect_typecheck_result(
    (
      #|effect Read {
      #|  read() -> Unit
      #|}
      #|effect Write {
      #|  write() -> Unit
      #|}
      #|effect Carrier[_E : Effect] {
      #|  carry() -> Unit
      #|}
      #|fn callback() -> Unit ! Read {
      #|  Read::read!()
      #|}
      #|fn carrier() -> Unit ! Carrier[{ Read, Write }] {
      #|  ()
      #|}
      #|fn[E : Effect] lower_then_exact(
      #|  action : () -> Unit ! E,
      #|  carrier : () -> Unit ! Carrier[E]
      #|) -> Unit {
      #|  ()
      #|}
      #|fn use() -> Unit {
      #|  lower_then_exact(callback, carrier)
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "handler measurement retains provisional and exact effect constraints" {
  let result = expect_typecheck_result(
    (
      #|effect Prompt {
      #|  ask() -> String
      #|}
      #|effect Log {
      #|  write() -> Unit
      #|}
      #|struct Carrier[_E : Effect] {
      #|  value : String
      #|}
      #|fn[E : Effect] invoke(callback : (String) -> String ! E, carrier : Carrier[{ E }]) -> String ! E {
      #|  callback(carrier.value)
      #|}
      #|fn run() -> String {
      #|  handle Prompt::ask!() with {
      #|    Prompt::ask(resume) => invoke(
      #|      resume,
      #|      Carrier[{ Log }]::{ value: "measured" },
      #|    )
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[effect_mismatch expected={} actual=effect#1 @ 14:20-23:2]
    ),
  )
}

///|
test "handler final pass rejects deferred effect lower bound conflicts" {
  let result = expect_typecheck_result(
    (
      #|effect Prompt {
      #|  ask() -> String
      #|}
      #|effect Read {
      #|  read() -> Unit
      #|}
      #|effect Log {
      #|  write() -> Unit
      #|}
      #|struct Carrier[_E : Effect] {
      #|  value : String
      #|}
      #|fn[E : Effect] invoke(callback : (String) -> String ! E, carrier : Carrier[{ E }]) -> String ! E {
      #|  callback(carrier.value)
      #|}
      #|fn run() -> String ! { Read, Log } {
      #|  handle Prompt::ask!() with {
      #|    Prompt::ask(resume) => {
      #|      let _written : Unit = Log::write!()
      #|      invoke(resume, Carrier[{ Read }]::{ value: "invalid" })
      #|    }
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: GenericArgumentInferenceFailed(
      #|      label="invoke",
      #|      failure=ConflictingGenericArgument(
      #|        parameter={ id: { index: 1 }, name: "E", kind: Effect },
      #|        previous=EffectArgument(Union([Singleton({ index: 2 }, []), Singleton({ index: 1 }, [])])),
      #|        actual=EffectArgument(Singleton({ index: 1 }, [])),
      #|      ),
      #|    ),
      #|    loc: {
      #|      start_offset: 450,
      #|      end_offset: 489,
      #|      start_line: 21,
      #|      start_column: 22,
      #|      end_line: 21,
      #|      end_column: 61,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "handler measurement rejects recursive residual effect arguments" {
  let result = expect_typecheck_result(
    (
      #|effect Prompt {
      #|  ask() -> Unit
      #|}
      #|effect Wrap[_E : Effect] {
      #|  touch() -> Unit
      #|}
      #|fn[E : Effect] wrap(callback : (Unit) -> Unit ! E) -> Unit ! Wrap[{ E }] {
      #|  ()
      #|}
      #|fn run() -> Unit {
      #|  handle Prompt::ask!() with {
      #|    Prompt::ask(resume) => wrap(resume)
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: RecursiveHandlerResidualEffect(Singleton({ index: 1 }, [EffectArgument(Parameter({ index: 2 }))])),
      #|    loc: {
      #|      start_offset: 252,
      #|      end_offset: 264,
      #|      start_line: 13,
      #|      start_column: 28,
      #|      end_line: 13,
      #|      end_column: 40,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "handler arm type binders retain their lexical kind" {
  let result = expect_typecheck_result(
    (
      #|effect Prompt {
      #|  ask[A]() -> Unit
      #|}
      #|fn run() -> Unit {
      #|  handle Prompt::ask![Int]() with {
      #|    Prompt::ask[T](resume) => {
      #|      let callback : () -> Unit ! T = fn () { () }
      #|      resume(())
      #|    }
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: KindMismatch(expected=Effect, actual=Type),
      #|    loc: {
      #|      start_offset: 170,
      #|      end_offset: 171,
      #|      start_line: 8,
      #|      start_column: 35,
      #|      end_line: 8,
      #|      end_column: 36,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
fn expect_first_handler_resume_callee_type(source : String) -> @types.Type {
  let result = expect_checked_source_result(source)
  guard result.source is Some(source_file) else {
    abort(@prettyprinter.render(result.diagnostics, width=100))
  }
  for declaration in source_file.declarations {
    if declaration is Function(declaration) {
      if find_first_handler_resume_callee_type(declaration.body) is Some(type_) {
        return type_
      }
    }
  }
  abort("expected handler resume call")
}

///|
fn find_first_handler_resume_callee_type(
  expression : @checked.CheckedExpr,
) -> @types.Type? {
  match expression {
    Handler(handlers~, ..) =>
      for handler in handlers {
        for operation in handler.operations {
          if operation.body is Some(body) {
            if find_first_handler_resume_callee_type(body) is Some(type_) {
              return Some(type_)
            }
          }
        }
      } nobreak {
        None
      }
    Derive(plan~, ..) => find_first_handler_resume_callee_type(plan.expansion)
    Call(callee~, arguments~, ..) => {
      if callee is Value(type_~, ..) {
        return Some(type_)
      }
      if find_first_handler_resume_callee_type(callee) is Some(type_) {
        return Some(type_)
      }
      for argument in arguments {
        if find_first_handler_resume_callee_type(argument.value) is Some(type_) {
          return Some(type_)
        }
      } nobreak {
        None
      }
    }
    Block(items~, result~, ..) => {
      for item in items {
        match item {
          Let(declaration) =>
            if find_first_handler_resume_callee_type(declaration.initializer)
              is Some(type_) {
              return Some(type_)
            }
          PatternLet(declaration) =>
            if find_first_handler_resume_callee_type(declaration.initializer)
              is Some(type_) {
              return Some(type_)
            }
          Expression(expression) =>
            if find_first_handler_resume_callee_type(expression) is Some(type_) {
              return Some(type_)
            }
          Function(declaration) =>
            if find_first_handler_resume_callee_type(declaration.body)
              is Some(type_) {
              return Some(type_)
            }
        }
      }
      find_first_handler_resume_callee_type(result)
    }
    If(condition~, then_branch~, else_branch~, ..) =>
      match find_first_handler_resume_callee_type(condition) {
        Some(type_) => Some(type_)
        None =>
          match find_first_handler_resume_callee_type(then_branch) {
            Some(type_) => Some(type_)
            None => find_first_handler_resume_callee_type(else_branch)
          }
      }
    Match(scrutinee~, arms~, ..) =>
      match find_first_handler_resume_callee_type(scrutinee) {
        Some(type_) => Some(type_)
        None => {
          for arm in arms {
            if find_first_handler_resume_callee_type(arm.body) is Some(type_) {
              return Some(type_)
            }
          }
          None
        }
      }
    GenericApplication(callee~, ..) =>
      find_first_handler_resume_callee_type(callee)
    FunctionEffectWiden(value~, ..) =>
      find_first_handler_resume_callee_type(value)
    OperationCall(arguments~, ..) | Variant(arguments~, ..) =>
      for argument in arguments {
        if find_first_handler_resume_callee_type(argument) is Some(type_) {
          return Some(type_)
        }
      } nobreak {
        None
      }
    Field(base~, ..) => find_first_handler_resume_callee_type(base)
    StructLiteral(fields~, ..) =>
      for field in fields {
        if find_first_handler_resume_callee_type(field.value) is Some(type_) {
          return Some(type_)
        }
      } nobreak {
        None
      }
    Literal(..)
    | Value(..)
    | CompilerIntrinsic(..)
    | ExternBinding(..)
    | ErrorRecovery(..)
    | FunctionLiteral(..) => None
  }
}

///|
test "typecheck accepts annotated effect operation call" {
  let result = expect_checked_source_result(
    (
      #|effect Console {
      #|  write(String) -> Unit
      #|}
      #|fn write_hello() -> Unit ! Console {
      #|  Console::write!("hi")
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|checked_source_typecheck_result {
      #|  checked {
      #|    effect Console#0 {
      #|      write#0(String) -> Unit
      #|    }
      #|    fn write_hello#0() -> Unit {
      #|      operation#0!("hi")
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck accepts explicit effect operation generic witnesses and handler binders" {
  let result = expect_checked_source_result(
    (
      #|effect Prompt {
      #|  choose[A](A, A) -> A
      #|}
      #|fn program() -> Int {
      #|  handle Prompt::choose![Int](40, 41) with {
      #|    Prompt::choose[T](left, right, resume) => resume(left)
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|checked_source_typecheck_result {
      #|  checked {
      #|    effect Prompt#0 {
      #|      choose#0[A#0 : Type](tparam#0, tparam#0) -> tparam#0
      #|    }
      #|    fn program#0() -> Int {
      #|      {
      #|        handle operation#0![Int](40, 41)
      #|        with effect#0 {
      #|          operation#0[T#1 : Type](left#1, right#2, resume#3) => resume#3(left#1)
      #|        }
      #|        final value#4 {
      #|          value#4
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
test "typecheck infers effect operation generic witnesses from payloads" {
  let result = expect_checked_source_result(
    (
      #|effect Prompt {
      #|  choose[A](A, A) -> A
      #|}
      #|fn choose_int() -> Int ! Prompt {
      #|  Prompt::choose!(1, 2)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|checked_source_typecheck_result {
      #|  checked {
      #|    effect Prompt#0 {
      #|      choose#0[A#0 : Type](tparam#0, tparam#0) -> tparam#0
      #|    }
      #|    fn choose_int#0() -> Int {
      #|      operation#0![Int](1, 2)
      #|    }
      #|  }
      #|  diagnostics {}
      #|}
    ),
  )
}

///|
test "typecheck elides unique generic effect and variant owners" {
  let result = expect_checked_source_result(
    (
      #|effect Schedule {
      #|  enqueue(Step) -> Unit
      #|}
      #|effect Async[E : Effect] {
      #|  suspend[A](((A) -> Unit ! E) -> Unit ! E) -> A
      #|}
      #|enum Step {
      #|  done(Int)
      #|  waiting[A](((A) -> Unit ! Schedule) -> Unit ! Schedule, (A) -> Step)
      #|}
      #|fn[A] ready(value : A) -> A ! Async[Schedule] {
      #|  suspend![A](fn (resume) { resume(value) })
      #|}
      #|fn run_task(task : () -> Int ! Async[Schedule]) -> Step {
      #|  handle task() with {
      #|    suspend[A](register, resume) => waiting[A](register, fn (value) { resume(value) })
      #|  } final value {
      #|    done(value)
      #|  }
      #|}
      #|fn[A] run_registration(register : ((A) -> Unit ! Schedule) -> Unit ! Schedule, resume : (A) -> Step) -> Step {
      #|  handle register(fn (value) {
      #|    let next : Step = resume(value)
      #|    enqueue!(next)
      #|  }) with {
      #|    enqueue(next, _continue) => next
      #|  } final _value {
      #|    done(0)
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|checked_source_typecheck_result {
      #|  checked {
      #|    effect Schedule#0 {
      #|      enqueue#0(type#0) -> Unit
      #|    }
      #|    effect Async#1[E#0 : Effect] {
      #|      suspend#1[A#1 : Type](((tparam#1) -> Unit ! tparam#0) -> Unit ! tparam#0) -> tparam#1
      #|    }
      #|    enum Step#0 {
      #|      done#0(Int)
      #|      waiting#1[A#2 : Type](((tparam#2) -> Unit ! effect#0) -> Unit ! effect#0, (tparam#2) -> type#0)
      #|    }
      #|    fn[A#3 : Type] ready#0(value#3 : tparam#3) -> tparam#3 {
      #|      operation#1![tparam#3](fn(resume#4 : (tparam#3) -> Unit ! effect#0) -> Unit {
      #|        resume#4(value#3)
      #|      })
      #|    }
      #|    fn run_task#1(task#5 : () -> Int ! effect#1[effect#0]) -> type#0 {
      #|      {
      #|        handle task#5()
      #|        with effect#1[effect#0] {
      #|          operation#1[A#4 : Type](register#6, resume#7) => variant#1[tparam#4](register#6, fn(value#8 : tparam#4) -> type#0 {
      #|            resume#7(value#8)
      #|          })
      #|        }
      #|        final value#9 {
      #|          variant#0(value#9)
      #|        }
      #|      }
      #|    }
      #|    fn[A#5 : Type] run_registration#2(register#10 : (
      #|      (tparam#5) -> Unit ! effect#0
      #|    ) -> Unit ! effect#0, resume#11 : (tparam#5) -> type#0) -> type#0 {
      #|      {
      #|        handle register#10(fn(value#12 : tparam#5) -> Unit {
      #|          let next#13 : type#0 = resume#11(value#12)
      #|          operation#0!(next#13)
      #|        })
      #|        with effect#0 {
      #|          operation#0(next#14, _continue#15) => next#14
      #|        }
      #|        final _value#16 {
      #|          variant#0(0)
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
test "typecheck accepts effect-kind generic witnesses for operations and variants" {
  let result = expect_checked_source_result(
    (
      #|effect Log {
      #|  log(Int) -> Unit
      #|}
      #|effect Coroutine[E : Effect] {
      #|  yield() -> Unit
      #|  spawn[A](() -> A ! { Coroutine[E], E }) -> Unit
      #|}
      #|enum Task[E : Effect] {
      #|  task[A](() -> A ! { Coroutine[E], E })
      #|}
      #|enum Packed[E : Effect] {
      #|  pack[A](() -> A ! { Coroutine[E], E })
      #|}
      #|fn child() -> Bool ! { Coroutine[Log], Log } {
      #|  let ignored_yield : Unit = Coroutine[Log]::yield!()
      #|  let ignored_log : Unit = Log::log!(1)
      #|  true
      #|}
      #|fn[A, E : Effect] spawn(body : () -> A ! { Coroutine[E], E }) -> Unit ! Coroutine[E] {
      #|  Coroutine[E]::spawn![A](body)
      #|}
      #|fn parent() -> Unit ! Coroutine[Log] {
      #|  let ignored_spawn : Unit = Coroutine[Log]::spawn![Bool](child)
      #|  spawn(child)
      #|}
      #|let task : Task[Log] = Task[Log]::task[Bool](child)
      #|fn[E : Effect] pack_spawn(body : () -> Bool ! { Coroutine[E], E }) -> Packed[E] {
      #|  handle Coroutine[E]::spawn![Bool](body) with {
      #|    Coroutine[E]::yield(resume) => Packed[E]::pack[Bool](body)
      #|    Coroutine[E]::spawn[A](body, resume) => Packed[E]::pack[A](body)
      #|  } final value {
      #|    Packed[E]::pack[Bool](body)
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
      #|      log#0(Int) -> Unit
      #|    }
      #|    effect Coroutine#1[E#0 : Effect] {
      #|      yield#1 -> Unit
      #|      spawn#2[A#1 : Type](() -> tparam#1 ! {effect#1[tparam#0], tparam#0}) -> Unit
      #|    }
      #|    enum Task#0[E#2 : Effect] {
      #|      task#0[A#3 : Type](() -> tparam#3 ! {effect#1[tparam#2], tparam#2})
      #|    }
      #|    enum Packed#1[E#4 : Effect] {
      #|      pack#1[A#5 : Type](() -> tparam#5 ! {effect#1[tparam#4], tparam#4})
      #|    }
      #|    fn child#0() -> Bool {
      #|      let ignored_yield#5 : Unit = operation#1!()
      #|      let ignored_log#6 : Unit = operation#0!(1)
      #|      true
      #|    }
      #|    fn[A#6 : Type, E#7 : Effect] spawn#1(body#7 : () -> tparam#6 ! {effect#1[tparam#7], tparam#7}) -> Unit {
      #|      operation#2![tparam#6](body#7)
      #|    }
      #|    fn parent#2() -> Unit {
      #|      let ignored_spawn#8 : Unit = operation#2![Bool](child#0)
      #|      spawn#1[Bool, effect#0](child#0)
      #|    }
      #|    let task#3 : type#0[effect#0] = variant#0[Bool](child#0)
      #|    fn[E#8 : Effect] pack_spawn#4(body#9 : () -> Bool ! {effect#1[tparam#8], tparam#8}) -> type#1[
      #|      tparam#8
      #|    ] {
      #|      {
      #|        handle operation#2![Bool](body#9)
      #|        with effect#1[tparam#8] {
      #|          operation#1(resume#10) => variant#1[Bool](body#9)
      #|          operation#2[A#9 : Type](body#11, resume#12) => variant#1[tparam#9](body#11)
      #|        }
      #|        final value#13 {
      #|          variant#1[Bool](body#9)
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
test "typecheck reports effect operation generic witness arity mismatch once" {
  let result = expect_typecheck_result(
    (
      #|effect Prompt {
      #|  choose[A](A, A) -> A
      #|}
      #|fn bad() -> Int ! Prompt {
      #|  Prompt::choose![Int, Bool](1, 2)
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[application_arity_mismatch effect operation generic arguments @ 6:3-6:35]
    ),
  )
}

///|
test "typecheck rejects operation call in pure function" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  write(String) -> Unit
      #|}
      #|fn bad() -> Unit {
      #|  Console::write!("hi")
      #|}
    ),
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: EffectMismatch(expected=Empty, actual=Singleton({ index: 0 }, [])),
      #|    loc: {
      #|      start_offset: 72,
      #|      end_offset: 99,
      #|      start_line: 5,
      #|      start_column: 18,
      #|      end_line: 7,
      #|      end_column: 2,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "typecheck accepts pure body under non-empty effect annotation" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  write(String) -> Unit
      #|}
      #|fn bad() -> Unit ! Console {
      #|  ()
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "typecheck propagates effectful named function call" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|fn read_int() -> Int ! Console {
      #|  Console::read!()
      #|}
      #|fn caller() -> Int ! Console {
      #|  read_int()
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
}

///|
test "typecheck rejects effectful function call in pure function" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|fn read_int() -> Int ! Console {
      #|  Console::read!()
      #|}
      #|fn caller() -> Int {
      #|  read_int()
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[effect_mismatch expected={} actual=effect#0 @ 8:20-10:2]
    ),
  )
}

///|
test "typecheck handler removes effect propagated through function call" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|fn read_int() -> Int ! Console {
      #|  Console::read!()
      #|}
      #|fn program() -> Int {
      #|  handle read_int() with {
      #|    Console::read(resume) => resume(41)
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
}

///|
test "typecheck propagates latent effect from function parameter call" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|fn call_read(f : () -> Int ! Console) -> Int ! Console {
      #|  f()
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
}

///|
test "typecheck checks operation payload type" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  write(String) -> Unit
      #|}
      #|fn bad() -> Unit ! Console {
      #|  Console::write!(1)
      #|}
    ),
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: TypeMismatch(expected=Primitive(String), actual=Primitive(Int)),
      #|    loc: {
      #|      start_offset: 102,
      #|      end_offset: 103,
      #|      start_line: 6,
      #|      start_column: 19,
      #|      end_line: 6,
      #|      end_column: 20,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "typecheck checks operation payload arity" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  write(String) -> Unit
      #|}
      #|fn bad() -> Unit ! Console {
      #|  Console::write!()
      #|}
    ),
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: ApplicationArityMismatch(label="effect operation arity"),
      #|    loc: {
      #|      start_offset: 86,
      #|      end_offset: 103,
      #|      start_line: 6,
      #|      start_column: 3,
      #|      end_line: 6,
      #|      end_column: 20,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "typecheck checks handler operation tables" {
  let result = expect_checked_source_result(
    (
      #|enum Choice {
      #|  left()
      #|  right()
      #|}
      #|effect Console {
      #|  read() -> Int
      #|  write(String) -> Unit
      #|  choose(Choice) -> Unit
      #|}
      #|fn program() -> Int {
      #|  handle Console::read!() with {
      #|    Console::read(resume) => 0
      #|    Console::write(message, resume2) => resume2(())
      #|    Console::choose(Choice::left(), resume3) => resume3(())
      #|    Console::choose(Choice::right(), resume4) => resume4(())
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result, width=100),
    content=(
      #|checked_source_typecheck_result {
      #|  checked {
      #|    enum Choice#0 {
      #|      left#0
      #|      right#1
      #|    }
      #|    effect Console#0 {
      #|      read#0 -> Int
      #|      write#1(String) -> Unit
      #|      choose#2(type#0) -> Unit
      #|    }
      #|    fn program#0() -> Int {
      #|      {
      #|        handle operation#0!()
      #|        with effect#0 {
      #|          operation#0(resume#1) => 0
      #|          operation#1(message#2, resume2#3) => resume2#3(())
      #|          operation#2(variant#0(), resume3#4) => resume3#4(())
      #|          operation#2(variant#1(), resume4#5) => resume4#5(())
      #|        }
      #|        final value#6 {
      #|          value#6
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
test "typecheck assigns resume binder function type" {
  let type_ = expect_first_handler_resume_callee_type(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|effect State {
      #|  get() -> Int
      #|}
      #|fn program() -> Int ! State {
      #|  handle Console::read!() with {
      #|    Console::read(resume) => resume(0)
      #|  } final value {
      #|    State::get!()
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(type_, width=100),
    content=(
      #|(Int) -> Int ! effect#1
    ),
  )
}

///|
test "typecheck resolves handler resume residual inside nested pure function" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|fn program() -> Int {
      #|  handle Console::read!() with {
      #|    Console::read(resume) => {
      #|      let callback : (Int) -> Int = fn (value) {
      #|        resume(value)
      #|      }
      #|      callback(0)
      #|    }
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
}

///|
test "typecheck rejects handler resume argument mismatch" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|fn program() -> Int {
      #|  handle Console::read!() with {
      #|    Console::read(resume) => resume("bad")
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[type_mismatch expected=Int actual=String @ 7:37-7:42]
    ),
  )
}

///|
test "typecheck rejects handler arm result mismatch" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|fn program() -> String {
      #|  handle Console::read!() with {
      #|    Console::read(resume) => 0
      #|  } final value {
      #|    "done"
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[type_mismatch expected=String actual=Int @ 7:30-7:31]
    ),
  )
}

///|
test "typecheck removes handled effect from handler residual effect" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|fn program() -> Int {
      #|  handle Console::read!() with {
      #|    Console::read(resume) => 0
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
}

///|
test "typecheck rejects handler for absent closed effect" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|fn program() -> Int {
      #|  handle 0 with {
      #|    Console::read(resume) => 0
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[effect_mismatch expected=effect#0 actual={} @ 6:3-10:4]
    ),
  )
}

///|
test "typecheck preserves unhandled residual effect" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|effect State {
      #|  get() -> Int
      #|}
      #|fn program() -> Int {
      #|  handle Console::read!() with {
      #|    Console::read(resume) => 0
      #|  } final value {
      #|    State::get!()
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[effect_mismatch expected={} actual=effect#1 @ 8:21-14:2]
    ),
  )
}

///|
test "typecheck preserves handler arm direct effects" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|effect State {
      #|  get() -> Int
      #|}
      #|fn program() -> Int {
      #|  handle Console::read!() with {
      #|    Console::read(resume) => State::get!()
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[effect_mismatch expected={} actual=effect#1 @ 8:21-14:2]
    ),
  )
}

///|
test "typecheck rechecks handler arms with final residual effect" {
  let result = expect_typecheck_result(
    (
      #|effect Prompt {
      #|  ask() -> Int
      #|}
      #|effect Log {
      #|  write() -> Unit
      #|}
      #|fn[E : Effect] compose(
      #|  first : (Int) -> Int ! E,
      #|  second : (Int) -> Int ! E
      #|) -> Int ! E {
      #|  first(second(0))
      #|}
      #|fn logged(value : Int) -> Int ! Log {
      #|  let _written : Unit = Log::write!()
      #|  value
      #|}
      #|fn run() -> Int ! Log {
      #|  handle Prompt::ask!() with {
      #|    Prompt::ask(resume) => compose(resume, logged)
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "typecheck measures effects around provisional handler generic evidence" {
  let result = expect_typecheck_result(
    (
      #|effect Prompt {
      #|  ask() -> Int
      #|}
      #|effect Log {
      #|  write() -> Unit
      #|}
      #|fn[E : Effect] invoke(callback : (Int) -> Int ! E) -> Int ! { Log, E } {
      #|  let _written : Unit = Log::write!()
      #|  callback(0)
      #|}
      #|fn run() -> Int ! Log {
      #|  handle Prompt::ask!() with {
      #|    Prompt::ask(resume) => invoke(resume)
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "handler measurement merges provisional exact and concrete lower bound" {
  let result = expect_typecheck_result(
    (
      #|effect Prompt {
      #|  ask() -> String
      #|}
      #|effect Log {
      #|  write() -> Unit
      #|}
      #|struct Carrier[_E : Effect] {
      #|  callback : (String) -> String ! _E
      #|}
      #|fn[E : Effect] pack(callback : (String) -> String ! E) -> Carrier[{ E }] {
      #|  Carrier::{ callback }
      #|}
      #|fn[E : Effect] invoke(
      #|  carrier : Carrier[{ E }],
      #|  callback : (String) -> String ! E
      #|) -> String ! E {
      #|  callback(carrier.callback("measured"))
      #|}
      #|fn logged(value : String) -> String ! Log {
      #|  let _written : Unit = Log::write!()
      #|  value
      #|}
      #|fn run() -> String ! Log {
      #|  handle Prompt::ask!() with {
      #|    Prompt::ask(resume) => invoke(pack(resume), logged)
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  debug_inspect(result.diagnostics, content="[]")
}

///|
test "typecheck rejects mixed handler effects" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|effect State {
      #|  get() -> Int
      #|}
      #|fn program() -> Int {
      #|  handle Console::read!() with {
      #|    Console::read(resume) => 0
      #|    State::get(resume2) => 1
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[mixed_handler_effects @ 11:5-11:29]
    ),
  )
}

///|
test "typecheck rejects duplicate handled effects" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|fn program() -> Int {
      #|  handle Console::read!() with {
      #|    Console::read(resume) => 0
      #|  } with {
      #|    Console::read(resume2) => 1
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[duplicate_handled_effect effect#0 @ 8:5-10:4]
    ),
  )
}

///|
test "typecheck rejects missing handler operation coverage" {
  let result = expect_typecheck_result(
    (
      #|enum Choice {
      #|  left()
      #|  right()
      #|}
      #|effect Console {
      #|  read() -> Int
      #|  choose(Choice) -> Unit
      #|}
      #|fn program() -> Int {
      #|  handle Console::read!() with {
      #|    Console::read(resume) => 0
      #|    Console::choose(Choice::left(), resume2) => resume2(())
      #|  } final value {
      #|    value
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[missing_handler_operation Console::choose @ 11:27-14:4]
    ),
  )
}

///|
test "typecheck rejects redundant handler operation arms" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  write(String) -> Unit
      #|}
      #|fn program() -> Int {
      #|  handle Console::write!("hi") with {
      #|    Console::write(_, resume) => resume(())
      #|    Console::write(message, resume2) => resume2(())
      #|  } final value {
      #|    0
      #|  }
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[unreachable_match_arm @ 8:5-8:52]
    ),
  )
}

///|
test "typecheck represents effect row variables" {
  let result = expect_typecheck_result(
    (
      #|fn[E : Effect] run(f : () -> Unit ! E) -> Unit ! E {
      #|  f()
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
}

///|
test "typecheck resolves import-free built-in Io effect" {
  let result = expect_typecheck_result(
    (
      #|fn run(action : () -> Unit ! Io) -> Unit ! Io {
      #|  action()
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
  debug_inspect(checked_function_effect(result, "run"), content="Io")
}

///|
test "typecheck does not let an effect alias shadow built-in Io" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  write(String) -> Unit
      #|}
      #|type Io = { Console }
      #|let write : (String) -> Unit ! Io = extern("%write")
      #|fn run() -> Unit ! Io {
      #|  write("hello")
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
  debug_inspect(checked_function_effect(result, "run"), content="Io")
}

///|
test "typecheck rejects generic arguments on built-in Io" {
  let result = expect_typecheck_result(
    (
      #|fn run(action : () -> Unit ! Io[Int]) -> Unit ! Io[Int] {
      #|  action()
      #|}
    ),
  )
  inspect(
    @prettyprinter.render(result.diagnostics, width=100),
    content=(
      #|[
      #|  type_arity_mismatch Io expected=0 actual=1 @ 2:30-2:37,
      #|  type_arity_mismatch Io expected=0 actual=1 @ 2:49-2:56
      #|]
    ),
  )
}

///|
test "typecheck expands effect set alias in function annotations" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|effect Log {
      #|  write(String) -> Unit
      #|}
      #|type UI : Effect = { Console, Log }
      #|fn program() -> Unit ! UI {
      #|  let ignored : Int = Console::read!()
      #|  Log::write!("ok")
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
  inspect(
    @prettyprinter.render(checked_function_effect(result, "program"), width=100),
    content=(
      #|{
      #|  effect#0,
      #|  effect#1
      #|}
    ),
  )
}

///|
test "typecheck applies generic effect set alias" {
  let result = expect_typecheck_result(
    (
      #|effect Coroutine {
      #|  pause() -> Unit
      #|}
      #|effect Log {
      #|  write(String) -> Unit
      #|}
      #|type Task[E : Effect] : Effect = { Coroutine, E }
      #|fn program() -> Unit ! Task[Log] {
      #|  let ignored : Unit = Coroutine::pause!()
      #|  Log::write!("ok")
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
  inspect(
    @prettyprinter.render(checked_function_effect(result, "program"), width=100),
    content=(
      #|{
      #|  effect#0,
      #|  effect#1
      #|}
    ),
  )
}

///|
test "typecheck normalizes expanded effect set alias" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|effect Log {
      #|  write(String) -> Unit
      #|}
      #|type Read = { Console }
      #|type UI = { Log, Read, Console }
      #|fn program() -> Unit ! UI {
      #|  let ignored : Int = Console::read!()
      #|  Log::write!("ok")
      #|}
    ),
  )
  inspect(@prettyprinter.render(result.diagnostics, width=100), content="[]")
  inspect(
    @prettyprinter.render(checked_function_effect(result, "program"), width=100),
    content=(
      #|{
      #|  effect#1,
      #|  effect#0
      #|}
    ),
  )
}

///|
test "typecheck reports effect alias cycle" {
  let result = expect_typecheck_result(
    (
      #|type A = { B }
      #|type B = { A }
      #|fn program() -> Unit ! A {
      #|  ()
      #|}
    ),
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: TypeAliasCycle(name="A"),
      #|    loc: {
      #|      start_offset: 38,
      #|      end_offset: 39,
      #|      start_line: 3,
      #|      start_column: 12,
      #|      end_line: 3,
      #|      end_column: 13,
      #|    },
      #|  },
      #|  {
      #|    kind: TypeAliasCycle(name="B"),
      #|    loc: {
      #|      start_offset: 23,
      #|      end_offset: 24,
      #|      start_line: 2,
      #|      start_column: 12,
      #|      end_line: 2,
      #|      end_column: 13,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "typecheck rejects type-kind alias in effect position" {
  let result = expect_typecheck_result(
    (
      #|type Answer = Int
      #|fn program() -> Unit ! Answer {
      #|  ()
      #|}
    ),
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: KindMismatch(expected=Effect, actual=Type),
      #|    loc: {
      #|      start_offset: 53,
      #|      end_offset: 59,
      #|      start_line: 3,
      #|      start_column: 24,
      #|      end_line: 3,
      #|      end_column: 30,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "typecheck validates explicit type alias result kinds" {
  let result = expect_typecheck_result(
    (
      #|effect Console {
      #|  read() -> Int
      #|}
      #|type Identity : [Type] -> Type = type[A] => A
      #|type WrongType : Type = { Console }
      #|type WrongEffect : Effect = Int
      #|type WrongConstructor : [Type] -> Type = Int
      #|type WrongValueType : Type = type[A] => A
    ),
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: KindMismatch(expected=Type, actual=Effect),
      #|    loc: {
      #|      start_offset: 110,
      #|      end_offset: 114,
      #|      start_line: 6,
      #|      start_column: 18,
      #|      end_line: 6,
      #|      end_column: 22,
      #|    },
      #|  },
      #|  {
      #|    kind: KindMismatch(expected=Effect, actual=Type),
      #|    loc: {
      #|      start_offset: 148,
      #|      end_offset: 154,
      #|      start_line: 7,
      #|      start_column: 20,
      #|      end_line: 7,
      #|      end_column: 26,
      #|    },
      #|  },
      #|  {
      #|    kind: KindMismatch(expected=Function([Type], Type), actual=Type),
      #|    loc: {
      #|      start_offset: 185,
      #|      end_offset: 199,
      #|      start_line: 8,
      #|      start_column: 25,
      #|      end_line: 8,
      #|      end_column: 39,
      #|    },
      #|  },
      #|  {
      #|    kind: KindMismatch(expected=Type, actual=Function([Type], Type)),
      #|    loc: {
      #|      start_offset: 228,
      #|      end_offset: 232,
      #|      start_line: 9,
      #|      start_column: 23,
      #|      end_line: 9,
      #|      end_column: 27,
      #|    },
      #|  },
      #|]
    ),
  )
}

///|
test "typecheck rejects type argument for effect alias parameter" {
  let result = expect_typecheck_result(
    (
      #|effect Coroutine {
      #|  yield() -> Unit
      #|}
      #|type Task[E : Effect] = { Coroutine, E }
      #|fn program() -> Unit ! Task[Int] {
      #|  ()
      #|}
    ),
  )
  debug_inspect(
    result.diagnostics,
    content=(
      #|[
      #|  {
      #|    kind: KindMismatch(expected=Effect, actual=Type),
      #|    loc: {
      #|      start_offset: 120,
      #|      end_offset: 123,
      #|      start_line: 6,
      #|      start_column: 29,
      #|      end_line: 6,
      #|      end_column: 32,
      #|    },
      #|  },
      #|]
    ),
  )
}
