///|
fn effect_conformance_basic_io() -> String {
  (
    #|module Basic.Io
    #|pub let println : (String) -> Unit ! Io = extern("println")
  )
}

///|
fn compile_effect_conformance_image(
  source : String,
) -> @loisvm_bytecode.BytecodeImage raise {
  let result = compile_program_for_test(source, [effect_conformance_basic_io()])
  if !result.diagnostics().is_empty() {
    fail("effect conformance compilation failed: \{Repr(result.diagnostics())}")
  }
  let program = successful_compilation(result)
  guard find_entry(program.entries(), "main") is Ok(entry) else {
    fail("effect conformance source produced no main entry")
  }
  let executable = match program.elaborate_entry(entry) {
    Ok(executable) => executable
    Err(error) => fail("effect conformance elaboration failed: \{Repr(error)}")
  }
  match lower_executable_image(executable) {
    Ok(image) => image
    Err(error) => fail("effect conformance lowering failed: \{Repr(error)}")
  }
}

///|
fn effect_conformance_registry(
  output : Array[String],
) -> @loisvm_runtime.RuntimeRegistry {
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="println",
      abi_major=1,
      parameters=[String],
      result=Unit,
      invoke=(_context, arguments) => {
        guard arguments is [BorrowedString(line)] else {
          raise Failure(message="println expects one String argument")
        }
        output.push(line.to_string())
        Unit
      },
    ),
  )
  registry
}

///|
fn run_effect_conformance_interpreter(
  image : @loisvm_bytecode.BytecodeImage,
) -> Array[String] raise {
  let output : Array[String] = []
  let loaded = match
    @loisvm_interp.load(image, effect_conformance_registry(output)) {
    Ok(value) => value
    Err(error) => fail("LoisVM interpreter load failed: \{Repr(error)}")
  }
  assert_eq(loaded.new_instance().execute(), Ok(()))
  output
}

///|
fn run_effect_conformance_wasm(
  image : @loisvm_bytecode.BytecodeImage,
) -> Array[String] raise {
  let output : Array[String] = []
  let loaded = match
    @loisvm_wasm.load(image, effect_conformance_registry(output)) {
    Ok(value) => value
    Err(error) => fail("LoisVM Wasm load failed: \{Repr(error)}")
  }
  let instance = match loaded.new_instance() {
    Ok(value) => value
    Err(error) => fail("LoisVM Wasm instantiation failed: \{Repr(error)}")
  }
  assert_eq(instance.execute(), Ok(()))
  output
}

///|
fn assert_effect_erased_host_boundary(
  image : @loisvm_bytecode.BytecodeImage,
) -> Unit raise {
  let imports : Array[
    (
      String,
      Int,
      Array[@loisvm_bytecode.RuntimeValueKind],
      @loisvm_bytecode.RuntimeValueKind,
    ),
  ] = []
  for function in image.functions {
    if function is RuntimeImport(import_) {
      imports.push(
        (import_.symbol, import_.abi_major, import_.parameters, import_.result),
      )
    }
  }
  assert_eq(imports, [("println", 1, [String], Unit)])
}

///|
fn assert_effect_conformance(
  source : String,
  expected : Array[String],
) -> Unit raise {
  let image = compile_effect_conformance_image(source)
  assert_effect_erased_host_boundary(image)
  let interpreter_output = run_effect_conformance_interpreter(image)
  let wasm_output = run_effect_conformance_wasm(image)
  assert_eq(interpreter_output, expected)
  assert_eq(wasm_output, expected)
  assert_eq(interpreter_output, wasm_output)
}

///|
test "struct fields evaluate in source order with reversed existential witnesses" {
  assert_effect_conformance(
    (
      #|module Main
      #|import Basic.Io.*
      #|struct Hide {
      #|  type A : Type
      #|  type B : Type
      #|  first : A
      #|  second : B
      #|}
      #|fn mark_int(label : String, value : I64) -> I64 ! Io {
      #|  println(label)
      #|  value
      #|}
      #|fn mark_bool(label : String, value : Bool) -> Bool ! Io {
      #|  println(label)
      #|  value
      #|}
      #|pub fn main() -> Unit ! Io {
      #|  let _hidden : Hide = Hide::{
      #|    B = Bool,
      #|    A = I64,
      #|    second: mark_bool("second", true),
      #|    first: mark_int("first", 1),
      #|  };
      #|  ()
      #|}
    ),
    ["second", "first"],
  )
}

///|
test "effect widening preserves indirect call ABI across production backends" {
  assert_effect_conformance(
    (
      #|module Main
      #|import Basic.Io.*
      #|fn pure_message() -> String {
      #|  "widened"
      #|}
      #|fn declared_message() -> String ! Io {
      #|  "declared"
      #|}
      #|fn invoke(callback : () -> String ! Io) -> Unit ! Io {
      #|  println(callback())
      #|}
      #|pub fn main() -> Unit ! Io {
      #|  invoke(pure_message)
      #|  invoke(fn() { "literal" })
      #|  invoke(declared_message)
      #|}
    ),
    ["widened", "literal", "declared"],
  )
}

///|
test "chained generic effect handlers preserve layout witnesses" {
  assert_effect_conformance(
    (
      #|module Main
      #|import Basic.Io.*
      #|
      #|effect Ask {
      #|  read() -> I64
      #|}
      #|
      #|effect Log {
      #|  write(I64) -> Unit
      #|}
      #|
      #|fn program() -> I64 ! { Ask, Log } {
      #|  let value = Ask::read!()
      #|  let _ = Log::write!(value)
      #|  value
      #|}
      #|
      #|fn[A, E : Effect] handle_ask(task : () -> A ! { Ask, E }) -> () -> A ! E {
      #|  fn() {
      #|    handle task() with {
      #|      Ask::read(resume) => resume(42)
      #|    } final value {
      #|      value
      #|    }
      #|  }
      #|}
      #|
      #|fn[A, E : Effect] handle_log(task : () -> A ! { Log, E }) -> () -> A ! E {
      #|  fn() {
      #|    handle task() with {
      #|      Log::write(_value, resume) => resume(())
      #|    } final value {
      #|      value
      #|    }
      #|  }
      #|}
      #|
      #|let handled_value : I64 = handle_log(handle_ask(program))()
      #|
      #|pub fn main() -> Unit ! Io {
      #|  let _value = handled_value
      #|  println("42")
      #|}
    ),
    ["42"],
  )
}

///|
test "algebraic effect widening preserves anonymous function ABI" {
  assert_effect_conformance(
    (
      #|module Main
      #|import Basic.Io.*
      #|effect Read {
      #|  read() -> String
      #|}
      #|fn invoke(callback : () -> String ! Read) -> String ! Read {
      #|  callback()
      #|}
      #|pub fn main() -> Unit ! Io {
      #|  let message : String = handle invoke(fn() { "literal" }) with {
      #|    Read::read(resume) => resume("unused")
      #|  } final value {
      #|    value
      #|  }
      #|  println(message)
      #|}
    ),
    ["literal"],
  )
}

///|
test "handler measurement preserves exact effect context in production lowering" {
  assert_effect_conformance(
    (
      #|module Main
      #|import Basic.Io.*
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
      #|fn run() -> String ! Log {
      #|  handle Prompt::ask!() with {
      #|    Prompt::ask(resume) => invoke(
      #|      resume,
      #|      Carrier[{ Log }]::{ value: "measured" },
      #|    )
      #|  } final value {
      #|    value
      #|  }
      #|}
      #|pub fn main() -> Unit ! Io {
      #|  let result : String = handle run() with {
      #|    Log::write(resume) => resume(())
      #|  } final value {
      #|    value
      #|  }
      #|  println(result)
      #|}
    ),
    ["measured"],
  )
}

///|
test "effect instances preserve nested forall binder kinds" {
  assert_effect_conformance(
    (
      #|module Main
      #|import Basic.Io.*
      #|type TypePoly = [_A]() -> Unit
      #|type EffectPoly = [_E : Effect]() -> Unit
      #|effect Carrier[_T] {
      #|  ask() -> Bool
      #|}
      #|fn both() -> Bool ! { Carrier[TypePoly], Carrier[EffectPoly] } {
      #|  let first = Carrier[TypePoly]::ask!()
      #|  let second = Carrier[EffectPoly]::ask!()
      #|  if first { second } else { false }
      #|}
      #|pub fn main() -> Unit ! Io {
      #|  let result = handle both() with {
      #|    Carrier[TypePoly]::ask(resume) => resume(true)
      #|  } with {
      #|    Carrier[EffectPoly]::ask(resume) => resume(false)
      #|  } final value {
      #|    value
      #|  }
      #|  if result {
      #|    println("true")
      #|  } else {
      #|    println("false")
      #|  }
      #|}
    ),
    ["false"],
  )
}

///|
test "generic effect rows preserve nested forall binder kinds" {
  assert_effect_conformance(
    (
      #|module Main
      #|import Basic.Io.*
      #|type TypePoly = [_A]() -> Unit
      #|type EffectPoly = [_E : Effect]() -> Unit
      #|effect Carrier[_T] {
      #|  ask() -> Bool
      #|}
      #|fn[E : Effect] run(action : () -> Bool ! E) -> Bool ! E {
      #|  action()
      #|}
      #|fn both() -> Bool ! { Carrier[TypePoly], Carrier[EffectPoly] } {
      #|  let first = Carrier[TypePoly]::ask!()
      #|  let second = Carrier[EffectPoly]::ask!()
      #|  if first { second } else { false }
      #|}
      #|pub fn main() -> Unit ! Io {
      #|  let result = handle run[{ Carrier[TypePoly], Carrier[EffectPoly] }](both) with {
      #|    Carrier[TypePoly]::ask(resume) => resume(true)
      #|  } with {
      #|    Carrier[EffectPoly]::ask(resume) => resume(false)
      #|  } final value {
      #|    value
      #|  }
      #|  if result {
      #|    println("true")
      #|  } else {
      #|    println("false")
      #|  }
      #|}
    ),
    ["false"],
  )
}

///|
test "effect lowering preserves a resumed operation result across branching" {
  assert_effect_conformance(
    (
      #|module Main
      #|import Basic.Io.*
      #|effect First {
      #|  ask() -> Bool
      #|}
      #|fn choose() -> Unit ! First {
      #|  let result = First::ask!()
      #|  if result { () } else { () }
      #|}
      #|pub fn main() -> Unit ! Io {
      #|  handle choose() with {
      #|    First::ask(resume) => resume(false)
      #|  } final value {
      #|    value
      #|  }
      #|  println("after")
      #|}
    ),
    ["after"],
  )
}

///|
fn interpreter_resolution_error(
  image : @loisvm_bytecode.BytecodeImage,
  registry : @loisvm_runtime.RuntimeRegistry,
) -> @loisvm_runtime.RuntimeImportResolutionError raise {
  match @loisvm_interp.load(image, registry) {
    Err(error) => error
    Ok(_) => fail("expected LoisVM interpreter load to fail")
  }
}

///|
fn wasm_resolution_error(
  image : @loisvm_bytecode.BytecodeImage,
  registry : @loisvm_runtime.RuntimeRegistry,
) -> @loisvm_runtime.RuntimeImportResolutionError raise {
  match @loisvm_wasm.load(image, registry) {
    Err(RuntimeImportResolution(error~)) => error
    Err(error) => fail("unexpected LoisVM Wasm load failure: \{Repr(error)}")
    Ok(_) => fail("expected LoisVM Wasm load to fail")
  }
}

///|
fn effect_conformance_failing_registry(
  message : String,
) -> @loisvm_runtime.RuntimeRegistry {
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="println",
      abi_major=1,
      parameters=[String],
      result=Unit,
      invoke=(_context, _arguments) => raise Failure(message~),
    ),
  )
  registry
}

///|
fn run_effect_conformance_interpreter_failure(
  image : @loisvm_bytecode.BytecodeImage,
  registry : @loisvm_runtime.RuntimeRegistry,
) -> Result[Unit, @loisvm_runtime.ExecutionError] raise {
  let loaded = match @loisvm_interp.load(image, registry) {
    Ok(value) => value
    Err(error) => fail("LoisVM interpreter load failed: \{Repr(error)}")
  }
  loaded.new_instance().execute()
}

///|
fn run_effect_conformance_wasm_failure(
  image : @loisvm_bytecode.BytecodeImage,
  registry : @loisvm_runtime.RuntimeRegistry,
) -> Result[Unit, @loisvm_runtime.ExecutionError] raise {
  let loaded = match @loisvm_wasm.load(image, registry) {
    Ok(value) => value
    Err(error) => fail("LoisVM Wasm load failed: \{Repr(error)}")
  }
  let instance = match loaded.new_instance() {
    Ok(value) => value
    Err(error) => fail("LoisVM Wasm instantiation failed: \{Repr(error)}")
  }
  instance.execute()
}

///|
test "runtime import resolution agrees across production backends" {
  let image = compile_effect_conformance_image(
    (
      #|module Main
      #|import Basic.Io.*
      #|pub fn main() -> Unit ! Io {
      #|  println("hello")
      #|}
    ),
  )
  let missing = @loisvm_runtime.RuntimeRegistry::new()
  let incompatible = @loisvm_runtime.RuntimeRegistry::new()
  incompatible.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="println",
      abi_major=2,
      parameters=[String],
      result=Unit,
      invoke=(_context, _arguments) => Unit,
    ),
  )
  debug_inspect(
    (
      interpreter_resolution_error(image, missing),
      wasm_resolution_error(image, missing),
      interpreter_resolution_error(image, incompatible),
      wasm_resolution_error(image, incompatible),
    ),
    content=(
      #|(
      #|  UnresolvedImport(symbol="println"),
      #|  UnresolvedImport(symbol="println"),
      #|  AbiMismatch(symbol="println", expected_major=1, actual_major=2),
      #|  AbiMismatch(symbol="println", expected_major=1, actual_major=2),
      #|)
    ),
  )
}

///|
test "runtime import failures agree across production backends" {
  let image = compile_effect_conformance_image(
    (
      #|module Main
      #|import Basic.Io.*
      #|pub fn main() -> Unit ! Io {
      #|  println("hello")
      #|}
    ),
  )
  let interpreter = run_effect_conformance_interpreter_failure(
    image,
    effect_conformance_failing_registry("boom"),
  )
  let wasm = run_effect_conformance_wasm_failure(
    image,
    effect_conformance_failing_registry("boom"),
  )
  debug_inspect(
    (interpreter, wasm),
    content=(
      #|(
      #|  Err(RuntimeImportFailure(symbol="println", message="boom")),
      #|  Err(RuntimeImportFailure(symbol="println", message="boom")),
      #|)
    ),
  )
}

///|
test "first-class effect-polymorphic values lower through explicit application" {
  assert_effect_conformance(
    (
      #|module Main
      #|import Basic.Io.*
      #|type EffectPoly = [E : Effect]() -> Unit ! E
      #|fn make() -> EffectPoly {
      #|  fn[E : Effect]() -> Unit ! E { () }
      #|}
      #|fn[E : Effect] named() -> Unit ! E {
      #|  ()
      #|}
      #|fn use(value : EffectPoly) -> Unit {
      #|  value[{}]()
      #|}
      #|pub fn main() -> Unit ! Io {
      #|  let local : EffectPoly = fn[E : Effect]() -> Unit ! E { () }
      #|  use(local)
      #|  use(make())
      #|  use(named)
      #|  println("ok")
      #|}
    ),
    ["ok"],
  )
}

///|
test "effect lowering agrees for a direct deep handler and runtime effect" {
  assert_effect_conformance(
    (
      #|module Main
      #|import Basic.Io.*
      #|effect Tick {
      #|  tick() -> Unit
      #|}
      #|pub fn main() -> Unit ! Io {
      #|  let _handled : Unit = handle Tick::tick!() with {
      #|    Tick::tick(resume) => {
      #|      let _written : Unit = println("handled")
      #|      resume(())
      #|    }
      #|  } final _value {
      #|    println("final")
      #|  }
      #|  println("after")
      #|}
    ),
    ["handled", "final", "after"],
  )
}

///|
test "effect lowering agrees for nested deep handlers and arm effects" {
  assert_effect_conformance(
    (
      #|module Main
      #|import Basic.Io.*
      #|effect Ping {
      #|  ping() -> Unit
      #|}
      #|pub fn main() -> Unit ! Io {
      #|  let _handled : Unit = handle {
      #|    handle Ping::ping!() with {
      #|      Ping::ping(resume) => {
      #|        let _inner : Unit = println("inner")
      #|        let _outer : Unit = Ping::ping!()
      #|        resume(())
      #|      }
      #|    } final value {
      #|      let _inner_final : Unit = println("inner-final")
      #|      value
      #|    }
      #|  } with {
      #|    Ping::ping(resume) => {
      #|      let _outer : Unit = println("outer")
      #|      resume(())
      #|    }
      #|  } final value {
      #|    let _outer_final : Unit = println("outer-final")
      #|    value
      #|  }
      #|  println("after")
      #|}
    ),
    ["inner", "outer", "inner-final", "outer-final", "after"],
  )
}

///|
test "effect lowering agrees for reusable resumptions with owned captures" {
  assert_effect_conformance(
    (
      #|module Main
      #|import Basic.Io.*
      #|effect Tick {
      #|  tick() -> Unit
      #|}
      #|fn resume_once() -> Unit ! Io {
      #|  let captured : String = "single"
      #|  handle {
      #|    let _tick : Unit = Tick::tick!()
      #|    println(captured)
      #|  } with {
      #|    Tick::tick(resume) => resume(())
      #|  } final value {
      #|    value
      #|  }
      #|}
      #|fn resume_twice() -> Unit ! Io {
      #|  let captured : String = "multi"
      #|  handle {
      #|    let _tick : Unit = Tick::tick!()
      #|    println(captured)
      #|  } with {
      #|    Tick::tick(resume) => {
      #|      let _first : Unit = resume(())
      #|      resume(())
      #|    }
      #|  } final value {
      #|    value
      #|  }
      #|}
      #|pub fn main() -> Unit ! Io {
      #|  let _single : Unit = resume_once()
      #|  resume_twice()
      #|}
    ),
    ["single", "multi", "multi"],
  )
}

///|
test "effect lowering agrees for generic resumptions with layout witnesses" {
  assert_effect_conformance(
    (
      #|module Main
      #|import Basic.Io.*
      #|effect Prompt {
      #|  choose[A](A, A) -> A
      #|}
      #|fn choose_message() -> String ! Prompt {
      #|  Prompt::choose![String]("selected", "ignored")
      #|}
      #|pub fn main() -> Unit ! Io {
      #|  let selected : String = handle choose_message() with {
      #|    Prompt::choose[T](left, _right, resume) => resume(left)
      #|  } final value {
      #|    value
      #|  }
      #|  println(selected)
      #|}
    ),
    ["selected"],
  )
}

// A `handle` in statement position is a dead binding whose initialiser is the
// whole installation. Deleting it is only sound when nothing it would have run
// has an effect, and after selective CPS the handler's arms live inside a
// dictionary the installed call receives. These pin each source of residual
// effect separately, so a regression cannot hide behind another one covering it.

///|
test "statement-position handle runs an arm that performs Io" {
  assert_effect_conformance(
    (
      #|module Main
      #|import Basic.Io.*
      #|effect Probe {
      #|  ping() -> Unit
      #|}
      #|fn body() -> Unit ! Probe {
      #|  Probe::ping!()
      #|}
      #|pub fn main() -> Unit ! Io {
      #|  handle body() with {
      #|    Probe::ping(resume) => {
      #|      println("arm")
      #|      resume(())
      #|    }
      #|  } final _value {
      #|    ()
      #|  }
      #|  println("after")
      #|}
    ),
    ["arm", "after"],
  )
}

///|
test "statement-position handle runs a final branch that performs Io" {
  assert_effect_conformance(
    (
      #|module Main
      #|import Basic.Io.*
      #|effect Probe {
      #|  ping() -> Unit
      #|}
      #|fn body() -> Unit ! Probe {
      #|  Probe::ping!()
      #|}
      #|pub fn main() -> Unit ! Io {
      #|  handle body() with {
      #|    Probe::ping(resume) => resume(())
      #|  } final _value {
      #|    println("final")
      #|  }
      #|  println("after")
      #|}
    ),
    ["final", "after"],
  )
}

///|
test "statement-position handle runs a handled expression that performs Io" {
  assert_effect_conformance(
    (
      #|module Main
      #|import Basic.Io.*
      #|effect Probe {
      #|  ping() -> Unit
      #|}
      #|fn body() -> Unit ! { Probe, Io } {
      #|  println("subject")
      #|  Probe::ping!()
      #|}
      #|pub fn main() -> Unit ! Io {
      #|  handle body() with {
      #|    Probe::ping(resume) => resume(())
      #|  } final _value {
      #|    ()
      #|  }
      #|  println("after")
      #|}
    ),
    ["subject", "after"],
  )
}

///|
test "statement-position handle installed inside an arm still runs" {
  assert_effect_conformance(
    (
      #|module Main
      #|import Basic.Io.*
      #|effect Probe {
      #|  ping() -> Unit
      #|}
      #|effect Inner {
      #|  tick() -> Unit
      #|}
      #|fn body() -> Unit ! Probe {
      #|  Probe::ping!()
      #|}
      #|fn inner_body() -> Unit ! Inner {
      #|  Inner::tick!()
      #|}
      #|pub fn main() -> Unit ! Io {
      #|  handle body() with {
      #|    Probe::ping(resume) => {
      #|      handle inner_body() with {
      #|        Inner::tick(inner_resume) => {
      #|          println("inner-arm")
      #|          inner_resume(())
      #|        }
      #|      } final _inner {
      #|        ()
      #|      }
      #|      resume(())
      #|    }
      #|  } final _value {
      #|    ()
      #|  }
      #|  println("after")
      #|}
    ),
    ["inner-arm", "after"],
  )
}
