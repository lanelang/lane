///|
fn ImageLowerer::intern_string(
  self : ImageLowerer,
  value : String,
) -> @bytecode.ConstantId {
  let bytes = @utf8.encode(value)
  for index, existing in self.constants {
    if existing == bytes {
      return { value: index, }
    }
  }
  let constant : @bytecode.ConstantId = { value: self.constants.length(), }
  self.constants.push(bytes)
  constant
}

///|
fn ImageLowerer::intern_layout(
  self : ImageLowerer,
  recipe : @bytecode.LayoutRecipe,
) -> @bytecode.LayoutId {
  for index, existing in self.layouts {
    if existing == recipe {
      return { value: index + 1, }
    }
  }
  let layout : @bytecode.LayoutId = { value: self.layouts.length() + 1, }
  self.layouts.push(recipe)
  layout
}

///|
fn ImageLowerer::intern_object_shape(
  self : ImageLowerer,
  shape : @bytecode.ObjectShape,
) -> @bytecode.ObjectShapeId {
  for index, existing in self.object_shapes {
    if existing == shape {
      return { value: index, }
    }
  }
  let id : @bytecode.ObjectShapeId = { value: self.object_shapes.length(), }
  self.object_shapes.push(shape)
  ignore(
    self.intern_layout(
      match shape {
        Data(_) => Data(id)
        Environment(_) => Environment(id)
      },
    ),
  )
  id
}

///|
fn ImageLowerer::intern_data_family(
  self : ImageLowerer,
  owner : @buslane.TypeId,
) -> @bytecode.DataFamilyId {
  for index, existing in self.data_families {
    if existing == owner {
      return { value: index, }
    }
  }
  let family : @bytecode.DataFamilyId = { value: self.data_families.length(), }
  self.data_families.push(owner)
  family
}

///|
