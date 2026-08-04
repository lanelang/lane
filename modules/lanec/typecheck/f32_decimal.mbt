///|
priv struct ParsedDecimal {
  negative : Bool
  coefficient : BigInt
  exponent10 : Int
  significant_digits : Int
}

///|
/// Converts the authored decimal exactly to a rational number, then rounds
/// that rational once to IEEE binary32 using round-to-nearest, ties-to-even.
fn parse_f32_decimal(raw : String) -> Float? {
  guard parse_decimal(raw) is Some(decimal) else { return None }
  let significand_bits = 23
  let minimum_normal_exponent = -126
  let maximum_normal_exponent = 127
  let hidden_bit = 1 << significand_bits
  let carry_bit = 1 << (significand_bits + 1)
  let sign = if decimal.negative { 1 << 31 } else { 0 }
  if decimal.coefficient.is_zero() {
    return Some(Float::reinterpret_from_int(sign))
  }
  let adjusted_exponent = decimal.significant_digits + decimal.exponent10 - 1
  if adjusted_exponent > 39 || adjusted_exponent < -46 {
    return None
  }
  let ten = BigInt::from_int(10)
  let one = BigInt::from_int(1)
  let (numerator, denominator) = if decimal.exponent10 >= 0 {
    (
      decimal.coefficient.mul(ten.pow(BigInt::from_int(decimal.exponent10))),
      one,
    )
  } else {
    (decimal.coefficient, ten.pow(BigInt::from_int(-decimal.exponent10)))
  }
  let exponent = binary_exponent(numerator, denominator)
  let magnitude_bits = if exponent >= minimum_normal_exponent {
    let mut rounded = round_binary_significand(
      numerator,
      denominator,
      significand_bits - exponent,
    )
    let mut normalized_exponent = exponent
    if rounded.compare_int(carry_bit) == 0 {
      rounded = BigInt::from_int(hidden_bit)
      normalized_exponent = normalized_exponent + 1
    }
    if normalized_exponent > maximum_normal_exponent {
      return None
    }
    ((normalized_exponent - minimum_normal_exponent + 1) << significand_bits) |
    (rounded.to_int() - hidden_bit)
  } else {
    let rounded = round_binary_significand(
      numerator,
      denominator,
      significand_bits - minimum_normal_exponent,
    )
    if rounded.is_zero() {
      return None
    }
    if rounded.compare_int(hidden_bit) == 0 {
      hidden_bit
    } else {
      rounded.to_int()
    }
  }
  Some(Float::reinterpret_from_int(sign | magnitude_bits))
}

///|
fn parse_decimal(raw : String) -> ParsedDecimal? {
  let digits = StringBuilder::new()
  // Once an exponent exceeds the source length by this margin, no coefficient
  // in the same source can bring binary32 back into range. Saturation prevents
  // an arbitrarily long exponent spelling from overflowing `Int`.
  let exponent_limit = raw.length() + 100
  let mut negative = false
  let mut in_exponent = false
  let mut exponent_negative = false
  let mut exponent_magnitude = 0
  let mut seen_exponent_digit = false
  let mut seen_decimal_point = false
  let mut fractional_digits = 0
  let mut seen_nonzero = false
  let mut significant_digits = 0
  let mut seen_coefficient_digit = false
  let mut index = 0
  for character in raw {
    match character {
      '-' if index == 0 => negative = true
      '.' if !in_exponent && !seen_decimal_point => seen_decimal_point = true
      'e' | 'E' if !in_exponent => in_exponent = true
      '+' if in_exponent && !seen_exponent_digit => ()
      '-' if in_exponent && !seen_exponent_digit => exponent_negative = true
      '0'..='9' => {
        let digit = character.to_int() - '0'.to_int()
        if in_exponent {
          seen_exponent_digit = true
          if exponent_magnitude < exponent_limit {
            exponent_magnitude = (exponent_magnitude * 10 + digit).min(
              exponent_limit,
            )
          }
        } else {
          seen_coefficient_digit = true
          digits.write_char(character)
          if seen_decimal_point {
            fractional_digits = fractional_digits + 1
          }
          if seen_nonzero {
            significant_digits = significant_digits + 1
          } else if digit != 0 {
            seen_nonzero = true
            significant_digits = 1
          }
        }
      }
      _ => return None
    }
    index = index + 1
  }
  if !seen_coefficient_digit || (in_exponent && !seen_exponent_digit) {
    return None
  }
  let explicit_exponent = if exponent_negative {
    -exponent_magnitude
  } else {
    exponent_magnitude
  }
  Some({
    negative,
    coefficient: BigInt::from_string(digits.to_string()),
    exponent10: explicit_exponent - fractional_digits,
    significant_digits,
  })
}

///|
fn binary_exponent(numerator : BigInt, denominator : BigInt) -> Int {
  // `bit_length` gives an estimate within one; the comparison establishes the
  // unique exponent e for which 2^e <= numerator / denominator < 2^(e + 1).
  let estimate = numerator.bit_length() - denominator.bit_length()
  let comparison = if estimate >= 0 {
    numerator.compare(denominator.shl(estimate))
  } else {
    numerator.shl(-estimate).compare(denominator)
  }
  if comparison < 0 {
    estimate - 1
  } else {
    estimate
  }
}

///|
fn round_binary_significand(
  numerator : BigInt,
  denominator : BigInt,
  shift : Int,
) -> BigInt {
  let (scaled_numerator, scaled_denominator) = if shift >= 0 {
    (numerator.shl(shift), denominator)
  } else {
    (numerator, denominator.shl(-shift))
  }
  let quotient = scaled_numerator.div(scaled_denominator)
  let remainder = scaled_numerator.mod(scaled_denominator)
  let midpoint_comparison = remainder.shl(1).compare(scaled_denominator)
  if midpoint_comparison > 0 ||
    (midpoint_comparison == 0 && !quotient.mod(BigInt::from_int(2)).is_zero()) {
    quotient.add(BigInt::from_int(1))
  } else {
    quotient
  }
}
