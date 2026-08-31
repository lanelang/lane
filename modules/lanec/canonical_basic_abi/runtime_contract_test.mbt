///|
test "runtime contract preserves a missing declaration as a typed ABI error" {
  let contract = CanonicalBasicAbiRuntimeContract::from_types(
    Some({ index: 0, }),
    None,
  )
  guard contract.certify([], MetadataRegistry()) is Err(error) else {
    fail("missing canonical Void declaration unexpectedly certified")
  }
  assert_true(error is MissingDeclaration(provider=Void))
  debug_inspect(
    error.object_diagnostic("Broken"),
    content=(
      #|{
      #|  source_id: None,
      #|  message: "invalid canonical Basic ABI in module object `Broken`",
      #|  span: None,
      #|  severity: Error,
      #|  code: Some("E4208"),
      #|  labels: [],
      #|  notes: [
      #|    "canonical Basic provider `Basic.Data.Void.Void` is not bound to the certified runtime identity",
      #|    "module objects must carry the certified canonical Basic runtime contract before identity remapping begins",
      #|  ],
      #|  helps: ["recompile the module object from valid Lane source"],
      #|  facts: [],
      #|  suggestions: [],
      #|}
    ),
  )
}

///|
test "runtime contract certifies the exact WasmAddress object shape" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let type_id = metadata.define_type("WasmAddress", [])
  ignore(
    metadata.define_data_constructor("WasmAddress", type_id, [], [
      Primitive(ByteBuffer),
      Primitive(I32),
    ]),
  )
  let contract = CanonicalBasicAbiRuntimeContract::from_types(
    None,
    Some(type_id),
  )
  let declarations = [
    CanonicalBasicAbiObjectTypeDeclaration::{
      module_path: "Basic.Wasm.Abi",
      name: "WasmAddress",
      type_id,
    },
  ]
  assert_true(contract.certify(declarations, metadata) is Ok(_))
}

///|
test "runtime contract rejects a forged WasmAddress object shape" {
  let metadata = @buslane.MetadataRegistry::MetadataRegistry()
  let type_id = metadata.define_type("WasmAddress", [])
  ignore(
    metadata.define_data_constructor("WasmAddress", type_id, [], [
      Primitive(ByteBuffer),
      Primitive(I64),
    ]),
  )
  let contract = CanonicalBasicAbiRuntimeContract::from_types(
    None,
    Some(type_id),
  )
  let declarations = [
    CanonicalBasicAbiObjectTypeDeclaration::{
      module_path: "Basic.Wasm.Abi",
      name: "WasmAddress",
      type_id,
    },
  ]
  assert_true(
    contract.certify(declarations, metadata)
    is Err(InvalidDeclaration(provider=WasmAddress, reason=_)),
  )
}
