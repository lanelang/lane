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
pub(all) enum IntrinsicSignature {
  Value(ValueKind)
  Function(parameters~ : Array[ValueKind], result~ : ValueKind)
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
  StringEqual
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
    "%string_equal" => Some(StringEqual)
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
    StringEqual => "%string_equal"
  }
}

///|
pub fn Intrinsic::signature(self : Intrinsic) -> IntrinsicSignature {
  match self {
    I64Add | I64Sub | I64Mul | I64Div | I64Rem =>
      Function(parameters=[Int, Int], result=Int)
    I64Neg => Function(parameters=[Int], result=Int)
    I64Equal | I64Less => Function(parameters=[Int, Int], result=Bool)
    F64Add | F64Sub | F64Mul | F64Div =>
      Function(parameters=[Double, Double], result=Double)
    F64Neg => Function(parameters=[Double], result=Double)
    F64Equal | F64Less => Function(parameters=[Double, Double], result=Bool)
    F64Inf | F64NegativeInf | F64Nan => Value(Double)
    StringEqual => Function(parameters=[String, String], result=Bool)
  }
}
