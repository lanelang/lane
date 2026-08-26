// The binary32 conversion is derived from Ulf Adams' Ryū implementation.
// Copyright 2018 Ulf Adams. Licensed under Apache-2.0 or BSL-1.0.

///|
priv struct FloatingDecimal32 {
  mantissa : UInt
  exponent : Int
}

///|
let f32_pow5_inv_split : ReadOnlyArray[UInt64] = [
  2305843009213693952UL, 1844674407370955161UL, 1475739525896764129UL, 1180591620717411303UL,
  1888946593147858085UL, 1511157274518286468UL, 1208925819614629174UL, 1934281311383406679UL,
  1547425049106725343UL, 1237940039285380274UL, 1980704062856608439UL, 1584563250285286751UL,
  1267650600228229401UL, 2028240960365167042UL, 1622592768292133633UL, 1298074214633706907UL,
  2076918743413931051UL, 1661534994731144841UL, 1329227995784915872UL, 2126764793255865396UL,
  1701411834604692317UL, 1361129467683753853UL, 2177807148294006166UL, 1742245718635204932UL,
  1393796574908163946UL, 2230074519853062314UL, 1784059615882449851UL, 1427247692705959881UL,
  2283596308329535809UL, 1826877046663628647UL, 1461501637330902918UL,
]

///|
let f32_pow5_split : ReadOnlyArray[UInt64] = [
  1152921504606846976UL, 1441151880758558720UL, 1801439850948198400UL, 2251799813685248000UL,
  1407374883553280000UL, 1759218604441600000UL, 2199023255552000000UL, 1374389534720000000UL,
  1717986918400000000UL, 2147483648000000000UL, 1342177280000000000UL, 1677721600000000000UL,
  2097152000000000000UL, 1310720000000000000UL, 1638400000000000000UL, 2048000000000000000UL,
  1280000000000000000UL, 1600000000000000000UL, 2000000000000000000UL, 1250000000000000000UL,
  1562500000000000000UL, 1953125000000000000UL, 1220703125000000000UL, 1525878906250000000UL,
  1907348632812500000UL, 1192092895507812500UL, 1490116119384765625UL, 1862645149230957031UL,
  1164153218269348144UL, 1455191522836685180UL, 1818989403545856475UL, 2273736754432320594UL,
  1421085471520200371UL, 1776356839400250464UL, 2220446049250313080UL, 1387778780781445675UL,
  1734723475976807094UL, 2168404344971008868UL, 1355252715606880542UL, 1694065894508600678UL,
  2117582368135750847UL, 1323488980084844279UL, 1654361225106055349UL, 2067951531382569187UL,
  1292469707114105741UL, 1615587133892632177UL, 2019483917365790221UL,
]

///|
fn pow5_bits(exponent : Int) -> Int {
  ((exponent * 1217359).reinterpret_as_uint() >> 19).reinterpret_as_int() + 1
}

///|
fn log10_pow2(exponent : Int) -> Int {
  ((exponent * 78913).reinterpret_as_uint() >> 18).reinterpret_as_int()
}

///|
fn log10_pow5(exponent : Int) -> Int {
  ((exponent * 732923).reinterpret_as_uint() >> 20).reinterpret_as_int()
}

///|
fn multiple_of_power_of_5(value : UInt, exponent : Int) -> Bool {
  let mut value = value
  for _ in 0..<exponent {
    if value % 5 != 0 {
      return false
    }
    value = value / 5
  }
  true
}

///|
fn multiple_of_power_of_2(value : UInt, exponent : Int) -> Bool {
  (value & ((1U << exponent) - 1)) == 0
}

///|
fn mul_shift_32(mantissa : UInt, factor : UInt64, shift : Int) -> UInt {
  let factor_low = (factor & 0xffffffffUL).to_uint()
  let factor_high = (factor >> 32).to_uint()
  let bits0 = mantissa.to_uint64() * factor_low.to_uint64()
  let bits1 = mantissa.to_uint64() * factor_high.to_uint64()
  (((bits0 >> 32) + bits1) >> (shift - 32)).to_uint()
}

///|
fn mul_pow5_inv_div_pow2(mantissa : UInt, q : Int, shift : Int) -> UInt {
  mul_shift_32(mantissa, f32_pow5_inv_split[q] + 1UL, shift)
}

///|
fn mul_pow5_div_pow2(mantissa : UInt, i : Int, shift : Int) -> UInt {
  mul_shift_32(mantissa, f32_pow5_split[i], shift)
}

///|
fn f32_to_decimal(
  ieee_mantissa : UInt,
  ieee_exponent : UInt,
) -> FloatingDecimal32 {
  let (binary_exponent, binary_mantissa) = if ieee_exponent == 0 {
    (1 - 127 - 23 - 2, ieee_mantissa)
  } else {
    (
      ieee_exponent.reinterpret_as_int() - 127 - 23 - 2,
      (1U << 23) | ieee_mantissa,
    )
  }
  let accepts_bounds = (binary_mantissa & 1) == 0
  let center = 4U * binary_mantissa
  let upper = center + 2U
  let lower_shift = if ieee_mantissa != 0 || ieee_exponent <= 1 {
    1U
  } else {
    0U
  }
  let lower = center - 1U - lower_shift
  let mut vr = 0U
  let mut vp = 0U
  let mut vm = 0U
  let mut decimal_exponent = 0
  let mut lower_is_trailing_zeros = false
  let mut center_is_trailing_zeros = false
  let mut last_removed_digit = 0U
  if binary_exponent >= 0 {
    let q = log10_pow2(binary_exponent)
    decimal_exponent = q
    let k = 61 + pow5_bits(q) - 1
    let shift = -binary_exponent + q + k
    vr = mul_pow5_inv_div_pow2(center, q, shift)
    vp = mul_pow5_inv_div_pow2(upper, q, shift)
    vm = mul_pow5_inv_div_pow2(lower, q, shift)
    if q != 0 && (vp - 1) / 10 <= vm / 10 {
      let previous_k = 61 + pow5_bits(q - 1) - 1
      last_removed_digit = mul_pow5_inv_div_pow2(
          center,
          q - 1,
          -binary_exponent + q - 1 + previous_k,
        ) %
        10
    }
    if q <= 9 {
      if center % 5 == 0 {
        center_is_trailing_zeros = multiple_of_power_of_5(center, q)
      } else if accepts_bounds {
        lower_is_trailing_zeros = multiple_of_power_of_5(lower, q)
      } else if multiple_of_power_of_5(upper, q) {
        vp = vp - 1
      }
    }
  } else {
    let q = log10_pow5(-binary_exponent)
    decimal_exponent = q + binary_exponent
    let i = -binary_exponent - q
    let k = pow5_bits(i) - 61
    let mut shift = q - k
    vr = mul_pow5_div_pow2(center, i, shift)
    vp = mul_pow5_div_pow2(upper, i, shift)
    vm = mul_pow5_div_pow2(lower, i, shift)
    if q != 0 && (vp - 1) / 10 <= vm / 10 {
      shift = q - 1 - (pow5_bits(i + 1) - 61)
      last_removed_digit = mul_pow5_div_pow2(center, i + 1, shift) % 10
    }
    if q <= 1 {
      center_is_trailing_zeros = true
      if accepts_bounds {
        lower_is_trailing_zeros = lower_shift == 1U
      } else {
        vp = vp - 1
      }
    } else if q < 31 {
      center_is_trailing_zeros = multiple_of_power_of_2(center, q - 1)
    }
  }
  let mut removed = 0
  let output = if lower_is_trailing_zeros || center_is_trailing_zeros {
    while vp / 10 > vm / 10 {
      lower_is_trailing_zeros = lower_is_trailing_zeros && vm % 10 == 0
      center_is_trailing_zeros = center_is_trailing_zeros &&
        last_removed_digit == 0
      last_removed_digit = vr % 10
      vr = vr / 10
      vp = vp / 10
      vm = vm / 10
      removed += 1
    }
    if lower_is_trailing_zeros {
      while vm % 10 == 0 {
        center_is_trailing_zeros = center_is_trailing_zeros &&
          last_removed_digit == 0
        last_removed_digit = vr % 10
        vr = vr / 10
        vm = vm / 10
        removed += 1
      }
    }
    if center_is_trailing_zeros && last_removed_digit == 5 && vr % 2 == 0 {
      last_removed_digit = 4
    }
    if (vr == vm && (!accepts_bounds || !lower_is_trailing_zeros)) ||
      last_removed_digit >= 5 {
      vr + 1
    } else {
      vr
    }
  } else {
    while vp / 10 > vm / 10 {
      last_removed_digit = vr % 10
      vr = vr / 10
      vp = vp / 10
      vm = vm / 10
      removed += 1
    }
    if vr == vm || last_removed_digit >= 5 {
      vr + 1
    } else {
      vr
    }
  }
  { mantissa: output, exponent: decimal_exponent + removed, }
}

///|
fn repeat_zeroes(count : Int) -> String {
  let output = StringBuilder::new()
  for _ in 0..<count {
    output.write_char('0')
  }
  output.to_string()
}

///|
fn render_decimal(value : FloatingDecimal32, negative : Bool) -> String {
  let digits = value.mantissa.to_string()
  let scientific_exponent = value.exponent + digits.length() - 1
  let sign = if negative { "-" } else { "" }
  if scientific_exponent >= -6 && scientific_exponent < 21 {
    let point = value.exponent + digits.length()
    if point <= 0 {
      sign + "0." + repeat_zeroes(-point) + digits
    } else if point >= digits.length() {
      sign + digits + repeat_zeroes(point - digits.length()) + ".0"
    } else {
      sign +
      digits.unsafe_substring(start=0, end=point) +
      "." +
      digits.unsafe_substring(start=point, end=digits.length())
    }
  } else {
    let coefficient = if digits.length() == 1 {
      digits
    } else {
      digits.unsafe_substring(start=0, end=1) +
      "." +
      digits.unsafe_substring(start=1, end=digits.length())
    }
    let exponent_sign = if scientific_exponent < 0 { "-" } else { "+" }
    sign +
    coefficient +
    "e" +
    exponent_sign +
    scientific_exponent.abs().to_string()
  }
}

///|
fn has_float_marker(text : String) -> Bool {
  for character in text {
    if character == '.' || character == 'e' || character == 'E' {
      return true
    }
  }
  false
}

///|
pub fn format_f64(value : Double) -> String {
  let bits = value.reinterpret_as_uint64()
  let negative = bits >> 63 != 0
  let exponent = bits & 0x7ff0000000000000UL
  let mantissa = bits & 0x000fffffffffffffUL
  if exponent == 0x7ff0000000000000UL {
    if mantissa != 0UL {
      "NaN"
    } else if negative {
      "-inf"
    } else {
      "inf"
    }
  } else if exponent == 0UL && mantissa == 0UL {
    if negative {
      "-0.0"
    } else {
      "0.0"
    }
  } else {
    let shortest = value.to_string()
    if has_float_marker(shortest) {
      shortest
    } else {
      shortest + ".0"
    }
  }
}

///|
pub fn format_f32(value : Float) -> String {
  let bits = value.reinterpret_as_uint()
  let negative = bits >> 31 != 0
  let exponent = bits & 0x7f800000
  let mantissa = bits & 0x007fffff
  if exponent == 0x7f800000 {
    if mantissa != 0 {
      "NaN"
    } else if negative {
      "-inf"
    } else {
      "inf"
    }
  } else if exponent == 0 && mantissa == 0 {
    if negative {
      "-0.0"
    } else {
      "0.0"
    }
  } else {
    render_decimal(f32_to_decimal(mantissa, exponent >> 23), negative)
  }
}
