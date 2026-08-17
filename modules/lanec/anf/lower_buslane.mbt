///|
priv struct AnfLowerer {
  generic_plan : RuntimeGenericPlan
  mut next_temp : Int
  mut next_function : Int
}

///|
/// Lowers verified effect-aware CPS Core directly to runtime ANF.
///
/// Effect projection is intentionally fused into this seam. The source
/// metadata is snapshotted, so observing or retaining the CPS Core program
/// cannot be affected by the one-way runtime projection.
pub fn lower_cps_core_to_runtime_anf(
  program : @buslane.Program,
) -> Result[AnfProgram, RuntimeAnfLoweringError] {
  Ok(lower_cps_core_to_runtime_anf_or_raise(program)) catch {
    error => Err(error)
  }
}

///|
fn lower_cps_core_to_runtime_anf_or_raise(
  program : @buslane.Program,
) -> AnfProgram raise RuntimeAnfLoweringError {
  let verification = @buslane.verify_program(program)
  if !verification.is_ok() {
    raise InvalidCpsCore(verification)
  }
  let generic_plan = runtime_generic_plan(program)
  let lowerer = AnfLowerer::{ generic_plan, next_temp: 0, next_function: 0 }
  let terms = program.terms.map(term => lowerer.lower_top_term(term))
  simplify_anf_program({ metadata: generic_plan.runtime_metadata(), terms })
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
) -> AnfTopTerm raise RuntimeAnfLoweringError {
  match term {
    Let(id, expr) => Let(id, self.lower_bound_expr(expr, Some(id)))
    LetRec(bindings) =>
      LetRec(bindings.map(binding => self.lower_recursive_binding(binding)))
    External(id) => External(id)
  }
}

///|
fn AnfLowerer::lower_recursive_binding(
  self : AnfLowerer,
  binding : @buslane.RecursiveBinding,
) -> AnfRecursiveBinding raise RuntimeAnfLoweringError {
  { id: binding.id, rhs: self.lower_recursable_atom(binding.rhs, binding.id) }
}

///|
fn AnfLowerer::lower_expr(
  self : AnfLowerer,
  expr : @buslane.Expr,
) -> AnfExpr raise RuntimeAnfLoweringError {
  self.lower_bound_expr(expr, None)
}

///|
fn AnfLowerer::lower_bound_expr(
  self : AnfLowerer,
  expr : @buslane.Expr,
  source : @buslane.ValueId?,
) -> AnfExpr raise RuntimeAnfLoweringError {
  self.lower_to_atom(expr, source, atom => Atom(atom))
}

///|
fn AnfLowerer::lower_to_atom(
  self : AnfLowerer,
  expr : @buslane.Expr,
  source : @buslane.ValueId?,
  continuation : (AnfAtom) -> AnfExpr raise RuntimeAnfLoweringError,
) -> AnfExpr raise RuntimeAnfLoweringError {
  match expr {
    Ref(id) => continuation(Ref(id))
    Literal(literal) => continuation(Literal(literal))
    Function(function) =>
      continuation(Function(self.lower_function(function, source)))
    TypeLambda(type_parameters, body) => {
      let retained = self.generic_plan.runtime_evidence_parameters(
        type_parameters,
      )
      if retained.is_empty() {
        self.lower_to_atom(body, source, continuation)
      } else {
        continuation(
          EvidenceLambda(
            parameters=retained,
            body=self.lower_bound_expr(body, source),
          ),
        )
      }
    }
    Call(callee, arguments) =>
      self.lower_to_atom(callee, None, callee => {
        self.lower_exprs_to_atoms(arguments, 0, [], arguments => {
          self.bind_temp(Call(callee~, arguments~), continuation)
        })
      })
    TypeApply(callee, arguments) => {
      let source_callee = callee
      self.lower_to_atom(callee, None, callee => {
        let parameters = self.generic_plan.expression_type_parameters(
          source_callee,
        )
        let arguments = self.generic_plan.runtime_arguments(
          parameters, arguments,
        )
        if arguments.is_empty() {
          continuation(callee)
        } else {
          self.bind_temp(ApplyEvidence(callee~, arguments~), continuation)
        }
      })
    }
    Construct(construct) =>
      self.lower_exprs_to_atoms(construct.payloads, 0, [], payloads => {
        let info = match
          self.generic_plan.metadata.data_constructor_info(
            construct.data_constructor,
          ) {
          Some(info) => info
          None => raise MissingDataConstructor(construct.data_constructor)
        }
        let owner = match self.generic_plan.metadata.type_info(info.owner) {
          Some(owner) => owner
          None => raise MissingType(info.owner)
        }
        self.bind_temp(
          Construct({
            data_constructor: construct.data_constructor,
            type_arguments: self.generic_plan.runtime_arguments(
              owner.parameters,
              construct.type_arguments,
            ),
            hidden_arguments: self.generic_plan.runtime_arguments(
              info.hidden_type_parameters,
              construct.hidden_witnesses,
            ),
            payloads,
          }),
          continuation,
        )
      })
    Let(id, initializer, body) =>
      self.lower_to_atom(initializer, Some(id), initializer => {
        Let(
          Value(id~, rhs=Atom(initializer)),
          self.lower_to_atom(body, source, continuation),
        )
      })
    LetRec(bindings, body) =>
      LetRec(
        bindings.map(binding => self.lower_recursive_binding(binding)),
        self.lower_to_atom(body, source, continuation),
      )
    Match(match_) =>
      self.lower_to_atom(match_.scrutinee, None, scrutinee => {
        self.bind_temp(
          Match({
            scrutinee,
            binder: match_.binder,
            result_type: self.generic_plan.runtime_type(match_.result_type),
            alternatives: match_.alternatives.map(alternative => {
              alt_constructor: alternative.alt_constructor,
              evidence_binders: self.generic_plan.runtime_evidence_parameters(
                alternative.type_binders,
              ),
              value_binders: alternative.value_binders,
              body: self.lower_bound_expr(alternative.body, source),
            }),
          }),
          continuation,
        )
      })
    Perform(perform) => raise ResidualPerform(perform.operation)
    Handle(_) => raise ResidualHandle
    Resume(id) => continuation(Ref(id))
  }
}

///|
fn AnfLowerer::lower_function(
  self : AnfLowerer,
  function : @buslane.FunctionExpr,
  source : @buslane.ValueId?,
) -> AnfFunction raise RuntimeAnfLoweringError {
  let id = self.fresh_function()
  {
    id,
    source,
    parameters: function.parameters,
    result_type: self.generic_plan.runtime_type(function.result_type),
    body: self.lower_expr(function.body),
  }
}

///|
fn AnfLowerer::lower_recursable_atom(
  self : AnfLowerer,
  expr : @buslane.Expr,
  source : @buslane.ValueId,
) -> AnfAtom raise RuntimeAnfLoweringError {
  match expr {
    Function(function) => Function(self.lower_function(function, Some(source)))
    TypeLambda(type_parameters, body) => {
      let retained = self.generic_plan.runtime_evidence_parameters(
        type_parameters,
      )
      if retained.is_empty() {
        self.lower_recursable_atom(body, source)
      } else {
        EvidenceLambda(
          parameters=retained,
          body=self.lower_bound_expr(body, Some(source)),
        )
      }
    }
    _ => abort("Buslane letrec rhs is not recursable")
  }
}

///|
fn AnfLowerer::bind_temp(
  self : AnfLowerer,
  rhs : AnfRhs,
  continuation : (AnfAtom) -> AnfExpr raise RuntimeAnfLoweringError,
) -> AnfExpr raise RuntimeAnfLoweringError {
  let temp = self.fresh_temp()
  Let(Temp(temp~, rhs~), continuation(Temp(temp)))
}

///|
fn AnfLowerer::lower_exprs_to_atoms(
  self : AnfLowerer,
  expressions : Array[@buslane.Expr],
  index : Int,
  atoms : Array[AnfAtom],
  continuation : (Array[AnfAtom]) -> AnfExpr raise RuntimeAnfLoweringError,
) -> AnfExpr raise RuntimeAnfLoweringError {
  if index >= expressions.length() {
    continuation(atoms)
  } else {
    self.lower_to_atom(expressions[index], None, atom => {
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
