///|
pub fn[A] CheckedDeriveProduct::make(
  type_constructor : TypeSymbolId,
  components : Array[(A, @types.Type, CheckedDeriveEvidence)],
) -> CheckedDeriveProduct[A] {
  let suffixes = Array::make(
    components.length() + 1,
    @types.Type::Primitive(Unit),
  )
  for index = components.length() - 1; index >= 0; index = index - 1 {
    suffixes[index] = @types.nominal_type(type_constructor, [
      components[index].1,
      suffixes[index + 1],
    ])
  }
  {
    representation: suffixes[0],
    steps: components.mapi(fn(index, component) {
      {
        head: component.0,
        head_type: component.1,
        tail_type: suffixes[index + 1],
        evidence: component.2,
      }
    }),
  }
}

///|
pub fn CheckedDeriveSum::make(
  type_constructor : TypeSymbolId,
  empty_constructor : TypeSymbolId,
  variants : Array[CheckedDeriveVariant],
) -> CheckedDeriveSum {
  let suffixes = Array::make(
    variants.length() + 1,
    @types.Type::Constructor(empty_constructor),
  )
  for index = variants.length() - 1; index >= 0; index = index - 1 {
    suffixes[index] = @types.nominal_type(type_constructor, [
      variants[index].payload.representation,
      suffixes[index + 1],
    ])
  }
  {
    representation: suffixes[0],
    steps: variants.mapi(fn(index, head) {
      { head, tail_type: suffixes[index + 1], }
    }),
  }
}

///|
pub fn CheckedDeriveShape::representation(
  self : CheckedDeriveShape,
) -> @types.Type {
  match self {
    Record(product~) => product.representation
    Enumeration(sum~) => sum.representation
  }
}

///|
pub fn CheckedDeriveShape::for_each_evidence(
  self : CheckedDeriveShape,
  visit : (CheckedDeriveEvidence) -> Unit,
) -> Unit {
  match self {
    Record(product~) =>
      for step in product.steps {
        visit(step.evidence)
      }
    Enumeration(sum~) =>
      for sum_step in sum.steps {
        for payload_step in sum_step.head.payload.steps {
          visit(payload_step.evidence)
        }
      }
  }
}
