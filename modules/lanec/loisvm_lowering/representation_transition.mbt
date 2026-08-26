///|
fn PhysicalRepresentationTransitionCatalog::new() -> PhysicalRepresentationTransitionCatalog {
  { transitions: [], }
}

///|
fn PhysicalRepresentationTransitionCatalog::intern(
  self : PhysicalRepresentationTransitionCatalog,
  transition : PhysicalRepresentationTransition,
) -> LoisvmRepresentationTransitionId {
  for index, existing in self.transitions {
    if existing == transition {
      return { index, }
    }
  }
  let identity : LoisvmRepresentationTransitionId = {
    index: self.transitions.length(),
  }
  self.transitions.push(transition)
  identity
}

///|
fn PhysicalRepresentationTransitionCatalog::transition(
  self : PhysicalRepresentationTransitionCatalog,
  identity : LoisvmRepresentationTransitionId,
) -> PhysicalRepresentationTransition raise LoisvmLoweringError {
  self.transitions
  .get(identity.index)
  .unwrap_or_else(() => {
    raise RepresentationSpecializationInvariant(
      detail="representation transition identity is outside its owning catalog",
    )
  })
}

///|
fn PhysicalRepresentationTransitionCatalog::verify(
  self : PhysicalRepresentationTransitionCatalog,
  callable_contracts : PhysicalCallableContractCatalog,
) -> Unit raise LoisvmLoweringError {
  for index, transition in self.transitions {
    callable_contracts.verify_key_reference(
      transition.source,
      allow_reserved=false,
    )
    callable_contracts.verify_key_reference(
      transition.target,
      allow_reserved=false,
    )
    if callable_contracts.canonical_key(transition.source) != transition.source ||
      callable_contracts.canonical_key(transition.target) != transition.target {
      raise RepresentationSpecializationInvariant(
        detail="representation transition contains a non-canonical callable-contract identity",
      )
    }
    if transition.source == transition.target {
      raise RepresentationSpecializationInvariant(
        detail="identity representation flow was interned as a transition",
      )
    }
    for previous in 0..<index {
      if self.transitions[previous] == transition {
        raise RepresentationSpecializationInvariant(
          detail="representation transition catalog contains a duplicate transition",
        )
      }
    }
    match transition.kind {
      Erase =>
        if !(transition.target is Value({ cleanup: OwnedErased, .. })) ||
          transition.source is Value({ cleanup: OwnedErased, .. }) {
          raise RepresentationSpecializationInvariant(
            detail="erase transition does not cross into erased representation",
          )
        }
      Unerase =>
        if !(transition.source is Value({ cleanup: OwnedErased, .. })) ||
          transition.target is Value({ cleanup: OwnedErased, .. }) {
          raise RepresentationSpecializationInvariant(
            detail="unerase transition does not cross out of erased representation",
          )
        }
      CallableAdapter =>
        if !(transition.source is Callable(_)) ||
          !(transition.target is Callable(_)) {
          raise RepresentationSpecializationInvariant(
            detail="callable-adapter transition does not connect callable contracts",
          )
        }
    }
  }
}

///|
fn LoisvmRepresentationTransitionBoundary::label(
  self : LoisvmRepresentationTransitionBoundary,
) -> String {
  match self {
    InitializerResult => "initializer result"
    FunctionResult => "function result"
    RecursiveBinding => "recursive binding"
    AtomBinding => "atom binding"
    CallResult => "call result"
    ScalarConstructionPayload => "scalar construction payload"
    DataConstructionPayload => "data construction payload"
    MatchResult => "match result"
    RepresentationCallArgument => "representation call argument"
    CallArgument => "call argument"
    CallableCapture => "callable capture"
    DataMatchPayload => "data match payload"
    CallableAdapterArgument => "callable adapter argument"
    CallableAdapterDiscard => "callable adapter discard"
    CallableAdapterResult => "callable adapter result"
  }
}

///|
fn PhysicalRepresentationTransitionKind::observation(
  self : PhysicalRepresentationTransitionKind,
) -> LoisvmRepresentationTransitionKind {
  match self {
    Erase => LoisvmRepresentationTransitionKind::Erase
    Unerase => LoisvmRepresentationTransitionKind::Unerase
    CallableAdapter => LoisvmRepresentationTransitionKind::CallableAdapter
  }
}

///|
fn PhysicalRepresentationTransitionCatalog::observations(
  self : PhysicalRepresentationTransitionCatalog,
  callable_contracts : PhysicalCallableContractCatalog,
) -> Array[LoisvmRepresentationTransition] raise LoisvmLoweringError {
  self.transitions.mapi((index, transition) => {
    id: { index, },
    source: transition.source.observation(callable_contracts),
    target: transition.target.observation(callable_contracts),
    kind: transition.kind.observation(),
  })
}
