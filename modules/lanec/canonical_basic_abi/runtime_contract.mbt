///|
/// The canonical Basic identities that remain semantically relevant after
/// source symbols have been lowered to Buslane metadata identities.
pub struct CanonicalBasicAbiRuntimeContract {
  void_type : @buslane.TypeId?
  wasm_address_type : @buslane.TypeId?
} derive(Debug, Eq)

///|
/// An untrusted module-object declaration projected without interpreting any
/// canonical Basic semantics.
pub(all) struct CanonicalBasicAbiObjectTypeDeclaration {
  module_path : String
  name : String
  type_id : @buslane.TypeId
} derive(Debug, Eq)

///|
pub(all) enum CanonicalBasicAbiRuntimeContractError {
  MissingDeclaration(provider~ : @abi.BasicTypeProvider)
  InvalidDeclaration(provider~ : @abi.BasicTypeProvider, reason~ : String)
} derive(Debug, Eq)

///|
/// A runtime contract whose declaration identity and Buslane shape have been
/// certified at the module-object trust boundary.
pub struct CertifiedCanonicalBasicAbiRuntimeContract {
  contract : CanonicalBasicAbiRuntimeContract
} derive(Debug, Eq)

///|
pub fn CanonicalBasicAbiRuntimeContract::empty() -> CanonicalBasicAbiRuntimeContract {
  { void_type: None, wasm_address_type: None, }
}

///|
pub fn CanonicalBasicAbiRuntimeContract::from_types(
  void_type : @buslane.TypeId?,
  wasm_address_type : @buslane.TypeId?,
) -> CanonicalBasicAbiRuntimeContract {
  { void_type, wasm_address_type, }
}

///|
pub fn CanonicalBasicAbiRuntimeContract::void_type(
  self : CanonicalBasicAbiRuntimeContract,
) -> @buslane.TypeId? {
  self.void_type
}

///|
pub fn CanonicalBasicAbiRuntimeContract::wasm_address_type(
  self : CanonicalBasicAbiRuntimeContract,
) -> @buslane.TypeId? {
  self.wasm_address_type
}

///|
pub fn lower_runtime_contract(
  checked : @checked.CheckedCanonicalBasicAbi,
  lower_type : (@symbol.TypeSymbolId) -> @buslane.TypeId,
) -> CanonicalBasicAbiRuntimeContract {
  {
    void_type: checked.type_symbol(Void).map(lower_type),
    wasm_address_type: checked.type_symbol(WasmAddress).map(lower_type),
  }
}

///|
pub fn CanonicalBasicAbiRuntimeContract::certify(
  self : CanonicalBasicAbiRuntimeContract,
  declarations : Array[CanonicalBasicAbiObjectTypeDeclaration],
  metadata : @buslane.MetadataRegistry,
) -> Result[
  CertifiedCanonicalBasicAbiRuntimeContract,
  CanonicalBasicAbiRuntimeContractError,
] {
  if self.void_type is Some(type_id) {
    let provider = @abi.BasicTypeProvider::Void
    guard declarations.any(declaration => {
      declaration.module_path == provider.module_path() &&
      declaration.name == provider.type_name() &&
      declaration.type_id == type_id
    }) else {
      return Err(MissingDeclaration(provider~))
    }
    guard metadata.type_info(type_id) is Some(info) &&
      info.flavor is Data &&
      info.parameters.is_empty() &&
      info.constructors.is_empty() else {
      return Err(
        InvalidDeclaration(
          provider~,
          reason="the declaration must lower to an empty data type",
        ),
      )
    }
  }
  if self.wasm_address_type is Some(type_id) {
    let provider = @abi.BasicTypeProvider::WasmAddress
    guard declarations.any(declaration => {
      declaration.module_path == provider.module_path() &&
      declaration.name == provider.type_name() &&
      declaration.type_id == type_id
    }) else {
      return Err(MissingDeclaration(provider~))
    }
    guard metadata.type_info(type_id) is Some(info) &&
      info.flavor is Data &&
      info.parameters.is_empty() &&
      info.constructors is [data_constructor] &&
      metadata.data_constructor_info(data_constructor) is Some(constructor_info) &&
      constructor_info.owner == type_id &&
      constructor_info.hidden_type_parameters.is_empty() &&
      constructor_info.payload_types == [Primitive(ByteBuffer), Primitive(I32)] else {
      return Err(
        InvalidDeclaration(
          provider~,
          reason="the declaration must lower to a data object containing `Bytes` and `I32` fields",
        ),
      )
    }
  }
  Ok({ contract: self, })
}

///|
pub fn CertifiedCanonicalBasicAbiRuntimeContract::void_type(
  self : CertifiedCanonicalBasicAbiRuntimeContract,
) -> @buslane.TypeId? {
  self.contract.void_type
}

///|
pub fn CertifiedCanonicalBasicAbiRuntimeContract::wasm_address_type(
  self : CertifiedCanonicalBasicAbiRuntimeContract,
) -> @buslane.TypeId? {
  self.contract.wasm_address_type
}
