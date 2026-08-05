///|
pub(all) enum BytecodeVerificationSite {
  Image
  Function(FunctionId)
  Block(FunctionId, BlockId)
  Instruction(FunctionId, BlockId, Int)
  Terminator(FunctionId, BlockId)
} derive(Debug, Eq)

///|
pub(all) suberror BytecodeVerificationError {
  InvalidBytecode(site~ : BytecodeVerificationSite, detail~ : String)
} derive(Debug, Eq)

///|
priv struct BytecodeVerifier {
  image : BytecodeImage
}

///|
pub fn verify_bytecode_image(
  image : BytecodeImage,
) -> Result[Unit, BytecodeVerificationError] {
  Ok(BytecodeVerifier::{ image, }.verify()) catch {
    error => Err(error)
  }
}

///|
fn BytecodeVerifier::verify(
  self : BytecodeVerifier,
) -> Unit raise BytecodeVerificationError {
  let image_site = BytecodeVerificationSite::Image
  if self.image.functions.is_empty() {
    self.fail(image_site, "function table must be nonempty")
  }
  self.verify_callable_abis()
  for index, entry in self.image.functions {
    let function : FunctionId = { value: index + 1 }
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
  self.verify_layouts_and_shapes()
  let global_dependencies = self.global_dependencies()
  for index, entry in self.image.functions {
    if entry is BytecodeBody(body) {
      let function : FunctionId = { value: index + 1 }
      self.verify_function(function, body)
      self.verify_function_flow(function, body, global_dependencies)
    }
  }
}

///|
fn BytecodeVerifier::verify_callable_abis(
  self : BytecodeVerifier,
) -> Unit raise BytecodeVerificationError {
  let site = BytecodeVerificationSite::Image
  if self.image.callable_abis.is_empty() {
    self.fail(site, "callable ABI table must be nonempty")
  }
  for index, abi in self.image.callable_abis {
    if abi.witness_count < 0 {
      self.fail(site, "callable ABI witness count must be nonnegative")
    }
    for parameter in abi.parameters {
      if !legal_metadata(parameter.representation, parameter.cleanup) {
        self.fail(site, "callable ABI contains an illegal parameter shape")
      }
    }
    if abi.result is Value(representation, cleanup) &&
      !legal_metadata(representation, cleanup) {
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
fn[T] BytecodeVerifier::fail(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  detail : String,
) -> T raise BytecodeVerificationError {
  ignore(self)
  raise InvalidBytecode(site~, detail~)
}

///|
fn BytecodeVerifier::function_entry(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  id : FunctionId,
) -> FunctionEntry raise BytecodeVerificationError {
  if id.value <= 0 || id.value > self.image.functions.length() {
    self.fail(site, "FunctionId \{id.value} is out of range")
  }
  self.image.functions[id.value - 1]
}

///|
fn BytecodeVerifier::callable_abi(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  id : CallableAbiId,
) -> CallableAbi raise BytecodeVerificationError {
  match self.image.callable_abi(id) {
    Some(abi) => abi
    None => self.fail(site, "CallableAbiId \{id.value} is out of range")
  }
}

///|
fn BytecodeVerifier::function_callable_abi(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  id : FunctionId,
) -> CallableAbi raise BytecodeVerificationError {
  ignore(self.function_entry(site, id))
  match self.image.function_callable_abi(id) {
    Some(abi) => abi
    None => self.fail(site, "function inputs do not define an ABI")
  }
}

///|
fn BytecodeVerifier::global_metadata(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  id : GlobalId,
) -> GlobalMetadata raise BytecodeVerificationError {
  if id.value < 0 || id.value >= self.image.globals.length() {
    self.fail(site, "GlobalId \{id.value} is out of range")
  }
  self.image.globals[id.value]
}

///|
fn BytecodeVerifier::layout_recipe(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  id : LayoutId,
) -> LayoutRecipe raise BytecodeVerificationError {
  if id.value <= 0 || id.value > self.image.layouts.length() {
    self.fail(site, "LayoutId \{id.value} is out of range")
  }
  self.image.layouts[id.value - 1]
}

///|
fn BytecodeVerifier::object_shape(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  id : ObjectShapeId,
) -> ObjectShape raise BytecodeVerificationError {
  if id.value < 0 || id.value >= self.image.object_shapes.length() {
    self.fail(site, "ObjectShapeId \{id.value} is out of range")
  }
  self.image.object_shapes[id.value]
}

///|
fn BytecodeVerifier::constant(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  id : ConstantId,
) -> Bytes raise BytecodeVerificationError {
  if id.value < 0 || id.value >= self.image.constants.length() {
    self.fail(site, "ConstantId \{id.value} is out of range")
  }
  self.image.constants[id.value]
}

///|
fn BytecodeVerifier::slot_metadata(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  body : FunctionBody,
  id : SlotId,
) -> SlotMetadata raise BytecodeVerificationError {
  if id.value < 0 || id.value >= body.slots.length() {
    self.fail(site, "SlotId \{id.value} is out of range")
  }
  body.slots[id.value]
}

///|
fn BytecodeVerifier::expect_slot(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  body : FunctionBody,
  id : SlotId,
  representation : Representation,
  cleanup : Cleanup,
) -> Unit raise BytecodeVerificationError {
  let actual = self.slot_metadata(site, body, id)
  if actual.representation != representation || actual.cleanup != cleanup {
    self.fail(
      site,
      "SlotId \{id.value} must be \{Repr(representation)} + \{Repr(cleanup)}, got \{Repr(actual.representation)} + \{Repr(actual.cleanup)}",
    )
  }
}

///|
fn BytecodeVerifier::expect_representation(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  body : FunctionBody,
  id : SlotId,
  representation : Representation,
) -> SlotMetadata raise BytecodeVerificationError {
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
fn BytecodeVerifier::expect_reference_operand(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  body : FunctionBody,
  id : SlotId,
) -> Unit raise BytecodeVerificationError {
  let actual = self.expect_representation(site, body, id, I32)
  if actual.cleanup != Trivial && actual.cleanup != OwnedRef {
    self.fail(site, "SlotId \{id.value} must hold a reference value")
  }
}

///|
fn BytecodeVerifier::expect_same_shape(
  self : BytecodeVerifier,
  site : BytecodeVerificationSite,
  body : FunctionBody,
  left : SlotId,
  right : SlotId,
) -> Unit raise BytecodeVerificationError {
  let left_metadata = self.slot_metadata(site, body, left)
  let right_metadata = self.slot_metadata(site, body, right)
  if left_metadata.representation != right_metadata.representation ||
    left_metadata.cleanup != right_metadata.cleanup {
    self.fail(
      site,
      "SlotId \{left.value} and SlotId \{right.value} have incompatible value shapes",
    )
  }
}

///|
fn BytecodeVerifier::verify_root_function(
  self : BytecodeVerifier,
  function : FunctionId,
  what : String,
) -> Unit raise BytecodeVerificationError {
  let site = BytecodeVerificationSite::Image
  match self.function_entry(site, function) {
    BytecodeBody(body) =>
      if body.inputs.environment is Some(_) ||
        !body.inputs.witnesses.is_empty() ||
        !body.inputs.user_parameters.is_empty() ||
        body.result != Unit {
        self.fail(
          site,
          "\{what} must be a no-context, zero-argument Unit bytecode body",
        )
      }
    RuntimeImport(_) => self.fail(site, "\{what} must be a bytecode body")
  }
}

///|
fn BytecodeVerifier::verify_globals(
  self : BytecodeVerifier,
) -> Unit raise BytecodeVerificationError {
  let site = BytecodeVerificationSite::Image
  for index, global in self.image.globals {
    if !legal_metadata(global.representation, global.cleanup) {
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
fn BytecodeVerifier::verify_layouts_and_shapes(
  self : BytecodeVerifier,
) -> Unit raise BytecodeVerificationError {
  let site = BytecodeVerificationSite::Image
  for layout in self.image.layouts {
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
  for shape in self.image.object_shapes {
    match shape {
      Data(data) =>
        self.verify_member_schemas(data.members, data.stored_witness_count)
      Environment(environment) =>
        self.verify_member_schemas(
          environment.members,
          environment.stored_witness_count,
        )
    }
  }
}

///|
fn BytecodeVerifier::verify_member_schemas(
  self : BytecodeVerifier,
  schemas : Array[MemberSchema],
  stored_witness_count : Int,
) -> Unit raise BytecodeVerificationError {
  let site = BytecodeVerificationSite::Image
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
  }
}

///|
fn legal_metadata(representation : Representation, cleanup : Cleanup) -> Bool {
  match (representation, cleanup) {
    (I32, Trivial | OwnedRef) => true
    (I64, Trivial | OwnedCallable | OwnedErased) => true
    (F32 | F64, Trivial) => true
    _ => false
  }
}

///|
fn result_shape(result : ResultAbi) -> (Representation, Cleanup)? {
  match result {
    Unit => None
    Value(representation, cleanup) => Some((representation, cleanup))
  }
}

///|
