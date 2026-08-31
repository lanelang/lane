///|
pub(all) struct FunctionId {
  value : Int
} derive(Debug, Eq, Compare)

///|
pub(all) struct CallableAbiId {
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
pub(all) struct DataFamilyId {
  value : Int
} derive(Debug, Eq, Compare)

///|
pub(all) enum Representation {
  I32
  I64
  F64
  F32
} derive(Debug, Eq)

///|
pub(all) enum Cleanup {
  Trivial
  OwnedRef
  OwnedCallable
  OwnedErased
} derive(Debug, Eq)

///|
pub(all) enum SemanticValueKind {
  ScalarValue
  LayoutValue
  LayoutConstructorValue(Int)
  CallableValue
  ByteSequenceValue
  ByteBufferValue
  DataValue(DataFamilyId)
  EnvironmentValue(ObjectShapeId)
  ErasedValue
} derive(Debug, Eq)

///|
pub(all) struct SlotMetadata {
  representation : Representation
  cleanup : Cleanup
  kind : SemanticValueKind
  erased_companion : SlotId?
} derive(Debug, Eq)

///|
pub(all) struct GlobalMetadata {
  representation : Representation
  cleanup : Cleanup
  kind : SemanticValueKind
  erased_companion : GlobalId?
} derive(Debug, Eq)

///|
pub(all) enum ResultAbi {
  Unit
  Value(Representation, Cleanup, SemanticValueKind)
} derive(Debug, Eq)

///|
pub(all) struct ValueAbi {
  representation : Representation
  cleanup : Cleanup
  kind : SemanticValueKind
} derive(Debug, Eq)

///|
pub(all) struct CallableAbi {
  witnesses : Array[ValueAbi]
  parameters : Array[ValueAbi]
  result : ResultAbi
} derive(Debug, Eq)

///|
pub(all) struct FunctionInputs {
  environment : SlotId?
  witnesses : Array[SlotId]
  user_parameters : Array[SlotId]
} derive(Debug, Eq)

///|
pub(all) enum LayoutRecipe {
  Unit
  Bool
  I64
  I32
  Char
  F64
  F32
  Callable
  ByteSequence
  ByteBuffer
  Byte
  Data(ObjectShapeId)
  Environment(ObjectShapeId)
  Reference
} derive(Debug, Eq)

///|
pub(all) struct MemberSchema {
  representation : Representation
  cleanup : Cleanup
  kind : SemanticValueKind
  witness_ordinal : Int?
} derive(Debug, Eq)

///|
pub(all) struct DataShape {
  family : DataFamilyId
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
pub(all) enum RuntimeImportArgument {
  Direct(SlotId)
  GuestAddress(SlotId, SlotId)
} derive(Debug, Eq)

///|
pub(all) enum Instruction {
  Copy(SlotId, SlotId)
  Move(SlotId, SlotId)
  RetainCopy(SlotId, SlotId)
  Release(SlotId)
  ConstI64(SlotId, Int64)
  ConstI32(SlotId, Int)
  ConstChar(SlotId, Int)
  ConstF64(SlotId, Int64)
  ConstF32(SlotId, Int)
  ConstBool(SlotId, Bool)
  ConstLayout(SlotId, LayoutId)
  ConstFunction(SlotId, FunctionId)
  ConstString(SlotId, ConstantId)
  CallDirect(FunctionId, SlotId?, Array[SlotId], Array[SlotId], SlotId?)
  CallRuntimeImport(FunctionId, Array[RuntimeImportArgument], SlotId?)
  CallPackedDirect(FunctionId, SlotId, Array[SlotId], Array[SlotId], SlotId?)
  CallValue(SlotId, CallableAbiId, Array[SlotId], Array[SlotId], SlotId?)
  MakeData(SlotId, ObjectShapeId, LayoutOperand, Array[SlotId], Array[SlotId])
  LoadTag(SlotId, SlotId)
  LoadObjectWitness(SlotId, ObjectShapeId, SlotId, Int)
  BorrowField(ObjectShapeId, SlotId, Int, ProjectionResult)
  ConsumeFields(ObjectShapeId, SlotId, Array[ProjectionSelection])
  MakeEnv(SlotId, ObjectShapeId, LayoutOperand, Array[SlotId], Array[SlotId])
  BorrowCapture(ObjectShapeId, SlotId, Int, ProjectionResult)
  ConsumeCaptures(ObjectShapeId, SlotId, Array[ProjectionSelection])
  MakeClosure(SlotId, FunctionId, SlotId)
  ByteToI64(SlotId, SlotId)
  I64ToByte(SlotId, SlotId)
  ByteSequenceMake(SlotId, SlotId, SlotId)
  ByteSequenceLength(SlotId, SlotId)
  ByteSequenceGet(SlotId, SlotId, SlotId)
  ByteSequenceSet(SlotId, SlotId, SlotId, SlotId)
  ByteSequenceEqual(SlotId, SlotId, SlotId)
  ByteSequenceConcat(SlotId, SlotId, SlotId)
  ByteSequenceSlice(SlotId, SlotId, SlotId, SlotId)
  ByteSequenceIsValidUtf8(SlotId, SlotId)
  ByteBufferMake(SlotId, SlotId)
  ByteBufferWriteBytes(SlotId, SlotId, SlotId)
  ByteBufferWriteI32(SlotId, SlotId, SlotId)
  ByteBufferWriteAddress(SlotId, SlotId, SlotId, SlotId)
  ByteBufferReadI32(SlotId, SlotId, SlotId)
  I32Add(SlotId, SlotId, SlotId)
  I32Sub(SlotId, SlotId, SlotId)
  I32Mul(SlotId, SlotId, SlotId)
  I32Neg(SlotId, SlotId)
  I32Div(SlotId, SlotId, SlotId)
  I32Rem(SlotId, SlotId, SlotId)
  I32Eq(SlotId, SlotId, SlotId)
  I32Lt(SlotId, SlotId, SlotId)
  I32ToI64(SlotId, SlotId)
  I64ToI32(SlotId, SlotId)
  I64Add(SlotId, SlotId, SlotId)
  I64Sub(SlotId, SlotId, SlotId)
  I64Mul(SlotId, SlotId, SlotId)
  I64Neg(SlotId, SlotId)
  I64Div(SlotId, SlotId, SlotId)
  I64Rem(SlotId, SlotId, SlotId)
  I64And(SlotId, SlotId, SlotId)
  I64Or(SlotId, SlotId, SlotId)
  I64Xor(SlotId, SlotId, SlotId)
  I64Not(SlotId, SlotId)
  I64Shl(SlotId, SlotId, SlotId)
  I64ShrS(SlotId, SlotId, SlotId)
  I64Eq(SlotId, SlotId, SlotId)
  I64Ne(SlotId, SlotId, SlotId)
  I64Lt(SlotId, SlotId, SlotId)
  I64Le(SlotId, SlotId, SlotId)
  I64Gt(SlotId, SlotId, SlotId)
  I64Ge(SlotId, SlotId, SlotId)
  BoolNot(SlotId, SlotId)
  BoolEq(SlotId, SlotId, SlotId)
  BoolNe(SlotId, SlotId, SlotId)
  F64Add(SlotId, SlotId, SlotId)
  F64Sub(SlotId, SlotId, SlotId)
  F64Mul(SlotId, SlotId, SlotId)
  F64Div(SlotId, SlotId, SlotId)
  F64Neg(SlotId, SlotId)
  F64Eq(SlotId, SlotId, SlotId)
  F64Ne(SlotId, SlotId, SlotId)
  F64Lt(SlotId, SlotId, SlotId)
  F64Le(SlotId, SlotId, SlotId)
  F64Gt(SlotId, SlotId, SlotId)
  F64Ge(SlotId, SlotId, SlotId)
  I64ToF64(SlotId, SlotId)
  F64ToI64(SlotId, SlotId)
  F32Add(SlotId, SlotId, SlotId)
  F32Sub(SlotId, SlotId, SlotId)
  F32Mul(SlotId, SlotId, SlotId)
  F32Div(SlotId, SlotId, SlotId)
  F32Neg(SlotId, SlotId)
  F32Eq(SlotId, SlotId, SlotId)
  F32Ne(SlotId, SlotId, SlotId)
  F32Lt(SlotId, SlotId, SlotId)
  F32Le(SlotId, SlotId, SlotId)
  F32Gt(SlotId, SlotId, SlotId)
  F32Ge(SlotId, SlotId, SlotId)
  I64ToF32(SlotId, SlotId)
  F32ToI64(SlotId, SlotId)
  F32ToF64(SlotId, SlotId)
  F64ToF32(SlotId, SlotId)
  F32ToString(SlotId, SlotId)
  F64ToString(SlotId, SlotId)
  EraseI32(SlotId, SlotId)
  UneraseI32(SlotId, SlotId)
  EraseI64(SlotId, SlotId)
  UneraseI64(SlotId, SlotId)
  EraseF64(SlotId, SlotId)
  UneraseF64(SlotId, SlotId)
  EraseF32(SlotId, SlotId)
  UneraseF32(SlotId, SlotId)
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
  TailCallPackedDirect(FunctionId, SlotId, Array[SlotId], Array[SlotId])
  TailCallValue(SlotId, CallableAbiId, Array[SlotId], Array[SlotId])
  Fatal(SlotId)
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
  result : ResultAbi
  blocks : Array[Block]
} derive(Debug, Eq)

///|
pub(all) enum FunctionEntry {
  PhysicalBody(FunctionBody)
  RuntimeImport(@wasm_abi.ImportContract)
} derive(Debug, Eq)

///|
pub(all) struct PhysicalProgram {
  entry : FunctionId
  initializer : FunctionId?
  callable_abis : Array[CallableAbi]
  data_family_count : Int
  functions : Array[FunctionEntry]
  globals : Array[GlobalMetadata]
  layouts : Array[LayoutRecipe]
  object_shapes : Array[ObjectShape]
  constants : Array[Bytes]
} derive(Debug, Eq)

///|
pub fn statically_known_object_shape(
  object_shapes : Array[ObjectShape],
  kind : SemanticValueKind,
) -> ObjectShapeId? {
  match kind {
    EnvironmentValue(shape) => Some(shape)
    DataValue(family) => {
      let mut found : ObjectShapeId? = None
      for index, shape in object_shapes {
        if shape is Data({ family: actual, .. }) && actual == family {
          if found is Some(_) {
            return None
          }
          found = Some({ value: index, })
        }
      }
      found
    }
    _ => None
  }
}
