# ANF atoms include lambdas

Lane2 structured ANF treats ordinary function values and type lambdas as core atoms. Calls, type applications, data construction, field access, conditionals, and matches remain computed expressions or right-hand sides, while lambda and type-lambda forms are value introductions that do not need an extra ANF binding solely to establish evaluation order.
