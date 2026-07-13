///|
pub(all) struct Program {
  metadata : @buslane.MetadataRegistry
  terms : Array[TopTerm]
} derive(Debug, Eq)

///|
pub(all) enum TopTerm {
  Let(@buslane.ValueId, Expr)
  LetRec(Array[RecursiveBinding])
  External(@buslane.ValueId)
} derive(Debug, Eq)

///|
pub(all) struct RecursiveBinding {
  id : @buslane.ValueId
  rhs : Expr
} derive(Debug, Eq)

///|
pub(all) enum Expr {
  Ref(@buslane.ValueId)
  Literal(@buslane.Literal)
  Function(FunctionExpr)
  Call(Expr, Array[Expr])
  TypeLambda(Array[@buslane.TypeParameterId], Expr)
  TypeApply(Expr, Array[@buslane.GenericArgument])
  Construct(ConstructExpr)
  Let(@buslane.ValueId, Expr, Expr)
  LetRec(Array[RecursiveBinding], Expr)
  Match(MatchExpr)
  Invoke(InvokeExpr)
  Install(InstallExpr)
} derive(Debug, Eq)

///|
pub(all) struct FunctionExpr {
  parameters : Array[@buslane.ValueId]
  result_type : @buslane.Type
  body : Expr
} derive(Debug, Eq)

///|
pub(all) struct ConstructExpr {
  data_constructor : @buslane.DataConId
  type_arguments : Array[@buslane.GenericArgument]
  hidden_witnesses : Array[@buslane.GenericArgument]
  payloads : Array[Expr]
} derive(Debug, Eq)

///|
pub(all) struct MatchExpr {
  scrutinee : Expr
  binder : @buslane.ValueId
  result_type : @buslane.Type
  alternatives : Array[Alternative]
} derive(Debug, Eq)

///|
pub(all) struct Alternative {
  alt_constructor : @buslane.AltCon
  type_binders : Array[@buslane.TypeParameterId]
  value_binders : Array[@buslane.ValueId]
  body : Expr
} derive(Debug, Eq)

///|
pub(all) struct InvokeExpr {
  operation : @buslane.OperationId
  effect_arguments : Array[@buslane.GenericArgument]
  hidden_witnesses : Array[@buslane.GenericArgument]
  payloads : Array[Expr]
} derive(Debug, Eq)

///|
pub(all) struct InstallExpr {
  body : Expr
  result_type : @buslane.Type
  dictionaries : Array[HandlerDictionary]
  final_clause : FunctionExpr
} derive(Debug, Eq)

///|
pub(all) struct HandlerDictionary {
  handled_effect : @buslane.Effect
  operations : Array[OperationClause]
} derive(Debug, Eq)

///|
pub(all) struct OperationClause {
  operation : @buslane.OperationId
  callable : ClauseCallable
} derive(Debug, Eq)

///|
pub(all) enum ClauseCallable {
  Monomorphic(FunctionExpr)
  Polymorphic(Array[@buslane.TypeParameterId], FunctionExpr)
} derive(Debug, Eq)
