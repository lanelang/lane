///|
let keyword_table : @hashmap.HashMap[String, Token] = [
    ("struct", STRUCT),
    ("enum", ENUM),
    ("effect", EFFECT),
    ("fn", FN),
    ("let", LET),
    ("type", TYPE),
    ("offer", OFFER),
    ("auto", AUTO),
    ("if", IF),
    ("else", ELSE),
    ("match", MATCH),
    ("handle", HANDLE),
    ("with", WITH),
    ("final", FINAL),
    ("builtin", BUILTIN),
    ("extern", EXTERN),
    ("module", MODULE),
    ("import", IMPORT),
    ("pub", PUB),
    ("true", TRUE),
    ("false", FALSE),
    ("_", UNDERSCORE),
  ]
  |> @hashmap.from_array()

///|
let reserved_word_table : @hashset.HashSet[String] = ["handler", "return"]
  |> @hashset.from_array()
