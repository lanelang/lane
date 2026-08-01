///|
test "example 37 lifted snapshot has only known companion mismatches" {
  guard compile_source(example_37_regression_source())
    is Succeeded(compiled, warnings) else {
    abort("expected example 37 regression source to compile")
  }
  assert_eq(warnings.diagnostics(), [])
  guard compiled.entries() is [entry] else {
    abort("expected one executable entry")
  }
  let mut lifted_verification = None
  let elaborated = compiled.elaborate_entry_observed(entry, stage => {
    if stage is MonadicContinuationsLifted(lifted) {
      lifted_verification = Some(@buslane.verify_program(lifted))
    }
  })
  guard elaborated is Ok(_) else {
    abort("expected executable elaboration to complete")
  }
  guard lifted_verification is Some(verification) else {
    abort("expected to observe the monadic-lift boundary")
  }
  let diagnostics = verification.diagnostics()
  assert_false(
    diagnostics.any(diagnostic => diagnostic.kind is UnknownTypeParameter(_)),
  )
  let type_mismatches = diagnostics.filter(diagnostic => {
    diagnostic.kind is TypeMismatch(_)
  })
  assert_eq(type_mismatches.length(), 2)
  assert_eq(diagnostics.length(), 2)
}

///|
fn example_37_regression_source() -> String {
  (
    #|module Test
    #|
    #|effect Coroutine[E : Effect] {
    #|  yield() -> Unit
    #|  spawn[A](() -> A ! { Coroutine[E], E }) -> Unit
    #|}
    #|
    #|effect Log {
    #|  log(Unit) -> Unit
    #|}
    #|
    #|enum Task[E : Effect] {
    #|  task[A](() -> A ! { Coroutine[E], E })
    #|}
    #|
    #|enum Runnable[E : Effect] {
    #|  runnable(() -> Step[E] ! E)
    #|}
    #|
    #|enum Queue[E : Effect] {
    #|  empty()
    #|  node(Runnable[E], Queue[E])
    #|}
    #|
    #|enum Step[E : Effect] {
    #|  done()
    #|  yielded(() -> Step[E] ! E)
    #|  spawned[A](() -> A ! { Coroutine[E], E }, () -> Step[E] ! E)
    #|}
    #|
    #|struct Scheduler[E : Effect] {
    #|  queue : Queue[E]
    #|}
    #|
    #|fn[A, E : Effect] spawn(body : () -> A ! { Coroutine[E], E }) -> Unit ! Coroutine[E] {
    #|  Coroutine[E]::spawn![A](body)
    #|}
    #|
    #|fn[E : Effect] yield() -> Unit ! Coroutine[E] {
    #|  Coroutine[E]::yield!()
    #|}
    #|
    #|fn log() -> Unit ! Log {
    #|  Log::log!(())
    #|}
    #|
    #|fn[E : Effect] enqueue(queue : Queue[E], item : Runnable[E]) -> Queue[E] {
    #|  match queue {
    #|    empty() => Queue[E]::node(item, Queue[E]::empty())
    #|    node(head, tail) => Queue[E]::node(head, enqueue(tail, item))
    #|  }
    #|}
    #|
    #|fn[E : Effect] run_task(task_value : Task[E]) -> Step[E] ! E {
    #|  match task_value {
    #|    task[A](body) =>
    #|      handle body() with {
    #|        Coroutine[E]::yield(resume) => Step[E]::yielded(
    #|          fn() -> Step[E] ! E {
    #|            resume(())
    #|          }
    #|        )
    #|        Coroutine[E]::spawn[B](body, resume) => Step[E]::spawned[B](
    #|          body,
    #|          fn() -> Step[E] ! E {
    #|            resume(())
    #|          }
    #|        )
    #|      } final _value {
    #|        Step[E]::done()
    #|      }
    #|  }
    #|}
    #|
    #|fn[E : Effect] run_queue(scheduler : Scheduler[E]) -> Scheduler[E] ! E {
    #|  match scheduler.queue {
    #|    empty() => scheduler
    #|    node(runnable_step, rest) =>
    #|      match runnable_step {
    #|        runnable(run) => run_step(run(), Scheduler[E]::{ queue: rest })
    #|      }
    #|  }
    #|}
    #|
    #|fn[E : Effect] run_step(step : Step[E], scheduler : Scheduler[E]) -> Scheduler[E] ! E {
    #|  match step {
    #|    done() => run_queue(scheduler)
    #|    yielded(resume) => run_queue(
    #|      Scheduler[E]::{ queue: enqueue(scheduler.queue, Runnable[E]::runnable(resume)) }
    #|    )
    #|    spawned[A](body, resume) => {
    #|      let child : Runnable[E] =
    #|        Runnable[E]::runnable(
    #|          fn() -> Step[E] ! E {
    #|            run_task(Task[E]::task[A](body))
    #|          }
    #|        )
    #|      run_step(resume(), Scheduler[E]::{ queue: enqueue(scheduler.queue, child) })
    #|    }
    #|  }
    #|}
    #|
    #|fn collect_logs(scheduler : Scheduler[Log]) -> Scheduler[Log] {
    #|  handle run_queue(scheduler) with {
    #|    Log::log(_event, resume) => resume(())
    #|  } final scheduler {
    #|    scheduler
    #|  }
    #|}
    #|
    #|fn child() -> Unit ! { Coroutine[Log], Log } {
    #|  let _child_started : Unit = log()
    #|  let _child_yielded : Unit = yield[Log]()
    #|  log()
    #|}
    #|
    #|fn parent() -> Unit ! { Coroutine[Log], Log } {
    #|  let _parent_started : Unit = log()
    #|  let _child_spawned : Unit = spawn(child)
    #|  let _parent_yielded : Unit = yield[Log]()
    #|  log()
    #|}
    #|
    #|pub fn answer() -> Unit {
    #|  let _scheduler : Scheduler[Log] =
    #|    collect_logs(
    #|      Scheduler[Log]::{
    #|        queue: Queue[Log]::node(
    #|          Runnable[Log]::runnable(
    #|            fn() {
    #|              run_task(Task[Log]::task[Unit](parent))
    #|            }
    #|          ),
    #|          Queue[Log]::empty()
    #|        )
    #|      }
    #|    )
    #|  ()
    #|}
  )
}
