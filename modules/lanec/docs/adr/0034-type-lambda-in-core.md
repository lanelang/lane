# Type lambda in core

Lane2 typed core represents generic function literals and other polymorphic values with explicit type lambda introduction and type application elimination. A generic function literal elaborates to a type lambda whose body is an ordinary function value, giving typed core a clear introduction/elimination pair for `Forall` types and leaving type arguments available for diagnostics until runtime type erasure.
