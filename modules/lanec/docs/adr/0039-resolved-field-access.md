# Resolved field access

Lane2 typed core represents field access by field symbol identity rather than by source name strings or raw field indices alone. Field metadata supplies the owner struct, display name, type, and layout index, so typed core keeps name resolution complete while preserving enough information for diagnostics, pretty printing, interpretation, and later layout lowering.
