///|
pub(all) struct OccurrenceInput {
  program : @buslane.Program
  entry : @buslane.ValueId
  roots : Array[@buslane.ValueId]
} derive(Debug, Eq)

///|
pub(all) struct ValueOccurrenceFact {
  value : @buslane.ValueId
  use_count : Int
  call_count : Int
  callee_only : Bool
  escapes : Bool
  used_in_effectful_context : Bool
  has_incomplete_type_application : Bool
  reachable_from_entry : Bool
} derive(Debug, Eq)

///|
pub(all) struct OccurrenceSummary {
  entry : @buslane.ValueId
  roots : Array[@buslane.ValueId]
  facts : Array[ValueOccurrenceFact]
} derive(Debug, Eq)

///|
priv enum UsePosition {
  Callee
  NonCallee
}

///|
priv struct OccurrenceAnalyzer {
  program : @buslane.Program
  top_definitions : Array[@buslane.Expr?]
  facts : Array[ValueOccurrenceFact]
}

///|
pub fn analyze(input : OccurrenceInput) -> OccurrenceSummary {
  let analyzer = OccurrenceAnalyzer::from_program(input.program)
  analyzer.record_occurrences()
  analyzer.record_reachability([input.entry] + input.roots)
  { entry: input.entry, roots: input.roots, facts: analyzer.facts, }
}

///|
/// Retains exactly the top-level definitions reachable from `roots`.
///
/// Metadata remains intact: type, effect, operation, and value identities are
/// program-wide facts rather than executable top-level definitions.
pub fn retain_reachable_top_terms(
  program : @buslane.Program,
  roots : Array[@buslane.ValueId],
) -> @buslane.Program {
  let analyzer = OccurrenceAnalyzer::from_program(program)
  analyzer.record_reachability(roots)
  let terms = []
  for term in program.terms {
    match term {
      Let(value, _) if analyzer.value_is_reachable(value) => terms.push(term)
      LetRec(bindings) => {
        let reachable = bindings.filter(binding => {
          analyzer.value_is_reachable(binding.id)
        })
        if !reachable.is_empty() {
          terms.push(LetRec(reachable))
        }
      }
      External(value) if analyzer.value_is_reachable(value) => terms.push(term)
      _ => ()
    }
  }
  { ..program, terms, }
}

///|
pub fn analyze_program(
  program : @buslane.Program,
  entry : @buslane.ValueId,
) -> OccurrenceSummary {
  analyze({ program, entry, roots: [], })
}

///|
fn OccurrenceAnalyzer::from_program(
  program : @buslane.Program,
) -> OccurrenceAnalyzer {
  let facts = []
  for index in 0..<program.metadata.values.length() {
    facts.push(ValueOccurrenceFact::empty({ index, }))
  }
  let top_definitions : Array[@buslane.Expr?] = Array::make(
    program.metadata.values.length(),
    None,
  )
  for term in program.terms {
    match term {
      Let(id, rhs) => top_definitions[id.index] = Some(rhs)
      LetRec(bindings) =>
        for binding in bindings {
          top_definitions[binding.id.index] = Some(binding.rhs)
        }
      External(_) => ()
    }
  }
  { program, top_definitions, facts, }
}

///|
fn ValueOccurrenceFact::empty(id : @buslane.ValueId) -> ValueOccurrenceFact {
  {
    value: id,
    use_count: 0,
    call_count: 0,
    callee_only: false,
    escapes: false,
    used_in_effectful_context: false,
    has_incomplete_type_application: false,
    reachable_from_entry: false,
  }
}

///|
fn OccurrenceAnalyzer::record_occurrences(self : OccurrenceAnalyzer) -> Unit {
  for definition in self.top_definitions {
    if definition is Some(rhs) {
      self.visit_expr(rhs, NonCallee, effectful=false)
    }
  }
}

///|
fn OccurrenceAnalyzer::record_reachability(
  self : OccurrenceAnalyzer,
  roots : Array[@buslane.ValueId],
) -> Unit {
  for root in roots {
    self.mark_reachable(root)
  }
}

///|
fn OccurrenceAnalyzer::value_is_reachable(
  self : OccurrenceAnalyzer,
  value : @buslane.ValueId,
) -> Bool {
  match self.facts.get(value.index) {
    Some(fact) => fact.reachable_from_entry
    None => false
  }
}

///|
fn OccurrenceAnalyzer::visit_expr(
  self : OccurrenceAnalyzer,
  expr : @buslane.Expr,
  position : UsePosition,
  effectful~ : Bool,
) -> Unit {
  match expr {
    Ref(id) | Resume(id) => self.record_use(id, position, effectful~)
    Literal(_) => ()
    Function(function) => {
      for parameter in function.parameters {
        self.ensure_fact(parameter)
      }
      self.visit_expr(function.body, NonCallee, effectful~)
    }
    Call(callee, arguments) => {
      self.visit_expr(
        callee,
        Callee,
        effectful=effectful || callee_has_effect(self.program, callee),
      )
      for argument in arguments {
        self.visit_expr(argument, NonCallee, effectful~)
      }
    }
    TypeLambda(_, body) => self.visit_expr(body, position, effectful~)
    TypeApply(callee, _) => self.visit_expr(callee, position, effectful~)
    Construct(construct) =>
      for payload in construct.payloads {
        self.visit_expr(payload, NonCallee, effectful~)
      }
    Let(id, initializer, body) => {
      self.ensure_fact(id)
      self.visit_expr(initializer, NonCallee, effectful~)
      self.visit_expr(body, NonCallee, effectful~)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        self.ensure_fact(binding.id)
      }
      for binding in bindings {
        self.visit_expr(binding.rhs, NonCallee, effectful~)
      }
      self.visit_expr(body, NonCallee, effectful~)
    }
    Match(match_) => {
      self.visit_expr(match_.scrutinee, NonCallee, effectful~)
      self.ensure_fact(match_.binder)
      for alternative in match_.alternatives {
        for binder in alternative.value_binders {
          self.ensure_fact(binder)
        }
        self.visit_expr(alternative.body, NonCallee, effectful~)
      }
    }
    Perform(perform) =>
      for payload in perform.payloads {
        self.visit_expr(payload, NonCallee, effectful=true)
      }
    Handle(handle) => {
      self.visit_expr(handle.body, NonCallee, effectful=true)
      self.ensure_fact(handle.result_binder)
      self.visit_expr(handle.final_body, NonCallee, effectful=true)
      for table in handle.handlers {
        for alternative in table.operations {
          for binder in alternative.payload_binders {
            self.ensure_fact(binder)
          }
          self.ensure_fact(alternative.resume_binder)
          self.visit_expr(alternative.body, NonCallee, effectful=true)
        }
      }
    }
  }
}

///|
fn OccurrenceAnalyzer::record_use(
  self : OccurrenceAnalyzer,
  id : @buslane.ValueId,
  position : UsePosition,
  effectful~ : Bool,
) -> Unit {
  guard self.facts.get(id.index) is Some(fact) else { return }
  let use_count = fact.use_count + 1
  let call_delta = if position is Callee { 1 } else { 0 }
  let call_count = fact.call_count + call_delta
  let escapes = fact.escapes || position is NonCallee
  self.facts[id.index] = {
    ..fact,
    use_count,
    call_count,
    callee_only: use_count == call_count,
    escapes,
    used_in_effectful_context: fact.used_in_effectful_context || effectful,
  }
}

///|
fn OccurrenceAnalyzer::ensure_fact(
  self : OccurrenceAnalyzer,
  id : @buslane.ValueId,
) -> Unit {
  guard self.facts.get(id.index) is None else { return }
  while self.facts.length() <= id.index {
    self.facts.push(ValueOccurrenceFact::empty({ index: self.facts.length(), }))
  }
}

///|
fn OccurrenceAnalyzer::mark_reachable(
  self : OccurrenceAnalyzer,
  id : @buslane.ValueId,
) -> Unit {
  guard self.facts.get(id.index) is Some(fact) else { return }
  if fact.reachable_from_entry {
    return
  }
  self.facts[id.index] = { ..fact, reachable_from_entry: true, }
  if self.top_definition(id) is Some(rhs) {
    self.mark_reachable_expr(rhs, 0)
  }
}

///|
fn OccurrenceAnalyzer::top_definition(
  self : OccurrenceAnalyzer,
  id : @buslane.ValueId,
) -> @buslane.Expr? {
  match self.top_definitions.get(id.index) {
    Some(Some(rhs)) => Some(rhs)
    _ => None
  }
}

///|
fn OccurrenceAnalyzer::mark_reachable_expr(
  self : OccurrenceAnalyzer,
  expr : @buslane.Expr,
  applied_type_argument_count : Int,
) -> Unit {
  match expr {
    Ref(id) => {
      self.record_reachable_type_application(id, applied_type_argument_count)
      self.mark_reachable(id)
    }
    Resume(id) => self.mark_reachable(id)
    Literal(_) => ()
    Function(function) => {
      for parameter in function.parameters {
        self.mark_reachable_value(parameter)
      }
      self.mark_reachable_expr(function.body, 0)
    }
    Call(callee, arguments) => {
      self.mark_reachable_expr(callee, 0)
      for argument in arguments {
        self.mark_reachable_expr(argument, 0)
      }
    }
    TypeLambda(_, body) => self.mark_reachable_expr(body, 0)
    TypeApply(callee, arguments) =>
      self.mark_reachable_expr(
        callee,
        applied_type_argument_count + arguments.length(),
      )
    Construct(construct) =>
      for payload in construct.payloads {
        self.mark_reachable_expr(payload, 0)
      }
    Let(id, initializer, body) => {
      self.mark_reachable_value(id)
      self.mark_reachable_expr(initializer, 0)
      self.mark_reachable_expr(body, 0)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        self.mark_reachable_value(binding.id)
      }
      for binding in bindings {
        self.mark_reachable_expr(binding.rhs, 0)
      }
      self.mark_reachable_expr(body, 0)
    }
    Match(match_) => {
      self.mark_reachable_expr(match_.scrutinee, 0)
      self.mark_reachable_value(match_.binder)
      for alternative in match_.alternatives {
        for binder in alternative.value_binders {
          self.mark_reachable_value(binder)
        }
        self.mark_reachable_expr(alternative.body, 0)
      }
    }
    Perform(perform) =>
      for payload in perform.payloads {
        self.mark_reachable_expr(payload, 0)
      }
    Handle(handle) => {
      self.mark_reachable_expr(handle.body, 0)
      self.mark_reachable_value(handle.result_binder)
      self.mark_reachable_expr(handle.final_body, 0)
      for table in handle.handlers {
        for alternative in table.operations {
          for binder in alternative.payload_binders {
            self.mark_reachable_value(binder)
          }
          self.mark_reachable_value(alternative.resume_binder)
          self.mark_reachable_expr(alternative.body, 0)
        }
      }
    }
  }
}

///|
fn OccurrenceAnalyzer::record_reachable_type_application(
  self : OccurrenceAnalyzer,
  id : @buslane.ValueId,
  applied_argument_count : Int,
) -> Unit {
  guard self.facts.get(id.index) is Some(fact) else { return }
  guard self.program.metadata.value_info(id) is Some(info) else { return }
  if applied_argument_count < forall_parameter_count(info.type_) {
    self.facts[id.index] = { ..fact, has_incomplete_type_application: true, }
  }
}

///|
fn forall_parameter_count(type_ : @buslane.Type) -> Int {
  match type_ {
    Forall(parameters, body) =>
      parameters.length() + forall_parameter_count(body)
    _ => 0
  }
}

///|
fn OccurrenceAnalyzer::mark_reachable_value(
  self : OccurrenceAnalyzer,
  id : @buslane.ValueId,
) -> Unit {
  self.ensure_fact(id)
  guard self.facts.get(id.index) is Some(fact) else { return }
  if !fact.reachable_from_entry {
    self.facts[id.index] = { ..fact, reachable_from_entry: true, }
  }
}

///|
fn callee_has_effect(
  program : @buslane.Program,
  callee : @buslane.Expr,
) -> Bool {
  match callee {
    Ref(id) | Resume(id) =>
      match program.metadata.value_info(id) {
        Some(info) => type_has_effect(info.type_)
        None => false
      }
    TypeApply(inner, _) => callee_has_effect(program, inner)
    _ => false
  }
}

///|
fn type_has_effect(type_ : @buslane.Type) -> Bool {
  match type_ {
    Function(_, _, effect) => effect_has_effect(effect)
    Forall(_, body) | TypeLambda(_, body) => type_has_effect(body)
    _ => false
  }
}

///|
fn effect_has_effect(effect : @buslane.Effect) -> Bool {
  match effect {
    Empty => false
    Builtin(_) | Singleton(_, _) | Parameter(_) => true
    Union(effects) => effects.any(effect_has_effect)
  }
}
