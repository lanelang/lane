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
priv struct TopDefinition {
  id : @buslane.ValueId
  rhs : @buslane.Expr
}

///|
priv struct OccurrenceAnalyzer {
  program : @buslane.Program
  top_definitions : Array[TopDefinition]
  facts : Array[ValueOccurrenceFact]
}

///|
pub fn analyze(input : OccurrenceInput) -> OccurrenceSummary {
  let analyzer = OccurrenceAnalyzer::from_program(input.program)
  analyzer.record_occurrences()
  analyzer.record_reachability(input.entry, input.roots)
  { entry: input.entry, roots: input.roots, facts: analyzer.facts }
}

///|
pub fn analyze_program(
  program : @buslane.Program,
  entry : @buslane.ValueId,
) -> OccurrenceSummary {
  analyze({ program, entry, roots: [] })
}

///|
fn OccurrenceAnalyzer::from_program(
  program : @buslane.Program,
) -> OccurrenceAnalyzer {
  let facts = []
  for index in 0..<program.metadata.values.length() {
    facts.push(ValueOccurrenceFact::empty({ index, }))
  }
  let top_definitions = []
  for term in program.terms {
    match term {
      Let(id, rhs) => top_definitions.push({ id, rhs })
      LetRec(bindings) =>
        for binding in bindings {
          top_definitions.push({ id: binding.id, rhs: binding.rhs })
        }
      External(_) => ()
    }
  }
  { program, top_definitions, facts }
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
    reachable_from_entry: false,
  }
}

///|
fn OccurrenceAnalyzer::record_occurrences(self : OccurrenceAnalyzer) -> Unit {
  for definition in self.top_definitions {
    self.visit_expr(definition.rhs, NonCallee, effectful=false)
  }
}

///|
fn OccurrenceAnalyzer::record_reachability(
  self : OccurrenceAnalyzer,
  entry : @buslane.ValueId,
  roots : Array[@buslane.ValueId],
) -> Unit {
  self.mark_reachable(entry)
  for root in roots {
    self.mark_reachable(root)
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
    self.facts.push(ValueOccurrenceFact::empty({ index: self.facts.length() }))
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
  self.facts[id.index] = { ..fact, reachable_from_entry: true }
  if self.find_top_definition(id) is Some(definition) {
    self.mark_reachable_expr(definition.rhs)
  }
}

///|
fn OccurrenceAnalyzer::find_top_definition(
  self : OccurrenceAnalyzer,
  id : @buslane.ValueId,
) -> TopDefinition? {
  for definition in self.top_definitions {
    if definition.id == id {
      return Some(definition)
    }
  }
  None
}

///|
fn OccurrenceAnalyzer::mark_reachable_expr(
  self : OccurrenceAnalyzer,
  expr : @buslane.Expr,
) -> Unit {
  match expr {
    Ref(id) | Resume(id) => self.mark_reachable(id)
    Literal(_) => ()
    Function(function) => {
      for parameter in function.parameters {
        self.mark_reachable_value(parameter)
      }
      self.mark_reachable_expr(function.body)
    }
    Call(callee, arguments) => {
      self.mark_reachable_expr(callee)
      for argument in arguments {
        self.mark_reachable_expr(argument)
      }
    }
    TypeLambda(_, body) | TypeApply(body, _) => self.mark_reachable_expr(body)
    Construct(construct) =>
      for payload in construct.payloads {
        self.mark_reachable_expr(payload)
      }
    Let(id, initializer, body) => {
      self.mark_reachable_value(id)
      self.mark_reachable_expr(initializer)
      self.mark_reachable_expr(body)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        self.mark_reachable_value(binding.id)
      }
      for binding in bindings {
        self.mark_reachable_expr(binding.rhs)
      }
      self.mark_reachable_expr(body)
    }
    Match(match_) => {
      self.mark_reachable_expr(match_.scrutinee)
      self.mark_reachable_value(match_.binder)
      for alternative in match_.alternatives {
        for binder in alternative.value_binders {
          self.mark_reachable_value(binder)
        }
        self.mark_reachable_expr(alternative.body)
      }
    }
    Perform(perform) =>
      for payload in perform.payloads {
        self.mark_reachable_expr(payload)
      }
    Handle(handle) => {
      self.mark_reachable_expr(handle.body)
      self.mark_reachable_value(handle.result_binder)
      self.mark_reachable_expr(handle.final_body)
      for table in handle.handlers {
        for alternative in table.operations {
          for binder in alternative.payload_binders {
            self.mark_reachable_value(binder)
          }
          self.mark_reachable_value(alternative.resume_binder)
          self.mark_reachable_expr(alternative.body)
        }
      }
    }
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
    self.facts[id.index] = { ..fact, reachable_from_entry: true }
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
    Io | Singleton(_, _) | Parameter(_) => true
    Union(effects) => effects.any(effect_has_effect)
  }
}
