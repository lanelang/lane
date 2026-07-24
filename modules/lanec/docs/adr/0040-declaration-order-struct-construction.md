# Declaration-order struct construction

Lane2 typed core normalizes struct construction to declaration order rather than preserving source field order. Semantic lowering checks missing, duplicate, and unknown fields, then produces field values in the owning struct's declared order so interpretation and later layout lowering do not depend on source spelling order.

Field initializer expressions still evaluate exactly once in source order. When source order differs from declaration order, Checked Core makes that sequencing explicit with local bindings before the declaration-ordered construction.
