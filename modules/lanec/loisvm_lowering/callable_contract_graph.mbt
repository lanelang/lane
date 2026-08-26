///|
priv enum PhysicalCallableContractSignatureValue {
  Unit
  Value(@bytecode.ValueAbi)
  Callable(Int)
} derive(Eq)

///|
priv struct PhysicalCallableContractSignature {
  witnesses : Array[@bytecode.ValueAbi]
  parameters : Array[PhysicalCallableContractSignatureValue]
  result : PhysicalCallableContractSignatureValue
} derive(Eq)

///|
fn PhysicalCallableContractCatalog::new() -> PhysicalCallableContractCatalog {
  { nodes: [], representatives: [], canonical: false, }
}

///|
fn PhysicalCallableContractCatalog::reserve(
  self : PhysicalCallableContractCatalog,
) -> PhysicalCallableContractId raise LoisvmLoweringError {
  if self.canonical {
    raise RepresentationSpecializationInvariant(
      detail="cannot reserve a recursive callable contract after graph canonicalization",
    )
  }
  let identity : PhysicalCallableContractId = { index: self.nodes.length(), }
  self.nodes.push(PhysicalCallableContractNode::Reserved)
  self.representatives.push(identity)
  identity
}

///|
fn PhysicalCallableContractCatalog::fill(
  self : PhysicalCallableContractCatalog,
  identity : PhysicalCallableContractId,
  contract : PhysicalCallableContract,
) -> Unit raise LoisvmLoweringError {
  guard self.nodes.get(identity.index) is Some(Reserved) else {
    raise RepresentationSpecializationInvariant(
      detail="callable-contract graph node was defined without one unique reservation",
    )
  }
  self.verify_references(contract, allow_reserved=true)
  self.nodes[identity.index] = Defined(contract)
}

///|
fn PhysicalCallableContractCatalog::intern(
  self : PhysicalCallableContractCatalog,
  contract : PhysicalCallableContract,
) -> PhysicalCallableContractId raise LoisvmLoweringError {
  let contract = if self.canonical {
    contract.remap(self.representatives)
  } else {
    contract
  }
  self.verify_references(contract, allow_reserved=!self.canonical)
  for index, node in self.nodes {
    if node is Defined(existing) && existing == contract {
      return self.canonical_identity({ index, })
    }
  }
  let identity : PhysicalCallableContractId = { index: self.nodes.length(), }
  self.nodes.push(Defined(contract))
  self.representatives.push(identity)
  identity
}

///|
fn PhysicalCallableContractCatalog::canonical_identity(
  self : PhysicalCallableContractCatalog,
  identity : PhysicalCallableContractId,
) -> PhysicalCallableContractId raise LoisvmLoweringError {
  guard self.representatives.get(identity.index) is Some(representative) else {
    raise RepresentationSpecializationInvariant(
      detail="callable-contract identity is outside its owning graph",
    )
  }
  representative
}

///|
fn PhysicalCallableContractCatalog::canonical_key(
  self : PhysicalCallableContractCatalog,
  key : CanonicalRuntimeTypeKey,
) -> CanonicalRuntimeTypeKey raise LoisvmLoweringError {
  match key {
    Unit | Value(_) => key
    Callable(identity) => Callable(self.canonical_identity(identity))
  }
}

///|
fn CanonicalRuntimeTypeKey::observation(
  self : CanonicalRuntimeTypeKey,
  contracts : PhysicalCallableContractCatalog,
) -> LoisvmRepresentationContract raise LoisvmLoweringError {
  match contracts.canonical_key(self) {
    Unit => LoisvmRepresentationContract::Unit
    Value(abi) => LoisvmRepresentationContract::Value(abi)
    Callable(contract) =>
      LoisvmRepresentationContract::Callable(contract=contract.index)
  }
}

///|
fn PhysicalCallableContractCatalog::observations(
  self : PhysicalCallableContractCatalog,
) -> Array[LoisvmCallableContractNode] raise LoisvmLoweringError {
  self.nodes.mapi((id, _) => {
    let identity : PhysicalCallableContractId = { index: id, }
    let representative = self.canonical_identity(identity)
    let contract = self.contract(identity)
    {
      id,
      representative: representative.index,
      witnesses: contract.witnesses.copy(),
      parameters: contract.parameters.map(parameter => {
        parameter.observation(self)
      }),
      result: contract.result.observation(self),
    }
  })
}

///|
fn PhysicalCallableParameterProjection::canonicalize(
  self : PhysicalCallableParameterProjection,
  contracts : PhysicalCallableContractCatalog,
) -> PhysicalCallableParameterProjection raise LoisvmLoweringError {
  match self {
    Unit => Unit
    Slot(key) => Slot(contracts.canonical_key(key))
    Product(fields) =>
      Product(fields.map(field => field.canonicalize(contracts)))
  }
}

///|
fn PhysicalCallableInterface::canonicalize(
  self : PhysicalCallableInterface,
  contracts : PhysicalCallableContractCatalog,
) -> PhysicalCallableInterface raise LoisvmLoweringError {
  {
    ..self,
    invocation: contracts.canonical_identity(self.invocation),
    parameters: self.parameters.map(parameter => {
      parameter.canonicalize(contracts)
    }),
  }
}

///|
fn PhysicalCallableContractCatalog::contract(
  self : PhysicalCallableContractCatalog,
  identity : PhysicalCallableContractId,
) -> PhysicalCallableContract raise LoisvmLoweringError {
  let identity = self.canonical_identity(identity)
  match self.nodes.get(identity.index) {
    Some(Defined(contract)) => contract
    Some(Reserved) =>
      raise RepresentationSpecializationInvariant(
        detail="callable-contract graph contains an incomplete node",
      )
    None =>
      raise RepresentationSpecializationInvariant(
        detail="callable-contract identity is outside its owning graph",
      )
  }
}

///|
fn ImageLowerer::callable_contract(
  self : ImageLowerer,
  identity : PhysicalCallableContractId,
) -> PhysicalCallableContract raise LoisvmLoweringError {
  self.callable_contracts.contract(identity)
}

///|
fn ImageLowerer::intern_callable_contract(
  self : ImageLowerer,
  contract : PhysicalCallableContract,
) -> PhysicalCallableContractId raise LoisvmLoweringError {
  self.callable_contracts.intern(contract)
}

///|
fn PhysicalAnfProgram::callable_contract(
  self : PhysicalAnfProgram,
  identity : PhysicalCallableContractId,
) -> PhysicalCallableContract raise LoisvmLoweringError {
  self.callable_contracts.contract(identity)
}

///|
fn FunctionLowerer::callable_contract(
  self : FunctionLowerer,
  identity : PhysicalCallableContractId,
) -> PhysicalCallableContract raise LoisvmLoweringError {
  self.physical_program.callable_contract(identity)
}

///|
fn PhysicalFunctionPlanner::callable_contract(
  self : PhysicalFunctionPlanner,
  identity : PhysicalCallableContractId,
) -> PhysicalCallableContract raise LoisvmLoweringError {
  self.physical.callable_contract(identity)
}

///|
fn PhysicalCallableContractCatalog::verify_references(
  self : PhysicalCallableContractCatalog,
  contract : PhysicalCallableContract,
  allow_reserved~ : Bool,
) -> Unit raise LoisvmLoweringError {
  for parameter in contract.parameters {
    self.verify_key_reference(parameter, allow_reserved~)
  }
  self.verify_key_reference(contract.result, allow_reserved~)
}

///|
fn PhysicalCallableContractCatalog::verify_key_reference(
  self : PhysicalCallableContractCatalog,
  key : CanonicalRuntimeTypeKey,
  allow_reserved~ : Bool,
) -> Unit raise LoisvmLoweringError {
  guard key is Callable(identity) else { return }
  match self.nodes.get(identity.index) {
    Some(Defined(_)) => ()
    Some(Reserved) if allow_reserved => ()
    Some(Reserved) =>
      raise RepresentationSpecializationInvariant(
        detail="canonical callable contract references an incomplete graph node",
      )
    None =>
      raise RepresentationSpecializationInvariant(
        detail="callable contract references an identity outside its owning graph",
      )
  }
}

///|
fn physical_callable_contract_signature(
  contract : PhysicalCallableContract,
  partitions : Array[Int],
) -> PhysicalCallableContractSignature raise LoisvmLoweringError {
  fn value(
    key : CanonicalRuntimeTypeKey,
    partitions : Array[Int],
  ) -> PhysicalCallableContractSignatureValue raise LoisvmLoweringError {
    match key {
      Unit => Unit
      Value(abi) => Value(abi)
      Callable(identity) => {
        guard partitions.get(identity.index) is Some(partition) else {
          raise RepresentationSpecializationInvariant(
            detail="callable-contract partition is missing a referenced node",
          )
        }
        Callable(partition)
      }
    }
  }
  {
    witnesses: contract.witnesses,
    parameters: contract.parameters.map(key => value(key, partitions)),
    result: value(contract.result, partitions),
  }
}

///|
fn PhysicalCallableContractCatalog::canonicalize(
  self : PhysicalCallableContractCatalog,
) -> Array[PhysicalCallableContractId] raise LoisvmLoweringError {
  if self.canonical {
    raise RepresentationSpecializationInvariant(
      detail="callable-contract graph was canonicalized more than once",
    )
  }
  let contracts = self.nodes.map(node => {
    match node {
      Defined(contract) => contract
      Reserved =>
        raise RepresentationSpecializationInvariant(
          detail="callable-contract graph cannot be frozen with an incomplete node",
        )
    }
  })
  let mut partitions = Array::make(contracts.length(), 0)
  for ;; {
    let signatures : Array[PhysicalCallableContractSignature] = []
    let next = Array::make(contracts.length(), 0)
    for index, contract in contracts {
      let signature = physical_callable_contract_signature(contract, partitions)
      let mut partition : Int? = None
      for candidate, existing in signatures {
        if existing == signature {
          partition = Some(candidate)
          break
        }
      }
      let partition = match partition {
        Some(partition) => partition
        None => {
          let partition = signatures.length()
          signatures.push(signature)
          partition
        }
      }
      next[index] = partition
    }
    if next == partitions {
      partitions = next
      break
    }
    partitions = next
  }
  let class_count = partitions.fold(init=0, (count, partition) => {
    count.max(partition + 1)
  })
  let representatives : Array[PhysicalCallableContractId?] = Array::make(
    class_count,
    None,
  )
  for index, partition in partitions {
    if representatives[partition] is None {
      representatives[partition] = Some({ index, })
    }
  }
  let identities = partitions.map(partition => {
    representatives[partition].unwrap_or_else(() => {
      raise RepresentationSpecializationInvariant(
        detail="callable-contract equivalence class has no representative",
      )
    })
  })
  for index, contract in contracts {
    self.nodes[index] = Defined(contract.remap(identities))
  }
  self.representatives = identities
  self.canonical = true
  identities
}

///|
fn PhysicalCallableContract::remap(
  self : PhysicalCallableContract,
  partitions : Array[PhysicalCallableContractId],
) -> PhysicalCallableContract raise LoisvmLoweringError {
  {
    witnesses: self.witnesses,
    parameters: self.parameters.map(key => {
      key.remap_callable_contract(partitions)
    }),
    result: self.result.remap_callable_contract(partitions),
  }
}

///|
fn CanonicalRuntimeTypeKey::remap_callable_contract(
  self : CanonicalRuntimeTypeKey,
  partitions : Array[PhysicalCallableContractId],
) -> CanonicalRuntimeTypeKey raise LoisvmLoweringError {
  match self {
    Unit | Value(_) => self
    Callable(identity) => {
      guard partitions.get(identity.index) is Some(identity) else {
        raise RepresentationSpecializationInvariant(
          detail="callable-contract remapping is missing a provisional identity",
        )
      }
      Callable(identity)
    }
  }
}

///|
fn CanonicalSpecializedEvidenceKey::remap_callable_contract(
  self : CanonicalSpecializedEvidenceKey,
  partitions : Array[PhysicalCallableContractId],
) -> CanonicalSpecializedEvidenceKey raise LoisvmLoweringError {
  match self {
    FirstOrder(key) => FirstOrder(key.remap_callable_contract(partitions))
    HigherKinded(_) => self
  }
}

///|
fn RepresentationSpecializationKey::remap_callable_contracts(
  self : RepresentationSpecializationKey,
  partitions : Array[PhysicalCallableContractId],
) -> RepresentationSpecializationKey raise LoisvmLoweringError {
  {
    ..self,
    specialized_evidence: self.specialized_evidence.map(entry => {
      (entry.0, entry.1.remap_callable_contract(partitions))
    }),
    captures: self.captures.map(capture => {
      ..capture,
      shape: capture.shape.remap_callable_contract(partitions),
    }),
    parameters: self.parameters.map(key => {
      key.remap_callable_contract(partitions)
    }),
    scalar_parameters: self.scalar_parameters.map(entry => {
      (
        entry.0,
        entry.1,
        entry.2.map(key => key.remap_callable_contract(partitions)),
      )
    }),
    result: self.result.remap_callable_contract(partitions),
  }
}

///|
fn PhysicalCallableContractCatalog::verify(
  self : PhysicalCallableContractCatalog,
) -> Unit raise LoisvmLoweringError {
  if !self.canonical {
    raise RepresentationSpecializationInvariant(
      detail="Physical ANF received an uncanonicalized callable-contract graph",
    )
  }
  for node in self.nodes {
    guard node is Defined(contract) else {
      raise RepresentationSpecializationInvariant(
        detail="Physical ANF received an incomplete callable-contract graph",
      )
    }
    self.verify_references(contract, allow_reserved=false)
  }
}
