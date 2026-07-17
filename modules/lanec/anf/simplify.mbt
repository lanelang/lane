///|
priv struct AnfRewriteScope {
  values : Array[(@buslane.ValueId, AnfAtom)]
  temps : Array[(AnfTempId, AnfAtom)]
}

///|
fn simplify_anf_program(program : AnfProgram) -> AnfProgram {
  let scope : AnfRewriteScope = { values: [], temps: [] }
  {
    metadata: program.metadata,
    terms: program.terms.map(fn(term) { simplify_top_term(term, scope) }),
  }
}

///|
fn simplify_top_term(term : AnfTopTerm, scope : AnfRewriteScope) -> AnfTopTerm {
  match term {
    Let(id, expr) => Let(id, simplify_expr(expr, scope))
    LetRec(bindings) =>
      LetRec(
        bindings.map(fn(binding) {
          {
            id: binding.id,
            rhs: simplify_atom(binding.rhs, scope.without_value(binding.id)),
          }
        }),
      )
    External(id) => External(id)
  }
}

///|
fn simplify_expr(expr : AnfExpr, scope : AnfRewriteScope) -> AnfExpr {
  match expr {
    Atom(atom) => Atom(simplify_atom(atom, scope))
    Let(binding, body) => {
      let rhs = simplify_rhs(binding.rhs(), scope)
      match rhs {
        Atom(atom) if atom_is_copyable(atom) =>
          simplify_expr(body, scope.with_binding(binding, atom))
        _ =>
          Let(
            binding.with_rhs(rhs),
            simplify_expr(body, scope.without_binding(binding)),
          )
      }
    }
    LetRec(bindings, body) => {
      let body_scope = bindings.fold(init=scope, fn(scope, binding) {
        scope.without_value(binding.id)
      })
      LetRec(
        bindings.map(fn(binding) {
          { id: binding.id, rhs: simplify_atom(binding.rhs, body_scope) }
        }),
        simplify_expr(body, body_scope),
      )
    }
    Match(match_) =>
      Match({
        scrutinee: simplify_atom(match_.scrutinee, scope),
        binder: match_.binder,
        result_type: match_.result_type,
        alternatives: match_.alternatives.map(fn(alternative) {
          let alternative_scope = alternative.value_binders.fold(
            init=scope.without_value(match_.binder),
            fn(scope, binder) { scope.without_value(binder) },
          )
          {
            alt_constructor: alternative.alt_constructor,
            type_binders: alternative.type_binders,
            value_binders: alternative.value_binders,
            body: simplify_expr(alternative.body, alternative_scope),
          }
        }),
      })
  }
}

///|
fn AnfBinding::rhs(self : AnfBinding) -> AnfRhs {
  match self {
    Value(rhs~, ..) | Temp(rhs~, ..) => rhs
  }
}

///|
fn AnfBinding::with_rhs(self : AnfBinding, rhs : AnfRhs) -> AnfBinding {
  match self {
    Value(id~, ..) => Value(id~, rhs~)
    Temp(temp~, ..) => Temp(temp~, rhs~)
  }
}

///|
fn atom_is_copyable(atom : AnfAtom) -> Bool {
  match atom {
    Literal(_) | Ref(_) | Temp(_) => true
    Function(_) | TypeLambda(_) => false
  }
}

///|
fn simplify_rhs(rhs : AnfRhs, scope : AnfRewriteScope) -> AnfRhs {
  match rhs {
    Atom(atom) => Atom(simplify_atom(atom, scope))
    Call(callee~, arguments~) =>
      Call(
        callee=simplify_atom(callee, scope),
        arguments=arguments.map(fn(atom) { simplify_atom(atom, scope) }),
      )
    TypeApply(callee~, arguments~) =>
      TypeApply(callee=simplify_atom(callee, scope), arguments~)
    Construct(construct) =>
      Construct({
        data_constructor: construct.data_constructor,
        type_arguments: construct.type_arguments,
        hidden_witnesses: construct.hidden_witnesses,
        payloads: construct.payloads.map(fn(atom) { simplify_atom(atom, scope) }),
      })
    Perform(perform) =>
      Perform({
        operation: perform.operation,
        effect_arguments: perform.effect_arguments,
        hidden_witnesses: perform.hidden_witnesses,
        payloads: perform.payloads.map(fn(atom) { simplify_atom(atom, scope) }),
      })
    Handle(handle) =>
      Handle({
        body: simplify_expr(handle.body, scope),
        result_binder: handle.result_binder,
        result_type: handle.result_type,
        final_body: simplify_expr(
          handle.final_body,
          scope.without_value(handle.result_binder),
        ),
        handlers: handle.handlers.map(fn(table) {
          {
            handled_effect: table.handled_effect,
            operations: table.operations.map(fn(alternative) {
              let operation_scope = alternative.payload_binders.fold(
                init=scope.without_value(alternative.resume_binder),
                fn(scope, binder) { scope.without_value(binder) },
              )
              {
                operation: alternative.operation,
                type_binders: alternative.type_binders,
                payload_binders: alternative.payload_binders,
                resume_binder: alternative.resume_binder,
                body: simplify_expr(alternative.body, operation_scope),
              }
            }),
          }
        }),
      })
  }
}

///|
fn simplify_atom(atom : AnfAtom, scope : AnfRewriteScope) -> AnfAtom {
  match atom {
    Literal(_) => atom
    Ref(id) =>
      match scope.find_value(id) {
        Some(replacement) => simplify_atom(replacement, scope)
        None => atom
      }
    Temp(temp) =>
      match scope.find_temp(temp) {
        Some(replacement) => simplify_atom(replacement, scope)
        None => atom
      }
    Function(function) => {
      let function_scope = function.parameters.fold(init=scope, fn(
        scope,
        parameter,
      ) {
        scope.without_value(parameter)
      })
      Function({
        parameters: function.parameters,
        result_type: function.result_type,
        body: simplify_expr(function.body, function_scope),
      })
    }
    TypeLambda(type_parameters~, body~) =>
      TypeLambda(type_parameters~, body=simplify_expr(body, scope))
  }
}

///|
fn AnfRewriteScope::find_value(
  self : AnfRewriteScope,
  id : @buslane.ValueId,
) -> AnfAtom? {
  for index = self.values.length() - 1; index >= 0; index = index - 1 {
    let (candidate, atom) = self.values[index]
    if candidate == id {
      return Some(atom)
    }
  }
  None
}

///|
fn AnfRewriteScope::find_temp(
  self : AnfRewriteScope,
  temp : AnfTempId,
) -> AnfAtom? {
  for index = self.temps.length() - 1; index >= 0; index = index - 1 {
    let (candidate, atom) = self.temps[index]
    if candidate == temp {
      return Some(atom)
    }
  }
  None
}

///|
fn AnfRewriteScope::with_binding(
  self : AnfRewriteScope,
  binding : AnfBinding,
  atom : AnfAtom,
) -> AnfRewriteScope {
  match binding {
    Value(id~, ..) => {
      let values = self.values.copy()
      values.push((id, atom))
      { values, temps: self.temps }
    }
    Temp(temp~, ..) => {
      let temps = self.temps.copy()
      temps.push((temp, atom))
      { values: self.values, temps }
    }
  }
}

///|
fn AnfRewriteScope::without_binding(
  self : AnfRewriteScope,
  binding : AnfBinding,
) -> AnfRewriteScope {
  match binding {
    Value(id~, ..) => self.without_value(id)
    Temp(temp~, ..) => self.without_temp(temp)
  }
}

///|
fn AnfRewriteScope::without_value(
  self : AnfRewriteScope,
  id : @buslane.ValueId,
) -> AnfRewriteScope {
  { values: self.values.filter(fn(entry) { entry.0 != id }), temps: self.temps }
}

///|
fn AnfRewriteScope::without_temp(
  self : AnfRewriteScope,
  temp : AnfTempId,
) -> AnfRewriteScope {
  {
    values: self.values,
    temps: self.temps.filter(fn(entry) { entry.0 != temp }),
  }
}
