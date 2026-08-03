# Lane Review Standard

The Lane language is designed to be elegant; the compiler must be its equal.
This review does not ask whether the code works — the test suite answers that.
It asks whether every package is a work of art: nothing missing, nothing extra, nothing accidental.

## The aesthetic, concretely
- No special cases. A rule holds uniformly or the rule is wrong; a branch added for one caller means the seam is misplaced — move the seam, never add the case.
- Uniformity has no exemptions: generated code, %-binders, and dead metadata obey the same laws as user code. "Unused" never excuses "illegal".
- Meaning lives in structure, never in spelling: no decision may hinge on the text of a name; ids and shapes carry the semantics.
- One owner per fact: every derived fact has exactly one producer. A second site computing the same thing is tomorrow's divergence, hence today's defect.
- Duality is honored: dual concepts (define/lookup, lower/verify, parameter/result) get dual shapes and dual names; every asymmetry needs a written reason.
- Code reads as inevitable, not clever: if believing it correct requires the commit message, it fails.

## The architecture
- The pipeline is a chain of verified programs: every stage boundary passes the Buslane verifier; no stage trusts its input or silently repairs it.
- Each IR is a first-class language: it has a printer, a parser, a codec, and a verifier, and round-trips through them. An IR you cannot print and re-check is not done.
- Problems are fixed where they are created, never masked downstream — dead-code elimination is not a fix, and phase order follows meaning, not convenience.
- One responsibility per package, stated in its CONTEXT.md in one paragraph that matches the code.
- The glossary is law: every concept has exactly one name, defined in CONTEXT.md and used verbatim in code, tests, and issues; synonym drift is a finding.
- Invariants are enforced by construction or checked by a verifier; a comment is not an enforcement mechanism.
- Tests pin contracts, not implementation accidents: a test that a legal refactor breaks is itself a finding.

## The method
- Root causes only: a workaround, patch, or compatibility shim is a top-severity finding. When the architecture is the bug, the finding must say so.
- Interface compatibility is never a reason to preserve a wrong design; rewrite the callers.
- Claims are measured, not argued: a root cause counts as established only with instrumentation or a minimal reproduction behind it.
- Findings are filed as issues/ISS-###.md with evidence; nothing is fixed silently mid-review.
- Mechanical gates (formatting, warnings, full test suite, examples corpus) are assumed prerequisites, not review content.

Severity: broken invariant → P0–P1; violated aesthetic → P1–P2; vocabulary drift → P2–P3.
