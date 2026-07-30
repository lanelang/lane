///|
pub(all) enum ValueKind {
  Unit
  Bool
  I64
  F64
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
  I64
  I32
  Char
  F64
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
  I32ToI64
  I64ToI32
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
  CharToI32
  I32ToChar
  StringToBytes
  BytesIsValidUtf8
  BytesToString
  BytesEqual
  BytesConcat
  BytesSlice
  ByteToI64
  I64ToByte
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
    "%i32_to_i64" => Some(I32ToI64)
    "%i64_to_i32" => Some(I64ToI32)
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
    "%char_to_i32" => Some(CharToI32)
    "%i32_to_char" => Some(I32ToChar)
    "%string_to_bytes" => Some(StringToBytes)
    "%bytes_is_valid_utf8" => Some(BytesIsValidUtf8)
    "%bytes_to_string" => Some(BytesToString)
    "%bytes_equal" => Some(BytesEqual)
    "%bytes_concat" => Some(BytesConcat)
    "%bytes_slice" => Some(BytesSlice)
    "%byte_to_i64" => Some(ByteToI64)
    "%i64_to_byte" => Some(I64ToByte)
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
    I32ToI64 => "%i32_to_i64"
    I64ToI32 => "%i64_to_i32"
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
    CharToI32 => "%char_to_i32"
    I32ToChar => "%i32_to_char"
    StringToBytes => "%string_to_bytes"
    BytesIsValidUtf8 => "%bytes_is_valid_utf8"
    BytesToString => "%bytes_to_string"
    BytesEqual => "%bytes_equal"
    BytesConcat => "%bytes_concat"
    BytesSlice => "%bytes_slice"
    ByteToI64 => "%byte_to_i64"
    I64ToByte => "%i64_to_byte"
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
      Function(parameters=[I64, I64], result=I64)
    I64Neg => Function(parameters=[I64], result=I64)
    I64Equal | I64Less => Function(parameters=[I64, I64], result=Bool)
    I32Add | I32Sub | I32Mul | I32Div | I32Rem =>
      Function(parameters=[I32, I32], result=I32)
    I32Neg => Function(parameters=[I32], result=I32)
    I32Equal | I32Less => Function(parameters=[I32, I32], result=Bool)
    I32ToI64 => Function(parameters=[I32], result=I64)
    I64ToI32 => Function(parameters=[I64], result=I32)
    F64Add | F64Sub | F64Mul | F64Div =>
      Function(parameters=[F64, F64], result=F64)
    F64Neg => Function(parameters=[F64], result=F64)
    F64Equal | F64Less => Function(parameters=[F64, F64], result=Bool)
    F64Inf | F64NegativeInf | F64Nan => Value(F64)
    CharToI32 => Function(parameters=[Char], result=I32)
    I32ToChar => Function(parameters=[I32], result=Char)
    StringToBytes => Function(parameters=[String], result=Bytes)
    BytesIsValidUtf8 => Function(parameters=[Bytes], result=Bool)
    BytesToString => Function(parameters=[Bytes], result=String)
    BytesEqual => Function(parameters=[Bytes, Bytes], result=Bool)
    BytesConcat => Function(parameters=[Bytes, Bytes], result=Bytes)
    BytesSlice => Function(parameters=[Bytes, I64, I64], result=Bytes)
    ByteToI64 => Function(parameters=[Byte], result=I64)
    I64ToByte => Function(parameters=[I64], result=Byte)
    BytesMake => Function(parameters=[I64, Byte], result=Bytes)
    BytesLength => Function(parameters=[Bytes], result=I64)
    BytesGet => Function(parameters=[Bytes, I64], result=Byte)
    BytesSet => Function(parameters=[Bytes, I64, Byte], result=Bytes)
  }
}
