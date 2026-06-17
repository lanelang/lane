# Shared type objects package

Lane2 keeps checked type objects in a dedicated compiler package rather than embedding them in semantic analysis. Source type syntax belongs to the parser and syntax layer, while semantic analysis, typed core, builtin dispatch keys, interpreter plugins, and future execution targets share the checked type object representation without depending on the type checker package internals.
