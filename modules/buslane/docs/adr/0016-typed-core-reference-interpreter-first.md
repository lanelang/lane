# Typed core reference interpreter first

Lane2 implements a reference interpreter for typed core ANF before building a bytecode VM. The reference interpreter provides a semantic oracle for type checking, operator lowering, pattern matching, closures, explicit libraries, and intrinsics; a later bytecode VM should be tested against this reference behavior rather than becoming the first place where core semantics are defined.
