# Builtin runtime plugins

Lane2 defines the core unsafe builtin contract in `lanec`, but concrete execution behavior is supplied by runtime-specific builtin plugins. Builtin dispatch receives both the intrinsic name and the typed core expected type, allowing plugins to select, validate, or debug runtime behavior without making the type checker interpret intrinsic names. This keeps the compiler core target-independent while allowing each reference interpreter, bytecode VM host, CLI tool, or future runtime to define its own builtin implementations beyond the required portable intrinsic names.
