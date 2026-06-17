# Origin spans in typed core

Lane2 typed core may carry origin spans as diagnostic annotations, but spans do not participate in semantics. Keeping origin spans through the semantic core supports type errors, interpreter traces, and later debug tables, while lower execution IRs and bytecode can compact this information into separate debug metadata.
