///|
priv struct CallableInitializationBody {
  id : ValueId
  body : Expr
}

///|
priv struct InitializationOrderFailure {
  initializer : ValueId
  dependency : ValueId
}

///|
priv struct InitializationDependencyCollector {
  top_level : Array[ValueId]
  bound : Array[ValueId]
  callables : Array[CallableInitializationBody]
}

///|
priv enum InitializationDependencyMode {
  Eager
  Callable
}

///|
/// Returns deferred top-level bindings that an eager initializer may reach
/// through a callable. Every non-direct-closure `Let` is an eager root,
/// independently of its declared `ValueKind`; direct references are classified
/// by `ValueScope`. Callable traversal reaches a fixed point by following known
/// callable bodies while `visiting` cuts recursive cycles.
fn Program::initialization_order_failures(
  self : Program,
) -> Array[InitializationOrderFailure] {
  let top_level = []
  let callables = []
  for term in self.terms {
    match term {
      External(id) => top_level.push(id)
      Let(id, initializer) => {
        top_level.push(id)
        if self.metadata.value_info(id) is Some(info) && info.kind is Function {
          callables.push({ id, body: initializer, })
        }
      }
      LetRec(bindings) =>
        for binding in bindings {
          top_level.push(binding.id)
          callables.push({ id: binding.id, body: binding.rhs, })
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
        if !initializer.is_direct_function_implementation() {
          let collector = InitializationDependencyCollector::{
            top_level,
            bound,
            callables,
          }
          let dependencies = []
          collector.collect(initializer, Eager, [], dependencies)
          for dependency in dependencies {
            if !bound.contains(dependency) {
              failures.push({ initializer: id, dependency, })
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
  mode : InitializationDependencyMode,
  visiting : Array[ValueId],
  dependencies : Array[ValueId],
) -> Unit {
  match expression {
    Ref(id) => {
      if mode is Callable &&
        self.top_level.contains(id) &&
        !dependencies.contains(id) {
        dependencies.push(id)
      }
      if self.bound.contains(id) && !visiting.contains(id) {
        for callable in self.callables {
          if callable.id == id {
            visiting.push(id)
            self.collect(callable.body, Callable, visiting, dependencies)
            ignore(visiting.pop())
          }
        }
      }
    }
    Literal(_) | Resume(_) => ()
    Function(function) =>
      self.collect(function.body, Callable, visiting, dependencies)
    Call(callee, arguments) => {
      self.collect(callee, mode, visiting, dependencies)
      for argument in arguments {
        self.collect(argument, mode, visiting, dependencies)
      }
    }
    TypeLambda(_, body) => self.collect(body, Callable, visiting, dependencies)
    TypeApply(callee, _) => self.collect(callee, mode, visiting, dependencies)
    Construct(construct) =>
      for payload in construct.payloads {
        self.collect(payload, mode, visiting, dependencies)
      }
    Let(_, initializer, body) => {
      self.collect(initializer, mode, visiting, dependencies)
      self.collect(body, mode, visiting, dependencies)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        self.collect(binding.rhs, Callable, visiting, dependencies)
      }
      self.collect(body, mode, visiting, dependencies)
    }
    Match(match_) => {
      self.collect(match_.scrutinee, mode, visiting, dependencies)
      for alternative in match_.alternatives {
        self.collect(alternative.body, mode, visiting, dependencies)
      }
    }
    Perform(perform) =>
      for payload in perform.payloads {
        self.collect(payload, mode, visiting, dependencies)
      }
    Handle(handle) => {
      self.collect(handle.body, mode, visiting, dependencies)
      self.collect(handle.final_body, mode, visiting, dependencies)
      for handler in handle.handlers {
        for operation in handler.operations {
          self.collect(operation.body, mode, visiting, dependencies)
        }
      }
    }
  }
}
