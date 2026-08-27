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
test "real example 37 classifies residual representation adaptation" {
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
  let mut generic_abi_erasures = 0
  let mut generic_abi_unerasures = 0
  let adapter_worker_ids = []
  let mut indirect_calls = []
  let lowered = @physical_lowering.lower_executable_program_to_physical_observed(
    executable,
    stage => {
      match stage {
        InitialVmcfg(image, provenance) => {
          indirect_calls = provenance.indirect_calls
          for item in provenance.functions {
            if item.origins.any(origin => origin is CallableAdapter) {
              adapter_worker_ids.push(item.function)
            }
          }
          adapter_workers = adapter_worker_ids.length()
          for entry in image.functions {
            guard entry is Body(body) else { continue }
            for block in body.blocks {
              for instruction in block.instructions {
                if instruction is MakeClosure(_, function, _) &&
                  adapter_worker_ids.contains(function) {
                  adapter_materializations += 1
                }
                match instruction {
                  EraseI32(_, _)
                  | EraseI64(_, _)
                  | EraseF32(_, _)
                  | EraseF64(_, _)
                  | EraseUnit(_) => generic_abi_erasures += 1
                  UneraseI32(_, _)
                  | UneraseI64(_, _)
                  | UneraseF32(_, _)
                  | UneraseF64(_, _)
                  | UneraseUnit(_) => generic_abi_unerasures += 1
                  _ => ()
                }
              }
            }
          }
        }
        FinalPhysicalProgram(_, provenance) =>
          for item in provenance.functions {
            if item.origins.any(origin => origin is CallableAdapter) {
              finalized_adapter_workers += 1
            }
          }
        Anf(_) => ()
      }
    },
  )
  guard lowered is Ok(_) else {
    abort("expected physical lowering to complete: \{Repr(lowered)}")
  }
  assert_eq(
    (
      adapter_workers,
      adapter_materializations,
      finalized_adapter_workers,
      generic_abi_erasures,
      generic_abi_unerasures,
      summarize_adapter_flow(indirect_calls, adapter_worker_ids),
    ),
    (
      21,
      26,
      21,
      15,
      11,
      { indirect_targets: 20, aggregate_stored_targets: 20, direct_only: 1, },
    ),
  )
  assert_eq(summarize_indirect_calls(indirect_calls), {
    total: 44,
    source_bound: 9,
    source_anonymous: 0,
    handler_elaboration: 0,
    monadic_transformation: 7,
    selective_cps: 9,
    callable_adapter: 18,
    representation_worker: 0,
    initialization: 1,
    runtime_support: 0,
    exact_capture_free: 0,
    exact_local: 0,
    exact_packed: 9,
    multiple_targets: 35,
    unknown_with_candidates: 0,
    unknown_without_candidates: 0,
    calls_without_boundary: 0,
  })
}

///|
priv struct AdapterFlowSummary {
  indirect_targets : Int
  aggregate_stored_targets : Int
  direct_only : Int
} derive(Debug, Eq)

///|
fn summarize_adapter_flow(
  calls : Array[@physical_lowering.PhysicalIndirectCallObservation],
  adapters : Array[@physical.FunctionId],
) -> AdapterFlowSummary {
  let indirect_targets = []
  let aggregate_stored_targets = []
  for call in calls {
    let targets = match call.resolution {
      ExactTarget(target, _) => [target]
      MultipleTargets(targets) | UnknownTargets(targets) => targets
    }
    for target in targets {
      guard adapters.contains(target) else { continue }
      if !indirect_targets.contains(target) {
        indirect_targets.push(target)
      }
      if call.boundaries.contains(AggregateStorage) &&
        !aggregate_stored_targets.contains(target) {
        aggregate_stored_targets.push(target)
      }
    }
  }
  {
    indirect_targets: indirect_targets.length(),
    aggregate_stored_targets: aggregate_stored_targets.length(),
    direct_only: adapters.length() - indirect_targets.length(),
  }
}

///|
priv struct IndirectCallSummary {
  total : Int
  mut source_bound : Int
  mut source_anonymous : Int
  mut handler_elaboration : Int
  mut monadic_transformation : Int
  mut selective_cps : Int
  mut callable_adapter : Int
  mut representation_worker : Int
  mut initialization : Int
  mut runtime_support : Int
  mut exact_capture_free : Int
  mut exact_local : Int
  mut exact_packed : Int
  mut multiple_targets : Int
  mut unknown_with_candidates : Int
  mut unknown_without_candidates : Int
  mut calls_without_boundary : Int
} derive(Debug, Eq)

///|
fn summarize_indirect_calls(
  calls : Array[@physical_lowering.PhysicalIndirectCallObservation],
) -> IndirectCallSummary {
  let summary : IndirectCallSummary = {
    total: calls.length(),
    source_bound: 0,
    source_anonymous: 0,
    handler_elaboration: 0,
    monadic_transformation: 0,
    selective_cps: 0,
    callable_adapter: 0,
    representation_worker: 0,
    initialization: 0,
    runtime_support: 0,
    exact_capture_free: 0,
    exact_local: 0,
    exact_packed: 0,
    multiple_targets: 0,
    unknown_with_candidates: 0,
    unknown_without_candidates: 0,
    calls_without_boundary: 0,
  }
  for call in calls {
    for origin in call.origins {
      match origin {
        SourceBound => summary.source_bound += 1
        SourceAnonymous => summary.source_anonymous += 1
        HandlerElaboration => summary.handler_elaboration += 1
        MonadicTransformation => summary.monadic_transformation += 1
        SelectiveCps => summary.selective_cps += 1
        CallableAdapter => summary.callable_adapter += 1
        RepresentationWorker => summary.representation_worker += 1
        Initialization => summary.initialization += 1
        RuntimeSupport => summary.runtime_support += 1
      }
    }
    match call.resolution {
      ExactTarget(_, CaptureFree) => summary.exact_capture_free += 1
      ExactTarget(_, Local) => summary.exact_local += 1
      ExactTarget(_, Packed) => summary.exact_packed += 1
      MultipleTargets(_) => summary.multiple_targets += 1
      UnknownTargets([]) => summary.unknown_without_candidates += 1
      UnknownTargets(_) => summary.unknown_with_candidates += 1
    }
    if call.boundaries.is_empty() {
      summary.calls_without_boundary += 1
    }
  }
  summary
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
fn effect_example_test_libraries() -> Array[@module_frontend.SourceInput] {
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
