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
  match read_u8(self) {
    0 => Unit
    1 => Bool(read_bool(self))
    2 => Int(read_i64_le(self))
    3 => Double(read_f64_le(self))
    4 => String(read_string(self))
    tag => invalid_tag(offset~, domain="Literal", tag~)
  }
}

///|
fn @bytecodec.ByteWriter::write_top_terms(
  self : @bytecodec.ByteWriter,
  terms : Array[TopTerm],
) -> Unit {
  self.write_u32_le(terms.length())
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
  match read_u8(self) {
    0 => Let(self.read_value_id(), self.read_expr())
    1 => LetRec(self.read_recursive_bindings())
    2 => External(self.read_value_id())
    tag => invalid_tag(offset~, domain="TopTerm", tag~)
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
  match read_u8(self) {
    0 => Ref(self.read_value_id())
    1 => Literal(self.read_literal())
    2 => Function(self.read_function_expr())
    3 => Call(self.read_expr(), self.read_exprs())
    4 => TypeLambda(self.read_type_parameter_ids(), self.read_expr())
    5 => TypeApply(self.read_expr(), self.read_generic_arguments())
    6 => Construct(self.read_construct_expr())
    7 => Let(self.read_value_id(), self.read_expr(), self.read_expr())
    8 => LetRec(self.read_recursive_bindings(), self.read_expr())
    9 => Match(self.read_match_expr())
    10 => Perform(self.read_perform_expr())
    11 => Handle(self.read_handle_expr())
    12 => Resume(self.read_value_id())
    tag => invalid_tag(offset~, domain="Expr", tag~)
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
