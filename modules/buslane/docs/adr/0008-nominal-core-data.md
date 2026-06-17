# Nominal core data

Lane2 typed core retains nominal struct and enum constructor identity instead of lowering data immediately to anonymous tuples, raw tags, or field offsets. Keeping nominal data in typed core preserves the language's nominal data model for diagnostics, pattern checking, interpretation, and later lowering; execution targets may still choose compact tag and layout representations after the semantic core.
