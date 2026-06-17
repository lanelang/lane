# Closure conversion after typed core

Lane2 typed core keeps first-class function values and lexical scope rather than lambda-lifting or closure-converting functions during type checking. Closure conversion belongs to a later lowered IR so the semantic core can remain close to the language while execution targets decide how to represent environments, closure objects, and function entry points.
