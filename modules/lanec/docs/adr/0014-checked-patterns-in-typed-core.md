# Checked patterns in typed core

Lane2 typed core keeps match arms as checked patterns rather than lowering pattern matching immediately to decision trees. Checked patterns preserve source-facing diagnostics and are simple for the reference interpreter, while decision-tree generation remains a later lowering step for optimized execution targets.
