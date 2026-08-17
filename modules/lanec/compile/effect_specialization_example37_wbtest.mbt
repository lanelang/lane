///|
test "real example 37 lifted snapshot verifies" {
  assert_eq(
    lifted_fixture_diagnostics(
      "../..", "examples/valid/37_coroutine_scheduler.lane",
    ),
    [],
  )
}

///|
test "real example 45 lifted snapshot verifies" {
  assert_eq(
    lifted_fixture_diagnostics("../..", "examples/valid/45_async_effect.lane"),
    [],
  )
}

///|
test "real example 37 shares escaped callable adapter workers" {
  let fixture_path = "examples/valid/37_coroutine_scheduler.lane"
  let result = compile({
    root: {
      source_id: fixture_path,
      text: @fs.read_file_to_string("../../\{fixture_path}", encoding="utf8"),
    },
    libraries: effect_example_test_libraries(),
  })
  guard result is Succeeded(compiled, warnings) else {
    abort("expected fixture to compile: \{Repr(result)}")
  }
  assert_eq(warnings.diagnostics(), [])
  let mut answer_entry = None
  for entry in compiled.entries() {
    if entry.name() == "answer" {
      answer_entry = Some(entry)
    }
  }
  guard answer_entry is Some(entry) else {
    abort("expected fixture to expose answer")
  }
  guard compiled.elaborate_entry(
      entry,
      @executable.ExecutionProfile::new(
        builtin_effects=[Io, Panic],
        supports_external_effects=true,
      ),
    )
    is Ok(executable) else {
    abort("expected executable elaboration to complete")
  }
  let mut adapter_workers = 0
  let mut adapter_materializations = 0
  let mut finalized_adapter_workers = 0
  let lowered = @loisvm_lowering.lower_executable_program_to_bytecode_observed(
    executable,
    stage => {
      match stage {
        InitialVmcfg(image, provenance) => {
          let worker_ids = []
          for item in provenance {
            if item.origins.any(origin => origin is CallableAdapter) {
              worker_ids.push(item.function)
            }
          }
          adapter_workers = worker_ids.length()
          for entry in image.functions {
            guard entry is Body(body) else { continue }
            for block in body.blocks {
              for instruction in block.instructions {
                if instruction is MakeClosure(_, function, _) &&
                  worker_ids.contains(function) {
                  adapter_materializations += 1
                }
              }
            }
          }
        }
        FinalBytecode(_, provenance) =>
          for item in provenance {
            if item.origins.any(origin => origin is CallableAdapter) {
              finalized_adapter_workers += 1
            }
          }
        Anf(_) => ()
      }
    },
  )
  guard lowered is Ok(_) else {
    abort("expected LoisVM lowering to complete: \{Repr(lowered)}")
  }
  assert_eq(
    (adapter_workers, adapter_materializations, finalized_adapter_workers),
    (17, 23, 17),
  )
}

///|
fn lifted_fixture_diagnostics(
  repository_root : String,
  fixture_path : String,
) -> Array[@buslane.VerifyDiagnostic] raise {
  let result = compile({
    root: {
      source_id: fixture_path,
      text: @fs.read_file_to_string(
        "\{repository_root}/\{fixture_path}",
        encoding="utf8",
      ),
    },
    libraries: effect_example_test_libraries(),
  })
  guard result is Succeeded(compiled, warnings) else {
    abort("expected fixture to compile: \{Repr(result)}")
  }
  assert_eq(warnings.diagnostics(), [])
  let mut answer_entry = None
  for entry in compiled.entries() {
    if entry.name() == "answer" {
      answer_entry = Some(entry)
    }
  }
  guard answer_entry is Some(entry) else {
    abort("expected fixture to expose answer")
  }
  let mut lifted_verification = None
  let elaborated = compiled.elaborate_entry_observed(
    entry,
    @executable.ExecutionProfile::new(
      builtin_effects=[Io, Panic],
      supports_external_effects=true,
    ),
    stage => {
      if stage is MonadicContinuationsLifted(lifted) {
        lifted_verification = Some(@buslane.verify_program(lifted))
      }
    },
  )
  guard elaborated is Ok(_) else {
    abort("expected executable elaboration to complete: \{Repr(elaborated)}")
  }
  guard lifted_verification is Some(verification) else {
    abort("expected to observe the monadic-lift boundary")
  }
  verification.diagnostics()
}

///|
fn effect_example_test_libraries() -> Array[SourceInput] {
  [
    {
      source_id: "<basic-io>",
      text: (
        #|module Basic.Io
        #|
        #|pub let println : (String) -> Unit ! Io = extern("println")
      ),
    },
    {
      source_id: "<basic-trait-num>",
      text: (
        #|module Basic.Trait.Num
        #|
        #|pub struct Add[T] {
        #|  add : (T, T) -> T
        #|}
        #|
        #|pub struct Mul[T] {
        #|  mul : (T, T) -> T
        #|}
      ),
    },
    {
      source_id: "<basic-trait-equal>",
      text: (
        #|module Basic.Trait.Equal
        #|
        #|pub struct Equal[T] {
        #|  equal : (T, T) -> Bool
        #|}
      ),
    },
    {
      source_id: "<basic-builtins>",
      text: (
        #|module Basic.Builtins
        #|
        #|pub let i64_add : (I64, I64) -> I64 = builtin("%i64_add")
        #|
        #|pub let i64_mul : (I64, I64) -> I64 = builtin("%i64_mul")
        #|
        #|pub let i64_equal : (I64, I64) -> Bool = builtin("%i64_equal")
      ),
    },
    {
      source_id: "<basic-data-i64>",
      text: (
        #|module Basic.Data.I64
        #|
        #|import Basic.Trait.Num.{ Add, Mul }
        #|import Basic.Trait.Equal.{ Equal }
        #|import Basic.Builtins.{ i64_add, i64_mul, i64_equal }
        #|
        #|pub offer i64_impl_add : Add[I64] = Add::{ add: i64_add }
        #|
        #|pub offer i64_impl_mul : Mul[I64] = Mul::{ mul: i64_mul }
        #|
        #|pub offer i64_impl_equal : Equal[I64] = Equal::{ equal: i64_equal }
      ),
    },
    {
      source_id: "<basic-ops>",
      text: (
        #|module Basic.Ops
        #|
        #|import Basic.Trait.Num.{ Add, Mul }
        #|import Basic.Trait.Equal.{ Equal }
        #|
        #|pub fn[T] op_add(a : T, b : T, auto op : Add[T]) -> T {
        #|  op.add(a, b)
        #|}
        #|
        #|pub fn[T] op_mul(a : T, b : T, auto op : Mul[T]) -> T {
        #|  op.mul(a, b)
        #|}
        #|
        #|pub fn[T] op_equal(a : T, b : T, auto op : Equal[T]) -> Bool {
        #|  op.equal(a, b)
        #|}
      ),
    },
  ]
}
