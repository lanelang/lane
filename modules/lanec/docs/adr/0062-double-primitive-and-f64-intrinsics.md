# Double primitive and f64 intrinsics

Lane adds `Double` as a language primitive for IEEE 754 binary64 values. `Double` literals are source numeric literals with a decimal fraction or exponent, must parse to finite binary64 values, and are not overloaded with `Int` literals or implicit `Int`/`Double` conversions.

Infinities and NaN are not language literals; the explicit Basic library surface provides ordinary values over `%f64_inf`, `%f64_ninf`, and `%f64_nan`. Basic also provides IEEE-style `Double` arithmetic and comparison operations over `%f64_*` intrinsics, but does not provide floating remainder or conversion functions in the first version.

Source diagnostics may retain the user's original literal spelling, while Buslane text and artifacts use stable roundtrip decimal text for the semantic binary64 value.
