///|
/// Compares runtime value contracts modulo alpha-renaming of evidence binders.
/// Type-expression identities drive evidence instantiation, but do not form
/// part of a value's runtime ABI.
pub fn RuntimeMetadata::types_representation_equivalent(
  self : RuntimeMetadata,
  left : RuntimeType,
  right : RuntimeType,
) -> Bool {
  self.runtime_types_equal(left, right, [], [])
}

///|
fn RuntimeMetadata::runtime_types_equal(
  self : RuntimeMetadata,
  left : RuntimeType,
  right : RuntimeType,
  left_bound : Array[RuntimeEvidenceId],
  right_bound : Array[RuntimeEvidenceId],
) -> Bool {
  match (left, right) {
    (Unit, Unit) | (ByteSequence, ByteSequence) => true
    (OpaqueReference(left), OpaqueReference(right)) => left == right
    (Scalar(left), Scalar(right)) => left == right
    // Runtime data values carry their own erased-field witnesses. Nominal
    // arguments select those witnesses when constructing or projecting the
    // object, but are not part of the value's callable ABI.
    (Data(left_owner, _), Data(right_owner, _)) => left_owner == right_owner
    (
      Callable(_, _)
      | Forall(_, _) as left_callable,
      Callable(_, _)
      | Forall(_, _) as right_callable,
    ) => {
      let (left_parameters, left_arguments, left_result) = runtime_callable_parts(
        left_callable,
      )
      let (right_parameters, right_arguments, right_result) = runtime_callable_parts(
        right_callable,
      )
      guard runtime_parameter_arities_equal(left_parameters, right_parameters) else {
        return false
      }
      let nested_left = left_bound.copy()
      nested_left.append(left_parameters.map(parameter => parameter.id))
      let nested_right = right_bound.copy()
      nested_right.append(right_parameters.map(parameter => parameter.id))
      self.runtime_type_arrays_equal(
        left_arguments, right_arguments, nested_left, nested_right,
      ) &&
      self.runtime_types_equal(
        left_result, right_result, nested_left, nested_right,
      )
    }
    (Erased(_, left_evidence), Erased(_, right_evidence)) =>
      runtime_evidence_equal(
        left_evidence, right_evidence, left_bound, right_bound,
      )
    _ => false
  }
}

///|
fn runtime_callable_parts(
  type_ : RuntimeType,
) -> (Array[RuntimeEvidenceParameter], Array[RuntimeType], RuntimeType) {
  match type_ {
    Forall(parameters, body) => {
      let (nested_parameters, arguments, result) = runtime_callable_parts(body)
      (parameters + nested_parameters, arguments, result)
    }
    Callable(arguments, result) => ([], arguments, result)
    _ => abort("runtime callable decomposition received a non-callable type")
  }
}

///|
fn RuntimeMetadata::runtime_type_arrays_equal(
  self : RuntimeMetadata,
  left : Array[RuntimeType],
  right : Array[RuntimeType],
  left_bound : Array[RuntimeEvidenceId],
  right_bound : Array[RuntimeEvidenceId],
) -> Bool {
  guard left.length() == right.length() else { return false }
  for index in 0..<left.length() {
    if !self.runtime_types_equal(
        left[index],
        right[index],
        left_bound,
        right_bound,
      ) {
      return false
    }
  }
  true
}

///|
fn runtime_evidence_equal(
  left : RuntimeEvidence,
  right : RuntimeEvidence,
  left_bound : Array[RuntimeEvidenceId],
  right_bound : Array[RuntimeEvidenceId],
) -> Bool {
  match (left, right) {
    (Static(left), Static(right)) => left == right
    (Parameter(left), Parameter(right)) =>
      runtime_parameter_equal(left, right, left_bound, right_bound)
    (Apply(left_callee, left_arguments), Apply(right_callee, right_arguments)) =>
      runtime_evidence_arrays_equal(
        left_arguments, right_arguments, left_bound, right_bound,
      ) &&
      runtime_evidence_equal(left_callee, right_callee, left_bound, right_bound)
    (Lambda(left_parameters, left_body), Lambda(right_parameters, right_body)) => {
      guard runtime_parameter_arities_equal(left_parameters, right_parameters) else {
        return false
      }
      let nested_left = left_bound.copy()
      nested_left.append(left_parameters.map(parameter => parameter.id))
      let nested_right = right_bound.copy()
      nested_right.append(right_parameters.map(parameter => parameter.id))
      runtime_evidence_equal(left_body, right_body, nested_left, nested_right)
    }
    _ => false
  }
}

///|
fn runtime_parameter_arities_equal(
  left : Array[RuntimeEvidenceParameter],
  right : Array[RuntimeEvidenceParameter],
) -> Bool {
  guard left.length() == right.length() else { return false }
  for index in 0..<left.length() {
    if left[index].arity != right[index].arity {
      return false
    }
  }
  true
}

///|
fn runtime_parameter_equal(
  left : RuntimeEvidenceId,
  right : RuntimeEvidenceId,
  left_bound : Array[RuntimeEvidenceId],
  right_bound : Array[RuntimeEvidenceId],
) -> Bool {
  let left_index = runtime_bound_index(left_bound, left)
  let right_index = runtime_bound_index(right_bound, right)
  match (left_index, right_index) {
    (Some(left), Some(right)) => left == right
    (None, None) => left == right
    _ => false
  }
}

///|
fn runtime_evidence_arrays_equal(
  left : Array[RuntimeEvidence],
  right : Array[RuntimeEvidence],
  left_bound : Array[RuntimeEvidenceId],
  right_bound : Array[RuntimeEvidenceId],
) -> Bool {
  guard left.length() == right.length() else { return false }
  for index in 0..<left.length() {
    if !runtime_evidence_equal(
        left[index],
        right[index],
        left_bound,
        right_bound,
      ) {
      return false
    }
  }
  true
}

///|
fn runtime_bound_index(
  bound : Array[RuntimeEvidenceId],
  parameter : RuntimeEvidenceId,
) -> Int? {
  for offset in 0..<bound.length() {
    let index = bound.length() - offset - 1
    if bound[index] == parameter {
      return Some(index)
    }
  }
  None
}
