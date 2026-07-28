///|
priv struct StructuralDeriveAbi {
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
fn SemanticChecker::structural_derive_abi(
  self : SemanticChecker,
  loc : SourceSpan,
) -> StructuralDeriveAbi? {
  guard self.canonical_struct("Deriver") is Some(deriver) &&
    self.canonical_struct("Product") is Some(product) &&
    self.canonical_enum("Sum") is Some(sum) &&
    self.canonical_struct("Iso") is Some(iso) &&
    self.canonical_struct("TypeInfo") is Some(type_info) &&
    self.canonical_struct("FieldInfo") is Some(field_info) &&
    self.canonical_struct("VariantInfo") is Some(variant_info) &&
    self.module_enum("Basic.Data.Void", "Void") is Some(void_declaration) else {
    self.report_invalid_derive_abi(
      "required canonical declarations are missing", loc,
    )
    return None
  }
  let abi = {
    deriver,
    product,
    sum,
    iso,
    type_info,
    field_info,
    variant_info,
    void_declaration,
  }
  if abi.validate() is Some(reason) {
    self.report_invalid_derive_abi(reason, loc)
    return None
  }
  Some(abi)
}

///|
fn SemanticChecker::canonical_struct(
  self : SemanticChecker,
  name : String,
) -> CheckedStructDeclaration? {
  guard self.module_type_symbol("Basic.Trait.Derive", name) is Some(symbol) else {
    return None
  }
  self.declarations.checked_struct(symbol)
}

///|
fn SemanticChecker::canonical_enum(
  self : SemanticChecker,
  name : String,
) -> CheckedEnumDeclaration? {
  self.module_enum("Basic.Trait.Derive", name)
}

///|
fn SemanticChecker::module_enum(
  self : SemanticChecker,
  module_path : String,
  name : String,
) -> CheckedEnumDeclaration? {
  guard self.module_type_symbol(module_path, name) is Some(symbol) else {
    return None
  }
  self.declarations.checked_enum(symbol)
}

///|
fn SemanticChecker::module_type_symbol(
  self : SemanticChecker,
  module_path : String,
  name : String,
) -> TypeSymbolId? {
  if self.resolved_source.module_path.components.join(".") == module_path {
    for declaration in self.resolved_source.declarations {
      match declaration {
        Struct(declaration) if declaration.name == name =>
          return Some(declaration.symbol)
        Enum(declaration) if declaration.name == name =>
          return Some(declaration.symbol)
        ExternalType(declaration) if declaration.name == name =>
          return Some(declaration.symbol)
        _ => ()
      }
    }
    return None
  }
  guard self.imported_environment.find(module_path) is Some(interface) else {
    return None
  }
  for type_ in interface.types {
    match type_ {
      Struct(declaration) if declaration.name == name =>
        return Some(declaration.symbol)
      Enum(declaration) if declaration.name == name =>
        return Some(declaration.symbol)
      External(declaration) if declaration.name == name =>
        return Some(declaration.symbol)
      _ => ()
    }
  }
  None
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
fn StructuralDeriveAbi::validate(self : StructuralDeriveAbi) -> String? {
  guard self.void_declaration.type_parameters.is_empty() &&
    self.void_declaration.variants.is_empty() else {
    return Some("`Basic.Data.Void.Void` must be an empty enum")
  }
  guard self.product.type_parameters is [product_a, product_b] &&
    product_a.kind == Type &&
    product_b.kind == Type &&
    self.product.fields is [product_head, product_tail] &&
    product_head.name == "head" &&
    product_head.type_ == Parameter(product_a.id) &&
    product_tail.name == "tail" &&
    product_tail.type_ == Parameter(product_b.id) else {
    return Some("`Product[A, B]` must contain `head : A` and `tail : B`")
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
    return Some("`Sum[A, B]` must contain `here(A)` and `there(B)`")
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
    return Some(
      "`Iso[T, R]` must contain the canonical `to` and `from` functions",
    )
  }
  guard metadata_struct_valid(self.type_info, [
      ("name", Primitive(String)),
      ("qualified_name", Primitive(String)),
    ]) &&
    metadata_struct_valid(self.field_info, [("name", Primitive(String))]) &&
    metadata_struct_valid(self.variant_info, [("name", Primitive(String))]) else {
    return Some("structural derivation metadata declarations are malformed")
  }
  self.validate_deriver()
}

///|
fn StructuralDeriveAbi::validate_deriver(self : StructuralDeriveAbi) -> String? {
  guard self.deriver.type_parameters is [capability] &&
    capability.kind == Function([Type], Type) else {
    return Some("`Deriver` must have one `[Type] -> Type` parameter")
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
    return Some("`Deriver` fields must match the canonical declaration order")
  }
  let c = @types.Type::Parameter(capability.id)
  let c_unit = apply_unary_type_constructor(c, Primitive(Unit))
  let c_void = apply_unary_type_constructor(
    c,
    Constructor(self.void_declaration.symbol),
  )
  guard unit.type_ == Function([], c_unit, Empty) &&
    void_method.type_ == Function([], c_void, Empty) else {
    return Some("`Deriver.unit` or `Deriver.void` has the wrong type")
  }
  guard validate_binary_deriver_method(product.type_, c, self.product.symbol) &&
    validate_binary_deriver_method(sum.type_, c, self.sum.symbol) else {
    return Some("`Deriver.product` or `Deriver.sum` has the wrong type")
  }
  guard validate_named_deriver_method(field.type_, c, self.field_info.symbol) &&
    validate_named_deriver_method(variant.type_, c, self.variant_info.symbol) else {
    return Some("`Deriver.field` or `Deriver.variant` has the wrong type")
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
    return Some("`Deriver.record` or `Deriver.enumeration` has the wrong type")
  }
  None
}

///|
fn metadata_struct_valid(
  declaration : CheckedStructDeclaration,
  expected : Array[(String, @types.Type)],
) -> Bool {
  if !declaration.type_parameters.is_empty() ||
    !declaration.type_members.is_empty() ||
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

///|
fn CheckedStructDeclaration::required_field(
  self : CheckedStructDeclaration,
  name : String,
) -> CheckedFieldDeclaration {
  for field in self.fields {
    if field.name == name {
      return field
    }
  }
  abort("validated structural derivation field is missing")
}

///|
fn CheckedEnumDeclaration::required_variant(
  self : CheckedEnumDeclaration,
  name : String,
) -> CheckedVariantDeclaration {
  for variant in self.variants {
    if variant.name == name {
      return variant
    }
  }
  abort("validated structural derivation variant is missing")
}
