///|
fn effect_conformance_basic_io() -> String {
  (
    #|module Basic.Io
    #|import Basic.Data.Void.{ Void }
    #|import Basic.Wasm.Abi.{ WasmAddress, address, allocate, write_address, write_bytes, write_i32 }
    #|let string_to_bytes : (String) -> Bytes = builtin("%string_to_bytes")
    #|let bytes_concat : (Bytes, Bytes) -> Bytes = builtin("%bytes_concat")
    #|let bytes_length : (Bytes) -> I64 = builtin("%bytes_length")
    #|let i64_add : (I64, I64) -> I64 = builtin("%i64_add")
    #|let i64_to_i32 : (I64) -> I32 = builtin("%i64_to_i32")
    #|let wasi_fd_write : (I32, WasmAddress, I32, WasmAddress) -> I32 ! Io = extern("wasi_snapshot_preview1", "fd_write")
    #|pub fn println(value : String) -> Unit ! Io {
    #|  let bytes = bytes_concat(string_to_bytes(value), string_to_bytes("\n"))
    #|  let length = bytes_length(bytes)
    #|  let frame = allocate(i64_add(12, length))
    #|  write_bytes(frame, 12, bytes)
    #|  write_address(frame, 0, frame, 12i32)
    #|  write_i32(frame, 4, i64_to_i32(length))
    #|  write_i32(frame, 8, 0i32)
    #|  let _errno = wasi_fd_write(1i32, address(frame, 0i32), 1i32, address(frame, 8i32))
    #|  ()
    #|}
    #|pub let panic : (String) -> Void ! Panic = builtin("%panic")
  )
}

///|
fn effect_conformance_basic_wasm_abi() -> String {
  (
    #|module Basic.Wasm.Abi
    #|let make : (I64) -> ByteBuffer ! Io = builtin("%byte_buffer_make")
    #|let write_bytes_builtin : (ByteBuffer, I64, Bytes) -> Unit ! Io = builtin("%byte_buffer_write_bytes")
    #|let write_i32_builtin : (ByteBuffer, I64, I32) -> Unit ! Io = builtin("%byte_buffer_write_i32")
    #|let write_address_builtin : (ByteBuffer, I64, ByteBuffer, I32) -> Unit ! Io = builtin("%byte_buffer_write_address")
    #|let read_i32_builtin : (ByteBuffer, I64) -> I32 ! Io = builtin("%byte_buffer_read_i32")
    #|pub struct WasmAddress { storage : ByteBuffer; offset : I32 }
    #|pub fn allocate(size : I64) -> ByteBuffer ! Io { make(size) }
    #|pub fn address(storage : ByteBuffer, offset : I32) -> WasmAddress { WasmAddress::{ storage, offset } }
    #|pub fn write_bytes(storage : ByteBuffer, index : I64, source : Bytes) -> Unit ! Io { write_bytes_builtin(storage, index, source) }
    #|pub fn write_i32(storage : ByteBuffer, index : I64, value : I32) -> Unit ! Io { write_i32_builtin(storage, index, value) }
    #|pub fn write_address(storage : ByteBuffer, index : I64, target : ByteBuffer, offset : I32) -> Unit ! Io { write_address_builtin(storage, index, target, offset) }
    #|pub fn read_i32(storage : ByteBuffer, index : I64) -> I32 ! Io { read_i32_builtin(storage, index) }
  )
}

///|
fn effect_conformance_basic_void() -> String {
  (
    #|module Basic.Data.Void
    #|pub enum Void {}
    #|pub fn[T] absurd(value : Void) -> T { match value {} }
  )
}

///|
fn compile_effect_conformance_image(
  source : String,
) -> @physical.PhysicalProgram raise {
  let result = compile_program_for_test(source, [
    effect_conformance_basic_io(),
    effect_conformance_basic_void(),
    effect_conformance_basic_wasm_abi(),
  ])
  if !result.diagnostics().is_empty() {
    fail("effect conformance compilation failed: \{Repr(result.diagnostics())}")
  }
  let program = successful_compilation(result)
  let mut main = None
  for entry in program.entries() {
    if entry.name() == "main" {
      main = Some(entry)
    }
  }
  guard main is Some(entry) else {
    fail("effect conformance source produced no main entry")
  }
  let executable = match
    program.elaborate_entry(entry, conformance_execution_profile()) {
    Ok(executable) => executable
    Err(error) => fail("effect conformance elaboration failed: \{Repr(error)}")
  }
  match @physical_lowering.lower_executable_program_to_physical(executable) {
    Ok(image) => image.image()
    Err(error) => fail("effect conformance lowering failed: \{Repr(error)}")
  }
}

///|
fn effect_conformance_output(bytes : Array[Byte]) -> Array[String] raise {
  @utf8.decode(Bytes::from_array(bytes))
  .split("\n")
  .filter(line => line != "")
  .map(line => line.to_owned())
  .to_array()
}

///|
fn run_effect_conformance(
  image : @physical.PhysicalProgram,
  mode : @lane_wasm_runtime.ExecutionMode,
) -> Array[String] raise {
  let (result, output) = execute_effect_conformance(image, mode)
  assert_eq(result, Ok(Returned))
  output
}

///|
fn execute_effect_conformance(
  image : @physical.PhysicalProgram,
  mode : @lane_wasm_runtime.ExecutionMode,
) -> (
  Result[@lane_runtime.ExecutionOutcome, @lane_runtime.ExecutionError],
  Array[String],
) raise {
  let (result, stdout, _) = execute_effect_conformance_with_stderr(image, mode)
  (result, stdout)
}

///|
fn execute_effect_conformance_with_stderr(
  image : @physical.PhysicalProgram,
  mode : @lane_wasm_runtime.ExecutionMode,
) -> (
  Result[@lane_runtime.ExecutionOutcome, @lane_runtime.ExecutionError],
  Array[String],
  Array[String],
) raise {
  let output : Array[Byte] = []
  let error_output : Array[Byte] = []
  let loaded = match
    load_physical(
      image,
      mode~,
      wasi_stdout=Some(bytes => output.append(bytes.to_array())),
      wasi_stderr=Some(bytes => error_output.append(bytes.to_array())),
    ) {
    Ok(value) => value
    Err(error) => fail("WebAssembly load failed: \{Repr(error)}")
  }
  (
    loaded.execute(),
    effect_conformance_output(output),
    effect_conformance_output(error_output),
  )
}

///|
fn run_effect_conformance_interpreter(
  image : @physical.PhysicalProgram,
) -> Array[String] raise {
  run_effect_conformance(image, Interpreter)
}

///|
fn run_effect_conformance_wasm(
  image : @physical.PhysicalProgram,
) -> Array[String] raise {
  run_effect_conformance(image, Jit)
}

///|
fn assert_effect_erased_host_boundary(
  image : @physical.PhysicalProgram,
) -> Unit raise {
  let imports : Array[@wasm_abi.ImportContract] = []
  for function in image.functions {
    if function is RuntimeImport(import_) {
      imports.push(import_)
    }
  }
  assert_eq(imports, [
    @wasm_abi.wasi_preview1_import("fd_write").unwrap().contract(),
  ])
  let adapter_bodies = image.functions.filter_map(function => {
    if function is PhysicalBody(body) &&
      body.blocks.any(block => {
        block.instructions.any(instruction => {
          instruction is CallRuntimeImport(_, _, _)
        })
      }) {
      Some(body)
    } else {
      None
    }
  })
  assert_eq(adapter_bodies.length(), 1)
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
fn assert_effect_conformance_traps(source : String) -> Unit raise {
  let image = compile_effect_conformance_image(source)
  let (interpreter, interpreter_output) = execute_effect_conformance(
    image,
    Interpreter,
  )
  let (jit, jit_output) = execute_effect_conformance(image, Jit)
  assert_true(interpreter is Err(EngineTrap(detail=_)))
  assert_true(jit is Err(EngineTrap(detail=_)))
  assert_eq(interpreter_output, [])
  assert_eq(jit_output, [])
}

///|
test "guest addresses reject offsets outside their buffer" {
  assert_effect_conformance_traps(
    (
      #|module Main
      #|import Basic.Wasm.Abi.{ WasmAddress, address, allocate }
      #|let fd_write : (I32, WasmAddress, I32, WasmAddress) -> I32 ! Io = extern("wasi_snapshot_preview1", "fd_write")
      #|pub fn main() -> Unit ! Io {
      #|  let frame = allocate(12)
      #|  let _errno = fd_write(1i32, address(frame, 13i32), 0i32, address(frame, 8i32))
      #|  ()
      #|}
    ),
  )
}

///|
test "buffer address writes reject out-of-bounds destinations" {
  assert_effect_conformance_traps(
    (
      #|module Main
      #|import Basic.Wasm.Abi.{ WasmAddress, address, allocate, write_address }
      #|let fd_write : (I32, WasmAddress, I32, WasmAddress) -> I32 ! Io = extern("wasi_snapshot_preview1", "fd_write")
      #|pub fn main() -> Unit ! Io {
      #|  let frame = allocate(12)
      #|  write_address(frame, 10, frame, 0i32)
      #|  let _errno = fd_write(1i32, address(frame, 0i32), 0i32, address(frame, 8i32))
      #|  ()
      #|}
    ),
  )
}

///|
test "host writes remain visible through the effectful ByteBuffer API" {
  assert_effect_conformance(
    (
      #|module Main
      #|import Basic.Io.{ println }
      #|import Basic.Wasm.Abi.{ WasmAddress, address, allocate, read_i32, write_address, write_bytes, write_i32 }
      #|let string_to_bytes : (String) -> Bytes = builtin("%string_to_bytes")
      #|let i32_equal : (I32, I32) -> Bool = builtin("%i32_equal")
      #|let fd_write : (I32, WasmAddress, I32, WasmAddress) -> I32 ! Io = extern("wasi_snapshot_preview1", "fd_write")
      #|pub fn main() -> Unit ! Io {
      #|  let frame = allocate(14)
      #|  write_bytes(frame, 12, string_to_bytes("x\n"))
      #|  write_address(frame, 0, frame, 12i32)
      #|  write_i32(frame, 4, 2i32)
      #|  write_i32(frame, 8, 0i32)
      #|  let _errno = fd_write(1i32, address(frame, 0i32), 1i32, address(frame, 8i32))
      #|  if i32_equal(read_i32(frame, 8), 2i32) {
      #|    println("count-ok")
      #|  } else {
      #|    println("count-bad")
      #|  }
      #|}
    ),
    ["x", "count-ok"],
  )
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
      #|pub fn main() -> Unit ! { Io, Panic } {
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
test "statement-position panic is fatal and does not continue on either backend" {
  let image = compile_effect_conformance_image(
    (
      #|module Main
      #|import Basic.Io.*
      #|import Basic.Data.Void.{ absurd }
      #|pub fn main() -> Unit ! { Io, Panic } {
      #|  absurd[Unit](panic("boom"))
      #|  println("after")
      #|}
    ),
  )
  let (interpreter, interpreter_output, interpreter_error) = execute_effect_conformance_with_stderr(
    image,
    Interpreter,
  )
  let (wasm, wasm_output, wasm_error) = execute_effect_conformance_with_stderr(
    image,
    Jit,
  )
  debug_inspect(
    (
      interpreter, interpreter_output, interpreter_error, wasm, wasm_output, wasm_error,
    ),
    content=(
      #|(
      #|  Ok(ProcessExit(code=1)),
      #|  [],
      #|  ["boom"],
      #|  Ok(ProcessExit(code=1)),
      #|  [],
      #|  ["boom"],
      #|)
    ),
  )
}

///|
test "first-class panic preserves fatal control on either backend" {
  let image = compile_effect_conformance_image(
    (
      #|module Main
      #|import Basic.Io.*
      #|import Basic.Data.Void.{ Void, absurd }
      #|fn invoke(abort : (String) -> Void ! Panic) -> Unit ! Panic {
      #|  absurd[Unit](abort("forwarded"))
      #|  ()
      #|}
      #|pub fn main() -> Unit ! { Io, Panic } {
      #|  invoke(panic)
      #|  println("after")
      #|}
    ),
  )
  let (interpreter, interpreter_output, interpreter_error) = execute_effect_conformance_with_stderr(
    image,
    Interpreter,
  )
  let (wasm, wasm_output, wasm_error) = execute_effect_conformance_with_stderr(
    image,
    Jit,
  )
  assert_eq(
    (
      interpreter, interpreter_output, interpreter_error, wasm, wasm_output, wasm_error,
    ),
    (
      Ok(ProcessExit(code=1)),
      [],
      ["forwarded"],
      Ok(ProcessExit(code=1)),
      [],
      ["forwarded"],
    ),
  )
}

///|
test "Panic effect alone does not imply terminal control" {
  let image = compile_effect_conformance_image(
    (
      #|module Main
      #|pub fn main() -> Unit ! Panic {
      #|  ()
      #|}
    ),
  )
  assert_eq(run_effect_conformance_interpreter(image), [])
  assert_eq(run_effect_conformance_wasm(image), [])
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
