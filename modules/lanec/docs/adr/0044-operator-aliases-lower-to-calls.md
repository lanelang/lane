# Operator aliases lower to calls

Lane2 typed core does not preserve ordinary operator aliases as special operator nodes. After operation resolution, operators such as `+`, `==`, and `<` lower to first-class calls of the resolved operation value; only `&&` and `||` additionally thunk their right operand according to the short-circuit operation rule.
