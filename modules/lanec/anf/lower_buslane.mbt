///|
priv struct BuslaneAnfLowerer {
  mut next_temp : Int
}

///|
/// Lowers Buslane expression-tree core into Buslane ANF.
pub fn lower_buslane_program_to_anf(
  program : @buslane.Program,
) -> BuslaneAnfProgram {
  let lowerer = BuslaneAnfLowerer::{ next_temp: 0 }
  {
    metadata: program.metadata,
    terms: program.terms.map(fn(term) { lowerer.lower_top_term(term) }),
  }
}

///|
fn BuslaneAnfLowerer::fresh_temp(self : BuslaneAnfLowerer) -> AnfTempId {
  let temp = AnfTempId::{ index: self.next_temp }
  self.next_temp = self.next_temp + 1
  temp
}

///|
fn BuslaneAnfLowerer::lower_top_term(
  self : BuslaneAnfLowerer,
  term : @buslane.TopTerm,
) -> BuslaneAnfTopTerm {
  match term {
    Let(id, expr) => Let(id, self.lower_expr(expr))
    LetRec(bindings) =>
      LetRec(
        bindings.map(fn(binding) { self.lower_recursive_binding(binding) }),
      )
    External(id) => External(id)
  }
}

///|
fn BuslaneAnfLowerer::lower_recursive_binding(
  self : BuslaneAnfLowerer,
  binding : @buslane.RecursiveBinding,
) -> BuslaneAnfRecursiveBinding {
  { id: binding.id, rhs: self.lower_recursable_atom(binding.rhs) }
}

///|
fn BuslaneAnfLowerer::lower_expr(
  self : BuslaneAnfLowerer,
  expr : @buslane.Expr,
) -> BuslaneAnfExpr {
  self.lower_to_atom(expr, fn(atom) { Atom(atom) })
}

///|
fn BuslaneAnfLowerer::lower_to_atom(
  self : BuslaneAnfLowerer,
  expr : @buslane.Expr,
  continuation : (BuslaneAnfAtom) -> BuslaneAnfExpr,
) -> BuslaneAnfExpr {
  match expr {
    Ref(id) => continuation(Ref(id))
    Literal(literal) => continuation(Literal(literal))
    Function(function) => continuation(Function(self.lower_function(function)))
    TypeLambda(type_parameters, body) =>
      continuation(TypeLambda(type_parameters~, body=self.lower_expr(body)))
    Call(callee, arguments) =>
      self.lower_to_atom(callee, fn(callee) {
        self.lower_exprs_to_atoms(arguments, 0, [], fn(arguments) {
          self.bind_temp(Call(callee~, arguments~), continuation)
        })
      })
    TypeApply(callee, arguments) =>
      self.lower_to_atom(callee, fn(callee) {
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
      self.lower_to_atom(initializer, fn(initializer) {
        Let(
          Value(id~, rhs=Atom(initializer)),
          self.lower_to_atom(body, continuation),
        )
      })
    LetRec(bindings, body) =>
      LetRec(
        bindings.map(fn(binding) { self.lower_recursive_binding(binding) }),
        self.lower_to_atom(body, continuation),
      )
    Match(match_) =>
      self.lower_to_atom(match_.scrutinee, fn(scrutinee) {
        Match({
          scrutinee,
          binder: match_.binder,
          result_type: match_.result_type,
          alternatives: match_.alternatives.map(fn(alternative) {
            {
              alt_constructor: alternative.alt_constructor,
              type_binders: alternative.type_binders,
              value_binders: alternative.value_binders,
              body: self.lower_to_atom(alternative.body, continuation),
            }
          }),
        })
      })
  }
}

///|
fn BuslaneAnfLowerer::lower_function(
  self : BuslaneAnfLowerer,
  function : @buslane.FunctionExpr,
) -> BuslaneAnfFunction {
  {
    parameters: function.parameters,
    result_type: function.result_type,
    body: self.lower_expr(function.body),
  }
}

///|
fn BuslaneAnfLowerer::lower_recursable_atom(
  self : BuslaneAnfLowerer,
  expr : @buslane.Expr,
) -> BuslaneAnfAtom {
  match expr {
    Function(function) => Function(self.lower_function(function))
    TypeLambda(type_parameters, body) =>
      TypeLambda(type_parameters~, body=self.lower_expr(body))
    _ => abort("Buslane letrec rhs is not recursable")
  }
}

///|
fn BuslaneAnfLowerer::bind_temp(
  self : BuslaneAnfLowerer,
  rhs : BuslaneAnfRhs,
  continuation : (BuslaneAnfAtom) -> BuslaneAnfExpr,
) -> BuslaneAnfExpr {
  let temp = self.fresh_temp()
  Let(Temp(temp~, rhs~), continuation(Temp(temp)))
}

///|
fn BuslaneAnfLowerer::lower_exprs_to_atoms(
  self : BuslaneAnfLowerer,
  expressions : Array[@buslane.Expr],
  index : Int,
  atoms : Array[BuslaneAnfAtom],
  continuation : (Array[BuslaneAnfAtom]) -> BuslaneAnfExpr,
) -> BuslaneAnfExpr {
  if index >= expressions.length() {
    continuation(atoms)
  } else {
    self.lower_to_atom(expressions[index], fn(atom) {
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
