# Operator aliases lower to calls

Lane2 typed core does not preserve ordinary operator aliases as special operator nodes. After canonical provider resolution, operators such as `+`, `==`, and `<` lower to first-class calls of the certified `Basic.Ops` value; only `&&` and `||` additionally thunk their right operand according to the short-circuit operation rule. ADR 0142 owns the provider identity mapping, while Basic owns the provider's declared type.
