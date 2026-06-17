# Interpreter entry selection

Lane2's reference interpreter evaluates a whole typed core program and lets the caller choose which checked value or function to evaluate. The interpreter does not hard-code `main`, because source files do not define executable entrypoints in v1 and entrypoint selection belongs to later linker or runtime tooling.
