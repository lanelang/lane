///|
pub(all) enum PhysicalVerificationSite {
  Image
  Function(FunctionId)
  Block(FunctionId, BlockId)
  Instruction(FunctionId, BlockId, Int)
  Terminator(FunctionId, BlockId)
} derive(Debug, Eq)

///|
pub(all) suberror PhysicalProgramVerificationError {
  InvalidPhysicalProgram(site~ : PhysicalVerificationSite, detail~ : String)
} derive(Debug, Eq)

///|
priv struct PhysicalProgramVerifier {
  image : PhysicalProgram
}

///|
pub fn verify_physical_program(
  image : PhysicalProgram,
) -> Result[Unit, PhysicalProgramVerificationError] {
  match verify_physical_program_for_execution(image) {
    Ok(_) => Ok(())
    Err(error) => Err(error)
  }
}

///|
pub fn verify_physical_program_for_execution(
  image : PhysicalProgram,
) -> Result[VerifiedPhysicalProgram, PhysicalProgramVerificationError] {
  Ok({ image, global_lifecycle: PhysicalProgramVerifier::{ image, }.verify(), }) catch {
    error => Err(error)
  }
}

///|
fn PhysicalProgramVerifier::verify(
  self : PhysicalProgramVerifier,
) -> GlobalLifecyclePlan raise PhysicalProgramVerificationError {
  let image_site = PhysicalVerificationSite::Image
  if self.image.functions.is_empty() {
    self.fail(image_site, "function table must be nonempty")
  }
  if self.image.data_family_count < 0 {
    self.fail(image_site, "data family count must be nonnegative")
  }
  self.verify_runtime_imports_and_constants()
  self.verify_callable_abis()
  for index, entry in self.image.functions {
    let function : FunctionId = { value: index + 1, }
    guard entry.callable_abi() is Some(abi) else {
      self.fail(Function(function), "function inputs do not define an ABI")
    }
    if !self.image.callable_abis.contains(abi) {
      self.fail(Function(function), "function ABI is missing from the table")
    }
  }
  self.verify_root_function(self.image.entry, "selected entry")
  match self.image.initializer {
    Some(initializer) =>
      self.verify_root_function(initializer, "instance initializer")
    None =>
      if !self.image.globals.is_empty() {
        self.fail(
          image_site, "nonempty instance global table requires an initializer",
        )
      }
  }
  self.verify_globals()
  let global_lifecycle = self.image.global_lifecycle_plan()
  self.verify_layouts_and_shapes()
  let global_dependencies = self.global_dependencies()
  for index, entry in self.image.functions {
    if entry is PhysicalBody(body) {
      let function : FunctionId = { value: index + 1, }
      self.verify_function(function, body)
      self.verify_function_flow(
        function, body, global_dependencies, global_lifecycle,
      )
    }
  }
  global_lifecycle
}

///|
fn PhysicalProgramVerifier::verify_callable_abis(
  self : PhysicalProgramVerifier,
) -> Unit raise PhysicalProgramVerificationError {
  let site = PhysicalVerificationSite::Image
  if self.image.callable_abis.is_empty() {
    self.fail(site, "callable ABI table must be nonempty")
  }
  for index, abi in self.image.callable_abis {
    for witness in abi.witnesses {
      if !self.legal_metadata(
          site,
          witness.representation,
          witness.cleanup,
          witness.kind,
        ) {
        self.fail(site, "callable ABI contains an illegal witness shape")
      }
    }
    for parameter in abi.parameters {
      if !self.legal_metadata(
          site,
          parameter.representation,
          parameter.cleanup,
          parameter.kind,
        ) {
        self.fail(site, "callable ABI contains an illegal parameter shape")
      }
    }
    if abi.result is Value(representation, cleanup, kind) &&
      !self.legal_metadata(site, representation, cleanup, kind) {
      self.fail(site, "callable ABI contains an illegal result shape")
    }
    for previous in 0..<index {
      if self.image.callable_abis[previous] == abi {
        self.fail(site, "callable ABI table contains a duplicate description")
      }
    }
  }
}

///|
fn PhysicalProgramVerifier::verify_runtime_imports_and_constants(
  self : PhysicalProgramVerifier,
) -> Unit raise PhysicalProgramVerificationError {
  for index, entry in self.image.functions {
    if entry is RuntimeImport(import_) {
      let site = PhysicalVerificationSite::Function({ value: index + 1, })
      self.verify_wasm_name(site, import_.module_name, "module name")
      self.verify_wasm_name(site, import_.field_name, "field name")
    }
  }
  for constant in self.image.constants {
    ignore(
      @utf8.decode(constant) catch {
        _ => self.fail(Image, "String constant must contain valid UTF-8")
      },
    )
  }
}

///|
fn PhysicalProgramVerifier::verify_wasm_name(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  name : String,
  what : String,
) -> Unit raise PhysicalProgramVerificationError {
  let bytes = @utf8.encode(name)
  if bytes.is_empty() {
    self.fail(site, "runtime import \{what} must be nonempty")
  }
  for byte in bytes {
    if byte.to_int() > 0x7F {
      self.fail(site, "runtime import \{what} must contain ASCII bytes only")
    }
    if byte == b'\x00' {
      self.fail(site, "runtime import \{what} must not contain NUL")
    }
  }
}

///|
fn[T] PhysicalProgramVerifier::fail(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  detail : String,
) -> T raise PhysicalProgramVerificationError {
  ignore(self)
  raise InvalidPhysicalProgram(site~, detail~)
}

///|
fn PhysicalProgramVerifier::function_entry(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  id : FunctionId,
) -> FunctionEntry raise PhysicalProgramVerificationError {
  if id.value <= 0 || id.value > self.image.functions.length() {
    self.fail(site, "FunctionId \{id.value} is out of range")
  }
  self.image.functions[id.value - 1]
}

///|
fn PhysicalProgramVerifier::callable_abi(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  id : CallableAbiId,
) -> CallableAbi raise PhysicalProgramVerificationError {
  match self.image.callable_abi(id) {
    Some(abi) => abi
    None => self.fail(site, "CallableAbiId \{id.value} is out of range")
  }
}

///|
fn PhysicalProgramVerifier::function_callable_abi(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  id : FunctionId,
) -> CallableAbi raise PhysicalProgramVerificationError {
  ignore(self.function_entry(site, id))
  match self.image.function_callable_abi(id) {
    Some(abi) => abi
    None => self.fail(site, "function inputs do not define an ABI")
  }
}

///|
fn PhysicalProgramVerifier::global_metadata(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  id : GlobalId,
) -> GlobalMetadata raise PhysicalProgramVerificationError {
  if id.value < 0 || id.value >= self.image.globals.length() {
    self.fail(site, "GlobalId \{id.value} is out of range")
  }
  self.image.globals[id.value]
}

///|
fn PhysicalProgramVerifier::layout_recipe(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  id : LayoutId,
) -> LayoutRecipe raise PhysicalProgramVerificationError {
  if id.value <= 0 || id.value > self.image.layouts.length() {
    self.fail(site, "LayoutId \{id.value} is out of range")
  }
  self.image.layouts[id.value - 1]
}

///|
fn PhysicalProgramVerifier::object_layout_id(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  shape : ObjectShapeId,
) -> LayoutId raise PhysicalProgramVerificationError {
  let expected : LayoutRecipe = match self.object_shape(site, shape) {
    Data(_) => Data(shape)
    Environment(_) => Environment(shape)
  }
  for index, layout in self.image.layouts {
    if layout == expected {
      return { value: index + 1, }
    }
  }
  self.fail(site, "object operation requires a canonical layout recipe")
}

///|
fn PhysicalProgramVerifier::require_data_family_layouts(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  family : DataFamilyId,
) -> Unit raise PhysicalProgramVerificationError {
  let mut found = false
  for index, shape in self.image.object_shapes {
    if shape is Data({ family: actual, .. }) && actual == family {
      found = true
      ignore(self.object_layout_id(site, { value: index, }))
    }
  }
  if !found {
    self.fail(site, "Data family has no object shape")
  }
}

///|
fn PhysicalProgramVerifier::object_shape(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  id : ObjectShapeId,
) -> ObjectShape raise PhysicalProgramVerificationError {
  if id.value < 0 || id.value >= self.image.object_shapes.length() {
    self.fail(site, "ObjectShapeId \{id.value} is out of range")
  }
  self.image.object_shapes[id.value]
}

///|
fn PhysicalProgramVerifier::constant(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  id : ConstantId,
) -> Bytes raise PhysicalProgramVerificationError {
  if id.value < 0 || id.value >= self.image.constants.length() {
    self.fail(site, "ConstantId \{id.value} is out of range")
  }
  self.image.constants[id.value]
}

///|
fn PhysicalProgramVerifier::slot_metadata(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  id : SlotId,
) -> SlotMetadata raise PhysicalProgramVerificationError {
  if id.value < 0 || id.value >= body.slots.length() {
    self.fail(site, "SlotId \{id.value} is out of range")
  }
  body.slots[id.value]
}

///|
fn PhysicalProgramVerifier::expect_slot(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  id : SlotId,
  representation : Representation,
  cleanup : Cleanup,
) -> Unit raise PhysicalProgramVerificationError {
  let actual = self.slot_metadata(site, body, id)
  if actual.representation != representation || actual.cleanup != cleanup {
    self.fail(
      site,
      "SlotId \{id.value} must be \{Repr(representation)} + \{Repr(cleanup)}, got \{Repr(actual.representation)} + \{Repr(actual.cleanup)}",
    )
  }
}

///|
fn PhysicalProgramVerifier::expect_value_shape(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  id : SlotId,
  representation : Representation,
  cleanup : Cleanup,
  kind : SemanticValueKind,
) -> Unit raise PhysicalProgramVerificationError {
  self.expect_slot(site, body, id, representation, cleanup)
  let actual = self.slot_metadata(site, body, id)
  if actual.kind != kind {
    self.fail(
      site,
      "SlotId \{id.value} must have \{Repr(kind)} semantic kind, got \{Repr(actual.kind)}",
    )
  }
}

///|
fn PhysicalProgramVerifier::expect_kind(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  id : SlotId,
  kind : SemanticValueKind,
) -> Unit raise PhysicalProgramVerificationError {
  let actual = self.slot_metadata(site, body, id)
  if actual.kind != kind {
    self.fail(
      site,
      "SlotId \{id.value} must have \{Repr(kind)} semantic kind, got \{Repr(actual.kind)}",
    )
  }
}

///|
fn PhysicalProgramVerifier::expect_data_value(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  id : SlotId,
  family : DataFamilyId?,
) -> Unit raise PhysicalProgramVerificationError {
  let actual = self.slot_metadata(site, body, id)
  guard actual.kind is DataValue(actual_family) else {
    self.fail(site, "SlotId \{id.value} must hold a Data value")
  }
  if family is Some(expected) && actual_family != expected {
    self.fail(
      site,
      "SlotId \{id.value} belongs to DataFamilyId \{actual_family.value}, expected DataFamilyId \{expected.value}",
    )
  }
}

///|
fn PhysicalProgramVerifier::expect_representation(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  id : SlotId,
  representation : Representation,
) -> SlotMetadata raise PhysicalProgramVerificationError {
  let actual = self.slot_metadata(site, body, id)
  if actual.representation != representation {
    self.fail(
      site,
      "SlotId \{id.value} must use \{Repr(representation)}, got \{Repr(actual.representation)}",
    )
  }
  actual
}

///|
fn PhysicalProgramVerifier::expect_same_shape(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  body : FunctionBody,
  left : SlotId,
  right : SlotId,
) -> Unit raise PhysicalProgramVerificationError {
  let left_metadata = self.slot_metadata(site, body, left)
  let right_metadata = self.slot_metadata(site, body, right)
  if left_metadata.representation != right_metadata.representation ||
    left_metadata.cleanup != right_metadata.cleanup ||
    left_metadata.kind != right_metadata.kind {
    self.fail(
      site,
      "SlotId \{left.value} and SlotId \{right.value} have incompatible value shapes",
    )
  }
}

///|
fn PhysicalProgramVerifier::verify_root_function(
  self : PhysicalProgramVerifier,
  function : FunctionId,
  what : String,
) -> Unit raise PhysicalProgramVerificationError {
  let site = PhysicalVerificationSite::Image
  match self.function_entry(site, function) {
    PhysicalBody(body) =>
      if body.inputs.environment is Some(_) ||
        !body.inputs.witnesses.is_empty() ||
        !body.inputs.user_parameters.is_empty() ||
        body.result != Unit {
        self.fail(
          site,
          "\{what} must be a no-context, zero-argument Unit physical body",
        )
      }
    RuntimeImport(_) => self.fail(site, "\{what} must be a physical body")
  }
}

///|
fn PhysicalProgramVerifier::verify_globals(
  self : PhysicalProgramVerifier,
) -> Unit raise PhysicalProgramVerificationError {
  let site = PhysicalVerificationSite::Image
  for index, global in self.image.globals {
    if !self.legal_metadata(
        site,
        global.representation,
        global.cleanup,
        global.kind,
      ) {
      self.fail(site, "illegal global representation and cleanup combination")
    }
    match (global.cleanup, global.erased_companion) {
      (OwnedErased, Some(companion)) => {
        if index == 0 || companion.value != index - 1 {
          self.fail(
            site, "OwnedErased global companion must immediately precede its owner",
          )
        }
        let companion_global = self.image.globals[companion.value]
        if companion_global.representation != I32 ||
          companion_global.cleanup != Trivial ||
          companion_global.kind != LayoutValue ||
          companion_global.erased_companion is Some(_) {
          self.fail(
            site, "erased global companion must be an I32 Trivial global",
          )
        }
      }
      (OwnedErased, None) =>
        self.fail(site, "OwnedErased global requires a companion")
      (_, Some(_)) =>
        self.fail(site, "only OwnedErased globals have companions")
      _ => ()
    }
  }
}

///|
fn PhysicalProgramVerifier::verify_layouts_and_shapes(
  self : PhysicalProgramVerifier,
) -> Unit raise PhysicalProgramVerificationError {
  let site = PhysicalVerificationSite::Image
  for layout_index, layout in self.image.layouts {
    for previous in 0..<layout_index {
      if self.image.layouts[previous] == layout {
        self.fail(site, "layout table contains a duplicate recipe")
      }
    }
    match layout {
      Data(id) =>
        if !(self.object_shape(site, id) is Data(_)) {
          self.fail(site, "Data layout references an Environment shape")
        }
      Environment(id) =>
        if !(self.object_shape(site, id) is Environment(_)) {
          self.fail(site, "Environment layout references a Data shape")
        }
      _ => ()
    }
  }
  for shape_index, shape in self.image.object_shapes {
    match shape {
      Data(data) => {
        if data.family.value < 0 ||
          data.family.value >= self.image.data_family_count {
          self.fail(site, "data shape has an out-of-range family")
        }
        for previous in 0..<shape_index {
          if self.image.object_shapes[previous] is Data(previous_data) &&
            previous_data.family == data.family &&
            previous_data.constructor_tag == data.constructor_tag {
            self.fail(
              site,
              "data family contains duplicate constructor tag \{data.constructor_tag}",
            )
          }
        }
        self.verify_member_schemas(data.members, data.stored_witness_count)
      }
      Environment(environment) =>
        self.verify_member_schemas(
          environment.members,
          environment.stored_witness_count,
        )
    }
  }
}

///|
fn PhysicalProgramVerifier::verify_member_schemas(
  self : PhysicalProgramVerifier,
  schemas : Array[MemberSchema],
  stored_witness_count : Int,
) -> Unit raise PhysicalProgramVerificationError {
  let site = PhysicalVerificationSite::Image
  if stored_witness_count < 0 {
    self.fail(site, "stored witness count must be nonnegative")
  }
  for schema in schemas {
    let legal = match (schema.representation, schema.cleanup) {
      (I32 | I64 | F64 | F32, Trivial) => schema.witness_ordinal is None
      (I32, OwnedRef) => schema.witness_ordinal is None
      (I64, OwnedCallable) => schema.witness_ordinal is None
      (I64, OwnedErased) =>
        match schema.witness_ordinal {
          Some(ordinal) => ordinal >= 0 && ordinal < stored_witness_count
          None => false
        }
      _ => false
    }
    if !legal {
      self.fail(site, "illegal object member schema")
    }
    if !self.legal_metadata(
        site,
        schema.representation,
        schema.cleanup,
        schema.kind,
      ) {
      self.fail(site, "object member schema has an illegal semantic value kind")
    }
  }
}

///|
fn PhysicalProgramVerifier::legal_metadata(
  self : PhysicalProgramVerifier,
  site : PhysicalVerificationSite,
  representation : Representation,
  cleanup : Cleanup,
  kind : SemanticValueKind,
) -> Bool raise PhysicalProgramVerificationError {
  match kind {
    ScalarValue => cleanup == Trivial
    LayoutValue => representation == I32 && cleanup == Trivial
    LayoutConstructorValue(arity) =>
      arity >= 0 &&
      representation == I64 &&
      (cleanup == Trivial || cleanup == OwnedCallable)
    CallableValue =>
      representation == I64 && (cleanup == Trivial || cleanup == OwnedCallable)
    ByteSequenceValue =>
      representation == I32 && (cleanup == Trivial || cleanup == OwnedRef)
    ArrayValue =>
      representation == I32 && (cleanup == Trivial || cleanup == OwnedRef)
    DataValue(family) => {
      if family.value < 0 || family.value >= self.image.data_family_count {
        self.fail(site, "DataFamilyId \{family.value} is out of range")
      }
      representation == I32 && (cleanup == Trivial || cleanup == OwnedRef)
    }
    EnvironmentValue(shape) => {
      if !(self.object_shape(site, shape) is Environment(_)) {
        self.fail(site, "environment value kind references a Data shape")
      }
      representation == I32 && (cleanup == Trivial || cleanup == OwnedRef)
    }
    ErasedValue => representation == I64 && cleanup == OwnedErased
  }
}

///|
fn result_shape(
  result : ResultAbi,
) -> (Representation, Cleanup, SemanticValueKind)? {
  match result {
    Unit => None
    Value(representation, cleanup, kind) =>
      Some((representation, cleanup, kind))
  }
}

///|
