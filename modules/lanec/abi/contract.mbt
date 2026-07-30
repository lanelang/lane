///|
pub(all) enum ValueKind {
  Unit
  Bool
  Int
  Double
  String
  Opaque
} derive(Debug, Eq)

///|
pub(all) struct HostSignature {
  parameters : Array[ValueKind]
  result : ValueKind
} derive(Debug, Eq)

///|
pub(all) enum IntrinsicValueKind {
  Unit
  Bool
  Int
  S32
  Char
  Double
  String
  Byte
  Bytes
} derive(Debug, Eq)

///|
pub(all) enum IntrinsicSignature {
  Value(IntrinsicValueKind)
  Function(
    parameters~ : Array[IntrinsicValueKind],
    result~ : IntrinsicValueKind
  )
} derive(Debug, Eq)

///|
pub(all) enum Intrinsic {
  I64Add
  I64Sub
  I64Mul
  I64Div
  I64Rem
  I64Neg
  I64Equal
  I64Less
  I32Add
  I32Sub
  I32Mul
  I32Div
  I32Rem
  I32Neg
  I32Equal
  I32Less
  S32ToInt
  IntToS32
  F64Add
  F64Sub
  F64Mul
  F64Div
  F64Neg
  F64Equal
  F64Less
  F64Inf
  F64NegativeInf
  F64Nan
  CharToS32
  S32ToChar
  StringToBytes
  BytesIsValidUtf8
  BytesToString
  BytesEqual
  BytesConcat
  BytesSlice
  ByteToInt
  IntToByte
  BytesMake
  BytesLength
  BytesGet
  BytesSet
} derive(Debug, Eq)

///|
pub fn Intrinsic::from_name(name : String) -> Intrinsic? {
  match name {
    "%i64_add" => Some(I64Add)
    "%i64_sub" => Some(I64Sub)
    "%i64_mul" => Some(I64Mul)
    "%i64_div" => Some(I64Div)
    "%i64_rem" => Some(I64Rem)
    "%i64_neg" => Some(I64Neg)
    "%i64_equal" => Some(I64Equal)
    "%i64_less" => Some(I64Less)
    "%i32_add" => Some(I32Add)
    "%i32_sub" => Some(I32Sub)
    "%i32_mul" => Some(I32Mul)
    "%i32_div" => Some(I32Div)
    "%i32_rem" => Some(I32Rem)
    "%i32_neg" => Some(I32Neg)
    "%i32_equal" => Some(I32Equal)
    "%i32_less" => Some(I32Less)
    "%s32_to_int" => Some(S32ToInt)
    "%int_to_s32" => Some(IntToS32)
    "%f64_add" => Some(F64Add)
    "%f64_sub" => Some(F64Sub)
    "%f64_mul" => Some(F64Mul)
    "%f64_div" => Some(F64Div)
    "%f64_neg" => Some(F64Neg)
    "%f64_equal" => Some(F64Equal)
    "%f64_less" => Some(F64Less)
    "%f64_inf" => Some(F64Inf)
    "%f64_ninf" => Some(F64NegativeInf)
    "%f64_nan" => Some(F64Nan)
    "%char_to_s32" => Some(CharToS32)
    "%s32_to_char" => Some(S32ToChar)
    "%string_to_bytes" => Some(StringToBytes)
    "%bytes_is_valid_utf8" => Some(BytesIsValidUtf8)
    "%bytes_to_string" => Some(BytesToString)
    "%bytes_equal" => Some(BytesEqual)
    "%bytes_concat" => Some(BytesConcat)
    "%bytes_slice" => Some(BytesSlice)
    "%byte_to_int" => Some(ByteToInt)
    "%int_to_byte" => Some(IntToByte)
    "%bytes_make" => Some(BytesMake)
    "%bytes_length" => Some(BytesLength)
    "%bytes_get" => Some(BytesGet)
    "%bytes_set" => Some(BytesSet)
    _ => None
  }
}

///|
pub fn Intrinsic::name(self : Intrinsic) -> String {
  match self {
    I64Add => "%i64_add"
    I64Sub => "%i64_sub"
    I64Mul => "%i64_mul"
    I64Div => "%i64_div"
    I64Rem => "%i64_rem"
    I64Neg => "%i64_neg"
    I64Equal => "%i64_equal"
    I64Less => "%i64_less"
    I32Add => "%i32_add"
    I32Sub => "%i32_sub"
    I32Mul => "%i32_mul"
    I32Div => "%i32_div"
    I32Rem => "%i32_rem"
    I32Neg => "%i32_neg"
    I32Equal => "%i32_equal"
    I32Less => "%i32_less"
    S32ToInt => "%s32_to_int"
    IntToS32 => "%int_to_s32"
    F64Add => "%f64_add"
    F64Sub => "%f64_sub"
    F64Mul => "%f64_mul"
    F64Div => "%f64_div"
    F64Neg => "%f64_neg"
    F64Equal => "%f64_equal"
    F64Less => "%f64_less"
    F64Inf => "%f64_inf"
    F64NegativeInf => "%f64_ninf"
    F64Nan => "%f64_nan"
    CharToS32 => "%char_to_s32"
    S32ToChar => "%s32_to_char"
    StringToBytes => "%string_to_bytes"
    BytesIsValidUtf8 => "%bytes_is_valid_utf8"
    BytesToString => "%bytes_to_string"
    BytesEqual => "%bytes_equal"
    BytesConcat => "%bytes_concat"
    BytesSlice => "%bytes_slice"
    ByteToInt => "%byte_to_int"
    IntToByte => "%int_to_byte"
    BytesMake => "%bytes_make"
    BytesLength => "%bytes_length"
    BytesGet => "%bytes_get"
    BytesSet => "%bytes_set"
  }
}

///|
pub fn Intrinsic::signature(self : Intrinsic) -> IntrinsicSignature {
  match self {
    I64Add | I64Sub | I64Mul | I64Div | I64Rem =>
      Function(parameters=[Int, Int], result=Int)
    I64Neg => Function(parameters=[Int], result=Int)
    I64Equal | I64Less => Function(parameters=[Int, Int], result=Bool)
    I32Add | I32Sub | I32Mul | I32Div | I32Rem =>
      Function(parameters=[S32, S32], result=S32)
    I32Neg => Function(parameters=[S32], result=S32)
    I32Equal | I32Less => Function(parameters=[S32, S32], result=Bool)
    S32ToInt => Function(parameters=[S32], result=Int)
    IntToS32 => Function(parameters=[Int], result=S32)
    F64Add | F64Sub | F64Mul | F64Div =>
      Function(parameters=[Double, Double], result=Double)
    F64Neg => Function(parameters=[Double], result=Double)
    F64Equal | F64Less => Function(parameters=[Double, Double], result=Bool)
    F64Inf | F64NegativeInf | F64Nan => Value(Double)
    CharToS32 => Function(parameters=[Char], result=S32)
    S32ToChar => Function(parameters=[S32], result=Char)
    StringToBytes => Function(parameters=[String], result=Bytes)
    BytesIsValidUtf8 => Function(parameters=[Bytes], result=Bool)
    BytesToString => Function(parameters=[Bytes], result=String)
    BytesEqual => Function(parameters=[Bytes, Bytes], result=Bool)
    BytesConcat => Function(parameters=[Bytes, Bytes], result=Bytes)
    BytesSlice => Function(parameters=[Bytes, Int, Int], result=Bytes)
    ByteToInt => Function(parameters=[Byte], result=Int)
    IntToByte => Function(parameters=[Int], result=Byte)
    BytesMake => Function(parameters=[Int, Byte], result=Bytes)
    BytesLength => Function(parameters=[Bytes], result=Int)
    BytesGet => Function(parameters=[Bytes, Int], result=Byte)
    BytesSet => Function(parameters=[Bytes, Int, Byte], result=Bytes)
  }
}
