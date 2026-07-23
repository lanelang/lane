///|
pub(all) enum TuplePresentationPathStep {
  TypeApplicationCallee
  TypeApplicationArgument(Int)
  TypeLambdaBody
  FunctionParameter(Int)
  FunctionResult
  FunctionEffect
  EffectTerm
  EffectUnionItem(Int)
  TupleItem(Int)
} derive(Debug, Eq)

///|
pub(all) struct TuplePresentation {
  path : Array[TuplePresentationPathStep]
  item_count : Int
} derive(Debug, Eq)
