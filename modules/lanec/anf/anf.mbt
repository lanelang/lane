///|
pub(all) struct AnfProgram {
  metadata : @buslane.MetadataRegistry
  terms : Array[AnfTopTerm]
} derive(Debug, Eq)

///|
pub(all) enum AnfTopTerm {
  Let(@buslane.ValueId, AnfExpr)
  LetRec(Array[AnfRecursiveBinding])
  External(@buslane.ValueId)
} derive(Debug, Eq)

///|
pub(all) struct AnfRecursiveBinding {
  id : @buslane.ValueId
  rhs : AnfAtom
} derive(Debug, Eq)

///|
pub(all) enum AnfExpr {
  Atom(AnfAtom)
  Let(AnfBinding, AnfExpr)
  LetRec(Array[AnfRecursiveBinding], AnfExpr)
  Match(AnfMatch)
} derive(Debug, Eq)

///|
pub(all) enum AnfBinding {
  Value(id~ : @buslane.ValueId, rhs~ : AnfRhs)
  Temp(temp~ : AnfTempId, rhs~ : AnfRhs)
} derive(Debug, Eq)

///|
pub(all) enum AnfRhs {
  Atom(AnfAtom)
  Call(callee~ : AnfAtom, arguments~ : Array[AnfAtom])
  TypeApply(callee~ : AnfAtom, arguments~ : Array[@buslane.GenericArgument])
  Construct(AnfConstruct)
  Perform(AnfPerform)
  Handle(AnfHandle)
} derive(Debug, Eq)

///|
pub(all) struct AnfPerform {
  operation : @buslane.OperationId
  effect_arguments : Array[@buslane.GenericArgument]
  hidden_witnesses : Array[@buslane.GenericArgument]
  payloads : Array[AnfAtom]
} derive(Debug, Eq)

///|
pub(all) struct AnfHandle {
  body : AnfExpr
  result_binder : @buslane.ValueId
  result_type : @buslane.Type
  final_body : AnfExpr
  handlers : Array[AnfHandlerTable]
} derive(Debug, Eq)

///|
pub(all) struct AnfHandlerTable {
  handled_effect : @buslane.Effect
  operations : Array[AnfOperationAlternative]
} derive(Debug, Eq)

///|
pub(all) struct AnfOperationAlternative {
  operation : @buslane.OperationId
  type_binders : Array[@buslane.TypeParameterId]
  payload_binders : Array[@buslane.ValueId]
  resume_binder : @buslane.ValueId
  body : AnfExpr
} derive(Debug, Eq)

///|
pub(all) struct AnfConstruct {
  data_constructor : @buslane.DataConId
  type_arguments : Array[@buslane.GenericArgument]
  hidden_witnesses : Array[@buslane.GenericArgument]
  payloads : Array[AnfAtom]
} derive(Debug, Eq)

///|
pub(all) enum AnfAtom {
  Literal(@buslane.Literal)
  Ref(@buslane.ValueId)
  Temp(AnfTempId)
  Function(AnfFunction)
  TypeLambda(
    type_parameters~ : Array[@buslane.TypeParameterId],
    body~ : AnfExpr
  )
} derive(Debug, Eq)

///|
pub(all) struct AnfFunction {
  parameters : Array[@buslane.ValueId]
  result_type : @buslane.Type
  body : AnfExpr
} derive(Debug, Eq)

///|
pub(all) struct AnfMatch {
  scrutinee : AnfAtom
  binder : @buslane.ValueId
  result_type : @buslane.Type
  alternatives : Array[AnfAlternative]
} derive(Debug, Eq)

///|
pub(all) struct AnfAlternative {
  alt_constructor : @buslane.AltCon
  type_binders : Array[@buslane.TypeParameterId]
  value_binders : Array[@buslane.ValueId]
  body : AnfExpr
} derive(Debug, Eq)
