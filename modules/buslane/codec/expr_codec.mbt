///|
fn @bytecodec.ByteWriter::write_literal(
  self : @bytecodec.ByteWriter,
  value : Literal,
) -> Unit {
  match value {
    Unit => self.write_u8(0)
    Bool(value) => {
      self.write_u8(1)
      self.write_bool(value)
    }
    Int(value) => {
      self.write_u8(2)
      self.write_i64_le(value)
    }
    Double(value) => {
      self.write_u8(3)
      self.write_f64_le(value)
    }
    String(value) => {
      self.write_u8(4)
      self.write_string(value)
    }
  }
}

///|
fn @bytecodec.ByteReader::read_literal(
  self : @bytecodec.ByteReader,
) -> Literal raise BuslaneDecodeError {
  let offset = self.offset()
  match self.view() {
    [u8be(0), .. rest] => {
      self.update_view(rest)
      Unit
    }
    [u8be(1), .. rest] => {
      self.update_view(rest)
      Bool(read_bool(self))
    }
    [u8be(2), .. rest] => {
      self.update_view(rest)
      Int(read_i64_le(self))
    }
    [u8be(3), .. rest] => {
      self.update_view(rest)
      Double(read_f64_le(self))
    }
    [u8be(4), .. rest] => {
      self.update_view(rest)
      String(read_string(self))
    }
    [u8be(tag), .. rest] => {
      self.update_view(rest)
      invalid_tag(offset~, domain="Literal", tag=tag.reinterpret_as_int())
    }
    _ => unexpected_u8(self, offset~)
  }
}

///|
fn @bytecodec.ByteWriter::write_top_terms(
  self : @bytecodec.ByteWriter,
  terms : Array[TopTerm],
) -> Unit {
  self.write_u32_le_int(terms.length())
  for term in terms {
    self.write_top_term(term)
  }
}

///|
fn @bytecodec.ByteReader::read_top_terms(
  self : @bytecodec.ByteReader,
) -> Array[TopTerm] raise BuslaneDecodeError {
  let terms = []
  for _ in 0..<read_u32_le(self) {
    terms.push(self.read_top_term())
  }
  terms
}

///|
fn @bytecodec.ByteWriter::write_top_term(
  self : @bytecodec.ByteWriter,
  term : TopTerm,
) -> Unit {
  match term {
    Let(id, expr) => {
      self.write_u8(0)
      self.write_value_id(id)
      self.write_expr(expr)
    }
    LetRec(bindings) => {
      self.write_u8(1)
      self.write_recursive_bindings(bindings)
    }
    External(id) => {
      self.write_u8(2)
      self.write_value_id(id)
    }
  }
}

///|
fn @bytecodec.ByteReader::read_top_term(
  self : @bytecodec.ByteReader,
) -> TopTerm raise BuslaneDecodeError {
  let offset = self.offset()
  match self.view() {
    [u8be(0), .. rest] => {
      self.update_view(rest)
      Let(self.read_value_id(), self.read_expr())
    }
    [u8be(1), .. rest] => {
      self.update_view(rest)
      LetRec(self.read_recursive_bindings())
    }
    [u8be(2), .. rest] => {
      self.update_view(rest)
      External(self.read_value_id())
    }
    [u8be(tag), .. rest] => {
      self.update_view(rest)
      invalid_tag(offset~, domain="TopTerm", tag=tag.reinterpret_as_int())
    }
    _ => unexpected_u8(self, offset~)
  }
}

///|
fn @bytecodec.ByteWriter::write_expr(
  self : @bytecodec.ByteWriter,
  expr : Expr,
) -> Unit {
  match expr {
    Ref(id) => {
      self.write_u8(0)
      self.write_value_id(id)
    }
    Literal(literal) => {
      self.write_u8(1)
      self.write_literal(literal)
    }
    Function(function_) => {
      self.write_u8(2)
      self.write_function_expr(function_)
    }
    Call(callee, arguments) => {
      self.write_u8(3)
      self.write_expr(callee)
      self.write_exprs(arguments)
    }
    TypeLambda(parameters, body) => {
      self.write_u8(4)
      self.write_type_parameter_ids(parameters)
      self.write_expr(body)
    }
    TypeApply(callee, arguments) => {
      self.write_u8(5)
      self.write_expr(callee)
      self.write_generic_arguments(arguments)
    }
    Construct(construct) => {
      self.write_u8(6)
      self.write_construct_expr(construct)
    }
    Let(id, value, body) => {
      self.write_u8(7)
      self.write_value_id(id)
      self.write_expr(value)
      self.write_expr(body)
    }
    LetRec(bindings, body) => {
      self.write_u8(8)
      self.write_recursive_bindings(bindings)
      self.write_expr(body)
    }
    Match(match_) => {
      self.write_u8(9)
      self.write_match_expr(match_)
    }
    Perform(perform) => {
      self.write_u8(10)
      self.write_perform_expr(perform)
    }
    Handle(handle) => {
      self.write_u8(11)
      self.write_handle_expr(handle)
    }
    Resume(id) => {
      self.write_u8(12)
      self.write_value_id(id)
    }
  }
}

///|
fn @bytecodec.ByteReader::read_expr(
  self : @bytecodec.ByteReader,
) -> Expr raise BuslaneDecodeError {
  let offset = self.offset()
  match self.view() {
    [u8be(0), .. rest] => {
      self.update_view(rest)
      Ref(self.read_value_id())
    }
    [u8be(1), .. rest] => {
      self.update_view(rest)
      Literal(self.read_literal())
    }
    [u8be(2), .. rest] => {
      self.update_view(rest)
      Function(self.read_function_expr())
    }
    [u8be(3), .. rest] => {
      self.update_view(rest)
      Call(self.read_expr(), self.read_exprs())
    }
    [u8be(4), .. rest] => {
      self.update_view(rest)
      TypeLambda(self.read_type_parameter_ids(), self.read_expr())
    }
    [u8be(5), .. rest] => {
      self.update_view(rest)
      TypeApply(self.read_expr(), self.read_generic_arguments())
    }
    [u8be(6), .. rest] => {
      self.update_view(rest)
      Construct(self.read_construct_expr())
    }
    [u8be(7), .. rest] => {
      self.update_view(rest)
      Let(self.read_value_id(), self.read_expr(), self.read_expr())
    }
    [u8be(8), .. rest] => {
      self.update_view(rest)
      LetRec(self.read_recursive_bindings(), self.read_expr())
    }
    [u8be(9), .. rest] => {
      self.update_view(rest)
      Match(self.read_match_expr())
    }
    [u8be(10), .. rest] => {
      self.update_view(rest)
      Perform(self.read_perform_expr())
    }
    [u8be(11), .. rest] => {
      self.update_view(rest)
      Handle(self.read_handle_expr())
    }
    [u8be(12), .. rest] => {
      self.update_view(rest)
      Resume(self.read_value_id())
    }
    [u8be(tag), .. rest] => {
      self.update_view(rest)
      invalid_tag(offset~, domain="Expr", tag=tag.reinterpret_as_int())
    }
    _ => unexpected_u8(self, offset~)
  }
}

///|
fn @bytecodec.ByteWriter::write_function_expr(
  self : @bytecodec.ByteWriter,
  expr : FunctionExpr,
) -> Unit {
  self.write_value_ids(expr.parameters)
  self.write_type(expr.result_type)
  self.write_expr(expr.body)
}

///|
fn @bytecodec.ByteReader::read_function_expr(
  self : @bytecodec.ByteReader,
) -> FunctionExpr raise BuslaneDecodeError {
  {
    parameters: self.read_value_ids(),
    result_type: self.read_type(),
    body: self.read_expr(),
  }
}

///|
fn @bytecodec.ByteWriter::write_construct_expr(
  self : @bytecodec.ByteWriter,
  expr : ConstructExpr,
) -> Unit {
  self.write_data_con_id(expr.data_constructor)
  self.write_generic_arguments(expr.type_arguments)
  self.write_generic_arguments(expr.hidden_witnesses)
  self.write_exprs(expr.payloads)
}

///|
fn @bytecodec.ByteReader::read_construct_expr(
  self : @bytecodec.ByteReader,
) -> ConstructExpr raise BuslaneDecodeError {
  {
    data_constructor: self.read_data_con_id(),
    type_arguments: self.read_generic_arguments(),
    hidden_witnesses: self.read_generic_arguments(),
    payloads: self.read_exprs(),
  }
}

///|
fn @bytecodec.ByteWriter::write_match_expr(
  self : @bytecodec.ByteWriter,
  expr : MatchExpr,
) -> Unit {
  self.write_expr(expr.scrutinee)
  self.write_value_id(expr.binder)
  self.write_type(expr.result_type)
  self.write_alternatives(expr.alternatives)
}

///|
fn @bytecodec.ByteReader::read_match_expr(
  self : @bytecodec.ByteReader,
) -> MatchExpr raise BuslaneDecodeError {
  {
    scrutinee: self.read_expr(),
    binder: self.read_value_id(),
    result_type: self.read_type(),
    alternatives: self.read_alternatives(),
  }
}

///|
fn @bytecodec.ByteWriter::write_perform_expr(
  self : @bytecodec.ByteWriter,
  expr : PerformExpr,
) -> Unit {
  self.write_operation_id(expr.operation)
  self.write_generic_arguments(expr.effect_arguments)
  self.write_generic_arguments(expr.hidden_witnesses)
  self.write_exprs(expr.payloads)
}

///|
fn @bytecodec.ByteReader::read_perform_expr(
  self : @bytecodec.ByteReader,
) -> PerformExpr raise BuslaneDecodeError {
  {
    operation: self.read_operation_id(),
    effect_arguments: self.read_generic_arguments(),
    hidden_witnesses: self.read_generic_arguments(),
    payloads: self.read_exprs(),
  }
}

///|
fn @bytecodec.ByteWriter::write_handle_expr(
  self : @bytecodec.ByteWriter,
  expr : HandleExpr,
) -> Unit {
  self.write_expr(expr.body)
  self.write_value_id(expr.result_binder)
  self.write_type(expr.result_type)
  self.write_expr(expr.final_body)
  self.write_handler_tables(expr.handlers)
}

///|
fn @bytecodec.ByteReader::read_handle_expr(
  self : @bytecodec.ByteReader,
) -> HandleExpr raise BuslaneDecodeError {
  {
    body: self.read_expr(),
    result_binder: self.read_value_id(),
    result_type: self.read_type(),
    final_body: self.read_expr(),
    handlers: self.read_handler_tables(),
  }
}
