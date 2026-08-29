///|
pub(all) enum WasmPhysicalOpcodeFamily {
  Ownership
  Callable
  Object
  ByteSequence
  Scalar
  Erasure
  Global
  ControlTransfer
} derive(Debug, Eq)

///|
fn WasmPhysicalOpcodeFamily::key(self : WasmPhysicalOpcodeFamily) -> String {
  match self {
    Ownership => "ownership"
    Callable => "callable"
    Object => "object"
    ByteSequence => "byteSequence"
    Scalar => "scalar"
    Erasure => "erasure"
    Global => "global"
    ControlTransfer => "controlTransfer"
  }
}

///|
pub(all) enum WasmExpansionCategory {
  FunctionAbi
  PhysicalStorage
  PhysicalOpcode(WasmPhysicalOpcodeFamily)
  ControlFlow
  RuntimeGuard
  ArcFrameState
  ArcUnwind
  ArcCleanupSupport
  RuntimeImportAdapter
  RuntimeSupport
  HelperSupport
  EntryLifecycle
} derive(Debug, Eq)

///|
pub fn WasmExpansionCategory::key(self : WasmExpansionCategory) -> String {
  match self {
    FunctionAbi => "functionAbi"
    PhysicalStorage => "physicalStorage"
    PhysicalOpcode(family) => "physicalOpcode.\{family.key()}"
    ControlFlow => "controlFlow"
    RuntimeGuard => "runtimeGuard"
    ArcFrameState => "arcFrameState"
    ArcUnwind => "arcUnwind"
    ArcCleanupSupport => "arcCleanupSupport"
    RuntimeImportAdapter => "runtimeImportAdapter"
    RuntimeSupport => "runtimeSupport"
    HelperSupport => "helperSupport"
    EntryLifecycle => "entryLifecycle"
  }
}

///|
pub(all) struct WasmExpansionScale {
  category : WasmExpansionCategory
  mut instruction_count : Int
  mut local_count : Int
} derive(Debug, Eq)

///|
pub(all) struct WasmFunctionScale {
  index : Int
  instruction_count : Int
  local_count : Int
  expansions : Array[WasmExpansionScale]
} derive(Debug, Eq)

///|
pub(all) struct WasmModuleScale {
  imported_function_count : Int
  defined_function_count : Int
  instruction_count : Int
  local_count : Int
  table_entry_count : Int
  if_count : Int
  unreachable_count : Int
  unreachable_support_role_count : Int
  expansions : Array[WasmExpansionScale]
  functions : Array[WasmFunctionScale]
} derive(Debug, Eq)

///|
priv struct CompiledWasmFunction {
  code : @wasm_types.FunctionCode
  expansions : Array[WasmExpansionScale]
}

///|
fn account_whole_function(
  code : @wasm_types.FunctionCode,
  category : WasmExpansionCategory,
) -> CompiledWasmFunction {
  {
    code,
    expansions: [
      {
        category,
        instruction_count: wasm_instruction_array_size(code.body),
        local_count: code.locals.length(),
      },
    ],
  }
}

///|
/// Aggregates scale facts recorded while catalog entries are materialized.
fn WasmFunctionEmitter::scale(
  self : WasmFunctionEmitter,
  unreachable_support_role_count : Int,
) -> WasmModuleScale {
  let functions = self.function_scales
  let expansions : Array[WasmExpansionScale] = []
  for function in functions {
    for expansion in function.expansions {
      add_expansion(
        expansions,
        expansion.category,
        expansion.instruction_count,
        expansion.local_count,
      )
    }
  }
  {
    imported_function_count: self.imported_function_count,
    defined_function_count: functions.length(),
    instruction_count: functions.fold(init=0, fn(total, function) {
      total + function.instruction_count
    }),
    local_count: functions.fold(init=0, fn(total, function) {
      total + function.local_count
    }),
    table_entry_count: self.module_.elems.fold(init=0, fn(total, element) {
      total + element.init.length()
    }),
    if_count: self.module_.codes.fold(init=0, fn(total, code) {
      total +
      count_wasm_instruction(code.body, instruction => {
        instruction is If(_, _, _)
      })
    }),
    unreachable_count: self.module_.codes.fold(init=0, fn(total, code) {
      total +
      count_wasm_instruction(code.body, instruction => {
        instruction is Unreachable
      })
    }),
    unreachable_support_role_count,
    expansions,
    functions,
  }
}

///|
fn add_expansion(
  expansions : Array[WasmExpansionScale],
  category : WasmExpansionCategory,
  instruction_count : Int,
  local_count : Int,
) -> Unit {
  guard instruction_count != 0 || local_count != 0 else { return }
  for expansion in expansions {
    if expansion.category == category {
      expansion.instruction_count += instruction_count
      expansion.local_count += local_count
      return
    }
  }
  expansions.push({ category, instruction_count, local_count, })
}

///|
fn expansion_instruction_count(expansions : Array[WasmExpansionScale]) -> Int {
  expansions.fold(init=0, fn(total, expansion) {
    total + expansion.instruction_count
  })
}

///|
fn count_wasm_instruction(
  instructions : Array[@wasm_types.Instruction],
  predicate : (@wasm_types.Instruction) -> Bool,
) -> Int {
  instructions.fold(init=0, fn(total, instruction) {
    let nested = match instruction {
      Block(_, body) | Loop(_, body) | TryTable(_, _, body) =>
        count_wasm_instruction(body, predicate)
      If(_, consequent, alternate) =>
        count_wasm_instruction(consequent, predicate) +
        count_wasm_instruction(alternate, predicate)
      _ => 0
    }
    total + (if predicate(instruction) { 1 } else { 0 }) + nested
  })
}

///|
fn wasm_instruction_array_size(
  instructions : Array[@wasm_types.Instruction],
) -> Int {
  instructions.fold(init=0, fn(total, instruction) {
    total + wasm_instruction_size(instruction)
  })
}

///|
fn wasm_instruction_size(instruction : @wasm_types.Instruction) -> Int {
  match instruction {
    Block(_, body) | Loop(_, body) | TryTable(_, _, body) =>
      1 + wasm_instruction_array_size(body)
    If(_, consequent, alternate) =>
      1 +
      wasm_instruction_array_size(consequent) +
      wasm_instruction_array_size(alternate)
    _ => 1
  }
}
