///|
/// A framing or primitive-value failure reported at an absolute reader offset.
pub(all) suberror ByteDecodeError {
  UnexpectedEnd(offset~ : Int, expected~ : String, available~ : Int)
  InvalidUtf8(offset~ : Int)
  InvalidBool(offset~ : Int, value~ : Int)
  ImplementationLimit(offset~ : Int, expected~ : String)
  TrailingBytes(offset~ : Int, remaining~ : Int)
} derive(Debug, Eq)
