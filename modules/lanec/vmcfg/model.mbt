///|
pub(all) struct ValueId {
  value : Int
} derive(Debug, Eq, Compare)

///|
pub(all) enum Ownership {
  Trivial
  Owned
  Borrowed
} derive(Debug, Eq)

///|
pub(all) struct ValueMetadata {
  representation : @bytecode.Representation
  cleanup : @bytecode.Cleanup
  kind : @bytecode.SemanticValueKind
  ownership : Ownership
  erased_companion : ValueId?
} derive(Debug, Eq)

///|
pub(all) struct FunctionInputs {
  environment : ValueId?
  witnesses : Array[ValueId]
  user_parameters : Array[ValueId]
} derive(Debug, Eq)

///|
pub(all) enum LayoutOperand {
  Immediate(@bytecode.LayoutId)
  Witness(ValueId)
} derive(Debug, Eq)

///|
pub(all) struct ProjectionResult {
  value_destination : ValueId
  witness_destination : ValueId?
} derive(Debug, Eq)

///|
pub(all) struct ProjectionSelection {
  member_index : Int
  result : ProjectionResult
} derive(Debug, Eq)

///|
pub(all) enum Instruction {
  Copy(ValueId, ValueId)
  Move(ValueId, ValueId)
  RetainCopy(ValueId, ValueId)
  Release(ValueId)
  ConstI64(ValueId, Int64)
  ConstI32(ValueId, Int)
  ConstChar(ValueId, Int)
  ConstF64(ValueId, Int64)
  ConstF32(ValueId, Int)
  ConstBool(ValueId, Bool)
  ConstLayout(ValueId, @bytecode.LayoutId)
  ConstFunction(ValueId, @bytecode.FunctionId)
  ConstString(ValueId, @bytecode.ConstantId)
  CallDirect(
    @bytecode.FunctionId,
    ValueId?,
    Array[ValueId],
    Array[ValueId],
    ValueId?
  )
  CallValue(ValueId, Array[ValueId], Array[ValueId], ValueId?)
  MakeData(
    ValueId,
    @bytecode.ObjectShapeId,
    LayoutOperand,
    Array[ValueId],
    Array[ValueId]
  )
  LoadTag(ValueId, ValueId)
  LoadObjectWitness(ValueId, @bytecode.ObjectShapeId, ValueId, Int)
  BorrowField(@bytecode.ObjectShapeId, ValueId, Int, ProjectionResult)
  ConsumeFields(@bytecode.ObjectShapeId, ValueId, Array[ProjectionSelection])
  MakeEnv(
    ValueId,
    @bytecode.ObjectShapeId,
    LayoutOperand,
    Array[ValueId],
    Array[ValueId]
  )
  BorrowCapture(@bytecode.ObjectShapeId, ValueId, Int, ProjectionResult)
  ConsumeCaptures(@bytecode.ObjectShapeId, ValueId, Array[ProjectionSelection])
  MakeClosure(ValueId, @bytecode.FunctionId, ValueId)
  ByteToI64(ValueId, ValueId)
  I64ToByte(ValueId, ValueId)
  ByteSequenceMake(ValueId, ValueId, ValueId)
  ByteSequenceLength(ValueId, ValueId)
  ByteSequenceGet(ValueId, ValueId, ValueId)
  ByteSequenceSet(ValueId, ValueId, ValueId, ValueId)
  ByteSequenceEqual(ValueId, ValueId, ValueId)
  ByteSequenceConcat(ValueId, ValueId, ValueId)
  ByteSequenceSlice(ValueId, ValueId, ValueId, ValueId)
  ByteSequenceIsValidUtf8(ValueId, ValueId)
  I32Add(ValueId, ValueId, ValueId)
  I32Sub(ValueId, ValueId, ValueId)
  I32Mul(ValueId, ValueId, ValueId)
  I32Neg(ValueId, ValueId)
  I32Div(ValueId, ValueId, ValueId)
  I32Rem(ValueId, ValueId, ValueId)
  I32Eq(ValueId, ValueId, ValueId)
  I32Lt(ValueId, ValueId, ValueId)
  I32ToI64(ValueId, ValueId)
  I64ToI32(ValueId, ValueId)
  I64Add(ValueId, ValueId, ValueId)
  I64Sub(ValueId, ValueId, ValueId)
  I64Mul(ValueId, ValueId, ValueId)
  I64Neg(ValueId, ValueId)
  I64Div(ValueId, ValueId, ValueId)
  I64Rem(ValueId, ValueId, ValueId)
  I64And(ValueId, ValueId, ValueId)
  I64Or(ValueId, ValueId, ValueId)
  I64Xor(ValueId, ValueId, ValueId)
  I64Not(ValueId, ValueId)
  I64Shl(ValueId, ValueId, ValueId)
  I64ShrS(ValueId, ValueId, ValueId)
  I64Eq(ValueId, ValueId, ValueId)
  I64Ne(ValueId, ValueId, ValueId)
  I64Lt(ValueId, ValueId, ValueId)
  I64Le(ValueId, ValueId, ValueId)
  I64Gt(ValueId, ValueId, ValueId)
  I64Ge(ValueId, ValueId, ValueId)
  BoolNot(ValueId, ValueId)
  BoolEq(ValueId, ValueId, ValueId)
  BoolNe(ValueId, ValueId, ValueId)
  F64Add(ValueId, ValueId, ValueId)
  F64Sub(ValueId, ValueId, ValueId)
  F64Mul(ValueId, ValueId, ValueId)
  F64Div(ValueId, ValueId, ValueId)
  F64Neg(ValueId, ValueId)
  F64Eq(ValueId, ValueId, ValueId)
  F64Ne(ValueId, ValueId, ValueId)
  F64Lt(ValueId, ValueId, ValueId)
  F64Le(ValueId, ValueId, ValueId)
  F64Gt(ValueId, ValueId, ValueId)
  F64Ge(ValueId, ValueId, ValueId)
  I64ToF64(ValueId, ValueId)
  F64ToI64(ValueId, ValueId)
  F32Add(ValueId, ValueId, ValueId)
  F32Sub(ValueId, ValueId, ValueId)
  F32Mul(ValueId, ValueId, ValueId)
  F32Div(ValueId, ValueId, ValueId)
  F32Neg(ValueId, ValueId)
  F32Eq(ValueId, ValueId, ValueId)
  F32Ne(ValueId, ValueId, ValueId)
  F32Lt(ValueId, ValueId, ValueId)
  F32Le(ValueId, ValueId, ValueId)
  F32Gt(ValueId, ValueId, ValueId)
  F32Ge(ValueId, ValueId, ValueId)
  I64ToF32(ValueId, ValueId)
  F32ToI64(ValueId, ValueId)
  F32ToF64(ValueId, ValueId)
  F64ToF32(ValueId, ValueId)
  F32ToString(ValueId, ValueId)
  F64ToString(ValueId, ValueId)
  EraseI32(ValueId, ValueId)
  UneraseI32(ValueId, ValueId)
  EraseI64(ValueId, ValueId)
  UneraseI64(ValueId, ValueId)
  EraseF64(ValueId, ValueId)
  UneraseF64(ValueId, ValueId)
  EraseF32(ValueId, ValueId)
  UneraseF32(ValueId, ValueId)
  EraseUnit(ValueId)
  UneraseUnit(ValueId)
  InitGlobal(@bytecode.GlobalId, ValueId)
  BorrowGlobal(ValueId, @bytecode.GlobalId)
} derive(Debug, Eq)

///|
pub(all) struct Edge {
  target : @bytecode.BlockId
  arguments : Array[ValueId]
} derive(Debug, Eq)

///|
pub(all) enum Terminator {
  Jump(Edge)
  BranchBool(ValueId, Edge, Edge)
  SwitchTag(ValueId, Array[Edge], Edge)
  Return(ValueId?)
  TailCallDirect(@bytecode.FunctionId, ValueId?, Array[ValueId], Array[ValueId])
  TailCallValue(ValueId, Array[ValueId], Array[ValueId])
  Unreachable
} derive(Debug, Eq)

///|
pub(all) struct Block {
  parameters : Array[ValueId]
  instructions : Array[Instruction]
  terminator : Terminator
} derive(Debug, Eq)

///|
pub(all) struct FunctionBody {
  values : Array[ValueMetadata]
  inputs : FunctionInputs
  result : @bytecode.ResultAbi
  blocks : Array[Block]
} derive(Debug, Eq)

///|
pub(all) enum FunctionEntry {
  Body(FunctionBody)
  RuntimeImport(@bytecode.RuntimeImport)
} derive(Debug, Eq)

///|
pub(all) struct Image {
  entry : @bytecode.FunctionId
  initializer : @bytecode.FunctionId?
  functions : Array[FunctionEntry]
  data_family_count : Int
  globals : Array[@bytecode.GlobalMetadata]
  layouts : Array[@bytecode.LayoutRecipe]
  object_shapes : Array[@bytecode.ObjectShape]
  constants : Array[Bytes]
} derive(Debug, Eq)

///|
pub(all) suberror FinalizeError {
  IllegalValueMetadata(value~ : ValueId)
  UseBeforeOwnership(value~ : ValueId, block~ : Int)
} derive(Debug, Eq)
