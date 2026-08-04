///|
fn BuslaneLowerer::lower_derive_iso(
  self : BuslaneLowerer,
  plan : @checked.CheckedDerivePlan,
) -> @buslane.Expr raise BuslaneLoweringError {
  let representation = plan.shape.representation()
  Construct({
    data_constructor: self.struct_constructor_id(plan.abi.iso),
    type_arguments: [
      self.lower_generic_argument(TypeArgument(plan.target)),
      self.lower_generic_argument(TypeArgument(representation)),
    ],
    hidden_witnesses: [],
    payloads: [
      self.lower_derive_to_function(plan),
      self.lower_derive_from_function(plan),
    ],
  })
}

///|
fn BuslaneLowerer::lower_derive_to_function(
  self : BuslaneLowerer,
  plan : @checked.CheckedDerivePlan,
) -> @buslane.Expr raise BuslaneLoweringError {
  let parameter = self.define_fresh_value(
    "_derive_value",
    Local,
    self.lower_type(plan.target),
  )
  let body : @buslane.Expr = match plan.shape {
    Record(product~) => {
      let target_arguments = derive_target_arguments(plan.target)
      self.lower_derive_product_value(
        product.steps.map(step => {
          self.lower_derive_field(
            Ref(parameter),
            step.head.symbol,
            target_arguments,
          )
        }),
        product,
        plan.abi,
      )
    }
    Enumeration(sum~) =>
      self.lower_derive_to_enumeration(plan, Ref(parameter), sum)
  }
  Function({
    parameters: [parameter],
    result_type: self.lower_type(plan.shape.representation()),
    body,
  })
}

///|
fn BuslaneLowerer::lower_derive_from_function(
  self : BuslaneLowerer,
  plan : @checked.CheckedDerivePlan,
) -> @buslane.Expr raise BuslaneLoweringError {
  let parameter = self.define_fresh_value(
    "_derive_representation",
    Local,
    self.lower_type(plan.shape.representation()),
  )
  let body : @buslane.Expr = match plan.shape {
    Record(product~) => {
      let target_arguments = derive_target_arguments(plan.target)
      Construct({
        data_constructor: self.struct_constructor_id(
          derive_target_symbol(plan.target),
        ),
        type_arguments: target_arguments.map(argument => {
          self.lower_generic_argument(argument)
        }),
        hidden_witnesses: [],
        payloads: self.lower_derive_product_projections(
          Ref(parameter),
          product,
          plan.abi,
        ),
      })
    }
    Enumeration(sum~) =>
      self.lower_derive_from_enumeration(plan, Ref(parameter), sum)
  }
  Function({
    parameters: [parameter],
    result_type: self.lower_type(plan.target),
    body,
  })
}

///|
fn BuslaneLowerer::lower_derive_to_enumeration(
  self : BuslaneLowerer,
  plan : @checked.CheckedDerivePlan,
  scrutinee : @buslane.Expr,
  sum : @checked.CheckedDeriveSum,
) -> @buslane.Expr raise BuslaneLoweringError {
  let binder = self.define_fresh_value(
    "_derive_enum",
    MatchBinder,
    self.lower_type(plan.target),
  )
  let alternatives : Array[@buslane.Alternative] = sum.steps.mapi((
    index,
    sum_step,
  ) => {
    let variant = sum_step.head
    let payload_binders = variant.payload.steps.map(step => {
      self.define_fresh_value(
        "_derive_payload",
        MatchBinder,
        self.lower_type(step.head_type),
      )
    })
    {
      alt_constructor: DataCon(self.data_constructor_id(variant.symbol)),
      type_binders: [],
      value_binders: payload_binders,
      body: self.lower_derive_sum_injection(
        plan.abi,
        sum,
        index,
        0,
        self.lower_derive_product_value(
          payload_binders.map(payload => Ref(payload)),
          variant.payload,
          plan.abi,
        ),
      ),
    }
  })
  Match({
    scrutinee,
    binder,
    result_type: self.lower_type(sum.representation),
    alternatives,
  })
}

///|
fn BuslaneLowerer::lower_derive_from_enumeration(
  self : BuslaneLowerer,
  plan : @checked.CheckedDerivePlan,
  representation : @buslane.Expr,
  sum : @checked.CheckedDeriveSum,
) -> @buslane.Expr raise BuslaneLoweringError {
  self.lower_derive_sum_elimination(
    plan,
    sum,
    0,
    representation,
    sum.representation,
  )
}

///|
fn BuslaneLowerer::lower_derive_sum_elimination(
  self : BuslaneLowerer,
  plan : @checked.CheckedDerivePlan,
  sum : @checked.CheckedDeriveSum,
  index : Int,
  scrutinee : @buslane.Expr,
  current_type : @types.Type,
) -> @buslane.Expr raise BuslaneLoweringError {
  let binder = self.define_fresh_value(
    "_derive_sum",
    MatchBinder,
    self.lower_type(current_type),
  )
  if index >= sum.steps.length() {
    return Match({
      scrutinee,
      binder,
      result_type: self.lower_type(plan.target),
      alternatives: [],
    })
  }
  let sum_step = sum.steps[index]
  let variant = sum_step.head
  let payload = self.define_fresh_value(
    "_derive_payload",
    MatchBinder,
    self.lower_type(variant.payload.representation),
  )
  let tail = self.define_fresh_value(
    "_derive_tail",
    MatchBinder,
    self.lower_type(sum_step.tail_type),
  )
  let target_arguments = derive_target_arguments(plan.target)
  Match({
    scrutinee,
    binder,
    result_type: self.lower_type(plan.target),
    alternatives: [
      {
        alt_constructor: DataCon(self.data_constructor_id(plan.abi.sum_here)),
        type_binders: [],
        value_binders: [payload],
        body: Construct({
          data_constructor: self.data_constructor_id(variant.symbol),
          type_arguments: target_arguments.map(argument => {
            self.lower_generic_argument(argument)
          }),
          hidden_witnesses: [],
          payloads: self.lower_derive_product_projections(
            Ref(payload),
            variant.payload,
            plan.abi,
          ),
        }),
      },
      {
        alt_constructor: DataCon(self.data_constructor_id(plan.abi.sum_there)),
        type_binders: [],
        value_binders: [tail],
        body: self.lower_derive_sum_elimination(
          plan,
          sum,
          index + 1,
          Ref(tail),
          sum_step.tail_type,
        ),
      },
    ],
  })
}

///|
fn BuslaneLowerer::lower_derive_sum_injection(
  self : BuslaneLowerer,
  abi : @checked.CheckedDeriveAbi,
  sum : @checked.CheckedDeriveSum,
  target_index : Int,
  current_index : Int,
  payload : @buslane.Expr,
) -> @buslane.Expr raise BuslaneLoweringError {
  guard sum.steps.get(current_index) is Some(sum_step) else {
    abort("checked derive sum target is missing")
  }
  let payload_type = sum_step.head.payload.representation
  if current_index == target_index {
    return Construct({
      data_constructor: self.data_constructor_id(abi.sum_here),
      type_arguments: [
        self.lower_generic_argument(TypeArgument(payload_type)),
        self.lower_generic_argument(TypeArgument(sum_step.tail_type)),
      ],
      hidden_witnesses: [],
      payloads: [payload],
    })
  }
  Construct({
    data_constructor: self.data_constructor_id(abi.sum_there),
    type_arguments: [
      self.lower_generic_argument(TypeArgument(payload_type)),
      self.lower_generic_argument(TypeArgument(sum_step.tail_type)),
    ],
    hidden_witnesses: [],
    payloads: [
      self.lower_derive_sum_injection(
        abi,
        sum,
        target_index,
        current_index + 1,
        payload,
      ),
    ],
  })
}

///|
fn[A] BuslaneLowerer::lower_derive_product_value(
  self : BuslaneLowerer,
  values : Array[@buslane.Expr],
  product : @checked.CheckedDeriveProduct[A],
  abi : @checked.CheckedDeriveAbi,
) -> @buslane.Expr raise BuslaneLoweringError {
  if values.length() != product.steps.length() {
    abort("checked derive product values are incomplete")
  }
  let mut result : @buslane.Expr = Literal(Unit)
  for index = values.length() - 1; index >= 0; index = index - 1 {
    let step = product.steps[index]
    result = Construct({
      data_constructor: self.struct_constructor_id(abi.product),
      type_arguments: [
        self.lower_generic_argument(TypeArgument(step.head_type)),
        self.lower_generic_argument(TypeArgument(step.tail_type)),
      ],
      hidden_witnesses: [],
      payloads: [values[index], result],
    })
  }
  result
}

///|
fn[A] BuslaneLowerer::lower_derive_product_projections(
  self : BuslaneLowerer,
  value : @buslane.Expr,
  product : @checked.CheckedDeriveProduct[A],
  abi : @checked.CheckedDeriveAbi,
) -> Array[@buslane.Expr] raise BuslaneLoweringError {
  let projections = []
  let mut current = value
  for step in product.steps {
    let arguments : Array[@types.GenericArgument] = [
      TypeArgument(step.head_type),
      TypeArgument(step.tail_type),
    ]
    projections.push(
      self.lower_derive_field(current, abi.product_head, arguments),
    )
    current = self.lower_derive_field(current, abi.product_tail, arguments)
  }
  projections
}

///|
fn BuslaneLowerer::lower_derive_field(
  self : BuslaneLowerer,
  base : @buslane.Expr,
  field : @symbol.FieldSymbolId,
  owner_arguments : Array[@types.GenericArgument],
) -> @buslane.Expr raise BuslaneLoweringError {
  let selector : @buslane.Expr = if owner_arguments.is_empty() {
    Ref(self.field_selector_id(field))
  } else {
    TypeApply(
      Ref(self.field_selector_id(field)),
      owner_arguments.map(argument => self.lower_generic_argument(argument)),
    )
  }
  Call(selector, [base])
}

///|
fn derive_target_symbol(type_ : @types.Type) -> @symbol.TypeSymbolId {
  guard decompose_checked_nominal(type_) is Some((symbol, _)) else {
    abort("checked derive target must be a normalized nominal type")
  }
  symbol
}

///|
fn derive_target_arguments(
  type_ : @types.Type,
) -> Array[@types.GenericArgument] {
  guard decompose_checked_nominal(type_) is Some((_, arguments)) else {
    abort("checked derive target must be a normalized nominal type")
  }
  arguments
}
