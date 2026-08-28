///|
fn encode_test_wasm_module(module_ : @wasm_types.Module) -> Bytes {
  let encoded = @wasm_encoder.encode(module_)
  Bytes::from_iter(encoded.iter().map(value => value.to_byte()))
}

///|
fn encode_profile_probe(source : String) -> Bytes raise {
  let module_ = @wasmoon_wat.parse(source) catch {
    error => fail(@wasmoon_wat.format_wat_error(error, source))
  }
  for control in @internal_abi.runtime_control_globals() {
    let index = module_.globals.length()
    let initial = match control {
      MaxLiveHeapBytes | MaxCallDepth => -1
      FailureCode => 0
    }
    let global : @wasm_types.Global = {
      type_: { value_type: I32, mutable: true, },
      init: [I32Const(initial)],
    }
    module_.globals.push(global)
    module_.exports.push({ name: control.name(), desc: Global(index), })
  }
  encode_test_wasm_module(module_)
}

///|
fn execute_profile_probe(
  source : String,
  mode : @lane_wasm_runtime.ExecutionMode,
) -> Unit raise {
  let loaded = match
    @lane_wasm_runtime.load_wasm(encode_profile_probe(source), mode~) {
    Ok(loaded) => loaded
    Err(error) =>
      fail("profile probe did not load in \{Repr(mode)}: \{Repr(error)}")
  }
  let instance = match loaded.new_instance() {
    Ok(instance) => instance
    Err(error) =>
      fail("profile probe did not instantiate in \{Repr(mode)}: \{Repr(error)}")
  }
  assert_eq(instance.execute(), Ok(()))
}

///|
fn assert_profile_probe(name : String, source : String) -> Unit raise {
  for mode in [@lane_wasm_runtime.ExecutionMode::Interpreter, Jit] {
    execute_profile_probe(source, mode) catch {
      error =>
        fail(
          "WebAssembly profile probe `\{name}` failed in \{Repr(mode)}: \{Repr(error)}",
        )
    }
  }
}

///|
test "Lane WebAssembly Profile executes in Wasmoon interpreter and JIT" {
  assert_profile_probe(
    "bulk-memory",
    (
      #|(module
      #|  (memory 1)
      #|  (func (export "_start")
      #|    i32.const 0
      #|    i32.const 42
      #|    i32.const 1
      #|    memory.fill
      #|    i32.const 0
      #|    i32.load8_u
      #|    i32.const 42
      #|    i32.ne
      #|    if unreachable end))
    ),
  )
  assert_profile_probe(
    "reference-types",
    (
      #|(module
      #|  (func (export "_start")
      #|    ref.null func
      #|    ref.is_null
      #|    i32.eqz
      #|    if unreachable end))
    ),
  )
  assert_profile_probe(
    "typed-function-references",
    (
      #|(module
      #|  (type $t (func (result i32)))
      #|  (func $target (type $t) (result i32) i32.const 42)
      #|  (elem declare func $target)
      #|  (func (export "_start")
      #|    ref.func $target
      #|    call_ref $t
      #|    i32.const 42
      #|    i32.ne
      #|    if unreachable end))
    ),
  )
  assert_profile_probe(
    "tail-call",
    (
      #|(module
      #|  (func $done)
      #|  (func (export "_start") return_call $done))
    ),
  )
  assert_profile_probe(
    "exception-handling",
    (
      #|(module
      #|  (tag $e)
      #|  (func (export "_start")
      #|    (block $handled
      #|      (try_table (catch $e $handled)
      #|        (throw $e))
      #|      unreachable)))
    ),
  )
  assert_profile_probe(
    "multi-value",
    (
      #|(module
      #|  (func $pair (result i32 i32) i32.const 20 i32.const 22)
      #|  (func (export "_start")
      #|    call $pair
      #|    i32.add
      #|    i32.const 42
      #|    i32.ne
      #|    if unreachable end))
    ),
  )
  assert_profile_probe(
    "fixed-width-simd",
    (
      #|(module
      #|  (func (export "_start")
      #|    v128.const i32x4 10 20 42 40
      #|    drop))
    ),
  )
  assert_profile_probe(
    "extended-constant-expressions",
    (
      #|(module
      #|  (global $answer i32 (i32.add (i32.const 20) (i32.const 22)))
      #|  (func (export "_start")
      #|    global.get $answer
      #|    i32.const 42
      #|    i32.ne
      #|    if unreachable end))
    ),
  )
}

///|
fn wasm_export_kind(desc : @wasm_types.ExportDesc) -> String {
  match desc {
    Func(_) => "function"
    Table(_) => "table"
    Memory(_) => "memory"
    Global(_) => "global"
    Tag(_) => "tag"
  }
}

///|
test "linked executable is a raw WASI command module" {
  let image = compile_effect_conformance_image(
    (
      #|module Main
      #|import Basic.Io.{ println }
      #|pub fn main() -> Unit ! Io { println("Lane") }
    ),
  )
  let verified = match @physical.verify_physical_program_for_execution(image) {
    Ok(verified) => verified
    Err(error) => fail("physical verification failed: \{Repr(error)}")
  }
  let module_ = match @wasm_target.compile(verified) {
    Ok(module_) => module_
    Err(error) => fail("Wasm compilation failed: \{Repr(error)}")
  }
  let wasm = encode_test_wasm_module(module_)
  let imports = module_.imports.map(import_ => (import_.mod_name, import_.name))
  let exports = module_.exports.map(export_ => {
    (export_.name, wasm_export_kind(export_.desc))
  })
  debug_inspect(
    (wasm[0:4].to_array(), imports, exports),
    content=(
      #|(
      #|  [0x00, 0x61, 0x73, 0x6d],
      #|  [("wasi_snapshot_preview1", "fd_write")],
      #|  [
      #|    ("lane.runtime.control.max_live_heap_bytes", "global"),
      #|    ("lane.runtime.control.max_call_depth", "global"),
      #|    ("lane.runtime.control.failure_code", "global"),
      #|    ("_start", "function"),
      #|    ("memory", "memory"),
      #|  ],
      #|)
    ),
  )
}
