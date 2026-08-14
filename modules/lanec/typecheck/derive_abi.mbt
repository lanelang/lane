///|
priv struct StructuralDeriveDeclarations {
  deriver : CheckedStructDeclaration
  product : CheckedStructDeclaration
  sum : CheckedEnumDeclaration
  iso : CheckedStructDeclaration
  type_info : CheckedStructDeclaration
  field_info : CheckedStructDeclaration
  variant_info : CheckedStructDeclaration
  void_declaration : CheckedEnumDeclaration
}

///|
priv struct StructuralDeriveMethods {
  unit : CheckedFieldDeclaration
  product : CheckedFieldDeclaration
  void_method : CheckedFieldDeclaration
  sum : CheckedFieldDeclaration
  field : CheckedFieldDeclaration
  variant : CheckedFieldDeclaration
  record : CheckedFieldDeclaration
  enumeration : CheckedFieldDeclaration
}

///|
fn SemanticChecker::structural_derive_abi(
  self : SemanticChecker,
  loc : SourceSpan,
) -> @checked.CheckedDeriveAbi? {
  guard self.canonical_basic_void_declaration(loc) is Some(void_declaration) else {
    return None
  }
  guard self.canonical_basic_struct(Deriver) is Some(deriver) &&
    self.canonical_basic_struct(Product) is Some(product) &&
    self.canonical_basic_enum(Sum) is Some(sum) &&
    self.canonical_basic_struct(Iso) is Some(iso) &&
    self.canonical_basic_struct(TypeInfo) is Some(type_info) &&
    self.canonical_basic_struct(FieldInfo) is Some(field_info) &&
    self.canonical_basic_struct(VariantInfo) is Some(variant_info) else {
    self.report_invalid_derive_abi(
      "required canonical declarations are missing", loc,
    )
    return None
  }
  let declarations = {
    deriver,
    product,
    sum,
    iso,
    type_info,
    field_info,
    variant_info,
    void_declaration,
  }
  match declarations.validate() {
    Ok(abi) => Some(abi)
    Err(reason) => {
      self.report_invalid_derive_abi(reason, loc)
      None
    }
  }
}

///|
fn SemanticChecker::report_invalid_derive_abi(
  self : SemanticChecker,
  reason : String,
  loc : SourceSpan,
) -> Unit {
  self.diagnostics.push({
    kind: InvalidStructuralDerivationInterface(reason~),
    loc,
  })
}

///|
fn StructuralDeriveDeclarations::validate(
  self : StructuralDeriveDeclarations,
) -> Result[@checked.CheckedDeriveAbi, String] {
  for
    entry in [
      ("Deriver", self.deriver),
      ("Product", self.product),
      ("Iso", self.iso),
      ("TypeInfo", self.type_info),
      ("FieldInfo", self.field_info),
      ("VariantInfo", self.variant_info),
    ] {
    let (name, declaration) = entry
    if !declaration.type_members.is_empty() {
      return Err("`\{name}` must not declare hidden type members")
    }
  }
  guard self.product.type_parameters is [product_a, product_b] &&
    product_a.kind == Type &&
    product_b.kind == Type &&
    self.product.fields is [product_head, product_tail] &&
    product_head.name == "head" &&
    product_head.type_ == Parameter(product_a.id) &&
    product_tail.name == "tail" &&
    product_tail.type_ == Parameter(product_b.id) else {
    return Err("`Product[A, B]` must contain `head : A` and `tail : B`")
  }
  guard self.sum.type_parameters is [sum_a, sum_b] &&
    sum_a.kind == Type &&
    sum_b.kind == Type &&
    self.sum.variants is [sum_here, sum_there] &&
    sum_here.name == "here" &&
    sum_here.type_parameters.is_empty() &&
    sum_here.payload == [Parameter(sum_a.id)] &&
    sum_there.name == "there" &&
    sum_there.type_parameters.is_empty() &&
    sum_there.payload == [Parameter(sum_b.id)] else {
    return Err("`Sum[A, B]` must contain `here(A)` and `there(B)`")
  }
  guard self.iso.type_parameters is [iso_t, iso_r] &&
    iso_t.kind == Type &&
    iso_r.kind == Type &&
    self.iso.fields is [iso_to, iso_from] &&
    iso_to.name == "to" &&
    iso_to.type_ == Function([Parameter(iso_t.id)], Parameter(iso_r.id), Empty) &&
    iso_from.name == "from" &&
    iso_from.type_ ==
    Function([Parameter(iso_r.id)], Parameter(iso_t.id), Empty) else {
    return Err(
      "`Iso[T, R]` must contain the canonical `to` and `from` functions",
    )
  }
  guard metadata_struct_valid(self.type_info, [
      ("name", Primitive(String)),
      ("qualified_name", Primitive(String)),
    ]) &&
    metadata_struct_valid(self.field_info, [("name", Primitive(String))]) &&
    metadata_struct_valid(self.variant_info, [("name", Primitive(String))]) else {
    return Err("structural derivation metadata declarations are malformed")
  }
  let methods = match self.validate_deriver() {
    Ok(methods) => methods
    Err(reason) => return Err(reason)
  }
  Ok({
    deriver: self.deriver.symbol,
    deriver_unit: methods.unit.symbol,
    deriver_product: methods.product.symbol,
    deriver_void: methods.void_method.symbol,
    deriver_sum: methods.sum.symbol,
    deriver_field: methods.field.symbol,
    deriver_variant: methods.variant.symbol,
    deriver_record: methods.record.symbol,
    deriver_enumeration: methods.enumeration.symbol,
    product: self.product.symbol,
    product_head: product_head.symbol,
    product_tail: product_tail.symbol,
    sum: self.sum.symbol,
    sum_here: sum_here.symbol,
    sum_there: sum_there.symbol,
    iso: self.iso.symbol,
    type_info: self.type_info.symbol,
    field_info: self.field_info.symbol,
    variant_info: self.variant_info.symbol,
    void_type: self.void_declaration.symbol,
  })
}

///|
fn StructuralDeriveDeclarations::validate_deriver(
  self : StructuralDeriveDeclarations,
) -> Result[StructuralDeriveMethods, String] {
  guard self.deriver.type_parameters is [capability] &&
    capability.kind == Function([Type], Type) else {
    return Err("`Deriver` must have one `[Type] -> Type` parameter")
  }
  guard self.deriver.fields
    is [unit, product, void_method, sum, field, variant, record, enumeration] &&
    unit.name == "unit" &&
    product.name == "product" &&
    void_method.name == "void" &&
    sum.name == "sum" &&
    field.name == "field" &&
    variant.name == "variant" &&
    record.name == "record" &&
    enumeration.name == "enumeration" else {
    return Err("`Deriver` fields must match the canonical declaration order")
  }
  let c = @types.Type::Parameter(capability.id)
  let c_unit = apply_unary_type_constructor(c, Primitive(Unit))
  let c_void = apply_unary_type_constructor(
    c,
    Constructor(self.void_declaration.symbol),
  )
  guard unit.type_ == Function([], c_unit, Empty) &&
    void_method.type_ == Function([], c_void, Empty) else {
    return Err("`Deriver.unit` or `Deriver.void` has the wrong type")
  }
  guard validate_binary_deriver_method(product.type_, c, self.product.symbol) &&
    validate_binary_deriver_method(sum.type_, c, self.sum.symbol) else {
    return Err("`Deriver.product` or `Deriver.sum` has the wrong type")
  }
  guard validate_named_deriver_method(field.type_, c, self.field_info.symbol) &&
    validate_named_deriver_method(variant.type_, c, self.variant_info.symbol) else {
    return Err("`Deriver.field` or `Deriver.variant` has the wrong type")
  }
  guard validate_nominal_deriver_method(
      record.type_,
      c,
      self.type_info.symbol,
      self.iso.symbol,
    ) &&
    validate_nominal_deriver_method(
      enumeration.type_,
      c,
      self.type_info.symbol,
      self.iso.symbol,
    ) else {
    return Err("`Deriver.record` or `Deriver.enumeration` has the wrong type")
  }
  Ok({ unit, product, void_method, sum, field, variant, record, enumeration })
}

///|
fn metadata_struct_valid(
  declaration : CheckedStructDeclaration,
  expected : Array[(String, @types.Type)],
) -> Bool {
  if !declaration.type_parameters.is_empty() ||
    declaration.fields.length() != expected.length() {
    return false
  }
  for index in 0..<expected.length() {
    let (name, type_) = expected[index]
    if declaration.fields[index].name != name ||
      declaration.fields[index].type_ != type_ {
      return false
    }
  }
  true
}

///|
fn validate_binary_deriver_method(
  type_ : @types.Type,
  capability : @types.Type,
  result_constructor : TypeSymbolId,
) -> Bool {
  guard type_ is Forall([a, b], body) && a.kind == Type && b.kind == Type else {
    return false
  }
  let a_type = @types.Type::Parameter(a.id)
  let b_type = @types.Type::Parameter(b.id)
  body ==
  Function(
    [
      apply_unary_type_constructor(capability, a_type),
      apply_unary_type_constructor(capability, b_type),
    ],
    apply_unary_type_constructor(
      capability,
      @types.nominal_type(result_constructor, [a_type, b_type]),
    ),
    Empty,
  )
}

///|
fn validate_named_deriver_method(
  type_ : @types.Type,
  capability : @types.Type,
  info_symbol : TypeSymbolId,
) -> Bool {
  guard type_ is Forall([a], body) && a.kind == Type else { return false }
  let a_type = @types.Type::Parameter(a.id)
  let c_a = apply_unary_type_constructor(capability, a_type)
  body == Function([Constructor(info_symbol), c_a], c_a, Empty)
}

///|
fn validate_nominal_deriver_method(
  type_ : @types.Type,
  capability : @types.Type,
  type_info_symbol : TypeSymbolId,
  iso_symbol : TypeSymbolId,
) -> Bool {
  guard type_ is Forall([t, r], body) && t.kind == Type && r.kind == Type else {
    return false
  }
  let t_type = @types.Type::Parameter(t.id)
  let r_type = @types.Type::Parameter(r.id)
  body ==
  Function(
    [
      Constructor(type_info_symbol),
      @types.nominal_type(iso_symbol, [t_type, r_type]),
      apply_unary_type_constructor(capability, r_type),
    ],
    apply_unary_type_constructor(capability, t_type),
    Empty,
  )
}

///|
fn apply_unary_type_constructor(
  type_constructor : @types.Type,
  argument : @types.Type,
) -> @types.Type {
  Apply(type_constructor, [TypeArgument(argument)])
}
