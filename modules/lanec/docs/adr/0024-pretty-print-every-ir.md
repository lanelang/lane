# Pretty print every IR

Lane2 provides a stable pretty printer for every compiler IR layer. Parser, resolver, type checker, typed core, and later lowered or bytecode layers should use readable pretty-printed output for diagnostics and test assertions instead of relying on raw debug dumps or weak structural predicates.
