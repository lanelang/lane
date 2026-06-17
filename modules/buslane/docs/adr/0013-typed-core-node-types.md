# Typed core node types

Lane2 typed core stores or otherwise makes available the type of every core expression and binding after type checking. The first implementation should attach types directly to core nodes for simplicity; a later arena or table-based representation may move the same information into a type table without changing the typed core contract.
