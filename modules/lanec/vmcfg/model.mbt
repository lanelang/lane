///|
pub(all) struct ValueId {
  value : Int
} derive(Debug, Eq, Compare)

///|
pub(all) enum CallableFlowBoundary {
  Alias
  BlockParameter
  FunctionParameter
  FunctionResult
  AggregateStorage
  GlobalStorage
  OpaqueInput
  OpaqueOperation
} derive(Debug, Eq)

///|
pub(all) enum CallableEnvironmentKnowledge {
  CaptureFree
  Local
  Packed
} derive(Debug, Eq)

///|
pub(all) enum IndirectCallResolution {
  ExactTarget(@physical.FunctionId, CallableEnvironmentKnowledge)
  MultipleTargets(Array[@physical.FunctionId])
  UnknownTargets(Array[@physical.FunctionId])
} derive(Debug, Eq)

///|
pub(all) struct IndirectCallObservation {
  function : @physical.FunctionId
  ordinal : Int
  resolution : IndirectCallResolution
  boundaries : Array[CallableFlowBoundary]
} derive(Debug, Eq)

///|
pub(all) enum Ownership {
  Trivial
  Owned
  Borrowed
} derive(Debug, Eq)

///|
pub(all) struct ValueMetadata {
  representation : @physical.Representation
  cleanup : @physical.Cleanup
  kind : @physical.SemanticValueKind
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
  Immediate(@physical.LayoutId)
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
  ConstLayout(ValueId, @physical.LayoutId)
  ConstFunction(ValueId, @physical.FunctionId)
  ConstString(ValueId, @physical.ConstantId)
  CallDirect(
    @physical.FunctionId,
    ValueId?,
    Array[ValueId],
    Array[ValueId],
    ValueId?
  )
  CallValue(ValueId, Array[ValueId], Array[ValueId], ValueId?)
  MakeData(
    ValueId,
    @physical.ObjectShapeId,
    LayoutOperand,
    Array[ValueId],
    Array[ValueId]
  )
  LoadTag(ValueId, ValueId)
  LoadObjectWitness(ValueId, @physical.ObjectShapeId, ValueId, Int)
  BorrowField(@physical.ObjectShapeId, ValueId, Int, ProjectionResult)
  ConsumeFields(@physical.ObjectShapeId, ValueId, Array[ProjectionSelection])
  MakeEnv(
    ValueId,
    @physical.ObjectShapeId,
    LayoutOperand,
    Array[ValueId],
    Array[ValueId]
  )
  BorrowCapture(@physical.ObjectShapeId, ValueId, Int, ProjectionResult)
  ConsumeCaptures(@physical.ObjectShapeId, ValueId, Array[ProjectionSelection])
  MakeClosure(ValueId, @physical.FunctionId, ValueId)
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
  InitGlobal(@physical.GlobalId, ValueId)
  BorrowGlobal(ValueId, @physical.GlobalId)
} derive(Debug, Eq)

///|
pub(all) struct Edge {
  target : @physical.BlockId
  arguments : Array[ValueId]
} derive(Debug, Eq)

///|
pub(all) enum Terminator {
  Jump(Edge)
  BranchBool(ValueId, Edge, Edge)
  SwitchTag(ValueId, Array[Edge], Edge)
  Return(ValueId?)
  TailCallDirect(@physical.FunctionId, ValueId?, Array[ValueId], Array[ValueId])
  TailCallValue(ValueId, Array[ValueId], Array[ValueId])
  Fatal(ValueId)
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
  result : @physical.ResultAbi
  blocks : Array[Block]
} derive(Debug, Eq)

///|
priv struct ArcFinalBody {
  body : FunctionBody
  use_def : UseDefAnalysis
}

///|
pub(all) enum FunctionEntry {
  Body(FunctionBody)
  RuntimeImport(@runtime.RuntimeImport)
} derive(Debug, Eq)

///|
pub(all) struct Image {
  entry : @physical.FunctionId
  initializer : @physical.FunctionId?
  functions : Array[FunctionEntry]
  data_family_count : Int
  globals : Array[@physical.GlobalMetadata]
  layouts : Array[@physical.LayoutRecipe]
  object_shapes : Array[@physical.ObjectShape]
  constants : Array[Bytes]
} derive(Debug, Eq)

///|
pub(all) enum PhysicalSlotPlanError {
  MissingAssignment(ValueId)
  MetadataMismatch(ValueId, @physical.SlotId)
  InterferenceConflict(ValueId, ValueId, @physical.SlotId)
} derive(Debug, Eq)

///|
pub(all) enum ArcFinalBodyError {
  EmptyControlFlowGraph
  EntryBlockHasParameters
  InvalidValue(ValueId)
  InvalidBlock(@physical.BlockId)
  UnreachableBlock(@physical.BlockId)
  EdgeArityMismatch(@physical.BlockId, @physical.BlockId, Int, Int)
  EdgeMetadataMismatch(@physical.BlockId, @physical.BlockId, Int)
  MissingDefinition(ValueId)
  UseBeforeDefinition(ValueId, @physical.BlockId)
  BorrowedValueConsumed(ValueId, @physical.BlockId)
  BorrowOwnerNotLive(ValueId, ValueId, @physical.BlockId)
  OwnedValueNotLive(ValueId, @physical.BlockId)
  OwnedValueOverwritten(ValueId, @physical.BlockId)
  OwnedValueEscapes(ValueId, @physical.BlockId)
  InconsistentOwnershipAtJoin(ValueId, @physical.BlockId)
  InvalidRelease(ValueId, @physical.BlockId)
} derive(Debug, Eq)

///|
pub(all) enum ValueDefinitionSite {
  FunctionInput(Int)
  BlockParameter(Int, Int)
  InstructionResult(Int, Int)
} derive(Debug, Eq)

///|
pub(all) enum UseDefAnalysisError {
  DuplicateDefinition(ValueId, ValueDefinitionSite, ValueDefinitionSite)
} derive(Debug, Eq)

///|
pub(all) suberror FunctionTableCanonicalizationError {
  InvalidFunctionReference(@physical.FunctionId)
  MissingFunctionMapping(@physical.FunctionId)
} derive(Debug, Eq)

///|
priv struct CanonicalPreArcImage {
  image : Image
  source_functions : Array[Array[@physical.FunctionId]]
  indirect_calls : Array[IndirectCallObservation]
}

///|
pub struct Finalization {
  pre_arc_image : Image
  source_functions : Array[Array[@physical.FunctionId]]
  indirect_calls : Array[IndirectCallObservation]
  physical_program : @physical.VerifiedPhysicalProgram
}

///|
pub(all) suberror FinalizeError {
  IllegalValueMetadata(value~ : ValueId)
  UseBeforeOwnership(value~ : ValueId, block~ : Int)
  UseDefAnalysisCompilerDefect(UseDefAnalysisError)
  FunctionTableCanonicalizationCompilerDefect(
    FunctionTableCanonicalizationError
  )
  IndirectCallObservationMismatch(@physical.FunctionId, Int, Int)
  ArcFinalVerificationCompilerDefect(ArcFinalBodyError)
  PhysicalSlotAllocationCompilerDefect(PhysicalSlotPlanError)
  PhysicalProgramVerificationCompilerDefect(
    @physical.PhysicalProgramVerificationError
  )
} derive(Debug, Eq)
