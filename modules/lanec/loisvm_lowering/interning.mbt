///|
fn ImageLowerer::intern_string(
  self : ImageLowerer,
  value : String,
) -> @bytecode.ConstantId raise LoisvmLoweringError {
  let bytes = @utf8.encode(value)
  for byte in bytes {
    if byte.to_int() > 0x7F {
      raise NonAsciiString(value~)
    }
  }
  for index, existing in self.constants {
    if existing == bytes {
      return { value: index }
    }
  }
  let constant : @bytecode.ConstantId = { value: self.constants.length() }
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
      return { value: index + 1 }
    }
  }
  let layout : @bytecode.LayoutId = { value: self.layouts.length() + 1 }
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
      return { value: index }
    }
  }
  let id : @bytecode.ObjectShapeId = { value: self.object_shapes.length() }
  self.object_shapes.push(shape)
  id
}

///|
