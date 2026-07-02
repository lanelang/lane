///|
fn BuslaneLowerer::lower_handler(
  self : BuslaneLowerer,
  body : @checked.CheckedExpr?,
  handlers : Array[@checked.CheckedHandlerTable],
  final_branch : @checked.CheckedHandlerFinalBranch,
  result_type : @types.Type,
) -> @buslane.Expr {
  guard body is Some(body) else { abort("unchecked handler body") }
  guard final_branch.body is Some(final_body) else {
    abort("unchecked handler final branch")
  }
  let result_binder = self.define_value(
    final_branch.binder_symbol,
    MatchBinder,
    self.lower_type(body.type_()),
  )
  Handle({
    body: self.lower_expr(body),
    result_binder,
    result_type: self.lower_type(result_type),
    final_body: self.lower_expr(final_body),
    handlers: self.lower_handler_tables(
      self.lower_handler_tables_for_alternatives(handlers, result_type),
    ),
  })
}

///|
fn BuslaneLowerer::lower_handler_tables(
  self : BuslaneLowerer,
  tables : Array[LoweredHandlerTable],
) -> Array[@buslane.HandlerTable] {
  tables.map(fn(table) {
    {
      handled_effect: self.lower_effect(table.handled_effect),
      operations: table.operations.map(fn(operation) {
        self.lower_operation_alternative(operation)
      }),
    }
  })
}

///|
fn BuslaneLowerer::lower_operation_alternative(
  self : BuslaneLowerer,
  operation : LoweredOperationAlternative,
) -> @buslane.OperationAlternative {
  {
    operation: self.operation_id(operation.operation),
    payload_binders: operation.payload_binders,
    resume_binder: operation.resume_binder,
    body: operation.body,
  }
}

///|
fn BuslaneLowerer::lower_handler_tables_for_alternatives(
  self : BuslaneLowerer,
  handlers : Array[@checked.CheckedHandlerTable],
  result_type : @types.Type,
) -> Array[LoweredHandlerTable] {
  handlers.map(fn(handler) {
    {
      handled_effect: handler.handled_effect,
      operations: self.lower_handler_operation_groups(
        lower_handler_operation_groups(handler.operations),
        result_type,
      ),
    }
  })
}

///|
fn lower_handler_operation_groups(
  operations : Array[@checked.CheckedHandlerOperationArm],
) -> Array[LowerHandlerOperationGroup] {
  let groups = []
  for operation in operations {
    match lower_handler_operation_group_index(groups, operation.operation) {
      Some(index) => groups[index].arms.push(operation)
      None =>
        groups.push({
          operation: operation.operation,
          payload_types: operation.payload_types,
          resume_type: operation.resume_type,
          arms: [operation],
        })
    }
  }
  groups
}

///|
fn lower_handler_operation_group_index(
  groups : Array[LowerHandlerOperationGroup],
  operation : @symbol.OperationSymbolId,
) -> Int? {
  for index in 0..<groups.length() {
    if groups[index].operation == operation {
      return Some(index)
    }
  }
  None
}

///|
fn BuslaneLowerer::lower_handler_operation_groups(
  self : BuslaneLowerer,
  groups : Array[LowerHandlerOperationGroup],
  result_type : @types.Type,
) -> Array[LoweredOperationAlternative] {
  groups.map(fn(group) {
    self.lower_handler_operation_group(group, result_type)
  })
}

///|
fn BuslaneLowerer::lower_handler_operation_group(
  self : BuslaneLowerer,
  group : LowerHandlerOperationGroup,
  result_type : @types.Type,
) -> LoweredOperationAlternative {
  let payload_binders = group.payload_types.map(fn(type_) {
    self.define_fresh_value(Parameter, self.lower_type(type_))
  })
  let resume_binder = self.define_fresh_value(
    Parameter,
    self.lower_type(group.resume_type),
  )
  let rows = group.arms.map(fn(arm) {
    self.bind_value_alias(arm.resume_symbol, resume_binder)
    for pattern in arm.payload_patterns {
      self.define_pattern_binders(pattern)
    }
    guard arm.body is Some(body) else {
      abort("unchecked handler operation body")
    }
    { patterns: arm.payload_patterns, body: self.lower_expr(body) }
  })
  {
    operation: group.operation,
    payload_binders,
    resume_binder,
    body: self.lower_pattern_decision(
      payload_binders.map(fn(binder) { Ref(binder) }),
      payload_binders,
      rows,
      group.payload_types,
      self.lower_type(result_type),
    ),
  }
}
