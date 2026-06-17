# MoonBit parser as syntax reference

Lane2 keeps its surface syntax close to MoonBit and uses `moonbitlang/parser` as the reference for concrete expression parsing, precedence, and associativity where Lane2 has not deliberately removed a feature. The parser repository is a reference for compatibility of syntax shape, not a required runtime dependency, because Lane2 intentionally omits mutation, assignment, module design, labels, and other features from v1.
