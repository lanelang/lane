///|
/// The transformation that first gave a runtime function its callable shape.
/// This is compiler provenance only; it never affects program semantics or
/// optimization legality.
pub(all) enum FunctionOrigin {
  SourceWritten
  HandlerElaboration
  MonadicTransformation
  SelectiveCps
} derive(Debug, Eq)

///|
priv struct FunctionOriginEntry {
  function : @buslane.FunctionExpr
  origin : FunctionOrigin
} derive(Debug, Eq)

///|
/// Transient provenance attached to immutable Buslane function objects.
/// Rewriters must explicitly transfer an entry whenever they rebuild or clone
/// a function. Runtime ANF consumes the catalog and internalizes the origin.
pub struct FunctionOriginCatalog {
  priv entries : Array[FunctionOriginEntry]
} derive(Debug, Eq)

///|
pub fn FunctionOriginCatalog::new() -> FunctionOriginCatalog {
  { entries: [], }
}

///|
pub fn FunctionOriginCatalog::origin(
  self : FunctionOriginCatalog,
  function : @buslane.FunctionExpr,
) -> FunctionOrigin? {
  for entry in self.entries.rev_iter() {
    if physical_equal(entry.function, function) {
      return Some(entry.origin)
    }
  }
  None
}

///|
/// Records the sole origin for a function object. Returns false only when the
/// same object was already assigned a conflicting origin.
pub fn FunctionOriginCatalog::record(
  self : FunctionOriginCatalog,
  function : @buslane.FunctionExpr,
  origin : FunctionOrigin,
) -> Bool {
  match self.origin(function) {
    Some(existing) => existing == origin
    None => {
      self.entries.push({ function, origin, })
      true
    }
  }
}

///|
/// Copies provenance to a function object produced by a semantics-preserving
/// rewrite. A missing source entry is reported to the transformation owner.
pub fn FunctionOriginCatalog::transfer(
  self : FunctionOriginCatalog,
  source : @buslane.FunctionExpr,
  target : @buslane.FunctionExpr,
) -> Bool {
  guard self.origin(source) is Some(origin) else { return false }
  self.record(target, origin)
}

///|
/// Constructs an explicitly uniform catalog for direct Buslane clients. The
/// caller, not this traversal, owns the asserted origin.
pub fn FunctionOriginCatalog::uniform(
  program : @buslane.Program,
  origin : FunctionOrigin,
) -> FunctionOriginCatalog {
  let catalog = FunctionOriginCatalog::new()
  for term in program.terms {
    match term {
      Let(_, expression) => catalog.record_expr(expression, origin)
      LetRec(bindings) =>
        for binding in bindings {
          catalog.record_expr(binding.rhs, origin)
        }
      External(_) => ()
    }
  }
  catalog
}

///|
fn FunctionOriginCatalog::record_function(
  self : FunctionOriginCatalog,
  function : @buslane.FunctionExpr,
  origin : FunctionOrigin,
) -> Unit {
  ignore(self.record(function, origin))
  self.record_expr(function.body, origin)
}

///|
fn FunctionOriginCatalog::record_expr(
  self : FunctionOriginCatalog,
  expression : @buslane.Expr,
  origin : FunctionOrigin,
) -> Unit {
  match expression {
    Ref(_) | Literal(_) | Resume(_) => ()
    Function(function) => self.record_function(function, origin)
    Call(callee, arguments) => {
      self.record_expr(callee, origin)
      for argument in arguments {
        self.record_expr(argument, origin)
      }
    }
    TypeLambda(_, body) | TypeApply(body, _) => self.record_expr(body, origin)
    Construct(construct) =>
      for payload in construct.payloads {
        self.record_expr(payload, origin)
      }
    Let(_, initializer, body) => {
      self.record_expr(initializer, origin)
      self.record_expr(body, origin)
    }
    LetRec(bindings, body) => {
      for binding in bindings {
        self.record_expr(binding.rhs, origin)
      }
      self.record_expr(body, origin)
    }
    Match(match_) => {
      self.record_expr(match_.scrutinee, origin)
      for alternative in match_.alternatives {
        self.record_expr(alternative.body, origin)
      }
    }
    Perform(perform) =>
      for payload in perform.payloads {
        self.record_expr(payload, origin)
      }
    Handle(handle) => {
      self.record_expr(handle.body, origin)
      self.record_expr(handle.final_body, origin)
      for table in handle.handlers {
        for operation in table.operations {
          self.record_expr(operation.body, origin)
        }
      }
    }
  }
}
