///|
pub(all) struct BuslaneAnfProgram {
  metadata : @buslane.MetadataRegistry
  terms : Array[BuslaneAnfTopTerm]
} derive(Debug, Eq)

///|
pub(all) enum BuslaneAnfTopTerm {
  Let(@buslane.ValueId, BuslaneAnfExpr)
  LetRec(Array[BuslaneAnfRecursiveBinding])
  External(@buslane.ValueId)
} derive(Debug, Eq)

///|
pub(all) struct BuslaneAnfRecursiveBinding {
  id : @buslane.ValueId
  rhs : BuslaneAnfAtom
} derive(Debug, Eq)

///|
pub(all) enum BuslaneAnfExpr {
  Atom(BuslaneAnfAtom)
  Let(BuslaneAnfBinding, BuslaneAnfExpr)
  LetRec(Array[BuslaneAnfRecursiveBinding], BuslaneAnfExpr)
  Match(BuslaneAnfMatch)
} derive(Debug, Eq)

///|
pub(all) enum BuslaneAnfBinding {
  Value(id~ : @buslane.ValueId, rhs~ : BuslaneAnfRhs)
  Temp(temp~ : AnfTempId, rhs~ : BuslaneAnfRhs)
} derive(Debug, Eq)

///|
pub(all) enum BuslaneAnfRhs {
  Atom(BuslaneAnfAtom)
  Call(callee~ : BuslaneAnfAtom, arguments~ : Array[BuslaneAnfAtom])
  TypeApply(callee~ : BuslaneAnfAtom, arguments~ : Array[@buslane.Type])
  Construct(BuslaneAnfConstruct)
  Perform(BuslaneAnfPerform)
  Handle(BuslaneAnfHandle)
} derive(Debug, Eq)

///|
pub(all) struct BuslaneAnfPerform {
  operation : @buslane.OperationId
  type_arguments : Array[@buslane.Type]
  payloads : Array[BuslaneAnfAtom]
} derive(Debug, Eq)

///|
pub(all) struct BuslaneAnfHandle {
  body : BuslaneAnfExpr
  result_binder : @buslane.ValueId
  result_type : @buslane.Type
  final_body : BuslaneAnfExpr
  handlers : Array[BuslaneAnfHandlerTable]
} derive(Debug, Eq)

///|
pub(all) struct BuslaneAnfHandlerTable {
  handled_effect : @buslane.Effect
  operations : Array[BuslaneAnfOperationAlternative]
} derive(Debug, Eq)

///|
pub(all) struct BuslaneAnfOperationAlternative {
  operation : @buslane.OperationId
  payload_binders : Array[@buslane.ValueId]
  resume_binder : @buslane.ValueId
  body : BuslaneAnfExpr
} derive(Debug, Eq)

///|
pub(all) struct BuslaneAnfConstruct {
  data_constructor : @buslane.DataConId
  type_arguments : Array[@buslane.Type]
  hidden_witnesses : Array[@buslane.Type]
  payloads : Array[BuslaneAnfAtom]
} derive(Debug, Eq)

///|
pub(all) enum BuslaneAnfAtom {
  Literal(@buslane.Literal)
  Ref(@buslane.ValueId)
  Temp(AnfTempId)
  Function(BuslaneAnfFunction)
  TypeLambda(
    type_parameters~ : Array[@buslane.TypeParameterId],
    body~ : BuslaneAnfExpr
  )
} derive(Debug, Eq)

///|
pub(all) struct BuslaneAnfFunction {
  parameters : Array[@buslane.ValueId]
  result_type : @buslane.Type
  body : BuslaneAnfExpr
} derive(Debug, Eq)

///|
pub(all) struct BuslaneAnfMatch {
  scrutinee : BuslaneAnfAtom
  binder : @buslane.ValueId
  result_type : @buslane.Type
  alternatives : Array[BuslaneAnfAlternative]
} derive(Debug, Eq)

///|
pub(all) struct BuslaneAnfAlternative {
  alt_constructor : @buslane.AltCon
  type_binders : Array[@buslane.TypeParameterId]
  value_binders : Array[@buslane.ValueId]
  body : BuslaneAnfExpr
} derive(Debug, Eq)
