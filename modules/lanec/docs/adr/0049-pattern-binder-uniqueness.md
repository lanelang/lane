# Pattern binder uniqueness

Lane2 patterns cannot bind the same value name more than once within a single pattern. Repeated binders would imply either shadowing or an implicit equality constraint between matched values, and Lane2 v1 has neither pattern guards nor built-in equality semantics for arbitrary values.
