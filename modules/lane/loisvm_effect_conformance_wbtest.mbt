///|
fn effect_conformance_basic_io() -> String {
  (
    #|module Basic.Io
    #|pub effect Write {
    #|  println(String) -> Unit
    #|}
    #|pub type Console = { Write }
    #|pub type Io = { Console }
  )
}

///|
fn compile_effect_conformance_image(
  source : String,
) -> @loisvm_bytecode.BytecodeImage raise {
  let result = @compile.compile_sources(source, [effect_conformance_basic_io()])
  if !result.diagnostics.is_empty() {
    fail(
      "effect conformance compilation failed: \{to_repr(result.diagnostics)}",
    )
  }
  guard result.program is Some(program) else {
    fail("effect conformance source produced no program")
  }
  guard find_entry(result.entries, "main") is Ok(entry) else {
    fail("effect conformance source produced no main entry")
  }
  match
    @loisvm_lowering.lower_linked_program_to_bytecode_with_runtime_effects(
      program,
      result.externals,
      entry,
      result.runtime_effect_operations,
    ) {
    Ok(image) => image
    Err(error) => fail("effect conformance lowering failed: \{to_repr(error)}")
  }
}

///|
fn effect_conformance_registry(
  output : Array[String],
) -> @loisvm_runtime.RuntimeRegistry {
  let registry = @loisvm_runtime.RuntimeRegistry::new()
  registry.register(
    @loisvm_runtime.RuntimeBinding::new(
      symbol="lane.effect.v1/Basic.Io/Write/println",
      abi_major=1,
      parameters=[String],
      result=Unit,
      invoke=(_context, arguments) => {
        guard arguments is [BorrowedString(line)] else {
          raise Failure(
            message="Basic.Io.Write.println expects one String argument",
          )
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
    Err(error) => fail("LoisVM interpreter load failed: \{to_repr(error)}")
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
    Err(error) => fail("LoisVM Wasm load failed: \{to_repr(error)}")
  }
  let instance = match loaded.new_instance() {
    Ok(value) => value
    Err(error) => fail("LoisVM Wasm instantiation failed: \{to_repr(error)}")
  }
  assert_eq(instance.execute(), Ok(()))
  output
}

///|
fn assert_effect_conformance(
  source : String,
  expected : Array[String],
) -> Unit raise {
  let image = compile_effect_conformance_image(source)
  let interpreter_output = run_effect_conformance_interpreter(image)
  let wasm_output = run_effect_conformance_wasm(image)
  assert_eq(interpreter_output, expected)
  assert_eq(wasm_output, expected)
  assert_eq(interpreter_output, wasm_output)
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
      #|      let _written : Unit = Write::println!("handled")
      #|      resume(())
      #|    }
      #|  } final _value {
      #|    Write::println!("final")
      #|  }
      #|  Write::println!("after")
      #|}
    ),
    ["handled", "final", "after"],
  )
}
