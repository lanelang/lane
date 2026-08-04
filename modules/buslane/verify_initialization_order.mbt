///|
priv struct CallableInitializationBody {
  id : ValueId
  body : Expr
}

///|
priv struct InitializationDependencyCollector {
  top_level : Array[ValueId]
  bound : Array[ValueId]
  callables : Array[CallableInitializationBody]
}

///|
/// Returns deferred top-level bindings that an eager initializer may reach
/// through a callable. Direct references are left to the ordinary scope check.
fn Program::unbound_callable_dependencies(
  self : Program,
) -> Array[(ValueId, ValueId)] {
  let top_level = []
  let callables = []
  for term in self.terms {
    match term {
      External(id) => top_level.push(id)
      Let(id, initializer) => {
        top_level.push(id)
        if self.metadata.value_info(id) is Some(info) && info.kind is Function {
          callables.push({ id, body: initializer })
        }
      }
      LetRec(bindings) =>
        for binding in bindings {
          top_level.push(binding.id)
          callables.push({ id: binding.id, body: binding.rhs })
        }
    }
  }
  let bound = []
  let failures = []
  for term in self.terms {
    match term {
      External(id) => bound.push(id)
      LetRec(bindings) =>
        for binding in bindings {
          bound.push(binding.id)
        }
      Let(id, initializer) => {
        if self.metadata.value_info(id) is Some(info) && info.kind is Value {
          let collector = InitializationDependencyCollector::{
            top_level,
            bound,
            callables,
          }
          let dependencies = []
          collector.collect(initializer, delayed=false, [], dependencies)
          for dependency in dependencies {
            if !bound.contains(dependency) {
              failures.push((id, dependency))
            }
          }
        }
        bound.push(id)
      }
    }
  }
  failures
}

///|
fn InitializationDependencyCollector::collect(
  self : InitializationDependencyCollector,
  expression : Expr,
  delayed~ : Bool,
  visiting : Array[ValueId],
  dependencies : Array[ValueId],
) -> Unit {
  match expression {
    Ref(id) => {
      if delayed && self.top_level.contains(id) && !dependencies.contains(id) {
        dependencies.push(id)
      }
      if self.bound.contains(id) && !visiting.contains(id) {
        for callable in self.callables {
          if callable.id == id {
            visiting.push(id)
            self.collect(callable.body, delayed=true, visiting, dependencies)
            ignore(visiting.pop())
          }
        }
      }
    }
    Literal(_) | Resume(_) => ()
    Function(function) =>
      self.collect(function.body, delayed=true, visiting, dependencies)
    Call(callee, arguments) => {
      self.collect(callee, delayed~, visiting, dependencies)
      for argument in arguments {
        self.collect(argument, delayed~, visiting, dependencies)
      }
    }
    TypeLambda(_, body) =>
      self.collect(body, delayed=true, visiting, dependencies)
    TypeApply(callee, _) =>
      self.collect(callee, delayed~, visiting, dependencies)
    Construct(construct) =>
      for payload in construct.payloads {
        self.collect(payload, delayed~, visiting, dependencies)
      }
    Let(_, initializer, body) => {
      self.collect(initializer, delayed~, visiting, dependencies)
      self.collect(body, delayed~, visiting, dependencies)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        self.collect(binding.rhs, delayed=true, visiting, dependencies)
      }
      self.collect(body, delayed~, visiting, dependencies)
    }
    Match(match_) => {
      self.collect(match_.scrutinee, delayed~, visiting, dependencies)
      for alternative in match_.alternatives {
        self.collect(alternative.body, delayed~, visiting, dependencies)
      }
    }
    Perform(perform) =>
      for payload in perform.payloads {
        self.collect(payload, delayed~, visiting, dependencies)
      }
    Handle(handle) => {
      self.collect(handle.body, delayed~, visiting, dependencies)
      self.collect(handle.final_body, delayed~, visiting, dependencies)
      for handler in handle.handlers {
        for operation in handler.operations {
          self.collect(operation.body, delayed~, visiting, dependencies)
        }
      }
    }
  }
}
