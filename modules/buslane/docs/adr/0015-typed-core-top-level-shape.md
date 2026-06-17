# Typed core top-level shape

Status: superseded by ADR-0052

Lane2 typed core represents a checked program as nominal type definitions, typed function definitions, typed value definitions, and typed contextual-call information rather than preserving source-shaped contextual sugar. This ADR has been superseded because v1 no longer has `open`, `let open`, or preopen exposure metadata; contextual arguments are supplied by Contextual Resolution as described in ADR-0052.
