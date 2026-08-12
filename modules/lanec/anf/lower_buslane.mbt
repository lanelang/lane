///|
priv struct AnfLowerer {
  mut next_temp : Int
  mut next_function : Int
}

///|
/// Lowers Buslane expression-tree core into ANF.
pub fn lower_buslane_program_to_anf(program : @buslane.Program) -> AnfProgram {
  let lowerer = AnfLowerer::{ next_temp: 0, next_function: 0 }
  simplify_anf_program({
    metadata: program.metadata,
    terms: program.terms.map(fn(term) { lowerer.lower_top_term(term) }),
  })
}

///|
/// Lowers verified effect-aware CPS Core directly to runtime ANF.
///
/// Effect projection is intentionally fused into this seam. The source
/// metadata is snapshotted, so observing or retaining the CPS Core program
/// cannot be affected by the one-way runtime projection.
pub fn lower_cps_core_to_runtime_anf(
  program : @buslane.Program,
) -> RuntimeAnfProgram {
  let runtime_program = runtime_buslane_projection(program)
  { program: lower_buslane_program_to_anf(runtime_program) }
}

///|
fn AnfLowerer::fresh_temp(self : AnfLowerer) -> AnfTempId {
  let temp = AnfTempId::{ index: self.next_temp }
  self.next_temp = self.next_temp + 1
  temp
}

///|
fn AnfLowerer::fresh_function(self : AnfLowerer) -> AnfFunctionId {
  let function = AnfFunctionId::{ value: self.next_function }
  self.next_function = self.next_function + 1
  function
}

///|
fn AnfLowerer::lower_top_term(
  self : AnfLowerer,
  term : @buslane.TopTerm,
) -> AnfTopTerm {
  match term {
    Let(id, expr) => Let(id, self.lower_bound_expr(expr, Some(id)))
    LetRec(bindings) =>
      LetRec(
        bindings.map(fn(binding) { self.lower_recursive_binding(binding) }),
      )
    External(id) => External(id)
  }
}

///|
fn AnfLowerer::lower_recursive_binding(
  self : AnfLowerer,
  binding : @buslane.RecursiveBinding,
) -> AnfRecursiveBinding {
  { id: binding.id, rhs: self.lower_recursable_atom(binding.rhs, binding.id) }
}

///|
fn AnfLowerer::lower_expr(self : AnfLowerer, expr : @buslane.Expr) -> AnfExpr {
  self.lower_bound_expr(expr, None)
}

///|
fn AnfLowerer::lower_bound_expr(
  self : AnfLowerer,
  expr : @buslane.Expr,
  source : @buslane.ValueId?,
) -> AnfExpr {
  self.lower_to_atom(expr, source, fn(atom) { Atom(atom) })
}

///|
fn AnfLowerer::lower_to_atom(
  self : AnfLowerer,
  expr : @buslane.Expr,
  source : @buslane.ValueId?,
  continuation : (AnfAtom) -> AnfExpr,
) -> AnfExpr {
  match expr {
    Ref(id) => continuation(Ref(id))
    Literal(literal) => continuation(Literal(literal))
    Function(function) =>
      continuation(Function(self.lower_function(function, source)))
    TypeLambda(type_parameters, body) =>
      continuation(
        TypeLambda(type_parameters~, body=self.lower_bound_expr(body, source)),
      )
    Call(callee, arguments) =>
      self.lower_to_atom(callee, None, fn(callee) {
        self.lower_exprs_to_atoms(arguments, 0, [], fn(arguments) {
          self.bind_temp(Call(callee~, arguments~), continuation)
        })
      })
    TypeApply(callee, arguments) =>
      self.lower_to_atom(callee, None, fn(callee) {
        self.bind_temp(TypeApply(callee~, arguments~), continuation)
      })
    Construct(construct) =>
      self.lower_exprs_to_atoms(construct.payloads, 0, [], fn(payloads) {
        self.bind_temp(
          Construct({
            data_constructor: construct.data_constructor,
            type_arguments: construct.type_arguments,
            hidden_witnesses: construct.hidden_witnesses,
            payloads,
          }),
          continuation,
        )
      })
    Let(id, initializer, body) =>
      self.lower_to_atom(initializer, Some(id), fn(initializer) {
        Let(
          Value(id~, rhs=Atom(initializer)),
          self.lower_to_atom(body, source, continuation),
        )
      })
    LetRec(bindings, body) =>
      LetRec(
        bindings.map(fn(binding) { self.lower_recursive_binding(binding) }),
        self.lower_to_atom(body, source, continuation),
      )
    Match(match_) =>
      self.lower_to_atom(match_.scrutinee, None, fn(scrutinee) {
        self.bind_temp(
          Match({
            scrutinee,
            binder: match_.binder,
            result_type: match_.result_type,
            alternatives: match_.alternatives.map(fn(alternative) {
              {
                alt_constructor: alternative.alt_constructor,
                type_binders: alternative.type_binders,
                value_binders: alternative.value_binders,
                body: self.lower_bound_expr(alternative.body, source),
              }
            }),
          }),
          continuation,
        )
      })
    Perform(perform) =>
      self.lower_exprs_to_atoms(perform.payloads, 0, [], fn(payloads) {
        self.bind_temp(
          Perform({
            operation: perform.operation,
            effect_arguments: perform.effect_arguments,
            hidden_witnesses: perform.hidden_witnesses,
            payloads,
          }),
          continuation,
        )
      })
    Handle(handle) =>
      self.bind_temp(
        Handle({
          body: self.lower_expr(handle.body),
          result_binder: handle.result_binder,
          result_type: handle.result_type,
          final_body: self.lower_expr(handle.final_body),
          handlers: handle.handlers.map(fn(table) {
            self.lower_handler_table(table)
          }),
        }),
        continuation,
      )
    Resume(id) => continuation(Ref(id))
  }
}

///|
fn AnfLowerer::lower_handler_table(
  self : AnfLowerer,
  table : @buslane.HandlerTable,
) -> AnfHandlerTable {
  {
    handled_effect: table.handled_effect,
    operations: table.operations.map(fn(alternative) {
      self.lower_operation_alternative(alternative)
    }),
  }
}

///|
fn AnfLowerer::lower_operation_alternative(
  self : AnfLowerer,
  alternative : @buslane.OperationAlternative,
) -> AnfOperationAlternative {
  {
    operation: alternative.operation,
    type_binders: alternative.type_binders,
    payload_binders: alternative.payload_binders,
    resume_binder: alternative.resume_binder,
    body: self.lower_expr(alternative.body),
  }
}

///|
fn AnfLowerer::lower_function(
  self : AnfLowerer,
  function : @buslane.FunctionExpr,
  source : @buslane.ValueId?,
) -> AnfFunction {
  let id = self.fresh_function()
  {
    id,
    source,
    parameters: function.parameters,
    result_type: function.result_type,
    body: self.lower_expr(function.body),
  }
}

///|
fn AnfLowerer::lower_recursable_atom(
  self : AnfLowerer,
  expr : @buslane.Expr,
  source : @buslane.ValueId,
) -> AnfAtom {
  match expr {
    Function(function) => Function(self.lower_function(function, Some(source)))
    TypeLambda(type_parameters, body) =>
      TypeLambda(
        type_parameters~,
        body=self.lower_bound_expr(body, Some(source)),
      )
    _ => abort("Buslane letrec rhs is not recursable")
  }
}

///|
fn AnfLowerer::bind_temp(
  self : AnfLowerer,
  rhs : AnfRhs,
  continuation : (AnfAtom) -> AnfExpr,
) -> AnfExpr {
  let temp = self.fresh_temp()
  Let(Temp(temp~, rhs~), continuation(Temp(temp)))
}

///|
fn AnfLowerer::lower_exprs_to_atoms(
  self : AnfLowerer,
  expressions : Array[@buslane.Expr],
  index : Int,
  atoms : Array[AnfAtom],
  continuation : (Array[AnfAtom]) -> AnfExpr,
) -> AnfExpr {
  if index >= expressions.length() {
    continuation(atoms)
  } else {
    self.lower_to_atom(expressions[index], None, fn(atom) {
      let next_atoms = atoms.copy()
      next_atoms.push(atom)
      self.lower_exprs_to_atoms(
        expressions,
        index + 1,
        next_atoms,
        continuation,
      )
    })
  }
}
