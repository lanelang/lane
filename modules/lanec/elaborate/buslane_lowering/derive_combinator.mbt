///|
fn BuslaneLowerer::lower_derive(
  self : BuslaneLowerer,
  plan : @checked.CheckedDerivePlan,
) -> @buslane.Expr raise BuslaneLoweringError {
  let deriver_type = @types.nominal_type_generic(plan.abi.deriver, [
    TypeArgument(plan.capability),
  ])
  let deriver = self.define_fresh_value(
    "_derive_deriver",
    Local,
    self.lower_type(deriver_type),
  )
  let body : @buslane.Expr = match plan.shape {
    Record(product~) => self.lower_record_derive(plan, deriver, product)
    Enumeration(sum~) => self.lower_enumeration_derive(plan, deriver, sum)
  }
  Let(deriver, self.lower_expr(plan.deriver.value()), body)
}

///|
fn BuslaneLowerer::lower_record_derive(
  self : BuslaneLowerer,
  plan : @checked.CheckedDerivePlan,
  deriver : @buslane.ValueId,
  product : @checked.CheckedDeriveProduct[@checked.CheckedDeriveField],
) -> @buslane.Expr raise BuslaneLoweringError {
  let mut derived = self.lower_derive_method_call(
    plan,
    deriver,
    plan.abi.deriver_unit,
    [],
    [],
  )
  for index = product.steps.length() - 1; index >= 0; index = index - 1 {
    let step = product.steps[index]
    let field = step.head
    let field_derived = self.lower_derive_method_call(
      plan,
      deriver,
      plan.abi.deriver_field,
      [TypeArgument(step.head_type)],
      [
        self.lower_derive_metadata(plan.abi.field_info, [field.name]),
        self.lower_expr(step.evidence.selection.value),
      ],
    )
    derived = self.lower_derive_method_call(
      plan,
      deriver,
      plan.abi.deriver_product,
      [TypeArgument(step.head_type), TypeArgument(step.tail_type)],
      [field_derived, derived],
    )
  }
  self.lower_derive_method_call(
    plan,
    deriver,
    plan.abi.deriver_record,
    [TypeArgument(plan.target), TypeArgument(product.representation)],
    [self.lower_derive_type_info(plan), self.lower_derive_iso(plan), derived],
  )
}

///|
fn BuslaneLowerer::lower_enumeration_derive(
  self : BuslaneLowerer,
  plan : @checked.CheckedDerivePlan,
  deriver : @buslane.ValueId,
  sum : @checked.CheckedDeriveSum,
) -> @buslane.Expr raise BuslaneLoweringError {
  let mut derived = self.lower_derive_method_call(
    plan,
    deriver,
    plan.abi.deriver_void,
    [],
    [],
  )
  for variant_index = sum.steps.length() - 1
      variant_index >= 0
      variant_index = variant_index - 1 {
    let sum_step = sum.steps[variant_index]
    let variant = sum_step.head
    let mut payload_derived = self.lower_derive_method_call(
      plan,
      deriver,
      plan.abi.deriver_unit,
      [],
      [],
    )
    for payload_index = variant.payload.steps.length() - 1
        payload_index >= 0
        payload_index = payload_index - 1 {
      let payload_step = variant.payload.steps[payload_index]
      payload_derived = self.lower_derive_method_call(
        plan,
        deriver,
        plan.abi.deriver_product,
        [
          TypeArgument(payload_step.head_type),
          TypeArgument(payload_step.tail_type),
        ],
        [
          self.lower_expr(payload_step.evidence.selection.value),
          payload_derived,
        ],
      )
    }
    let variant_derived = self.lower_derive_method_call(
      plan,
      deriver,
      plan.abi.deriver_variant,
      [TypeArgument(variant.payload.representation)],
      [
        self.lower_derive_metadata(plan.abi.variant_info, [variant.name]),
        payload_derived,
      ],
    )
    derived = self.lower_derive_method_call(
      plan,
      deriver,
      plan.abi.deriver_sum,
      [
        TypeArgument(variant.payload.representation),
        TypeArgument(sum_step.tail_type),
      ],
      [variant_derived, derived],
    )
  }
  self.lower_derive_method_call(
    plan,
    deriver,
    plan.abi.deriver_enumeration,
    [TypeArgument(plan.target), TypeArgument(sum.representation)],
    [self.lower_derive_type_info(plan), self.lower_derive_iso(plan), derived],
  )
}

///|
fn BuslaneLowerer::lower_derive_method_call(
  self : BuslaneLowerer,
  plan : @checked.CheckedDerivePlan,
  deriver : @buslane.ValueId,
  method_field : @symbol.FieldSymbolId,
  generic_arguments : Array[@types.GenericArgument],
  arguments : Array[@buslane.Expr],
) -> @buslane.Expr raise BuslaneLoweringError {
  let selector : @buslane.Expr = TypeApply(
    Ref(self.field_selector_id(method_field)),
    [self.lower_generic_argument(TypeArgument(plan.capability))],
  )
  let mut callee : @buslane.Expr = Call(selector, [Ref(deriver)])
  if !generic_arguments.is_empty() {
    callee = TypeApply(
      callee,
      generic_arguments.map(argument => self.lower_generic_argument(argument)),
    )
  }
  Call(callee, arguments)
}

///|
fn BuslaneLowerer::lower_derive_type_info(
  self : BuslaneLowerer,
  plan : @checked.CheckedDerivePlan,
) -> @buslane.Expr {
  self.lower_derive_metadata(plan.abi.type_info, [
    plan.metadata.name,
    plan.metadata.qualified_name,
  ])
}

///|
fn BuslaneLowerer::lower_derive_metadata(
  self : BuslaneLowerer,
  type_symbol : @symbol.TypeSymbolId,
  values : Array[String],
) -> @buslane.Expr {
  Construct({
    data_constructor: self.struct_constructor_id(type_symbol),
    type_arguments: [],
    hidden_witnesses: [],
    payloads: values.map(value => Literal(String(value))),
  })
}
