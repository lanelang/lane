///|
fn BuslaneLowerer::lower_derive(
  self : BuslaneLowerer,
  plan : @checked.CheckedDerivePlan,
) -> @buslane.Expr {
  let deriver_type = @types.nominal_type_generic(plan.abi.deriver, [
    TypeArgument(plan.capability),
  ])
  let deriver = self.define_fresh_value(
    "_derive_deriver",
    Local,
    self.lower_type(deriver_type),
  )
  let body : @buslane.Expr = match plan.shape {
    Record(fields~) => self.lower_record_derive(plan, deriver, fields)
    Enumeration(variants~) =>
      self.lower_enumeration_derive(plan, deriver, variants)
  }
  Let(deriver, self.lower_expr(plan.deriver), body)
}

///|
fn BuslaneLowerer::lower_record_derive(
  self : BuslaneLowerer,
  plan : @checked.CheckedDerivePlan,
  deriver : @buslane.ValueId,
  fields : Array[@checked.CheckedDeriveField],
) -> @buslane.Expr {
  let mut derived = self.lower_derive_method_call(
    plan,
    deriver,
    plan.abi.deriver_unit,
    [],
    [],
  )
  let mut tail_type = @types.Type::Primitive(Unit)
  for index = fields.length() - 1; index >= 0; index = index - 1 {
    let field = fields[index]
    let field_derived = self.lower_derive_method_call(
      plan,
      deriver,
      plan.abi.deriver_field,
      [TypeArgument(field.type_)],
      [
        self.lower_derive_metadata(plan.abi.field_info, [field.name]),
        self.lower_derive_evidence(plan.evidence, index),
      ],
    )
    derived = self.lower_derive_method_call(
      plan,
      deriver,
      plan.abi.deriver_product,
      [TypeArgument(field.type_), TypeArgument(tail_type)],
      [field_derived, derived],
    )
    tail_type = derive_binary_type(plan.abi.product, field.type_, tail_type)
  }
  self.lower_derive_method_call(
    plan,
    deriver,
    plan.abi.deriver_record,
    [TypeArgument(plan.target), TypeArgument(plan.representation)],
    [self.lower_derive_type_info(plan), self.lower_derive_iso(plan), derived],
  )
}

///|
fn BuslaneLowerer::lower_enumeration_derive(
  self : BuslaneLowerer,
  plan : @checked.CheckedDerivePlan,
  deriver : @buslane.ValueId,
  variants : Array[@checked.CheckedDeriveVariant],
) -> @buslane.Expr {
  let evidence_offsets = []
  let mut evidence_offset = 0
  for variant in variants {
    evidence_offsets.push(evidence_offset)
    evidence_offset += variant.payload.length()
  }
  let mut derived = self.lower_derive_method_call(
    plan,
    deriver,
    plan.abi.deriver_void,
    [],
    [],
  )
  let mut tail_type = @types.Type::Constructor(plan.abi.void_type)
  for variant_index = variants.length() - 1
      variant_index >= 0
      variant_index = variant_index - 1 {
    let variant = variants[variant_index]
    let mut payload_derived = self.lower_derive_method_call(
      plan,
      deriver,
      plan.abi.deriver_unit,
      [],
      [],
    )
    let mut payload_tail_type = @types.Type::Primitive(Unit)
    for payload_index = variant.payload.length() - 1
        payload_index >= 0
        payload_index = payload_index - 1 {
      let payload_type = variant.payload[payload_index]
      payload_derived = self.lower_derive_method_call(
        plan,
        deriver,
        plan.abi.deriver_product,
        [TypeArgument(payload_type), TypeArgument(payload_tail_type)],
        [
          self.lower_derive_evidence(
            plan.evidence,
            evidence_offsets[variant_index] + payload_index,
          ),
          payload_derived,
        ],
      )
      payload_tail_type = derive_binary_type(
        plan.abi.product,
        payload_type,
        payload_tail_type,
      )
    }
    let variant_derived = self.lower_derive_method_call(
      plan,
      deriver,
      plan.abi.deriver_variant,
      [TypeArgument(payload_tail_type)],
      [
        self.lower_derive_metadata(plan.abi.variant_info, [variant.name]),
        payload_derived,
      ],
    )
    derived = self.lower_derive_method_call(
      plan,
      deriver,
      plan.abi.deriver_sum,
      [TypeArgument(payload_tail_type), TypeArgument(tail_type)],
      [variant_derived, derived],
    )
    tail_type = derive_binary_type(plan.abi.sum, payload_tail_type, tail_type)
  }
  self.lower_derive_method_call(
    plan,
    deriver,
    plan.abi.deriver_enumeration,
    [TypeArgument(plan.target), TypeArgument(plan.representation)],
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
) -> @buslane.Expr {
  let selector : @buslane.Expr = TypeApply(
    Ref(self.field_selector_id(method_field)),
    [self.lower_generic_argument(TypeArgument(plan.capability))],
  )
  let mut callee : @buslane.Expr = Call(selector, [Ref(deriver)])
  if !generic_arguments.is_empty() {
    callee = TypeApply(
      callee,
      generic_arguments.map(fn(argument) {
        self.lower_generic_argument(argument)
      }),
    )
  }
  Call(callee, arguments)
}

///|
fn BuslaneLowerer::lower_derive_evidence(
  self : BuslaneLowerer,
  evidence : Array[@checked.CheckedDeriveEvidence],
  index : Int,
) -> @buslane.Expr {
  guard evidence.get(index) is Some(value) else {
    abort("checked structural derivation evidence is incomplete")
  }
  self.lower_expr(value.value)
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
    payloads: values.map(fn(value) { Literal(String(value)) }),
  })
}

///|
fn BuslaneLowerer::lower_derive_iso(
  self : BuslaneLowerer,
  plan : @checked.CheckedDerivePlan,
) -> @buslane.Expr {
  Construct({
    data_constructor: self.struct_constructor_id(plan.abi.iso),
    type_arguments: [
      self.lower_generic_argument(TypeArgument(plan.target)),
      self.lower_generic_argument(TypeArgument(plan.representation)),
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
) -> @buslane.Expr {
  let parameter = self.define_fresh_value(
    "_derive_value",
    Local,
    self.lower_type(plan.target),
  )
  let body : @buslane.Expr = match plan.shape {
    Record(fields~) => {
      let target_arguments = derive_target_arguments(plan.target)
      self.lower_derive_product_value(
        fields.map(fn(field) {
          self.lower_derive_field(
            Ref(parameter),
            field.symbol,
            target_arguments,
          )
        }),
        fields.map(fn(field) { field.type_ }),
        plan.abi,
      )
    }
    Enumeration(variants~) =>
      self.lower_derive_to_enumeration(plan, Ref(parameter), variants)
  }
  Function({
    parameters: [parameter],
    result_type: self.lower_type(plan.representation),
    body,
  })
}

///|
fn BuslaneLowerer::lower_derive_from_function(
  self : BuslaneLowerer,
  plan : @checked.CheckedDerivePlan,
) -> @buslane.Expr {
  let parameter = self.define_fresh_value(
    "_derive_representation",
    Local,
    self.lower_type(plan.representation),
  )
  let body : @buslane.Expr = match plan.shape {
    Record(fields~) => {
      let target_arguments = derive_target_arguments(plan.target)
      Construct({
        data_constructor: self.struct_constructor_id(
          derive_target_symbol(plan.target),
        ),
        type_arguments: target_arguments.map(fn(argument) {
          self.lower_generic_argument(argument)
        }),
        hidden_witnesses: [],
        payloads: self.lower_derive_product_projections(
          Ref(parameter),
          fields.map(fn(field) { field.type_ }),
          plan.abi,
        ),
      })
    }
    Enumeration(variants~) =>
      self.lower_derive_from_enumeration(plan, Ref(parameter), variants)
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
  variants : Array[@checked.CheckedDeriveVariant],
) -> @buslane.Expr {
  let binder = self.define_fresh_value(
    "_derive_enum",
    MatchBinder,
    self.lower_type(plan.target),
  )
  let sum_types = derive_sum_suffix_types(plan.abi, variants)
  let alternatives : Array[@buslane.Alternative] = variants.mapi(fn(
    index,
    variant,
  ) {
    let payload_binders = variant.payload.map(fn(type_) {
      self.define_fresh_value(
        "_derive_payload",
        MatchBinder,
        self.lower_type(type_),
      )
    })
    {
      alt_constructor: DataCon(self.data_constructor_id(variant.symbol)),
      type_binders: [],
      value_binders: payload_binders,
      body: self.lower_derive_sum_injection(
        plan.abi,
        variants,
        index,
        0,
        self.lower_derive_product_value(
          payload_binders.map(fn(payload) { Ref(payload) }),
          variant.payload,
          plan.abi,
        ),
        sum_types,
      ),
    }
  })
  Match({
    scrutinee,
    binder,
    result_type: self.lower_type(plan.representation),
    alternatives,
  })
}

///|
fn BuslaneLowerer::lower_derive_from_enumeration(
  self : BuslaneLowerer,
  plan : @checked.CheckedDerivePlan,
  representation : @buslane.Expr,
  variants : Array[@checked.CheckedDeriveVariant],
) -> @buslane.Expr {
  self.lower_derive_sum_elimination(
    plan,
    variants,
    0,
    representation,
    derive_sum_suffix_types(plan.abi, variants),
  )
}

///|
fn BuslaneLowerer::lower_derive_sum_elimination(
  self : BuslaneLowerer,
  plan : @checked.CheckedDerivePlan,
  variants : Array[@checked.CheckedDeriveVariant],
  index : Int,
  scrutinee : @buslane.Expr,
  sum_types : Array[@types.Type],
) -> @buslane.Expr {
  let current_type = sum_types[index]
  let binder = self.define_fresh_value(
    "_derive_sum",
    MatchBinder,
    self.lower_type(current_type),
  )
  if index >= variants.length() {
    return Match({
      scrutinee,
      binder,
      result_type: self.lower_type(plan.target),
      alternatives: [],
    })
  }
  let variant = variants[index]
  let payload_type = derive_product_representation_type(
    plan.abi,
    variant.payload,
  )
  let payload = self.define_fresh_value(
    "_derive_payload",
    MatchBinder,
    self.lower_type(payload_type),
  )
  let tail = self.define_fresh_value(
    "_derive_tail",
    MatchBinder,
    self.lower_type(sum_types[index + 1]),
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
          type_arguments: target_arguments.map(fn(argument) {
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
          variants,
          index + 1,
          Ref(tail),
          sum_types,
        ),
      },
    ],
  })
}

///|
fn BuslaneLowerer::lower_derive_sum_injection(
  self : BuslaneLowerer,
  abi : @checked.CheckedDeriveAbi,
  variants : Array[@checked.CheckedDeriveVariant],
  target_index : Int,
  current_index : Int,
  payload : @buslane.Expr,
  sum_types : Array[@types.Type],
) -> @buslane.Expr {
  let payload_type = derive_product_representation_type(
    abi,
    variants[current_index].payload,
  )
  let tail_type = sum_types[current_index + 1]
  if current_index == target_index {
    return Construct({
      data_constructor: self.data_constructor_id(abi.sum_here),
      type_arguments: [
        self.lower_generic_argument(TypeArgument(payload_type)),
        self.lower_generic_argument(TypeArgument(tail_type)),
      ],
      hidden_witnesses: [],
      payloads: [payload],
    })
  }
  Construct({
    data_constructor: self.data_constructor_id(abi.sum_there),
    type_arguments: [
      self.lower_generic_argument(TypeArgument(payload_type)),
      self.lower_generic_argument(TypeArgument(tail_type)),
    ],
    hidden_witnesses: [],
    payloads: [
      self.lower_derive_sum_injection(
        abi,
        variants,
        target_index,
        current_index + 1,
        payload,
        sum_types,
      ),
    ],
  })
}

///|
fn BuslaneLowerer::lower_derive_product_value(
  self : BuslaneLowerer,
  values : Array[@buslane.Expr],
  types : Array[@types.Type],
  abi : @checked.CheckedDeriveAbi,
) -> @buslane.Expr {
  let mut result : @buslane.Expr = Literal(Unit)
  let mut result_type = @types.Type::Primitive(Unit)
  for index = values.length() - 1; index >= 0; index = index - 1 {
    result = Construct({
      data_constructor: self.struct_constructor_id(abi.product),
      type_arguments: [
        self.lower_generic_argument(TypeArgument(types[index])),
        self.lower_generic_argument(TypeArgument(result_type)),
      ],
      hidden_witnesses: [],
      payloads: [values[index], result],
    })
    result_type = derive_binary_type(abi.product, types[index], result_type)
  }
  result
}

///|
fn BuslaneLowerer::lower_derive_product_projections(
  self : BuslaneLowerer,
  value : @buslane.Expr,
  types : Array[@types.Type],
  abi : @checked.CheckedDeriveAbi,
) -> Array[@buslane.Expr] {
  let suffix_types = derive_product_suffix_types(abi, types)
  let projections = []
  let mut current = value
  for index in 0..<types.length() {
    let arguments : Array[@types.GenericArgument] = [
      TypeArgument(types[index]),
      TypeArgument(suffix_types[index + 1]),
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
) -> @buslane.Expr {
  let selector : @buslane.Expr = if owner_arguments.is_empty() {
    Ref(self.field_selector_id(field))
  } else {
    TypeApply(
      Ref(self.field_selector_id(field)),
      owner_arguments.map(fn(argument) { self.lower_generic_argument(argument) }),
    )
  }
  Call(selector, [base])
}

///|
fn derive_product_representation_type(
  abi : @checked.CheckedDeriveAbi,
  components : Array[@types.Type],
) -> @types.Type {
  derive_product_suffix_types(abi, components)[0]
}

///|
fn derive_product_suffix_types(
  abi : @checked.CheckedDeriveAbi,
  components : Array[@types.Type],
) -> Array[@types.Type] {
  let suffixes = Array::make(
    components.length() + 1,
    @types.Type::Primitive(Unit),
  )
  for index = components.length() - 1; index >= 0; index = index - 1 {
    suffixes[index] = derive_binary_type(
      abi.product,
      components[index],
      suffixes[index + 1],
    )
  }
  suffixes
}

///|
fn derive_sum_suffix_types(
  abi : @checked.CheckedDeriveAbi,
  variants : Array[@checked.CheckedDeriveVariant],
) -> Array[@types.Type] {
  let suffixes = Array::make(
    variants.length() + 1,
    @types.Type::Constructor(abi.void_type),
  )
  for index = variants.length() - 1; index >= 0; index = index - 1 {
    suffixes[index] = derive_binary_type(
      abi.sum,
      derive_product_representation_type(abi, variants[index].payload),
      suffixes[index + 1],
    )
  }
  suffixes
}

///|
fn derive_binary_type(
  type_constructor : @symbol.TypeSymbolId,
  first : @types.Type,
  second : @types.Type,
) -> @types.Type {
  @types.nominal_type(type_constructor, [first, second])
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
