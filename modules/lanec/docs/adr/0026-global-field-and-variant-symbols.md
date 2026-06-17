# Global field and variant symbols

Lane2 uses globally unique field and variant symbol identities, with metadata recording the owning struct or enum, source name, type, and declaration position. This keeps field access, variant construction, contextual forwarding, diagnostics, and typed core references simple while still preserving each symbol's nominal owner.
