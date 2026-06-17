# Declaration-order struct patterns

Lane2 typed core normalizes checked struct patterns to declaration order. Semantic lowering resolves field names, punning, duplicates, and completeness before core, allowing the interpreter and later lowered IR to match struct values by declared field position while diagnostics and pretty printers still recover field names from metadata.
