# Resolve open before typed core

Status: superseded by ADR-0052

Lane2 resolves `open`, `preopen`, unqualified variants, and operator aliases before producing typed core. These forms are lexical and naming mechanisms rather than runtime constructs, so typed core contains direct references to the selected values, functions, constructors, and operations; diagnostics can still retain source-resolution information in the resolved AST layer.
