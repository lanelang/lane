///|
pub(all) struct FunctionId {
  value : Int
} derive(Debug, Eq, Compare)

///|
pub(all) struct GlobalId {
  value : Int
} derive(Debug, Eq, Compare)

///|
pub(all) struct LayoutId {
  value : Int
} derive(Debug, Eq, Compare)

///|
pub(all) struct BlockId {
  value : Int
} derive(Debug, Eq, Compare)

///|
pub(all) struct SlotId {
  value : Int
} derive(Debug, Eq, Compare)

///|
pub(all) struct ConstantId {
  value : Int
} derive(Debug, Eq, Compare)

///|
pub(all) struct ObjectShapeId {
  value : Int
} derive(Debug, Eq, Compare)

///|
pub(all) enum Representation {
  I32
  I64
  F64
} derive(Debug, Eq)

///|
pub(all) enum Cleanup {
  Trivial
  OwnedRef
  OwnedCallable
  OwnedErased
} derive(Debug, Eq)

///|
pub(all) struct SlotMetadata {
  representation : Representation
  cleanup : Cleanup
  erased_companion : SlotId?
} derive(Debug, Eq)

///|
pub(all) struct GlobalMetadata {
  representation : Representation
  cleanup : Cleanup
  erased_companion : GlobalId?
} derive(Debug, Eq)

///|
pub(all) enum ResultRepresentation {
  Unit
  I32
  I64
  F64
} derive(Debug, Eq)

///|
pub(all) struct FunctionInputs {
  environment : SlotId?
  witnesses : Array[SlotId]
  user_parameters : Array[SlotId]
} derive(Debug, Eq)

///|
pub(all) struct RuntimeImport {
  abi_major : Int
  user_arity : Int
  symbol : String
} derive(Debug, Eq)

///|
pub(all) enum LayoutRecipe {
  Unit
  Bool
  Int
  Double
  Callable
  String
  Data(ObjectShapeId)
  Environment(ObjectShapeId)
  Reference
} derive(Debug, Eq)

///|
pub(all) struct MemberSchema {
  representation : Representation
  cleanup : Cleanup
  witness_ordinal : Int?
} derive(Debug, Eq)

///|
pub(all) struct DataShape {
  constructor_tag : Int
  stored_witness_count : Int
  members : Array[MemberSchema]
} derive(Debug, Eq)

///|
pub(all) struct EnvironmentShape {
  stored_witness_count : Int
  members : Array[MemberSchema]
} derive(Debug, Eq)

///|
pub(all) enum ObjectShape {
  Data(DataShape)
  Environment(EnvironmentShape)
} derive(Debug, Eq)

///|
pub(all) enum LayoutOperand {
  Immediate(LayoutId)
  Witness(SlotId)
} derive(Debug, Eq)

///|
pub(all) struct ProjectionResult {
  value_destination : SlotId
  witness_destination : SlotId?
} derive(Debug, Eq)

///|
pub(all) struct ProjectionSelection {
  member_index : Int
  result : ProjectionResult
} derive(Debug, Eq)

///|
pub(all) enum Instruction {
  Copy(SlotId, SlotId)
  Move(SlotId, SlotId)
  RetainCopy(SlotId, SlotId)
  Release(SlotId)
  ConstInt(SlotId, Int64)
  ConstDouble(SlotId, Int64)
  ConstBool(SlotId, Bool)
  ConstLayout(SlotId, LayoutId)
  ConstFunction(SlotId, FunctionId)
  ConstString(SlotId, ConstantId)
  CallDirect(FunctionId, SlotId?, Array[SlotId], Array[SlotId], SlotId?)
  CallValue(SlotId, Array[SlotId], Array[SlotId], SlotId?)
  MakeData(SlotId, ObjectShapeId, LayoutOperand, Array[SlotId], Array[SlotId])
  LoadTag(SlotId, SlotId)
  LoadObjectWitness(SlotId, ObjectShapeId, SlotId, Int)
  BorrowField(ObjectShapeId, SlotId, Int, ProjectionResult)
  ConsumeFields(ObjectShapeId, SlotId, Array[ProjectionSelection])
  MakeEnv(SlotId, ObjectShapeId, LayoutOperand, Array[SlotId], Array[SlotId])
  BorrowCapture(ObjectShapeId, SlotId, Int, ProjectionResult)
  ConsumeCaptures(ObjectShapeId, SlotId, Array[ProjectionSelection])
  MakeClosure(SlotId, FunctionId, SlotId)
  StringLength(SlotId, SlotId)
  StringConcat(SlotId, SlotId, SlotId)
  StringSlice(SlotId, SlotId, SlotId, SlotId)
  StringEq(SlotId, SlotId, SlotId)
  IntAdd(SlotId, SlotId, SlotId)
  IntSub(SlotId, SlotId, SlotId)
  IntMul(SlotId, SlotId, SlotId)
  IntNeg(SlotId, SlotId)
  IntDiv(SlotId, SlotId, SlotId)
  IntRem(SlotId, SlotId, SlotId)
  IntAnd(SlotId, SlotId, SlotId)
  IntOr(SlotId, SlotId, SlotId)
  IntXor(SlotId, SlotId, SlotId)
  IntNot(SlotId, SlotId)
  IntShl(SlotId, SlotId, SlotId)
  IntShrS(SlotId, SlotId, SlotId)
  IntEq(SlotId, SlotId, SlotId)
  IntNe(SlotId, SlotId, SlotId)
  IntLt(SlotId, SlotId, SlotId)
  IntLe(SlotId, SlotId, SlotId)
  IntGt(SlotId, SlotId, SlotId)
  IntGe(SlotId, SlotId, SlotId)
  BoolNot(SlotId, SlotId)
  BoolEq(SlotId, SlotId, SlotId)
  BoolNe(SlotId, SlotId, SlotId)
  DoubleAdd(SlotId, SlotId, SlotId)
  DoubleSub(SlotId, SlotId, SlotId)
  DoubleMul(SlotId, SlotId, SlotId)
  DoubleDiv(SlotId, SlotId, SlotId)
  DoubleNeg(SlotId, SlotId)
  DoubleEq(SlotId, SlotId, SlotId)
  DoubleNe(SlotId, SlotId, SlotId)
  DoubleLt(SlotId, SlotId, SlotId)
  DoubleLe(SlotId, SlotId, SlotId)
  DoubleGt(SlotId, SlotId, SlotId)
  DoubleGe(SlotId, SlotId, SlotId)
  IntToDouble(SlotId, SlotId)
  DoubleToInt(SlotId, SlotId)
  EraseI32(SlotId, SlotId)
  UneraseI32(SlotId, SlotId)
  EraseI64(SlotId, SlotId)
  UneraseI64(SlotId, SlotId)
  EraseF64(SlotId, SlotId)
  UneraseF64(SlotId, SlotId)
  EraseUnit(SlotId)
  UneraseUnit(SlotId)
  InitGlobal(GlobalId, SlotId)
  BorrowGlobal(SlotId, GlobalId)
} derive(Debug, Eq)

///|
pub(all) struct Edge {
  target : BlockId
  arguments : Array[SlotId]
} derive(Debug, Eq)

///|
pub(all) enum Terminator {
  Jump(Edge)
  BranchBool(SlotId, Edge, Edge)
  SwitchTag(SlotId, Array[Edge], Edge)
  Return(SlotId?)
  TailCallDirect(FunctionId, SlotId?, Array[SlotId], Array[SlotId])
  TailCallValue(SlotId, Array[SlotId], Array[SlotId])
  Unreachable
} derive(Debug, Eq)

///|
pub(all) struct Block {
  parameters : Array[SlotId]
  instructions : Array[Instruction]
  terminator : Terminator
} derive(Debug, Eq)

///|
pub(all) struct FunctionBody {
  slots : Array[SlotMetadata]
  inputs : FunctionInputs
  result : ResultRepresentation
  blocks : Array[Block]
} derive(Debug, Eq)

///|
pub(all) enum FunctionEntry {
  BytecodeBody(FunctionBody)
  RuntimeImport(RuntimeImport)
} derive(Debug, Eq)

///|
pub(all) struct BytecodeImage {
  entry : FunctionId
  initializer : FunctionId?
  functions : Array[FunctionEntry]
  globals : Array[GlobalMetadata]
  layouts : Array[LayoutRecipe]
  object_shapes : Array[ObjectShape]
  constants : Array[Bytes]
} derive(Debug, Eq)
