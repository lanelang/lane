# Resolved variant core

Lane2 typed core represents enum construction and enum patterns with variant symbol identities and declaration-order payloads. Variant metadata records the owning enum, display name, payload types, and eventual tag/index information, so interpretation compares variant identity directly while later lowering can choose compact runtime tags.
